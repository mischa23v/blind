import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const root = new URL('../../', import.meta.url);
const read = p => readFileSync(new URL(p, root), 'utf8');
const sampler = read('ios/BlindAssist/DepthSampler.swift');
const policy = read('BlindCore/Sources/BlindCore/NativeDepthObservationPolicy.swift');
const nav = read('ios/BlindAssist/NavigationModel.swift');
const runtime = read('ios/BlindAssist/ObservedSceneRuntime.swift');
function before(s, first, second) {
  const a = s.indexOf(first), b = s.indexOf(second);
  assert.ok(a >= 0 && b >= 0 && a < b, `${first} must occur before ${second}`);
}
function nativeBinding(s) {
  const observation = s.slice(s.indexOf('static func observation('));
  for (const token of ['NativeDepthObservationPolicy.projection(',
    'NativeDepthObservationPolicy.horizontalForward(',
    'NativeDepthObservationPolicy.acceptedDepth(',
    'depths[column], confidence: confidences[column]',
    'transform * SIMD4<Float>(Float(camera.x), Float(camera.y), Float(camera.z), 1)',
    'CVPixelBufferLockBaseAddress(buffer, .readOnly)',
    'defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }',
    'defer { CVPixelBufferUnlockBaseAddress(confidence, .readOnly) }']) assert.ok(observation.includes(token), token);
  assert.equal((observation.match(/by: NativeDepthObservationPolicy\.pixelStride/g) ?? []).length, 2);
  before(observation, 'NativeDepthObservationPolicy.horizontalForward(', 'var samples:');
  before(observation, 'NativeDepthObservationPolicy.acceptedDepth(', 'projection.cameraPoint(');
}
test('native hazard sampler uses shared policy without copying buffers or changing world transform', () => {
  nativeBinding(sampler);
  for (const token of ['NativeDepthObservationPolicy.projection(', 'NativeDepthObservationPolicy.horizontalForward(', 'NativeDepthObservationPolicy.acceptedDepth(', 'by: NativeDepthObservationPolicy.pixelStride']) {
    assert.throws(() => nativeBinding(sampler.replace(token, 'MUTATED')));
  }
  const lookup = sampler.slice(sampler.indexOf('static func worldPoint('),sampler.indexOf('static func observation('));
  assert.match(lookup,/confidences\[c\] >= 1/);
  assert.match(lookup,/\(0\.15\.\.\.8\)\.contains\(value\)/);
});
test('shared values retain native hazard semantics and Float-to-Double order', () => {
  for (const token of ['pixelStride = 2','requiredConfidence: UInt8 = 2','depthRange = 0.15...5.0',
    'minimumHorizontalOpticalLength: Float = 0.25','let value = Double(depth)',
    'Double(fx) * sx','let horizontalLength = hypot(opticalX, opticalZ)',
    'guard horizontalLength > minimumHorizontalOpticalLength else { return nil }']) {
    assert.ok(policy.includes(token));
    assert.ok(!policy.replace(token,'MUTATED').includes(token));
  }
});
test('existing ingress cadence and nil invalidation still precede detector; runtime cadence stays owned', () => {
  const frames=nav.slice(nav.indexOf('func session(_ session: ARSession, didUpdate frame: ARFrame)'));
  const check = s => {
    before(s,'frame.timestamp - lastProcessed >= 1.0 / 15','DepthSampler.observation(from: frame)');
    before(s,'FrameTimestampPolicy.isFresh','lastProcessed = frame.timestamp');
    before(s,'$0.suspendLive(at: frame.timestamp)','detector.process(observation)');
    before(s,'detector.invalidateRecentEvidence()','detector.process(observation)');
  };
  check(frames);
  for(const token of ['frame.timestamp - lastProcessed >= 1.0 / 15','FrameTimestampPolicy.isFresh','$0.suspendLive(at: frame.timestamp)','detector.invalidateRecentEvidence()']) assert.throws(()=>check(frames.replace(token,'MUTATED')));
  assert.match(runtime,/observation\.timestamp - lastOffered >= 0\.1/);
  assert.match(runtime,/self\.revalidate\(now: self\.clock\(\)\)/);
});
