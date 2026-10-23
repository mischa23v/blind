// Source wiring contracts only. They complement executable BlindCore policy tests;
// they do not validate Apple callbacks, OCR accuracy, audio timing or device lifecycle.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const read = file => readFile(new URL(`../../${file}`, import.meta.url), 'utf8');
const compact = source => source.replace(/\s+/g, '');
function section(source, from, to) {
  const start = source.indexOf(from);
  assert.notEqual(start, -1, `Missing source boundary: ${from}`);
  const end = source.indexOf(to, start + from.length);
  assert.notEqual(end, -1, `Missing source boundary: ${to}`);
  return source.slice(start, end);
}
function includesAll(source, fragments) {
  const normalized = compact(source);
  for (const fragment of fragments) assert.ok(normalized.includes(compact(fragment)), fragment);
}
function before(source, first, second) {
  const normalized = compact(source), a = normalized.indexOf(compact(first)), b = normalized.indexOf(compact(second));
  assert.ok(a >= 0 && b >= 0 && a < b, `${first} must precede ${second}`);
}

test('reader callbacks own their token before touching shared in-flight state', async () => {
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  const start = section(model, 'func startReadingTool(', 'func stopReadingTool(');
  before(start, 'cancelDescription()', 'readingWork.begin()');
  for (const body of [
    section(model, 'private func updateReadingTool(', 'private func readWholePage('),
    section(model, 'private func readWholePage(', 'private static func documentReadingChunks(')
  ]) {
    const callback = body.slice(body.indexOf('}.value'));
    before(callback, 'self.readingWork.owns(capture.token)', 'self.readingInFlight = false');
    includesAll(callback, ['!Task.isCancelled', 'self.readingCaptureAllowed(capture)']);
  }
  const gate = section(model, 'private func readingCaptureAllowed(', 'private func updateReadingTool(');
  includesAll(gate, ['assistantSession.foregroundActive', 'assistantSession.generation == capture.sessionGeneration',
    'readingWork.accepts(capture.token', 'visualCapturePoseAllowed(origin: capture.origin, forward: capture.forward)',
    'perceptionResultAllowed(request: capture.request, generation: capture.generation',
    'mapRevision: capture.mapRevision, alignmentRevision: capture.alignmentRevision']);
  const policy = await read('BlindCore/Sources/BlindCore/ReadingWorkSession.swift');
  includesAll(policy, ['token = UUID(); active = true', 'token = UUID(); active = false',
    'active && token == candidate', 'now >= capturedAt', 'now - capturedAt < 0.5']);
});

test('reader stop invalidates ownership and queued chunks before interrupting active speech', async () => {
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  const stop = section(model, 'func stopReadingTool(', 'private struct ReadingCapture');
  includesAll(stop, ['readingWork.cancel()', 'readingTask?.cancel()', 'readingTool = nil',
    'documentChunks = []', 'documentSpeechID = nil', 'documentStability.reset()', 'documentOrigin = nil']);
  before(stop, 'documentSpeechID = nil', 'feedback.stopInformation(');
  before(stop, 'readingWork.cancel()', 'feedback.stopInformation(');
  // Silent cancellation must stop an active document too, not only explicit Stop commands.
  const silent = stop.slice(0, stop.indexOf('if announce'));
  includesAll(silent, ['documentSpeechID != nil', 'feedback.stopInformation(']);
  const cancel = section(model, 'private func cancelDescription()', 'private func publish()');
  includesAll(cancel, ['stopReadingTool(announce: false)', 'currencyRetake.clear()', 'exploreTask?.cancel()']);
  for (const [start, end] of [['func suspendExperience()', 'func startConversation()'],
    ['func muteConversation()', 'func endConversation()'], ['func endConversation()', 'func reconnectListening()']]) {
    includesAll(section(model, start, end), ['cancelDescription()']);
  }
});

test('whole-page output uses bounded snapshot chunks and retires only completed matching speech', async () => {
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  const page = section(model, 'private func readWholePage(', 'private static func documentReadingChunks(');
  includesAll(page, ['self.documentChunks = Self.documentReadingChunks(text, arabic: arabic)', 'self.speakNextDocumentChunk()']);
  const chunks = section(model, 'private static func documentReadingChunks(', 'private func speakNextDocumentChunk()');
  includesAll(chunks, ['NLTokenizer(unit: .word)', 'tokens(for: text.startIndex..<text.endIndex)',
    'From the captured page:', 'من الصفحة الملتقطة:']);
  const bound = chunks.match(/stride\s*\(\s*from\s*:\s*0\s*,\s*to\s*:\s*tokens\.count\s*,\s*by\s*:\s*(\d+)/);
  assert.ok(bound && Number(bound[1]) > 0 && Number(bound[1]) <= 26,
    'Leave room for the snapshot prefix inside the minimum 30-word admission budget');
  const dispatch = section(model, 'private func speakNextDocumentChunk()', 'func captureExploreSnapshot()');
  includesAll(dispatch, ['documentSpeechID == nil', 'documentChunks.first', 'readingWork.active',
    'assistantSession.foregroundActive', 'detection.hazard == .observing', '!voice.awaitingUtterance',
    'feedback.speechPriority == nil', 'speakRequested(chunk, replace: false, speechID: id)']);
  assert.doesNotMatch(dispatch, /removeFirst\s*\(/, 'Admission does not prove completion');
  const finish = section(model, 'feedback.onRequestedSpeechFinished =', 'feedback.onIdle =');
  before(finish, 'self.documentSpeechID == id', 'self.documentChunks.removeFirst()');
  before(finish, 'outcome == .completed', 'self.documentChunks.removeFirst()');
  includesAll(finish, ['self.readingTool == .document', 'self.stopReadingTool(announce: false)']);
});

test('currency continuation requires an explicit pending command and a fresh newer frame', async () => {
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  const receive = section(model, 'func receiveCompanionUtterance(', 'private func handleConversationTaskControl(');
  includesAll(receive, ['pendingRetake.isPending', 'CurrencyRetakeSession.isRetryCommand(text)', 'retryCurrencyCapture(pendingRetake); return']);
  before(receive, 'let pendingRetake = currencyRetake', 'cancelDescription()');
  before(receive, 'cancelDescription()', 'retryCurrencyCapture(pendingRetake)');
  assert.equal((model.match(/\bretryCurrencyCapture\s*\(/g) ?? []).length, 2,
    'Only the declaration and explicit user-command handler may invoke retry');
  const retry = section(model, 'private func retryCurrencyCapture(', 'func routeClothingColorCommand(');
  includesAll(retry, ['assistantSession.foregroundActive', 'attention.stationary', 'detection.hazard == .observing',
    'SaudiBanknotePolicy.fresh(capturedAt: lastFrameWallTime, now: now)',
    'retake.takeRetry(frameAt: lastFrameWallTime, now: now)', 'routeSaudiBanknoteCommand("read money", retake: retake)']);
  before(retry, 'retake.takeRetry(', 'routeSaudiBanknoteCommand("read money", retake: retake)');
  assert.doesNotMatch(retry, /Timer\s*\.|Task\s*\.\s*sleep|LocalImageAssistant/, 'No automatic polling or model fallback');
  const policy = await read('BlindCore/Sources/BlindCore/CurrencyRetakeSession.swift');
  const take = section(policy, 'func takeRetry(', 'public mutating func clear()');
  includesAll(take, ['phase == .armed', 'now < expiresAt', 'retriesUsed < Self.maximumAdditionalAttempts',
    'frameAt.isFinite', 'frameAt <= now', 'frameAt > lastFrameAt', 'phase = .awaitingResult']);
  before(take, 'frameAt > lastFrameAt', 'retriesUsed += 1');
  includesAll(policy, ['phase != .closed', 'reason == .unavailable', 'now >= $0']);
});

test('unavailable or incompatible currency recognizers cannot open retry or guessing paths', async () => {
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  const route = section(model, 'func routeSaudiBanknoteCommand(', 'private func retryCurrencyCapture(');
  const unavailable = section(route, 'guard SaudiBanknoteReferenceRecognition.isAvailable', 'guard running');
  includesAll(unavailable, ['currencyRetake.clear()', 'return true']);
  assert.doesNotMatch(unavailable, /\.arm\s*\(|LocalImageAssistant/);
  const failure = section(route, 'if error is SaudiBanknoteReferenceRecognition.Failure', '} else {');
  includesAll(failure, ['currencyRetake.clear()', "unavailable in this build. I won't guess."]);
  assert.doesNotMatch(failure, /\.arm\s*\(/);
  const adapter = await read('ios/BlindAssist/SaudiBanknoteReferenceRecognition.swift');
  assert.match(adapter, /enum\s+Failure\s*:\s*Error\s*\{\s*case\s+unavailable\s*,\s*incompatible/);
  assert.match(route, /case\s+\.denomination\s*=\s*result/);
  includesAll(route, ['self.currencyRetake.clear()', 'self.speakRequested(self.message, narrationID: request)',
    'self.currencyRetake.arm(reason: reason, rejectedFrameAt: capturedAt']);
});

test('photo transfer and Vision continuations stay fenced to the visible presentation and request', async () => {
  const view = await read('ios/BlindAssist/ExplorePictureView.swift');
  const load = section(view, '.onChange(of: photo)', 'if let snapshot =');
  includesAll(load, ['presentationActive', 'photoLoadTask = Task', '!Task.isCancelled',
    'photoLoadGeneration == generation', 'model.assistantSession.generation == sessionGeneration']);
  before(load, 'cancelPhotoLoad()', 'loadTransferable(');
  before(load, 'model.clearExploreSnapshot()', 'loadTransferable(');
  before(load, 'photoLoadGeneration == generation', 'model.explorePhoto(image)');
  before(load, 'model.assistantSession.generation == sessionGeneration', 'model.explorePhoto(image)');
  includesAll(section(view, '.onDisappear', 'private func cancelPhotoLoad'),
    ['presentationActive = false', 'cancelPhotoLoad()', 'model.clearExploreSnapshot()']);
  includesAll(view.slice(view.indexOf('private func cancelPhotoLoad')),
    ['photoLoadGeneration = UUID()', 'photoLoadTask?.cancel()', 'photoLoadTask = nil']);
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  const clear = section(model, 'func clearExploreSnapshot()', 'func explorePhoto(');
  includesAll(clear, ['exploreRequest = UUID()', 'exploreTask?.cancel()', 'exploreSnapshot = nil']);
  const photo = model.slice(model.indexOf('func explorePhoto('));
  includesAll(photo, ['!Task.isCancelled', 'self.exploreRequest == token', 'self.assistantSession.generation == generation']);
});
