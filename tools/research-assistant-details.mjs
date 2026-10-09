// Download named, pinned reference files discovered in the first research pass.
// Upstream source is evidence only; nothing is executed or added as a dependency.
import { readFile, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
const root = fileURLToPath(new URL('../research/assistant-upstreams/', import.meta.url));
const selections = {
  'groue/GRDB.swift': ['GRDB/Migration/DatabaseMigrator.swift', 'Tests/GRDBTests/Migrations/DatabaseMigratorTests.swift', 'Tests/GRDBTests/Core/DatabasePool/DatabasePoolConcurrencyTests.swift'],
  'getzep/graphiti': ['graphiti_core/edges.py', 'graphiti_core/search/search_filters.py', 'tests/utils/maintenance/test_edge_operations.py', '.github/workflows/unit_tests.yml'],
  'mem0ai/mem0': ['tests/memory/test_session_scope.py', 'tests/memory/test_storage.py'],
  'vectorize-io/hindsight': ['hindsight-api-slim/tests/test_bank_config_atomicity.py', 'hindsight-api-slim/tests/test_bank_file_storage.py'],
  'soundscape-community/soundscape': ['apps/ios/GuideDogs/Code/Command Processor/CalloutHistory.swift', 'apps/ios/GuideDogs/Code/Behaviors/Helpers/CalloutStateMachine.swift', 'apps/ios/GuideDogs/Code/Behaviors/Default/AutoCalloutGenerator.swift', '.github/workflows/ios-tests.yml'],
  'apple/swift-async-algorithms': ['Tests/AsyncAlgorithmsTests/TestThrottle.swift', 'Tests/AsyncAlgorithmsTests/TestDebounce.swift', 'Tests/AsyncAlgorithmsTests/TestChannel.swift'],
  'recastnavigation/recastnavigation': ['Tests/DetourCrowd/Tests_DetourPathCorridor.cpp'],
};
for (const [repo, paths] of Object.entries(selections)) {
  const directory = resolve(root, repo.replace('/', '--'));
  const record = JSON.parse(await readFile(resolve(directory, 'audit.json'), 'utf8'));
  const known = JSON.parse(await readFile(resolve(directory, 'paths.json'), 'utf8'));
  for (const path of paths) {
    if (!known.includes(path)) throw new Error(`Undiscovered path: ${repo}/${path}`);
    const url = `https://raw.githubusercontent.com/${repo}/${record.revision}/${path}`;
    const response = await fetch(url, { signal: AbortSignal.timeout(30_000) });
    if (!response.ok) throw new Error(`${response.status}: ${url}`);
    const source = await response.text();
    if (Buffer.byteLength(source) > 1_000_000) throw new Error(`Oversized reference: ${url}`);
    const entry = { path, url: `https://github.com/${repo}/blob/${record.revision}/${path}`,
      localFile: path.replaceAll('/', '__'), sha256: createHash('sha256').update(source).digest('hex') };
    await writeFile(resolve(directory, entry.localFile), source);
    record.evidence = record.evidence.filter(e => e.path !== path).concat(entry);
  }
  await writeFile(resolve(directory, 'audit.json'), JSON.stringify(record, null, 2) + '\n');
  console.log(`${repo}: ${paths.length} pinned reference files downloaded`);
}
