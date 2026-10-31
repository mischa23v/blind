#!/usr/bin/env python3
"""Source dependency/inverse proof only; an Apple rerun must establish real linking."""
import hashlib,json,subprocess,tempfile
from pathlib import Path
H=Path(__file__).resolve().parent
R=H.parents[1]
I=R/'research/native-candidate-app-integration-85/integrated'
checks=[]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def check(name,value):
    assert value,name
    checks.append(name)
check('all nine classification fixtures byte unchanged',sha(R/'ios/BlindAssistTests/ClassificationIngressTests.swift')=='5acab13703280db80c7faba48d82927baabf6fa1d78f3103ed2ce4f14435f8bb')
check('83 source byte unchanged',sha(R/'research/mesh-candidate-ingress-83/Sources/MeshCandidateIngress.swift')=='733a7bdcc4a8da7ff4fc95c087b690e369ca03c79adcc729e277934d708b53b1')
check('latest workflow byte unchanged',sha(R/'.github/workflows/native-apple.yml')=='d5d9d483e138803d4c952976fe0bfa531946f8f0ebffe198abb0d08a9d3b799b')
check('native helper byte unchanged',sha(R/'tools/ci/native-apple.sh')=='c6c51f72b00004b17aba1ef20b5a4314c5062847cddfa7a377cba41060b093c4')
check('exact latest parent pins snapshot',sha(H/'integrated-SOURCE_PINS.json.before')=='a65951fece8fc480feac441138a80dfc782a8d813880c3db0b8d10892e4c152e')
insert="""    subprocess.run(['git', 'apply', '-R', str(H / 'hosted-decoder-link-membership.patch')], cwd=root,
                   check=True, timeout=15, capture_output=True)
    for name, digest in manifest['beforeHostedDecoderLinkMembership'].items():
        check('exact pre-hosted-decoder-link project recovered ' + name, hashlib.sha256((root / name).read_bytes()).hexdigest() == digest)
"""
s=(I/'check.py').read_text()
check('new inverse before classification inverse',s.index("H / 'hosted-decoder-link-membership.patch'")<s.index("H / 'classification-ingress-membership.patch'"))
check('entire previous checker preserved',s.replace(insert,'').replace('classificationIngressMembershipApplied=True, hostedDecoderLinkMembershipApplied=True,','classificationIngressMembershipApplied=True,')==(H/'integrated-check.py.before').read_text())
a=json.loads((H/'integrated-SOURCE_PINS.json.before').read_text());b=json.loads((I/'SOURCE_PINS.json').read_text())
check('all prior inverse metadata preserved',{k:v for k,v in a.items() if k!='integrated'}=={k:v for k,v in b.items() if k not in ['integrated','beforeHostedDecoderLinkMembership']})
changed={'tools/generate-xcode-project.mjs','ios/BlindAssist.xcodeproj/project.pbxproj','research/native-candidate-app-integration-85/integrated/check.py','research/native-candidate-app-integration-85/integrated/hosted-decoder-link-membership.patch','tools/test/hosted-mesh-decoder-link.test.mjs'}
check('only narrow intended pins change',{k:v for k,v in a['integrated'].items() if k not in changed}=={k:v for k,v in b['integrated'].items() if k not in changed})
check('all changed pins exact',all(b['integrated'][p]==sha(R/p) for p in changed))
check('exact prior project pin',b['beforeHostedDecoderLinkMembership']=={'ios/BlindAssist.xcodeproj/project.pbxproj':sha(H/'project.pbxproj.before')})
with tempfile.TemporaryDirectory(prefix='hosted81-inverse-') as tmp:
    root=Path(tmp)
    for target,before,patch in [('ios/BlindAssist.xcodeproj/project.pbxproj','project.pbxproj.before',I/'hosted-decoder-link-membership.patch'),('tools/generate-xcode-project.mjs','generator.before.mjs',H/'generator-link.patch')]:
        p=root/target;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes((R/target).read_bytes())
        subprocess.run(['git','apply','-R',str(patch)],cwd=root,check=True,capture_output=True)
        check('exact inverse '+target,p.read_bytes()==(H/before).read_bytes())
        subprocess.run(['git','apply',str(patch)],cwd=root,check=True,capture_output=True)
        check('exact forward '+target,p.read_bytes()==(R/target).read_bytes())
node="""
import {readFile} from 'node:fs/promises';import assert from 'node:assert/strict';import {createHash} from 'node:crypto';
import {generateProject as current} from './tools/generate-xcode-project.mjs';
import {generateProject as before} from './research/hosted-mesh-decoder-link-20261028/generator.before.mjs';
const h='research/hosted-mesh-decoder-link-20261028/';const names=JSON.parse(await readFile(h+'verified-app-inventory.json','utf8')).files.map(x=>x.name).sort();assert.equal(names.length,65);
const old=await readFile(h+'project.pbxproj.before','utf8'),now=await readFile('ios/BlindAssist.xcodeproj/project.pbxproj','utf8');assert.equal(before(names),old);assert.equal(current(names),now);
const graph=s=>new Map([...s.matchAll(/^([A-F0-9]{24}) = \\{ (.*) \\};$/gm)].map(([,k,v])=>[k,v]));const a=graph(old),b=graph(now),id=n=>createHash('sha256').update(n).digest('hex').slice(0,24).toUpperCase();
for(const name of ['target','sources','frameworks','unit-sources']){assert.ok(a.has(id(name)));assert.equal(a.get(id(name)),b.get(id(name)));}
for(const [key,value] of a)if(value.startsWith('isa = XCBuildConfiguration;'))assert.equal(value,b.get(key));
console.log(JSON.stringify({canonicalBeforeAndAfter:true,remoteAppFiles:65,appAndTestSourcesUnchanged:true,appLinkageAndAllBuildSettingsUnchanged:true}));
"""
project=json.loads(subprocess.check_output(['node','--input-type=module','-'],input=node,cwd=R,text=True))
check('canonical65 inventory and unchanged app/test source graph',project['canonicalBeforeAndAfter'] and project['appAndTestSourcesUnchanged'])
tap=subprocess.check_output(['node','--test','--test-reporter=tap','tools/test/hosted-mesh-decoder-link.test.mjs'],cwd=R,text=True)
(H/'regression.tap').write_text(tap)
check('three graph/symbol regression tests pass','# pass 3' in tap and '# fail 0' in tap)
cumulative=json.loads(subprocess.check_output(['python3',str(I/'check.py')],cwd=R,text=True))
(H/'integrated-result.json').write_text(json.dumps(cumulative,indent=2)+'\n')
check('cumulative70 source checks pass',cumulative['sourceChecksPassed']==70)
result=dict(kind='source_graph_and_inverse_only',passed=len(checks),checks=checks,project=project,regressionTestsPassed=3,cumulativeSourceChecks=70,localAppSwiftFiles=len(list((R/'ios/BlindAssist').glob('*.swift'))),appleLinkVerified=False,hostedTestsExecutedAfterFix=False,workflowChanged=False,physicalAuthority=False)
(H/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
