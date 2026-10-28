// Source graph/symbol ownership regression only, NOT an Apple linker execution.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {generateProject} from '../generate-xcode-project.mjs';
const id=n=>createHash('sha256').update(n).digest('hex').slice(0,24).toUpperCase();
const list=(body,key)=>(body.match(new RegExp(`\\b${key} = \\(([^)]*)\\);`))?.[1]??'').split(',').filter(Boolean);
function verify(source){
 const g=new Map([...source.matchAll(/^([A-F0-9]{24}) = \{ (.*) \};$/gm)].map(([,k,v])=>[k,v]));
 const pkg=id('mesh-decoder-package'),product=id('unit-mesh-decoder'),build=id('unit-mesh-decoder-build');
 assert.equal(g.get(pkg),'isa = XCLocalSwiftPackageReference; relativePath = "../research/native-mesh-decoder-81";');
 assert.equal(g.get(product),`isa = XCSwiftPackageProductDependency; package = ${pkg}; productName = MeshBufferDecoder81;`);
 assert.equal(g.get(build),`isa = PBXBuildFile; productRef = ${product};`);
 assert.ok(list(g.get(id('project')),'packageReferences').includes(pkg));
 assert.ok(list(g.get(id('unit-target')),'packageProductDependencies').includes(product));
 assert.ok(list(g.get(id('unit-frameworks')),'files').includes(build));
 assert.ok(list(g.get(id('unit-target')),'buildPhases').includes(id('unit-frameworks')));
 assert.ok(!list(g.get(id('target')),'packageProductDependencies').includes(product));
 assert.ok(!list(g.get(id('frameworks')),'files').includes(build));
 for(const [p,b] of [['unit-mesh-ingress','unit-mesh-ingress-build'],['unit-mesh-snapshot','unit-mesh-snapshot-build']]){
  assert.ok(list(g.get(id('unit-target')),'packageProductDependencies').includes(id(p)));
  assert.ok(list(g.get(id('unit-frameworks')),'files').includes(id(b)));
 }
 assert.ok(list(g.get(id('unit-sources')),'files').includes(id('unit-spatial-build:ClassificationIngressTests.swift')));
}
test('hosted target directly links decoder81 alongside unchanged82/83 and classification tests',async()=>{
 verify(generateProject(['BlindAssistApp.swift']));
 verify(await readFile(new URL('../../ios/BlindAssist.xcodeproj/project.pbxproj',import.meta.url),'utf8'));
});
test('missing package, product, framework or wrong product mutations are rejected',()=>{
 const p=generateProject(['BlindAssistApp.swift']);
 for(const key of ['mesh-decoder-package','unit-mesh-decoder','unit-mesh-decoder-build']){
  const broken=p.replace(`${id(key)},`,'');assert.notEqual(p,broken);assert.throws(()=>verify(broken));
 }
 assert.throws(()=>verify(p.replace('productName = MeshBufferDecoder81;','productName = WrongDecoder;')));
});
test('known missing symbols are reachable through82 public types and default argument used by fixtures',async()=>{
 const [snapshot,decoder,fixtures,packageSource]=await Promise.all([
  'research/arkit-mesh-adapter-82/Sources/MeshSnapshot.swift',
  'research/native-mesh-decoder-81/Sources/MeshBufferDecoder.swift',
  'ios/BlindAssistTests/ClassificationIngressTests.swift',
  'research/native-mesh-decoder-81/Package.swift'
 ].map(p=>readFile(new URL('../../'+p,import.meta.url),'utf8')));
 assert.ok(snapshot.includes('mesh: MeshBufferDecoder.ValidatedRevision'));
 assert.ok(snapshot.includes('limits: MeshBufferDecoder.Limits = .init()'));
 assert.ok(decoder.includes('public enum ClassificationDiagnostic'));
 assert.ok(decoder.includes('public let classificationDiagnostics: [ClassificationDiagnostic]'));
 assert.ok(decoder.includes('public init(vertices: Int = 200_000, faces: Int = 100_000'));
 for(const marker of ['MeshSnapshot82.preflight(', 'MeshSnapshot82.decode(', 'mesh.classificationDiagnostics'])assert.ok(fixtures.includes(marker));
 assert.ok(packageSource.includes('.library(name: "MeshBufferDecoder81", targets: ["MeshBufferDecoder81"])'));
});
