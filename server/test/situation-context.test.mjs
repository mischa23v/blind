import { test } from 'node:test';
import assert from 'node:assert/strict';
import { cases } from '../../tools/fixtures/home-awareness.mjs';
import { cleanSituation } from '../src/situation-context.mjs';
import { validateScene, createApp } from '../src/app.mjs';
import { userPrompt, withinWordBudget } from '../src/scene-policy.mjs';
const source = () => structuredClone(cases[0].request);

test('ordinary category preferences survive the prompt and cannot disable hazard producers', () => {
  const input = source();
  input.context.situation.categoryModes = { social: 'onRequest', signs: 'automatic', objects: 'automatic', decor: 'muted', interests: 'automatic' };
  assert.deepEqual(JSON.parse(userPrompt(validateScene(input))).context.situation.categoryModes, input.context.situation.categoryModes);
  input.context.situation.categoryModes.danger = 'muted'; assert.throws(() => validateScene(input));
});

test('anonymous camera tracks retain change limits and reject stale, duplicate or invented identity data', () => {
  const input = source().context.situation;
  const track = { id: 'vision-1', sourceID: 'sequence', category: 'person', ageMS: 200, confidence: 0.9,
    bounds: { x: 0.1, y: 0.2, width: 0.3, height: 0.5 }, change: 'movedInCameraView' };
  input.visualTracks = [track]; assert.deepEqual(cleanSituation(input).visualTracks, [track]);
  for (const change of [{ ageMS: 1501 }, { identity: 'Maya' }, { change: 'approachingToTalk' },
    { bounds: { x: 0.8, y: 0.2, width: 0.3, height: 0.5 } }]) {
    input.visualTracks = [{ ...track, ...change }]; assert.throws(() => cleanSituation(input));
  }
  input.visualTracks = [track, track]; assert.throws(() => cleanSituation(input));
});

test('manual alignment remains distinct from recognition and requires fresh complete map pose', () => {
  const input = source().context.situation;
  delete input.arrival;
  input.location.state = 'manuallyAligned'; input.location.bodyForward = null;
  assert.deepEqual(cleanSituation(input), input);
  for (const field of ['placeID', 'floorID', 'frameID', 'mapRevision', 'position']) {
    const invalid = structuredClone(input); invalid.location[field] = null;
    assert.throws(() => cleanSituation(invalid));
  }
  input.location.ageMS = 501; assert.throws(() => cleanSituation(input));
});
test('first launch accepts dialogue without fabricating a saved place or floor', () => {
  const input = source().context.situation;
  input.location = { state: 'unknown', placeID: null, floorID: null, frameID: null, mapRevision: null, ageMS: 0, position: null, cameraForward: null, bodyForward: null };
  input.places = []; input.entities = []; input.connections = [];
  input.goal = { description: 'Reach the bathroom', targetPlaceID: null, focusEntityID: null };
  input.returnPlaceID = null; delete input.arrival;
  input.conversation = { goalRevision: 'user-goal-1', turns: [{ role: 'user', text: 'I am entering a bedroom on the way.' }] };
  assert.deepEqual(cleanSituation(input), input);
  input.location.state = 'localized';
  assert.throws(() => cleanSituation(input));
});

test('situation retains place hierarchy, source states, people, goals and interests through the actual request path', () => {
  for (const item of cases.filter(x => !x.danger)) {
    const prompt = JSON.parse(userPrompt(validateScene(item.request)));
    assert.deepEqual(prompt.context.situation, item.request.context.situation);
    assert.equal(prompt.maximumWords, item.request.wordAllowance);
  }
});
test('unknown or stale geometry and dangling/cyclic references cannot reach the model', () => {
  const mutations = [s => { s.location.ageMS = 501; }, s => { s.location.state = 'unknown'; },
    s => { s.goal.targetPlaceID = 'invented'; }, s => { s.goal.focusEntityID = 'invented'; },
    s => { s.entities[0].ageMS = 3001; }, s => { s.entities[0].placeID = 'invented'; },
    s => { s.places[0].parentID = 'reception'; }, s => { s.connections[0].to = 'invented'; },
    s => { s.entities.push(s.entities[0]); }, s => { s.location.bodyForward.x = Infinity; },
    s => { s.location.cameraForward.x = 2; }, s => { s.privateHistory = 'do not send'; },
    s => { s.entities[0].identity.basis = 'guessed_from_face'; }];
  mutations.push(s => { s.location.floorID = 'reception'; }, s => { s.places.find(p => p.id === 'reception').parentID = 'home'; });
  for (const mutate of mutations) {
    const input = source(); mutate(input.context.situation);
    assert.throws(() => validateScene(input), error => error.status === 400);
  }
});
test('arrival and dialogue are bounded and consistent with the current room and map', () => {
  const input = source().context.situation;
  input.arrival = { fromPlaceID: 'hall', toPlaceID: 'reception', ageMS: 100, sourceID: 'fixture-entry' };
  input.conversation = { goalRevision: 'goal-2', turns: [{ role: 'user', text: 'I want to use the bathroom.' }] };
  assert.deepEqual(cleanSituation(input), input);
  for (const mutate of [s => { s.arrival.toPlaceID = 'training'; }, s => { s.arrival.ageMS = 3001; },
    s => { s.arrival.fromPlaceID = 'training'; }, s => { s.conversation.turns[0].role = 'system'; },
    s => { s.conversation.turns = Array(7).fill(s.conversation.turns[0]); }]) {
    const invalid = structuredClone(input); mutate(invalid); assert.throws(() => cleanSituation(invalid));
  }
});
test('last-seen people and unknown body orientation survive as unknown, not current facts', () => {
  for (const id of ['last-seen', 'camera-turn']) {
    const input = cases.find(item => item.id === id).request.context.situation;
    assert.deepEqual(cleanSituation(input), input);
  }
  const unknown = source().context.situation;
  unknown.location = { state: 'unknown', placeID: null, floorID: null, frameID: null,
    mapRevision: null, ageMS: 0, position: null, cameraForward: null, bodyForward: null };
  assert.equal(cleanSituation(unknown).entities[0].identity.name, 'Maya');
});

test('detailed dialogue retains qualifications and bounds Unicode without truncation', () => {
  const input = source().context.situation;
  const answer = 'The painting contains blue and green shapes. '.repeat(12) + 'I cannot confirm the artist or whether the nearby chair is available.';
  input.conversation = { goalRevision: 'goal-rich', turns: [{ role: 'assistant', text: answer }, { role: 'user', text: 'Tell me more about that painting' }] };
  assert.equal(cleanSituation(input).conversation.turns[0].text, answer);
  const text = 'e\u0301'.repeat(1000);
  input.conversation.turns = [{ role: 'assistant', text }];
  assert.equal(cleanSituation(input).conversation.turns[0].text, text);
  input.conversation.turns[0].text += 'x'; assert.throws(() => cleanSituation(input));
  input.conversation.turns[0].text = ' \n\t'; assert.throws(() => cleanSituation(input));
});

test('speech attempts retain outcomes and source references without claiming facts were heard', () => {
  const input = source().context.situation;
  input.deliveredFactIDs = [];
  input.narration = ['pending', 'completed', 'interrupted', 'unknown'].map((outcome, i) => ({
    id: `speech-${i}`, snapshotID: `earlier-snapshot-${i}`, sourceIDs: ['older-map-revision'],
    text: 'Earlier description; not evidence of the current view.', outcome, ageMS: i === 3 ? null : 100
  }));
  const cleaned = cleanSituation(input);
  assert.deepEqual(cleaned.narration, input.narration);
  assert.deepEqual(cleaned.deliveredFactIDs, []);
  const invalid = structuredClone(input); invalid.narration[0].outcome = 'assumed-heard';
  assert.throws(() => cleanSituation(invalid));
  invalid.narration = [...input.narration, input.narration[0]];
  assert.throws(() => cleanSituation(invalid));
});
test('word budget measures Arabic/English words and rejects invalid caller allowances', () => {
  assert.equal(withinWordBudget('A blue chair.', { language: 'en', detail: 'detailed', context: {}, wordAllowance: 2 }), false);
  assert.equal(withinWordBudget('كرسي أزرق', { language: 'ar', detail: 'detailed', context: {}, wordAllowance: 2 }), true);
  for (const wordAllowance of [0, -1, 301, 1.5, '80']) assert.throws(() => validateScene({ ...source(), wordAllowance }));
});
test('unresolved location cannot retain a previous room or frame as current', () => {
  const previous = source().context.situation;
  previous.location.state = 'unknown';
  previous.location.position = null; previous.location.bodyForward = null; previous.location.cameraForward = null;
  assert.throws(() => cleanSituation(previous));
});
test('model-authored map edits and approval claims are not situation inputs', () => {
  for (const field of ['mapEdits', 'approvedByUser', 'overwriteRoom']) {
    const input = source().context.situation; input[field] = true;
    assert.throws(() => cleanSituation(input));
  }
});
test('real HTTP delivery rejects an oversized answer without chopping its meaning', async () => {
  const token = 'synthetic-test-token-long-enough';
  const server = createApp({ token, apiKey: 'test-key', model: 'fake' }, async () => 'The chair is not available.');
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  try {
    const result = await fetch(`http://127.0.0.1:${server.address().port}/v1/scene`, {
      method: 'POST', headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ ...source(), wordAllowance: 3 })
    });
    assert.equal(result.status, 502);
    assert.equal((await result.json()).answer, undefined);
  } finally { await new Promise(resolve => server.close(resolve)); }
});
