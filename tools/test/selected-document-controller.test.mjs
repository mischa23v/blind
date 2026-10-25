// Production extension + actual Core owner; substitutes are expressly not native audio/PDF.
import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
const root = fileURLToPath(new URL('../../', import.meta.url));
const swift = process.env.BLIND_SWIFTC || 'swiftc';
const available = spawnSync(swift, ['--version'], { encoding: 'utf8' }).status === 0;
test('extracted selected-PDF controller ownership, exact callbacks, private redaction, lease and budget wakes', { skip: !available }, t => {
  const dir = mkdtempSync(join(process.env.BLIND_TEST_SCRATCH || tmpdir(), 'selected-document-controller-'));
  try {
    const source = join(dir, 'main.swift'), binary = join(dir, 'witness');
    const generated = spawnSync('python3', [join(root, 'tools/test/generate-selected-document-witness.py'), root, source], { encoding: 'utf8' });
    assert.equal(generated.status, 0, generated.stdout + generated.stderr);
    const built = spawnSync(swift, ['-swift-version', '5', '-parse-as-library', '-module-cache-path', join(dir, 'cache'), source, '-o', binary], { encoding: 'utf8', timeout: 120000 });
    assert.equal(built.status, 0, built.stdout + built.stderr);
    const ran = spawnSync(binary, [], { encoding: 'utf8', timeout: 30000 });
    assert.equal(ran.status, 0, ran.stdout + ran.stderr);
    assert.match(ran.stdout, /Selected document projection: \d+ assertions; 0 failures/);
    t.diagnostic(ran.stdout.trim());
  } finally { rmSync(dir, { recursive: true, force: true }); }
});
