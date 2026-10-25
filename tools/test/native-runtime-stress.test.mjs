// Synthetic shell runner witnesses, not Xcode or simulator execution.
import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, mkdir, writeFile, readFile, rm } from 'node:fs/promises';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { spawnSync } from 'node:child_process';
const root=new URL('../../',import.meta.url);
async function run(mode) {
 const dir=await mkdtemp(join(tmpdir(),'blind-runtime-stress-'));
 try {
  await mkdir(join(dir,'bin'));await mkdir(join(dir,'blind-native-ci'));await writeFile(join(dir,'blind-native-ci/simulator-id'),'synthetic-simulator');
  const commands={uname:'#!/bin/bash\necho Darwin\n',git:'#!/bin/bash\necho synthetic-sha\n',xcrun:`#!/bin/bash
if [[ "$MODE" == missing-summary ]]; then exit 1; fi
if [[ "$MODE" == skipped-tests ]]; then echo '{"result":"Passed","totalTestCount":17,"passedTests":16,"failedTests":0,"skippedTests":1}'; exit 0; fi
if [[ "$MODE" == zero-tests ]]; then echo '{"result":"Passed","totalTestCount":0,"passedTests":0,"failedTests":0,"skippedTests":0}'; exit 0; fi
if [[ "$MODE" == first-fail && "$(cat "$RUNNER_TEMP/count")" = 1 ]]; then
 echo '{"result":"Failed","totalTestCount":17,"passedTests":16,"failedTests":1,"skippedTests":0}'
else
 echo '{"result":"Passed","totalTestCount":17,"passedTests":17,"failedTests":0,"skippedTests":0}'
fi
`,xcodebuild:`#!/bin/bash
printf '%s\\n' "$*" >> "$RUNNER_TEMP/commands.log"
if [[ "$*" == *build-for-testing* ]]; then
 if [[ "$MODE" == build-fail ]]; then echo 'error: synthetic build failure'; exit 65; fi
 exit 0
fi
previous=''; for arg in "$@"; do
 if [[ "$previous" = -resultBundlePath ]]; then mkdir -p "$arg"; fi
 previous="$arg"
done
count=0; [[ -f "$RUNNER_TEMP/count" ]] && count=$(cat "$RUNNER_TEMP/count")
count=$((count+1)); echo "$count" > "$RUNNER_TEMP/count"
echo "Test Case '-[BlindAssistTests.ConnectedJourneyRuntimeTests testSynthetic]' started."
if [[ "$MODE" == first-fail && "$count" = 1 ]]; then
 echo 'NATIVE_RUNTIME_IO id=fixture phase=read-return'
 echo 'NATIVE_RUNTIME_WAIT fulfilled=false'
 echo 'error: synthetic-original-assertion'
 echo "Test Case '-[BlindAssistTests.ConnectedJourneyRuntimeTests testSynthetic]' failed (3.1 seconds)."
 exit 65
fi
echo "Test Case '-[BlindAssistTests.ConnectedJourneyRuntimeTests testSynthetic]' passed (0.1 seconds)."
echo 'Executed 17 tests, with 0 failures'
`};
  for(const [name,source]of Object.entries(commands))await writeFile(join(dir,'bin',name),source,{mode:0o755});
  const result=spawnSync('bash',['tools/ci/native-runtime-stress.sh'],{cwd:root,env:{...process.env,PATH:join(dir,'bin')+':'+process.env.PATH,RUNNER_TEMP:dir,DEVELOPER_DIR:dir,MODE:mode},encoding:'utf8',timeout:10000});
  assert.equal(result.error,undefined);
  return {...result,commands:(await readFile(join(dir,'commands.log'),'utf8')).trim().split('\n'),results:await readFile(join(dir,'blind-runtime-stress/results.tsv'),'utf8')};
 }finally{await rm(dir,{recursive:true,force:true});}
}
test('one failed attempt cannot be erased by four later passes',async()=>{
 const r=await run('first-fail');assert.equal(r.status,1);assert.equal(r.commands.length,6);assert.equal(r.commands.filter(x=>x.includes('build-for-testing')).length,1);assert.equal(r.commands.filter(x=>x.includes('test-without-building')).length,5);assert.match(r.stdout,/fulfilled=false/);assert.match(r.stdout,/error: synthetic-original-assertion/);assert.match(r.stdout,/completed=5 failed_attempts=1/);assert.match(r.results,/1\t65/);assert.match(r.results,/5\t0/);
});
test('all five successful attempts are retained without extra retries',async()=>{
 const r=await run('pass');assert.equal(r.status,0);assert.equal(r.commands.length,6);assert.match(r.stdout,/completed=5 failed_attempts=0/);assert.equal(r.results.trim().split('\n').length,6);
 for(const command of r.commands){assert.ok(command.includes('-only-testing:BlindAssistTests/ConnectedJourneyRuntimeTests'));assert.ok(command.includes('-parallel-testing-enabled NO'));assert.ok(command.includes('-jobs 2'));}
});
test('failed build reports five not-run attempts instead of a false test pass',async()=>{
 const r=await run('build-fail');assert.equal(r.status,65);assert.equal(r.commands.length,1);assert.match(r.stdout,/completed=0 not_run=5 reason=build-failed/);assert.equal(r.results.trim(),'attempt\texit_status');
});
test('stress workflow runs only on its own exact paths or explicit dispatch',async()=>{
 const text=await readFile(new URL('.github/workflows/native-runtime-stress.yml',root),'utf8');assert.match(text,/workflow_dispatch:/);assert.match(text,/cancel-in-progress: false/);assert.match(text,/github.event.repository.private == false/);assert.match(text,/timeout-minutes: 45/);
 const paths=text.slice(text.indexOf('    paths:'),text.indexOf('  workflow_dispatch:'));
 assert.equal((paths.match(/^      - /gm)||[]).length,2);assert.ok(paths.includes("'.github/workflows/native-runtime-stress.yml'"));assert.ok(paths.includes("'tools/ci/native-runtime-stress.sh'"));assert.doesNotMatch(paths,/\*|ios\/|BlindCore/);
});

for (const mode of ['missing-summary', 'zero-tests', 'skipped-tests']) {
 test(`all five attempts run but ${mode} cannot pass the diagnostic`, async()=>{
  const r=await run(mode);assert.equal(r.status,1);assert.equal(r.commands.length,6);assert.match(r.stdout,/completed=5 failed_attempts=0 diagnostic_errors=5/);
 });
}
