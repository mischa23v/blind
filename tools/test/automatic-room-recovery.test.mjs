import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const source = readFileSync(new URL('../../ios/BlindAssist/NavigationModel.swift', import.meta.url), 'utf8');

test('automatic room recovery is wired into foreground camera ticks and appearance probes', () => {
  assert.match(source, /self\.tickAutomaticRoomRecovery\(now: ProcessInfo\.processInfo\.systemUptime\)/);
  assert.match(source, /probeAutomaticRoomAppearance\(frame: frame\)/);
  assert.match(source, /self\.recoveryAppearance\[room\] = \(score, capturedAt\)/);
  assert.match(source, /self\.observationFrameID == frameID/);
  assert.match(source, /now - capturedAt <= 3/);
});

test('automatic selection cannot bypass saved frame verification or repeat manual prompts', () => {
  assert.match(source, /frameVerified: recoveredFrame != nil/);
  assert.match(source, /automaticRoomRecovery\.recovered\(attemptID: attempt\.id/);
  assert.match(source, /places\.places\.filter \{ \$0\.worldFrame != nil \}/);
  assert.match(source, /launch\(map: map, worldSessionID: sessionID, announceCalibration: false\)/);
  assert.match(source, /if !self\.automaticRoomRecoveryEnabled && \(self\.placeRecovery\.expire/);
  assert.match(source, /if !self\.automaticRoomRecoveryEnabled \{ self\.askRoom/);
});

test('map launches do not replenish automatic retry budget', () => {
  const launch = source.slice(source.indexOf('private func launch(map:'), source.indexOf('\n    func stop()', source.indexOf('private func launch(map:')));
  assert.doesNotMatch(launch, /automaticRoomRecovery\.reset/);
  assert.match(source, /case \.recovered = automaticRoomRecovery\.state/);
  assert.match(source, /automaticRoomRecovery\.takeExhaustionNotice\(\)/);
});

test('automatic retries defer to explicit reading, listening and requested speech', () => {
  assert.match(source, /let mayStart = !busy && readingTool == nil && !currencyActive && !colorActive &&/);
  assert.match(source, /!voice\.awaitingUtterance && feedback\.canSpeakAmbient/);
  assert.match(source, /allowNewAttempt: mayStart/);
  assert.match(source, /if mayStart && automaticRoomRecovery\.takeExhaustionNotice/);
});
