import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const root = new URL('../../', import.meta.url);
const read = p => readFileSync(new URL(p, root), 'utf8');
const source = read('ios/BlindAssist/NavigationModel.swift');
function between(s, a, b) {
  const start = s.indexOf(a), end = s.indexOf(b, start + a.length);
  assert.ok(start >= 0 && end > start, `${a} -> ${b}`); return s.slice(start, end);
}
function contracts(s) {
  const scene = between(s, 'func readScene(', 'private static func wordCount(');
  assert.match(scene, /let frame = session.currentFrame, let capture = captureObjectView\(frame\)/);
  assert.match(scene, /let origin = capture.origin, originForward = capture.forward/);
  assert.match(scene, /let originHeading = NativeDepthObservationPolicy.horizontalForward/);
  assert.equal((scene.match(/queueQuestion\(question, cloud: cloud, focus: focus, camera: origin, forward: originHeading\)/g) ?? []).length, 2);
  assert.match(scene, /let image = frame.capturedImage, capturedAt = capture.capturedAt/);
  assert.doesNotMatch(scene, /capturedAt = lastFrameWallTime|let origin = lastObservation\?\.camera/);
  assert.ok(scene.indexOf('captureObjectView(frame)') < scene.indexOf('VisionService.inspect(image: image'));
  const extra = between(scene, 'for _ in 0..<2 {', 'let confirmedObjects =');
  for (const token of ['let laterCapture = self.captureObjectView(laterFrame)', 'laterCapture.generation == capture.generation',
    'laterCapture.sessionGeneration == capture.sessionGeneration', '!groundingTimestamps.contains(laterFrame.timestamp)',
    'RequestedVisualCapturePose.poseStable(origin: origin, current: laterCapture.origin',
    'originForward: originForward, currentForward: laterCapture.forward']) assert.ok(extra.includes(token), token);
  assert.ok(extra.indexOf('poseStable') < extra.indexOf('groundingFrame(image: later'));
  const deliver = between(scene, 'guard let deliveryFrame', '// Generic VLM');
  for (const token of ['captureObjectView(deliveryFrame)', 'deliveryCapture.generation == capture.generation',
    'deliveryCapture.sessionGeneration == capture.sessionGeneration', 'RequestedVisualCapturePose.sceneDeliveryAllowed',
    'currentFrameAt: deliveryCapture.capturedAt', 'tracking: self.lastObservation?.trackingNormal == true']) assert.ok(deliver.includes(token), token);
  assert.match(scene, /self.modelSceneCapture = \(lease.id, capturedAt, origin, originForward, capture.generation, capture.sessionGeneration\)/);
  const reply = between(s, 'private func modelReplyAllowed(', 'private func retainedModelReply(');
  for (const token of ['captureObjectView(frame)', 'current.generation == capture.generation', 'current.sessionGeneration == capture.sessionGeneration',
    'RequestedVisualCapturePose.sceneDeliveryAllowed', 'currentFrameAt: current.capturedAt', 'tracking: lastObservation?.trackingNormal == true']) assert.ok(reply.includes(token), token);
}
test('scene pixels use their actual camera receipt through grounding and delayed delivery', () => contracts(source));
test('existing receipt rejects stale future nonfinite replayed and invalid-pose RGB input', () => {
  const capture = between(source, 'private func captureObjectView(', '/// Live search');
  for (const token of ['capturedAt: frame.timestamp', 'frame.camera.transform', 'case .normal = frame.camera.trackingState',
    'capture.capturedAt.isFinite', 'now >= capture.capturedAt', 'FrameTimestampPolicy.isFresh(capturedAt: frame.timestamp',
    'capture.capturedAt <= frame.timestamp', 'passiveObservationGeneration == capture.generation',
    'assistantSession.generation == capture.sessionGeneration', 'RequestedVisualCapturePose.poseStable']) assert.ok(capture.includes(token), token);
  const policy = read('BlindCore/Sources/BlindCore/ContextualTextPolicy.swift');
  assert.match(policy, /capturedAt.isFinite && receivedAt.isFinite && capturedAt >= 0/);
  assert.match(policy, /receivedAt >= capturedAt && receivedAt - capturedAt <= 0.5/);
});
test('source substitutions cannot silently detach evidence from frame time pose or epoch', () => {
  const mutations = [
    s => s.replace('let image = frame.capturedImage, capturedAt = capture.capturedAt', 'let image = frame.capturedImage, capturedAt = lastFrameWallTime'),
    s => s.replace('let origin = capture.origin, originForward = capture.forward', 'let origin = lastObservation!.camera, originForward = lastObservation!.forward'),
    s => s.replace('laterCapture.generation == capture.generation', 'true'),
    s => s.replace('laterCapture.sessionGeneration == capture.sessionGeneration', 'true'),
    s => s.replace('currentFrameAt: deliveryCapture.capturedAt', 'currentFrameAt: self.lastFrameWallTime'),
    s => s.replace('current.generation == capture.generation', 'true'),
    s => s.replace('currentFrameAt: current.capturedAt', 'currentFrameAt: lastFrameWallTime'),
  ];
  for (const mutation of mutations) { const changed = mutation(source); assert.notEqual(changed, source); assert.throws(() => contracts(changed)); }
});
test('existing no-absence and physical-safety gates remain ahead of scene output', () => {
  const scene = between(source, 'func readScene(', 'private static func wordCount(');
  for (const token of ['VisualGrounding.groundedDescription($0, confirmed: confirmedObjects)',
    'SaudiBanknotePolicy.containsUnverifiedMoneyValue(answer)', 'if fromModel && SpatialClaimGuard.containsSpatialClaim(answer)',
    'if fromModel && ClothingColorCommand.containsUnverifiedColorClaim(answer)', 'if automatic && !self.ambientDescriptions']) {
    assert.ok(scene.indexOf(token) >= 0 && scene.indexOf(token) < scene.indexOf('self.deliverCandidate('), token);
  }
});

test('scene adapter preserves optical pitch checks and normalizes only legacy yaw input', () => {
  const helper = read('BlindCore/Sources/BlindCore/RequestedVisualCapturePose.swift');
  const adapter = helper.slice(helper.indexOf('public static func sceneDeliveryAllowed('));
  assert.ok(adapter.indexOf('guard poseStable(') < adapter.indexOf('SceneDelivery.allowed('));
  assert.equal((adapter.match(/NativeDepthObservationPolicy.horizontalForward/g) ?? []).length, 2);
  assert.match(adapter, /originForward: sourceHeading, currentForward: currentHeading/);
  const fixture = read('BlindCore/Tests/BlindCoreTests/SceneFrameProvenanceTests.swift');
  assert.match(fixture, /testStablePitchedViewDoesNotLoseItsLegacyYaw/);
  assert.match(fixture, /testPitchOnlyChangeIsStillRejected/);
});
