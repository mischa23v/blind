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
