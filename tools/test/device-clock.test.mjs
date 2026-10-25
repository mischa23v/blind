// Source wiring contracts only; CompanionClockTests execute the clock/evidence policy.
// These do not prove an Apple build, model tool selection or spoken delivery on device.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
const read = path => readFile(new URL(`../../${path}`, import.meta.url), 'utf8');

test('device clock executes as an advertised read-only tool without a camera or network', async () => {
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  const executor = model.slice(model.indexOf('@MainActor private func readCompanionTool('));
  const body = executor.match(/case \.deviceClock:\s*([\s\S]*?)(?=\n\s*case \.)/)?.[1];
  assert.ok(body, 'device clock has a tool executor case');
  assert.match(body, /acquireClockReply\(\)/);
  assert.match(body, /return lease.result/);
  assert.match(model, /Date\(\), ProcessInfo.processInfo.systemUptime, \.current/);
  assert.doesNotMatch(body, /running|camera|session\.currentFrame|URLSession|requestPermission/);
  assert.match(model, /availableTools: self\.availableCompanionTools/);
  assert.match(model, /var result: Set<CompanionToolKind> = \[\.savedMemory, \.navigationState, \.deviceClock\]/);
  const helper = await read('BlindCore/Sources/BlindCore/CompanionEvidence.swift');
  assert.match(helper, /case currentObservation, savedMemory, navigationState, deviceClock/);
  assert.match(helper, /case \.deviceClock:\s*return CompanionClock\.isClockEvidence\(item\) && item\.isCurrent\(at: date\)/);
});

test('clock speech skips only validated camera-independent records and retains dispatch guards', async () => {
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  const start = model.indexOf('private func queueConversationSpeech');
  const end = model.indexOf('private func readCompanionToolForTurn', start);
  const body = model.slice(start, end);
  assert.match(body, /CompanionEvidenceGuard\.requiredVisualEvidence\(text, reports: reports, evidence: evidence\)/);
  assert.match(body, /captures\.count == current\.count/);
  assert.match(body, /CompanionEvidenceGuard\.allows\(next\.text, reports: next\.reports, evidence: next\.evidence, now: Date\(\)\)/);
  assert.match(body, /SpatialClaimGuard\.containsSpatialClaim\(text\)/);
  assert.match(body, /assistantSession\.accepts\(generation: next\.generation\)/);
});

test('model advertises a fresh clock read rather than a hardcoded date or invented time', async () => {
  const adapter = await read('ios/BlindAssist/LocalImageAssistant.swift');
  assert.match(adapter, /navigationState, deviceClock, saudiBanknote/);
  assert.match(adapter, /For current time, call deviceClock; repeat its fresh evidence, never guess/);
  assert.match(adapter, /Tool failures and empty results mean unknown, never absent/);
});
