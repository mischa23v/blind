import {assertFullAuditDestinations} from './helpers/full-audit-contract.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
const ui = fs.readFileSync(new URL('../../ios/BlindAssistUITests/LaunchTests.swift', import.meta.url), 'utf8');
const helper = ui.slice(ui.indexOf('private func auditFullDestination'), ui.indexOf('func testOfflineCommunityLibrary'));
test('same full default audit scope and only existing disabled contrast exemption', () => {
  assert.match(helper, /try app\.performAccessibilityAudit \{ issue in/);
  assert.doesNotMatch(helper, /performAccessibilityAudit\(for:|\.dynamicType|\.hitRegion/);
  assert.match(helper, /guard issue\.auditType == \.contrast, let element = issue\.element else \{ return false \}/);
  assert.match(helper, /return element\.identifier == "retrace-session" && !element\.isEnabled/);
  assert.match(ui, /continueAfterFailure = false/);
});
test('destination readiness uses required UI and preserves failure', () => {
  assert.match(helper, /navigationBars\[title\]\.waitForExistence\(timeout: 10\)/);
  assert.match(helper, /buttons\[requiredControl\]\.waitForExistence\(timeout: 10\)/);
  assert.match(helper, /XCTAssertTrue\(titleReady/);
  assert.match(helper, /XCTAssertTrue\(controlReady/);
  assert.match(helper, /auditFullDestination\("camera", title: "Camera and safety", requiredControl: "monitor-toggle"\)/);
  assert.match(helper, /auditFullDestination\("ask", title: "Ask and goals", requiredControl: "local-answer"\)/);
});
test('before and deferred after captures; all callback descriptions bounded', () => {
  assert.match(helper, /defer \{ recordFullAuditEvidence\(phase, "after"\) \}/);
  assert.match(helper, /recordFullAuditEvidence\(phase, "before"\)/);
  assert.match(helper, /compactDescription\.prefix\(2048\)/);
  assert.match(helper, /detailedDescription\.prefix\(4096\)/);
  assert.match(ui, /attachment\.name = "full-audit-\\\(phase\)-\\\(point\)"/);
});
test('no retries, sleeps or state/style mutation in audit helper', () => {
  assert.doesNotMatch(helper, /sleep\(|retry\(|swipe|startSimulation|content_size|font\(|frame\(/);
  assert.match(ui, /XCTAssertTrue\(app\.launchArguments\.contains\("--ui-testing"\)\)/);
});
test('only known controls recorded; unavailable frames never read', () => {
  const capture = ui.slice(ui.indexOf('private func recordFullAuditEvidence'), ui.indexOf('private func auditFullDestination'));
  assert.match(capture, /if element\.exists \{/);
  assert.match(capture, /else \{\s*print\("ACCESSIBILITY_AUDIT_FRAME/);
  assert.doesNotMatch(capture, /app\.debugDescription|allElementsBoundByIndex/);
});

const observation = ui.slice(ui.indexOf('    private func recordAuditIssueObservation'), ui.indexOf('    @MainActor\n    private func auditFullDestination'));
function assertCallbackObservation(source) {
  assert.match(source, /guard app\.launchArguments\.contains\("--ui-testing"\),/);
  assert.match(source, /phase == "camera" \|\| phase == "ask" else \{ return \}/);
  const gate = 'if issue.auditType == .contrast, let element = issue.element,\n           element.identifier == "retrace-session", !element.isEnabled { return }';
  assert.ok(source.includes(gate), 'Only existing exemption bypasses observation');
  assert.ok(source.indexOf(gate) < source.indexOf('observedFindings += 1'), 'Ignored finding consumes no capture budget');
  assert.match(source, /guard observedFindings <= 2 else/);
  assert.match(source, /let index = observedFindings/);
  assert.match(source, /callback_observation_not_historical_failure_state/);
  assert.match(source, /XCTAttachment\(screenshot: app\.screenshot\(\)\)/);
  assert.match(source, /screenshot\.name = name \+ "-screen"/);
  assert.match(source, /attachment\.name = name \+ "-metadata"/);
  assert.match(source, /XCTAttachment\(data: data, uniformTypeIdentifier: "public.json"\)/);
  assert.equal(source.match(/try element\.snapshot\(\)/g)?.length, 1);
  assert.match(source, /if let element = issue\.element/);
  for (const key of ['identifier', 'label', 'elementType', 'frame', 'enabled']) assert.ok(source.includes('"'+key+'":'));
  assert.match(source, /"elementPresent": issue\.element != nil, "snapshotStatus": "not_available"/);
  assert.match(source, /metadata\["snapshotStatus"\] = "failed"/);
  assert.match(source, /metadata\["snapshotErrorType"\]/);
  assert.match(source, /data\.count > 16 \* 1024/);
  assert.match(source, /metadata\["metadataTruncated"\] = true/);
  assert.match(source, /ACCESSIBILITY_AUDIT_CAPTURE_ERROR/);
  assert.equal(source.match(/\.lifetime = \.keepAlways/g)?.length, 2);
  assert.doesNotMatch(source, /\.children\b|dictionaryRepresentation|children\(|debugDescription|waitFor|sleep\(|swipe|\.tap\(|performAccessibilityAudit|preferredContentSizeCategory|XCTFail|XCTSkip|throw error/);
}
test('bounded callback-time evidence uses one public root snapshot and no audit mutations', () => {
  assertCallbackObservation(observation);
  for (const [before,after] of [
    ['guard observedFindings <= 2', 'guard observedFindings <= 20'],
    ['issue.auditType == .contrast', 'issue.auditType == .dynamicType'],
    ['element.identifier == "retrace-session", !element.isEnabled', '!element.isEnabled'],
    ['app.launchArguments.contains("--ui-testing")', 'true'],
    ['callback_observation_not_historical_failure_state', 'historical_failure_state'],
    ['try element.snapshot()', 'try element.snapshot(); app.swipeUp()'],
    ['"snapshotStatus": "not_available"', '"snapshotStatus": "captured"'],
    ['data.count > 16 * 1024', 'data.count > 160 * 1024'],
    ['metadata["snapshotStatus"] = "failed"', 'throw error'],
  ]) {
    const mutation = observation.replace(before,after);
    assert.notEqual(mutation, observation);
    assert.throws(() => assertCallbackObservation(mutation), {name:'AssertionError'});
  }
});

test('callback cap and observation call cannot replace or bypass original decision', () => {
  assertFullAuditDestinations(ui);
  for (const [before, after] of [
    ['recordAuditIssueObservation(issue, phase: phase, observedFindings: &observedFindings)', ''],
    ['recordAuditIssueObservation(issue, phase: phase, observedFindings: &observedFindings)', 'return true'],
  ]) {
    const mutation = ui.replace(before, after);
    assert.notEqual(mutation, ui);
    assert.throws(() => assertFullAuditDestinations(mutation), {name:'AssertionError'});
  }
});
