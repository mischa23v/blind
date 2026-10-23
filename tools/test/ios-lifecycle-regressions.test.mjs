// Source integration checks complement WorkRevision's executable Swift tests. Apple framework
// callbacks still require the Mac/iPhone harness; these checks ensure the adapters use the gates.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
const read = file => readFile(new URL(`../../${file}`, import.meta.url), 'utf8');

test('all fast image-answer completions revalidate their request and current scene', async () => {
  const source = await read('ios/BlindAssist/NavigationModel.swift');
  for (const name of ['findItemByLook(', 'verifyHeldItem(']) {
    const start = source.indexOf(`private func ${name}`);
    const end = source.indexOf('\n    private func ', start + 1);
    const body = source.slice(start, end < 0 ? undefined : end);
    assert.match(body, /perceptionResultAllowed\(/, name);
    assert.match(body, /mapRevision: mapRevision, alignmentRevision: alignmentRevision/, name);
  }
  // RGB discovery uses exact capture ownership; the disabled physical branch
  // additionally invokes the existing spatial/map validator.
  const search = source.slice(source.indexOf('private func continueSearch('), source.indexOf('private func offerSearchHint('));
  for (const required of ['self.requestID == request', 'self.objectViewIsCurrent(capture)',
    'self.perceptionResultAllowed', 'mapRevision: mapRevision, alignmentRevision: alignmentRevision']) {
    assert.ok(search.includes(required), required);
  }
  const rgb = source.slice(source.indexOf('private func objectViewIsCurrent('), source.indexOf('/// Live search'));
  for (const required of ['requestID == capture.request', 'passiveObservationGeneration == capture.generation',
    'now - capture.capturedAt < (snapshotPlayback ? 12 : 0.5)', 'case .normal = frame.camera.trackingState']) {
    assert.ok(rgb.includes(required), required);
  }
  const gate = source.slice(source.indexOf('private func perceptionResultAllowed'), source.indexOf('private func cancelDescription'));
  for (const required of ['running', '!simulation', '!places.scanning', 'requestID == request', 'perceptionGeneration == generation', 'SceneDelivery.allowed', 'indoor.revision == mapRevision', 'indoor.alignmentRevision == alignmentRevision']) {
    assert.ok(gate.includes(required), required);
  }
});

test('voice deletion uses the same appearance cleanup as UI deletion', async () => {
  const source = await read('ios/BlindAssist/NavigationModel.swift');
  const voice = source.slice(source.indexOf('case .forget(let name):'), source.indexOf('/// Live search'));
  assert.match(voice, /forgetItem\(saved\)/);
  const deletion = source.slice(source.indexOf('func forgetItem('), source.indexOf('var savedRooms:'));
  assert.match(deletion, /updated.forget/); assert.match(deletion, /itemAppearance.forget/);
  assert.match(deletion, /learningItem = nil/); assert.match(deletion, /cancelDescription\(\)/);
});

test('queued private image writes honor record deletion revisions', async () => {
  for (const [file, key] of [['ItemAppearance.swift', 'key'], ['RoomRecall.swift', 'room']]) {
    const source = await read(`ios/BlindAssist/${file}`);
    assert.ok(source.includes(`workRevision.token(for: ${key})`));
    assert.match(source, /workRevision.accepts\(revision\)/);
    assert.ok(source.includes(`workRevision.invalidate(${key})`));
    assert.match(source, /func cancelPendingWork\(\) \{ workRevision.invalidateAll\(\) \}/);
  }
});

test('OCR cannot convert an ambiguous appearance match to an ownership assertion', async () => {
  const source = await read('ios/BlindAssist/ItemAppearance.swift');
  assert.match(source, /let result = ItemAppearanceMatch.decide\(distances\)/);
  assert.doesNotMatch(source, /result = \.same\(/);
});

test('unresolved room evidence clears both identity and trusted learning basis', async () => {
  const source = await read('ios/BlindAssist/NavigationModel.swift');
  const start = source.indexOf('private func updateRoomRecognition(');
  const body = source.slice(start, source.indexOf('private func askRoom(', start));
  assert.match(body, /case \.unknown:\s*self.invalidateRecognizedRoom\(\)/);
  assert.match(source, /recognizedRoomID = nil; recognizedBasis = \[\]/);
  assert.doesNotMatch(body, /clues.append\(\.movedThrough/, 'one connected door is not proof of a crossing');
});

test('microphone permission explains hands-free companion listening', async () => {
  const plist = await read('ios/BlindAssist/Info.plist');
  assert.match(plist, /voice conversation you start/);
  assert.match(plist, /until you mute or end it/);
  assert.match(plist, /separate background voice opt-in/);
  assert.doesNotMatch(plist, /only when you tap Talk/);
});


test('reply-only home keeps controls available through the Settings destination', async () => {
  const source = await read('ios/BlindAssist/DashboardView.swift');
  const home = source.slice(source.indexOf('private struct CompanionHomeView'), source.indexOf('private struct CompanionControlsView'));
  assert.match(home, /Text\(reply\)/);
  assert.match(home, /companion-reply/);
  assert.match(home, /model.currentReply/);
  assert.doesNotMatch(home, /Button\(|Toggle\(|TextField\(|NavigationLink|HomeToolButtons|homePrompt|sceneAnswer|onChange|UIAccessibility|accessibilityActions/);
  assert.match(home, /toolbar\(\.hidden, for: \.navigationBar\)/);
  assert.doesNotMatch(source, /toolbar\(\.hidden, for: \.tabBar\)/);
  const controls = source.slice(source.indexOf('private struct CompanionControlsView'), source.indexOf('private struct HomeAction'));
  for (const required of ['model.muteConversation', 'model.endConversation', 'model.startConversation',
    '$model.cameraAwareness', 'write-message', 'HomeToolButtons(model: model)']) {
    assert.ok(controls.includes(required), required);
  }
  assert.match(source, /NavigationLink[\s\S]*CompanionControlsView\(model: model\)/);
  assert.match(source, /accessibilityIdentifier\("conversation-controls"\)/);
  assert.doesNotMatch(controls, /if model.textOnly\s*\{\s*Button/);
  const monitor = source.slice(source.indexOf('private var monitor:'), source.indexOf('private var assistant:'));
  assert.match(monitor, /Stop monitoring/);
  assert.match(monitor, /model.cameraAwareness.toggle\(\)/);
  assert.doesNotMatch(monitor, /startExperience\(|restartSensors\(/);
  for (const identifier of ['background-conversation', 'assistant-audience', 'conversation-memory', 'wearable-setup', 'reconnect-microphone', 'home-practice']) {
    assert.equal(source.split(`accessibilityIdentifier("${identifier}")`).length - 1, 1, `${identifier} must be unique`);
  }
});

test('photo library transfers cannot restart exploration after dismissal or supersession', async () => {
  const source = await read('ios/BlindAssist/ExplorePictureView.swift');
  assert.match(source, /@State private var photoLoadTask: Task<Void, Never>\?/);
  assert.match(source, /@State private var photoLoadGeneration = UUID\(\)/);
  const load = source.slice(source.indexOf('.onChange(of: photo)'), source.indexOf('if let snapshot ='));
  assert.match(load, /guard let item, presentationActive else \{ return \}/);
  assert.ok(load.indexOf('cancelPhotoLoad()') < load.indexOf('loadTransferable'));
  assert.ok(load.indexOf('model.clearExploreSnapshot()') < load.indexOf('loadTransferable'));
  assert.match(load, /guard !Task.isCancelled, presentationActive, photoLoadGeneration == generation else \{ return \}/);
  assert.match(load, /model.assistantSession.generation == sessionGeneration else \{ return \}/);
  assert.ok(load.indexOf('photoLoadGeneration == generation') < load.indexOf('model.explorePhoto(image)'));
  assert.ok(load.indexOf('model.assistantSession.generation == sessionGeneration') < load.indexOf('model.explorePhoto(image)'));
  const dismiss = source.slice(source.indexOf('.onDisappear'), source.indexOf('private func cancelPhotoLoad'));
  for (const required of ['presentationActive = false', 'cancelPhotoLoad()', 'photo = nil', 'model.clearExploreSnapshot()']) {
    assert.ok(dismiss.includes(required), required);
  }
  const cancellation = source.slice(source.indexOf('private func cancelPhotoLoad'));
  assert.match(cancellation, /photoLoadGeneration = UUID\(\)/);
  assert.match(cancellation, /photoLoadTask\?\.cancel\(\)/);
  const capture = source.slice(source.indexOf('Button(t("Take a new picture'), source.indexOf('.accessibilityIdentifier("explore-capture")'));
  assert.ok(capture.indexOf('cancelPhotoLoad()') < capture.indexOf('model.captureExploreSnapshot()'));
});

test('hosted premise fixtures follow the code-owned parser before consulting the model', async () => {
  const source = await read('ios/BlindAssistTests/CommunityTests.swift');
  const suite = source.slice(source.indexOf('struct UnsupportedPremiseTests'));
  assert.match(suite, /if let utterance = CompanionUtterance.parse\(message\)/);
  assert.match(suite, /last = state.respond\(to: utterance, message: message, arabic: false\)/);
  assert.ok(suite.indexOf('state.respond(') < suite.indexOf('LocalImageAssistant.converse('));
  assert.doesNotMatch(suite, /answer.action/);
  assert.match(source, /final class CompanionWorkingStateTests/);
});
