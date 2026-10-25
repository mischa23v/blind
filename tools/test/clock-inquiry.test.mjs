// Source-contract checks, not Apple SDK, voice, or on-device clock acceptance.
// Deterministic time/rollback policy executes in CompanionClockInquiryTests.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const read = path => readFileSync(new URL(`../../${path}`, import.meta.url), 'utf8');
const model = read('ios/BlindAssist/NavigationModel.swift');
const core = read('BlindCore/Sources/BlindCore/CompanionClockInquiry.swift');
function body(signature, source = model) {
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

test('clock inquiry crosses conversation authority before any mutating task entry', () => {
  const receive = body('func receiveCompanionUtterance(');
  const route = receive.indexOf('if routeClockInquiry(text, origin: origin)');
  assert.ok(route > receive.indexOf('let origin: CompanionCommandOrigin'));
  for (const action of ['routeVoiceRoomScan(text)', 'everydayTasks.pause()', 'cancelDescription()',
                        'handleConversationTaskControl(control)', 'routeEverydayTask(text)', 'answerConversation(text)']) {
    assert.ok(receive.indexOf(action) > route, action);
  }
  assert.match(body('public static func accepts(', core), /CommandAuthority.permits\(\.conversation, from: origin\) && recognizes\(question\)/);
  assert.match(body('private func routeClockInquiry('), /guard CompanionClockInquiry.accepts\(question, origin: origin\) else/);
});

test('read-only clock inquiry does not mutate goal search navigation reports camera or shared request identity', () => {
  const route = body('private func routeClockInquiry(');
  assert.match(route, /interruptOrdinaryConversation\(origin: origin\)/);
  assert.doesNotMatch(route, /cancelDescription\(|stopReturn\(|cancelRoute\(|everydayTasks\.|objectSearch|familiarPeople|recordCompanionMessage\(|companionWorkingState\.|persistWorkingState\(|requestID\s*=|perceptionGeneration\s*=|readScene\(|LocalImageAssistant|session\.currentFrame|cameraAwareness\s*=/);
  assert.match(route, /CompanionClockReplyLease.read\(binding: binding, now: Date\(\),\s*monotonicNow: ProcessInfo.processInfo.systemUptime, timeZone: \.current/);
  assert.match(route, /codeOwned: true, origin: origin, clockReplyID: binding.replyID/);
});

test('queue dispatch playback and repeat preserve original read lease', () => {
  assert.match(body('private func queueConversationSpeech('), /clockReplyIsCurrent\(clockReplyID, text: text\)/);
  assert.match(body('private func drainConversationSpeech('), /clockReplyIsCurrent\(clockID, text: next.text\)/);
  assert.match(body('private func revalidateConversationSpeech('), /revalidateClockReplies\(\)/);
  const revalidate = body('private func revalidateClockReplies(');
  assert.match(revalidate, /feedback.stopRequestedSpeech\(active.id\)/);
  assert.match(revalidate, /conversationSpeech.removeAll \{ \$0.clockReplyID == id \}/);
  assert.match(revalidate, /if currentReply == lease.reply \{ currentReply = expired \}/);
  assert.doesNotMatch(revalidate, /stopReturn\(|cancelRoute\(|stopCamera|\.read\(/);
  const repeat = body('@discardableResult func speakRequested(');
  assert.match(repeat, /clockReplyIsCurrent\(id, text: text\)/);
  assert.match(repeat, /clockReplyID: id/);
  assert.doesNotMatch(repeat, /CompanionClock(?:ReplyLease)?\.read/);
});

test('clock expiry runs with camera off and never remints a read during validation', () => {
  const route = body('private func routeClockInquiry(');
  assert.match(route, /Task \{ @MainActor \[weak self\]/);
  assert.match(route, /self.revalidateClockReplies\(\)/);
  assert.match(route, /Task.sleep\(for: \.milliseconds\(100\)\)/);
  assert.doesNotMatch(route, /guard .*running|guard .*camera|startWatchdog/);
  const validate = body('private func clockReplyIsCurrent(');
  assert.match(validate, /requestID: requestID,\s*generation: assistantSession.generation, replyID: id/);
  assert.match(validate, /lease.validates\(reply: text/);
  assert.doesNotMatch(validate, /CompanionClock(?:ReplyLease)?\.read/);
  assert.match(core, /age < CompanionClock.lifetime/);
  assert.match(core, /wallAge < CompanionClock.lifetime/);
  assert.match(core, /timeZone.identifier == timeZoneIdentifier/);
  assert.match(core, /guard valid else \{ invalidated = true; return false \}/);
});
