// Data preparation only. This converts a pinned authored example, not a real scanned venue.
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { createHash } from 'node:crypto';
const revision = 'e54861c1099964607efd86b07e858f309e3fe45f';
const directory = new URL('../research/map-fixtures/oas-e54861c/', import.meta.url);
const raw = await readFile(new URL('apartment_50m2.json', directory));
const expected = '6a3356cf5ac9d8c6d7a30f73665961d14ec47c62577fd7b414465e0ebafd3327';
if (createHash('sha256').update(raw).digest('hex') !== expected) throw Error('Source differs from the pinned download.');
const plan = JSON.parse(raw);
const sourceURL = `https://github.com/autodesk-platform-services/open-architecture-standards-2d-floor-plans/blob/${revision}/svg-viewer/examples/apartment_50m2.json`;
const packageData = {
  schemaVersion: 1, id: 'oas-apartment-example', revision: 'oas-e54861c-adapter-v1',
  name: plan.title, description: 'Independently published authored apartment example. Not a scanned home or the user’s home.',
  author: 'Autodesk Platform Services source example; Blind Assist format adaptation', license: 'Apache-2.0',
  licenseText: await readFile(new URL('LICENSE', directory), 'utf8'),
  attribution: `Derived from ${sourceURL}. Source SHA-256 ${expected}. Adaptation converts millimetres to metres and source x/y drawing coordinates to package x/z. No current position or route was added.`,
  sourceURL, createdAt: '2026-10-08T00:00:00Z', visibility: 'public', provenance: 'authored',
  coordinateSystem: 'local-meters-y-up', localization: 'preview-only',
  coverageGaps: ['The actual building, address, owner and floor are unknown.', 'Drawing axes are not north or the user’s facing direction.',
    'No live pose, relocalization anchors, floor/head clearance or obstacle observations.',
    'Door relationships and dimensions come from the authored example. Door positions and live opening status are not established.',
    'The bedroom and bathroom share a boundary but the source does not connect them directly.'],
  floors: [{ id: 'drawing-level', name: 'Drawing level — actual floor unknown', frameID: 'oas-plan-local' }],
  rooms: plan.rooms.map(room => ({ id: room.id, name: room.name, floorID: 'drawing-level',
    kind: room.usage === 'circulation' ? 'corridor' : 'room', description: `Source usage: ${room.usage}. Authored area: ${room.area_m2} square metres.`,
    boundary: room.boundary_polygon.points.map(point => ({ x: point.x / 1000, y: 0, z: point.y / 1000 })) })),
  connections: plan.openings.filter(opening => opening.opening_type === 'door').map(opening => ({
    id: opening.id, fromRoomID: opening.connects_rooms[0], toRoomID: opening.connects_rooms[1], kind: 'door', state: 'mapped',
    source: `Pinned OAS example, wall ${opening.in_wall}`, widthMeters: opening.width_mm / 1000, heightMeters: opening.height_mm / 1000
  })), reviews: []
};
if (packageData.connections.some(edge => edge.fromRoomID === 'exterior' || edge.toRoomID === 'exterior'))
  packageData.rooms.push({ id: 'exterior', name: 'Exterior connection', floorID: 'drawing-level', kind: 'exit', description: 'The source labels this connection exterior. No exterior geometry or route is supplied.' });
const bytes = JSON.stringify(packageData, null, 2) + '\n';
for (const relative of ['../maps/community/', '../BlindCore/Tests/BlindCoreTests/Fixtures/']) {
  const output = new URL(relative, import.meta.url); await mkdir(output, { recursive: true });
  await writeFile(new URL('oas-apartment.blindplace.json', output), bytes);
}
console.log('Prepared the pinned OAS apartment package and XCTest resource. No tests, localisation or navigation were run.');
