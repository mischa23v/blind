import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
const root = new URL('../diagnostics/PracticeLayoutHost/', import.meta.url);
const read = p => fs.readFileSync(new URL(p, root), 'utf8');
const host = read('PracticeLayoutHost.swift');
const tests = read('PracticeLayoutHostUITests/ComparisonTests.swift');
const project = read('PracticeLayoutHost.xcodeproj/project.pbxproj');

test('fixed independent 12 audit and 3 endpoint test selectors', () => {
  const expected = [];
  for (const variant of ['A','B','C']) {
    for (const kind of ['DynamicType','HitRegion'])
      for (const repetition of [1,2]) expected.push('test'+variant+'_'+kind+'_'+repetition);
    expected.push('test'+variant+'_Endpoint');
  }
  assert.deepEqual([...tests.matchAll(/func (test\w+)\(/g)].map(m=>m[1]).sort(), expected.sort());
});
test('all audit issues are unsuppressed and public descriptions bounded', () => {
  assert.match(tests,/performAccessibilityAudit\(for: type\)/);
  assert.match(tests,/compactDescription\.prefix\(2048\)/);
  assert.match(tests,/detailedDescription\.prefix\(4096\)/);
  assert.match(tests,/return false/);
  assert.doesNotMatch(tests,/return true|XCTSkip|issue\.auditType\s*==/);
});
test('after screenshot retained through audit throw', () => {
  assert.match(tests,/defer \{\s*capture\(app, prefix \+ "-after"\)\s*app\.terminate\(\)/);
  assert.match(tests,/image\.lifetime = \.keepAlways/);
  assert.match(tests,/continueAfterFailure = true/);
});
test('static isolated host has no model, packages, network, storage, permission request', () => {
  assert.doesNotMatch(host,/NavigationModel|URLSession|UserDefaults|FileManager|AVCapture|requestAuthorization|import BlindCore/);
  assert.doesNotMatch(project,/XCRemoteSwiftPackage|BlindAssist\.app|BlindCore/);
  assert.doesNotMatch(host,/minHeight|minWidth|buttonStyle/);
});
test('common presentation and category validation remain explicit', () => {
  for (const token of ['.preferredColorScheme(.dark)', '.navigationTitle("Camera and safety")',
    '.environment(\\.layoutDirection, .leftToRight)', 'UIApplication.shared.preferredContentSizeCategory.rawValue == expected'])
    assert.ok(host.includes(token), token);
  assert.match(tests,/XCTAssertEqual\(UIApplication.shared.preferredContentSizeCategory, category\)/);
});
test('fixed bounded endpoint does not reverse or require full footer fit', () => {
  assert.match(tests,/for step in 0\.\.<8/);
  assert.doesNotMatch(tests,/swipeDown|sleep\(|footer\.frame\.minY/);
  assert.match(tests,/bottom <= app\.windows\.firstMatch\.frame\.maxY - 34/);
  assert.match(tests,/XCTAssertTrue\(endpointVisible/);
});
test('project references resolve and app/UI test dependency is explicit', () => {
  const defined = new Set([...project.matchAll(/^([0-9A-F]{24}) = /gm)].map(m=>m[1]));
  const referenced = [...project.matchAll(/\b[0-9A-F]{24}\b/g)].map(m=>m[0]);
  for (const id of referenced) assert.ok(defined.has(id), id);
  assert.match(project,/productType = "com.apple.product-type.bundle.ui-testing"/);
  assert.match(project,/TEST_TARGET_NAME = PracticeLayoutHost/);
});
