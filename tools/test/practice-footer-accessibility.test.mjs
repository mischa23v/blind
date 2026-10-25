// Source contracts only; actual Apple Dynamic Type audit remains required.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const view = readFileSync(new URL('../../ios/BlindAssist/DashboardView.swift', import.meta.url), 'utf8');
function assertFooter(source) {
 const start = source.indexOf('Text(t("Practice pauses live sensors');
 assert.ok(start >= 0);
 const text = source.slice(start, source.indexOf('\n            }', start));
 assert.match(text, /Keep using your cane or guide dog\./);
 assert.match(text, /واصل استخدام العصا أو كلب الإرشاد/);
 for (const modifier of ['.font(.body)', '.lineLimit(nil)', '.fixedSize(horizontal: false, vertical: true)', '.multilineTextAlignment(.leading)']) assert.ok(text.includes(modifier), modifier);
 assert.doesNotMatch(text, /dynamicTypeSize|minimumScaleFactor|accessibilityHidden|frame\(height/);
}
test('actual diagnosed practice footer scales and wraps without removing safety text', () => {
 assertFooter(view);
 const start = view.indexOf('Text(t("Practice pauses live sensors');
 for (const modifier of ['.font(.body)', '.lineLimit(nil)', '.fixedSize(horizontal: false, vertical: true)', '.multilineTextAlignment(.leading)']) {
  const mutation = view.slice(0,start) + view.slice(start).replace(modifier,'');
  assert.throws(() => assertFooter(mutation), {name:'AssertionError'});
 }
});
test('original plain footer is rejected by source contract', () => {
 assert.throws(() => assertFooter('Text(t("Practice pauses live sensors. Keep using your cane or guide dog.", "واصل استخدام العصا أو كلب الإرشاد"))\n            }'), {name:'AssertionError'});
});
