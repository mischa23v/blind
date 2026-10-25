import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile,mkdtemp,writeFile,mkdir,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {spawnSync} from 'node:child_process';
const root=new URL('../../',import.meta.url);
const swift=await readFile(new URL('ios/BlindAssistTests/CommunityTests.swift',root),'utf8');
const shell=await readFile(new URL('tools/ci/native-apple.sh',root),'utf8');
test('each adapter call has immediately preceding fixed observation; no gate',()=>{
 const lines=swift.split('\n');let count=0;
 for(let i=0;i<lines.length;i++)if(lines[i].includes('await LocalImageAssistant.converse(')){
  assert.match(lines[i-1],/^\s*recordModelAvailabilityBeforeAdapter\("[a-zA-Z.]+"\)$/);count++;
 }
 assert.equal(count,8);
 const helper=swift.slice(swift.indexOf('private func recordModelAvailabilityBeforeAdapter'),swift.indexOf('@Suite("Local conversation regression'));
 assert.match(helper,/SystemLanguageModel.default.availability/);
 for(const state of ['available','deviceNotEligible','appleIntelligenceNotEnabled','modelNotReady','unknownUnavailable','unknownAvailability','apiUnavailable','frameworkUnavailable'])assert.ok(helper.includes(`"${state}"`));
 assert.match(helper,/observation=before adapter invocation/);
 assert.doesNotMatch(helper,/localizedDescription|String\(describing:|dialogue|prompt|response|error|throw |#require|#expect/);
});
test('diagnostic extraction is bounded on success and failure and preserves status',async()=>{
 for(const status of [0,65]){
  const dir=await mkdtemp(join(tmpdir(),'model-availability-'));
  try{
   await mkdir(join(dir,'blind-native-ci'));await writeFile(join(dir,'blind-native-ci/simulator-id'),'synthetic-id');await mkdir(join(dir,'bin'));
   await writeFile(join(dir,'bin/xcodebuild'),`#!/bin/bash\nfor i in {1..100}; do echo 'MODEL_AVAILABILITY fixture=synthetic observation=before adapter invocation model=SystemLanguageModel.default state=available runtimeOS=27.0.0'; done\nexit ${status}\n`,{mode:0o755});
   const r=spawnSync('bash',['tools/ci/native-apple.sh','unit'],{cwd:root,env:{...process.env,PATH:join(dir,'bin')+':'+process.env.PATH,RUNNER_TEMP:dir},encoding:'utf8',timeout:5000});
   assert.equal(r.status,status);const excerpt=r.stdout.split('MODEL_AVAILABILITY_BEGIN')[1].split('MODEL_AVAILABILITY_END')[0];
   assert.equal((excerpt.match(/^MODEL_AVAILABILITY fixture=/gm)||[]).length,80);
  }finally{await rm(dir,{recursive:true,force:true});}
 }
});
test('host provenance is explicit and never a new gate or environment dump',()=>{
 assert.match(shell,/sw_vers -productVersion 2>\/dev\/null \|\| true/);
 assert.match(shell,/sw_vers -buildVersion 2>\/dev\/null \|\| true/);
 assert.match(shell,/\|\| host_version=unknown/);assert.match(shell,/\|\| host_build=unknown/);
 assert.doesNotMatch(shell,/printenv|system_profiler|ioreg/);
});
