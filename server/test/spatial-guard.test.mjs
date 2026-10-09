import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { containsSpatialClaim } from '../src/spatial-guard.mjs';
import { createApp } from '../src/app.mjs';
import { SYSTEM, SYSTEM_COMPACT, systemFor } from '../src/scene-policy.mjs';

const fixture = JSON.parse(await readFile(new URL('../../BlindCore/Tests/BlindCoreTests/Fixtures/spatial-claims.json', import.meta.url), 'utf8'));
const config = { apiKey: 'test-key', model: 'test-model', token: 'secret' };
const image = 'data:image/jpeg;base64,/9j/2Q==';

test('shared fixture: hazard geometry, step counts, clear-path and unhedged distances are caught', () => {
  for (const text of fixture.blocked) assert.equal(containsSpatialClaim(text), true, text);
  for (const text of fixture.allowed) assert.equal(containsSpatialClaim(text), false, text);
});

test('model instructions carry the spatial safety rule', () => {
  assert.match(SYSTEM, /SPATIAL SAFETY RULE/);
  assert.match(SYSTEM_COMPACT, /SPATIAL SAFETY RULE/);
  assert.match(SYSTEM_COMPACT, /Never give a step count/);
  assert.equal(systemFor({ detail: 'balanced', context: { observations: [] } }), SYSTEM_COMPACT);
  assert.equal(systemFor({ detail: 'detailed', context: { observations: [] } }), SYSTEM);
  assert.ok(SYSTEM_COMPACT.length < SYSTEM.length / 3);
  assert.doesNotMatch(SYSTEM, /Use concrete locations relative to the camera: ahead, left, right/);
});

async function ask(answers) {
  const calls = [];
  const server = createApp(config, async scene => { calls.push(scene); return answers[calls.length - 1]; });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  try {
    const response = await fetch(`http://127.0.0.1:${server.address().port}/v1/scene`, { method: 'POST',
      headers: { 'Authorization': 'Bearer secret', 'Content-Type': 'application/json' },
      body: JSON.stringify({ question: 'Where are the stairs?', image, detail: 'balanced' }) });
    return { status: response.status, body: await response.json(), calls };
  } finally { await new Promise(resolve => server.close(resolve)); }
}

test('relay retries once, then speaks only a compliant answer', async () => {
  const result = await ask(['The stairs are 10 steps ahead.', 'Stairs are visible near the door; the sensors will give their position.']);
  assert.equal(result.status, 200);
  assert.equal(result.calls.length, 2);
  assert.equal(result.calls[1].spatialRetry, true);
  assert.equal(result.body.answer, 'Stairs are visible near the door; the sensors will give their position.');
});

test('relay refuses when the retry still gives hazard geometry', async () => {
  const result = await ask(['The path is clear.', 'Go down the stairs on your left.']);
  assert.equal(result.status, 502);
  assert.equal(result.body.answer, undefined);
});

test('an over-long answer is retried once for a shorter complete answer', async () => {
  const calls = [];
  const server = createApp(config, async scene => { calls.push(scene);
    return calls.length === 1 ? 'The closet has two tall pine doors, a white cloth bag on one handle, and an open door beside it leading to a lit hallway.' : 'A tall pine wardrobe with a bag on its handle.'; });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  try {
    const response = await fetch(`http://127.0.0.1:${server.address().port}/v1/scene`, { method: 'POST',
      headers: { 'Authorization': 'Bearer secret', 'Content-Type': 'application/json' },
      body: JSON.stringify({ question: 'Is there a closet?', image, detail: 'balanced', wordAllowance: 12 }) });
    assert.equal(response.status, 200);
    assert.equal(calls.length, 2);
    assert.equal(calls[1].shorterRetry, true);
    assert.equal((await response.json()).answer, 'A tall pine wardrobe with a bag on its handle.');
  } finally { await new Promise(resolve => server.close(resolve)); }
});

test('only the offending sentence is dropped, with no second model call', async () => {
  const result = await ask(['A lamp stands on the desk beside the bed. The stairs are 10 steps ahead.']);
  assert.equal(result.status, 200);
  assert.equal(result.calls.length, 1);
  assert.equal(result.body.answer, 'A lamp stands on the desk beside the bed.');
});

test('leading whole sentences that fit the budget are kept without a retry', async () => {
  const calls = [];
  const server = createApp(config, async scene => { calls.push(scene);
    return 'A pine wardrobe fills the wall. Beside it an open door shows a lit hallway with a lamp on a small table.'; });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  try {
    const response = await fetch(`http://127.0.0.1:${server.address().port}/v1/scene`, { method: 'POST',
      headers: { 'Authorization': 'Bearer secret', 'Content-Type': 'application/json' },
      body: JSON.stringify({ question: 'Is there a closet?', image, detail: 'balanced', wordAllowance: 8 }) });
    assert.equal(response.status, 200);
    assert.equal(calls.length, 1);
    assert.equal((await response.json()).answer, 'A pine wardrobe fills the wall.');
  } finally { await new Promise(resolve => server.close(resolve)); }
});

test('compliant object estimate passes without a retry', async () => {
  const result = await ask(['The lamp is on the desk to your left, roughly two metres away.']);
  assert.equal(result.status, 200);
  assert.equal(result.calls.length, 1);
});
