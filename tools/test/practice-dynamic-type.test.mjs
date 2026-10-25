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
  assertDiagnosticFailurePropagation(workflow);
  for (const mutation of [
    workflow.replace('      - name: Retain diagnostic failure status\n        if: always() && steps.layout.outcome != \'success\'\n        run: exit 1\n', ''),
    workflow.replace('        run: exit 1', '        run: exit 0'),
    workflow.replace('    runs-on: xcode-27', '    continue-on-error: true\n    runs-on: xcode-27'),
    workflow.replace('        run: bash tools/ci/native-apple.sh ui-diagnostic', '        continue-on-error: true\n        run: bash tools/ci/native-apple.sh ui-diagnostic'),
    workflow.replace('        if: always()\n        run: bash tools/ci/native-apple.sh ui-diagnostic', '        run: bash tools/ci/native-apple.sh ui-diagnostic'),
    workflow.replace('          if-no-files-found: error', '          if-no-files-found: warn'),
  ]) {
    assert.notEqual(mutation, workflow);
    assert.throws(() => assertDiagnosticFailurePropagation(mutation), {name: 'AssertionError'});
  }
});

// The layout recorder may continue solely to let the original audit execute.
// Its failure is restored at the end; neither job nor audit is allowed to pass it.
function assertDiagnosticFailurePropagation(workflow) {
  assert.doesNotMatch(workflow, /cancel-in-progress: true/);
  const [preamble, ...steps] = workflow.split(/^      - /m);
  assert.doesNotMatch(preamble, /continue-on-error:/);
  const layouts = steps.filter(step => /^        id: layout$/m.test(step));
  assert.equal(layouts.length, 1);
  const layout = layouts[0];
  assert.match(layout, /^        continue-on-error: true$/m);
  assert.match(layout, /^        run: bash tools\/ci\/practice-layout-diagnostic.sh$/m);
  for (const step of steps) if (step !== layout) assert.doesNotMatch(step, /continue-on-error:/);
  assert.equal(workflow.match(/continue-on-error:/g)?.length, 1);
  const audits = steps.filter(step => /^        run: bash tools\/ci\/native-apple.sh ui-diagnostic$/m.test(step));
  assert.equal(audits.length, 1);
  assert.match(audits[0], /^        if: always\(\)$/m);
  const final = steps[steps.length - 1];
  assert.match(final, /^        if: always\(\) && steps.layout.outcome != 'success'$/m);
  assert.match(final, /^        run: exit 1$/m);
  assert.ok(steps.indexOf(audits[0]) < steps.length - 1);
  const artifact = steps.find(step => step.includes('name: practice-layout-screenshots'));
  assert.ok(artifact);
  assert.match(artifact, /^        if: always\(\)$/m);
  assert.match(artifact, /^          if-no-files-found: error$/m);
}
