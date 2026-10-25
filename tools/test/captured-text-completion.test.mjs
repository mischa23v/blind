import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const root = new URL('../../', import.meta.url);
const read = p => readFileSync(new URL(p,root),'utf8');
const native=read('ios/BlindAssist/NavigationModel.swift');
const section=(s,a,b)=>s.slice(s.indexOf(a),s.indexOf(b,s.indexOf(a)+a.length));
test('only installed text leaves acquisition clock; live frame gate stays acquisition-only',()=>{
 const update=section(native,'private func updateCapturedText(frame:', 'private struct ReadingCapture');
 assert.ok(update.indexOf('if capturedText.source != nil') < update.indexOf('readingStarted >= CompanionReferenceReading.lifetime'));
 assert.match(update,/capturedTextCameraAllowed\(\)/);
 const playback=section(native,'private func capturedTextPlaybackAllowed()', 'private func cancelCapturedTextBudgetWake()');
 for(const s of ['mayRespond','foregroundActive','privateAudioHeld','isUrgent','!textOnly']) assert.ok(playback.includes(s));
 assert.doesNotMatch(playback,/currentFrame|trackingState|interfaceOrientation|isFresh/);
 assert.match(native,/foreground: \(capturedText.source == nil \? capturedTextCameraAllowed\(\) : capturedTextPlaybackAllowed\(\)\)/);
});
test('one cancellable wake is source/deadline owned and cannot complete speech',()=>{
 const schedule=section(native,'private func scheduleCapturedTextBudgetWake(', 'private func speakNextCapturedText()');
 const assertOwned=s=>{
  for(const x of ['capturedTextBudgetWake == nil','deadline.isFinite','deadline > now','Task.sleep','!Task.isCancelled','self.capturedText.selection?.id == selectionID','self.capturedTextBudgetWakeAt == deadline','self.revalidateCapturedText()']) assert.ok(s.includes(x),x);
  assert.doesNotMatch(s,/capturedText\.finish|completed \+=|playbackCompleted\s*=/);
 };
 assertOwned(schedule);
 for(const x of ['capturedTextBudgetWake == nil','!Task.isCancelled','self.capturedText.selection?.id == selectionID','self.capturedTextBudgetWakeAt == deadline']) assert.throws(()=>assertOwned(schedule.replace(x,'true')));
 const dispatch=section(native,'private func speakNextCapturedText()', 'private func capturedTextSpeechPermission(');
 assert.ok(dispatch.indexOf('guard capturedTextBudgetWakeAt == nil')<dispatch.indexOf('capturedText.next(context)'));
 assert.ok(dispatch.indexOf('nextInformationBudgetTime')<dispatch.indexOf('capturedText.begin(phrase'));
 assert.match(dispatch,/dispatchText\(phrase.text, kind: .answer, requested: true, replace: false/);
});
test('stop, replacement and pace changes revoke the wake; exact callback alone completes',()=>{
 const clear=section(native,'private func clearCapturedText()', 'private func capturedTextContext()');
 assert.ok(clear.indexOf('cancelCapturedTextBudgetWake()')<clear.indexOf('capturedText.clear()'));
 const cancel=section(native,'private func cancelCapturedTextBudgetWake()', 'private func capturedTextPacingChanged()');
 assert.match(cancel,/capturedTextBudgetWake\?\.cancel\(\)/);assert.match(cancel,/capturedTextBudgetWakeAt = nil/);
 const pace=section(native,'private func capturedTextPacingChanged()', 'private func scheduleCapturedTextBudgetWake(');
 assert.match(pace,/cancelCapturedTextBudgetWake\(\)[\s\S]*revalidateCapturedText\(\)/);
 const finish=section(native,'private func finishCapturedTextSpeech(', 'private func updateCapturedText(');
 assert.ok(finish.indexOf('capturedText.finish(id: id, text: text, outcome: outcome')<finish.indexOf('capturedText.playbackCompleted'));
 assert.doesNotMatch(finish,/confirmSubtaskComplete|recordCompletedSubtask/);
});
test('terminal metadata is session-owned and explicit deletion cannot resurrect it',()=>{
 const clear=section(native,'private func clearCapturedText()', 'private func capturedTextContext()');
 const valid=s=>{
  for(const x of ['receipt.sessionGeneration == assistantSession.generation','assistantSession.foregroundActive','assistantSession.mayRespond','!assistantSession.privateAudioHeld']) assert.ok(s.includes(x),x);
  assert.match(s,/stopReadingTool\(announce: false\)[\s\S]*lastCapturedTextPlaybackReceipt = nil/);
 };
 valid(clear);
 for(const x of ['receipt.sessionGeneration == assistantSession.generation','assistantSession.foregroundActive','assistantSession.mayRespond','!assistantSession.privateAudioHeld']) assert.throws(()=>valid(clear.replace(x,'true')));
 assert.match(native,/oldValue.generation != assistantSession.generation[^\n]*lastCapturedTextPlaybackReceipt = nil/);
 for(const start of ['private func retireHeldSearchForPrivacyDeletion()', 'func clearNarrationHistory()']) assert.match(section(native,start,'\n    }'),/purgeCapturedTextPlayback\(\)/);
});
