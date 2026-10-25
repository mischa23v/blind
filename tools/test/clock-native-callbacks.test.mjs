// Extract and execute production clock boundary logic. Platform services are
// deterministic collaborators, not an Apple SDK, speech engine or device trial.
import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdirSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { tmpdir } from 'node:os';
import { spawnSync } from 'node:child_process';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
test('production clock callbacks keep original lease, operation ownership and proposal publication order', {
  skip: !process.env.BLIND_SWIFTC && 'Set BLIND_SWIFTC to execute the extracted Swift clock replay.',
  timeout: 180_000,
}, () => {
  const work = mkdtempSync(join(process.env.BLIND_TEST_SCRATCH || tmpdir(), 'blind-clock-native-'));
  const tests = join(work, 'Tests/NativeClockReplayTests');
  mkdirSync(tests, { recursive: true });
  mkdirSync(join(work, 'home'), { recursive: true });
  const extraction = spawnSync(process.env.BLIND_PYTHON || 'python3', [join(root, 'tools/test/generate-clock-native-harness.py'),
    join(root, 'ios/BlindAssist/NavigationModel.swift'), join(tests, 'ClockNativeCallbackTests.swift'),
    join(root, 'ios/BlindAssist/LocalImageAssistant.swift')], { encoding: 'utf8' });
  assert.equal(extraction.status, 0, `${extraction.stdout || ''}\n${extraction.stderr || ''}`);
  const dependency = JSON.stringify(join(root, 'BlindCore'));
  writeFileSync(join(work, 'Package.swift'), `// swift-tools-version: 5.9\nimport PackageDescription\nlet package = Package(name: "NativeClockReplay", dependencies: [.package(path: ${dependency})], targets: [.testTarget(name: "NativeClockReplayTests", dependencies: [.product(name: "BlindCore", package: "BlindCore")])])\n`);
  const result = spawnSync(join(dirname(process.env.BLIND_SWIFTC), 'swift'), ['test', '--package-path', work,
    '--scratch-path', join(work, 'build'), '--cache-path', join(work, 'cache'), '--jobs', '1'], {
    encoding: 'utf8', timeout: 175_000, maxBuffer: 8 * 1024 * 1024,
    env: { ...process.env, HOME: join(work, 'home'), XDG_CACHE_HOME: join(work, 'cache'),
      SWIFTPM_MODULECACHE_OVERRIDE: join(work, 'modules'), CLANG_MODULE_CACHE_PATH: join(work, 'clang-cache') },
  });
  const output = `${result.stdout || ''}\n${result.stderr || ''}`;
  writeFileSync(join(work, 'execution.log'), output);
  assert.equal(result.status, 0, `Clock replay failed; preserved package/log: ${work}\n${output.slice(-12000)}`);
  assert.match(output, /Executed 16 tests, with 0 failures/);
  assert.match(readFileSync(join(tests, 'ClockNativeCallbackTests.swift'), 'utf8'), /testRejectedProposalNeverReachesDisplayObservers/);
});
