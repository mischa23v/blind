import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { parseUtterance, containsUnsupportedClaim, supportedText, agreedObjects, groundedDescription } from '../src/companion-guards.mjs';

// Same shared fixture as BlindCore CompanionEvidenceTests, so Node and Swift cannot drift apart.
const fixture = JSON.parse(await readFile(new URL('../../BlindCore/Tests/BlindCoreTests/Fixtures/companion-evidence.json', import.meta.url), 'utf8'));

test('child find requests and location reports are parsed by code', () => {
  for (const { text, expect } of fixture.utterances) assert.deepEqual(parseUtterance(text), expect, text);
});

test('chat replies cannot assert current location, presence, absence or perception', () => {
  for (const text of fixture.claims.unsupported) assert.equal(containsUnsupportedClaim(text), true, text);
  for (const text of fixture.claims.allowed) assert.equal(containsUnsupportedClaim(text), false, text);
});

test('unsupported sentences are dropped and the rest kept', () => {
  assert.equal(supportedText('Your cup is not found. Where did you last have it?'), 'Where did you last have it?');
  assert.equal(supportedText('Your cup is on the kitchen table.'), '');
});

test('image descriptions keep only hedged or detector-agreed objects', () => {
  for (const { text, frames, expect } of fixture.grounding) {
    assert.equal(groundedDescription(text, agreedObjects(frames)), expect, text);
  }
});
