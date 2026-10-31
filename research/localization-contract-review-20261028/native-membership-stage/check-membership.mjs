import {readFile,readdir,access} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
import {generateProject} from '../../../tools/generate-xcode-project.mjs';
const root=new URL('../../../',import.meta.url);
const read=p=>readFile(new URL(p,root),'utf8');
const before=await read('research/localization-contract-review-20261028/native-membership-stage/project-before.txt');
const after=await read('ios/BlindAssist.xcodeproj/project.pbxproj');
const names=(await readdir(new URL('ios/BlindAssist/',root))).filter(f=>f.endsWith('.swift')).sort();
assert.equal(names.length,62);assert.equal(after,generateProject(names));
const paths=s=>[...s.matchAll(/path = "?([^;"\n]+\.swift)"?;/g)].map(m=>m[1]).sort();
const a=paths(before),b=paths(after),added=b.filter(x=>!a.includes(x));
assert.deepEqual(added,['BlindAssist/RecordedRoomRoutePreview.swift','BlindAssistTests/ConnectedNavigationBenchIntegrationTests.swift','BlindAssistTests/KoivuSourceAnchorBenchFixture.swift']);
assert.deepEqual(a.filter(x=>!b.includes(x)),[]);
const stable=s=>s.split('\n').filter(l=>/XCLocalSwiftPackageReference|XCSwiftPackageProductDependency|PBXFrameworksBuildPhase|buildSettings =/.test(l));
assert.deepEqual(stable(after),stable(before));
for(const name of ['KoivuSourceAnchorBenchFixture.swift','ConnectedNavigationBenchIntegrationTests.swift']) {
 assert.equal(await read('ios/BlindAssistTests/'+name),await read('research/connected-navigation-bench-20261028/'+name));
 const id=createHash('sha256').update('unit-spatial-build:'+name).digest('hex').slice(0,24).toUpperCase();
 assert.ok(after.includes(id+' = { isa = PBXBuildFile;'));
 assert.ok(after.split('\n').some(l=>l.includes('PBXSourcesBuildPhase')&&l.includes(id+',')));
}
for(const p of added)await access(new URL('ios/'+p,root));
console.log(JSON.stringify({kind:'source-membership-only',nativeSwiftFiles:62,addedPaths:added,removedPaths:[],packagesAndFlagsUnchanged:true,hostedTestsMatchReviewedSources:true,exactGeneratorParity:true,nativeExecution:false,currentProjectSHA256:createHash('sha256').update(after).digest('hex')},null,2));
