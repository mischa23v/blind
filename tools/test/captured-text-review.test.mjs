import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const root=process.env.CAPTURED_REVIEW_ROOT || new URL('../../',import.meta.url).pathname;
const read=p=>readFileSync(root+'/'+p,'utf8');
const native=read('ios/BlindAssist/NavigationModel.swift');
const section=(s,a,b)=>s.slice(s.indexOf(a),s.indexOf(b,s.indexOf(a)+a.length));
test('completed page is retained, not automatically forgotten',()=>{
 const finish=section(native,'private func finishCapturedTextSpeech(', 'private func updateCapturedText(');
 assert.doesNotMatch(finish,/if capturedText.playbackCompleted \{ stopReadingTool/);
 assert.match(finish,/pauseCapturedTextPlayback/);
});
test('review is intercepted before ordinary cancellation in both trusted request paths',()=>{
 for (const [start,end] of [['func receiveCompanionUtterance(', 'private func revalidateClockReplies('], ['func readScene(', 'private static func wordCount(']]) {
  const body=section(native,start,end);
  const review=body.indexOf('routeCapturedTextReview(');
  const cancel=body.indexOf(start.includes('readScene')?'stopReadingTool(announce: false)':'cancelDescription()');
  assert.ok(review>=0 && review<cancel, start);
 }
});
test('onset uses exact actual platform start after permission, never enqueue',()=>{
 const feedback=read('ios/BlindAssist/Feedback.swift');
 const start=section(feedback,'func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart', 'func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish');
 assert.match(start,/onRequestedSpeechStarted\?\(id, active.text\)/);
 assert.ok(start.indexOf('requestedSpeechPermission')<start.indexOf('onRequestedSpeechStarted?'));
 assert.equal((feedback.match(/onRequestedSpeechStarted\?\(/g)||[]).length,1);
});

test('retention blocks only ambient scene replacement, and privacy/input lanes remain explicit',()=>{
 assert.match(native,/if automatic, currencyActive \|\| colorActive \|\| readingTool != nil \|\| capturedText.source != nil/);
 assert.match(native,/if \(usesCapturedText \|\| capturedText.source != nil\) && !currencyActive/);
 const route=section(native,'private func routeCapturedTextReview(', 'private func updateCapturedText(');
 assert.match(route,/CommandAuthority.permits\(\.changeGoal, from: origin\)/);
 assert.doesNotMatch(route,/capturedTextCameraAllowed|confirmSubtaskComplete|recordCompanionMessage|persist|model\./);
 assert.match(native,/CapturedTextReviewCommand.parse\(text\) == nil/);
 const guidance=section(native,'private func offerCapturedTextReviewGuidance()', 'private func routeCapturedTextReview(');
 assert.match(guidance,/kind: .answer, requested: true, replace: false/);
 assert.doesNotMatch(guidance,/speakOperation|currentReply|persist|recordCompanionMessage/);
});
test('retained historical review survives nonurgent depth/VIO loss without acquiring fresh camera authority',()=>{
 assert.match(native,/else if !detection.hazard.isUrgent && capturedText.source != nil && capturedTextPlaybackAllowed\(\) \{[\s\S]*?invalidatePerceptionWork\(preserveCapturedText: true\)/);
 const pause=section(native,'private func pauseCapturedTextPlayback()', 'private func offerCapturedTextReviewGuidance()');
 assert.doesNotMatch(pause,/cameraTextEpoch\s*=|cancelDescription\(|capturedText.clear\(/);
});
