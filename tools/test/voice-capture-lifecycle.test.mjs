// Source contracts only. Runtime audio, Apple SDK compilation, route changes,
// VoiceOver echo and background endurance still require Xcode/physical devices.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
const voice = await readFile(new URL('../../ios/BlindAssist/VoiceInput.swift', import.meta.url), 'utf8');
const policy = await readFile(new URL('../../BlindCore/Sources/BlindCore/VoiceCaptureRecoveryPolicy.swift', import.meta.url), 'utf8');
function between(source, start, end) {
  const from = source.indexOf(start);
  assert.notEqual(from, -1, start);
  const to = source.indexOf(end, from + start.length);
  assert.notEqual(to, -1, end);
  return source.slice(from, to);
}

test('voice keeps required local recognition and stopped-engine echo cancellation', () => {
  assert.match(voice, /recognizer\.supportsOnDeviceRecognition/);
  assert.match(voice, /request\.requiresOnDeviceRecognition = true/);
  const capture = between(voice, 'private func capture(', 'private func beginTurn(');
  assert.ok(capture.indexOf('setVoiceProcessingEnabled(true)') < capture.indexOf('engine.start()'));
  assert.doesNotMatch(voice, /URLSession|URLRequest|AVAudioFile|write\(to:|uploadTask/);
});

test('onset uses non-echo partial evidence and revalidates after its callback', () => {
  const recognition = between(voice, 'recognition = recognizer?.recognitionTask', 'let duration = continuous');
  assert.ok(recognition.indexOf('shouldIgnore?(text)') < recognition.indexOf('self.onSpeechBegan?()'));
  assert.ok(recognition.indexOf('self.onSpeechBegan?()') < recognition.indexOf('if result.isFinal'));
  assert.match(recognition, /onSpeechBegan\?\(\)[\s\S]*?guard self\.accepts\(session: session, turn: id\) else \{ return \}/);
  assert.match(voice, /not semantic VAD or speaker identity/);
  assert.match(policy, /wasRejected = ignored && next == text/);
});

test('permission, request callbacks and timers reject superseded capture sessions', () => {
  const begin = between(voice, 'private func begin(arabic:', 'private func permissionUnavailable');
  assert.equal((begin.match(/self\.lifecycle\.session == session, self\.canCapture/g) ?? []).length, 2);
  const turn = between(voice, 'private func beginTurn(', 'func finish()');
  assert.ok((turn.match(/accepts\(session: session, turn: id\)/g) ?? []).length >= 4);
  const capture = between(voice, 'private func capture(', 'private func beginTurn(');
  assert.match(capture, /SFSpeechRecognizer\.authorizationStatus\(\) == \.authorized/);
  assert.match(capture, /recordPermission == \.granted/);
});

test('explicit opt-in gates background audio and mute invalidates retry tokens', () => {
  assert.match(voice, /private var backgroundAllowed = false/);
  assert.match(voice, /func setBackgroundAllowed\(_ allowed: Bool\)/);
  const background = between(voice, 'observe(UIApplication.didEnterBackgroundNotification)', '\n    deinit');
  assert.match(background, /!self\.backgroundAllowed/);
  assert.match(background, /self\.cancel\(\)/);
  assert.doesNotMatch(voice, /observe\(UIApplication\.(didBecomeActive|willEnterForeground)Notification/);
  const cancel = between(policy, 'public mutating func cancel()', 'public func allowsCapture');
  assert.match(cancel, /session = UUID\(\)/);
  assert.match(cancel, /requested = false; continuous = false/);
  assert.match(cancel, /pendingRetry = nil/);
  assert.match(policy, /\(!inBackground \|\| backgroundAllowed\)/);
});

test('interruption, media reset and route changes preserve cancellation boundaries', () => {
  for (const notification of ['interruptionNotification', 'mediaServicesWereLostNotification',
    'mediaServicesWereResetNotification', 'routeChangeNotification', 'AVAudioEngineConfigurationChange']) {
    assert.ok(voice.includes(notification), notification);
  }
  assert.match(voice, /InterruptionOptions\(rawValue: rawOptions\)\.contains\(\.shouldResume\)/);
  assert.match(voice, /reason != \.categoryChange, reason != \.unknown/);
  assert.match(voice, /changed === current/);
  assert.match(voice, /if state == \.recovering, recovery != nil \{ return \}/);
  assert.match(policy, /requested && self\.session == session && !interrupted && mediaServicesAvailable/);
});

test('recovery is bounded, claimed once and never reset by each transcript partial', () => {
  assert.match(policy, /guard attempts < 3 else \{ cancel\(\); return nil \}/);
  assert.match(policy, /now - healthySince >= 30/);
  assert.match(policy, /retry\.token == pendingRetry/);
  assert.match(voice, /self\.lifecycle\.claim\(retry/);
  assert.match(voice, /if announce, lifecycle\.attempts == 1/);
  const recognition = between(voice, 'recognition = recognizer?.recognitionTask', 'let duration = continuous');
  assert.doesNotMatch(recognition, /attempts = 0|captureStarted/);
});

test('capture health checks missing buffers rather than claiming acoustic speech detection', () => {
  assert.match(voice, /systemUptime - self\.input\.lastBufferTime/);
  assert.match(voice, /age > 8/);
  assert.match(voice, /if buffer\.frameLength > 0/);
  assert.match(voice, /Text inactivity is a fallback endpoint heuristic, NOT acoustic silence/);
  assert.match(voice, /continuous \? 50/);
  assert.match(voice, /RunLoop\.main\.add\(timer, forMode: \.common\)/);
});

test('stop clears stale hypotheses and only removes a tap that was installed', () => {
  const stop = between(voice, 'private func stopCapture()', 'private func recover(');
  assert.match(stop, /turn = UUID\(\)/);
  assert.match(stop, /input\.replace\(with: nil\)/);
  assert.match(stop, /if tapInstalled \{ engine\?\.inputNode\.removeTap/);
  assert.match(stop, /utterance = VoiceUtteranceTracker\(\); transcript = ""; listening = false/);
  const finish = between(voice, 'func finish()', 'func endManualTurn()');
  assert.match(finish, /guard lifecycle\.requested, canCapture else \{ return \}/);
  assert.match(finish, /utterance\.deliverable\(isEcho: shouldIgnore\?/);
});


test('private route removal cancels before synchronous main-actor notification and cannot auto-recover', () => {
  const route = between(voice, 'observe(AVAudioSession.routeChangeNotification)', 'observe(.AVAudioEngineConfigurationChange)');
  const removal = between(route, 'if reason == .oldDeviceUnavailable', 'guard self.lifecycle.requested, self.canCapture');
  assert.match(voice, /var onPrivateRouteLost: \(@MainActor \(\) -> Void\)\?/);
  assert.match(removal, /self\.lifecycle\.privateRouteLost\(\)/);
  assert.match(removal, /self\.cancelRecovery\(\); self\.stopCapture\(\)/);
  assert.ok(removal.indexOf('self.stopCapture()') < removal.indexOf('MainActor.assumeIsolated'));
  assert.match(removal, /if let callback = self\.onPrivateRouteLost \{ callback\(\) \}/);
  assert.match(removal, /return/);
  assert.doesNotMatch(removal, /recover\(|onUnavailable|DispatchQueue\.main\.async|Task \{/);
  assert.match(policy, /public mutating func privateRouteLost\(\) \{ cancel\(\) \}/);
  assert.match(route, /self\.recover\(message:/, 'other eligible route changes still rebuild');
});


test('energy onset is bounded, synchronous on PCM and fenced across capture and turn renewal', () => {
  const tap = between(voice, 'func append(_ buffer: AVAudioPCMBuffer)', 'private func drainAcousticUpdate()');
  assert.match(tap, /buffer\.floatChannelData\?\[0\]/);
  assert.match(tap, /detector\.process\(samples: samples/);
  assert.match(tap, /if began \|\| wasActive != detector\.isActive/);
  assert.match(tap, /scheduleDrain = mailbox\.offer/);
  assert.match(tap, /if scheduleDrain \{\s*DispatchQueue\.main\.async \{ \[weak self\] in self\?\.drainAcousticUpdate\(\) \}/);
  const capture = between(voice, 'sink.beginCapture(captureID)', 'engine.inputNode.installTap');
  assert.match(capture, /self\.captureGeneration == update\.capture/);
  assert.match(capture, /accepts\(session: sessionID, turn: update\.turn\)/);
  assert.match(capture, /systemUptime - onsetAt <= 0\.75/);
  assert.match(capture, /!self\.speechBeganDelivered/);
  assert.match(capture, /let wasActive = self.acousticSpeechActive/);
  assert.match(capture, /if wasActive && !self.acousticSpeechActive && !self.awaitingUtterance/);
  assert.match(capture, /self.onReadyForReply\?\(\)/);
  const renewal = between(voice, 'private func beginTurn(', 'recognition = recognizer?.recognitionTask');
  assert.match(renewal, /acousticSpeechActive = input\.replace\(with: request, turn: id\)/);
  assert.doesNotMatch(renewal, /beginCapture|AcousticSpeechOnset\(/);
  const stop = between(voice, 'private func stopCapture()', 'private func recover(');
  assert.match(stop, /captureGeneration = UUID\(\)/);
  assert.match(stop, /input\.cancelCapture\(\)/);
});
