import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { cases } from '../../tools/fixtures/home-awareness.mjs';
import { validateScene } from '../src/app.mjs';
import { userPrompt } from '../src/scene-policy.mjs';

// Real independently authored source topology; still NOT a physical localization test.
const raw = readFileSync(new URL('../../research/map-fixtures/oas-e54861c/apartment_50m2.json', import.meta.url));
const source = JSON.parse(raw);
const packageData = JSON.parse(readFileSync(new URL('../../maps/community/oas-apartment.blindplace.json', import.meta.url), 'utf8'));
function request() {
  const value = structuredClone(cases[0].request);
  const revision = packageData.revision;
  value.question = 'Which room connects the bedroom and bathroom? Is this my home and which way do I face?';
  value.context.situation = {
    version: 1, snapshotID: 'sourced-preview', coverage: 'mapped_only',
    location: { state: 'unknown', placeID: null, floorID: null, frameID: null, mapRevision: null,
      ageMS: 0, position: null, cameraForward: null, bodyForward: null },
    places: [
      { id: packageData.id, name: packageData.name, kind: 'building', parentID: null, sourceID: revision },
      ...packageData.floors.map(floor => ({ id: floor.id, name: floor.name, kind: 'floor', parentID: packageData.id, sourceID: revision })),
      ...packageData.rooms.map(room => ({ id: room.id, name: room.name, kind: room.kind, parentID: room.floorID, sourceID: revision }))
    ],
    connections: packageData.connections.map(edge => ({ from: edge.fromRoomID, to: edge.toRoomID, state: edge.state, sourceID: revision })),
    entities: [], goal: { description: 'Understand this example before a visit', targetPlaceID: 'bathroom', focusEntityID: null },
    preferences: [], deliveredFactIDs: [], returnPlaceID: null
  };
  return value;
}
test('downloaded authored apartment keeps source doors without adding an ensuite or current pose', () => {
  assert.equal(createHash('sha256').update(raw).digest('hex'), '6a3356cf5ac9d8c6d7a30f73665961d14ec47c62577fd7b414465e0ebafd3327');
  const expected = source.openings.filter(item => item.opening_type === 'door').map(item => item.connects_rooms);
  const prompt = JSON.parse(userPrompt(validateScene(request()))), situation = prompt.context.situation;
  assert.deepEqual(situation.connections.map(edge => [edge.from, edge.to]), expected);
  assert.equal(situation.connections.some(edge => [edge.from, edge.to].includes('bedroom') && [edge.from, edge.to].includes('bathroom')), false);
  assert.equal(situation.location.state, 'unknown'); assert.equal(situation.location.bodyForward, null);
  assert.equal(situation.places.find(place => place.kind === 'floor').name, 'Drawing level — actual floor unknown');
  assert.equal(situation.entities.length, 0); assert.equal(packageData.localization, 'preview-only');
});
test('sourced map does not excuse retained stale location or an invented room reference', () => {
  const stale = request(); stale.context.situation.location.placeID = 'bedroom';
  assert.throws(() => validateScene(stale), error => error.status === 400);
  const invented = request(); invented.context.situation.connections.push({ from: 'bathroom', to: 'hidden-exit', state: 'mapped', sourceID: packageData.revision });
  assert.throws(() => validateScene(invented), error => error.status === 400);
});
