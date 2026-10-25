// Packaging-only contracts, not a native test run or new acceptance evidence.
// Keep published packets unchanged: their standalone contracts expect the actual
// workflow beside them, although the repository stores workflows under .github.
import test from 'node:test';
import assert from 'node:assert/strict';
import {copyFileSync, mkdtempSync, readdirSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';

const root = fileURLToPath(new URL('../../', import.meta.url));
for (const name of ['reading-component', 'reading-review-component']) {
  test(`${name}: unchanged published contracts with repository workflow`, () => {
    const dir = mkdtempSync(join(process.env.BLIND_TEST_SCRATCH || tmpdir(), 'reading-contract-'));
    try {
      const packet = join(root, 'tests/scenarios/integrated', name);
      for (const entry of readdirSync(packet, {withFileTypes: true})) {
        if (entry.isFile()) copyFileSync(join(packet, entry.name), join(dir, entry.name));
      }
      const workflow = `native-${name}.yml`;
      copyFileSync(join(root, '.github/workflows', workflow), join(dir, workflow));
      // Only Node source contracts execute; never invoke the native runner.
      // A nested test process must own its runner, not inherit the parent's IPC context.
      const env = {...process.env};
      delete env.NODE_TEST_CONTEXT;
      const result = spawnSync(process.execPath, ['--test', 'contract.test.mjs'], {
        cwd: dir, env, encoding: 'utf8', timeout: 30_000,
      });
      assert.ifError(result.error);
      assert.equal(result.status, 0, result.stdout + result.stderr);
    } finally {
      rmSync(dir, {recursive: true, force: true});
    }
  });
}
