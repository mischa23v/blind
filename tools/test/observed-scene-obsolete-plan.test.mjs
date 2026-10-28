import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

// Source contracts only. Native XCTest executes the actual accumulator/planner;
// these checks do not establish native compilation, runtime timing or safety.
const read = path => readFile(new URL(`../../${path}`, import.meta.url), 'utf8');
const runtime = await read('ios/BlindAssist/ObservedSceneRuntime.swift');
const cases = await read('ios/BlindAssistTests/ObservedSceneRuntimeTests.swift');
const helper = await read('tools/ci/native-apple.sh');

function ordered(source, ...needles) {
  let offset = 0;
  for (const needle of needles) {
    const index = source.indexOf(needle, offset);
    assert.ok(index >= offset, `Missing or reordered ${needle}`);
    offset = index + needle.length;
  }
}
function checkWorker(source) {
  const worker = source.slice(source.indexOf('queue.async { [weak self] in'));
  ordered(worker, 'worker.scene.observe(observation', 'let plan = body.flatMap',
    'guard validity.isCurrent else { return nil }', 'worker.scene.planCurrent(',
    'DispatchQueue.main.async', 'guard let self, self.workID == id',
    'self.workID = nil', 'self.planValidity = nil',
    'self.epoch == generation, self.session == session, self.goalRevision == goal, self.bodyRevision == bodyVersion',
    'self.snapshot = snapshot; self.plan = plan', 'self.revalidate(now: self.clock())');
}

test('obsolete-plan check follows retained observation and precedes only actual planning', () => {
  checkWorker(runtime);
  for (const changed of [
    runtime.replace('guard validity.isCurrent else { return nil }', ''),
    runtime.replace('let snapshot = worker.scene.observe(observation, sessionID: session, now: now, hazard: hazard)',
      'let snapshot = worker.scene.snapshot()'),
    runtime.replace('self.workID = nil', ''),
    runtime.replace('self.bodyRevision == bodyVersion', 'true'),
    runtime.replace('self.revalidate(now: self.clock())', '')
  ]) assert.throws(() => checkWorker(changed));
});

test('one locked token per admitted job; retirement does not free the busy slot', () => {
  assert.match(runtime, /func invalidate\(\) \{ lock\.lock\(\); current = false; lock\.unlock\(\) \}/);
  assert.match(runtime, /var isCurrent: Bool \{ lock\.lock\(\); defer \{ lock\.unlock\(\) \}; return current \}/);
  ordered(runtime, 'workID == nil', 'workID = id', 'let validity = PlanValidity()', 'planValidity = validity', 'queue.async');
  assert.equal((runtime.match(/workID = nil/g) ?? []).length, 1);
  assert.equal((runtime.match(/planValidity = nil/g) ?? []).length, 1);
  const retirementSignatures = ['func begin(session:', 'func stop()', 'func trackingLost(',
    'func setIntent(', 'func invalidateBody()', 'func suspendLive('];
  function checkRetirements(source) {
    for (const signature of retirementSignatures) {
      const start = source.indexOf(signature);
      const end = source.indexOf('\n    }', start);
      const body = source.slice(start, end);
      assert.ok(start >= 0 && end > start);
      assert.ok(body.includes('planValidity?.invalidate()'), signature);
      assert.doesNotMatch(body, /workID\s*=\s*nil|planValidity\s*=\s*nil/);
    }
  }
  checkRetirements(runtime);
  for (const signature of retirementSignatures) {
    const start = runtime.indexOf(signature);
    const marker = runtime.indexOf('planValidity?.invalidate()', start);
    assert.throws(() => checkRetirements(runtime.slice(0, marker) + runtime.slice(marker + 'planValidity?.invalidate()'.length)));
  }
});

test('existing freshness, QoS, single slot, frame size and original latency assertion remain', () => {
  assert.match(runtime, /DispatchQueue\(label: "blind\.observed-scene", qos: \.utility\)/);
  assert.match(runtime, /now - observation\.timestamp <= 0\.5/);
  assert.match(runtime, /now - captured > 0\.5/);
  assert.match(runtime, /observation\.timestamp - lastOffered >= 0\.1/);
  assert.match(cases, /for x in -25\.\.\.25 \{ for z in 3\.\.\.55/);
  assert.match(cases, /XCTAssertLessThanOrEqual\(elapsed, 1\.2, "Original latency budget exceeded; functional completion is not a speed claim"\)/);
  assert.equal((cases.match(/XCTAssertEqual\((goalTiming|bodyTiming|freshTiming)\?\.planWasInvoked, false\)/g) ?? []).length, 3);
});

test('bounded DEBUG timing keeps extraction prefix and brackets actual planning separately', () => {
  assert.match(runtime, /private var times: \[TimeInterval\?\] = \[nil, nil, nil, nil, nil, nil, nil\]/);
  assert.doesNotMatch(runtime, /print\(/);
  for (const field of ['admitted=', 'workerStarted=', 'workerFinished=', 'mainDelivered=',
    'queueAdmission=', 'workerWall=', 'mainHandoff=', 'observeWall=', 'planInvoked=', 'planWall=']) assert.ok(runtime.includes(field));
  for (const phase of ['admitted', 'workerStarted', 'observationFinished', 'planStarted', 'planFinished', 'workerFinished', 'mainDelivered']) {
    assert.equal((runtime.match(new RegExp(`timing\\.mark\\(\\.${phase}\\)`, 'g')) ?? []).length, 1);
  }
  ordered(runtime, 'worker.scene.observe(', 'timing.mark(.observationFinished)', 'guard validity.isCurrent',
    'timing.mark(.planStarted)', 'worker.scene.planCurrent(', 'timing.mark(.planFinished)',
    'afterPlanning?()', 'timing.mark(.workerFinished)', 'DispatchQueue.main.async', 'timing.mark(.mainDelivered)');
  assert.match(helper, /grep -E '\^OBSERVED_SCENE_FENCE_\(PHASE\|LATENCY\) '.*head -8.*cut -c 1-1500/);
});

test('native regressions retain history without using it as support and cover late invalidation', () => {
  for (const token of [
    'func testQueuedObsoletePlanKeepsHistoryAndNextValidPlanStillRuns()',
    'frame(1.2, sparse: true)', '$0.lastSeen == 1', '.unknownTerrain', '.candidatePath',
    'func testInvalidationAfterPlanningCompletesBeforeDeliveryRetainsBusySlot()',
    'for changeBody in [false, true]', 'await fulfillment(of: [gate.entered], timeout: 5)',
    'XCTAssertNil(gate.releasedNormally)', 'XCTAssertEqual(gate.releasedNormally, true)',
    'XCTAssertFalse(forbiddenPublication)', 'runtime.diagnosticAfterPlanningForTesting = nil'
  ]) assert.ok(cases.includes(token), token);
  ordered(cases.slice(cases.indexOf('func testInvalidationAfterPlanningCompletesBeforeDelivery')),
    'await fulfillment(of:', 'if changeBody { runtime.invalidateBody()',
    'XCTAssertFalse(runtime.offer(', 'gate.release.signal()', 'try await runtime.waitForCurrentWorkForTesting()');
});
