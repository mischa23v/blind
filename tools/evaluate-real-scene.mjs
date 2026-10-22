// Q09 real-data feasibility evaluation (TASKS.md). Real iPad LiDAR capture (Apple CA-1M,
// CC BY-NC-ND 4.0) with recorded per-frame device poses and labelled objects, sent through the
// actual relay (createApp + describe + spatial guard + word budget) to a vision model.
// Spatial facts are computed by code from the recorded pose, standing in for the phone's
// sensor/map renderer; the model's object estimates are compared against them.
// Limits: recorded poses are not live localisation; a handheld iPad heading stands in for body
// heading; the cloud model is not the on-device model. Without --live no model calls are made.
import { readFileSync, readdirSync, mkdirSync, writeFileSync, existsSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { join, resolve, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import { randomBytes } from 'node:crypto';
import { createApp, describe } from '../server/src/app.mjs';
import { containsSpatialClaim } from '../server/src/spatial-guard.mjs';

const root = resolve(fileURLToPath(new URL('..', import.meta.url)));
const option = name => { const i = process.argv.indexOf(name); return i < 0 ? undefined : process.argv[i + 1]; };
const sceneDir = resolve(option('--scene') ?? join(root, 'research/datasets/ca1m-val-42898570'));
const live = process.argv.includes('--live');
const model = option('--model') ?? process.env.OPENAI_MODEL;
if (live && (!model || !process.env.OPENAI_API_KEY)) throw new Error('Explicit --model and an API key are required for --live.');
const captureID = readdirSync(join(sceneDir, 'extracted'))[0];
const data = join(sceneDir, 'extracted', captureID);
const out = join(root, 'artifacts/windows-stage/q09'); mkdirSync(join(out, 'frames'), { recursive: true });

// ---- Geometry from the recorded pose (code, never the model) ----
const world = JSON.parse(readFileSync(join(data, 'world.gt/instances.json'), 'utf8'));
const named = world.filter(item => item.category !== 'object');
const frames = readdirSync(data).filter(n => n.endsWith('.gt')).map(n => n.slice(0, -3)).sort();
const K = JSON.parse(readFileSync(join(data, `${frames[0]}.wide/image/K.json`), 'utf8'));
const [width, height] = JSON.parse(readFileSync(join(data, `${frames[0]}._wide/image/size`), 'utf8'));
const pose = id => JSON.parse(readFileSync(join(data, `${id}.gt/RT.json`), 'utf8'));
const toCamera = (RT, p) => { const d = [0, 1, 2].map(i => p[i] - RT[i][3]); return [0, 1, 2].map(c => RT[0][c] * d[0] + RT[1][c] * d[1] + RT[2][c] * d[2]); };
function inView(RT, p) {
  const [x, y, z] = toCamera(RT, p);
  if (z <= 0.2) return false;
  const u = K[0][0] * x / z + K[0][2], v = K[1][1] * y / z + K[1][2];
  return u >= 0 && u < width && v >= 0 && v < height;
}
// Horizontal bearing relative to where the device faces (world z is up).
function relation(RT, p) {
  const fwd = [RT[0][2], RT[1][2]], right = [RT[0][0], RT[1][0]];
  const fl = Math.hypot(...fwd), rl = Math.hypot(...right);
  const d = [p[0] - RT[0][3], p[1] - RT[1][3]];
  const ahead = (d[0] * fwd[0] + d[1] * fwd[1]) / fl, side = (d[0] * right[0] + d[1] * right[1]) / rl;
  const angle = Math.atan2(side, ahead) * 180 / Math.PI, distance = Math.hypot(...d);
  const a = Math.abs(angle), hand = angle >= 0 ? 'right' : 'left';
  const sector = a < 30 ? 'ahead' : a < 75 ? `ahead ${hand}` : a < 120 ? hand : a < 160 ? `behind ${hand}` : 'behind';
  return { angle: Math.round(angle), distance: Math.round(distance * 10) / 10, sector };
}
// Code-rendered sensor fact: plain and confident, labelled with its basis.
const fact = (RT, item) => { const r = relation(RT, item.position); return `${item.category}: ${r.sector}, ${r.distance} metres${inView(RT, item.position) ? '' : ', not in camera view'}`; };

function visibleCategories(id) {
  const local = JSON.parse(readFileSync(join(data, `${id}.wide/instances.json`), 'utf8'));
  return [...new Set(local.map(item => item.category).filter(c => c !== 'object'))].sort();
}
const door = named.find(item => item.category === 'door');
const closet = named.find(item => item.category === 'closet');
const pick = fraction => frames[Math.min(frames.length - 1, Math.floor(fraction * frames.length))];
const doorVisible = frames.filter((id, i) => i % 10 === 0 && inView(pose(id), door.position)).at(0);
const doorBehind = frames.filter((id, i) => i % 10 === 0 && Math.abs(relation(pose(id), door.position).angle) > 120).at(0);
const closetVisible = frames.filter((id, i) => i % 10 === 0 && closet && inView(pose(id), closet.position)).at(0);

// ---- Frames to JPEG (dataset is untrusted data: python -I, script outside the data folder) ----
function jpeg(id) {
  const target = join(out, 'frames', `${id}.jpg`);
  if (!existsSync(target)) {
    const member = `${captureID}/${id}.wide/image.png`, tmp = join(out, 'frames', 'tmp');
    mkdirSync(tmp, { recursive: true });
    // Relative paths from the dataset folder: GNU tar reads "C:" as a remote host.
    const tar = spawnSync('tar', ['-xf', `ca1m-val-${captureID}.tar`, '-C', relative(sceneDir, tmp).replace(/\\/g, '/'), member],
                          { cwd: sceneDir, encoding: 'utf8' });
    if (tar.status !== 0) throw new Error(`Frame extraction did not complete: ${tar.stderr}`);
    // -E ignores Python environment variables; only tools/ (our code) is on the import path, never the data folder.
    const py = spawnSync('python', ['-E', join(root, 'tools/png-to-jpeg.py'), join(tmp, member), target, '1024'], { cwd: join(root, 'tools'), encoding: 'utf8' });
    if (py.status !== 0) throw new Error(`JPEG conversion did not complete: ${py.stderr}`);
  }
  return 'data:image/jpeg;base64,' + readFileSync(target).toString('base64');
}

const sequence = [0.1, 0.3, 0.5, 0.7, 0.9].map(pick);
const scenarios = [
  { id: 'S1-first-entry', frame: pick(0.15), question: 'Describe this room.', focus: 'room', detail: 'detailed', words: 110 },
  ...sequence.map((frame, i) => ({ id: `S2-walk-${i + 1}`, frame, question: 'Describe what is in front of me.', focus: 'surroundings', detail: 'balanced', words: 55, history: true })),
  { id: 'S3-door-visible', frame: doorVisible, question: 'Where is the door?', focus: 'object', detail: 'balanced', words: 40, target: door },
  { id: 'S3-door-behind', frame: doorBehind, question: 'Where is the door?', focus: 'object', detail: 'balanced', words: 40, target: door },
  { id: 'S4-closet-outfit', frame: closetVisible ?? pick(0.5), question: 'I want to change clothes. Is there a closet here, and what is near it?', focus: 'object', detail: 'balanced', words: 55, target: closet },
  { id: 'S5-step-count', frame: doorVisible, question: 'How many steps is it to the door?', focus: 'object', detail: 'balanced', words: 40, target: door }
].filter(s => s.frame);

function situationWith(history) {
  return { version: 1, snapshotID: 'q09-walk', coverage: 'unknown',
    location: { state: 'unknown', placeID: null, floorID: null, frameID: null, mapRevision: null, ageMS: 0, position: null, cameraForward: null, bodyForward: null },
    places: [], connections: [], entities: [], goal: { description: 'Look around this room', targetPlaceID: null, focusEntityID: null },
    preferences: [], deliveredFactIDs: [], returnPlaceID: null,
    narration: history.slice(-4).map((text, i) => ({ id: `q09-n${i}`, snapshotID: 'q09-walk', sourceIDs: [], text, outcome: 'completed', ageMS: 4000 })) };
}
const directionOf = text => {
  const t = text.toLowerCase();
  if (/not (visible|in (this|the) view)|can'?t see|cannot see|don'?t see/.test(t)) return 'not visible';
  const found = ['behind', 'left', 'right', 'ahead', 'in front'].filter(w => t.includes(w));
  return found.length ? found.join('+') : 'none stated';
};
// Compare the model's words with the measured bearing (positive angle = to the right).
const agrees = (said, truth) => {
  if (said === 'not visible' || said === 'none stated') return null;
  const checks = [];
  if (said.includes('right')) checks.push(truth.angle > 5 && Math.abs(truth.angle) < 165);
  if (said.includes('left')) checks.push(truth.angle < -5 && Math.abs(truth.angle) < 165);
  if (said.includes('behind')) checks.push(Math.abs(truth.angle) > 110);
  if (said.includes('ahead') || said.includes('in front')) checks.push(Math.abs(truth.angle) < 60);
  return checks.length ? checks.every(Boolean) : null;
};

const report = { generatedAt: new Date().toISOString(), live, model: live ? model : null,
  dataset: { name: 'Apple CA-1M', capture: captureID, license: 'CC BY-NC-ND 4.0', frames: frames.length, labelledObjects: world.length,
    roomCategories: [...new Set(named.map(i => i.category))].sort() },
  limits: ['Recorded device poses, not live localisation on the phone', 'Handheld iPad heading stands in for chest-mounted body heading',
    'Cloud model through the relay, not the on-device model', 'One bedroom capture'],
  scenarios: [] };

let server, url, calls = 0;
const raw = [];
if (live) {
  const config = { apiKey: process.env.OPENAI_API_KEY, model, token: randomBytes(16).toString('hex'), timeoutMS: 60_000, ratePerMinute: 60 };
  // Record every raw model answer so a retried (discarded) answer can be reviewed.
  server = createApp(config, async (scene, cfg, signal) => { calls += 1; const answer = await describe(scene, cfg, signal); raw.push(answer); return answer; });
  await new Promise(done => server.listen(0, '127.0.0.1', done));
  url = `http://127.0.0.1:${server.address().port}/v1/scene`;
  report.token = undefined;
  var bearer = config.token;
}
const history = [];
try {
  for (const s of scenarios) {
    const RT = pose(s.frame);
    const row = { id: s.id, frame: s.frame, question: s.question, visibleCategories: visibleCategories(s.frame),
      sensorFacts: [door, closet].filter(Boolean).map(item => fact(RT, item)), answer: null, status: 'not_run' };
    if (s.target) row.measured = { category: s.target.category, ...relation(RT, s.target.position), inView: inView(RT, s.target.position) };
    if (live) {
      const before = calls, started = Date.now();
      const body = { question: s.question, image: jpeg(s.frame), language: 'en', detail: s.detail, focus: s.focus, wordAllowance: s.words };
      if (s.history) body.context = { version: 1, motion: 'moving', monitoring: 'observing', observations: [], situation: situationWith(history) };
      const response = await fetch(url, { method: 'POST', headers: { Authorization: `Bearer ${bearer}`, 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
      const result = await response.json();
      Object.assign(row, { status: response.status, latencyMS: Date.now() - started, providerCalls: calls - before,
        answer: result.answer ?? null, refusal: result.error ?? null,
        // A raw answer whose sentences were kept (after filtering/trimming) was used, not discarded.
        discardedAnswers: raw.slice(before, calls).filter(text => !result.answer || !text.includes(result.answer.split(/(?<=[.!?])\s/)[0])) });
      if (row.answer) {
        row.spatialGuardOnFinal = containsSpatialClaim(row.answer);
        if (s.history) history.push(row.answer);
        if (s.target) { row.modelDirection = directionOf(row.answer); row.directionAgrees = agrees(row.modelDirection, row.measured); }
      }
      console.log(`${row.id}: ${row.status} in ${row.latencyMS} ms, ${row.providerCalls} call(s)`);
    }
    report.scenarios.push(row);
  }
} finally { if (server) await new Promise(done => server.close(done)); }
const file = join(out, live ? `report-live-${model.replace(/[^a-z0-9.-]/gi, '_')}.json` : 'report-geometry.json');
writeFileSync(file, JSON.stringify(report, null, 2));
console.log(`Wrote ${file}`);
