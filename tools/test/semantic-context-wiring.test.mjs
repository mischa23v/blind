import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const read = path => readFileSync(new URL(`../../${path}`, import.meta.url), 'utf8');
test('specialized reads are bounded non-mutating adapters with gallery-aware playback', () => {
  const native = read('ios/BlindAssist/NavigationModel.swift');
  const body = native.slice(native.indexOf('@MainActor private func readSpecializedCompanionTool'), native.indexOf('private func recordCompanionMessage'));
  for (const token of ['saudiBanknotes.inspect', 'clothingColors.inspect', 'VisionService.textLines', 'familiarPeople.readForConversation', 'conversationFrameProbe.isAvailable', 'familiarRevision: familiarRevision']) assert.ok(body.includes(token), token);
  assert.doesNotMatch(body, /routeSaudiBanknoteCommand|routeClothingColorCommand|changeGoal|cancelDescription/);
  assert.match(native, /familiarPeople.operationRevision == revision/);
  assert.match(native, /onEvidenceInvalidated = .*revalidateConversationSpeech/);
  assert.match(native, /requiredVisualEvidence\(text, reports: reports, evidence: evidence\)/);
});
test('native replay invokes production model path without loading grading rubric', () => {
  const source = read('ios/BlindAssistTests/CompanionNativeReplayTests.swift');
  assert.match(source, /LocalImageAssistant.converse\(/);
  assert.match(source, /state.ingestDirectActionReport\(episode.user\)/);
  assert.match(source, /state.apply\(update, latest: episode.user\)/);
  assert.match(source, /throw XCTSkip/);
  assert.doesNotMatch(source, /frozen_rubric|expectedAnswer|expectedResponse/);
  assert.match(source, /SHA256.hash\(data: bytes\)/);
});
