import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
const root=process.env.CAPTURED_TEXT_SOURCE_ROOT || fileURLToPath(new URL('../../',import.meta.url));
const read=p=>readFileSync(root+'/'+p,'utf8');
const native=read('ios/BlindAssist/NavigationModel.swift');
const section=(start,end)=>native.slice(native.indexOf(start),native.indexOf(end,native.indexOf(start)));
test('new RGB admission has lifecycle freshness and orientation, no pose or VIO authority',()=>{
 const s=section('private func capturedTextCameraAllowed()', 'private func retireCapturedTextSource()');
 for(const token of ['shouldRunCamera','mayRespond','foregroundActive','privateAudioHeld','!cameraInterrupted','isUrgent','FrameTimestampPolicy.isFresh','interfaceOrientation == .portrait']) assert.ok(s.includes(token),token);
 assert.doesNotMatch(s,/trackingState|stationary|transform|sceneDepth/);
});
test('text route freezes and hashes actual pixels, uses only local OCR and complete blocks',()=>{
 const s=section('private func updateCapturedText(frame:', 'private struct ReadingCapture');
 for(const token of ['capturedTextNativeLease == nil','readingWork.owns(token)','self.capturedText.selection == selection','CIContext().createCGImage','SHA256.hash(data: bytes as Data)','VisionService.capturedTextLines','media: .capturedText','kind: .historicalMemory','bodyUTF16Range','capturedText.install']) assert.ok(s.includes(token),token);
 assert.doesNotMatch(s,/\.prefix\(|confidence\s*>|URLSession|write\(|\.normal|model\./);
});
test('only explicit text/document switch routes to new receipt; original barcode/light capture gate remains',()=>{
 assert.match(native,/usesCapturedText: Bool \{ readingTool == \.liveText \|\| readingTool == \.document \}/);
 assert.match(native,/if usesCapturedText \{ updateCapturedText\(frame: frame\); return \}/);
 assert.match(native,/guard readingCameraAllowed\(\), case \.normal = frame.camera.trackingState/);
 assert.match(native,/readingWork.accepts\(capture.token[\s\S]*visualCapturePoseAllowed\(origin: capture.origin/);
});
test('typed travel path retains original stricter capture owner and no raw fallback',()=>{
 const s=section('private func updateCapturedText(frame:', 'private struct ReadingCapture');
 assert.match(s,/let boardingCapture = captureObjectView\(frame\)/);
 assert.match(s,/BoardingPassDispatch.textRows/); assert.match(s,/deliverBoardingReading\(travel, owner: boardingOwner, capture: boardingCapture\)/);
 assert.match(s,/else \{ self.stopReadingTool\(announce: false\) \}\n                return/);
});
test('callbacks own exact speech, private delivery and retained native lease',()=>{
 assert.match(native,/self.finishCapturedTextSpeech\(id: id, text: text, outcome: outcome\)/);
 assert.match(native,/self\?\.capturedTextSpeechPermission/);
 assert.match(native,/boardingSpeechIDs.contains\(\$0\) \|\| capturedTextSpeechIDs.contains\(\$0\)/);
 const s=section('private func clearCapturedText()', 'private func capturedTextContext()');
 assert.match(s,/capturedText.clear\(\)[\s\S]*stopRequestedSpeech/); assert.doesNotMatch(s,/capturedTextNativeLease = nil/);
});
test('VIO preservation is captured-only and actual source invalidation rotates epoch',()=>{
 assert.match(native,/if readingTool != nil && !usesCapturedText \{ stopReadingTool/);
 assert.match(native,/invalidatePerceptionWork\(preserveCapturedText: true\)/);
 const capturedOnly=section('else if !detection.hazard.isUrgent && usesCapturedText && capturedTextCameraAllowed()', '} else { cancelDescription() }');
 assert.match(capturedOnly,/invalidatePerceptionWork\(preserveCapturedText: true\)/);
 assert.doesNotMatch(capturedOnly,/preserveRGBHistoryWork|preserveRGB\s*=/, 'Limited-VIO text must not preserve other RGB producers');
 assert.match(native,/if !preserveRGBHistoryWork && !preserveCapturedText \{ retireCapturedTextSource\(\) \}/);
 assert.match(native,/cameraTextEpoch = UUID\(\)\n        clearCapturedText\(\)/);
});
test('explicit reading permits ambient-off but quiet/stop cancels through existing reader',()=>{
 const s=section('private func capturedTextContext()', 'private func revalidateCapturedText()');
 assert.match(s,/quiet: false/);
 assert.match(native,/func stopReadingTool[^\n]*\{\n        clearCapturedText\(\)/);
 assert.match(native,/private func cancelDescription\(\)[\s\S]*stopReadingTool\(announce: false\)/);
});
test('pending native jobs cannot extend request deadline; chunk cap fits minimum budget',()=>{
 const s=section('private func updateCapturedText(frame:', 'private struct ReadingCapture');
 assert.ok(s.indexOf('readingStarted >= CompanionReferenceReading.lifetime') < s.indexOf('capturedTextNativeLease == nil'));
 assert.match(read('BlindCore/Sources/BlindCore/CapturedTextReference.swift'),/phraseWordLimit: 25/);
 assert.match(read('BlindCore/Sources/BlindCore/CapturedTextReference.swift'),/now - value.capturedAt < 0.5/);
});
