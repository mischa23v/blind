import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { assertDepthHazardsBefore, declaration, depthHazardsCall, frameSignature, withoutComments } from './helpers/navigation-source-contract.mjs';
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
  const frames = declaration(nav, frameSignature);
  const nilDepthSignature = 'guard let observation = DepthSampler.observation(from: frame) else';
  const background = 'updateBackgroundPerception(frame: frame, observation: observation, nonspatialOnly: !observation.trackingNormal)';
  const normalize = value => value.replace(/\s+/g, ' ').trim();
  const check = source => {
    const frame = declaration(withoutComments(source), frameSignature);
    before(frame, 'frame.timestamp - lastProcessed >= 1.0 / 15', 'DepthSampler.observation(from: frame)');
    before(frame, 'FrameTimestampPolicy.isFresh', 'lastProcessed = frame.timestamp');
    // Limit inspection to this guard: a later helper's copy cannot hide a removed
    // nil-depth invalidation or make an adversarial mutation look unchanged.
    const missing = declaration(frame, nilDepthSignature);
    const body = normalize(missing.slice(missing.indexOf('{') + 1, -1));
    assert.ok(body.startsWith('withObservedScene { $0.suspendLive(at: frame.timestamp) }'), 'Nil-depth scene retirement is the first synchronous statement');
    assert.ok(body.endsWith(normalize(`detector.invalidateRecentEvidence()
        phoneDetection = Detection(.uncertain, reason: DepthSampler.unavailableReason(from: frame)); lastObservation = nil; publish()
        updateNonspatialObjectMemory(frame: frame)
        return`)), 'Nil-depth evidence invalidation and publication directly precede RGB fallback and return');
    before(frame, nilDepthSignature, depthHazardsCall);
    // Verify the actual synchronous helper and assignments, not just a renamed call.
    assertDepthHazardsBefore(source, background);
  };
  check(nav);
  const mutateFrame = (from, to) => {
    assert.ok(frames.includes(from));
    return nav.replace(frames, frames.replace(from, to));
  };
  const mutants = [
    ...['frame.timestamp - lastProcessed >= 1.0 / 15', 'FrameTimestampPolicy.isFresh',
      '$0.suspendLive(at: frame.timestamp)', 'detector.invalidateRecentEvidence()'].map(token => mutateFrame(token, 'MUTATED')),
    mutateFrame('detector.invalidateRecentEvidence()', 'Task { detector.invalidateRecentEvidence() }'),
    mutateFrame('withObservedScene { $0.suspendLive(at: frame.timestamp) }', 'Task { withObservedScene { $0.suspendLive(at: frame.timestamp) } }'),
    mutateFrame('lastObservation = nil; publish()', 'lastObservation = nil'),
    mutateFrame(depthHazardsCall, `Task { ${depthHazardsCall} }`),
    mutateFrame(depthHazardsCall, `defer { ${depthHazardsCall} }`),
    mutateFrame(depthHazardsCall, '').replace(background, `${background}\n${depthHazardsCall}`),
    nav.replace('let legacyDetection = detector.process(observation)', 'let legacyDetection = Detection(.observing)'),
    nav.replace('phoneDetection = legacyDetection', '/* missing urgent publication */')
  ];
  for (const mutant of mutants) {
    assert.notEqual(mutant, nav);
    assert.throws(() => check(mutant), { name: 'AssertionError' });
  }
  assert.match(runtime,/observation\.timestamp - lastOffered >= 0\.1/);
  assert.match(runtime,/self\.revalidate\(now: self\.clock\(\)\)/);
});
