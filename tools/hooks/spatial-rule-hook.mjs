// Claude Code PostToolUse hook (configured in .claude/settings.json). After an AI edit to a
// file that carries the spatial safety rule (AGENTS.md, task E13), rerun the rule's tests.
// Exit 2 feeds the message back to the editing session; other files exit 0 immediately.
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';

const root = resolve(fileURLToPath(new URL('../..', import.meta.url)));
const GUARDED = ['server/src/app.mjs', 'server/src/scene-policy.mjs', 'server/src/spatial-guard.mjs',
  'BlindCore/Sources/BlindCore/SpatialClaimGuard.swift', 'ios/BlindAssist/NavigationModel.swift',
  'BlindCore/Tests/BlindCoreTests/Fixtures/spatial-claims.json', 'AGENTS.md',
  'tools/test/spatial-rule.test.mjs', 'server/test/spatial-guard.test.mjs'];

let input = '';
for await (const chunk of process.stdin) input += chunk;
let path = '';
try {
  const event = JSON.parse(input || '{}');
  path = event.tool_input?.file_path ?? event.tool_response?.filePath ?? '';
} catch { process.exit(0); }
const normalized = path.replace(/\\/g, '/').toLowerCase();
if (!GUARDED.some(file => normalized.endsWith(file.toLowerCase()))) process.exit(0);

const result = spawnSync(process.execPath, ['--test', '--test-concurrency=1',
  'tools/test/spatial-rule.test.mjs', 'server/test/spatial-guard.test.mjs'], { cwd: root, encoding: 'utf8' });
if (result.status === 0) process.exit(0);
const notOk = (result.stdout ?? '').split('\n').filter(line => line.startsWith('not ok')).slice(0, 5).join('\n');
process.stderr.write(`Spatial safety rule check did not pass after this edit to ${path}. Restore the spatial check (AGENTS.md, task E13) before continuing.\n${notOk}\n`);
process.exit(2);
