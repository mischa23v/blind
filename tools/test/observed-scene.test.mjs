import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
const read = path => readFile(new URL(`../../${path}`, import.meta.url), 'utf8');
const model = await read('ios/BlindAssist/NavigationModel.swift');
const scene = await read('BlindCore/Sources/BlindCore/ObservedScene.swift');
const runtime = await read('ios/BlindAssist/ObservedSceneRuntime.swift');

// Source contracts complement actual portable Swift execution. No ARKit/audio
// or physical performance is asserted by a string/source check.
function assertRequiredOrder(source, earlier, later) {
  const first = source.indexOf(earlier), second = source.indexOf(later);
  assert.ok(first >= 0 && second >= 0 && first < second, `${earlier} must exist before ${later}`);
}
function assertDetectorBeforeOffer(source) {
  const frameStart = source.indexOf('func session(_ session: ARSession, didUpdate frame:');
  assert.ok(frameStart >= 0, 'native frame callback must exist');
  const frame = source.slice(frameStart);
  const offer = frame.indexOf('$0.offer(observation, session: sceneSession');
  const detector = frame.indexOf('detector.process(observation)');
  assert.ok(detector >= 0 && offer >= 0 && detector < offer, 'actual urgent detector must precede scene work');
  const required = frame.includes('let legacyDetection = detector.process(observation)')
    ? ['if legacyDetection.hazard.isUrgent', 'phoneDetection = legacyDetection',
       'phoneDetection = BodyCollisionWarning.combining(legacyDetection, with: bodyAssessment)']
    : ['phoneDetection = detector.process(observation)'];
  for (const assignment of required) {
    const position = frame.indexOf(assignment);
    assert.ok(position >= 0 && position < offer, `${assignment} must precede scene work`);
  }
}
test('observed scene consumes actual depth after urgent detector, off the native owner', () => {
  assertDetectorBeforeOffer(model);
  assert.match(model, /floor: detector\.floorHeight,[\s\S]*?hazard: phoneDetection\.hazard/);
  assert.match(runtime, /queue\.async[\s\S]*worker\.scene\.observe\(observation/);
  assert.match(runtime, /workID == nil/);
  assert.match(runtime, /self\.epoch == generation, self\.session == session, self\.goalRevision == goal/);
  assert.match(runtime, /revalidate\(now: self\.clock\(\)\)/);
});
test('loss/restart/deletion retain explicit capture ownership and retire candidates', () => {
  const frames = model.slice(model.indexOf('func session(_ session: ARSession, didUpdate frame:'));
  assertRequiredOrder(frames, '$0.trackingLost(at: frame.timestamp)', 'guard running');
  assert.match(model, /DepthSampler\.observation\(from: frame\) else \{\s*withObservedScene \{ \$0\.suspendLive\(at: frame\.timestamp\)/);
  assert.match(runtime, /observation\.timestamp > minimumCapture/);
  assert.match(model, /self\.nativeObservations\.begin\(sessionID: sessionID[\s\S]*?self\.withObservedScene \{ \$0\.begin\(session: sessionID, capturedAfter:/);
  assert.equal((model.match(/self\.withObservedScene \{ \$0\.stop\(\) \}\s*self\.nativeObservations\.clearHistory/g) ?? []).length, 2);
});
test('return target comes from the existing recorder/trail, never origin shortcut', () => {
  assert.match(scene, /private var recorder = JourneyRecorder\(\)/);
  assert.match(scene, /returnTrail\.begin\(journey: recorder\.journey/);
  assert.match(scene, /returnTrail\.update\(camera: observation\.camera/);
  assert.match(scene, /guard let recordedTarget = returnTrail\.candidateTarget/);
  assert.doesNotMatch(scene, /target = start\b/);
  assert.match(scene, /\$0\.segment != 0/);
});
test('historical hits cannot reopen missing current support or physical sinks', () => {
  assert.match(scene, /planner\.plan\(observation: current, floor: floor/);
  assert.doesNotMatch(scene, /planner\.plan\(observation:.*cells/);
  for (const source of [scene, runtime]) {
    assert.doesNotMatch(source, /acceptConnectedJourneyCapture\(|acceptRegisteredCapture\(|feedback\.|speakMobility\(|spatialRouteBeacon\(/);
  }
  assert.match(scene, /authorizesPhysicalGuidance: Bool \{ false \}/);
  assert.match(scene, /cells\.count > configuration\.maximumCells/);
});
test('native runtime and its actual portable tests have generated project membership', async () => {
  const project = await read('ios/BlindAssist.xcodeproj/project.pbxproj');
  assert.match(project, /ObservedSceneRuntime\.swift/);
  assert.match(project, /ObservedSceneRuntimeTests\.swift/);
  const generator = await read('tools/generate-xcode-project.mjs');
  assert.match(generator, /'ObservedSceneRuntimeTests\.swift'/);
  assert.match(model, /MainActor\.assumeIsolated \{\s*let runtime = ObservedSceneRuntime\(\)/);
});
test('helper progress is explicitly nonphysical and not auto-announced', async () => {
  const dashboard = await read('ios/BlindAssist/DashboardView.swift');
  assert.match(dashboard, /Text\(model\.observedSceneStatus\)\.accessibilityIdentifier\("observed-scene-planner-status"\)/);
  assert.match(model, /Not walking guidance/);
  assert.doesNotMatch(model, /speak\w*\(observedSceneStatus/);
});

test('new goal and changed body independently fence queued candidate plans', () => {
  assert.match(model, /oldValue\.goalRevision != companionWorkingState\.goalRevision[\s\S]*?bindGoalRevision/);
  assert.match(runtime, /ownerGoalRevision = revision; setIntent\(\.lookAhead\)/);
  assert.match(runtime, /self\.bodyRevision == bodyVersion/);
  assert.match(runtime, /let plan = body\.flatMap/);
  assert.match(model, /body: bodyWarningProfile\?\.recordedBoundsPreview\(\)\?\.envelope/);
  assert.doesNotMatch(model, /body: BodyEnvelope\(\), now:/);
  assertRequiredOrder(runtime, 'now >= observation.timestamp', 'lastOffered = observation.timestamp');
});

test('urgent detector ordering contract rejects missing calls and premature scene work', () => {
  const combined = model.includes('let legacyDetection = detector.process(observation)') ? model : model.replace(
    'phoneDetection = detector.process(observation)',
    `let legacyDetection = detector.process(observation)
        if legacyDetection.hazard.isUrgent {
            phoneDetection = legacyDetection
        } else {
            phoneDetection = BodyCollisionWarning.combining(legacyDetection, with: bodyAssessment)
        }`);
  for (const source of [model, combined]) {
    assertDetectorBeforeOffer(source);
    assert.throws(() => assertDetectorBeforeOffer(source.replaceAll('detector.process(observation)', 'detector.unavailable(observation)')));
    assert.throws(() => assertDetectorBeforeOffer(source.replace('detector.process(observation)', '$0.offer(observation, session: sceneSession); detector.process(observation)')));
  }
  assert.throws(() => assertDetectorBeforeOffer(combined.replace('phoneDetection = legacyDetection', 'phoneDetection = Detection(.uncertain)')));
  assert.throws(() => assertDetectorBeforeOffer(combined.replace('phoneDetection = BodyCollisionWarning.combining(legacyDetection, with: bodyAssessment)', 'phoneDetection = Detection(.uncertain)')));
});

test('capture-loss and timestamp-order contracts reject absent guard tokens', () => {
  for (const [source, first, second] of [
    [model.slice(model.indexOf('func session(_ session: ARSession, didUpdate frame:')), '$0.trackingLost(at: frame.timestamp)', 'guard running'],
    [runtime, 'now >= observation.timestamp', 'lastOffered = observation.timestamp']
  ]) {
    assertRequiredOrder(source, first, second);
    assert.throws(() => assertRequiredOrder(source.replaceAll(first, ''), first, second));
    assert.throws(() => assertRequiredOrder(source.replaceAll(second, ''), first, second));
  }
});
