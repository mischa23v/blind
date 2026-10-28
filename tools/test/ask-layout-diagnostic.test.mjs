// Source/mutation checks, not native rendering or physical-navigation evidence.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { assertFullAuditDestinations } from './helpers/full-audit-contract.mjs';
const read = p => readFileSync(new URL('../../' + p, import.meta.url), 'utf8');
const ui = read('ios/BlindAssistUITests/LaunchTests.swift');
const runner = read('tools/ci/practice-layout-diagnostic.sh');
const exporter = read('tools/ci/export-practice-layout-screenshots.py');
function guardAsk(source, shell, python) {
 const probe = source.match(/private func recordAskLayout\(sizeName: String\) \{([\s\S]*?)\n    \}\n    @MainActor/)?.[1];
 assert.ok(probe);
 assert.ok(source.includes('recordPracticeFooterEnd(footerElement, expectedLabel: footer, sizeName: sizeName)\n        recordAskLayout(sizeName: sizeName)'));
 assert.ok(probe.includes('openSettingsPage("ask-screen")'));
 assert.ok(probe.includes('app.buttons["local-answer"]'));
 assert.ok(probe.includes('app.staticTexts["local-answer-unavailable-reason"]'));
 assert.ok(probe.includes('let expectedReason = "Camera monitoring is not running. Open Camera and safety to start it."'));
 assert.ok(probe.includes('XCTAssertFalse(action.isEnabled'));
 assert.ok(probe.includes('XCTAssertEqual(reason.label, expectedReason)'));
 assert.ok(probe.includes('reason.frame.maxY > navigation.frame.maxY && reason.frame.maxY <= tabs.frame.minY'));
 assert.ok(probe.includes('XCTAssertTrue(endIsVisible()'));
 assert.ok(probe.includes('recordPracticeLayoutAttachment(sizeName + "-ask-reason-end")'));
 assert.doesNotMatch(probe,/\.tap\(|launchArguments|launchEnvironment|performAccessibilityAudit|continueAfterFailure/);
 assert.ok(shell.includes('for size in large accessibility-extra-extra-extra-large; do'));
 assert.ok(shell.includes('xcrun simctl ui "$device" content_size "$size"'));
 assert.ok(shell.includes('ASK_LAYOUT afterReveal.*role=ask-reason'));
 assert.ok(shell.includes('ASK_LAYOUT reasonEnd.*endVisible=true'));
 assert.ok(python.includes("'ask-action', 'ask-reason', 'ask-reason-end'"));
 assert.ok(python.includes('set(selected) != set(expected)'));
 assert.ok(python.includes('32 * 1024 * 1024'));
 assertFullAuditDestinations(source);
}
test('same two system-size probes retain full Ask reason, disabled semantics and bounded seven-role export',()=>guardAsk(ui,runner,exporter));
for(const [name,from,to] of [
 ['full reason','Camera monitoring is not running. Open Camera and safety to start it.','Unavailable.'],
 ['disabled state','XCTAssertFalse(action.isEnabled','XCTAssertTrue(action.isEnabled'],
 ['tab-bar overlap','reason.frame.maxY <= tabs.frame.minY','true'],
 ['end reachability','XCTAssertTrue(endIsVisible()','XCTAssertTrue(true'],
 ['after-Practice visit','        recordAskLayout(sizeName: sizeName)','        // no Ask probe'],
]) test(name+' regression is rejected',()=>assert.throws(()=>guardAsk(ui.replaceAll(from,to),runner,exporter)));
test('missing size/endpoint/export coverage cannot pass source contract',()=>{
 assert.throws(()=>guardAsk(ui,runner.replace('for size in large accessibility-extra-extra-extra-large; do','for size in large; do'),exporter));
 assert.throws(()=>guardAsk(ui,runner.replace('ASK_LAYOUT reasonEnd.*endVisible=true','ignored'),exporter));
 assert.throws(()=>guardAsk(ui,runner,exporter.replace("'ask-action', 'ask-reason', 'ask-reason-end'","'ask-action'")));
});
