import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
const read = p => fs.readFileSync(new URL('../../'+p, import.meta.url), 'utf8');
const original = read('ios/BlindAssistUITests/LaunchTests.swift');
const typed = read('ios/BlindAssistUITests/CameraAuditScopeTests.swift');
const project = read('ios/BlindAssist.xcodeproj/project.pbxproj');
const gate = '        try XCTSkipUnless(ProcessInfo.processInfo.environment["BLIND_AUDIT_SCOPE_CONTROL"] == "1",\n                          "Diagnostic-only scope control; not ordinary UI acceptance")\n';
test('setup and navigation are identical apart from explicit opt-in gate', () => {
  const expected = original.slice(original.indexOf('    private var app:'), original.indexOf('    func testMainScreenContainsOnlyReplyAndTabButtons'));
  const observed = typed.slice(typed.indexOf('    private var app:'), typed.indexOf('    @MainActor\n    private func recordFullAuditEvidence')).replace(gate,'');
  assert.equal(observed, expected);
});
test('capture and readiness contract differs only in audit type and helper name', () => {
  const expected = original.slice(original.indexOf('    @MainActor\n    private func recordFullAuditEvidence'), original.indexOf('    @MainActor\n    func testAccessibilityAuditOfCameraAndAsk'));
  const observed = typed.slice(typed.indexOf('    @MainActor\n    private func recordFullAuditEvidence'), typed.indexOf('    @MainActor\n    func testCameraDynamicTypeOnly'))
    .replaceAll('auditDynamicTypeDestination','auditFullDestination')
    .replace('performAccessibilityAudit(for: .dynamicType)', 'performAccessibilityAudit');
  assert.equal(observed, expected);
});
test('original full audit and contrast exemption are still present', () => {
  assert.match(original, /try app\.performAccessibilityAudit \{ issue in/);
  assert.match(original, /try auditFullDestination\("camera", title: "Camera and safety", requiredControl: "monitor-toggle"\)/);
  assert.match(original, /try auditFullDestination\("ask", title: "Ask and goals", requiredControl: "local-answer"\)/);
  for (const source of [original,typed]) {
    assert.match(source, /guard issue\.auditType == \.contrast, let element = issue\.element else \{ return false \}/);
    assert.match(source, /return element\.identifier == "retrace-session" && !element\.isEnabled/);
    assert.match(source, /continueAfterFailure = false/);
  }
});
test('one new opt-in camera-only test; no regular-acceptance execution', () => {
  assert.equal([...typed.matchAll(/func test\w+\(/g)].length,1);
  assert.ok(typed.includes(gate));
  assert.ok(typed.indexOf(gate) < typed.indexOf('app.launch()'));
  assert.match(typed, /try auditDynamicTypeDestination\("camera", title: "Camera and safety", requiredControl: "monitor-toggle"\)/);
  assert.doesNotMatch(typed,/performAccessibilityAudit\(for: \.all\)|\.font\(|Thread\.sleep|Task\.sleep|startSimulation/);
});
test('source entry is in UI-test phase only', () => {
  assert.match(project,/46F2B9EA8552D92DF137AF80 = \{ isa = PBXFileReference;.*CameraAuditScopeTests.swift/);
  assert.match(project,/4906879117E546BCF3C42670 = \{ isa = PBXBuildFile; fileRef = 46F2B9EA8552D92DF137AF80/);
  const phases = project.split('\n').filter(l=>l.includes('isa = PBXSourcesBuildPhase'));
  assert.equal(phases.filter(l=>l.includes('4906879117E546BCF3C42670')).length,1);
  assert.ok(phases.find(l=>l.includes('4906879117E546BCF3C42670')).startsWith('760DD443C1DF2461277A1FDF'));
});
