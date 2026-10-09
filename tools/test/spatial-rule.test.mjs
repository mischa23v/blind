// Static guard for the permanent spatial safety rule (AGENTS.md, task E13): every path
// from a model answer to speech must pass the shared check. A later edit that removes
// a check makes this test report it. The Claude Code hook in .claude/settings.json reruns
// this file after edits to the guarded sources.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const read = path => readFile(new URL(`../../${path}`, import.meta.url), 'utf8');

test('relay checks every model answer and retries once', async () => {
  const app = await read('server/src/app.mjs');
  assert.match(app, /import \{ containsSpatialClaim \} from '\.\/spatial-guard\.mjs'/);
  const first = app.indexOf('let answer = await provider(');
  const check = app.indexOf('if (containsSpatialClaim(answer))', first);
  const reply = app.indexOf("reply(200, { answer", first);
  assert.ok(first > 0 && check > first && reply > check, 'spatial check must sit between the provider answer and the reply');
});

test('app checks model text before speaking it', async () => {
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  const guardAt = model.indexOf('if fromModel && SpatialClaimGuard.containsSpatialClaim(answer)');
  const speakAt = model.indexOf('self.feedback.speakAmbient(answer', guardAt);
  assert.ok(guardAt > 0 && speakAt > guardAt, 'spatial check must come before ambient speech of a model answer');
  assert.equal((model.match(/fromModel = true/g) ?? []).length, 2, 'cloud and on-device answers are both marked as model text');
});

test('model instructions and both checks stay in place', async () => {
  assert.match(await read('server/src/scene-policy.mjs'), /SPATIAL SAFETY RULE/);
  assert.match(await read('BlindCore/Sources/BlindCore/SpatialClaimGuard.swift'), /public static func containsSpatialClaim/);
  assert.match(await read('AGENTS.md'), /Spatial safety rule/);
});
