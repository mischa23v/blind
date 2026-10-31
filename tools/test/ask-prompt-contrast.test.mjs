// Source contracts only: semantic primary prompts do not establish a native audit pass.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { assertFullAuditDestinations } from './helpers/full-audit-contract.mjs';

const read = path => readFileSync(new URL(`../../${path}`, import.meta.url), 'utf8');
const dashboard = read('ios/BlindAssist/DashboardView.swift');
const ui = read('ios/BlindAssistUITests/LaunchTests.swift');
const fields = [
  ['Your question', 'سؤالك', 'assistantQuestion', 'Question or target', 'السؤال أو الهدف'],
  ['New goal, for example: the bathroom', 'هدف جديد، مثلاً: الحمام', 'objectiveDraft', 'New goal', 'هدف جديد'],
];

function assertReadablePrompts(source) {
  const assistant = source.slice(source.indexOf('    private var assistant: some View {'),
    source.indexOf('        .navigationTitle(t("Ask and goals",'));
  assert.ok(assistant.length > 0, 'The real Ask destination remains present');
  for (const [english, arabic, binding, label, arabicLabel] of fields) {
    const expected = `TextField(t("${english}", "${arabic}"), text: $model.${binding},\n` +
      `                    prompt: Text(t("${english}", "${arabic}")).foregroundColor(.primary), axis: .vertical)\n` +
      `                    .accessibilityLabel(t("${label}", "${arabicLabel}"))`;
    assert.ok(assistant.includes(expected), `${binding} keeps its complete bilingual prompt, binding, primary color, vertical growth and accessibility label`);
  }
  assert.doesNotMatch(assistant, /\.minimumScaleFactor\(|\.dynamicTypeSize\(|\.clipped\(|\.accessibilityHidden\(/,
    'Do not hide or shrink text to address contrast');
}

test('both enabled Ask text fields use explicit semantic primary prompts', () => {
  assertReadablePrompts(dashboard);
});

test('contrast change retains the full native audit and its existing decisions', () => {
  assertFullAuditDestinations(ui);
});

test('prompt guard rejects removal or lower-emphasis coloring of either prompt', () => {
  for (const [english, arabic] of fields) {
    const prompt = `prompt: Text(t("${english}", "${arabic}")).foregroundColor(.primary), `;
    assert.throws(() => assertReadablePrompts(dashboard.replace(prompt, '')));
    assert.throws(() => assertReadablePrompts(dashboard.replace(prompt, prompt.replace('.primary', '.secondary'))));
  }
});

test('prompt guard rejects shortened labels, a changed binding, or a changed accessible name', () => {
  for (const [english, arabic, binding, label, arabicLabel] of fields) {
    for (const [from, to] of [[english, 'Short'], [arabic, 'قصير'],
      [`$model.${binding}`, '$model.other'],
      [`.accessibilityLabel(t("${label}", "${arabicLabel}"))`, '.accessibilityLabel("Other")']]) {
      assert.throws(() => assertReadablePrompts(dashboard.replace(from, to)), from);
    }
  }
});

test('prompt guard rejects hiding or shrinking the Ask form content', () => {
  const anchor = '.accessibilityLabel(t("New goal", "هدف جديد"))';
  for (const modifier of ['.minimumScaleFactor(0.5)', '.dynamicTypeSize(.large)', '.clipped()', '.accessibilityHidden(true)']) {
    assert.throws(() => assertReadablePrompts(dashboard.replace(anchor, anchor + modifier)), modifier);
  }
});
