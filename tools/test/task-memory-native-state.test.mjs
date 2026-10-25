// Exercises the exact Foundation-only production WorkingState, not a copied
// reducer or source regex. This is not an iOS build, camera test or LLM run.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, writeFileSync, mkdirSync, mkdtempSync, cpSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { tmpdir } from 'node:os';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
test('production task state retains exact sources, chronology and scoped completion', {
  skip: !process.env.BLIND_SWIFTC && 'Set BLIND_SWIFTC to execute the extracted Swift production-state replay.',
  timeout: 180_000,
}, () => {
  const source = readFileSync(join(root, 'ios/BlindAssist/LocalImageAssistant.swift'), 'utf8');
  const start = source.indexOf('/// App-owned state:');
  const end = source.indexOf('#if canImport(FoundationModels)', start);
  assert.ok(start >= 0 && end > start, 'Production extraction markers must exist');
  const work = mkdtempSync(join(process.env.BLIND_TEST_SCRATCH || tmpdir(), 'blind-task-memory-'));
  mkdirSync(join(work, 'Sources/NativeStateReplay'), { recursive: true });
  mkdirSync(join(work, 'home'), { recursive: true });
  writeFileSync(join(work, 'Sources/NativeStateReplay/ExtractedWorkingState.swift'), 'import Foundation\nimport BlindCore\n\n' + source.slice(start, end));
  cpSync(join(root, 'tools/test/fixtures/task-memory-native-state'), join(work, 'Tests/NativeStateReplayTests'), { recursive: true });
  const nativeTests = readFileSync(join(root, 'ios/BlindAssistTests/CommunityTests.swift'), 'utf8');
  const existingStart = nativeTests.indexOf('final class CompanionWorkingStateTests:');
  assert.ok(existingStart >= 0, 'Existing production-state tests must remain included');
  const existingEnd = nativeTests.indexOf('\n}\n', existingStart);
  assert.ok(existingEnd > existingStart, 'Existing state test class must end at a top-level brace');
  writeFileSync(join(work, 'Tests/NativeStateReplayTests/ExistingWorkingStateTests.swift'), 'import XCTest\nimport Foundation\nimport BlindCore\n@testable import NativeStateReplay\n' + nativeTests.slice(existingStart, existingEnd + 3));
  const dependency = JSON.stringify(join(root, 'BlindCore'));
  writeFileSync(join(work, 'Package.swift'), `// swift-tools-version: 5.9\nimport PackageDescription\nlet package = Package(name: "NativeStateReplay", dependencies: [.package(path: ${dependency})], targets: [.target(name: "NativeStateReplay", dependencies: [.product(name: "BlindCore", package: "BlindCore")]), .testTarget(name: "NativeStateReplayTests", dependencies: ["NativeStateReplay", .product(name: "BlindCore", package: "BlindCore")])])\n`);
  const swift = join(dirname(process.env.BLIND_SWIFTC), 'swift');
  const result = spawnSync(swift, ['test', '--package-path', work, '--scratch-path', join(work, 'build'), '--cache-path', join(work, 'cache'), '--jobs', '1'], {
    encoding: 'utf8', timeout: 175_000, maxBuffer: 8 * 1024 * 1024,
    env: { ...process.env, HOME: join(work, 'home'), XDG_CACHE_HOME: join(work, 'cache'), SWIFTPM_MODULECACHE_OVERRIDE: join(work, 'modules'), CLANG_MODULE_CACHE_PATH: join(work, 'clang-cache') },
  });
  const output = `${result.stdout || ''}\n${result.stderr || ''}`;
  writeFileSync(join(work, 'execution.log'), output);
  assert.equal(result.status, 0, `Extracted state replay failed; preserved package/log: ${work}\n${output.slice(-12000)}`);
  assert.match(output, /Executed 37 tests, with 0 failures/);
});
