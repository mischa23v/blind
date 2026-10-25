import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp, mkdir, cp, readFile, writeFile, rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join, dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {execFileSync} from 'node:child_process';
const here = dirname(fileURLToPath(import.meta.url));
async function fixture() {
  const root = await mkdtemp(join(tmpdir(),'voice-probe-static-'));
  await mkdir(join(root,'apple'));
  for (const name of ['generate-project.mjs','ActorTests.swift']) await cp(join(here,name),join(root,'apple',name));
  await cp(join(here,'../source'),join(root,'source'),{recursive:true});
  await cp(join(here,'../source-native-v2'),join(root,'source-native-v2'),{recursive:true});
  return root;
}
test('generator isolates enrollment in test target and leaves production default body intact', async () => {
  const root = await fixture();
  try {
    execFileSync(process.execPath,[join(root,'apple/generate-project.mjs'),join(root,'project')]);
    const original = await readFile(join(root,'source-native-v2/ProtectedVoiceEnrollmentStore.swift'),'utf8');
    const projected = await readFile(join(root,'project/ProtectedVoiceEnrollmentStore.swift'),'utf8');
    const stripped = projected.replace(/\n    #if VOICE_ENROLLMENT_TESTING\n[\s\S]*?    #endif\n/,'')
      .replace(/                #if VOICE_ENROLLMENT_TESTING\n[\s\S]*?                #endif\n/,'')
      .replace(/        #if VOICE_ENROLLMENT_TESTING\n[\s\S]*?        #endif\n/,'');
    assert.equal(stripped, original);
    assert.equal(await readFile(join(root,'project/VoiceEnrollment.swift'),'utf8'), await readFile(join(root,'source/VoiceEnrollment.swift'),'utf8'));
    assert.doesNotMatch(await readFile(join(root,'project/Host.swift'),'utf8'),/Enrollment|VoiceAuthority|Microphone|AVAudio/);
    assert.match(await readFile(join(root,'project/Host.swift'),'utf8'),/some Scene[\s\S]*WindowGroup/);
    const pbx = await readFile(join(root,'project/VoiceProbe.xcodeproj/project.pbxproj'),'utf8');
    assert.equal((pbx.match(/VOICE_ENROLLMENT_TESTING/g)||[]).length,1);
    assert.match(pbx,/INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES/);
    assert.doesNotMatch(pbx,/BlindAssist\.app|XCLocalSwiftPackage|\.mlmodel|BLIND_/);
    const sources = [...pbx.matchAll(/isa = PBXSourcesBuildPhase;[^\n]*files = \(([^)]*)\)/g)].map(m=>m[1].split(',').filter(Boolean).length);
    assert.deepEqual(sources,[1,3]);
    assert.equal((await readFile(join(root,'project/ActorTests.swift'),'utf8')).match(/func test\w+\(/g).length,3);
  } finally { await rm(root,{recursive:true,force:true}); }
});
test('changed reviewed source refuses projection before output creation', async () => {
  const root = await fixture();
  try {
    await writeFile(join(root,'source/VoiceEnrollment.swift'),'// not the reviewed input\n');
    assert.throws(()=>execFileSync(process.execPath,[join(root,'apple/generate-project.mjs'),join(root,'project')],{stdio:'pipe'}),/Reviewed source hash mismatch/);
  } finally { await rm(root,{recursive:true,force:true}); }
});
test('generator refuses reuse of an existing project directory', async () => {
  const root = await fixture();
  try {
    await mkdir(join(root,'project'));
    assert.throws(()=>execFileSync(process.execPath,[join(root,'apple/generate-project.mjs'),join(root,'project')],{stdio:'pipe'}),/EEXIST/);
  } finally { await rm(root,{recursive:true,force:true}); }
});
test('execution scripts retain Apple gate, bounded concurrency and exact no-skip results', async () => {
  const typecheck = await readFile(join(here,'typecheck.sh'),'utf8');
  const actor = await readFile(join(here,'actor-tests.sh'),'utf8');
  assert.match(typecheck,/uname -s.*Darwin/);
  assert.match(typecheck,/-target arm64-apple-ios17\.0/);
  assert.match(actor,/bash "\$HERE\/typecheck\.sh"/);
  assert.match(actor,/-parallel-testing-enabled NO/);
  assert.match(actor,/-maximum-concurrent-test-simulator-destinations 1/);
  assert.match(actor,/!= \(3, 3, 0, 0\)/);
  assert.match(actor,/simctl create/);
  assert.doesNotMatch(actor,/simctl (erase|shutdown all|delete all)|downloadPlatform/);
});
