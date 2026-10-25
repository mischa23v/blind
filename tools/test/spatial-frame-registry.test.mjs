import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

// Source contracts only. These checks do not execute Swift, transform math, ARKit,
// localization, routing or physical collision logic. XCTest cases require Swift.
const registry = await readFile(new URL('../../BlindCore/Sources/BlindCore/SpatialFrameRegistry.swift', import.meta.url), 'utf8');
const lease = await readFile(new URL('../../BlindCore/Sources/BlindCore/SpatialLocalizationLease.swift', import.meta.url), 'utf8');
const swiftTests = await readFile(new URL('../../BlindCore/Tests/BlindCoreTests/SpatialFrameRegistryTests.swift', import.meta.url), 'utf8');

function between(text, start, end) {
  assert.ok(text.includes(start), `missing start: ${start}`);
  assert.ok(text.includes(end), `missing end: ${end}`);
  return text.slice(text.indexOf(start), text.indexOf(end, text.indexOf(start)));
}

test('spatial source contract: durable snapshot excludes live pose and confidence', () => {
  const snapshot = between(registry, 'public struct SpatialRegistrySnapshot:', 'public enum SpatialRegistryError:');
  for (const field of ['nodes', 'maps', 'activeBindings', 'links', 'transitions']) assert.match(snapshot, new RegExp(`public let ${field}:`));
  assert.doesNotMatch(snapshot, /public (?:let|var) (?:pose|position|sessionID|capturedAt|confidence|tracking|accepted):/);
  for (const name of ['SpatialLocalizationCapture', 'SpatialOutputLease', 'SpatialLocalizationLease']) {
    const declaration = lease.match(new RegExp(`public struct ${name}: ([^{]+)\\{`));
    assert.ok(declaration);
    assert.doesNotMatch(declaration[1], /Codable|Decodable|Encodable/);
  }
});

test('spatial source contract: registry reuses geometry and saved-map types without a new planner', () => {
  assert.match(registry, /translation: Point3/);
  assert.match(registry, /savedWorldFrame: SavedWorldFrame\?/);
  assert.match(registry, /validateIndoorMap\(_ indoorMap: IndoorMap/);
  assert.match(registry, /try indoorMap\.validate\(\)/);
  assert.match(registry, /indoorMap\.packageID == binding\.mapID/);
  assert.match(registry, /indoorMap\.packageRevision == binding\.revision/);
  assert.doesNotMatch(registry + lease, /import (?:ARKit|CoreLocation)|URLSession|SQLite|func route\(/);
});

test('spatial source contract: metric scale and unknown-floor checks are explicit', () => {
  assert.match(registry, /guard map\.metersPerUnit == 1 else/);
  assert.match(registry, /map\.floorLevels\.values\.contains\(floorID\)/);
  assert.match(registry, /nodes\[roomID\]\?\.parentID == floorID/);
  assert.match(registry, /record\.floorLevels\[\$0\] != nil/);
  assert.match(registry, /case \.world: expected = nil/);
  for (const kind of ['world', 'place', 'building', 'floor']) assert.match(registry, new RegExp(`expected = \\.${kind}`));
});

test('spatial source contract: exact active binding and missing transform fail closed', () => {
  assert.match(registry, /snapshot\.activeBindings\.contains\(binding\)/);
  assert.match(registry, /if from == to \{ return \.identity \}/);
  assert.match(registry, /throw SpatialRegistryError\.missingTransform/);
  assert.match(registry, /targetToCommon\.inverted\(\)\.composed\(after: sourceToCommon\)/);
  assert.match(registry, /visited\.insert\(current\)\.inserted/);
  assert.match(registry, /next\.maps\.contains\(\$0\)/);
  assert.match(registry, /next\.links\.contains\(\$0\)/);
});

test('spatial source contract: GPS, room appearance and camera-only heading cannot admit a pose', () => {
  assert.match(lease, /capture\.source == \.alignedMapPose/);
  assert.match(lease, /capture\.headingSource == \.bodyAligned/);
  assert.match(lease, /capture\.trackingNormal/);
  assert.match(lease, /capture\.positionUncertainty <= limits\.maximumPositionUncertainty/);
  assert.match(lease, /capture\.headingUncertainty <= limits\.maximumHeadingUncertainty/);
  assert.match(lease, /try registry\.validateLocation\(floorID: capture\.floorID, roomID: capture\.roomID, in: capture\.binding\)/);
});

test('spatial source contract: capture age, session, replay and invalidation are checked', () => {
  assert.match(lease, /capture\.sessionID == sessionID/);
  assert.match(lease, /capture\.capturedAt > \$0/);
  assert.match(lease, /now >= capture\.capturedAt/);
  assert.match(lease, /now - capture\.capturedAt <= limits\.maximumCaptureAge/);
  assert.match(lease, /maximumCaptureAge <= SavedWorldFrameRecovery\.maximumFrameAge/);
  const accept = between(lease, 'public mutating func accept(', 'public func current(');
  assert.ok(accept.indexOf('accepted = nil') < accept.indexOf('try validate('));
  assert.match(lease, /sessionID = UUID\(\); accepted = nil; acceptanceID = nil; acceptedInstallationID = nil; lastFrameTime = nil/);
  assert.match(lease, /public mutating func loseTracking\(\) \{ restart\(\) \}/);
});

test('spatial source contract: route and collision leases bind purpose, map, revision, floor and capture', () => {
  assert.match(lease, /guard binding == capture\.binding, floorID == capture\.floorID else/);
  assert.match(lease, /output\.purpose == purpose/);
  assert.match(lease, /output\.binding == capture\.binding/);
  assert.match(lease, /output\.floorID == capture\.floorID/);
  assert.match(lease, /output\.captureID == capture\.id/);
  assert.match(lease, /output\.sessionID == sessionID/);
  assert.match(lease, /output\.acceptanceID == acceptanceID/);
  assert.match(lease, /acceptedInstallationID == registry\.installationID/);
  assert.match(lease, /accepted = capture; acceptanceID = UUID\(\)/);
  assert.match(lease, /try\? validate\(accepted, registry: registry, now: now\)/);
});

test('spatial source contract: pending XCTest coverage names the required failure cases', () => {
  const required = ['RotatedRoomToBuildingAndSiblingFloor', 'InverseAndCompositionPreservePositionAndHeading',
    'MissingTransformNeverFallsBackToIdentity', 'MapLabelsOrSameFrameStringDoNotEstablishConnection',
    'MissingOrNonMetricScaleRejected', 'InvalidParentAndDuplicateNodeRejected',
    'FrameCyclesDuplicateParentAndNonfiniteTransformRejected', 'UnknownAndWrongFloorRejected',
    'DoorwayCannotPretendToChangeFloor', 'NewRevisionRetainsHistoryAndRejectsOldBinding',
    'UpdateCannotRewriteOrDiscardMapHistoryOrTransform', 'IndoorMapAdapterUsesExplicitFloorAndPackageRevision',
    'SavedWorldFrameCannotBeAttachedToUnrelatedFrame', 'GPSAndRoomAppearanceNeverEstablishPose',
    'FreshAlignedCaptureSupportsOnlyItsExactOutputBinding', 'CameraHeadingTrackingLossAndUncertaintyReject',
    'ExpiredFutureAndWrongSessionCapturesReject', 'ReplayAndRejectedNewObservationInvalidateCurrentPose',
    'NewCaptureInvalidatesQueuedOldResult', 'RevisionChangeInvalidatesPoseAndQueuedCollision',
    'RestartPreservesMapHistoryButNotPoseOrOldSessionAuthority', 'ExplicitTrackingLossRetiresOutputs',
    'TrackingLossRejectsNewerInflightCaptureFromOldOwnership',
    'CaptureIDReuseAfterReplayCacheRolloverCannotReviveOldLease',
    'SnapshotReplacementCannotReviveCaptureEvenWhenBindingMatches',
    'IndependentAcceptanceInCopiedGateCannotShareOutputLease', 'InvalidPolicyCannotAdmitCapture'];
  for (const name of required) assert.match(swiftTests, new RegExp(`func test${name}\\(`));
  assert.match(swiftTests, /Synthetic policy\/geometry fixtures, not sensor localization/);
});
