// Source graph and exact canonical serialization only; no Xcode/Swift execution.
import {readFile,mkdtemp,writeFile,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {pathToFileURL} from 'node:url';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {generateProject} from '../../tools/generate-xcode-project.mjs';
const home=new URL('./',import.meta.url),root=new URL('../../',home);
const id=n=>createHash('sha256').update(n).digest('hex').slice(0,24).toUpperCase();
const list=(body,key)=>(body.match(new RegExp(`\\b${key} = \\(([^)]*)\\);`))?.[1]??'').split(',').filter(Boolean);
const inventory=JSON.parse(await readFile(new URL('verified-app-inventory.json',home),'utf8'));
const names=inventory.files.map(x=>x.name).sort();
assert.equal(names.length,65);assert.equal(new Set(names).size,65);
const before=await readFile(new URL('project.pbxproj.before',home),'utf8');
const current=await readFile(new URL('ios/BlindAssist.xcodeproj/project.pbxproj',root),'utf8');
const scratch=await mkdtemp(join(tmpdir(),'classification-before-generator-'));
try {
 const file=join(scratch,'generator.mjs');
 await writeFile(file,await readFile(new URL('generate-xcode-project.mjs.before',home)));
 const old=await import(pathToFileURL(file).href);
 assert.equal(old.generateProject(names),before);
} finally {await rm(scratch,{recursive:true,force:true});}
assert.equal(generateProject(names),current);
function graph(text){return new Map([...text.matchAll(/^([A-F0-9]{24}) = \{ (.*) \};$/gm)].map(([,k,v])=>[k,v]));}
function verify(text){
 const g=graph(text),unit=g.get(id('unit-target')),app=g.get(id('target'));
 for(const [product,build,pkg,name] of [['unit-mesh-ingress','unit-mesh-ingress-build','stage85package','MeshCandidateIngress83'],['unit-mesh-snapshot','unit-mesh-snapshot-build','mesh-snapshot-package','MeshSnapshot82']]){
  assert.equal(g.get(id(product)),`isa = XCSwiftPackageProductDependency; package = ${id(pkg)}; productName = ${name};`);
  assert.equal(g.get(id(build)),`isa = PBXBuildFile; productRef = ${id(product)};`);
  assert.ok(list(unit,'packageProductDependencies').includes(id(product)));
  assert.ok(list(g.get(id('unit-frameworks')),'files').includes(id(build)));
  assert.ok(list(g.get(id('project')),'packageReferences').includes(id(pkg)));
  assert.ok(!list(app,'packageProductDependencies').includes(id(product)));
 }
 assert.equal(g.get(id('mesh-snapshot-package')),'isa = XCLocalSwiftPackageReference; relativePath = "../research/arkit-mesh-adapter-82";');
 const ref=id('unit-spatial:ClassificationIngressTests.swift'),build=id('unit-spatial-build:ClassificationIngressTests.swift');
 assert.equal(g.get(ref),'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "BlindAssistTests/ClassificationIngressTests.swift"; sourceTree = SOURCE_ROOT;');
 assert.equal(g.get(build),`isa = PBXBuildFile; fileRef = ${ref};`);
 assert.ok(list(g.get(id('unit-sources')),'files').includes(build));
 assert.ok(list(g.get(id('group')),'children').includes(ref));
 assert.ok(!list(g.get(id('sources')),'files').includes(build));
 assert.ok(!text.includes('BLIND_MESH_CANDIDATE_DIAGNOSTICS'));
}
verify(current);verify(generateProject(['BlindAssistApp.swift']));
const oldGraph=graph(before),newGraph=graph(current);
for(const name of ['sources','frameworks','target']){
 assert.ok(oldGraph.has(id(name)));assert.ok(newGraph.has(id(name)));
 assert.equal(newGraph.get(id(name)),oldGraph.get(id(name)),`unchanged app ${name}`);
}
for(const key of oldGraph.keys())if(oldGraph.get(key).startsWith('isa = XCBuildConfiguration;'))assert.equal(newGraph.get(key),oldGraph.get(key));
let mutations=0;
for(const key of ['unit-mesh-ingress','unit-mesh-snapshot','unit-mesh-ingress-build','unit-mesh-snapshot-build','mesh-snapshot-package','unit-spatial-build:ClassificationIngressTests.swift']){
 const broken=current.replace(`${id(key)},`,'');assert.notEqual(broken,current);assert.throws(()=>verify(broken));mutations++;
}
console.log(JSON.stringify({kind:'project_source_graph_only',beforeAndAfterCanonicalEquality:true,verifiedRemoteAppFiles:65,appBuildGraphUnchanged:true,newHostedTestOnly:true,explicitHostedProducts:['MeshCandidateIngress83','MeshSnapshot82'],mutationsRejected:mutations,swiftCompiled:false,nativeTestsExecuted:false}));
