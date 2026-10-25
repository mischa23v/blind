import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, readFile, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
const root = new URL('../../', import.meta.url);
test('every real-model text unwrap retains its require and adds only fixture/status context', async () => {
  const source = await readFile(new URL('ios/BlindAssistTests/CommunityTests.swift', root), 'utf8');
  const unwraps = source.split('\n').filter(line => /#require\((greeting|answer|response|first)\.text/.test(line));
  assert.equal(unwraps.length, 7);
  for (const line of unwraps) {
    assert.match(line, /#require\((greeting|answer|response|first)\.text, "MODEL_FIXTURE /);
    assert.match(line, /status=\\\((greeting|answer|response|first)\.status\)/);
  }
  assert.equal((source.match(/\.enabled\(if: OnDeviceLanguage.supports/g) ?? []).length, 4);
  assert.match(source, /#expect\(!SpatialClaimGuard.containsSpatialClaim\(last\)\)/);
  assert.match(source, /#expect\(!ConversationClaimGuard.containsUnsupportedClaim\(last\)\)/);
});
async function logged(lines, status = 65) {
  const dir = await mkdtemp(join(tmpdir(), 'blind-model-diagnostics-'));
  try {
    const fixture = join(dir, 'fixture.log');
    await writeFile(fixture, lines.join('\n') + '\n');
    const source = await readFile(new URL('tools/ci/native-apple.sh', root), 'utf8');
    const helper = source.slice(source.indexOf('run_logged() {'), source.indexOf('\ncase "$mode"'));
    return spawnSync('bash', ['-c', `set -euo pipefail\n${helper}\nfixture() { cat "$fixture"; return ${status}; }\nrun_logged unit fixture`], {
      cwd: root, env: { ...process.env, out: dir, fixture }, encoding: 'utf8', timeout: 5000
    });
  } finally { await rm(dir, { recursive: true, force: true }); }
}
test('early Swift Testing issue and app status survive later output without changing exit65', async () => {
  const r = await logged(['✘ Test remembersName() recorded an issue at CommunityTests.swift:408: Expectation failed: greeting.text',
    '↳ MODEL_FIXTURE conversation.greeting status=The on-device reply could not finish. No external action was taken.',
    'unrelated model text must not enter the issue excerpt', ...Array(200).fill('later ordinary output')]);
  assert.equal(r.status, 65);
  const excerpt = r.stdout.split('SWIFT_TESTING_ISSUES_BEGIN')[1].split('SWIFT_TESTING_ISSUES_END')[0];
  assert.match(excerpt, /Expectation failed: greeting.text/);
  assert.match(excerpt, /MODEL_FIXTURE conversation.greeting status=/);
  assert.doesNotMatch(excerpt, /unrelated model text|later ordinary output/);
});
test('Swift Testing excerpt is independently capped by lines and line length', async () => {
  const r = await logged([...Array.from({ length: 150 }, (_, i) => `↳ MODEL_FIXTURE case${i} status=${'x'.repeat(2000)}`), ...Array(100).fill('later output')]);
  assert.equal(r.status, 65);
  const lines = r.stdout.split('SWIFT_TESTING_ISSUES_BEGIN')[1].split('SWIFT_TESTING_ISSUES_END')[0].trim().split('\n').slice(1);
  assert.equal(lines.length, 80);
  assert.ok(lines.every(line => line.length <= 1200));
});
test('successful unit execution keeps status zero and does not emit a failure excerpt', async () => {
  const r = await logged(['Test run with 7 tests passed'], 0);
  assert.equal(r.status, 0);
  assert.doesNotMatch(r.stdout, /SWIFT_TESTING_ISSUES_BEGIN/);
});
