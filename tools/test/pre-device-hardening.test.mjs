import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
const read = p => readFileSync(new URL(`../../${p}`, import.meta.url), 'utf8');
const model = read('ios/BlindAssist/NavigationModel.swift');
const local = read('ios/BlindAssist/LocalImageAssistant.swift');
function declaration(source, signature) {
  const start = source.indexOf(signature); assert.ok(start >= 0, signature);
  const first = source.indexOf('{', start); let depth = 0;
  for (let i = first; i < source.length; i++) {
    if (source[i] === '{') depth++;
    if (source[i] === '}' && --depth === 0) return source.slice(start, i + 1);
  }
  assert.fail(signature);
}
test('generic observation is attributed captured-view evidence with separately revalidated playback, not a calibrated depth claim', () => {
  const tools = declaration(model, '@MainActor private func readCompanionTool(');
  const observation = tools.slice(tools.indexOf('case .currentObservation:'));
  assert.match(observation, /captureObjectView\(frame\)/);
  assert.match(observation, /objectViewIsCurrent\(capture, snapshotPlayback: true\)/);
  assert.match(observation, /CompanionEvidence\(kind: \.capturedView/);
  assert.match(observation, /CapturedViewEvidence.candidate\(\$0, arabic: arabic\)/);
  assert.match(observation, /CapturedViewEvidence.candidate\(\$0, appearance: true, arabic: arabic\)/);
  assert.match(observation, /snapshot: true/);
  assert.doesNotMatch(observation, /lastObservation|hazard == \.observing|perceptionResultAllowed/);
  const playback = declaration(model, 'private func revalidateConversationSpeech(');
  assert.match(playback, /allSatisfy\(conversationCaptureIsCurrent\)/);
  assert.match(model, /snapshotPlayback: capture.snapshot/);
  assert.match(playback, /feedback.stopRequestedSpeech\(active.id\)/);
  assert.ok((model.match(/revalidateConversationSpeech\(\)/g) ?? []).length >= 3);
});
test('hold narration precedes task classification and does not end camera or microphone; crossing bypasses model and uses explicit audience', () => {
  const receive = declaration(model, 'func receiveCompanionUtterance(');
  assert.ok(receive.indexOf('AssistantControl.parse(text) == .quiet') < receive.indexOf('ConversationIntent.classify(text)'));
  assert.match(receive, /!ambientDescriptions,[\s\S]*== "continue"/);
  const hold = declaration(model, 'func stopDescriptions(');
  assert.doesNotMatch(hold, /endConversation|muteConversation|stopCameraMonitoring|cameraAwareness = false/);
  const crossing = declaration(model, 'private func routeUnverifiedPhysicalRequest(');
  assert.match(crossing, /RoadCrossingPolicy.reply\(audience: assistantAudience, arabic: arabic\)/);
  assert.ok(crossing.indexOf('RoadCrossingPolicy.requiresCodeOwnedReply') < crossing.indexOf('routeEverydayTask'));
  assert.match(model, /assistant-audience"\) \?\? AssistantAudience.childWithGuardian.rawValue/);
  assert.doesNotMatch(receive, /assistantAudience\s*=/);
});
test('fresh RGB survives nonurgent depth loss while urgent or unavailable monitoring still cancels', () => {
  const publish = declaration(model, 'private func publish(');
  assert.match(publish, /let preserveRGB = !detection.hazard.isUrgent/);
  assert.match(publish, /session.currentFrame.flatMap \{ captureObjectView\(\$0\) \} != nil/);
  assert.match(publish, /if preserveRGB \{ invalidatePerceptionWork\(preserveRGBHistoryWork: true\) \}/);
  assert.match(publish, /else \{ cancelDescription\(\) \}/);
});
test('private audio loss exempts only code-owned detection alerts, never arbitrary route names', () => {
  const delivery = declaration(model, 'private func deliverCandidate(');
  assert.match(delivery, /let independentAlert = alert != nil && \(candidate.kind == \.hazard \|\| candidate.kind == \.mobility\)/);
  assert.match(delivery, /guard independentAlert \|\| !assistantSession.privateAudioHeld/);
  const selection = declaration(model, 'func indoorBeacon(');
  assert.match(selection, /if connectedJourneyOwnsNavigation/);
  assert.doesNotMatch(selection, /indoor\.next\(|spatialRouteOutput\.deliver/);
  const beacon = declaration(model, 'private func connectedJourneyBeacon(');
  assert.match(beacon, /spatialRouteOutput\.deliver\(ticket: ticket, goalRevision: revision/);
  assert.match(beacon, /InformationCandidate\(key: "spatial-route:"[\s\S]*kind: \.mobility/);
  assert.match(beacon, /deliverCandidate\(candidate, speechID: id, spatialRouteID: id\)/);
  assert.doesNotMatch(beacon, /speakMobility\(indoor\.message\)|alert:/);
  const routePermission = declaration(model, 'private func spatialRouteOutputAllowed(');
  assert.match(routePermission, /!assistantSession\.privateAudioHeld/);
  assert.match(routePermission, /guard connectedJourneyOwnsNavigation else \{ return false \}/);
  assert.match(routePermission, /\$0\.permits\(ticket, now: now\)/);
  assert.doesNotMatch(routePermission, /indoor\.permitsSpatialOutput/);
  const mobility = declaration(model, 'private func speakMobility(');
  assert.doesNotMatch(mobility, /alert:/);
});
test('actual conversation instructions including snapshot and search repairs fit all six declared byte budgets', {
  skip: !process.env.BLIND_SWIFTC && 'Set BLIND_SWIFTC for the extracted production prompt check.',
}, () => {
  const directory = mkdtempSync(join(tmpdir(), 'blind-prompt-budget-'));
  try {
    const prompt = declaration(local, 'private static func conversationInstructions(').replace('private static', 'static');
    const sections = declaration(local, 'private struct CompanionSystemPrompts');
    const limit = Number(read('BlindCore/Sources/BlindCore/ContextWindowPolicy.swift').match(/maximumInstructionsUTF8Bytes = ([\d_]+)/)[1].replaceAll('_', ''));
    const swift = `import Foundation\n${read('BlindCore/Sources/BlindCore/AssistantAudience.swift')}\npublic enum ContextWindowPolicy { ${declaration(read('BlindCore/Sources/BlindCore/ContextWindowPolicy.swift'), 'public struct Field')} }\n${read('BlindCore/Sources/BlindCore/CompanionModelContext.swift')}\n${sections}\nenum Prompt { ${prompt} }\nfor audience in AssistantAudience.allCases { for arabic in [false,true] { let text = Prompt.conversationInstructions(arabic: arabic, audience: audience); precondition(text.utf8.count <= ${limit}); precondition(text.contains("Captured-view evidence is a past snapshot")); precondition(text.contains("evidence-grounded next check")) } }\nprint("six production prompt budgets passed")\n`;
    const path = join(directory, 'main.swift'), binary = join(directory, 'run'); writeFileSync(path, swift);
    execFileSync(process.env.BLIND_SWIFTC, ['-module-cache-path', join(directory, 'cache'), path, '-o', binary], { timeout: 60_000 });
    assert.match(execFileSync(binary, { encoding: 'utf8', timeout: 10_000 }), /six production prompt budgets passed/);
  } finally { rmSync(directory, { recursive: true, force: true }); }
});
