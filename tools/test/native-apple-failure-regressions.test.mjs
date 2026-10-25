// Integration/source contracts only. Actual Foundation and actor scheduling witnesses
// are recorded in NATIVE_APPLE_FAILURE_REPAIR.md; Apple UI execution remains required.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const read = path => readFile(new URL('../../' + path, import.meta.url), 'utf8');

test('native failure repairs preserve explicit off, nonblocking waits and honest capability/audit gates', async () => {
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  assert.match(model, /cameraAwareness = UserDefaults.standard.object\(forKey: "camera-awareness"\) == nil\s*\? true : UserDefaults.standard.bool\(forKey: "camera-awareness"\)/);
  const hosted = await read('ios/BlindAssistTests/CommunityTests.swift');
  for (const name of ['testOfflinePackageMetadataRestoresButPoseDoesNot', 'testForgedRevisionCannotAttachAnotherGeometryOnRestart']) {
    const start = hosted.indexOf('@MainActor func ' + name);
    assert.ok(start >= 0, name);
    const body = hosted.slice(start, hosted.indexOf('\n    }', start));
    assert.match(body, /try await awaitIndoorIOAsync/);
    assert.match(body, /try await restoredNavigatorAsync/);
    assert.doesNotMatch(body, /try awaitIndoorIO \{|try restoredNavigator\(\)/);
  }
  assert.match(hosted, /testAsyncMapWaitLeavesMainOwnerAvailable/);
  assert.match(hosted, /await fulfillment\(of: \[done\], timeout: 10\)/);
  assert.match(hosted, /Requires the real English on-device Foundation Model/);
  assert.match(hosted, /func unavailableProviderDoesNotInventAReply/);
  assert.match(hosted, /#expect\(answer.text == nil\)/);
  assert.match(hosted, /func codeOwnedHistoricalReportNeverBecomesCurrentGeometry/);
  const runtime = await read('ios/BlindAssistTests/ConnectedJourneyRuntimeTests.swift');
  assert.match(runtime, /await fulfillment\(of: \[done\], timeout: 3\)/);
  assert.match(runtime, /throw WaitError.timedOut/);
  assert.doesNotMatch(runtime, /0\.\.<3000|Task.sleep\(nanoseconds: 1_000_000\)/);
  const ui = await read('ios/BlindAssistUITests/LaunchTests.swift');
  assert.match(ui, /camera-off launch preference is respected before practice/);
  assert.match(ui, /ACCESSIBILITY_AUDIT=type:/);
  assert.equal(ui.match(/guard issue.auditType == \.contrast, let element = issue.element else \{ return false \}/g)?.length, 2);
  assert.doesNotMatch(ui, /issue.auditType == \.dynamicType/);
});

test('camera preference contract rejects old NO conversion and constant defaults', async () => {
  const source = await read('ios/BlindAssist/NavigationModel.swift');
  const marker = '@Published var cameraAwareness = ';
  const start = source.indexOf(marker), end = source.indexOf(' {', start);
  assert.ok(start >= 0 && end > start);
  const initializer = source.slice(start, end);
  const required = /cameraAwareness = UserDefaults.standard.object\(forKey: "camera-awareness"\) == nil\s*\? true : UserDefaults.standard.bool\(forKey: "camera-awareness"\)/;
  assert.match(initializer, required);
  for (const expression of [
    'UserDefaults.standard.object(forKey: "camera-awareness") as? Bool ?? true',
    'true', 'false',
  ]) {
    assert.throws(() => assert.match(marker + expression, required), {name: 'AssertionError'});
  }
});
