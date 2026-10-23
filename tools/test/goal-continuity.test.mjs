// Source contracts complement IndoorGoalContinuityTests in the hosted Apple app.
// They do not establish live localization, camera accuracy, speech or model behavior.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const read = path => readFile(new URL(`../../${path}`, import.meta.url), 'utf8');
const body = (source, start, end) => {
  const a = source.indexOf(start);
  const b = source.indexOf(end, a + start.length);
  assert.ok(a >= 0 && b > a, `${start} → ${end}`);
  return source.slice(a, b);
};

test('route cancellation does not erase or manufacture measured alignment', async () => {
  const source = await read('ios/BlindAssist/IndoorNavigator.swift');
  const cancel = body(source, 'func cancelRoute()', 'func invalidatePosition()');
  assert.match(cancel, /route = \[\]; waypointIndex = 0; suggestedDestination = nil/);
  assert.match(cancel, /message = text\("No active route\.", "لا يوجد مسار نشط\."\)/);
  assert.doesNotMatch(cancel, /(?:anchorWorld|anchorMap|worldForward|mapForward|alignedLevel|alignmentRevision)\s*=/);
  const invalidate = body(source, 'func invalidatePosition()', 'func situation(');
  for (const field of ['anchorWorld', 'anchorMap', 'worldForward', 'mapForward', 'alignedLevel']) {
    assert.ok(invalidate.includes(`${field} = nil`), `${field} must clear on actual pose loss`);
  }
  assert.match(invalidate, /alignmentRevision = UUID\(\)/);
  assert.match(invalidate, /cancelRoute\(\)/);
});

test('retained alignment still has freshness gates and replan invalidates it', async () => {
  const source = await read('ios/BlindAssist/IndoorNavigator.swift');
  const situation = body(source, 'func situation(', 'func mapDirection(');
  assert.match(situation, /if tracking, frameAge.isFinite, \(0\.\.\.0\.5\).contains\(frameAge\)/);
  const plan = body(source, 'func plan(', 'func addKeepOutZone(');
  assert.match(plan, /invalidatePosition\(\)/);
  const next = body(source, 'func next(', 'func confirmArrival()');
  assert.match(source, /var hasActiveRoute: Bool \{ waypointIndex >= 0 && waypointIndex < route.count \}/);
  assert.match(next, /guard hasActiveRoute/);
});

test('goal continuity has native regression fixtures rather than supplied-room proof', async () => {
  const source = await read('ios/BlindAssistTests/CommunityTests.swift');
  assert.match(source, /final class IndoorGoalContinuityTests: XCTestCase/);
  for (const name of [
    'testTaskCancellationRetiresRouteButPreservesEstablishedMapFrame',
    'testCancellationAfterPhysicalCueClearsMessageInBothLanguages',
    'testConfirmedFinalWaypointHasNoActiveRoute',
    'testTaskCancellationCannotCreateUnknownAlignment',
    'testTrackingLossStillInvalidatesRetainedMapFrame',
    'testExplicitReplanDoesNotReuseOldRouteAlignment'
  ]) assert.ok(source.includes(`func ${name}()`), name);
});

test('ordinary model conversation does not regain arbitrary spatial situation prose', async () => {
  const source = await read('ios/BlindAssist/LocalImageAssistant.swift');
  const conversation = body(source, 'static func converse(', 'let instructions = conversationInstructions(');
  assert.match(conversation, /_ = situation/);
  assert.match(conversation, /suspendedGoalsNotActive/);
  assert.match(conversation, /proposedStepNotExecuted/);
});
