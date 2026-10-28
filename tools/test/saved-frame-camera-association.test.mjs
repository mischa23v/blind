// Source contracts only, not ARKit execution, localization accuracy or guidance acceptance.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { declaration, frameSignature, withoutComments } from './helpers/navigation-source-contract.mjs';

const read = path => readFileSync(new URL(`../../${path}`, import.meta.url), 'utf8');
const core = read('BlindCore/Sources/BlindCore/SavedWorldFrame.swift');
const places = read('ios/BlindAssist/PlaceStore.swift');
const navigation = read('ios/BlindAssist/NavigationModel.swift');

test('saved-frame camera receipt is opaque diagnostic association, not registration or physical evidence', () => {
  const receipt = withoutComments(declaration(core, 'public struct SavedWorldFrameCameraAssociation:'));
  assert.match(receipt, /Equatable, Sendable/);
  assert.doesNotMatch(receipt, /Codable|Decodable|public init|NativeCameraTransform|SpatialLocalizationCapture|SpatialFloorSupport/);
  assert.match(receipt, /fileprivate init\(frame: SavedWorldFrame, sessionID: UUID, recoveryID: UUID, capturedAt: Double\)/);
  assert.match(receipt, /var reference: Reference \{ \.camera \}/);
  assert.match(receipt, /var uncertainty: Uncertainty \{ \.unmeasured \}/);
  assert.match(receipt, /var permitsPhysicalGuidance: Bool \{ false \}/);
  const mint = declaration(core, 'public func cameraAssociation(');
  assert.match(mint, /guard let lastValidatedAt, capturedAt == lastValidatedAt,/);
  assert.match(mint, /current\(sessionID: sessionID, now: now\)/);
  assert.match(mint, /recoveryID: recoveryID, capturedAt: capturedAt/);
});

test('pre-throttle tracking seam ignores older/foreign ownership and cannot establish normal-frame evidence', () => {
  const hook = withoutComments(declaration(core, 'public mutating func observeTrackingInterruption('));
  assert.match(hook, /guard self\.sessionID == sessionID, let startedAt,/);
  assert.match(hook, /frameTime\.isFinite, frameTime >= startedAt,/);
  assert.match(hook, /lastFrameTime\.map\(\{ frameTime > \$0 \}\) \?\? true else \{ return \}/);
  assert.match(hook, /case \.normal: return/);
  assert.match(hook, /mappingAvailable: false,\s*originAnchorMatches: false, frameTime: frameTime, now: now/);
  const native = withoutComments(declaration(places, 'func observeWorldMapTrackingInterruption('));
  assert.match(native, /case \.normal: return/);
  assert.match(native, /case \.limited\(\.relocalizing\): tracking = \.relocalizing/);
  assert.match(native, /default: tracking = \.unavailable/);
  assert.doesNotMatch(native, /\.anchors|Data\(|Task|DispatchQueue|\.reset\(/);
});

test('native callbacks enforce the exact ARSession before recovery or lifecycle mutation', () => {
  for (const signature of [frameSignature,
    'func session(_ session: ARSession, didFailWithError error: Error)',
    'func sessionWasInterrupted(_ session: ARSession)',
    'func sessionInterruptionEnded(_ session: ARSession)']) {
    const body = withoutComments(declaration(navigation, signature));
    assert.match(body.slice(body.indexOf('{') + 1), /^\s*guard session === self\.session else \{ return \}/);
  }
  for (const signature of ['func session(_ session: ARSession, didFailWithError error: Error)',
    'func sessionWasInterrupted(_ session: ARSession)']) {
    const body = withoutComments(declaration(navigation, signature));
    assert.match(body, /guard session === self\.session else \{ return \}\s*places\.invalidateWorldMapRecovery\(\)/);
  }
  const frame = withoutComments(declaration(navigation, frameSignature));
  assert.ok(frame.indexOf('places.observeWorldMapTrackingInterruption(') < frame.indexOf('frame.timestamp - lastProcessed'));
  assert.equal((frame.match(/observeWorldMapRecovery\(for: place, frame: frame, sessionID: [^,]+, now: receivedAt\)/g) ?? []).length, 2);
  assert.doesNotMatch(frame, /observeWorldMapRecovery\([^\n]+now: lastFrameWallTime/);
});

test('association seam forwards the exact capture without filling a transform or adding an authority consumer', () => {
  const seam = withoutComments(declaration(places, 'func cameraWorldFrameAssociation('));
  assert.match(seam, /now: Double = ProcessInfo\.processInfo\.systemUptime/);
  assert.match(seam, /worldFrameRecovery\.cameraAssociation\(sessionID: sessionID, capturedAt: capturedAt, now: now\)/);
  assert.doesNotMatch(seam, /\.identity|sourceToMap|alignment|accept|SpatialLocalization/);
  const fixtures = read('BlindCore/Tests/BlindCoreTests/SavedWorldFrameTests.swift');
  for (const name of ['CameraAssociationRequiresExactLatestAcceptedCaptureAndRealClock',
    'CameraAssociationDoesNotRenewAfterDelayedCallback', 'ThrottledFinalRelocalizingCallbackCanSeedThreeNormalFrames',
    'ThrottledTrackingLossWithdrawsAssociationUntilFreshRelocalization', 'ObsoleteInterruptionCannotWithdrawNewerNativeAssociation',
    'AssociationResetAndNewBeginNeverReuseRecoveryEpoch', 'UnverifiedNormalTrackingAndBadAnchorNeverMintAssociation',
    'StaleOrFutureInterruptionFailsClosedWithoutMintingAssociation']) {
    assert.match(fixtures, new RegExp(`func test${name}\\(`));
  }
});
