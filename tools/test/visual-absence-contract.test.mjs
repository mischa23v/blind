import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { groundedDescription, agreedObjects } from '../../server/src/companion-guards.mjs';
const root = new URL('../../', import.meta.url);
const read = p => readFileSync(new URL(p, root), 'utf8');
const cases = JSON.parse(read('BlindCore/Tests/BlindCoreTests/Fixtures/companion-evidence.json')).grounding.slice(-20);
test('unobserved empty/absent/departed claims stay withheld even with detected objects and hedging', () => {
  assert.equal(cases.length, 20);
  for (const row of cases.slice(0, 16)) {
    assert.equal(row.expect, ''); assert.equal(groundedDescription(row.text, agreedObjects(row.frames)), '', row.text);
  }
});
test('actual agreed positive observations and uncertainty remain usable', () => {
  for (const row of cases.slice(16)) assert.equal(groundedDescription(row.text, agreedObjects(row.frames)), row.expect, row.text);
});
test('Swift and JavaScript share exact new absence patterns and check them before hedging', () => {
  const swift = read('BlindCore/Sources/BlindCore/VisualGrounding.swift'), js = read('server/src/companion-guards.mjs');
  const swiftPattern = name => swift.match(new RegExp(`let ${name} = regex\\(#"([^\\n]+)"#\\)`))?.[1];
  const jsPattern = name => js.match(new RegExp(`const ${name} = /([^\\n]+)/i?;`))?.[1];
  assert.ok(swiftPattern('emptyView')); assert.ok(swiftPattern('arabicEmptyView'));
  assert.equal(swiftPattern('emptyView'), jsPattern('EMPTY_VIEW'));
  assert.equal(swiftPattern('arabicEmptyView'), jsPattern('AR_EMPTY_VIEW'));
  const swiftGuard = swift.slice(swift.indexOf('public static func groundedDescription'));
  assert.ok(swiftGuard.indexOf('isAbsenceClaim(sentence)') < swiftGuard.indexOf('isHedged(sentence)'));
  const jsGuard = js.slice(js.indexOf('export function groundedDescription'));
  assert.ok(jsGuard.indexOf('isAbsenceClaim(sentence)') < jsGuard.indexOf('hedged(sentence)'));
});
