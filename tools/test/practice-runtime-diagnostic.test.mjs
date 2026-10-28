// Source contracts and mutations, not a native timing or accessibility result.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const read = p => readFileSync(new URL('../../' + p, import.meta.url), 'utf8');
const model = read('ios/BlindAssist/NavigationModel.swift');
const ui = read('ios/BlindAssistUITests/LaunchTests.swift');
function guardTrace(model, ui) {
 const diagnostic = model.slice(model.indexOf('private final class PracticeRuntimeDiagnostic'));
 assert.ok(diagnostic.length > 0);
 assert.ok(model.includes('#if DEBUG\n/// Synthetic UI-test metadata only.'));
 for(const gate of ['process.arguments.contains("--ui-testing")', 'process.arguments.contains("--practice-runtime-diagnostic")',
  'process.environment["BLIND_PRACTICE_TRACE_TEST"] == PracticeRuntimeDiagnostic.testID',
  'UUID(uuidString: process.environment["BLIND_PRACTICE_TRACE_RUN"] ?? "")']) assert.ok(model.includes(gate),gate);
 assert.doesNotMatch(diagnostic,/@Published|objectWillChange|\.send\(|UserDefaults|cameraImage|pixelBuffer|imageData|assistantQuestion|currentReply|sceneAnswer/);
 assert.ok(diagnostic.includes('state.snapshots < 32'));
 assert.ok(diagnostic.includes('state.events.count < 16'));
 assert.ok(diagnostic.includes('data.count <= 16 * 1024'));
 assert.ok(diagnostic.includes('nextTickSnapshot = finish + 10'));
 assert.ok(diagnostic.indexOf('queue.async {') < diagnostic.indexOf('try data.write'));
 const setup = ui.match(/override func setUpWithError\(\) throws \{([\s\S]*?)\n    \}/)?.[1];
 const practice = ui.match(/func testPracticeIsAnnouncedAndCanStop\(\) \{([\s\S]*?)\n    \}/)?.[1];
 assert.ok(setup && practice);
 assert.doesNotMatch(setup,/practice-runtime-diagnostic|BLIND_PRACTICE_TRACE|PRACTICE_RUNTIME_RUN/);
 assert.doesNotMatch(ui,/if name ==/);
 assert.equal(ui.split('app.launchArguments.append("--practice-runtime-diagnostic")').length,2);
 assert.equal(ui.split('print("PRACTICE_RUNTIME_RUN test=').length,2);
 const configured = practice.indexOf('app.launchArguments.append("--practice-runtime-diagnostic")');
 const launched = practice.indexOf('app.launch()');
 const navigated = practice.indexOf('openSettingsPage("camera-screen")');
 assert.ok(practice.indexOf('let runID = UUID().uuidString') >= 0 && practice.indexOf('let runID = UUID().uuidString') < configured);
 assert.ok(practice.indexOf('app.terminate()') >= 0 && practice.indexOf('app.terminate()') < configured);
 assert.ok(configured >= 0 && launched > configured && navigated > launched);
 assert.ok(practice.slice(configured,launched).includes('app.launchEnvironment["BLIND_PRACTICE_TRACE_TEST"] = "LaunchTests/testPracticeIsAnnouncedAndCanStop"'));
 assert.ok(practice.slice(configured,launched).includes('app.launchEnvironment["BLIND_PRACTICE_TRACE_RUN"] = runID'));
 assert.ok(practice.slice(configured,launched).includes('print("PRACTICE_RUNTIME_RUN test=LaunchTests/testPracticeIsAnnouncedAndCanStop run=\\(runID)")'));
 assert.doesNotMatch(practice.slice(navigated),/app\.launch\(|app\.terminate\(|launchArguments|launchEnvironment/);
 assert.ok(ui.includes('app.launchEnvironment["BLIND_PRACTICE_TRACE_TEST"] = "LaunchTests/testPracticeIsAnnouncedAndCanStop"'));
 assert.ok(ui.includes('let cancellationEvidenceLimit: TimeInterval = 90'));
 assert.equal((ui.match(/XCTAssertLessThan\(.*(?:\n[^\n]*)?/g)||[]).filter(x=>x.includes('cancellationEvidenceLimit')).length,2);
 assert.ok(ui.includes('        end.tap()\n        XCTAssertFalse(practiceStatus.exists)'));
 assert.ok(model.includes('Timer.scheduledTimer(withTimeInterval: 120, repeats: false)'));
}
test('Practice diagnostic remains explicit, metadata-only, bounded and off the UI publication path',()=>guardTrace(model,ui));
for(const [name,from,to] of [
 ['UI gate','process.arguments.contains("--ui-testing")','true'],
 ['explicit gate','process.arguments.contains("--practice-runtime-diagnostic")','true'],
 ['test identity','process.environment["BLIND_PRACTICE_TRACE_TEST"] == PracticeRuntimeDiagnostic.testID','true'],
 ['write cadence','nextTickSnapshot = finish + 10','nextTickSnapshot = finish'],
 ['snapshot bound','state.snapshots < 32','true'],
 ['payload bound','data.count <= 16 * 1024','true'],
 ['production expiry','Timer.scheduledTimer(withTimeInterval: 120, repeats: false)','Timer.scheduledTimer(withTimeInterval: 240, repeats: false)'],
]) test(name+' weakening is rejected',()=>assert.throws(()=>guardTrace(model.replace(from,to),ui)));
test('real End tap and evidence deadline cannot be substituted',()=>{
 assert.throws(()=>guardTrace(model,ui.replace('        end.tap()','        // no tap')));
 assert.throws(()=>guardTrace(model,ui.replace('let cancellationEvidenceLimit: TimeInterval = 90','let cancellationEvidenceLimit: TimeInterval = 180')));
});

test('only the explicit Practice test may relaunch with the diagnostic nonce',()=>{
 assert.throws(()=>guardTrace(model,ui.replace('func testPracticeIsAnnouncedAndCanStop()', 'func testOtherPractice()')));
 assert.throws(()=>guardTrace(model,ui.replace('        app.launchArguments.append("--practice-runtime-diagnostic")','        // diagnostic not configured')));
 assert.throws(()=>guardTrace(model,ui.replace('        app.terminate()','        // stale instance')));
 assert.throws(()=>guardTrace(model,ui.replace('        end.tap()', '        app.launch()\n        end.tap()')));
});
