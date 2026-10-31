// Source contracts only: these do not render SwiftUI or establish an audit pass.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { assertFullAuditDestinations } from './helpers/full-audit-contract.mjs';

const read = path => readFileSync(new URL(`../../${path}`, import.meta.url), 'utf8');
const dashboard = read('ios/BlindAssist/DashboardView.swift');
const ui = read('ios/BlindAssistUITests/LaunchTests.swift');
const expected = [
  ['Everything in view', 'كل ما في الصورة', 'surroundings'],
  ['Room layout', 'تخطيط الغرفة', 'room'],
  ['People', 'الأشخاص', 'people'],
  ['One object', 'غرض واحد', 'object'],
  ['Path features', 'معالم المسار', 'path'],
  ['Read text', 'قراءة النص', 'text'],
];

function focusPicker(source) {
  const start = source.indexOf('                Picker(t("Look at", "انظر إلى"), selection: $focus) {');
  const end = source.indexOf('                Button(t("Ask about the camera view",', start);
  assert.ok(start >= 0 && end > start, 'Native labelled focus picker precedes the camera question action');
  return source.slice(start, end);
}

function assertFocusLayout(source) {
  const picker = focusPicker(source);
  const options = [...picker.matchAll(/Text\(t\("([^"]+)", "([^"]+)"\)\)\.tag\("([^"]+)"\)/g)];
  assert.deepEqual(options.map(match => match.slice(1)), expected,
    'Keep every complete English/Arabic label and its original selection tag');
  assert.equal(picker.match(/\.pickerStyle\(\.inline\)/g)?.length, 1,
    'Use native inline selection rows, not the compressed trailing menu value');
  for (const option of options) {
    assert.ok(picker.includes(option[0] + '\n                        .lineLimit(nil)\n                        .fixedSize(horizontal: false, vertical: true)'),
      `${option[1]} must wrap at the offered width and grow vertically`);
  }
  assert.doesNotMatch(picker,
    /\.frame\(|\.clipped\(|\.minimumScaleFactor\(|\.dynamicTypeSize\(|\.environment\(|\.font\(|\.labelsHidden\(|\.accessibilityHidden\(|\.accessibilityElement\(|\.accessibilityLabel\(/,
    'No fixed bounds, text shrink/cap, hidden label, or substituted accessibility text');
}

test('Ask focus uses native selection with six complete multiline bilingual rows', () => {
  assertFocusLayout(dashboard);
});

test('default focus and the real camera question action retain the same binding', () => {
  assert.match(dashboard, /@State private var focus = "surroundings"/);
  assert.match(dashboard, /model\.readScene\(cloud: false, question: sceneQuestion, focus: focus\)/);
  assert.match(dashboard, /\.disabled\(model\.busy \|\| model\.simulation \|\| !model\.running\)/);
  assert.match(dashboard, /\.environment\(\\\.layoutDirection, model\.arabic \? \.rightToLeft : \.leftToRight\)/);
});

test('Camera and Ask still execute their full default accessibility audits', () => {
  assertFullAuditDestinations(ui);
});

test('source guard rejects removing or abbreviating the audited label', () => {
  assert.throws(() => assertFocusLayout(dashboard.replace('Everything in view', 'Everything')));
  assert.throws(() => assertFocusLayout(dashboard.replace('كل ما في الصورة', 'الصورة')));
});

test('source guard rejects shrinking, clipping, or removing native inline layout', () => {
  const picker = focusPicker(dashboard);
  for (const replacement of ['.pickerStyle(.menu)', '.lineLimit(1)', '.minimumScaleFactor(0.5)', '.dynamicTypeSize(...DynamicTypeSize.large)', '.accessibilityHidden(true)']) {
    assert.throws(() => assertFocusLayout(dashboard.replace(picker, picker.replace('.pickerStyle(.inline)', replacement))), replacement);
  }
});

test('source guard rejects loss of intrinsic text height on any option', () => {
  const picker = focusPicker(dashboard);
  for (const option of expected) {
    const label = `Text(t("${option[0]}", "${option[1]}")).tag("${option[2]}")`;
    const broken = picker.replace(label + '\n                        .lineLimit(nil)\n                        .fixedSize(horizontal: false, vertical: true)', label);
    assert.throws(() => assertFocusLayout(dashboard.replace(picker, broken)), option[0]);
  }
});

test('full audit guard rejects a clipping exemption or Ask audit removal', () => {
  assert.throws(() => assertFullAuditDestinations(ui.replace(
    'guard issue.auditType == .contrast, let element = issue.element else { return false }',
    'if issue.auditType == .textClipped { return true }\n            guard issue.auditType == .contrast, let element = issue.element else { return false }')));
  assert.throws(() => assertFullAuditDestinations(ui.replace('try auditFullDestination("ask",', '// try auditFullDestination("ask",')));
});
