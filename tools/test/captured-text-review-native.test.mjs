// Extracted production controller methods + actual Core reading/authority policies.
// Camera/session/budget/speech are explicit substitutes: not native audio/device QA.
import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,rmSync,readFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const root=fileURLToPath(new URL('../../',import.meta.url));
const swift=process.env.BLIND_SWIFTC || 'swiftc';
const available=spawnSync(swift,['--version'],{encoding:'utf8'}).status===0;
test('extracted captured-page review controller: lifetime, cancellation, budget, private ownership', {skip:!available},()=>{
 const dir=mkdtempSync(join(process.env.BLIND_TEST_SCRATCH || tmpdir(),'captured-review-'));
 try {
  const source=join(dir,'main.swift'), binary=join(dir,'review');
  const gen=spawnSync('python3',[join(root,'tools/test/generate-captured-review-witness.py'),root,source],{encoding:'utf8'});
  assert.equal(gen.status,0,gen.stdout+gen.stderr);
  const build=spawnSync(swift,['-swift-version','5','-module-cache-path',join(dir,'cache'),source,'-o',binary],{encoding:'utf8',timeout:120000});
  assert.equal(build.status,0,build.stdout+build.stderr);
  const run=spawnSync(binary,[],{encoding:'utf8',timeout:30000});
  assert.equal(run.status,0,run.stdout+run.stderr);
  assert.match(run.stdout,/Executed 9 tests, with 0 failures/);
 } finally { rmSync(dir,{recursive:true,force:true}); }
});
