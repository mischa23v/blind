// Static checks for the conversation evidence rule (2026-10-22): the model never decides where
// an object is or what the camera saw. Code answers find requests and location reports, model chat
// passes ConversationClaimGuard and SpatialClaimGuard, image descriptions are grounded, and the
// main screen shows only the current reply. Logic is tested by server/test/companion-guards.test.mjs
// and BlindCore CompanionEvidenceTests with the shared fixture.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const read = path => readFile(new URL(`../../${path}`, import.meta.url), 'utf8');

test('code answers find requests and location reports before any model', async () => {
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  const scene = model.split('func readScene(')[1];
  const parse = scene.indexOf('CompanionUtterance.parse(question)');
  assert.ok(parse > 0 && parse < scene.indexOf('handleItemOrLocate(question)'), 'parsed before saved-item and live-scene paths');
  assert.ok(parse < scene.indexOf('LocalImageAssistant.describe('), 'parsed before the image model');
  const assistant = await read('ios/BlindAssist/LocalImageAssistant.swift');
  const converse = assistant.split('static func converse(')[1];
  assert.ok(converse.indexOf('CompanionUtterance.parse(latest)') < converse.indexOf('CompanionSessions.shared.take'), 'code path precedes the model');
  assert.doesNotMatch(assistant, /readCompanionContext|CompanionDecision|proposedStep/, 'old model-written task state is gone');
});

test('model chat passes both evidence checks before it is shown or returned', async () => {
  const assistant = await read('ios/BlindAssist/LocalImageAssistant.swift');
  const acceptable = assistant.split('static func acceptableChat(')[1].split('}')[0];
  assert.match(acceptable, /SpatialClaimGuard\.containsSpatialClaim/);
  assert.match(acceptable, /ConversationClaimGuard\.containsUnsupportedClaim/);
  const converse = assistant.split('static func converse(')[1];
  assert.ok(converse.indexOf('acceptableChat(sentence)') < converse.indexOf('await onPartial?(sentence)'), 'partials are checked');
  assert.ok(converse.indexOf('acceptableChat(kept)') < converse.indexOf('return LocalImageAnswer(text: kept'), 'final text is checked');
  // Model-labelled words are used only when they appear in the child's message.
  assert.match(assistant, /message\.localizedCaseInsensitiveContains\(text\)/);
});

test('image descriptions are grounded in detector agreement before speech', async () => {
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  const agreed = model.indexOf('VisualGrounding.agreedObjects(groundingFrames)');
  const grounded = model.indexOf('VisualGrounding.groundedDescription($0, confirmed: confirmedObjects)');
  const marked = model.indexOf('if !grounded.isEmpty { answer = grounded; fromModel = true }');
  assert.ok(agreed > 0 && grounded > agreed && marked > grounded);
});

test('main screen shows only the current reply', async () => {
  const view = await read('ios/BlindAssist/DashboardView.swift');
  const home = view.split('private struct CompanionHomeView')[1].split('\nstruct AssistantToolsView')[0];
  assert.match(home, /accessibilityIdentifier\("companion-reply"\)/);
  assert.match(home, /\.toolbar\(\.hidden, for: \.tabBar\)/);
  assert.match(home, /\.toolbar\(\.hidden, for: \.navigationBar\)/);
  assert.doesNotMatch(home, /companion-greeting|home-status|companion-goal|microphone-status|practice-status/);
  // The only on-screen button is the developer typing control, shown in --text-only builds.
  const body = home.split('var body: some View')[1].split('.sheet(')[0];
  assert.equal((body.match(/Button\(/g) ?? []).length, 1);
  assert.match(body, /if model\.textOnly \{\s*Button/);
});

test('a manual or answer-window turn never switches continuous listening off', async () => {
  const voice = await read('ios/BlindAssist/VoiceInput.swift');
  const start = voice.split('func start(arabic: Bool')[1].split('func startContinuous')[0];
  assert.match(start, /if continuous && listening && self\.arabic == arabic \{ beginTurn\(\); return \}/);
  assert.doesNotMatch(voice, /Listening couldn't recover/);
});
