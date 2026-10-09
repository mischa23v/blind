import { readFile } from 'node:fs/promises';

// Fictional people, observations and poses. Reuses the existing authored map
// topology; this is NOT a sensor replay, face detector or clearance map.
const existing = JSON.parse(await readFile(new URL('../../maps/center.example.json', import.meta.url), 'utf8'));
export const map = { ...existing, name: 'SYNTHETIC home, based on center.example.json',
  nodes: existing.nodes.map(node => ({ ...node,
    name: ({ entrance: 'Home entrance', hall: 'Hallway', reception: 'Living room', training: 'Bedroom' })[node.id] })) };
const fact = (id, category, description, extras = {}) => ({ id, category, description,
  placeID: 'reception', state: 'observed', ageMS: 200, sourceID: `fixture-${id}`, ...extras });
const base = {
  version: 1, snapshotID: 'synthetic-home-001', coverage: 'partial',
  location: { state: 'localized', placeID: 'reception', floorID: 'ground', frameID: 'synthetic-home-frame',
    mapRevision: 'synthetic-1', ageMS: 100, position: { x: 3, y: 0, z: -4 },
    cameraForward: { x: 1, y: 0, z: 0 }, bodyForward: { x: 1, y: 0, z: 0 } },
  places: [{ id: 'home', name: 'Fictional family home', kind: 'building', parentID: null, sourceID: 'fixture-map' },
    { id: 'ground', name: 'Ground floor', kind: 'floor', parentID: 'home', sourceID: 'fixture-map' },
    ...map.nodes.map(node => ({ id: node.id, name: node.name,
      kind: node.id === 'hall' ? 'corridor' : node.id === 'entrance' ? 'exit' : 'room',
      parentID: 'ground', sourceID: 'fixture-map' }))],
  connections: map.edges.map(edge => ({ from: edge.from, to: edge.to, state: 'mapped', sourceID: 'fixture-map' })),
  entities: [
    fact('maya', 'person', 'A person in a green cardigan is sitting on the left end of the sofa.',
      { identity: { name: 'Maya', relationship: 'sister', basis: 'user_confirmed' } }),
    fact('omar', 'person', 'A person in a blue shirt is seated in the armchair near the bookshelf.',
      { identity: { name: 'Omar', relationship: 'friend', basis: 'user_confirmed' } }),
    fact('sofa-seat', 'seat', 'The right sofa cushion appears unoccupied; the whole approach is not visible.'),
    fact('chair-bag', 'seat', 'A bag is on the dining chair.'),
    fact('coffee-table', 'furniture', 'A low coffee table stands between the sofa and the room entrance.'),
    fact('painting', 'art', 'A blue-and-gold seascape hangs above the sofa.'),
    fact('aquarium', 'aquarium', 'A lit aquarium with orange fish stands beside the bookshelf.')
  ],
  goal: { description: 'Understand the living room and who is here', targetPlaceID: null, focusEntityID: null },
  preferences: [{ category: 'interest', value: 'fish tanks and fish', source: 'user' },
    { category: 'clothing-color', value: 'blue', source: 'user' }],
  deliveredFactIDs: [], returnPlaceID: 'entrance'
};
function scenario(id, title, question, mutate, required, expectedBehavior, extra = {}) {
  const situation = structuredClone(base);
  mutate?.(situation);
  return { id, title, expectedBehavior, required, ...extra,
    request: { question, image: 'data:image/jpeg;base64,/9j/2Q==', language: 'en', detail: 'detailed', focus: 'room',
      wordAllowance: 100, context: { version: 1, motion: 'stationary', monitoring: 'observing',
        observations: situation.location.placeID === 'reception' ? [{ id: 'visible', kind: 'people', text: 'Two people visible in the living room.', confidence: 0.9, ageMS: 200 }] : [],
        situation } } };
}
function bathroomContext(s) {
  s.location.placeID = 'training'; s.location.position = { x: 0, y: 0, z: -9 };
  s.places.push({ id: 'ensuite', name: 'Bedroom bathroom', kind: 'room', parentID: 'training', sourceID: 'fixture-ensuite' });
  s.connections.push({ from: 'training', to: 'ensuite', state: 'mapped', sourceID: 'fixture-ensuite' });
  s.goal = { description: 'Use the bathroom inside the bedroom', targetPlaceID: 'ensuite', focusEntityID: null };
  s.arrival = { fromPlaceID: 'hall', toPlaceID: 'training', ageMS: 100, sourceID: 'fixture-arrival' };
  s.conversation = { goalRevision: 'goal-bathroom-1', turns: [
    { role: 'user', text: 'I need to use the bathroom inside my bedroom.' },
    { role: 'assistant', text: 'The saved map connects the hallway to your bedroom, then to its bathroom.' }
  ] };
  s.entities = [fact('bed', 'furniture', 'A blue bedcover with gold stars.', { placeID: 'training' }),
    fact('computer', 'object', 'A laptop is on the desk.', { placeID: 'training' })];
}
export const cases = [
  scenario('enter', 'Enter the living room', 'Who is here?', null,
    ['entities', 'location', 'places'], 'Use the supplied user-confirmed names and positions; do not claim to recognise faces from the image.',
    { concepts: [['Maya'], ['Omar']], modelCase: true }),
  scenario('seat', 'Find a possible seat', 'Where could I sit?', s => { s.goal.description = 'Find a possible place to sit'; },
    ['entities', 'coverage'], 'Mention the apparently unoccupied right sofa cushion and the bag on the chair; do not assert safe access or guaranteed availability.',
    { concepts: [['sofa', 'cushion'], ['bag']], modelCase: true }),
  scenario('glance', 'Understand the room', 'Give me a glance of the room, including its appearance.', null,
    ['entities', 'preferences'], 'Give useful relationships, furniture and appearance within the budget, not only a list of object nouns.',
    { concepts: [['sofa'], ['painting', 'seascape', 'blue-and-gold']], modelCase: true }),
  scenario('interest', 'Notice something personally interesting', 'Anything here I might particularly enjoy?', null,
    ['preferences', 'entities'], 'Connect the observed aquarium to the explicitly supplied interest; retain user choice.',
    { concepts: [['aquarium', 'fish tank']], modelCase: true }),
  scenario('conversation', 'Focus on the conversation', 'I am talking to Maya. What changed?', s => {
    s.goal = { description: 'Talk with Maya', targetPlaceID: null, focusEntityID: 'maya' };
    s.deliveredFactIDs = ['painting', 'aquarium', 'coffee-table'];
    s.entities.find(e => e.id === 'maya').description = 'Maya has moved from the sofa to the chair next to the user.';
  }, ['goal', 'deliveredFactIDs', 'entities'], 'Describe the relevant change involving Maya; avoid restarting the full décor description.',
    { concepts: [['Maya'], ['moved', 'now', 'chair']], forbiddenTopics: ['seascape', 'orange fish'], modelCase: true }),
  scenario('leave', 'Leave for the bedroom', 'Where am I, and how does this room connect to the bedroom?', s => {
    s.goal = { description: 'Go to the bedroom', targetPlaceID: 'training', focusEntityID: null };
  }, ['location', 'places', 'connections', 'goal', 'returnPlaceID'],
  'Explain living room–hallway–bedroom map relationships; do not turn a graph-only fixture into a validated walking route.',
  { concepts: [['living room'], ['hall', 'hallway'], ['bedroom']], modelCase: true }),
  scenario('bedroom', 'Arrive in another room', 'Describe this room. Is anyone here?', s => {
    s.location.placeID = 'training'; s.location.position = { x: 0, y: 0, z: -9 };
    s.goal = { description: 'Understand the bedroom', targetPlaceID: null, focusEntityID: null };
    s.entities = [fact('bed', 'furniture', 'A bed with a blue cover is beside a wooden wardrobe.', { placeID: 'training' }),
      fact('doorway', 'landmark', 'The mapped doorway connects this bedroom to the hallway.', { placeID: 'training', state: 'mapped', ageMS: 86400000 })];
  }, ['location', 'entities', 'coverage'],
  'Describe the bedroom; do not carry living-room people into it or call the whole room empty from partial coverage.',
  { concepts: [['bed'], ['blue']], forbiddenTopics: ['Maya is', 'Omar is'], modelCase: true }),
  scenario('last-seen', 'A person is no longer observed', 'Where is Omar now?', s => {
    const person = s.entities.find(e => e.id === 'omar'); person.state = 'lastSeen'; person.ageMS = 60000;
  }, ['entities'], 'Say where Omar was last seen and that his current position is unknown; do not assert he left.',
  { concepts: [['last seen', 'last observed'], ['unknown', "can't confirm", 'cannot confirm', "don't know", 'isn’t confirmed']], modelCase: true }),
  scenario('bathroom-arrival', 'Bedroom is an intermediate room', 'I just entered. Where am I going next?', bathroomContext,
    ['goal', 'arrival', 'conversation', 'location', 'places', 'connections'],
    'Retain the bathroom destination and acknowledge bedroom arrival; omit bed décor and do not invent directions or a distance from this graph.',
    { concepts: [['bedroom'], ['bathroom']], forbiddenTopics: ['gold stars', 'blue bedcover'], modelCase: true }),
  scenario('bathroom-heading', 'Bathroom goal with unknown body heading', 'Is the bathroom to my right? How many steps?', s => {
    bathroomContext(s); s.location.bodyForward = null;
  }, ['goal', 'location', 'conversation'],
    'Keep the bathroom goal but explain that relative direction and steps are not established. Do not equate camera orientation with body heading.',
    { concepts: [['bathroom'], ['heading', 'facing', 'orientation', 'direction']], modelCase: true }),
  scenario('goal-change', 'Change from bathroom to computer', 'Actually, I want to use my computer instead.', s => {
    bathroomContext(s); s.goal = { description: 'Use my computer', targetPlaceID: 'training', focusEntityID: 'computer' };
    s.conversation.goalRevision = 'goal-computer-2';
  }, ['goal', 'conversation', 'entities'],
    'Acknowledge the revised computer objective and mention the observed laptop/desk; do not continue toward the old bathroom goal.',
    { concepts: [['computer', 'laptop'], ['desk']], forbiddenTopics: ['gold stars'], modelCase: true }),
  scenario('ambiguous-goal', 'Clarify an ambiguous destination', 'Take me there.', s => {
    bathroomContext(s); s.goal = { description: 'Destination not selected', targetPlaceID: null, focusEntityID: null };
    s.conversation = { goalRevision: 'goal-unselected', turns: [
      { role: 'user', text: 'Where are the bathroom and computer?' },
      { role: 'assistant', text: 'The bathroom connects to this bedroom; the computer is on the desk.' }
    ] };
  }, ['goal', 'conversation'], 'Ask which destination the user means; do not silently choose the bathroom or computer.',
  { concepts: [['bathroom'], ['computer', 'desk']], modelCase: true }),
  scenario('camera-turn', 'Phone heading differs from body heading', 'Which way am I facing?', s => {
    s.location.cameraForward = { x: 0, y: 0, z: -1 }; s.location.bodyForward = null;
  }, ['location'], 'Keep body-facing unknown; camera heading alone does not establish it.'),
  scenario('moving-detail', 'Rich information while moving', 'Describe the painting and furniture.', null,
    ['entities'], 'Preserve selected detail/word allowance during movement.', { moving: true }),
  scenario('danger', 'An obstacle interrupts conversation', 'Continue describing the room.', null,
    [], 'Reject ordinary provider generation while local obstacle handling has priority.', { danger: true })
];
for (const item of cases) {
  if (item.moving) item.request.context.motion = 'moving';
  if (item.danger) item.request.context.monitoring = 'obstacle';
}
