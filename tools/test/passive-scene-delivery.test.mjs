import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const source = readFileSync(new URL('../../ios/BlindAssist/NavigationModel.swift', import.meta.url), 'utf8');
const policy = readFileSync(new URL('../../BlindCore/Sources/BlindCore/PassiveSceneDelivery.swift', import.meta.url), 'utf8');
test('passive content identity is independent of model wording and capture IDs', () => {
  assert.ok(source.includes('PassiveSceneDelivery.signature(observations: context.observations,'));
  assert.ok(source.includes('confirmedObjects: Array(confirmedObjects)'));
  assert.ok(!source.includes('revision.isEmpty ? answer : revision'));
  assert.ok(!policy.includes('observation.id'));
  assert.ok(!policy.includes('observation.capturedAt'));
  assert.ok(source.indexOf('self.passiveSceneDelivery.allows(passiveSignature') < source.indexOf('let local = await LocalImageAssistant.describe('));
});
test('passive admission retains companion gates and delivery-owned completion', () => {
  assert.ok(source.includes('let spoken = self.deliverCandidate(candidate, narrationID: currentRequest)'));
  assert.ok(source.includes('kind: automatic ? .discovery : .answer'));
  assert.ok(source.includes('createdAt: capturedAt, expiresAt: capturedAt + 6, requested: !automatic'));
  const callback = source.slice(source.indexOf('feedback.onNarrationFinished ='), source.indexOf('feedback.requestedSpeechPermission ='));
  assert.ok(callback.includes('passiveSceneDelivery.finish(id: id, completed: outcome == .completed,'));
  assert.ok(callback.includes('currentOwner: self.passiveSceneOwner'));
  const failed = source.slice(source.indexOf('let spoken = self.deliverCandidate(candidate, narrationID: currentRequest)'), source.indexOf('let sessionID = self.narrationSession, at = Date()'));
  assert.ok(failed.includes('finish(id: currentRequest, completed: false,'));
  assert.ok(source.includes('if let id = passiveSceneDelivery.cancelPending()'));
});
test('scope contains lifecycle and room visit but no frame timestamp', () => {
  const scope = source.slice(source.indexOf('private var passiveSceneOwner:'), source.indexOf('private var lastSceneContent'));
  for (const field of ['assistantSession.generation', 'observationFrameID', 'perceptionGeneration', 'visits', 'indoor.revision', 'indoor.alignmentRevision', 'preferencesRevision']) assert.ok(scope.includes(field), field);
  assert.ok(!scope.includes('timestamp'));
  assert.ok(!scope.includes('lastFrameWallTime'));
});
