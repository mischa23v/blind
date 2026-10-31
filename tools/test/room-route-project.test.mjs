// Graph/source checks only; no Apple build, package resolution or routing execution.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile,readdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {generateProject} from '../generate-xcode-project.mjs';
const id=n=>createHash('sha256').update(n).digest('hex').slice(0,24).toUpperCase();
const list=(body,key)=>(body.match(new RegExp(`\\b${key} = \\(([^)]*)\\);`))?.[1]??'').split(',').filter(Boolean);
const tests=['ClassifiedRoomMeshTests.swift','SavedRoomRouteMeshAppleFixtureTests.swift','SavedRoomRouteCollisionOracle.swift','SavedRoomRouteCollisionOracleTests.swift','SavedRoomRouteDiagnosticAppleTests.swift','SavedRoomRouteJourneyAppleTests.swift'];
function verify(source){
 const g=new Map([...source.matchAll(/^([A-F0-9]{24}) = \{ (.*) \};$/gm)].map(([,k,v])=>[k,v]));
 assert.equal(g.get(id('room-mesh-package')),'isa = XCLocalSwiftPackageReference; relativePath = "../research/room-mesh-package-75/BlindRoomMesh";');
 assert.ok(list(g.get(id('project')),'packageReferences').includes(id('room-mesh-package')));
 for(const [target,product,build,phase] of [['target','room-mesh-product','room-mesh-library','frameworks'],['unit-target','unit-room-mesh','unit-room-mesh-build','unit-frameworks']]){
  assert.equal(g.get(id(product)),`isa = XCSwiftPackageProductDependency; package = ${id('room-mesh-package')}; productName = BlindRoomMesh;`);
  assert.equal(g.get(id(build)),`isa = PBXBuildFile; productRef = ${id(product)};`);
  assert.ok(list(g.get(id(target)),'packageProductDependencies').includes(id(product)));
  assert.ok(list(g.get(id(target)),'buildPhases').includes(id(phase)));
  assert.ok(list(g.get(id(phase)),'files').includes(id(build)));
 }
 const folder=id('unit-route-fixtures'),build=id('unit-route-fixtures-build'),phase=id('unit-resources');
 assert.equal(g.get(folder),'isa = PBXFileReference; lastKnownFileType = folder; path = "BlindAssistTests/Fixtures/RoomRouteDiagnostic"; sourceTree = SOURCE_ROOT;');
 assert.equal(g.get(build),`isa = PBXBuildFile; fileRef = ${folder};`);
 assert.ok(list(g.get(id('group')),'children').includes(folder));
 assert.deepEqual(list(g.get(phase),'files'),[id('unit-roomplan-fixtures-build'),build]);
 assert.ok(list(g.get(id('unit-target')),'buildPhases').includes(phase));
 for(const name of tests){
  const ref=id(`unit-spatial:${name}`),b=id(`unit-spatial-build:${name}`);
  assert.equal(g.get(ref),`isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "BlindAssistTests/${name}"; sourceTree = SOURCE_ROOT;`);
  assert.equal(g.get(b),`isa = PBXBuildFile; fileRef = ${ref};`);
  assert.ok(list(g.get(id('unit-sources')),'files').includes(b));
  assert.ok(!list(g.get(id('sources')),'files').includes(b));
 }
 for(const [k,v] of g){
  if(v.startsWith('isa = PBXNativeTarget;')&&k!==id('unit-target'))assert.ok(!list(v,'buildPhases').includes(phase));
  if((v.startsWith('isa = PBXResourcesBuildPhase;')||v.startsWith('isa = PBXSourcesBuildPhase;'))&&k!==phase)assert.ok(!list(v,'files').includes(build));
  if(v.startsWith('isa = PBXBuildFile;')&&v.includes(`fileRef = ${folder};`))assert.equal(k,build);
 }
}
test('canonical project binds existing local room mesh to app/tests and protocols only to hosted tests',async()=>{
 const files=(await readdir(new URL('../../ios/BlindAssist/',import.meta.url))).filter(x=>x.endsWith('.swift')).sort();
 const p=generateProject(files);verify(p);
 assert.equal(p,await readFile(new URL('../../ios/BlindAssist.xcodeproj/project.pbxproj',import.meta.url),'utf8'));
 assert.deepEqual((await readdir(new URL('../../ios/BlindAssistTests/Fixtures/RoomRouteDiagnostic/',import.meta.url))).sort(),['JOURNEY_ADDENDUM.json','PROFILE_28CM_ADDENDUM.json','PROTOCOL.json']);
});
test('missing linkage, test source, resource and app embedding mutations are rejected',()=>{
 const p=generateProject(['BlindAssistApp.swift']);verify(p);
 for(const name of ['room-mesh-library','unit-room-mesh-build','unit-spatial-build:SavedRoomRouteJourneyAppleTests.swift','unit-route-fixtures-build']){
  const broken=p.replace(`${id(name)},`,'');assert.notEqual(p,broken);assert.throws(()=>verify(broken));
 }
 const broken=p.replace(`buildPhases = (${id('sources')},`,`buildPhases = (${id('unit-resources')},${id('sources')},`);assert.throws(()=>verify(broken));
});
