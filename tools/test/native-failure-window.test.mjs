import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, readFile, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
const root = new URL('../../', import.meta.url);
const begin = name => `Test Case '-[BlindAssistTests.ConnectedJourneyRuntimeTests ${name}]' started.`;
const end = (name, result='failed') => `Test Case '-[BlindAssistTests.ConnectedJourneyRuntimeTests ${name}]' ${result} (3.1 seconds).`;
const fail = name => [begin(name), `NATIVE_RUNTIME_IO id=${name}-IO phase=read-start`, `NATIVE_RUNTIME_IO id=${name}-IO phase=read-return`, `NATIVE_RUNTIME_PHASE test=${name} operation=fixture-id phase=restore-detached-begin uptime=123.4`, `NATIVE_RUNTIME_WAIT test=${name} phase=returned fulfilled=false loading=true`, end(name)];
async function run(lines, shell=false) {
  const dir = await mkdtemp(join(tmpdir(), 'blind-failure-window-'));
  try {
    const fixture=join(dir,'fixture.log'); await writeFile(fixture, lines.join('\n')+'\n');
    if (!shell) return spawnSync('python3', ['tools/ci/extract-native-unit-failures.py', fixture], {cwd:root,encoding:'utf8',timeout:5000});
    const source=await readFile(new URL('tools/ci/native-apple.sh',root),'utf8');
    const helper=source.slice(source.indexOf('run_logged() {'),source.indexOf('\ncase "$mode"'));
    return spawnSync('bash',['-c',`set -euo pipefail\n${helper}\nfixture() { cat "$fixture"; return 65; }\nrun_logged unit fixture`],{cwd:root,env:{...process.env,out:dir,fixture},encoding:'utf8',timeout:5000});
  } finally {await rm(dir,{recursive:true,force:true});}
}
test('early failure retains its IO IDs and false completion despite hundreds of later successes',async()=>{
 const lines=fail('testEarly');for(let i=0;i<200;i++)lines.push(begin(`testLater${i}`),`NATIVE_RUNTIME_WAIT test=later${i} fulfilled=true`,end(`testLater${i}`,'passed'));
 const r=await run(lines);assert.equal(r.status,0);assert.match(r.stdout,/id=testEarly-IO phase=read-return/);assert.match(r.stdout,/NATIVE_RUNTIME_PHASE test=testEarly operation=fixture-id/);assert.match(r.stdout,/fulfilled=false/);assert.match(r.stdout,/testEarly.*started/);assert.match(r.stdout,/testEarly.*failed/);assert.doesNotMatch(r.stdout,/testLater/);assert.match(r.stdout,/emitted=1 omitted=0/);
});
test('phase ring and total failure cap are explicit and preserve a displaced false completion',async()=>{
 const lines=[begin('testLarge'),'NATIVE_RUNTIME_WAIT fulfilled=false'];for(let i=0;i<900;i++)lines.push(`NATIVE_RUNTIME_IO id=large phase=${i}`);lines.push(end('testLarge'),...fail('testTwo'),...fail('testThree'),...fail('testFour'));
 const r=await run(lines);assert.equal(r.status,0);assert.match(r.stdout,/retained=400 dropped=501/);assert.match(r.stdout,/fulfilled=false/);assert.match(r.stdout,/phase=899/);assert.doesNotMatch(r.stdout,/testFour/);assert.match(r.stdout,/emitted=3 omitted=1/);assert.ok(r.stdout.split('\n').length<1250);
});
test('crashed failing wait retains missing-end marker and only allowlisted metadata',async()=>{
 const r=await run([begin('testInterrupted'),'unrelated private-looking payload must not be included','NATIVE_RUNTIME_WAIT test=interrupted fulfilled=false']);assert.equal(r.status,0);assert.match(r.stdout,/TEST_END_MISSING/);assert.doesNotMatch(r.stdout,/private-looking/);
});
test('passing log emits no failure window',async()=>{
 const r=await run([begin('testPass'),'NATIVE_RUNTIME_IO id=pass phase=read-return',end('testPass','passed')]);assert.equal(r.status,0);assert.doesNotMatch(r.stdout,/FAILURE_BEGIN/);assert.match(r.stdout,/emitted=0 omitted=0/);
});
test('combined unit shell retains original error and exit65 plus early failure window',async()=>{
 const lines=[...fail('testEarly'),'error: original assertion failure'];for(let i=0;i<200;i++)lines.push(begin(`testLater${i}`),'NATIVE_RUNTIME_WAIT fulfilled=true',end(`testLater${i}`,'passed'));
 const r=await run(lines,true);assert.equal(r.status,65);assert.match(r.stdout,/error: original assertion failure/);assert.match(r.stdout,/id=testEarly-IO/);assert.match(r.stdout,/fulfilled=false/);assert.match(r.stdout,/FAILURE_SUMMARY emitted=1/);
});
