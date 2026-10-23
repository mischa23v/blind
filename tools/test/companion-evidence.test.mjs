// Source-integration contracts. Behavioral evidence is in the shared Swift/Node fixtures;
// these checks do not claim an Apple build, actual model quality or microphone/device success.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
const read = path => readFile(new URL(`../../${path}`, import.meta.url), 'utf8');
const section = (text, from, to) => {
  const start = text.indexOf(from), end = text.indexOf(to, start + from.length);
  assert.ok(start >= 0 && end > start, `${from} -> ${to}`);
  return text.slice(start, end);
};

test('explicit location requests and reports are code-owned before model calls', async () => {
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  const receive = section(model, 'func receiveCompanionUtterance(', 'private func handleConversationTaskControl');
  assert.ok(receive.indexOf('CompanionUtterance.parse(text)') < receive.indexOf('answerConversation(text)'));
  const scene = section(model, 'func readScene(', 'private func queueQuestion(');
  assert.ok(scene.indexOf('CompanionUtterance.parse(question)') < scene.indexOf('LocalImageAssistant.describe('));
  const conversation = section(model, 'private func answerConversation(', 'func startVoiceQuestion');
  assert.ok(conversation.indexOf('CompanionUtterance.parse(question)') < conversation.indexOf('LocalImageAssistant.converse('));
  assert.doesNotMatch(conversation, /answer\.action/);
  const local = await read('ios/BlindAssist/LocalImageAssistant.swift');
  assert.match(local, /CompanionFactBook/);
  assert.match(local, /locationReportSources/);
});

test('model conversation keeps exact provenance, claim guard and streamed delivery admission', async () => {
  const core = await read('BlindCore/Sources/BlindCore/CompanionEvidence.swift');
  const gate = section(core, 'public static func allows(', '/// Sentence boundaries');
  assert.match(gate, /SpatialClaimGuard\.containsSpatialClaim/);
  assert.match(gate, /ConversationClaimGuard\.containsUnsupportedClaim\(remainder\)/);
  assert.ok(gate.indexOf('exact.isCurrent') < gate.indexOf('ConversationClaimGuard'));
  assert.ok(gate.indexOf('attributedQuotation') < gate.indexOf('ConversationClaimGuard'));
  const assistant = await read('ios/BlindAssist/LocalImageAssistant.swift');
  assert.match(assistant, /CompanionSentenceStream/);
  assert.match(assistant, /CompanionEvidenceGuard\.allows/);
});

test('image descriptions retain detector agreement without weakening spatial rules', async () => {
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  assert.match(model, /VisualGrounding\.agreedObjects\(groundingFrames\)/);
  assert.match(model, /VisualGrounding\.groundedDescription\(\$0, confirmed: confirmedObjects\)/);
  assert.match(model, /if fromModel && SpatialClaimGuard\.containsSpatialClaim\(answer\)/);
});

test('reply-only home keeps assistant controls and reading shortcuts on a separate screen', async () => {
  const view = await read('ios/BlindAssist/DashboardView.swift');
  assert.match(view, /HomeToolButtons\(model: model\)/);
  assert.match(view, /CompanionControlsView\(model: model\)/);
  assert.match(view, /companion-reply/);
  assert.match(view, /muteConversation|assistantSession/);
  assert.match(view, /endConversation/);
  assert.doesNotMatch(view, /\.toolbar\(\.hidden, for: \.tabBar\)/);
});

test('manual turns preserve continuous capture without defeating mute end or bounded recovery', async () => {
  const voice = await read('ios/BlindAssist/VoiceInput.swift');
  assert.match(voice, /if continuous, lifecycle\.requested, self\.arabic == arabic/);
  assert.match(voice, /VoiceCaptureRecoveryPolicy/);
  assert.match(voice, /func cancel\(\)/);
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  assert.match(model, /assistantSession\.mute\(\)/);
  assert.match(model, /assistantSession\.end\(\)/);
  assert.match(model, /assistantSession\.setBackgroundAllowed\(backgroundConversation\)/);
});

test('sensor search does not turn missed detections or stale positions into current facts', async () => {
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  const search = section(model, 'private func locate(_ target:', '// MARK: - The person');
  assert.doesNotMatch(search, /readScene\(/);
  assert.match(search, /case \.notLocated:[\s\S]*ObjectSearch\.notLocated/);
  assert.match(search, /DepthSampler\.worldPoint/);
  assert.match(search, /point: located, now: capturedAt/);
  assert.match(search, /current\.id == trackedID/);
  assert.match(search, /point\.distance\(to: current\.point\) <= 0\.3/);
  const target = await read('BlindCore/Sources/BlindCore/TrackedTarget.swift');
  assert.ok(target.indexOf('guard now - lastSeen < 0.5') < target.indexOf('relation.distance <= Self.reachDistance'));
});

test('background and practice respect separate camera and conversation lifecycles', async () => {
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  const suspend = section(model, 'func suspendExperience()', 'func startConversation()');
  assert.match(suspend, /assistantSession\.enterBackground\(\)/);
  assert.match(suspend, /stopCameraMonitoring\(\)/);
  assert.match(suspend, /if !assistantSession\.shouldListen \{ voice\.cancel\(\) \}/);
  const practice = section(model, 'func startSimulation()', 'func simulate(');
  assert.match(practice, /stopCameraMonitoring\(\)/);
  assert.doesNotMatch(practice, /\bstop\(\)|reconnectListening\(\)/);
  assert.match(practice, /withTimeInterval: 120/);
});

test('reading is model-free and page work stays owned until cancellable completion', async () => {
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  const reading = model.split('// MARK: - Reading tools')[1];
  assert.doesNotMatch(reading, /LocalImageAssistant|LanguageModelSession|SceneQuestionClient|URLSession/);
  for (const name of ['textLines', 'documentCorners', 'code']) assert.ok(reading.includes(`VisionService.${name}`));
  assert.match(reading, /readingTask = Task/);
  assert.match(reading, /readingWork\.owns\(capture\.token\)/);
  assert.match(reading, /readingCaptureAllowed\(capture\)/);
  assert.match(reading, /readingWork\.cancel\(\); readingTask\?\.cancel\(\)/);
  const page = section(reading, 'private func readWholePage(', '/// Captured pictures');
  assert.doesNotMatch(page.split('readingTask = Task')[0], /readingTool = nil/);
  assert.ok(page.indexOf('readingCaptureAllowed(capture)') < page.indexOf('self.sceneAnswer = text'));
});

test('new goals cancel reading before money colour or model routing and stale callbacks cannot unlock a new job', async () => {
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  const scene = section(model, 'func readScene(', 'private func queueQuestion(');
  assert.ok(scene.indexOf('stopReadingTool(announce: false)') < scene.indexOf('routeSaudiBanknoteCommand(question)'));
  const cancel = section(model, 'private func cancelDescription()', 'private func publish()');
  assert.match(cancel, /stopReadingTool\(announce: false\)/);
  const reading = section(model, 'private func updateReadingTool(', '/// Captured pictures');
  assert.ok(reading.indexOf('readingWork.owns(capture.token)') < reading.indexOf('self.readingInFlight = false'));
});

test('captured photo work is private fenced and cannot return after dismissal', async () => {
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  const snapshot = section(model, 'func captureExploreSnapshot()', 'extension CGImagePropertyOrientation');
  assert.equal((snapshot.match(/self\.exploreRequest == token/g) ?? []).length, 2);
  assert.match(snapshot, /func clearExploreSnapshot\(\)[\s\S]*exploreRequest = UUID\(\); exploreTask\?\.cancel\(\)/);
  assert.doesNotMatch(snapshot, /saveValue|write\(to:|URLSession/);
});
