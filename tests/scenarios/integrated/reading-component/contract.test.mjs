import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const read = p => readFileSync(new URL(p,import.meta.url),'utf8');
const source=read('CapturedTextNativeComponentTests.swift');
test('component alone owns bridge; production admission and gates are not modified',()=>{
 const project=read('generate-project.mjs');
 assert.match(project,/XCLocalSwiftPackageReference; relativePath = BlindCore/);
 assert.doesNotMatch(project,/copy.*NavigationModel|AdmittedSpeech\(|textOnly\s*=/);
 assert.match(source,/attention.decide\(\[candidate\]/);
 assert.match(source,/nextInformationBudgetTime/);
 assert.match(source,/CompanionSettings\(wordsPerMinute: 30\)/);
});
test('only exact native finish advances source; timer never completes it',()=>{
 const finish=source.slice(source.indexOf('func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish'),source.indexOf('func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel'));
 const owned=s=>{
  for(const x of ['utterance === current.0','utterance.speechString == current.1.text','reader.finish(id: current.1.id','outcome: .completed','reader.playbackCompleted']) assert.ok(s.includes(x),x);
 };
 owned(finish);
 for(const x of ['utterance === current.0','utterance.speechString == current.1.text']) assert.throws(()=>owned(finish.replace(x,'true')));
 const wake=source.slice(source.indexOf('wake = Task'),source.indexOf('let stamp = now'));
 assert.doesNotMatch(wake,/reader.finish|outcome: .completed/);
 assert.doesNotMatch(source,/\.speechSynthesizer\(/);
 assert.match(source,/timeout: 480/);
 assert.match(source,/XCTAssertGreaterThan\(playback.finishTime - playback.started, 60\)/);
});
test('fixture and all installed phrases remain labelled authored and hash actual UTF8 bytes',()=>{
 for(const x of ['SHA256.hash(data: Data(fixture.utf8))','installedPhrases = reader.phrases.map','fixtureUTF8SHA256','ledgerDeadline','voiceEvidenceLimit','acquisition']) assert.ok(source.includes(x),x);
 assert.doesNotMatch(source,/String\(repeating: "a", count: 64\)/);
});
test('runner is fixed once, exact clean source, fresh owned simulator; failures retained',()=>{
 const runner=read('run-native.sh');
 assert.match(runner,/status --porcelain --untracked-files=all -- BlindCore/);
 assert.match(runner,/rev-parse HEAD/);
 assert.equal((runner.match(/xcodebuild -project/g)||[]).length,1);
 assert.match(runner,/simctl create/); assert.match(runner,/simctl delete "\$sim"/);
 assert.doesNotMatch(runner,/rm -rf|retry-tests|test-iterations|simctl erase/);
 assert.match(runner,/\(1,1,0,0\)/);
 assert.match(read('native-reading-component.yml'),/if: always\(\)/);
});
test('evidence explicitly excludes app integration and installed-asset proof',()=>{
 const docs=read('README.md');
 for(const x of ['not an app/controller/Feedback/camera test','not the production controller','does not prove installed assets','individual speech callback lasting over 60 seconds']) assert.ok(docs.includes(x),x);
});
