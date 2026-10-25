import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const root = new URL('../../', import.meta.url);
const read = name => readFileSync(new URL(`ios/BlindAssist/${name}.swift`, root), 'utf8');
const nav = read('NavigationModel');
const model = read('LocalImageAssistant');
const voice = read('VoiceInput');
const feedback = read('Feedback');
const familiar = read('FamiliarFaceExperiment');
const journey = read('JourneyStore');
const mapping = read('NativeMapping');
const indoor = read('IndoorNavigator');
const section = (source, a, b) => source.slice(source.indexOf(a), source.indexOf(b, source.indexOf(a)));

// Skip default-argument closures before balancing the complete method body.
function method(source, signature) {
  const start=source.indexOf(signature); assert.ok(start>=0,signature);
  const parameters=source.indexOf('(',start); let depth=0, end=-1;
  for(let i=parameters;i<source.length;i++) {
    if(source[i]==='(') depth++;
    if(source[i]===')' && --depth===0) { end=i; break; }
  }
  assert.ok(end>parameters,`Unclosed parameters: ${signature}`);
  const open=source.indexOf('{',end); depth=0;
  for(let i=open;i<source.length;i++) {
    if(source[i]==='{') depth++;
    if(source[i]==='}' && --depth===0) return source.slice(open+1,i);
  }
  assert.fail(`Unclosed method: ${signature}`);
}

// Source contracts only. These DO NOT execute Apple callbacks or compile Swift.
test('native debug integration: every recorder symbol is positively DEBUG guarded', () => {
  for (const [name, source] of Object.entries({ nav, model, voice, feedback, familiar, journey, mapping, indoor })) {
    const conditions = [];
    for (const [index, line] of source.split('\n').entries()) {
      const text = line.trim();
      if (text.startsWith('#if ')) conditions.push(text.slice(4));
      if (text === '#else') conditions[conditions.length - 1] = `!(${conditions.at(-1)})`;
      if (text.startsWith('#elseif ')) conditions[conditions.length - 1] = text.slice(8);
      if (/\b(?:DebugNativeSessionTrace|DebugSessionLog|debugTrace|purgeDebugSessionDiagnostics|debugPurgePending)\b/.test(text) && !text.startsWith('//')) {
        assert.ok(conditions.includes('DEBUG'), `${name}:${index + 1}: ${text}`);
      }
      if (text === '#endif') conditions.pop();
    }
    assert.equal(conditions.length, 0, `${name}: balanced compile conditions`);
  }
});

test('native debug integration: trace captures session once and forwards lazy payload', () => {
  const trace = model.slice(model.indexOf('struct DebugNativeSessionTrace'));
  assert.match(trace, /guard let log = recorder else \{ return nil \}/);
  assert.match(trace, /self\.token = log\.sessionToken/);
  assert.match(trace, /session: token/);
  assert.match(trace, /detail: detail/);
  assert.doesNotMatch(trace, /URLSession|CVPixelBuffer|AVAudio|UIImage|FileManager|Data\(contentsOf/);
});

test('native debug integration: controller preserves input origin and command authority decisions', () => {
  assert.match(nav, /source: fromVoice \? \.unverifiedMicrophone : \.userTyped/);
  assert.match(nav, /controller\.inputRejected\.emptyOversizeOrNotListening/);
  assert.match(nav, /commandAuthority\.changeGoal\.rejected\.unverifiedMicrophone/);
  assert.match(nav, /commandAuthority\.changeGoal\.accepted\.trustedInterface/);
});

test('native debug integration: ASR final text is logged before turn rotation with no new audio access', () => {
  const finish = section(voice, '    func finish()', '    /// Scene operations');
  assert.ok(finish.indexOf('debugTrace?.event') < finish.indexOf('beginTurn()'));
  assert.match(finish, /deliverableUnverified/);
  assert.match(finish, /notDeliverable/);
  assert.doesNotMatch(finish, /capturedImage|floatChannelData|JSONEncoder|sampleBuffer/);
});

test('native debug integration: request IDs are passed from real owners; missing IDs remain optional', () => {
  assert.match(model, /requestID: UUID\? = nil/);
  assert.match(nav, /availableTools: \[\], toolExecutor: nil, requestID: id/);
  assert.match(nav, /\}, requestID: id, onSpeechCandidate:/);
  assert.match(nav, /modelContext: modelContext, requestID: currentRequest/);
  assert.match(nav, /modelContext: modelContext, requestID: request\)/);
});

test('native debug integration: actual prompts and context keys are logged, unavailable record IDs stay unbound', () => {
  assert.match(model, /text: instructions, label: scope \+ "\.instructions"/);
  assert.match(model, /text: plan\.prompt, label: scope \+ "\.actualPrompt"/);
  assert.match(model, /plan\.context\.keys\.sorted\(\)/);
  assert.match(model, /underlyingRecordIDs=unbound/);
  for (const scope of ['conversation.reducedRetry', 'bookkeeping', 'spot.imageOmitted', 'describe.imageOmitted']) assert.ok(model.includes(scope));
});

test('native debug integration: tool return log reuses actual returned JSON without running tools twice', () => {
  const tool = section(model, 'private struct ReadLocalEvidence', '/// Thin adapter');
  assert.equal((tool.match(/runtime\.run\(/g) || []).length, 1);
  assert.equal((tool.match(/JSONEncoder\(\)\.encode\(result\)/g) || []).length, 1);
  assert.match(tool, /\.init\(text: payload, label: "readLocalEvidence\.returnedJSON; SDKCallID=unbound"\)/);
  assert.match(tool, /return payload/);
  assert.doesNotMatch(tool, /toolCallID: UUID\(/);
});

test('native debug integration: raw output, final safety gate and callback failure are separate', () => {
  for (const label of ['cumulativeUnvalidatedSnapshot', 'finalTrimmedUnvalidatedText', 'conversation.finalGuard.rejected', 'conversation.finalGuard.accepted', 'conversation.cancelled', 'conversation.contextBudgetError']) assert.ok(model.includes(label));
  assert.match(nav, /conversationSpeech\.captureBindingMissing/);
  assert.match(nav, /conversationSpeech\.deliveryRevalidationOrSink\.rejected/);
  assert.match(nav, /conversationSpeech\.activeCaptureInvalidated/);
});

test('native debug integration: synthesized start comes only from matching native didStart', () => {
  const start = section(feedback, '    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart', '    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish');
  assert.match(start, /utterance === currentUtterance/);
  assert.match(start, /active\.transport == \.synthesized/);
  assert.match(start, /event\(\.speechStarted/);
  assert.equal((feedback.match(/event\(\.speechStarted/g) || []).length, 1);
});

test('native debug integration: actual finish/cancel, app cancel and timeout are distinguishable', () => {
  for (const label of ['AVSpeech.didFinish', 'AVSpeech.didCancel', 'app.cancelOrLifecycle', 'speech.timeout.notCompletion']) assert.ok(feedback.includes(label));
  assert.match(feedback, /completion\.outcome == \.completed \? \.speechCompleted/);
  assert.match(feedback, /completion\.outcome == \.interrupted \? \.speechInterrupted : \.unavailable/);
});

test('native debug integration: VoiceOver text callbacks do not invent utterance IDs or proven playback', () => {
  assert.match(feedback, /completion\.attempt\.transport == \.accessibility \? \.unavailable/);
  assert.match(feedback, /utteranceID: completion\.attempt\.transport == \.synthesized \? completion\.attempt\.token : nil/);
  assert.match(feedback, /VoiceOverCorrelation=unbound/);
  assert.match(feedback, /VoiceOver\.textOnlyCallback/);
});

test('native debug integration: privacy removal invokes purge and reports failure without new controls', () => {
  for (const [signature, mutation] of [
    ['func clearAssistantConversation(', 'assistantDialogue = AssistantDialogue()'],
    ['func clearNarrationHistory(', 'enqueueNarration'],
    ['func clearObservedObjects(', 'nativeObservations.clearHistory('],
    ['func removeAssistantInterest(', 'updated.remove(id: id)'],
    ['func forgetItem(', 'nativeObservations.clearHistory('],
    ['func forgetRoomPictures(', 'roomRecall.forget(room: id)'],
    ['func deletePlace(', 'nativeObservations.clearHistory('],
    ['func forgetRoom(', 'nativeObservations.clearHistory('],
    ['func removeHint(', 'companion.memory.removeHint(id: id)'],
  ]) {
    const body=method(nav,signature);
    const check=source=>{
      assert.match(source, /#if DEBUG\s+purgeDebugSessionDiagnostics\(\)\s+#endif/);
      const purge=source.indexOf('purgeDebugSessionDiagnostics()'), change=source.indexOf(mutation);
      assert.ok(purge>=0 && change>purge,`${signature}: purge precedes privacy mutation`);
    };
    check(body);
    assert.throws(()=>check(body.replace('purgeDebugSessionDiagnostics()','')), {name:'AssertionError'},signature);
  }
  const clear = method(nav, 'func clearAssistantConversation(');
  const checkClear = source => {
    const ordered = ['purgeDebugSessionDiagnostics()', 'cancelDescription()',
      'assistantDialogue = AssistantDialogue()', 'companionWorkingState = CompanionWorkingState()', 'persistWorkingState()'];
    let previous = -1;
    for (const token of ordered) {
      const at = source.indexOf(token); assert.ok(at > previous, `Conversation privacy order: ${token}`); previous = at;
    }
    assert.doesNotMatch(source, /persistDialogue\(/, 'Clear submits one paired empty snapshot, never old task state.');
  };
  checkClear(clear);
  for (const mutation of [
    clear.replace('purgeDebugSessionDiagnostics()', ''),
    clear.replace('assistantDialogue = AssistantDialogue()', ''),
    clear.replace('companionWorkingState = CompanionWorkingState()', ''),
    'persistWorkingState();' + clear,
  ]) assert.throws(() => checkClear(mutation), {name: 'AssertionError'});
  assert.doesNotMatch(nav, /unverifiedDialogue/, 'Anonymous microphone turns no longer share retained history.');
  assert.match(method(nav, 'private func receiveUnverifiedConversation('), /let dialogue = VoiceConversationPrivacy\.anonymousTurn\(text\)/);
  const forget = section(nav, '    func forgetConversationRecord(', '    func savePreferredName(');
  const admission = 'guard companionWorkingState.allowsLegacyReportMutation else { return }';
  const admissionAt = forget.indexOf(admission);
  const purgeAt = forget.indexOf('purgeDebugSessionDiagnostics()');
  const mutationAt = forget.indexOf('assistantDialogue.forgetUserRecord(id: id)');
  assert.ok(admissionAt >= 0 && purgeAt > admissionAt && mutationAt > purgeAt);
  assert.doesNotMatch(forget.slice(0, admissionAt), /retireHeldSearch|purgeDebug|forgetUserRecord|removeReport|persist|return true/);
  assert.match(forget.slice(admissionAt + admission.length, purgeAt), /^\s*retireHeldSearchForPrivacyDeletion\(\)\s*#if DEBUG\s*$/);
  assert.match(forget.slice(purgeAt, mutationAt), /^purgeDebugSessionDiagnostics\(\)\s*#endif\s*guard let original = assistantDialogue\.userRecords\.first\(where: \{ \$0\.id == id \}\),\s*$/);
  assert.ok(forget.indexOf('companionWorkingState.removeReport(original.text)') > mutationAt);
  assert.ok(forget.indexOf('persistDialogue(); persistWorkingState()') > mutationAt);
  assert.match(nav, /guard !debugPurgePending else/);
  assert.match(nav, /debugLastPurgeSucceeded = success/);
  assert.match(familiar, /case \.deletePerson\(let id\):\s*#if DEBUG\s*purgeDebugSessionDiagnostics/);
  assert.match(familiar, /func deleteAll\(\) \{\s*#if DEBUG\s*purgeDebugSessionDiagnostics/);
  assert.doesNotMatch(nav + familiar, /Button\(".*[Dd]ebug|showDebugHistory|debugHistoryTab/);
});

test('native debug integration: removed/replaced names and corrected records purge superseded content', () => {
  const name = section(nav, '    func savePreferredName', '    private func persistWorkingState');
  assert.match(name, /name\.isEmpty \|\| \(!preferredName\.isEmpty && name != preferredName\)/);
  assert.match(name, /purgeDebugSessionDiagnostics\(\)/);
  const correction = section(nav, '    @discardableResult func correctConversationRecord', '    func forgetConversationRecord');
  assert.match(correction, /purgeDebugSessionDiagnostics\(\)/);
});

test('native debug integration: shared microphone validation fence is never invented as request provenance', () => {
  assert.match(nav, /requestID: origin == \.unverifiedMicrophone \|\| codeOwned \? nil : request/);
  assert.match(nav, /requestID: next\.origin == \.unverifiedMicrophone \|\| next\.codeOwned \? nil : next\.request/);
  assert.match(nav, /requestID: active\.origin == \.unverifiedMicrophone \|\| active\.codeOwned \? nil : active\.request/);
});

test('native debug integration: every clock acquisition logs its actual reply owner without shared request provenance', () => {
  const acquire = section(nav, '    private func acquireClockReply(', '    private var activeModelClockReplyID:');
  assert.match(acquire, /let clockTrace = DebugNativeSessionTrace\(\)/);
  assert.match(acquire, /question == nil \? "deviceClock.modelRead" : "deviceClock.directRead"/);
  assert.match(acquire, /clockLabel \+ "\.returned; replyID=" \+ binding.replyID.uuidString/);
  assert.equal((acquire.match(/CompanionClockReplyLease\.read\(/g) || []).length, 1);
  assert.match(nav, /acquireClockReply\(question: question\)/);
  assert.match(nav, /clockReceipt: receipt.replyIDs.isEmpty \? nil : receipt/);
  assert.match(nav, /if let receipt = next\.clockReceipt, !clockDeliveryIsCurrent/);
  assert.match(nav, /revalidateClockReplies\(\)/);
});

test('native debug integration: shopping and direct-store deletion cannot leave retained diagnostics', () => {
  assert.match(nav, /if case \.remove = command \{ purgeDebugSessionDiagnostics\(\) \}/);
  assert.match(journey, /func delete\(_ journey: Journey\) \{\s*#if DEBUG\s*purgeDebugSessionDiagnostics/);
  assert.match(mapping, /func deleteMap\(\) \{\s*#if DEBUG\s*purgeDebugSessionDiagnostics/);
  assert.match(indoor, /func deleteMap\(completion: @escaping MapCompletion = \{ _ in \}\) \{\s*#if DEBUG\s*purgeDebugSessionDiagnostics/);
  for (const store of [journey, mapping, indoor]) {
    assert.match(store, /guard !debugPurgePending else/);
    assert.match(store, /debugLastPurgeSucceeded = success/);
  }
});

test('native debug integration: purge failures never enter child-visible UI fields', () => {
  for (const source of [nav, familiar, journey, mapping, indoor]) {
    const helper = section(source, '    private func purgeDebugSessionDiagnostics()', '    #endif');
    assert.doesNotMatch(helper, /self\?\.(message|status|profileStatus|currentReply|sceneAnswer)\s*=/);
    assert.match(helper, /debugLastPurgeSucceeded = success/);
    assert.match(helper, /DebugNativeSessionTrace\.reportPurgeResult\(success\)/);
  }
  assert.match(model, /FileHandle\.standardError\.write/);
});

test('native debug integration: developer purge report is off-main and bounded without blocking admission', () => {
  const report = model.slice(model.indexOf('    private static let purgeReportQueue'));
  assert.match(report, /DispatchSemaphore\(value: 1\)/);
  assert.match(report, /purgeReportSlot\.wait\(timeout: \.now\(\)\)/);
  assert.ok(report.indexOf('purgeReportQueue.async') < report.indexOf('FileHandle.standardError.write'));
  assert.match(report, /defer \{ purgeReportSlot\.signal\(\) \}/);
});
