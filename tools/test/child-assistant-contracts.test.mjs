// Source wiring checks, not Apple callback execution, real-model behavior, or latency tests.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
const read = path => readFile(new URL(`../../${path}`, import.meta.url), 'utf8');
const compact = text => text.replace(/\s+/g, '');
function section(source, start, end) {
  const a = source.indexOf(start), b = source.indexOf(end, a + start.length);
  assert.ok(a >= 0 && b > a, `Missing section ${start} / ${end}`);
  return source.slice(a, b);
}
function before(source, first, second) {
  const text = compact(source), a = text.indexOf(compact(first)), b = text.indexOf(compact(second));
  assert.ok(a >= 0 && b > a, `${first} must precede ${second}`);
}

test('foreground launch starts only an idle conversation and respects saved-off sensing', async () => {
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  const app = await read('ios/BlindAssist/BlindAssistApp.swift');
  assert.match(app, /onChange\(of: scenePhase, initial: true\)/);
  assert.match(app, /phase == \.active.*resumeExperienceIfNeeded\(\)/);
  const resume = section(model, 'func resumeExperienceIfNeeded()', 'func suspendExperience()');
  assert.match(resume, /if assistantSession\.state == \.idle\s*\{[^}]*assistantSession\.start\(\)/);
  assert.match(resume, /if cameraAwareness && assistantSession\.foregroundActive && !textOnly\s*\{ start\(\) \}/);
  assert.match(resume, /if !textOnly && assistantSession\.shouldListen\s*\{ voice\.startContinuous/);
  assert.match(model, /cameraAwareness = UserDefaults.standard.object\(forKey: "camera-awareness"\) == nil\s*\? true : UserDefaults.standard.bool\(forKey: "camera-awareness"\)/);
  const state = await read('BlindCore/Sources/BlindCore/AssistantSession.swift');
  const enter = section(state, 'public mutating func enterForeground()', 'public mutating func setBackgroundAllowed(');
  assert.doesNotMatch(enter, /state\s*=|start\(/, 'foreground must not replace muted/ended state');
});

test('permission denial is reported and late camera grants cannot override foreground or off state', async () => {
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  const permission = section(model, 'switch AVCaptureDevice.authorizationStatus', 'private func launch(');
  assert.match(permission, /cameraStartupID == id/);
  assert.match(permission, /assistantSession\.foregroundActive/);
  assert.match(permission, /self\.cameraAwareness/);
  assert.match(permission, /if granted\s*\{ self\.outdoor\.requestCoarseLocation\(\); self\.launchWithNearbyPlace\(\) \} else \{ self\.cameraPermissionNeeded\(\) \}/);
  before(permission, 'guard let self, self.cameraStartupID == id, self.assistantSession.foregroundActive, self.cameraAwareness else { return }',
    'if granted { self.outdoor.requestCoarseLocation(); self.launchWithNearbyPlace() }');
  assert.match(permission, /default: cameraPermissionNeeded\(\)/);
  assert.match(permission, /I need camera permission/);
  const voice = await read('ios/BlindAssist/VoiceInput.swift');
  assert.match(voice, /guard status == \.authorized else \{ self\.permissionUnavailable\(\)/);
  assert.match(voice, /guard allowed else \{ self\.permissionUnavailable\(\)/);
  assert.match(voice, /I need microphone and speech permission/);
});

test('authorized startup wrapper captures once before bounded room recovery, without reset loops', async () => {
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  const startup = section(model, 'private func launchWithNearbyPlace()', 'private func cancelAutomaticRoomRecovery()');
  before(startup, 'cancelAutomaticRoomRecovery()', 'automaticRoomRecoveryEnabled = true');
  before(startup, 'launch()', 'tickAutomaticRoomRecovery(now:');
  assert.equal((startup.match(/\blaunch\(\)/g) ?? []).length, 1);
  assert.doesNotMatch(startup, /\bfor\s|\bwhile\s|recognize\(/);
  const launch = section(model, 'private func launch(map:', '\n    func stop()');
  assert.doesNotMatch(launch, /automaticRoomRecovery\.reset|launchWithNearbyPlace\(/);
  const tick = section(model, 'private func tickAutomaticRoomRecovery(now:', 'private func probeAutomaticRoomAppearance(frame:');
  assert.match(tick, /allowNewAttempt: mayStart/);
  assert.doesNotMatch(tick, /automaticRoomRecovery\.reset|launchWithNearbyPlace\(/);
});

test('ordinary conversation is not forced through camera capture or permission setup', async () => {
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  const receive = section(model, 'func receiveCompanionUtterance(', 'private func routeEverydayTask(');
  assert.match(receive, /if case \.visualRequest = ConversationIntent\.classify\(text\)\s*\{\s*readScene\(cloud: false, question: text\)\s*\} else \{\s*answerConversation\(text\)/);
  assert.doesNotMatch(receive, /requestAccess|session\.currentFrame|VisionService|URLSession/);
  const chat = section(model, 'private func answerConversation(', 'func startVoiceQuestion(');
  before(chat, 'ConversationDomainPolicy.allowsModelResponse(to: question)', 'LocalImageAssistant.converse(');
  assert.doesNotMatch(chat, /guard running|guard cameraAwareness|requestAccess|session\.currentFrame/);
});

test('sensor callbacks reach hazard cancellation and dispatch without waiting for model work', async () => {
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  const wearable = section(model, 'wearables.onUpdate =', 'voice.onUnavailable =');
  assert.match(wearable, /if self\.running \{ self\.publish\(\) \}/);
  assert.doesNotMatch(wearable, /await|Task\.sleep|LocalImageAssistant|URLSession/);
  const publish = section(model, 'private func publish()', 'func session(_ session: ARSession, didFailWithError');
  before(publish, 'cancelDescription()', 'announceDetection(detection)');
  assert.match(publish, /detection\.hazard\.isUrgent/);
  assert.match(publish, /questionTask\?\.cancel\(\)/);
  assert.doesNotMatch(publish, /await|LocalImageAssistant|URLSession|Task\.sleep/);
  const cancel = section(model, 'private func cancelDescription()', 'private func publish()');
  for (const value of ['conversationSpeech.removeAll()', 'exploreTask?.cancel()', 'stopReadingTool(announce: false)', 'requestID = UUID()', 'questionTask?.cancel()']) {
    assert.ok(compact(cancel).includes(compact(value)), value);
  }
  const announce = section(model, 'private func announceDetection(', 'private func');
  assert.match(announce, /isUrgent \? \.hazard/);
});

test('unvalidated object direction is disabled and physical requests cannot fall through to chat', async () => {
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  assert.match(model, /private static let objectInteractionGuidanceValidated = false/);
  const receive = section(model, 'func receiveCompanionUtterance(', 'private func routeEverydayTask(');
  before(receive, 'routeUnverifiedPhysicalRequest(text)', 'answerConversation(text)');
  const chat = section(model, 'private func answerConversation(', 'func startVoiceQuestion(');
  before(chat, 'routeUnverifiedPhysicalRequest(question)', 'LocalImageAssistant.converse(');
  const tracked = section(model, 'private func updateTrackedTarget()', 'private func');
  assert.match(tracked, /guard Self\.objectInteractionGuidanceValidated else \{ trackedTarget = nil; return \}/);
});
