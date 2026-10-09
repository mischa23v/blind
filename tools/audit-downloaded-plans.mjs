// Inspect independently published floor plans. No LLM creates rooms/measurements.
// This is a source-data audit, not localisation or walking-route validation.
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
const root = resolve(fileURLToPath(new URL('..', import.meta.url)));
const base = resolve(root, 'research/map-fixtures/oas-e54861c');
const revision = 'e54861c1099964607efd86b07e858f309e3fe45f';
const sources = [
  { file: 'apartment_50m2.json', path: 'svg-viewer/examples/apartment_50m2.json', sha: '6a3356cf5ac9d8c6d7a30f73665961d14ec47c62577fd7b414465e0ebafd3327' },
  { file: 'multi_room_plan.md', path: 'docs/examples/multi_room_plan.md', sha: '83df123b2287125beb21b8b57b18ae3a6c93f410eed8f754fc4d7882a9baa64d' }
];
const plans = [];
for (const source of sources) {
  const bytes = await readFile(resolve(base, source.file));
  if (createHash('sha256').update(bytes).digest('hex') !== source.sha) throw new Error('Downloaded fixture changed.');
  const text = bytes.toString('utf8');
  const plan = JSON.parse(source.file.endsWith('.json') ? text : text.match(/```json\s*([\s\S]*?)```/)[1]);
  if (plan.units.length !== 'mm') throw new Error('Unsupported units.');
  const issues = [];
  const rooms = plan.rooms.map(room => {
    const points = room.boundary_polygon.points;
    if (points.length < 3 || !points.every(p => Number.isFinite(p.x) && Number.isFinite(p.y))) throw new Error('Invalid polygon coordinates.');
    const twiceArea = points.reduce((sum, p, i) => { const q = points[(i + 1) % points.length]; return sum + p.x * q.y - q.x * p.y; }, 0);
    const areaM2 = Math.abs(twiceArea) / 2e6;
    if (Math.abs(areaM2 - room.area_m2) > 0.01) issues.push({ type: 'area_conflict', roomID: room.id, declaredM2: room.area_m2, polygonM2: areaM2, resolution: 'needs_author_or_user_review; source not overwritten' });
    return { id: room.id, name: room.name, usage: room.usage,
      boundingWidthM: (Math.max(...points.map(p => p.x)) - Math.min(...points.map(p => p.x))) / 1000,
      boundingDepthM: (Math.max(...points.map(p => p.y)) - Math.min(...points.map(p => p.y))) / 1000,
      polygonAreaM2: areaM2, sourceAreaM2: room.area_m2, points };
  });
  const doors = plan.openings.filter(o => o.opening_type === 'door').map(o => {
    if (!plan.walls.some(w => w.id === o.in_wall) || o.connects_rooms.some(id => id !== 'exterior' && !rooms.some(r => r.id === id))) throw new Error('Dangling opening reference.');
    return { id: o.id, connects: o.connects_rooms, widthM: o.width_mm / 1000, heightM: o.height_mm / 1000, wallID: o.in_wall };
  });
  plans.push({ id: plan.plan_id, title: plan.title,
    source: `https://github.com/autodesk-platform-services/open-architecture-standards-2d-floor-plans/blob/${revision}/${source.path}`,
    sha256: source.sha, sourceKind: 'published authored example, not a measured scan', rooms, doors, issues,
    verifiedCurrentVenue: null, ownerRelationship: null, livePose: null,
    productionAcceptance: 'NOT_MET', missing: ['venue identity and personal association', 'relocalisation anchors and matching camera/depth observations',
      'current session pose/body heading and uncertainty', 'live obstacles/floor/head clearance', 'user verification of labels and map conflicts'] });
}
const out = resolve(root, 'artifacts/map-grounding'); await mkdir(out, { recursive: true });
await writeFile(resolve(out, 'source-audit.json'), JSON.stringify({ revision, plans, note: 'Two independent source examples. Neither is the user’s home; no map edits were applied.' }, null, 2));
const escape = text => String(text).replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('"', '&quot;');
const drawings = plans.map(plan => `<section><h2>${escape(plan.title)}</h2><p><a href="${plan.source}">Pinned source</a> · ${plan.sourceKind}</p><svg xmlns="http://www.w3.org/2000/svg" viewBox="-500 -500 11000 6400" role="img" aria-label="Room polygons from the published plan, not a current position or route">${plan.rooms.map((r, i) => {
  const x = Math.min(...r.points.map(p => p.x)) + 180, y = Math.min(...r.points.map(p => p.y)) + 400;
  return `<polygon points="${r.points.map(p => `${p.x},${p.y}`).join(' ')}" fill="${['#d2e8f1','#e2ead1','#ead7ed','#f5e6c8'][i % 4]}" stroke="#293c48" stroke-width="30"/><text x="${x}" y="${y}" font-size="210">${escape(r.name)}</text><text x="${x}" y="${y + 280}" font-size="180">Bounds ${r.boundingWidthM} × ${r.boundingDepthM} m</text>`;
}).join('')}</svg><h3>Published doorway connections</h3><ul>${plan.doors.map(d => `<li>${escape(d.connects.join(' ↔ '))}: ${d.widthM} m wide, ${d.heightM} m high</li>`).join('')}</ul><p>Issues: ${plan.issues.length ? escape(JSON.stringify(plan.issues)) : 'No area conflict detected by this limited check.'}</p><p>Live navigation acceptance: <strong>NOT MET</strong>. ${escape(plan.missing.join('; '))}.</p></section>`).join('');
await writeFile(resolve(out, 'report.html'), `<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Downloaded floor-plan evidence</title><style>body{font:17px/1.6 system-ui;max-width:1000px;margin:auto;padding:24px;color:#172f3b;background:#f4f7f8}svg{width:100%}section{background:white;padding:24px;margin:24px 0}a{color:#126095}</style><h1>Downloaded floor-plan evidence</h1><p>Dimensions and room/door records come from the pinned upstream files. No model supplied them. These are authored examples, not surveyed homes. Missing data remains missing; conflicts require review. Door widths and connections are listed, not invented into this polygon drawing.</p>${drawings}</html>`);
console.log(JSON.stringify(plans.map(p => ({ id: p.id, rooms: p.rooms.length, doors: p.doors.length, issues: p.issues, productionAcceptance: p.productionAcceptance }))));
