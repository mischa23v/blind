// Source regression only; does not execute SwiftUI layout or certify Dynamic Type.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const view = readFileSync(new URL('../../ios/BlindAssist/DashboardView.swift', import.meta.url), 'utf8');
function assertHeader(source) {
  const match = source.match(/Text\(t\("Practice", "التدريب"\)\)([\s\S]*?)\}\s*footer:/);
  assert.ok(match, 'Bilingual Practice header remains in its section');
  const modifiers = match[1];
  assert.match(modifiers, /\.font\(\.body\.weight\(\.semibold\)\)/);
  assert.match(modifiers, /\.lineLimit\(nil\)/);
  assert.match(modifiers, /\.fixedSize\(horizontal: false, vertical: true\)/);
  assert.match(modifiers, /\.multilineTextAlignment\(\.leading\)/);
  assert.doesNotMatch(modifiers, /dynamicTypeSize|minimumScaleFactor|accessibilityHidden|frame\(height/);
}
test('Practice heading has an explicit scalable semantic font and unconstrained vertical text', () => {
  assertHeader(view);
  for (const modifier of ['.font(.body.weight(.semibold))', '.lineLimit(nil)', '.fixedSize(horizontal: false, vertical: true)', '.multilineTextAlignment(.leading)']) {
    const start = view.indexOf('Text(t("Practice", "التدريب"))');
    const mutated = view.slice(0, start) + view.slice(start).replace(modifier, '');
    assert.throws(() => assertHeader(mutated), {name: 'AssertionError'});
  }
});
test('original diagnosed plain heading fails the new contract', () => {
  assert.throws(() => assertHeader('Text(t("Practice", "التدريب")) } footer:'), {name: 'AssertionError'});
});
test('camera audit still executes and does not suppress Dynamic Type findings', () => {
  const ui = readFileSync(new URL('../../ios/BlindAssistUITests/LaunchTests.swift', import.meta.url), 'utf8');
  assert.match(ui, /func testAccessibilityAuditOfCameraAndAsk\(\) throws/);
  assert.match(ui, /try app\.performAccessibilityAudit/);
  assert.equal(ui.match(/guard issue.auditType == \.contrast, let element = issue.element else \{ return false \}/g)?.length, 2);
  assert.doesNotMatch(ui, /issue.auditType == \.dynamicType/);
});
