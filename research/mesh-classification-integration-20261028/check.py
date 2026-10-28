#!/usr/bin/env python3
"""Current bounded adoption source proof, not Swift/native or the complete85 gate."""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

H=Path(__file__).resolve().parent
R=H.parents[1]
I=R/'research/native-candidate-app-integration-85/integrated'
P=R/'research/mesh-classification-ingress-proposal-20261028'
checks=[]
def check(name,value):
    assert value,name
    checks.append(name)
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
proposal=json.loads((P/'MANIFEST.json').read_text())
check('frozen proposal manifest',sha(P/'MANIFEST.json')=='8d1cc7307a945e46459946aafe1aa208ef231c7f8dc7894c16a2d9b627051a12')
check('all frozen proposal bytes preserved',all(sha(R/f['path'])==f['sha256'] for f in proposal['files']))
check('actual83 source equals reviewed proposal',(R/'research/mesh-candidate-ingress-83/Sources/MeshCandidateIngress.swift').read_bytes()==(P/'candidate/MeshCandidateIngress.swift').read_bytes())
check('actual hosted tests equal reviewed fixtures',(R/'ios/BlindAssistTests/ClassificationIngressTests.swift').read_bytes()==(P/'Tests/ClassificationIngressTests.swift').read_bytes())
sourcepins=json.loads((R/'research/mesh-candidate-ingress-83/SOURCE_PINS.json').read_text())
check('actual83 source pin',sourcepins['research/mesh-candidate-ingress-83/Sources/MeshCandidateIngress.swift']==sha(R/'research/mesh-candidate-ingress-83/Sources/MeshCandidateIngress.swift'))
proposedpins=json.loads((P/'candidate/SOURCE_PINS.json').read_text())
# Separately coordinated75 pin repair may change only this nested manifest hash.
allow='research/room-mesh-package-75/APPLE_SOURCE_PINS.json'
check('unrelated83 pin entries preserved',{k:v for k,v in sourcepins.items() if k!=allow}=={k:v for k,v in proposedpins.items() if k!=allow})
if (R/allow).exists(): check('coordinated75 manifest reference',sourcepins[allow]==sha(R/allow))
check('default off bench remains byte frozen',sha(R/'research/live-mesh-bench-proposal-20261028/MANIFEST.json')=='4b29e3f5c70ba743c2bbb21c99aa36ddfbb7b14a917129e93d3a608520cf53a7')
check('workflow byte unchanged',sha(R/'.github/workflows/native-apple.yml')=='ba74cd55736aa76248b885cf3c2454ba7ce2d082b0f7f040cd87ad8389e37a8e')
check('timing helper byte unchanged',sha(R/'tools/ci/native-apple.sh')=='c6c51f72b00004b17aba1ef20b5a4314c5062847cddfa7a377cba41060b093c4')
current=(I/'check.py').read_text()
insert="""    subprocess.run(['git', 'apply', '-R', str(H / 'classification-ingress-membership.patch')], cwd=root,
                   check=True, timeout=15, capture_output=True)
    for name, digest in manifest['beforeClassificationIngressMembership'].items():
        check('exact pre-classification-ingress project recovered ' + name, hashlib.sha256((root / name).read_bytes()).hexdigest() == digest)
"""
check('membership inverse first',current.index("H / 'classification-ingress-membership.patch'") < current.index("H / 'apple-room-route-membership.patch'"))
check('entire prior cumulative checker preserved',current.replace(insert,'').replace('appleRoomRouteMembershipApplied=True, classificationIngressMembershipApplied=True,','appleRoomRouteMembershipApplied=True,')==(H/'integrated-check.py.before').read_text())
base=json.loads((H/'integrated-SOURCE_PINS.json.before').read_text())
next=json.loads((I/'SOURCE_PINS.json').read_text())
check('all prior inverse metadata preserved',{k:v for k,v in next.items() if k not in ['integrated','beforeClassificationIngressMembership']}=={k:v for k,v in base.items() if k!='integrated'})
changed={'ios/BlindAssist.xcodeproj/project.pbxproj','tools/generate-xcode-project.mjs','research/native-candidate-app-integration-85/integrated/check.py','research/native-candidate-app-integration-85/integrated/classification-ingress-membership.patch','research/mesh-candidate-ingress-83/Sources/MeshCandidateIngress.swift','research/mesh-candidate-ingress-83/SOURCE_PINS.json','ios/BlindAssistTests/ClassificationIngressTests.swift'}
check('only intended integrated pins changed',{k:v for k,v in next['integrated'].items() if k not in changed}=={k:v for k,v in base['integrated'].items() if k not in changed})
check('all adoption integrated pins exact',all(next['integrated'][name]==sha(R/name) for name in changed))
check('membership before pin exact',next['beforeClassificationIngressMembership']=={'ios/BlindAssist.xcodeproj/project.pbxproj':sha(H/'project.pbxproj.before')})
with tempfile.TemporaryDirectory(prefix='classified-adoption-inverse-') as temp:
    root=Path(temp)
    for name in ['ios/BlindAssist.xcodeproj/project.pbxproj','tools/generate-xcode-project.mjs']:
        target=root/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes((R/name).read_bytes())
    subprocess.run(['git','apply','-R',str(I/'classification-ingress-membership.patch')],cwd=root,check=True,capture_output=True)
    check('project inverse recovers exact928 baseline',(root/'ios/BlindAssist.xcodeproj/project.pbxproj').read_bytes()==(H/'project.pbxproj.before').read_bytes())
    subprocess.run(['git','apply','-R',str(H/'generator-membership.patch')],cwd=root,check=True,capture_output=True)
    check('generator inverse recovers exact928 baseline',(root/'tools/generate-xcode-project.mjs').read_bytes()==(H/'generate-xcode-project.mjs.before').read_bytes())
    subprocess.run(['git','apply',str(I/'classification-ingress-membership.patch')],cwd=root,check=True,capture_output=True)
    subprocess.run(['git','apply',str(H/'generator-membership.patch')],cwd=root,check=True,capture_output=True)
    check('forward source replay exact',all((root/name).read_bytes()==(R/name).read_bytes() for name in ['ios/BlindAssist.xcodeproj/project.pbxproj','tools/generate-xcode-project.mjs']))
project=json.loads(subprocess.check_output(['node',str(H/'project-check.mjs')],cwd=R,text=True))
check('remote-inventory canonical project and mutations',project['beforeAndAfterCanonicalEquality'] and project['verifiedRemoteAppFiles']==65 and project['mutationsRejected']==6)
missing=[name for name in next['integrated'] if not (R/name).exists()]
app_count=len(list((R/'ios/BlindAssist').glob('*.swift')))
cumulative=None
if not missing:
    cumulative=json.loads(subprocess.check_output(['python3',str(I/'check.py')],cwd=R,text=True))
    check('cumulative85 checker executed without bypass',cumulative['sourceChecksPassed']>=67)
    (H/'INTEGRATED85_RESULT.json').write_text(json.dumps(cumulative,indent=2)+'\n')
result=dict(kind='adoption_source_and_inverse_only',passed=len(checks),checks=checks,project=project,
            cumulative85SourceChecksPassed=None if cumulative is None else cumulative['sourceChecksPassed'],
            materializedAppSwiftCount=app_count,expectedRemoteAppSwiftCount=65,wholeAppDirectoryScanComplete=app_count==65,
            fullIntegrated85Gate='blocked_missing_pinned_inputs' if missing else 'source_checker_executed_with_explicit_app_inventory_limit',missingPinnedInputs=missing,
            swiftCompiled=False,swiftTestsExecuted=False,cameraActivated=False,physicalAuthority=False)
(H/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
