#!/usr/bin/env node
// Optional local ground-truth injection replay, NOT perception or model evaluation.
// No downloads/network. Restricted annotation material exists only in a temporary
// directory outside this repository, is never logged, and is removed on exit.
import { readFile, readdir, mkdtemp, writeFile, rm } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const args = process.argv.slice(2);
function option(name, fallback) {
  const index = args.indexOf(name);
  return index === -1 ? fallback : args[index + 1];
}
const root = fileURLToPath(new URL('../', import.meta.url));
const dataRoot = option('--sequence');
if (!dataRoot) throw new Error('Required: --sequence /external/path/to/42898570; optional --swift /path/to/swift --scratch-path /external/build');
const swift = option('--swift', 'swift');
const scratch = option('--scratch-path', join(tmpdir(), 'blind-semantic-replay-build'));
const cache = option('--cache-path', join(process.env.XDG_CACHE_HOME ?? join(tmpdir(), 'blind-semantic-replay-cache'), 'swiftpm'));
const config = option('--config-path', join(process.env.XDG_CACHE_HOME ?? join(tmpdir(), 'blind-semantic-replay-cache'), 'config'));
const security = option('--security-path', join(process.env.XDG_CACHE_HOME ?? join(tmpdir(), 'blind-semantic-replay-cache'), 'security'));
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const sourcePath = join(resolve(dataRoot), 'world.gt', 'instances.json');
const bytes = await readFile(sourcePath);
const sourceSHA256 = hash(bytes);
if (sourceSHA256 !== '286e7c8268ca6de5be7564ee9d4afc977f729c7500d2aa755db65e62b31f8a9c') {
  throw new Error('Wrong source revision: expected the pinned CA-1M validation 42898570 world annotations');
}
const instances = JSON.parse(bytes);
if (instances.length !== 99 || instances.filter(row => row.category !== 'object').length !== 43) throw new Error('Pinned inventory counts changed');
for (const row of instances) {
  if (typeof row.id !== 'string' || typeof row.category !== 'string' || row.position.length !== 3 ||
      !row.position.every(Number.isFinite)) throw new Error('Invalid annotation input');
}
const goldenCategories = [...new Set(instances.filter(row => row.category !== 'object').map(row => row.category))].sort();
// Audit actual recorded pose evidence but do not pass it as localization authority.
const firstFrame = (await readdir(dataRoot)).filter(name => /^\d+\.gt$/.test(name)).sort()[0];
const poseBytes = await readFile(join(dataRoot, firstFrame, 'RT.json'));
const pose = JSON.parse(poseBytes);
if (pose.length !== 4 || !pose.every(row => row.length === 4 && row.every(Number.isFinite))) throw new Error('Invalid recorded pose matrix');
const temporary = await mkdtemp(join(tmpdir(), 'blind-semantic-ca1m-'));
try {
  const input = join(temporary, 'input.json');
  await writeFile(input, JSON.stringify({ sourceSHA256, goldenCategories,
    records: instances.map(({ id, category, position }) => ({ id, category, position })) }), { mode: 0o600 });
  console.log(JSON.stringify({ phase: 'source-audit', sourceSHA256, sourceBytes: bytes.length,
    objects: instances.length, namedObjects: 43, namedCategories: goldenCategories.length,
    recordedPoseSHA256: hash(poseBytes), recordedPoseShape: '4x4',
    limits: 'Ground-truth category injection only. No detector/model, measured clock, live calibration, route or recognition accuracy.' }));
  const run = spawnSync(swift, ['test', '--package-path', join(root, 'BlindCore'), '--scratch-path', scratch,
    '--cache-path', cache, '--config-path', config, '--security-path', security,
    '--jobs', '1', '--filter', 'SemanticMemoryReplayTests/testInventoryReplayAgainstOriginalLabelsAndOptionalExternalAnnotations'],
    { cwd: root, env: { ...process.env, BLIND_SEMANTIC_REPLAY_INPUT: input }, encoding: 'utf8', maxBuffer: 16 * 1024 * 1024 });
  // Print the XCTest summary and hash/count receipt, never test assertions that
  // might contain restricted labels/IDs on failure. Full output is temporary.
  const stdout = run.stdout ?? '', stderr = run.stderr ?? '';
  for (const line of (stdout + '\n' + stderr).split('\n')) {
    if (/SEMANTIC_EXTERNAL_REPLAY|Executed \d+ test|Build complete!|Test Suite .* (passed|failed)/.test(line)) console.log(line);
  }
  console.log(JSON.stringify({ phase: 'result', status: run.status === 0 ? 'passed' : 'failed',
    exitCode: run.status, outputSHA256: hash(stdout + '\n' + stderr),
    error: run.error ? String(run.error.message) : undefined,
    sourceSHA256, goldenLabelQueries: goldenCategories.length * 3,
    noRestrictedDataCommitted: true, noCloudOrModelCalls: true }));
  if (run.status !== 0) {
    console.error('External replay failed. Re-run locally with a private diagnostic sink; raw restricted assertions are deliberately not printed.');
    process.exitCode = 1;
  }
} finally {
  await rm(temporary, { recursive: true, force: true });
}
