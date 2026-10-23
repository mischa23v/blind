// Source wiring contracts only; CompanionClockTests execute the clock/evidence policy.
// These do not prove an Apple build, model tool selection or spoken delivery on device.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
const read = path => readFile(new URL(`../../${path}`, import.meta.url), 'utf8');

test('device clock executes as an advertised read-only tool without a camera or network', async () => {
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  const body = model.match(/case \.deviceClock:\s*([\s\S]*?)(?=\n\s*case \.)/)?.[1];
  assert.ok(body, 'device clock has a tool executor case');
  assert.match(body, /CompanionClock\.read\(now: Date\(\), timeZone: \.current, arabic: arabic\)/);
  assert.doesNotMatch(body, /running|camera|session\.currentFrame|URLSession|requestPermission/);
  assert.match(model, /availableTools: Set\(CompanionToolKind\.allCases\)/);
  const helper = await read('BlindCore/Sources/BlindCore/CompanionEvidence.swift');
  assert.match(helper, /case currentObservation, savedMemory, navigationState, deviceClock/);
  assert.match(helper, /case \.deviceClock:\s*return CompanionClock\.isClockEvidence\(item\) && item\.isCurrent\(at: now\)/);
});

test('clock speech skips only validated camera-independent records and retains dispatch guards', async () => {
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  const start = model.indexOf('private func queueConversationSpeech');
  const end = model.indexOf('private func readCompanionToolForTurn', start);
  const body = model.slice(start, end);
  assert.match(body, /\.measuredState && !CompanionClock\.isClockEvidence\(\$0\)/);
  assert.match(body, /captures\.count == current\.count/);
  assert.match(body, /CompanionEvidenceGuard\.allows\(next\.text, reports: next\.reports, evidence: next\.evidence, now: Date\(\)\)/);
  assert.match(body, /SpatialClaimGuard\.containsSpatialClaim\(text\)/);
  assert.match(body, /assistantSession\.accepts\(generation: next\.generation\)/);
});

test('model advertises a fresh clock read rather than a hardcoded date or invented time', async () => {
  const adapter = await read('ios/BlindAssist/LocalImageAssistant.swift');
  assert.match(adapter, /navigationState, or deviceClock/);
  assert.match(adapter, /For the current time, call deviceClock and repeat its complete fresh evidence/);
  assert.match(adapter, /never guess from conversation or training/);
});
