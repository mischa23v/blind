// Project-source graph checks only. Does not execute Xcode resource copying/RoomPlan.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile,readdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {generateProject} from '../generate-xcode-project.mjs';
const id=n=>createHash('sha256').update(n).digest('hex').slice(0,24).toUpperCase();
const list=(body,key)=>(body.match(new RegExp(`\\b${key} = \\(([^)]*)\\);`))?.[1]??'').split(',').filter(Boolean);
function verify(project) {
 const graph=new Map([...project.matchAll(/^([A-F0-9]{24}) = \{ (.*) \};$/gm)].map(([,key,body])=>[key,body]));
 const folder=id('unit-roomplan-fixtures'),build=id('unit-roomplan-fixtures-build'),phase=id('unit-resources');
 assert.equal(graph.get(folder),'isa = PBXFileReference; lastKnownFileType = folder; path = "BlindAssistTests/Fixtures/RoomPlanApple"; sourceTree = SOURCE_ROOT;');
 assert.equal(graph.get(build),`isa = PBXBuildFile; fileRef = ${folder};`);
 assert.ok(graph.get(phase).startsWith('isa = PBXResourcesBuildPhase;'));
 assert.deepEqual(list(graph.get(phase),'files'),[build,id('unit-route-fixtures-build')]);
 assert.ok(list(graph.get(id('unit-target')),'buildPhases').includes(phase));
 assert.ok(list(graph.get(id('group')),'children').includes(folder));
 const testBuild=id('unit-spatial-build:SavedRoomDiagnosticGeometryAppleFixtureTests.swift');
 assert.ok(list(graph.get(id('unit-sources')),'files').includes(testBuild));
 assert.equal(graph.get(testBuild),`isa = PBXBuildFile; fileRef = ${id('unit-spatial:SavedRoomDiagnosticGeometryAppleFixtureTests.swift')};`);
 for(const [key,body] of graph) {
  if(body.startsWith('isa = PBXNativeTarget;')&&key!==id('unit-target'))assert.ok(!list(body,'buildPhases').includes(phase));
  if((body.startsWith('isa = PBXResourcesBuildPhase;')||body.startsWith('isa = PBXSourcesBuildPhase;'))&&key!==phase)assert.ok(!list(body,'files').includes(build));
  if(body.startsWith('isa = PBXBuildFile;')&&body.includes(`fileRef = ${folder};`))assert.equal(key,build);
 }
}
test('RoomPlan folder and test belong only to hosted test resource/source phases',async()=>{
 const files=(await readdir(new URL('../../ios/BlindAssist/',import.meta.url))).filter(x=>x.endsWith('.swift')).sort();
 const generated=generateProject(files);verify(generated);
 assert.equal(generated,await readFile(new URL('../../ios/BlindAssist.xcodeproj/project.pbxproj',import.meta.url),'utf8'));
});
test('fixture resource checks reject missing membership and app embedding',()=>{
 const source=generateProject(['BlindAssistApp.swift']);verify(source);
 const phase=id('unit-resources'),build=id('unit-roomplan-fixtures-build');
 for(const changed of [source.replace(`${phase},); buildRules`,'); buildRules'),source.replace(`files = (${build},${id('unit-route-fixtures-build')},);`,'files = ();'),source.replace(`buildPhases = (${id('sources')},`,`buildPhases = (${phase},${id('sources')},`),source.replace(`files = (); runOnlyForDeploymentPostprocessing = 0;`,`files = (${build},); runOnlyForDeploymentPostprocessing = 0;`)]) {
  assert.notEqual(changed,source);assert.throws(()=>verify(changed));
 }
});
test('test-only folder has exactly original fixtures, license and provenance metadata',async()=>{
 const root=new URL('../../ios/BlindAssistTests/Fixtures/RoomPlanApple/',import.meta.url);
 assert.deepEqual((await readdir(root)).sort(),['APPLE-LICENSE.txt','Bedroom3.capturedRoom.json','Hallway2.capturedRoom.json','README.md','manifest.json']);
 const fixture=await readFile(new URL('../../ios/BlindAssistTests/SavedRoomDiagnosticGeometryAppleFixtureTests.swift',import.meta.url),'utf8');
 assert.match(fixture,/Bundle\(for: Self.self\)/);assert.match(fixture,/subdirectory: "RoomPlanApple"/);
});
