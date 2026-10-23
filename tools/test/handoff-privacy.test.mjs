// Execute the actual packager only in tiny, disposable repositories containing synthetic data.
// Never invoke it against this checkout or copy any user/private source into the fixtures.
import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, mkdir, readFile, writeFile, readdir, rm } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';

const packager = await readFile(new URL('../package-handoff.mjs', import.meta.url), 'utf8');
const directories = ['BlindCore', 'BlindMemory', 'ios', 'firmware', 'hardware', 'integration', 'maps', 'server', 'tools', 'research'];
const required = ['README.md', 'MAC_HANDOFF.md', 'blind.txt', 'package.json', 'package-lock.json', '.gitignore',
  'AGENTS.md', 'PROJECT_PLAN.md', 'TASKS.md', 'TODO.md', 'PROGRESS.md'];
const syntheticSecret = 'SYNTHETIC_PRIVATE_SENTINEL_NOT_USER_DATA';

async function fixture(t, { git = true, ignore = true } = {}) {
  const root = await mkdtemp(join(tmpdir(), 'blind-handoff-privacy-'));
  t.after(() => rm(root, { recursive: true, force: true }));
  for (const directory of directories) await mkdir(join(root, directory), { recursive: true });
  for (const file of required) await writeFile(join(root, file), file.endsWith('.json') ? '{}\n' : 'Synthetic test fixture\n');
  await writeFile(join(root, '.gitignore'), ignore ? 'research/private/\n' : '');
  await writeFile(join(root, 'tools/package-handoff.mjs'), packager);
  if (git) {
    const init = spawnSync('git', ['init', '--quiet', root], { encoding: 'utf8' });
    assert.equal(init.status, 0, init.stderr);
  }
  return root;
}
async function put(root, path, data) {
  await mkdir(dirname(join(root, path)), { recursive: true });
  await writeFile(join(root, path), data);
}
function run(root) {
  return spawnSync(process.execPath, [join(root, 'tools/package-handoff.mjs')], {
    cwd: root, encoding: 'utf8', timeout: 20_000,
    env: { ...process.env, GIT_CEILING_DIRECTORIES: dirname(root) }
  });
}
async function staged(root) {
  const entries = await readdir(join(root, 'artifacts'), { withFileTypes: true });
  const folders = entries.filter(entry => entry.isDirectory());
  assert.equal(folders.length, 1, 'Exactly one synthetic handoff directory');
  const output = join(root, 'artifacts', folders[0].name);
  const manifest = JSON.parse(await readFile(join(output, 'HANDOFF_MANIFEST.json'), 'utf8'));
  return { output, files: manifest.files.map(file => file.path) };
}

test('NUL-delimited Git filtering excludes ignored Arabic and newline filenames verbatim', async t => {
  const root = await fixture(t);
  const hidden = ['research/private/مرجع نقدي.json', 'research/private/private\nreference.json',
    'research/private/quote"reference.json', 'research/private/back\\slash.json'];
  const visible = ['research/قراءة عامة.md', 'research/public\nreference.json', 'tools/allowed.mjs'];
  for (const path of hidden) await put(root, path, syntheticSecret);
  for (const path of visible) await put(root, path, 'Public synthetic fixture\n');
  const result = run(root);
  assert.equal(result.status, 0, result.stderr || result.error?.message);
  const { output, files } = await staged(root);
  for (const path of hidden) assert.ok(!files.includes(path), `Ignored path leaked: ${JSON.stringify(path)}`);
  for (const path of visible) assert.ok(files.includes(path), `Allowed path missing: ${JSON.stringify(path)}`);
  for (const path of files) {
    const bytes = await readFile(join(output, path), 'utf8');
    assert.ok(!bytes.includes(syntheticSecret), `Private synthetic contents leaked through ${JSON.stringify(path)}`);
  }
});

test('Git check-ignore no-match exit status permits public synthetic source packaging', async t => {
  const root = await fixture(t, { ignore: false });
  await put(root, 'research/allowed.json', '{"synthetic":true}\n');
  const result = run(root);
  assert.equal(result.status, 0, result.stderr || result.error?.message);
  assert.ok((await staged(root)).files.includes('research/allowed.json'));
});

test('handoff fails closed before staging when Git cannot determine ignored paths', async t => {
  const root = await fixture(t, { git: false });
  await put(root, 'research/private/غير منشور.json', syntheticSecret);
  const result = run(root);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /refusing to package possibly private files/);
  await assert.rejects(readdir(join(root, 'artifacts')), { code: 'ENOENT' });
});

test('handoff preserves required native source, bundled prompt and notices', async t => {
  const root = await fixture(t);
  const paths=['ios/BlindAssist/CurrencyNative/BAReferenceMatcher.mm',
    'BlindCore/Sources/BlindCore/Resources/guide-prompt.txt',
    'ios/BlindAssist/CurrencyNative/THIRD_PARTY_NOTICES.txt',
    'research/example/component.LICENSE', 'tools/currency-reference/requirements.txt'];
  for(const path of paths) await put(root,path,'Public synthetic source fixture\n');
  const result=run(root);assert.equal(result.status,0,result.stderr);
  const {files}=await staged(root);for(const path of paths) assert.ok(files.includes(path),path);
});
