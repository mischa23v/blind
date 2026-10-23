import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

// Source contracts only. These complement the executable portable ledger tests;
// they do not establish Apple SDK compilation, real speech, or VoiceOver behavior.
const feedback = readFileSync(new URL('../../ios/BlindAssist/Feedback.swift', import.meta.url), 'utf8');
const navigation = readFileSync(new URL('../../ios/BlindAssist/NavigationModel.swift', import.meta.url), 'utf8');

function bodyAfter(source, marker) {
  const start = source.indexOf(marker);
  assert.notEqual(start, -1, `Missing source contract: ${marker}`);
  const open = source.indexOf('{', start);
  let depth = 1;
  for (let i = open + 1; i < source.length; i += 1) {
    if (source[i] === '{') depth += 1;
    if (source[i] === '}' && --depth === 0) return source.slice(open + 1, i);
  }
  assert.fail(`Unclosed source contract: ${marker}`);
}

test('source contract: requested speech stays behind AdmittedSpeech and has its own completion ID', () => {
  assert.match(feedback, /func deliver\(_ admitted: AdmittedSpeech, narrationID: UUID\? = nil,\s*speechID: UUID\? = nil/);
  assert.match(feedback, /var onRequestedSpeechFinished: \(\(UUID, String, NarrationDelivery\) -> Void\)\?/);
  assert.match(feedback, /case \.requested\(let id\): self\.onRequestedSpeechFinished\?\(id, completion\.attempt\.text, completion\.outcome\)/);
  assert.doesNotMatch(feedback, /func (?:speak|deliver)\(_ text: String/);
});

test('source contract: requested transport policy is used and synthesis preserves assistive settings', () => {
  const speak = bodyAfter(feedback, 'private func speak(');
  assert.match(speak, /SpeechDeliveryLedger\.transport\(for: destination, priority: priority/);
  assert.match(speak, /transport: transport/);
  assert.match(speak, /voiceOverRunning: UIAccessibility.isVoiceOverRunning, independentAlert: independentAlert/);
  assert.match(speak, /transport: transport, independentAlert: independentAlert/);
  assert.match(speak, /if transport == \.accessibility/);
  assert.match(speak, /utterance\.prefersAssistiveTechnologySettings = true/);
  assert.equal((feedback.match(/speech\.speak\(/g) ?? []).length, 1);
});

test('source contract: private-route loss interrupts private mobility without silencing independent sensor alerts', () => {
  const dispatch = bodyAfter(navigation, 'private func deliverCandidate(');
  assert.match(dispatch, /let independentAlert = alert != nil && \(candidate.kind == \.hazard \|\| candidate.kind == \.mobility\)/);
  assert.match(dispatch, /feedback.deliver\(admitted,[\s\S]*independentAlert: independentAlert/);
  const deliver = bodyAfter(feedback, 'func deliver(');
  assert.match(deliver, /independentAlert && alert != nil/);
  assert.match(deliver, /admitted.priority == \.mobility \|\| admitted.urgent/);
  assert.match(deliver, /independentAlert: verifiedIndependentAlert/);
  const loss = bodyAfter(navigation, 'voice.onPrivateRouteLost = ');
  assert.match(loss, /feedback.stopForPrivateRouteLoss\(\)/);
  assert.doesNotMatch(loss, /stopInformation\(|speakOperation|speakRequested/);
  const stop = bodyAfter(feedback, 'func stopForPrivateRouteLoss()');
  assert.match(stop, /guard !delivery.mayContinueAfterPrivateRouteLoss else \{ return \}/);
  assert.match(stop, /finishActive\(outcome: \.interrupted, stopSynthesizer: true, notify: false\)/);
  assert.match(stop, /speech.stopSpeaking\(at: \.immediate\)/);
  assert.doesNotMatch(stop, /requestCancellationAnnouncement|urgentUntil|player.stop|priority != \.mobility/);
});

test('source contract: onset, mute and end cancel queued work and stop requested audio', () => {
  for (const marker of ['voice.onSpeechBegan = ', 'func muteConversation()', 'func endConversation()']) {
    const body = bodyAfter(navigation, marker);
    assert.match(body, /cancelDescription\(\)/, marker);
    assert.match(body, /feedback\.stopInformation\(announceCancellation: false\)/, marker);
  }
  const stop = bodyAfter(feedback, 'func stopInformation(');
  assert.match(stop, /delivery\.active\?\.priority != \.mobility/);
  assert.match(stop, /delivery\.active\?\.priority != \.danger/);
  assert.match(stop, /finishActive\(outcome: \.interrupted, stopSynthesizer: true\)/);
  assert.match(stop, /speech\.stopSpeaking\(at: \.immediate\)/);
});

test('source contract: cancellation invalidates identity before platform stop and timeout cannot claim completion', () => {
  const finish = bodyAfter(feedback, 'private func finishActive(');
  assert.ok(finish.indexOf('currentUtterance = nil') < finish.indexOf('speech.stopSpeaking'));
  assert.match(feedback, /guard utterance === currentUtterance, delivery\.active\?\.transport == \.synthesized/);
  const timeout = bodyAfter(feedback, 'private func armOutputTimeout(');
  assert.match(timeout, /delivery\.active\?\.token == token/);
  assert.match(timeout, /finishActive\(outcome: \.unknown, stopSynthesizer: true\)/);
  assert.doesNotMatch(timeout, /\.completed/);
});

test('source contract: spatial playback never downgrades the recording audio session', () => {
  const setup = bodyAfter(feedback, 'func configureSpatialAudio()');
  const categoryChange = bodyAfter(setup, 'if audio.category != .playAndRecord');
  assert.match(categoryChange, /audio\.setCategory\(\.playback/);
  assert.equal((feedback.match(/audio\.setCategory\(/g) ?? []).length, 1);
});
