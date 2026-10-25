import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

// These are source contracts, NOT execution/compilation of the Swift recorder.
const source = readFileSync(new URL('../../BlindCore/Sources/BlindCore/DebugSessionLog.swift', import.meta.url), 'utf8');
const swiftTests = readFileSync(new URL('../../BlindCore/Tests/BlindCoreTests/DebugSessionLogTests.swift', import.meta.url), 'utf8');
const between = (start, end) => source.slice(source.indexOf(start), source.indexOf(end, source.indexOf(start)));

test('debug recorder: whole implementation is DEBUG-only', () => {
  assert.ok(source.startsWith('#if DEBUG\n'));
  assert.ok(source.trimEnd().endsWith('#endif'));
  assert.ok(swiftTests.startsWith('#if DEBUG\n'));
});

test('debug recorder: exact explicit developer argument precedes directory/init', () => {
  const shared = between('public static let shared', 'public struct SessionToken');
  assert.match(source, /launchArgument = "--blind-debug-session-log"/);
  assert.match(shared, /guard ProcessInfo\.processInfo\.arguments\.contains\(launchArgument\)/);
  assert.ok(shared.indexOf('guard ProcessInfo') < shared.indexOf('defaultDirectory'));
  assert.doesNotMatch(source, /UserDefaults|environment\[|URLSession|import SwiftUI|@Published|Network\./);
});

test('debug recorder: disabled, stale and full checks precede lazy payload evaluation', () => {
  const record = between('public func record(', 'public func snapshot');
  for (const gate of ['guard accepting, !purged', 'guard session == sessionToken', 'pending < limits.pendingEvents']) {
    assert.ok(record.indexOf(gate) >= 0 && record.indexOf(gate) < record.indexOf('let value = detail()'));
  }
  assert.ok(record.indexOf('let text = bounded') < record.indexOf('queue.async'));
});

test('debug recorder: hard session, retained, queue and text bounds are explicit', () => {
  assert.match(source, /sessionBytes = 8 \* 1024 \* 1024/);
  assert.match(source, /retainedBytes = 32 \* 1024 \* 1024/);
  assert.match(source, /pendingEvents = 128/);
  assert.match(source, /textBytes = 8 \* 1024/);
  assert.match(source, /recordBytes = 64 \* 1024/);
  assert.match(source, /terminalReserve = 4 \* 1024/);
  assert.match(source, /value\.utf8\.prefix\(maximum \+ 1\)/);
});

test('debug recorder: quotas stop instead of evicting history', () => {
  const append = between('private func append(', 'private func stop(');
  assert.match(append, /limits\.sessionBytes - limits\.terminalReserve - sessionBytes/);
  assert.match(append, /limits\.retainedBytes - limits\.terminalReserve - retainedBytes/);
  assert.match(append, /stop\(\.sessionLimit\)/);
  assert.match(append, /stop\(\.retentionLimit\)/);
  assert.doesNotMatch(append, /removeItem|removeOwned|sorted\(/);
});

test('debug recorder: missing request/tool/utterance bindings are explicitly unbound', () => {
  const correlation = between('public struct Correlation', 'public struct Detail');
  assert.equal((correlation.match(/\?\? "unbound"/g) || []).length, 3);
  assert.doesNotMatch(correlation, /UUID\(\)|lastRequest|currentRequest/);
});

test('debug recorder: speech attempted, start, completion, rejection and interruption are distinct', () => {
  for (const value of ['speechRequested', 'speechStarted', 'speechCompleted', 'speechInterrupted', 'speechRejected', 'modelResponseChunk', 'modelResponse', 'outputGate', 'toolCall', 'toolResult']) {
    assert.match(source, new RegExp(`\\b${value}\\b`));
  }
  assert.doesNotMatch(source, /case .*heard|case .*reasoning|case .*image|case .*audio/i);
});

test('debug recorder: metrics expose loss, truncation, redaction and write failure', () => {
  const metrics = between('public struct Metrics', 'struct Limits');
  for (const name of ['dropped', 'staleCallbacks', 'truncatedFields', 'redactedFields', 'writeErrors', 'priorUncleanSessions', 'stopReason']) {
    assert.ok(metrics.includes(name));
  }
});

test('debug recorder: clean termination drains, synchronizes and removes only current marker', () => {
  const finalize = between('private func finalize()', 'private func control');
  assert.match(finalize, /pending == 0 && !purged && !accepting/);
  assert.match(finalize, /control\(\.sessionEnded\)/);
  assert.match(finalize, /try handle\.synchronize\(\)/);
  assert.ok(finalize.indexOf('try handle.close()') < finalize.indexOf('removeItem(at: marker)'));
  assert.match(finalize, /if !failed, let marker/);
});

test('debug recorder: privacy fence precedes asynchronous deletion and cannot re-enable', () => {
  const purge = between('public func purge(', 'public static func purgeForPrivacyClear');
  assert.ok(purge.indexOf('purged = true') < purge.indexOf('queue.async'));
  assert.match(purge, /accepting = false/);
  assert.match(purge, /removeOwnedFiles\(in: self\.directory\)/);
  assert.match(purge, /\.purgeFailed/);
  assert.doesNotMatch(source, /accepting = true|public func (start|restart|resume|enable)\b/);
});

test('debug recorder: privacy clear also handles logs from disabled launches', () => {
  const purge = between('public static func purgeForPrivacyClear', 'func drainForTesting');
  assert.match(purge, /if let recorder = shared/);
  assert.match(purge, /removeOwnedFiles\(in: directory\)/);
});

test('debug recorder: owned private directory, no raw media API, and conservative redaction', () => {
  assert.match(source, /BlindDebugSessions/);
  assert.match(source, /isExcludedFromBackup = true/);
  assert.match(source, /FileProtectionType\.complete/);
  assert.match(source, /rejectSymlink/);
  assert.match(source, /\[sensitive content omitted\]/);
  const detail = between('public struct Detail', 'public enum StopReason');
  assert.doesNotMatch(detail, /Data|URL|image|audio|embedding|password/);
  assert.match(detail, /text: String\?/);
});

test('debug recorder: prepared native tests cover actual IO and failure cases', () => {
  for (const name of ['DisabledDoesNotEvaluate', 'CleanFinishDrains', 'ForeignSession', 'UTF8BoundAndRedaction', 'PendingQueueIsBounded', 'SessionLimitStops', 'RetainedLimitNeverEvicts', 'WriteFailureStops', 'PriorUncleanMarker', 'PrivacyClearPurges']) {
    assert.ok(swiftTests.includes(`func test${name}`));
  }
});
