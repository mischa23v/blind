// Source contracts only: hosted Apple scheduling still requires a native run.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
const read = path => readFile(new URL('../../' + path, import.meta.url), 'utf8');

test('all continuity scenarios await real map IO without blocking the main owner', async () => {
  const source = await read('ios/BlindAssistTests/CommunityTests.swift');
  const start = source.indexOf('final class IndoorGoalContinuityTests: XCTestCase');
  const suite = source.slice(start, source.indexOf('\n/// State logic only.', start));
  assert.ok(start >= 0);
  assert.match(suite, /@MainActor private func navigator\(aligned: Bool = true\) async throws/);
  assert.match(suite, /try await awaitIndoorIOAsync \{ done in try navigator.load/);
  assert.doesNotMatch(suite, /try awaitIndoorIO\s*\{|wait\(for:|XCTSkip|try\? /);
  for (const name of [
    'testTaskCancellationRetiresRouteButPreservesPreviewFrame',
    'testCancellationAfterWithheldLegacyCueClearsMessageInBothLanguages',
    'testConfirmedFinalWaypointHasNoActiveRoute',
    'testTaskCancellationCannotCreateUnknownAlignment',
    'testTrackingLossStillInvalidatesRetainedMapFrame',
    'testExplicitReplanDoesNotReuseOldRouteAlignment',
  ]) assert.ok(suite.includes(`@MainActor func ${name}() async throws`), name);
  assert.equal((suite.match(/let navigator = try await navigator\(/g) ?? []).length, 6);
  assert.match(source, /await fulfillment\(of: \[done\], timeout: 10\)/);
});

test('runtime diagnostics preserve original completion conditions and timeout failures', async () => {
  const source = await read('ios/BlindAssistTests/ConnectedJourneyRuntimeTests.swift');
  assert.match(source, /await fulfillment\(of: \[done\], timeout: 3\)/);
  assert.match(source, /guard condition\(\) else \{/);
  assert.match(source, /throw WaitError.timedOut/);
  assert.match(source, /publications \+= 1\s+previous\?\(\)/);
  assert.match(source, /NATIVE_RUNTIME_WAIT/);
  assert.match(source, /ProcessInfo.processInfo.systemUptime/);
  for (const phase of ['read-start', 'read-held', 'read-return', 'write-start', 'write-held', 'write-injected-failure', 'write-return']) {
    assert.ok(source.includes(`trace("${phase}")`), phase);
  }
  // Trace strings contain phase/timing metadata, never stored data or map payloads.
  const records = source.split('\n').filter(line => /traceBuffer\.record\("NATIVE_RUNTIME_(?:IO|WAIT) /.test(line));
  assert.equal(records.length, 3);
  for (const line of records) assert.doesNotMatch(line, /\\\((?:data|envelope|payload|runtime.goal|runtime.status)/);
});

test('native failure output retains bounded phase diagnostics without hiding assertions', async () => {
  const source = await read('tools/ci/native-apple.sh');
  assert.match(source, /if \[\[ "\$label" = unit \]\]; then/);
  assert.ok(source.includes('python3 tools/ci/extract-native-unit-failures.py "$out/$label.log" || true'));
  assert.match(source, /return "\$status"/);
  assert.ok(source.indexOf('error:|fatal') < source.indexOf('python3 tools/ci/extract-native-unit-failures.py'));
});

test('combined shell diagnostics preserve failed status and isolate bounded practice chronology', async () => {
  const { mkdtemp, rm } = await import('node:fs/promises');
  const { tmpdir } = await import('node:os');
  const { join } = await import('node:path');
  const { spawnSync } = await import('node:child_process');
  const source = await read('tools/ci/native-apple.sh');
  const body = source.slice(source.indexOf('run_logged() {'), source.indexOf('\ncase "$mode"'));
  assert.ok(body.startsWith('run_logged() {'));
  const out = await mkdtemp(join(tmpdir(), 'blind-native-log-witness-'));
  try {
    const script = 'set -euo pipefail\n' + body + `
fixture() {
  echo 'NEIGHBOR_TEST_BEFORE'
  echo "Test Case '-[BlindAssistUITests.LaunchTests testPracticeIsAnnouncedAndCanStop]' started."
  for ((i=0;i<300;i++)); do echo "PRACTICE_ACTION_$i"; done
  echo "Test Case '-[BlindAssistUITests.LaunchTests testPracticeIsAnnouncedAndCanStop]' failed (192.675 seconds)."
  echo 'NEIGHBOR_TEST_AFTER'
  echo 'error: synthetic-original-failure'
  for ((i=0;i<80;i++)); do echo "TAIL_PADDING_$i"; done
  return 65
}
run_logged ui fixture
`;
    const result = spawnSync('bash', ['-c', script], { env: { ...process.env, out }, encoding: 'utf8', timeout: 5000 });
    assert.equal(result.error, undefined);
    assert.equal(result.status, 65);
    assert.ok(result.stdout.includes('error: synthetic-original-failure'));
    const begin = result.stdout.indexOf('PRACTICE_TRACE_BEGIN');
    const end = result.stdout.indexOf('PRACTICE_TRACE_END');
    assert.ok(begin >= 0 && end > begin);
    const trace = result.stdout.slice(begin, end).trim().split('\n').slice(1);
    assert.equal(trace.length, 240);
    assert.ok(trace.some(line => line === 'PRACTICE_ACTION_299'));
    assert.ok(trace.at(-1).includes('failed (192.675 seconds).'));
    assert.ok(trace.every(line => !line.includes('NEIGHBOR_TEST_')));
  } finally {
    await rm(out, { recursive: true, force: true });
  }
});
