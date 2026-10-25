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
  const final = body('voice.onFinished =');
  assert.match(final, /guard let self, self.voice.consumeDelivery\(turn\) else/);
  assert.match(final, /receiveCompanionUtterance\(turn.text, fromVoice: true\)/);
  assert.ok(final.indexOf('consumeDelivery(') < final.indexOf('receiveCompanionUtterance('));
  const receive = body('func receiveCompanionUtterance(');
  assert.match(receive, /let origin: CompanionCommandOrigin = fromVoice \? \.unverifiedMicrophone : \.trustedInterface/);
  const gate = 'guard CommandAuthority.permits(.changeGoal, from: origin) else';
  assert.match(receive, /receiveUnverifiedConversation\(text, origin: origin\)\s*return/);
  const gateIndex = receive.indexOf(gate);
  assert.ok(gateIndex >= 0, 'Command-authority gate must be present');
  for (const action of ['routeVoiceRoomScan(text)', 'calibrate()', 'handleConversationTaskControl(control)', 'companionWorkingState.changeGoal(destination, originalRequest: text, sourceID: source.sourceID, at: source.time)', 'companionWorkingState.changeGoal(goal, originalRequest: text, sourceID: source.sourceID, at: source.time)', 'answerCompanionOffer(answer)', 'routeEverydayTask(text)', 'answerConversation(text)']) {
    const actionIndex = receive.indexOf(action);
    assert.ok(actionIndex >= 0 && gateIndex < actionIndex, action);
  }
});

test('trusted goal mutation keeps canonical labels distinct from the original user request', () => {
  const receive = body('func receiveCompanionUtterance(');
  for (const [parser, label] of [['AssistantControl.explicitGoal(text)', 'destination'], ['ConversationIntent.explicitTaskGoal(text)', 'goal']]) {
    const branch = declaration(receive, `if let ${label} = ${parser}`);
    assert.ok(branch.includes(`companionWorkingState.changeGoal(${label}, originalRequest: text, sourceID: source.sourceID, at: source.time)`), label);
    const source = branch.indexOf('guard let source = recordCompanionMessage(text) else { return }');
    assert.ok(source >= 0 && source < branch.indexOf('companionWorkingState.changeGoal('), 'Bind the exact source and original capture time before changing the goal');
    assert.doesNotMatch(branch, /originalRequest:\s*(?:destination|goal)\b/, 'A parsed label is not a user quote');
    assert.ok(branch.indexOf('changeGoal(') < branch.indexOf('persistWorkingState()'), 'Persist the exact bound request with the goal');
  }
  const local = read('ios/BlindAssist/LocalImageAssistant.swift');
  const change = declaration(local, 'mutating func changeGoal(');
  assert.match(change, /originalRequest\.flatMap/);
  assert.match(change, /CompanionTaskSource\(originalRequest: \$0, canonicalLabel: value,/);
  assert.match(change, /goal = value; goalSource = source;/);
  assert.doesNotMatch(change, /CompanionTaskSource\(originalRequest: value/);
  const source = read('BlindCore/Sources/BlindCore/CompanionTaskSource.swift');
  const note = declaration(source, 'public var memoryNote:');
  assert.match(note, /subject: canonicalLabel, text: originalRequest/);
  assert.doesNotMatch(note, /text: canonicalLabel/);
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
  assert.match(chat, /let dialogue = VoiceConversationPrivacy.anonymousTurn\(text\)/);
  assert.doesNotMatch(model, /unverifiedDialogue/);
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
  assert.doesNotMatch(isolated, /\.record\(/);
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

test('anonymous conversation has explicit current-turn isolation and clear cancels pending output', () => {
  const clear = body('func clearAssistantConversation(');
  assert.match(clear, /cancelDescription\(\)/);
  assert.doesNotMatch(model, /unverifiedDialogue/);
  const chat = body('private func receiveUnverifiedConversation(');
  assert.match(chat, /VoiceConversationPrivacy.anonymousTurn\(text\)/);
  const privacy = declaration(read('BlindCore/Sources/BlindCore/VoiceAuthority.swift'), 'public static func anonymousTurn(');
  assert.match(privacy, /var dialogue = AssistantDialogue\(\)/);
  assert.match(privacy, /dialogue.record\(role: "user", text: text\)/);
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
  const start = body('func startReturn('), sink = body('private func spatialRouteOutputAllowed(');
  assert.match(start, /requestReturn\(origin: \.trustedInterface/);
  assert.doesNotMatch(start, /returnTrail\.begin|journeys\.current/);
  assert.match(sink, /observation\.trackingNormal/);
  assert.match(sink, /lastFrameWallTime < 0.5/);
  assert.match(sink, /\$0\.permits\(ticket, now: now\)/);
  assert.match(body('private func routeConnectedJourneyCommand('), /CommandAuthority\.permits\(\.changeGoal, from: origin\)/);
  assert.match(body('func muteConversation('), /assistantSession.mute\(\)/);
  assert.match(body('func endConversation('), /assistantSession.end\(\)/);
  assert.match(body('private func routeUnverifiedPhysicalRequest('), /ConversationDomainPolicy.requiresPhysicalVerification/);
});


test('microphone cannot clear the selected photo before the command gate', () => {
  const receive = body('func receiveCompanionUtterance(');
  assert.match(receive, /if CommandAuthority.permits\(\.changeGoal, from: origin\), selectedPhoto.selection != nil \{ clearExploreSnapshot\(\) \}/);
});

test('native microphone provenance is exact and one-use without speaker elevation', () => {
  const voice = read('ios/BlindAssist/VoiceInput.swift');
  const consume = declaration(voice, 'func consumeDelivery(');
  assert.match(consume, /guard activeDelivery == turn else/);
  assert.match(consume, /activeDelivery = nil/);
  const finish = declaration(voice, 'func finish(');
  assert.ok(finish.indexOf('CapturedVoiceTurn(') < finish.indexOf('beginTurn()'));
  assert.match(finish, /activeDelivery = completed/);
  assert.match(finish, /defer \{ activeDelivery = nil \}/);
  const contract = read('BlindCore/Sources/BlindCore/VoiceAuthority.swift');
  assert.match(contract, /var origin: CompanionCommandOrigin \{ \.unverifiedMicrophone \}/);
  assert.match(contract, /permitsPrivateContext\(evidence: VoiceEvidence\) -> Bool \{ false \}/);
});
