import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { containsSpatialClaim } from '../src/spatial-guard.mjs';
import { createApp } from '../src/app.mjs';
import { SYSTEM, SYSTEM_COMPACT, systemFor, keepSafeSentences } from '../src/scene-policy.mjs';

const fixture = JSON.parse(await readFile(new URL('../../BlindCore/Tests/BlindCoreTests/Fixtures/spatial-claims.json', import.meta.url), 'utf8'));
const config = { apiKey: 'test-key', model: 'test-model', token: 'secret' };
const image = 'data:image/jpeg;base64,/9j/2Q==';

test('shared fixture: physical geometry and actions are caught even when hedged or quoted', () => {
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
  const result = await ask(['The stairs are 10 steps ahead.', 'Stairs are visible; the app needs verified measurements.']);
  assert.equal(result.status, 200);
  assert.equal(result.calls.length, 2);
  assert.equal(result.calls[1].spatialRetry, true);
  assert.equal(result.body.answer, 'Stairs are visible; the app needs verified measurements.');
});

test('relay keeps only a fixed hazard line when the retry still gives hazard geometry', async () => {
  const result = await ask(['The path is clear.', 'Go down the stairs on your left.']);
  assert.equal(result.status, 200);
  assert.equal(result.body.answer, 'A possible hazard is visible.');
});

test('relay refuses when the retry still claims clearance without naming a hazard', async () => {
  const result = await ask(['The path is clear.', 'The way is clear.']);
  assert.equal(result.status, 502);
  assert.equal(result.body.answer, undefined);
});

test('an over-long answer is retried once for a shorter complete answer', async () => {
  const calls = [];
  const server = createApp(config, async scene => { calls.push(scene);
    return calls.length === 1 ? 'The wardrobe has elaborate decorative carvings, polished pine doors, ornate brass handles, a floral pattern, several painted birds, and a warm golden brown finish.' : 'A tall pine wardrobe with ornate handles.'; });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  try {
    const response = await fetch(`http://127.0.0.1:${server.address().port}/v1/scene`, { method: 'POST',
      headers: { 'Authorization': 'Bearer secret', 'Content-Type': 'application/json' },
      body: JSON.stringify({ question: 'Is there a closet?', image, detail: 'balanced', wordAllowance: 12 }) });
    assert.equal(response.status, 200);
    assert.equal(calls.length, 2);
    assert.equal(calls[1].shorterRetry, true);
    assert.equal((await response.json()).answer, 'A tall pine wardrobe with ornate handles.');
  } finally { await new Promise(resolve => server.close(resolve)); }
});

test('only the offending sentence is dropped, with no second model call', async () => {
  const result = await ask(['A lamp has a blue shade. The stairs are 10 steps ahead.']);
  assert.equal(result.status, 200);
  assert.equal(result.calls.length, 1);
  assert.equal(result.body.answer, 'A possible hazard is visible. A lamp has a blue shade.');
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

test('hedged ordinary-object geometry is rejected instead of corrected by later frames', async () => {
  const text = 'The lamp is on the desk to your left, roughly two metres away.';
  const result = await ask([text, text]);
  assert.equal(result.status, 502);
  assert.equal(result.calls.length, 2);
  assert.equal(result.calls[1].spatialRetry, true);
  assert.equal(result.body.answer, undefined);
});

// Actual relay regressions use only a local stub, never a real model/API call.
test('clearance paraphrases cannot pass the relay unchanged', async () => {
  for (const text of ['The corridor is unobstructed.', 'You can safely walk forward.', 'الممر سالك.', 'يمكنك المشي بأمان.']) {
    const result = await ask([text, text]);
    assert.equal(result.status, 502, text);
    assert.equal(result.calls.length, 2, text);
    assert.equal(result.body.answer, undefined, text);
  }
});

test('sentence filtering preserves original hazard context in both languages', async () => {
  const cases = [
    ['There is a staircase. It is roughly two metres ahead.', 'There is a staircase.'],
    ['The staircase is on your left. It is roughly two metres ahead.', ''],
    ['It is roughly two metres ahead. There is a staircase.', 'There is a staircase.'],
    ['يوجد درج. إنه أمامك بحوالي مترين.', 'يوجد درج.'],
    ['الدرج على يمينك. هو على بعد مترين تقريباً.', ''],
  ];
  for (const [text, expected] of cases) {
    assert.equal(keepSafeSentences(text, 'ar'), expected, text);
    // A seen hazard is never silently lost: with nothing compliant left, a fixed line reports it.
    const result = await ask([text, text]);
    assert.equal(result.status, 200, text);
    const notices = ['A possible hazard is visible.', 'قد يظهر خطر محتمل.'];
    assert.ok(expected ? result.body.answer === expected : notices.includes(result.body.answer), text);
  }
});

test('filter drops ordinary-object estimates while retaining nonspatial hazard notice', () => {
  const text = 'Stairs are visible. The lamp is roughly two metres to your left.';
  assert.equal(keepSafeSentences(text, 'en'), 'Stairs are visible.');
});

// These exercise the actual local relay with a stub provider, not a live model or sensors.
test('physical actions, pickup identity and safe reach claims never pass a repeated model answer', async () => {
  for (const text of [
    'Maybe pick up the knife.', 'It is safe to reach for it.', 'Follow me.',
    'The sensors confirm that you can grab it.', 'Try extending your arm a little.',
    'ربما تقدر تمسكه.', 'مدّ يدك شوي وخذه.', 'يمكن تلف جسمك شوي.',
    'The sign says “pick up the knife.”', 'اللافتة تقول «خذ السكين».',
  ]) {
    const result = await ask([text, text]);
    assert.equal(result.status, 502, text);
    assert.equal(result.calls.length, 2, text);
    assert.equal(result.body.answer, undefined, text);
  }
});

test('a nonspatial description survives but a later pickup instruction does not', async () => {
  const result = await ask(['A mug has a blue pattern. Maybe pick it up by the handle.']);
  assert.equal(result.status, 200);
  assert.equal(result.calls.length, 1);
  assert.equal(result.body.answer, 'A mug has a blue pattern.');
});

test('neither role prompt allows everyday-object estimates or a model certainty bypass', () => {
  for (const prompt of [SYSTEM, SYSTEM_COMPACT]) {
    assert.doesNotMatch(prompt, /may give an approximate direction|rough distance in metres|coming a little closer/);
    assert.match(prompt, /reachability/);
    assert.match(prompt, /code/);
    assert.match(prompt, /even.*(?:hedged|maybe)/);
  }
});
