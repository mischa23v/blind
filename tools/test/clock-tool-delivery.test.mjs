// Source contracts supplement the extracted production callback execution tests.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const read = path => readFileSync(new URL(`../../${path}`, import.meta.url), 'utf8');
const model = read('ios/BlindAssist/NavigationModel.swift');
const core = read('BlindCore/Sources/BlindCore/CompanionClockDelivery.swift');
function body(signature, source = model) {
  const start = source.indexOf(signature); assert.ok(start >= 0, signature);
  const first = source.indexOf('{', start); let depth = 0;
  for (let i = first; i < source.length; i++) {
    if (source[i] === '{') depth++;
    if (source[i] === '}' && --depth === 0) return source.slice(start, i + 1);
  }
  assert.fail(signature);
}
test('all native clock reads go through acquisition registration before tool return', () => {
  assert.doesNotMatch(model, /CompanionClock\.read\(/);
  const acquire = body('private func acquireClockReply(');
  assert.match(acquire, /CompanionClockReplyLease.read/);
  assert.match(acquire, /clockReplies\[binding.replyID\] = lease/);
  assert.ok(acquire.indexOf('clockReplies[binding.replyID] = lease') < acquire.indexOf('return lease'));
  assert.match(acquire, /startClockExpiry\(\)/);
  const turn = body('@MainActor private func readCompanionToolForTurn(');
  assert.ok(turn.indexOf('await readCompanionTool(request)') < turn.indexOf('CompanionClockDelivery.validatesToolResult'));
  assert.match(turn, /status: \.stale/);
});
test('legacy everyday clock route precedes all subtask mutation', () => {
  const route = body('private func routeEverydayTask(');
  const early = route.indexOf('if request.capability == .deviceClock');
  assert.ok(early >= 0);
  for (const mutation of ['everydayUtterance =', 'everydayTasks.setGoal', 'everydayTasks.begin', 'everydayTasks.pause']) {
    assert.ok(early < route.indexOf(mutation), mutation);
  }
  assert.doesNotMatch(route, /finishEverydayTask\(\.deviceClock|deliverConversationReply\(value.text\)/);
});
test('model admission is before metadata but final publication remains after the proposal gate', () => {
  const chat = body('private func answerConversation(');
  assert.match(chat, /guard self.showConversationReply\(displayed, settled: false\) else/);
  const admission = chat.indexOf('guard let text = self.modelReplyText(rawText), self.clockDeliveryReceipt(text) != nil');
  const metadata = chat.indexOf('if self.activeModelClockReplyID == nil, let update = answer.taskUpdate');
  const proposal = chat.indexOf('guard self.companionWorkingState.actionProgress.allowsProposal(text, goalRevision: revision) else');
  const publication = chat.indexOf('guard self.showConversationReply(text, settled: true) else');
  assert.ok(admission >= 0 && admission < metadata && metadata < proposal && proposal < publication);
  const beforeProposal = chat.slice(admission, proposal);
  assert.doesNotMatch(beforeProposal, /showConversationReply\(text|sceneAnswer = text|currentReply = text/);
  assert.match(body('private func receiveUnverifiedConversation('), /guard self.showConversationReply\(reply, settled: true, origin: origin\)/);
});
test('camera-independent expiry covers previews settled text active and queued clock speech', () => {
  const expire = body('private func revalidateClockReplies(');
  for (const token of ['sceneClockReceipt', 'currentClockReceipt', 'activeConversationSpeech', 'conversationSpeech.removeAll', 'feedback.stopRequestedSpeech(active.id)']) assert.ok(expire.includes(token), token);
  assert.doesNotMatch(expire, /clockReplies.removeValue|stopReturn|cancelRoute|includingAlerts/);
  assert.match(body('private func startClockExpiry('), /clockReplies.values.contains\(where: \{ !\$0.invalidated \}\)/);
});
test('repeat retains original receipt and no delivery boundary acquires a fresh clock', () => {
  const repeat = body('@discardableResult func speakRequested(');
  assert.match(repeat, /sceneClockReceipt, currentClockReceipt/);
  assert.match(repeat, /clockReceipt: receipt/);
  for (const signature of ['@discardableResult func speakRequested(', 'private func queueConversationSpeech(', 'private func drainConversationSpeech(', 'private func clockDeliveryReceipt(', 'private func clockDeliveryIsCurrent(']) {
    assert.doesNotMatch(body(signature), /acquireClockReply\(|CompanionClock(?:ReplyLease)?\.read\(/, signature);
  }
});
test('policy binds exact original source and record and never silently chooses a newer equal string', () => {
  assert.match(core, /result == original.result/);
  assert.match(core, /\.issuedAt < \$1.issuedAt/);
  assert.match(core, /receipt.text.utf8.elementsEqual\(text.utf8\)/);
  assert.match(core, /leases\[id\] = lease/);
  assert.doesNotMatch(core, /CompanionClockReplyLease.read\(|CompanionClock.read\(/);
});

test('model-selected clock operation uses only first acquired code-owned reply, not a language blacklist', () => {
  assert.match(body('private func modelReplyText('), /return modelClockReceipt\(\)\?\.text/);
  assert.match(body('private func modelClockReceipt('), /CompanionClockDelivery.replyForClockOperation/);
  assert.match(body('private func queueModelConversationSpeech('), /queueConversationSpeech\(receipt.text/);
  assert.match(body('private func queueModelConversationSpeech('), /modelClockSpeechQueuedID != id/);
  assert.match(body('@MainActor private func readCompanionTool('), /if firstClockSelection \{ modelClockOperation = lease.binding \}/);
});

test('failed first clock acquisition still latches the clock operation before any model callback', () => {
  const tool = body('@MainActor private func readCompanionTool(');
  assert.ok(tool.indexOf('modelClockOperation = .init(') < tool.indexOf('guard let lease = acquireClockReply()'));
  assert.match(tool, /let firstClockSelection = activeModelClockReplyID == nil/);
});
