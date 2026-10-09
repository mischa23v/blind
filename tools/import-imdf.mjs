import { readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';

export function importLandmarks(document, latitude, longitude) {
  if (document?.type !== 'FeatureCollection' || !Array.isArray(document.features) ||
      !Number.isFinite(latitude) || !Number.isFinite(longitude) || Math.abs(latitude) > 90 || Math.abs(longitude) > 180) throw new Error('Invalid GeoJSON or origin.');
  const nodes = document.features.filter(feature => feature.geometry?.type === 'Point').map(feature => {
    const [lon, lat] = feature.geometry.coordinates ?? [];
    if (typeof feature.id !== 'string' || !feature.id || !Number.isFinite(lat) || !Number.isFinite(lon) ||
        Math.abs(lat) > 90 || Math.abs(lon) > 180) throw new Error('Invalid point feature.');
    return { id: feature.id, name: feature.properties?.name?.en ?? feature.id,
      level: feature.properties?.level_id ?? 'unknown', position: {
        x: (lon - longitude) * Math.PI / 180 * 6371000 * Math.cos(latitude * Math.PI / 180),
        y: 0, z: -(lat - latitude) * Math.PI / 180 * 6371000 } };
  });
  if (!nodes.length || new Set(nodes.map(node => node.id)).size !== nodes.length) throw new Error('No point landmarks, or duplicate identifiers.');
  return { name: 'Imported landmarks — author and verify route edges', nodes, edges: [] };
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [input, output, lat, lon] = process.argv.slice(2);
  if (!input || !output || lat === undefined || lon === undefined) throw new Error('Usage: npm run maps -- points.geojson map.json latitude longitude');
  await writeFile(output, JSON.stringify(importLandmarks(JSON.parse(await readFile(input, 'utf8')), Number(lat), Number(lon)), null, 2) + '\n', { flag: 'wx' });
  console.log('Imported landmarks. Route edges must be authored from surveyed walkable connections.');
}
