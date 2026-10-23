// Source/configuration contracts only, not Apple SDK linking or real-image accuracy.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
const read = file => readFile(new URL(`../../${file}`, import.meta.url), 'utf8');

test('device-test selection requires explicit Debug/native flags and a pinned manifest hash', async () => {
  const source = await read('ios/BlindAssist/SaudiBanknoteReferenceRecognition.swift');
  assert.match(source, /#if DEBUG && BLIND_CURRENCY_DEVICE_TEST && BLIND_CURRENCY_REFERENCE\s+static let selected/);
  assert.match(source, /object\(forInfoDictionaryKey: "BACurrencyDeviceTestManifestSHA256"\)/);
  assert.match(source, /validSHA\(hash\) else \{ return nil \}/);
  assert.match(source, /algorithm: \.sift, manifestSHA256: hash, thresholds: \.experimental/);
  assert.match(source, /authorization: \.deviceTest\(\.init\(referencePackSHA256: hash\)\)/);
  assert.match(source, /#else\s+static let selected: SaudiBanknoteReferenceProfile\? = nil/);
  assert.match(source, /permission\.referencePackSHA256 == manifestSHA256/);
  assert.match(source, /algorithm == \.sift && thresholds == \.experimental/);
});

test('device authorization is not fabricated release approval or human review', async () => {
  const adapter = await read('ios/BlindAssist/SaudiBanknoteReferenceRecognition.swift');
  assert.doesNotMatch(adapter, /humanReviewed:\s*true|appleDeviceAcceptanceReviewed:\s*true|ReleaseApproval\(/);
  assert.match(adapter, /case \.release\(let approval\):\s+return approval.valid/);
  assert.match(adapter, /SaudiBanknoteReferencePolicy.decide\(evidence, thresholds: profile.thresholds, approval: approval\)/);
  assert.match(adapter, /#if DEBUG && BLIND_CURRENCY_DEVICE_TEST\s+return SaudiBanknoteReferencePolicy.decideForDeviceTest/);
  const policy = await read('BlindCore/Sources/BlindCore/SaudiBanknoteReferencePolicy.swift');
  const device = policy.split('public static func decideForDeviceTest')[1].split('public static func experimentalDecision')[0];
  assert.match(device, /authorization.valid, thresholds == \.experimental/);
  assert.match(device, /switch experimentalDecision\(evidence, thresholds: thresholds\)/);
  assert.doesNotMatch(device, /ReleaseApproval|humanReviewed:\s*true/);
});

test('device pack allowance is isolated from unchanged production coverage and file gates', async () => {
  const source = await read('ios/BlindAssist/SaudiBanknoteReferenceRecognition.swift');
  assert.match(source, /case \.release:\s+guard pack.allHumanReviewed, pack.minimumCoverage else/);
  assert.match(source, /case \.deviceTest:\s+#if DEBUG && BLIND_CURRENCY_DEVICE_TEST\s+guard pack.deviceTestCoverage else/);
  assert.match(source, /guard digest\(bytes\) == profile.manifestSHA256/);
  assert.match(source, /digest\(data\) == reference.sha256/);
  assert.match(source, /SaudiBanknoteReferencePack.safeRelativePath/);
  assert.match(source, /isSymbolicLink != true/);
  assert.match(source, /totalBytes <= SaudiBanknoteReferencePolicy.Limits.totalReferenceBytes/);
  assert.match(source, /width \* height <= 8_000_000/);
});

test('device output still requires whole-frame rectangle and native evidence gates', async () => {
  const source = await read('ios/BlindAssist/SaudiBanknoteReferenceRecognition.swift');
  assert.match(source, /VNDetectRectanglesRequest/);
  assert.match(source, /guard proposals.count == 1 else \{ return \.multiple \}/);
  assert.match(source, /engine.inspect\(image: cg\)/);
  assert.match(source, /Task.checkCancellation\(\)/);
  assert.doesNotMatch(source, /URLSession|VNRecognizeTextRequest|VNCoreMLRequest/);
});
