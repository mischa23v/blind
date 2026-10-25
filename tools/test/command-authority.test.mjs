// Source contracts only. XCTest policy execution and Apple/device microphone,
// navigation, concurrent-model, and audible-hazard acceptance remain separate.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const read = path => readFileSync(new URL(`../../${path}`, import.meta.url), 'utf8');
const model = read('ios/BlindAssist/NavigationModel.swift');
const policy = read('BlindCore/Sources/BlindCore/CommandAuthority.swift');
function declaration(source, signature) {
  const start = source.indexOf(signature);
  assert.ok(start >= 0, signature);
  const first = source.indexOf('{', start);
  let depth = 0;
  for (let i = first; i < source.length; i++) {
    if (source[i] === '{') depth++;
    if (source[i] === '}' && --depth === 0) return source.slice(start, i + 1);
  }
  assert.fail(`Unclosed declaration: ${signature}`);
}
const body = signature => declaration(model, signature);

test('policy grants microphone only conversation and ordinary interruption, not guessed speaker authority', () => {
  assert.match(policy, /case \.unverifiedMicrophone:\s*return effect == \.conversation \|\| effect == \.interruptOrdinarySpeech/);
  assert.match(policy, /case \.modelOutput, \.observedContent, \.unknown:\s*return false/);
  assert.match(policy, /case \.trustedInterface:\s*return true/);
  const origins = declaration(policy, 'public enum CompanionCommandOrigin:');
  assert.doesNotMatch(origins, /case .*verifiedSpeaker|case .*guardian|case .*familiar/i);
  for (const effect of ['changeGoal', 'cancelTaskOrNavigation', 'startReturn', 'changeMonitoring', 'requestPhysicalGuidance', 'commitUserReport']) {
    assert.match(policy, new RegExp(`case ${effect}\\b`));
  }
});

test('every microphone final fails closed before scan, goal, calibration, offer and action dispatch', () => {
  assert.match(body('voice.onFinished ='), /receiveCompanionUtterance\(text, fromVoice: true\)/);
  const receive = body('func receiveCompanionUtterance(');
  assert.match(receive, /let origin: CompanionCommandOrigin = fromVoice \? \.unverifiedMicrophone : \.trustedInterface/);
  const gate = 'guard CommandAuthority.permits(.changeGoal, from: origin) else';
  assert.match(receive, /receiveUnverifiedConversation\(text, origin: origin\)\s*return/);
  for (const action of ['routeVoiceRoomScan(text)', 'calibrate()', 'handleConversationTaskControl(control)', 'changeGoal(destination)', 'answerCompanionOffer(answer)', 'routeEverydayTask(text)', 'answerConversation(text)']) {
    assert.ok(receive.indexOf(gate) >= 0 && receive.indexOf(gate) < receive.indexOf(action), action);
  }
});

test('acoustic onset cannot cancel routes, searches, monitoring, confirmations or shared request identity', () => {
  const onset = body('voice.onSpeechBegan =');
  assert.match(onset, /interruptOrdinaryConversation\(origin: \.unverifiedMicrophone\)/);
  assert.doesNotMatch(onset, /cancelDescription\(|stopReturn\(|cancelRoute\(|interruptedSearch\.capture|calibrate\(|voiceRoomScan\.cancel/);
  const interrupt = body('private func interruptOrdinaryConversation(');
  assert.match(interrupt, /if questionIsChat/);
  assert.match(interrupt, /questionTask\?\.cancel\(\)/);
  assert.match(interrupt, /feedback.stopRequestedSpeech\(active.id\)/);
  assert.doesNotMatch(interrupt, /cancelDescription\(|stopReturn\(|cancelRoute\(|objectSearch|everydayTasks|voiceRoomScan|requestID\s*=|perceptionGeneration\s*=|stopCameraMonitoring|includingAlerts|feedback.stop\(/);
});

test('unverified chat cannot call command adapters, inherit a trusted goal, write user records or apply model task updates', () => {
  const chat = body('private func receiveUnverifiedConversation(');
  assert.match(chat, /origin == \.unverifiedMicrophone/);
  assert.match(chat, /availableTools: \[\], toolExecutor: nil/);
  assert.match(chat, /let dialogue = unverifiedDialogue/);
  assert.match(chat, /guard !busy else/);
  assert.match(chat, /ConversationDomainPolicy.allowsModelResponse\(to: text\)/);
  assert.match(chat, /SpatialClaimGuard.containsSpatialClaim\(reply\)/);
  assert.match(chat, /CompanionEvidenceGuard.allows\(reply/);
  assert.doesNotMatch(chat, /answer\.taskUpdate|\.apply\(|recordCompanionMessage\(|persistDialogue\(|persistWorkingState\(|assistantDialogue\.record|companionWorkingState\.|readScene\(|routeEverydayTask\(|routeVoiceRoomScan\(|calibrate\(|startReturn\(|stopReturn\(|indoor\.|modelContext:/);
});

test('unverified output cannot be laundered into persistent reports or action-progress receipts', () => {
  const completion = body('feedback.onRequestedSpeechFinished =');
  const gate = completion.indexOf('if pending.origin == .unverifiedMicrophone');
  const durable = completion.indexOf('self.assistantDialogue.record(role: "assistant", text: text)');
  assert.ok(gate >= 0 && durable > gate);
  const isolated = completion.slice(gate, durable);
  assert.match(isolated, /unverifiedDialogue.record\(role: "assistant", text: text\)/);
  assert.match(isolated, /return/);
  assert.match(body('private func queueConversationSpeech('), /origin: origin/);
  assert.match(body('private func unverifiedConversationReply('), /origin: \.unverifiedMicrophone/);
});

test('unverified reply callbacks expire on session, request, cancellation and the independent turn lease', () => {
  const chat = body('private func receiveUnverifiedConversation(');
  for (const token of ['!Task.isCancelled', 'self.unverifiedConversationID == id', 'accepts(generation: generation)', 'self.assistantSession.shouldListen', 'self.requestID == request']) {
    assert.ok(chat.includes(token), token);
  }
  assert.match(chat, /Task.sleep\(for: \.seconds\(30\)\)/);
  const cancel = body('private func cancelDescription(');
  assert.match(cancel, /unverifiedConversationID = UUID\(\)/);
  assert.match(cancel, /unverifiedConversationTask\?\.cancel\(\)/);
  assert.match(cancel, /unverifiedConversationTimeout\?\.cancel\(\)/);
});

test('clear conversation removes transient microphone history before another same-session turn', () => {
  const clear = body('func clearAssistantConversation(');
  assert.match(clear, /cancelDescription\(\)/);
  assert.match(clear, /unverifiedDialogue = AssistantDialogue\(\); unverifiedDialogueGeneration = nil/);
  const chat = body('private func receiveUnverifiedConversation(');
  assert.match(chat, /unverifiedDialogueGeneration != assistantSession.generation/);
  assert.doesNotMatch(chat, /situation:/, 'the existing converse implementation ignores situation; do not imply that it enforces authority');
});

test('quiet speech is limited to the reply and independent valid hazard dispatch ignores command trust', () => {
  const chat = body('private func receiveUnverifiedConversation(');
  const quiet = chat.slice(chat.indexOf('if AssistantControl.parse(text) == .quiet'), chat.indexOf('let intent ='));
  assert.doesNotMatch(quiet, /stopDescriptions\(|stopReturn\(|cancelRoute\(|ambientDescriptions\s*=|cameraAwareness\s*=|muteConversation\(|endConversation\(/);
  assert.match(quiet, /Hazard alerts are unchanged/);
  const publish = body('private func publish(');
  assert.match(publish, /policy.shouldAnnounce\(detection, at: now\)/);
  assert.match(publish, /announceDetection\(detection\)/);
  assert.doesNotMatch(publish, /CommandAuthority|unverifiedDialogue|unverifiedConversation|ambientDescriptions/);
});

test('trusted UI actions retain their existing independent controls and physical evidence gates', () => {
  assert.match(body('func setAssistantObjective('), /assistantDialogue.setGoal\(objectiveDraft\)/);
  assert.match(body('func startReturn('), /observation.trackingNormal/);
  assert.match(body('func startReturn('), /lastFrameWallTime < 0.5/);
  assert.match(body('func muteConversation('), /assistantSession.mute\(\)/);
  assert.match(body('func endConversation('), /assistantSession.end\(\)/);
  assert.match(body('private func routeUnverifiedPhysicalRequest('), /ConversationDomainPolicy.requiresPhysicalVerification/);
});
