// Source contract only, not an execution or accessibility acceptance claim.
import assert from 'node:assert/strict';

export function assertFullAuditDestinations(ui) {
  const helper = ui.match(/^    private func auditFullDestination\(_ phase: String, title: String, requiredControl: String\) throws \{\n([\s\S]*?)^    \}/m);
  assert.ok(helper, 'Shared full audit helper exists');
  const destination = ui.match(/^    func testAccessibilityAuditOfCameraAndAsk\(\) throws \{\n([\s\S]*?)^    \}/m);
  assert.ok(destination, 'Original Camera and Ask test exists');
  // Exact active call path, rather than counting guard text in two old copies.
  assert.equal(destination[1].trim(), `openSettingsPage("camera-screen")
        try auditFullDestination("camera", title: "Camera and safety", requiredControl: "monitor-toggle")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let ask = app.buttons["ask-screen"]
        reveal(ask); ask.tap()
        try auditFullDestination("ask", title: "Ask and goals", requiredControl: "local-answer")`);
  // Reject early returns, throws or conditional bypasses before the real audit.
  assert.equal(helper[1].split('        try app.performAccessibilityAudit { issue in')[0].trim(), "let previousContinueAfterFailure = continueAfterFailure\n        defer {\n            // Keep the original audit failure, but allow its after-state evidence\n            // to be retained before restoring this test's fail-fast policy.\n            recordFullAuditEvidence(phase, \"after\")\n            continueAfterFailure = previousContinueAfterFailure\n        }\n        // Required destination UI, not a sleep, scroll, altered state or audit exemption.\n        let titleReady = app.navigationBars[title].waitForExistence(timeout: 10)\n        let controlReady = app.buttons[requiredControl].waitForExistence(timeout: 10)\n        print(\"ACCESSIBILITY_AUDIT_READINESS phase=\\(phase) titleReady=\\(titleReady) controlReady=\\(controlReady)\")\n        recordFullAuditEvidence(phase, \"before\")\n        XCTAssertTrue(titleReady, \"Expected destination navigation title\")\n        XCTAssertTrue(controlReady, \"Expected destination control\")\n        // XCTest records audit failures normally; only abort-on-first-failure is\n        // delayed inside this scope so the diagnostic defer can execute.\n        continueAfterFailure = true\n        var observedFindings = 0");
  const callback = helper[1].match(/        try app\.performAccessibilityAudit \{ issue in\n([\s\S]*?)        \}\s*$/);
  assert.ok(callback, 'Both destinations use the unchanged default-all audit');
  // Only the existing bounded diagnostic print/comment may precede the guard.
  // Any extra return, broader condition or additional exemption fails closed.
  const diagnosticPrint = "print(\"ACCESSIBILITY_AUDIT=type:\\(issue.auditType),phase:\\(phase),compact:\\(issue.compactDescription.prefix(2048)),detailed:\\(issue.detailedDescription.prefix(4096)),element:\\(String((issue.element?.debugDescription ?? \"unidentified\").prefix(1200)).replacingOccurrences(of: \"\\n\", with: \" | \"))\")";
  const capture = "            self.recordAuditIssueObservation(issue, phase: phase, observedFindings: &observedFindings)\n";
  assert.ok(callback[1].includes(capture), 'Bounded observation precedes unchanged decision');
  const decision = callback[1].replace(capture, '').split('\n').filter(line => line.trim() !== diagnosticPrint && line.trim() !== '// WCAG exempts inactive controls; retain every other audit finding.').join('\n').trim();
  assert.equal(decision, `guard issue.auditType == .contrast, let element = issue.element else { return false }
            return element.identifier == "retrace-session" && !element.isEnabled`);
  assert.equal(ui.match(/guard issue.auditType == \.contrast, let element = issue.element else \{ return false \}/g)?.length, 1);
  assert.doesNotMatch(helper[1], /performAccessibilityAudit\(for:|\.dynamicType|\.hitRegion|XCTSkip|return true/);
  assert.match(ui, /continueAfterFailure = false/);
}
