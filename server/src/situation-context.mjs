import Ajv from 'ajv';

// Ajv handles schema validation; only the product contract/reference checks are
// local glue. No perception, identity recognition or route planning lives here.
const text = { type: 'string', minLength: 1, maxLength: 300 };
const id = { type: 'string', minLength: 1, maxLength: 64 };
const optionalID = { anyOf: [id, { type: 'null' }] };
const object = properties => ({ type: 'object', additionalProperties: false,
  properties, required: Object.keys(properties) });
const point = object({ x: { type: 'number' }, y: { type: 'number' }, z: { type: 'number' } });
const nullablePoint = { anyOf: [point, { type: 'null' }] };
const entity = object({ id, category: { enum: ['person', 'seat', 'furniture', 'art', 'aquarium', 'obstacle', 'landmark', 'text', 'object'] },
  description: text, placeID: id, state: { enum: ['observed', 'lastSeen', 'mapped'] },
  ageMS: { type: 'number', minimum: 0 }, sourceID: id });
entity.properties.identity = object({ name: text, relationship: text, basis: { enum: ['user_confirmed', 'enrolled_match'] } });
const schema = object({ version: { const: 1 }, snapshotID: id, coverage: { enum: ['partial', 'mapped_only', 'unknown'] },
  location: object({ state: { enum: ['localized', 'manuallyAligned', 'unknown'] }, placeID: optionalID, floorID: optionalID,
    frameID: optionalID, mapRevision: optionalID, ageMS: { type: 'number', minimum: 0 },
    position: nullablePoint, cameraForward: nullablePoint, bodyForward: nullablePoint }),
  places: { type: 'array', minItems: 0, maxItems: 64,
    items: object({ id, name: text, kind: { enum: ['building', 'floor', 'room', 'store', 'restaurant', 'corridor', 'exit'] }, parentID: optionalID, sourceID: id }) },
  connections: { type: 'array', maxItems: 128, items: object({ from: id, to: id, state: { enum: ['mapped', 'blocked', 'unknown'] }, sourceID: id }) },
  entities: { type: 'array', maxItems: 32, items: entity },
  goal: object({ description: text, targetPlaceID: optionalID, focusEntityID: optionalID }),
  preferences: { type: 'array', maxItems: 16, items: object({ category: text, value: text, source: { const: 'user' } }) },
  deliveredFactIDs: { type: 'array', maxItems: 64, uniqueItems: true, items: id }, returnPlaceID: optionalID
});
// Optional bounded dialogue is app-supplied context, not persistent memory.
schema.properties.conversation = object({ goalRevision: id, turns: { type: 'array', maxItems: 6,
  items: object({ role: { enum: ['user', 'assistant'] }, text: { type: 'string', minLength: 1, maxLength: 2000, pattern: '\\S' } }) } });
schema.properties.arrival = object({ fromPlaceID: id, toPlaceID: id,
  ageMS: { type: 'number', minimum: 0, maximum: 3000 }, sourceID: id });
schema.properties.narration = { type: 'array', maxItems: 4, items: object({
  id, snapshotID: id, sourceIDs: { type: 'array', maxItems: 64, items: id },
  text: { type: 'string', minLength: 1, maxLength: 2000, pattern: '\\S' },
  outcome: { enum: ['pending', 'completed', 'interrupted', 'unknown'] },
  ageMS: { anyOf: [{ type: 'number', minimum: 0 }, { type: 'null' }] }
}) };
schema.properties.categoryModes = object(Object.fromEntries(['social', 'signs', 'objects', 'decor', 'interests'].map(category => [category, { enum: ['automatic', 'onRequest', 'muted'] }])));
schema.properties.mapNotes = { type: 'array', maxItems: 2, items: object({ placeID: id,
  text: { type: 'string', minLength: 1, maxLength: 4000 }, sourceID: id, state: { const: 'mapped' }
}) };
schema.properties.visualTracks = { type: 'array', maxItems: 8, items: object({
  id, sourceID: id, category: { const: 'person' }, ageMS: { type: 'number', minimum: 0, maximum: 1500 },
  confidence: { type: 'number', minimum: 0.6, maximum: 1 },
  bounds: object({ x: { type: 'number', minimum: 0, maximum: 1 }, y: { type: 'number', minimum: 0, maximum: 1 },
    width: { type: 'number', exclusiveMinimum: 0, maximum: 1 }, height: { type: 'number', exclusiveMinimum: 0, maximum: 1 } }),
  change: { enum: ['movedInCameraView', 'notEstablished'] }
}) };
const validate = new Ajv({ strict: true, allErrors: false }).compile(schema);

export function cleanSituation(value) {
  if (value === undefined) return undefined;
  if (!validate(value)) throw new Error('Invalid situation context.');
  const tracks = value.visualTracks ?? [];
  if (new Set(tracks.map(x => x.id)).size !== tracks.length || tracks.some(x => x.bounds.x + x.bounds.width > 1.000001 || x.bounds.y + x.bounds.height > 1.000001)) throw new Error('Invalid visual track.');
  const places = new Map(value.places.map(place => [place.id, place]));
  const entities = new Map(value.entities.map(item => [item.id, item]));
  if (places.size !== value.places.length || entities.size !== value.entities.length) throw new Error('Duplicate context ID.');
  const validPlace = reference => reference === null || places.has(reference);
  if ((value.mapNotes ?? []).some(note => !places.has(note.placeID))) throw new Error('Unknown room note reference.');
  for (const place of value.places) {
    if (!validPlace(place.parentID)) throw new Error('Unknown containing place.');
    const seen = new Set([place.id]); let parent = place.parentID;
    while (parent !== null) {
      if (seen.has(parent)) throw new Error('Cyclic place hierarchy.');
      seen.add(parent); parent = places.get(parent)?.parentID ?? null;
    }
  }
  if (![value.location.placeID, value.location.floorID, value.goal.targetPlaceID, value.returnPlaceID].every(validPlace)) throw new Error('Unknown place reference.');
  if (value.goal.focusEntityID !== null && !entities.has(value.goal.focusEntityID)) throw new Error('Unknown conversation focus.');
  if (value.connections.some(edge => !places.has(edge.from) || !places.has(edge.to) || edge.from === edge.to)) throw new Error('Invalid place connection.');
  for (const item of value.entities) {
    if (!places.has(item.placeID) || (item.identity && item.category !== 'person') ||
        (item.state === 'observed' && item.ageMS > 3000)) throw new Error('Invalid or stale entity.');
  }
  const position = value.location;
  if (position.floorID !== null && places.get(position.floorID)?.kind !== 'floor') throw new Error('Invalid floor reference.');
  if (position.placeID !== null && position.floorID !== null) {
    let ancestor = position.placeID;
    while (ancestor !== null && ancestor !== position.floorID) ancestor = places.get(ancestor).parentID;
    if (ancestor !== position.floorID) throw new Error('Place is outside the stated floor.');
  }
  if (value.arrival && (position.state !== 'localized' || value.arrival.toPlaceID !== position.placeID ||
      !places.has(value.arrival.fromPlaceID) || value.arrival.fromPlaceID === value.arrival.toPlaceID ||
      !value.connections.some(edge => (edge.from === value.arrival.fromPlaceID && edge.to === value.arrival.toPlaceID) ||
        (edge.to === value.arrival.fromPlaceID && edge.from === value.arrival.toPlaceID)))) throw new Error('Inconsistent arrival context.');
  if (['localized', 'manuallyAligned'].includes(position.state) && (!position.placeID || !position.floorID || !position.frameID || !position.mapRevision || !position.position || position.ageMS > 500)) throw new Error('Invalid or stale pose.');
  // Saved map/catalog entries may remain in `places`, but are not the current
  // room/frame after a restart, tracking loss or unresolved place match.
  if (position.state === 'unknown' && (position.placeID || position.floorID || position.frameID || position.mapRevision ||
      position.position || position.cameraForward || position.bodyForward)) throw new Error('Unknown location carries a current place or pose.');
  for (const forward of [position.cameraForward, position.bodyForward]) {
    if (forward && Math.abs(Math.hypot(forward.x, forward.y, forward.z) - 1) > 0.01) throw new Error('Invalid orientation vector.');
  }
  return structuredClone(value);
}
