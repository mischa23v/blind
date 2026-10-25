// Source regression only: real Apple accessibility auditing remains authoritative.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const read = path => readFile(new URL('../../' + path, import.meta.url), 'utf8');
function practiceLabel(source) {
  const end = source.indexOf('.accessibilityIdentifier("start-simulation")');
  assert.ok(end >= 0, 'Practice remains explicitly identifiable');
  const start = source.lastIndexOf('Button', end);
  assert.ok(start >= 0);
  return source.slice(start, end);
}
function assertFlexiblePractice(source) {
  const label = practiceLabel(source);
  assert.match(label, /Button \{ model.startSimulation\(\) \} label: \{/);
  assert.match(label, /Text\(t\("Try practice \(2 minutes\)", "جرب التدريب \(دقيقتان\)"\)\)/);
  assert.match(label, /\.font\(\.body\)/);
  assert.match(label, /\.lineLimit\(nil\)/);
  assert.match(label, /\.fixedSize\(horizontal: false, vertical: true\)/);
  assert.doesNotMatch(label, /frame\(height:|minimumScaleFactor|dynamicTypeSize\(/);
}
test('practice duration label grows vertically at larger Dynamic Type without changing its action', async () => {
  const source = await read('ios/BlindAssist/DashboardView.swift');
  assertFlexiblePractice(source);
  const label = practiceLabel(source);
  for (const mutation of [
    label.replace('.fixedSize(horizontal: false, vertical: true)', '.fixedSize(horizontal: false, vertical: false)'),
    label.replace('.lineLimit(nil)', '.lineLimit(1)'),
    label.replace('.font(.body)', '.font(.system(size: 17))'),
    'Button(t("Try practice (2 minutes)", "جرب التدريب (دقيقتان)")) { model.startSimulation() }\n',
  ]) {
    assert.notEqual(mutation, label);
    assert.throws(() => assertFlexiblePractice(source.replace(label, mutation)), {name: 'AssertionError'});
  }
  const audit = await read('ios/BlindAssistUITests/LaunchTests.swift');
  assert.doesNotMatch(audit, /issue.auditType == \.dynamicType/);
  assert.equal(audit.match(/guard issue.auditType == \.contrast, let element = issue.element else \{ return false \}/g)?.length, 2);
});
test('focused unsuppressed accessibility audit reruns for affected view and UI test changes', async () => {
  const workflow = await read('.github/workflows/accessibility-diagnostic.yml');
  for (const path of ['.github/workflows/accessibility-diagnostic.yml', 'ios/BlindAssist/DashboardView.swift', 'ios/BlindAssistUITests/LaunchTests.swift']) {
    assert.ok(workflow.includes("      - '" + path + "'"), path);
  }
  assert.match(workflow, /run: bash tools\/ci\/native-apple.sh ui-diagnostic/);
  assert.doesNotMatch(workflow, /continue-on-error|cancel-in-progress: true/);
});
