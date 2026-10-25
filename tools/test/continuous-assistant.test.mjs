// Source integration contracts; executable policies live in BlindCoreTests.
// These checks cannot establish Apple API typing, actual model quality or audio behavior.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
const read = name => readFile(new URL(`../../${name}`, import.meta.url), 'utf8');
const section = (source, from, to) => source.slice(source.indexOf(from), source.indexOf(to, source.indexOf(from) + from.length));

test('ordinary conversation is routed before camera availability', async () => {
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  const receive = section(model, 'func receiveCompanionUtterance', 'private func handleConversationTaskControl');
  assert.match(receive, /fromVoice: Bool = false/);
  assert.match(receive, /!fromVoice \|\| assistantSession.shouldListen/);
  assert.match(receive, /case \.visualRequest = ConversationIntent.classify\(text\)/);
  assert.match(receive, /else \{\s*answerConversation\(text\)/);
  assert.match(receive, /routeSaudiBanknoteCommand\(text\) \|\| routeClothingColorCommand\(text\)/);
  assert.match(receive, /routeFamiliarPeopleCommand\(text\)/);
});

test('unverified speech onset interrupts only ordinary conversation without cancelling capture', async () => {
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  const onset = section(model, 'voice.onSpeechBegan =', 'voice.onFinished =');
  assert.match(onset, /assistantSession.shouldListen/);
  assert.match(onset, /interruptOrdinaryConversation\(origin: \.unverifiedMicrophone\)/);
  assert.doesNotMatch(onset, /cancelDescription\(|stopReturn\(|cancelRoute\(|interruptedSearch\.capture/);
  assert.doesNotMatch(onset, /voice.cancel|includingAlerts: true/);
});

test('streamed phrases are bounded, revalidated, separately admitted and not replayed at final', async () => {
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  const queue = section(model, 'private func queueConversationSpeech', 'private func readCompanionTool');
  assert.match(queue, /conversationSpeech.count < 4/);
  assert.match(queue, /SpatialClaimGuard.containsSpatialClaim/);
  assert.match(queue, /requestID == next.request/);
  assert.match(queue, /assistantSession.accepts\(generation: next.generation\)/);
  assert.match(queue, /createdAt < 30/);
  assert.match(queue, /speakRequested\(next.text, replace: false, speechID: next.id\)/);
  const ready = section(model, 'voice.onReadyForReply =', 'voice.onFinished =');
  assert.match(ready, /assistantSession.shouldListen/);
  assert.match(ready, /drainConversationSpeech\(\)/);
  const reply = section(model, 'private func answerConversation', 'func startVoiceQuestion');
  assert.match(reply, /queueConversationSpeech\(phrase/);
  assert.match(reply, /else if self.streamedConversationText.isEmpty/);
  assert.doesNotMatch(reply, /self.textOnly \|\| self.speakRequested\(text\)/);
});

test('spoken history is recorded only for matching completed requested speech', async () => {
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  const completion = section(model, 'feedback.onRequestedSpeechFinished =', 'feedback.onIdle =');
  for (const value of ['pending.id == id', 'outcome == .completed', 'pending.request == self.requestID', 'accepts(generation: pending.generation)', 'record(role: "assistant", text: text)']) assert.ok(completion.includes(value), value);
});

test('mute and end fence late work and do not disable hazard monitoring', async () => {
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  for (const [from, to, transition] of [['func muteConversation()', 'func endConversation()', 'mute'], ['func endConversation()', 'func reconnectListening()', 'end']]) {
    const body = section(model, from, to);
    assert.match(body, new RegExp(`assistantSession\\.${transition}\\(\\)`));
    assert.match(body, /cancelDescription\(\); voice.cancel\(\)/);
    assert.match(body, /stopInformation\(announceCancellation: false\)/);
    assert.doesNotMatch(body, /stopCameraMonitoring|includingAlerts: true/);
  }
  assert.match(model, /guard !textOnly, assistantSession.shouldListen, !voice.continuous, listenAfterQuestions/);
});

test('background voice is opt-in and cannot imply background camera', async () => {
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  const suspend = section(model, 'func suspendExperience()', 'func startConversation()');
  assert.match(suspend, /assistantSession.enterBackground\(\)/);
  assert.match(suspend, /stopCameraMonitoring\(\)/);
  assert.match(suspend, /if !assistantSession.shouldListen \{ voice.cancel\(\) \}/);
  const info = await read('ios/BlindAssist/Info.plist');
  assert.match(info, /<key>UIBackgroundModes<\/key>\s*<array>\s*<string>audio<\/string>/);
  const view = await read('ios/BlindAssist/DashboardView.swift');
  for (const id of ['mute-conversation', 'end-conversation', 'start-conversation', 'camera-awareness', 'background-conversation', 'camera-status']) assert.ok(view.includes(`"${id}"`), id);
  assert.match(view, /force-quitting ends it/);
});

test('actual local tool registration is bounded and cannot perform actions', async () => {
  const adapter = await read('ios/BlindAssist/LocalImageAssistant.swift');
  assert.match(adapter, /LanguageModelSession\(tools: reduced \? \[\] : tools/);
  assert.match(adapter, /CompanionToolRuntime\(available: availableTools/);
  assert.doesNotMatch(adapter, /eight-year-old/);
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  const tools = section(model, 'private func readCompanionTool', 'private func recordCompanionMessage');
  for (const kind of ['savedMemory', 'navigationState', 'currentObservation']) assert.ok(tools.includes(`case .${kind}:`));
  assert.match(tools, /conversationFrameProbe.inspect\(image: frame.capturedImage/);
  assert.match(tools, /captureObjectView\(frame\)/);
  assert.match(tools, /objectViewIsCurrent\(capture, snapshotPlayback: true\)/);
  assert.match(model, /@MainActor private func readCompanionToolForTurn/);
  assert.match(model, /@MainActor private func readCompanionTool\(/);
  assert.match(tools, /expiresAt: captured.addingTimeInterval\(12\)/);
  assert.doesNotMatch(tools, /session.run|start\(\)|navigate\(|URLSession|saveValue|speakRequested/);
});

test('correction and forgetting scrub both original reports and derived task context', async () => {
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  const edit = section(model, 'func correctConversationRecord', 'func savePreferredName');
  assert.match(edit, /correctUserRecord\(id: id, replacement: replacement\)/);
  assert.match(edit, /forgetUserRecord\(id: id\)/);
  assert.equal((edit.match(/removeReport\(original.text\)/g) ?? []).length, 2);
  assert.equal((edit.match(/cancelDescription\(\)/g) ?? []).length, 2);
  const view = await read('ios/BlindAssist/DashboardView.swift');
  for (const id of ['conversation-memory', 'correct-conversation-record', 'forget-conversation-record', 'forget-conversation']) assert.ok(view.includes(`"${id}"`));
});

test('queued source evidence is revalidated at dispatch and foreground transitions cancel work', async () => {
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  const drain = section(model, 'private func drainConversationSpeech', 'private func readCompanionTool');
  assert.match(drain, /CompanionEvidenceGuard.allows\(next.text, reports: next.reports, evidence: next.evidence, now: Date\(\)\)/);
  assert.match(drain, /next.captures.allSatisfy\(conversationCaptureIsCurrent\)/);
  assert.match(model, /capture.expiresAt.map\(\{ ProcessInfo.processInfo.systemUptime < \$0 \}\)/);
  assert.match(model, /familiarPeople.operationRevision == revision/);
  assert.match(drain, /private func revalidateConversationSpeech/);
  const reply = section(model, 'private func answerConversation', 'func startVoiceQuestion');
  assert.match(reply, /onSpeechCandidate: \{/);
  assert.match(reply, /reports: reports, evidence: evidence/);
  const resume = section(model, 'func resumeExperienceIfNeeded', 'func suspendExperience');
  assert.ok(resume.indexOf('cancelDescription()') < resume.indexOf('assistantSession.enterForeground()'));
});

test('visual history waits for completed narration and explicit tasks commit before inference', async () => {
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  const completion = section(model, 'feedback.onNarrationFinished =', 'feedback.onRequestedSpeechFinished =');
  for (const value of ['pending.id == id', 'outcome == .completed', 'self.requestID == id', 'pending.generation', 'record(role: "assistant", text: text)']) assert.ok(completion.includes(value), value);
  const visual = section(model, 'func readScene', 'private func');
  assert.doesNotMatch(visual, /if !automatic \{ self.assistantDialogue.record\(role: "assistant"/);
  const receive = section(model, 'func receiveCompanionUtterance', 'private func handleConversationTaskControl');
  const authority = receive.indexOf('guard CommandAuthority.permits(.changeGoal, from: origin) else');
  const parsed = receive.indexOf('if let goal = ConversationIntent.explicitTaskGoal(text)');
  const commit = receive.indexOf('companionWorkingState.changeGoal(goal, originalRequest: text)');
  const inference = receive.indexOf('answerConversation(text)');
  assert.ok(authority >= 0 && parsed > authority && commit > parsed && inference > commit,
    'Only an authorized explicit request can commit its original text before inference');
  assert.doesNotMatch(receive.slice(parsed, inference), /originalRequest:\s*goal\b/,
    'Do not relabel a canonical goal as the original user request');
});

test('private audio route removal mutes normal output without an announcement', async () => {
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  const loss = section(model, 'voice.onPrivateRouteLost =', 'voice.onSpeechBegan =');
  assert.match(loss, /assistantSession.losePrivateAudioRoute\(\)/);
  assert.match(model, /guard independentAlert \|\| !assistantSession.privateAudioHeld/);
  assert.match(loss, /cancelDescription\(\)/);
  assert.match(loss, /feedback.stopForPrivateRouteLoss\(\)/);
  assert.ok(loss.indexOf('assistantSession.losePrivateAudioRoute()') < loss.indexOf('feedback.stopForPrivateRouteLoss()'));
  assert.doesNotMatch(loss, /speakOperation|speakRequested|stopCameraMonitoring/);
});

test('physical inspection cannot fall through to free-form streamed answers', async () => {
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  const cash = section(model, 'func routeSaudiBanknoteCommand', 'func routeClothingColorCommand');
  assert.match(cash, /ConversationDomainPolicy.requiredInspection\(for: text\) == \.banknote/);
  assert.doesNotMatch(cash, /SaudiBanknoteCommand.matches/);
  const reply = section(model, 'private func answerConversation', 'func startVoiceQuestion');
  assert.equal((reply.match(/ConversationDomainPolicy.allowsModelResponse\(to: question\)/g) ?? []).length, 3);
  assert.ok(reply.indexOf('allowsModelResponse') < reply.indexOf('LocalImageAssistant.converse'));
});


test('audience is an explicit local preference and changing it invalidates a turn', async () => {
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  const preference = section(model, '@Published var assistantAudience', '    private var');
  assert.match(preference, /AssistantAudience\(persistedValue:\s*UserDefaults/);
  assert.match(preference, /\?\? AssistantAudience.childWithGuardian.rawValue/);
  assert.match(preference, /assistantSession.invalidate\(\); cancelDescription\(\)/);
  assert.match(model, /audience: self.assistantAudience/);
  const view = await read('ios/BlindAssist/DashboardView.swift');
  assert.match(view, /accessibilityIdentifier\("assistant-audience"\)/);
  assert.match(view, /AssistantAudience.childWithGuardian/);
});


test('context overflow retry cannot repeat tools or already emitted speech', async () => {
  const adapter = await read('ios/BlindAssist/LocalImageAssistant.swift');
  assert.match(adapter, /case \.exceededContextWindowSize/);
  assert.match(adapter, /#if BLIND_FOUNDATION_MODELS_V2 \|\| BLIND_APPLE_MULTIMODAL/);
  assert.match(adapter, /case \.contextSizeExceeded/);
  assert.match(adapter, /recovery.onOverflow\(emittedText: chunks.delivered, cancelled: Task.isCancelled\)/);
  assert.match(adapter, /case \.preservePartial:/);
  assert.match(adapter, /LanguageModelSession\(tools: reduced \? \[\] : tools/);
  assert.match(adapter, /instructions: instructions/);
  assert.doesNotMatch(adapter, /error.localizedDescription.contains/);
});
