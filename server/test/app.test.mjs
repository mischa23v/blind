import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createApp, validateScene } from '../src/app.mjs';

const token = 'test-token-with-more-than-24-characters';
const scene = { question: 'What is visible?', image: 'data:image/jpeg;base64,/9j/2Q==', language: 'en' };
async function withServer(config, provider, callback) {
  const server = createApp(config, provider);
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  try { await callback(`http://127.0.0.1:${server.address().port}`); }
  finally { await new Promise(resolve => server.close(resolve)); }
}
const config = { token, apiKey: 'fake-key', model: 'configured-test-model' };
function post(url, value = scene, bearer = token) {
  return fetch(`${url}/v1/scene`, { method: 'POST', headers: { 'Authorization': `Bearer ${bearer}`, 'Content-Type': 'application/json' }, body: JSON.stringify(value) });
}
test('rejects missing and incorrect access tokens before calling provider', async () => {
  let calls = 0;
  await withServer(config, async () => { calls++; return 'visible chair'; }, async url => {
    assert.equal((await post(url, scene, 'wrong')).status, 401);
    assert.equal((await fetch(`${url}/v1/scene`, { method: 'POST' })).status, 401);
  }); assert.equal(calls, 0);
});
test('real HTTP endpoint forwards a deliberate image question and marks no clearance', async () => {
  let forwarded;
  await withServer(config, async input => { forwarded = input; return 'A chair is visible.'; }, async url => {
    const response = await post(url); assert.equal(response.status, 200);
    assert.equal(response.headers.get('cache-control'), 'no-store');
    assert.deepEqual(await response.json(), { answer: 'A chair is visible.', source: 'cloud', navigationClearance: false });
  }); assert.equal(forwarded.image, scene.image);
});
test('unconfigured service does not fake a cloud response', async () => {
  await withServer({ token }, async () => assert.fail(), async url => assert.equal((await post(url)).status, 503));
});
test('validates language, image bytes, size, and arbitrary image URLs', () => {
  for (const invalid of [{ ...scene, question: '' }, { ...scene, language: 'xx' },
    { ...scene, detail: 'unsafe' }, { ...scene, image: 'https://localhost/private' },
    { ...scene, image: 'data:image/jpeg;base64,YWJjZA==' }, { ...scene, image: 'data:image/jpeg;base64,/9j/2Q=' }]) {
    assert.throws(() => validateScene(invalid));
  }
  assert.equal(validateScene({ ...scene, language: 'ar' }).language, 'ar');
});
test('sanitizes upstream failures without exposing credentials', async () => {
  await withServer(config, async () => { throw new Error('secret fake-key'); }, async url => {
    const response = await post(url); assert.equal(response.status, 502);
    assert.doesNotMatch(JSON.stringify(await response.json()), /fake-key/);
  });
});
test('rate limits authenticated questions', async () => {
  await withServer(config, async () => 'A room.', async url => {
    for (let i = 0; i < 6; i++) assert.equal((await post(url)).status, 200);
    assert.equal((await post(url)).status, 429);
  });
});
test('aborts a slow provider', async () => {
  await withServer({ ...config, timeoutMS: 20 }, async (_scene, _config, signal) => {
    await new Promise((_, reject) => signal.addEventListener('abort', () => reject(new Error('aborted')), { once: true }));
  }, async url => assert.equal((await post(url)).status, 504));
});
test('health and unknown routes work', async () => {
  await withServer(config, async () => '', async url => {
    assert.equal((await fetch(`${url}/health`)).status, 200);
    assert.equal((await fetch(`${url}/other`)).status, 404);
  });
});
test('connection check requires authentication and never calls the image provider', async () => {
  await withServer(config, async () => assert.fail('No provider request expected'), async url => {
    assert.equal((await fetch(`${url}/v1/status`)).status, 401);
    const response = await fetch(`${url}/v1/status`, { headers: { Authorization: `Bearer ${token}` } });
    assert.deepEqual(await response.json(), { sceneConfigured: true, policyVersion: 1 });
  });
});
