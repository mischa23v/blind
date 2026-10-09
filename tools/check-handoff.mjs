import { readFile } from 'node:fs/promises';
import { resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';

const root = process.argv[2] ? resolve(process.argv[2]) : resolve(fileURLToPath(new URL('..', import.meta.url)));
const manifest = JSON.parse(await readFile(resolve(root, 'HANDOFF_MANIFEST.json'), 'utf8'));
for (const item of manifest.files) {
  const path = resolve(root, item.path);
  if (!path.startsWith(root + sep)) throw new Error('Invalid manifest path.');
  const data = await readFile(path);
  if (data.length !== item.bytes || createHash('sha256').update(data).digest('hex') !== item.sha256) throw new Error(`Handoff mismatch: ${item.path}`);
}
console.log(`Verified ${manifest.files.length} files against the handoff manifest.`);
