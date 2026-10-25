import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const read=p=>readFileSync(new URL(p,import.meta.url),'utf8');
const source=read('CapturedTextReviewNativeComponentTests.swift');
const section=(a,b)=>source.slice(source.indexOf(a),source.indexOf(b,source.indexOf(a)+a.length));
test('authored two-part fixture is frozen, hashed and never promoted to camera proof',()=>{
 for(const x of ['count: 4','count, 40','originalPhrases.count == 2','SHA256.hash(data: Data(fixture.utf8))','no image/camera/OCR']) assert.ok(source.includes(x),x);
 assert.doesNotMatch(source,/String\(repeating: "a", count: 64\)/);
});
test('real onset must precede repeat replacement and old cancellation request',()=>{
 const start=section('func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart','func rejectOldCallback');
 const owned=s=>{
  for(const x of ['utterance === current.utterance','utterance.speechString == current.phrase.text','reader.started(id: current.phrase.id','review(.repeatPart, phase: .repeated)','awaitingOldCancellation = true','speech.stopSpeaking(at: .immediate)']) assert.ok(s.includes(x),x);
  assert.ok(s.indexOf('reader.started')<s.indexOf('review(.repeatPart'));
  assert.ok(s.indexOf('review(.repeatPart')<s.indexOf('speech.stopSpeaking'));
 };
 owned(start);
 for(const x of ['reader.started(id: current.phrase.id','utterance === current.utterance']) assert.throws(()=>owned(start.replace(x,'REMOVED')));
 assert.doesNotMatch(source,/\.speechSynthesizer\(/);
});
test('actual old cancellation uses old context and cannot poison replacement',()=>{
 const reject=section('func rejectOldCallback','func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel');
 const assertSafe=s=>{
  for(const x of ['context(current.selection)','!accepted','reader.selection == selected','reader.playbackReceipt == before','!reader.withdrawn','reader.completed == 0','reader.paused == beforePaused','reader.lastSpokenPart == beforeSpoken','reader.pending == beforePending']) assert.ok(s.includes(x),x);
 };
 assertSafe(reject);
 for(const x of ['!accepted','!reader.withdrawn','reader.paused == beforePaused','context(current.selection)']) assert.throws(()=>assertSafe(reject.replace(x,'REMOVED')));
 const cancel=section('func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel','func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish');
 assert.match(cancel,/awaitingOldCancellation[\s\S]*rejectOldCallback\(current, outcome: .interrupted\)/);
});
test('a racing real finish is preserved and fails rather than inventing cancellation',()=>{
 const finish=section('func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish','func shutdown()');
 assert.match(finish,/if awaitingOldCancellation[\s\S]*rejectOldCallback\(current, outcome: .completed\)[\s\S]*fail\("Requested cancellation raced with actual finish"\); return/);
 assert.ok(finish.indexOf('if awaitingOldCancellation')<finish.indexOf('guard reader.finish'));
});
test('retained source keeps timestamps but every review renews playback identity',()=>{
 const review=section('func review(_ command:', 'func pump()');
 for(const x of ['next.id != selected.id','next.requestID != selected.requestID','next.issuedAt == originalSelection.issuedAt','next.capturedAt == originalSelection.capturedAt','reader.source!.identity == oldSource','isDisjoint(with: oldIDs)']) assert.ok(review.includes(x),x);
 assert.match(source,/originalReceipt = reader.playbackReceipt/);
 assert.match(source,/finalReceipt = reader.clear\(\)/);
 assert.match(source,/!reader.review\(.repeatPart, requestID: UUID\(\), context: oldContext\)/);
});
test('ordinary ledger and bounded real wake remain unchanged; no timer completion',()=>{
 const pump=section('func pump()', 'func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart');
 for(const x of ['nextInformationBudgetTime','attention.decide','Task.sleep','!Task.isCancelled','self.reader.selection?.id == selectedID']) assert.ok(pump.includes(x),x);
 assert.doesNotMatch(pump,/outcome: .completed|reader.finish/);
 assert.match(source,/wordsPerMinute: 30/); assert.match(source,/timeout: 480/);
 assert.match(source,/queuedRepeatRejected = !reader.review/);
});
test('fixed host targets actual architecture and runner executes once',()=>{
 const generator=read('generate-project.mjs'),runner=read('run-native.sh');
 assert.match(generator,/ONLY_ACTIVE_ARCH = YES/);
 assert.match(generator,/XCLocalSwiftPackageReference; relativePath = BlindCore/);
 assert.doesNotMatch(generator,/AdmittedSpeech\(|textOnly\s*=|ARCHS = arm64|EXCLUDED_ARCHS/);
 assert.equal((runner.match(/xcodebuild -project/g)||[]).length,1);
 assert.match(runner,/status --porcelain --untracked-files=all -- BlindCore/);
 const pin=JSON.parse(read('source-pins.json')).commit; assert.match(pin,/^[a-f0-9]{40}$/);
 assert.ok(runner.includes('expected='+pin)); assert.ok(read('native-reading-review-component.yml').includes('ref: '+pin));
 assert.doesNotMatch(runner,/retry-tests|test-iterations|simctl erase|rm -rf/);
});
test('scope excludes controller and actor inference and preserves race failure',()=>{
 const docs=read('README.md');
 for(const x of ['test-owned AVSpeech bridge','No production controller','not acoustic intelligibility','fail the requested-cancellation expectation','incomplete snapshot taken before cancellation']) assert.ok(docs.includes(x),x);
 for(const x of ['count, 1','count, 4','count, 5','playback.completed.count, 4']) assert.ok(source.includes(x),x);
});
