import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { containsSpatialClaim } from '../src/spatial-guard.mjs';
const fixture = JSON.parse(await readFile(new URL('../../BlindCore/Tests/BlindCoreTests/Fixtures/spatial-claims.json', import.meta.url), 'utf8'));
test('authored ordinary conversation additions preserve the entire shared Swift/Node spatial fixture', () => {
  for (const text of fixture.blocked) assert.equal(containsSpatialClaim(text), true, text);
  for (const text of fixture.allowed) assert.equal(containsSpatialClaim(text), false, text);
});
test('all authored spoken-equivalent dash variants preserve physical blocking', () => {
  for (const dash of ['-', '‐', '‑', '‒', '–', '—', '−']) {
    for (const template of ['A lamp in-front-of you.', 'The object is within-your-hands.', 'Light-the-candle.', 'Heat-the-milk.', 'The-path-is-clear.']) {
      const text = template.replaceAll('-', dash);
      assert.equal(containsSpatialClaim(text), true, text);
    }
  }
});
