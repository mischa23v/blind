// Read-only upstream research. Fetches metadata and small source files only.
// Does not install dependencies, run upstream code, start services, or use Docker.
import { mkdir, readFile, readdir, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('..', import.meta.url));
const output = resolve(root, 'research/assistant-upstreams');
const repositories = [
  'groue/GRDB.swift', 'mem0ai/mem0', 'getzep/graphiti',
  'vectorize-io/hindsight', 'letta-ai/letta', 'letta-ai/letta-code', 'ml-explore/mlx-swift-lm',
  'introlab/rtabmap', 'recastnavigation/recastnavigation',
  'soundscape-community/soundscape', 'apple/swift-async-algorithms',
  'ifzhang/ByteTrack', 'deepinsight/insightface', 'isl-org/Open3D',
  'maplibre/maplibre-native', 'microsoft/onnxruntime',
  'hulop/NavCogIOSv3', 'openindoormaps/openindoormaps', 'open-indoor/openindoor6',
];
const indexOnly = process.argv.includes('--index-only');
const only = process.argv.slice(2).filter(arg => arg !== '--index-only');
const selected = only.length ? repositories.filter(r => only.includes(r)) : repositories;
if (only.some(r => !repositories.includes(r))) throw new Error('Unknown repository');
await mkdir(output, { recursive: true });
const headers = { 'User-Agent': 'BlindAssist-Upstream-Research', Accept: 'application/vnd.github+json' };
async function fetchText(url, maximumBytes = 12_000_000) {
  const response = await fetch(url, { headers, signal: AbortSignal.timeout(30_000) });
  if (!response.ok) throw new Error(`${response.status} ${url}`);
  const chunks = []; let size = 0;
  for await (const chunk of response.body) {
    size += chunk.length;
    if (size > maximumBytes) throw new Error(`Response exceeds research size limit: ${url}`);
    chunks.push(chunk);
  }
  return Buffer.concat(chunks).toString('utf8');
}
async function json(url) { return JSON.parse(await fetchText(url)); }
function blobURL(repo, sha, path) {
  return `https://github.com/${repo}/blob/${sha}/${path}`;
}
async function audit(repo) {
  const record = { requestedRepository: repo, retrievedAt: new Date().toISOString(), execution: 'Not installed, compiled, or tested' };
  const destination = resolve(output, repo.replace('/', '--'));
  await mkdir(destination, { recursive: true });
  try {
    const metadata = await json(`https://api.github.com/repos/${repo}`);
    Object.assign(record, {
      repository: metadata.full_name, url: metadata.html_url, defaultBranch: metadata.default_branch,
      archived: metadata.archived, pushedAt: metadata.pushed_at, createdAt: metadata.created_at,
      declaredLicense: metadata.license?.spdx_id ?? null, openIssuesAndPRs: metadata.open_issues_count,
    });
    const commit = await json(`https://api.github.com/repos/${repo}/commits/${metadata.default_branch}`);
    record.revision = commit.sha;
    record.commitDate = commit.commit.committer.date;
    const tree = await json(`https://api.github.com/repos/${repo}/git/trees/${commit.sha}?recursive=1`);
    record.treeTruncated = tree.truncated;
    const paths = tree.tree.filter(x => x.type === 'blob').map(x => x.path);
    const tests = paths.filter(p => /(^|\/)(tests?|__tests__)(\/|\.)|Tests\.swift$|test_[^/]+\.(py|cpp)$|\.(test|spec)\.[cm]?[jt]sx?$/i.test(p));
    const workflows = paths.filter(p => /^\.github\/workflows\/[^/]+\.ya?ml$/.test(p));
    record.testPathCount = tests.length;
    record.testPaths = tests.slice(0, 40).map(p => blobURL(repo, commit.sha, p));
    record.workflows = workflows.map(p => blobURL(repo, commit.sha, p));
    await writeFile(resolve(destination, 'paths.json'), JSON.stringify(paths, null, 2) + '\n');
    const readme = paths.find(p => /^readme(\.md|\.rst|\.txt)?$/i.test(p));
    const license = paths.find(p => /^(license|licence|copying)(\.md|\.txt|\.rst)?$/i.test(p));
    const packageFile = paths.find(p => /^(Package\.swift|pyproject\.toml|package\.json|CMakeLists\.txt)$/.test(p));
    const samples = [...new Set([readme, license, packageFile,
      workflows.find(p => /test|ci|build/i.test(p)) ?? workflows[0],
      tests.find(p => /\.(swift|py|cpp|ts)$/.test(p))].filter(Boolean))];
    record.evidence = [];
    for (const path of samples) {
      const entry = { path, url: blobURL(repo, commit.sha, path) };
      try {
        const source = await fetchText(`https://raw.githubusercontent.com/${repo}/${commit.sha}/${path}`, 1_000_000);
        entry.sha256 = createHash('sha256').update(source).digest('hex');
        entry.localFile = path.replaceAll('/', '__');
        await writeFile(resolve(destination, entry.localFile), source);
      } catch (error) { entry.error = error.message; }
      record.evidence.push(entry);
    }
  } catch (error) { record.error = error.message; }
  await writeFile(resolve(destination, 'audit.json'), JSON.stringify(record, null, 2) + '\n');
  console.log(JSON.stringify({ repository: repo, revision: record.revision, license: record.declaredLicense,
    testPaths: record.testPathCount, workflows: record.workflows?.length, error: record.error }));
  return record;
}
// Two small HTTP jobs at a time; no model weights or source archives are downloaded.
const queue = indexOnly ? [] : [...selected];
await Promise.all([0, 1].map(async () => {
  while (queue.length) { const repo = queue.shift(); await audit(repo); }
}));
const results = [];
for (const dir of await readdir(output, { withFileTypes: true })) {
  if (!dir.isDirectory()) continue;
  const destination = resolve(output, dir.name);
  const record = JSON.parse(await readFile(resolve(destination, 'audit.json'), 'utf8'));
  if (record.revision && !record.error) {
    const paths = JSON.parse(await readFile(resolve(destination, 'paths.json'), 'utf8'));
    const tests = paths.filter(p => /(^|\/)(tests?|__tests__)(\/|\.)|Tests\.swift$|test_[^/]+\.(py|cpp)$|\.(test|spec)\.[cm]?[jt]sx?$/i.test(p));
    record.testPathCount = tests.length;
    record.testPaths = tests.slice(0, 40).map(p => blobURL(record.repository, record.revision, p));
    for (const item of record.evidence) {
      if (!item.localFile) continue;
      const body = await readFile(resolve(destination, item.localFile));
      if (createHash('sha256').update(body).digest('hex') !== item.sha256) throw new Error(`Changed research evidence: ${item.url}`);
    }
    await writeFile(resolve(destination, 'audit.json'), JSON.stringify(record, null, 2) + '\n');
  }
  results.push(record);
}
results.sort((a, b) => a.requestedRepository.localeCompare(b.requestedRepository));
await writeFile(resolve(output, 'review.json'), JSON.stringify({ indexedAt: new Date().toISOString(), results }, null, 2) + '\n');
const table = ['# Pinned upstream research inventory', '',
  'Research snapshots only, not dependency selections. File-path counts include fixtures and are not passed test counts. No upstream code or tests were executed. API license labels may be incomplete; see the written review and actual license notices.', '',
  '| Repository | Reviewed revision | Commit date (UTC) | API license label | Test-related paths | Workflows | Retrieval |',
  '| --- | --- | --- | --- | ---: | ---: | --- |'];
for (const r of results) table.push(`| [${r.repository ?? r.requestedRepository}](${r.url ?? ''}) | [${r.revision?.slice(0, 12) ?? 'unavailable'}](${r.url}/commit/${r.revision}) | ${r.commitDate ?? 'unknown'} | ${r.declaredLicense ?? 'unknown'} | ${r.testPathCount ?? 'unknown'} | ${r.workflows?.length ?? 'unknown'} | ${r.error ? 'Incomplete; see audit.json' : 'Source snapshot obtained'} |`);
table.push('', 'Each repository folder contains audit.json with full revisions, pinned source URLs, file hashes, and any retrieval failures. paths.json records the inspected source tree. Copies are reference evidence, not app dependencies.', '');
await writeFile(resolve(output, 'INDEX.md'), table.join('\n'));
console.log(`Indexed ${results.length} repositories; downloaded evidence hashes checked. No runtime tests executed.`);
