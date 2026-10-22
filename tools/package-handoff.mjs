import { readdir, mkdir, readFile, writeFile, copyFile, stat } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { resolve, join, extname } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(fileURLToPath(new URL('..', import.meta.url)));
const stamp = new Date().toISOString().replaceAll(':', '-').replaceAll('.', '-');
const destination = join(root, 'artifacts', `blind-assist-${stamp}`);
const excluded = new Set(['.build', '.pio', '.tools', '.git', 'node_modules', 'artifacts', 'xcuserdata', 'DerivedData']);
const extensions = new Set(['.swift', '.sql', '.mjs', '.py', '.cpp', '.c', '.h', '.hpp', '.ino', '.ini', '.md', '.json', '.plist', '.pbxproj', '.xcscheme', '.xcconfig', '.sh', '.yml', '.yaml']);
const files = [];
async function collect(directory) {
  for (const item of await readdir(join(root, directory), { withFileTypes: true })) {
    if (excluded.has(item.name) || (item.name.startsWith('.') && item.name !== '.env.example')) continue;
    const path = `${directory}/${item.name}`;
    if (item.isDirectory()) await collect(path);
    else if (item.isFile() && (extensions.has(extname(item.name)) || item.name === '.env.example' || /^(LICENSE|NOTICE)(\..*)?$/.test(item.name))) files.push(path);
  }
}
for (const directory of ['BlindCore', 'BlindMemory', 'ios', 'firmware', 'hardware', 'integration', 'maps', 'server', 'tools', 'research']) await collect(directory);
// Never package what .gitignore keeps private (datasets, currency references, local models): keep
// only files Git would track, when Git metadata is available.
const ignoredCheck = spawnSync('git', ['check-ignore', '--stdin'], { cwd: root, input: files.join('\n'), encoding: 'utf8' });
if (ignoredCheck.status === 0 || ignoredCheck.status === 1) {
  const ignored = new Set(ignoredCheck.stdout.split('\n').filter(Boolean));
  for (let index = files.length - 1; index >= 0; index--) if (ignored.has(files[index])) files.splice(index, 1);
} else {
  throw new Error('Could not check .gitignore; refusing to package possibly private files.');
}
files.push('README.md', 'MAC_HANDOFF.md', 'blind.txt', 'package.json', 'package-lock.json', '.gitignore',
  'AGENTS.md', 'PROJECT_PLAN.md', 'TASKS.md', 'TODO.md', 'PROGRESS.md');
// Include only these known synthetic evaluation artifacts, never personal map databases.
for (const file of ['artifacts/simulation/report.html', 'artifacts/simulation/report.json', 'artifacts/simulation/cafe.synthetic.json',
  'artifacts/native-memory/node-tests.tap', 'artifacts/minimum-assistant/node-tests.tap', 'artifacts/minimum-assistant/integration-tests.tap', 'artifacts/minimum-assistant/checkpoint.json',
  'artifacts/home-awareness/minimum-core.json', 'artifacts/map-grounding/source-audit.json', 'artifacts/map-grounding/report.html',
  'research/user-notes/blindw.txt']) {
  try { if ((await stat(join(root, file))).isFile()) files.push(file); }
  catch (error) { if (error.code !== 'ENOENT') throw error; }
}
await mkdir(destination, { recursive: true });
const manifest = [];
for (const file of files.sort()) {
  const source = join(root, file), output = join(destination, file);
  await mkdir(resolve(output, '..'), { recursive: true });
  await copyFile(source, output);
  const data = await readFile(output);
  manifest.push({ path: file, bytes: data.length, sha256: createHash('sha256').update(data).digest('hex') });
}
await writeFile(join(destination, 'HANDOFF_MANIFEST.json'), JSON.stringify({ created: new Date().toISOString(), files: manifest }, null, 2));
const archive = `${destination}.tar.gz`;
const result = spawnSync('tar', ['-czf', archive, '-C', destination, '.'], { stdio: 'inherit' });
if (result.error || result.status !== 0) throw new Error('Archive creation failed; source staging folder is available.');
const digest = createHash('sha256').update(await readFile(archive)).digest('hex');
await writeFile(`${archive}.sha256`, `${digest}  ${archive.split(/[\\/]/).at(-1)}\n`);
console.log(`Packaged ${files.length} source files (${(await stat(archive)).size} bytes): ${archive}`);
console.log('Dependency caches, local credentials and personal map databases are excluded.');
