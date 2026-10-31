// Graph/source checks only. No Apple compilation or endpoint correctness claim.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {generateProject} from '../../tools/generate-xcode-project.mjs';
const id=n=>createHash('sha256').update(n).digest('hex').slice(0,24).toUpperCase();
const list=(body,key)=>(body.match(new RegExp(`\\b${key} = \\(([^)]*)\\);`))?.[1]??'').split(',').filter(Boolean);
const name='SavedRoomStrictEndpointTests.swift';
function verify(source){
 const graph=new Map([...source.matchAll(/^([A-F0-9]{24}) = \{ (.*) \};$/gm)].map(([,k,v])=>[k,v]));
 const ref=id(`unit-spatial:${name}`),build=id(`unit-spatial-build:${name}`);
 assert.equal(graph.get(ref),`isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "BlindAssistTests/${name}"; sourceTree = SOURCE_ROOT;`);
 assert.equal(graph.get(build),`isa = PBXBuildFile; fileRef = ${ref};`);
 assert.equal(list(graph.get(id('unit-sources')),'files').filter(x=>x===build).length,1);
 assert.equal(list(graph.get(id('group')),'children').filter(x=>x===ref).length,1);
 for(const [key,value] of graph)if(value.startsWith('isa = PBXSourcesBuildPhase;')&&key!==id('unit-sources'))assert.ok(!list(value,'files').includes(build));
}
test('exact existing app inventory generates new hosted-only member',async()=>{
 const inventory=JSON.parse(await readFile(new URL('app-source-inventory.json',import.meta.url),'utf8'));
 const generated=generateProject(inventory);verify(generated);
 assert.equal(generated,await readFile(new URL('../../ios/BlindAssist.xcodeproj/project.pbxproj',import.meta.url),'utf8'));
});
test('missing membership and accidental app target mutations fail',()=>{
 const p=generateProject(['BlindAssistApp.swift']);verify(p);const build=id(`unit-spatial-build:${name}`);
 assert.throws(()=>verify(p.replace(`${build},`,'')));
 assert.throws(()=>verify(p.replace(`${id('sources')} = { isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (`,`${id('sources')} = { isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (${build},`)));
});
