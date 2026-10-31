#!/usr/bin/env python3
"""Read-only consistency check of retained public evidence; never reruns native code."""
import hashlib,json,pathlib,sys
P=pathlib.Path(__file__).resolve().parent
if sys.flags.optimize: raise RuntimeError('Run without optimization')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def require(ok,msg):
 if not ok: raise ValueError(msg)
manifest=json.loads((P/'MANIFEST.json').read_text())
for name,h in manifest['files'].items():
 rel=pathlib.PurePosixPath(name);require(not rel.is_absolute() and '..' not in rel.parts,'Unsafe file path')
 require(sha(P/name)==h,'Evidence file changed: '+name)
e=json.loads((P/'TERMINAL_EVIDENCE.json').read_text());s=json.loads((P/'PROTOCOL_SCOPE.json').read_text())
require(e['runId']==41011080206 and e['conclusion']=='success','Wrong terminal run')
require(e['workflowCommit']=='e418290ac2a70f93c4250bb094091082408f7093','Wrong workflow commit')
v=e['provenance'];require(v['actualWorkflowCommit']==e['workflowCommit'] and v['historicalProtocolCommit']=='5a6ad0ad5c64879a9e95bae9212054ab9daf950d','Source identity mismatch')
require(v['historicalInputCount']==58 and v['checkoutMatchedInputCount']==55 and v['historicalOverrideCount']==3 and v['allHistoricalInputsVerified'],'Historical inventory mismatch')
require(e['artifacts']==[] and e['artifactUploadStep']=='skipped','Storage evidence changed')
require(not e['fullResultBytesRetrieved'] and not e['fullReceiptBytesRetrieved'],'Do not claim unavailable full receipt retrieval')
receipts={r['path']:r for r in e['receipts']};receipt=receipts['blind-edt-navigation-probe/receipt.json'];result=receipts['blind-edt-navigation-probe/RESULT.json']
for r in [receipt,result]:
 require(r['availability']=='present' and r['metadata']['all50OriginalControlsReproduced'] is True and r['metadata']['candidateGoalsMet'] is True,'Control/candidate metadata failed')
 require(r['metadata']['physicalAuthority'] is False and r['metadata']['appActivation'] is False,'Invalid authority claim')
require(result['metadata']['candidateExecuted'] is True and result['metadata']['candidateRequests']==25,'Candidate count changed')
require(receipt['metadata']['nativeHookChecks']['checks']==51 and receipt['metadata']['nativeHookChecks']['passed']==51,'Hook controls differ')
require(result['sha256']==receipt['metadata']['resultSHA256']=='4debf8286fd2fc2892767fb3ded89e836909730f3f6cd2bc1806490505f1521a','Result identity differs')
source=P/'PROTOCOL_SOURCE.swift.txt'
require(sha(source)==s['sourcePins']['research/native-floor-import-repair-20261028/edt-navigation-probe/main.swift']['sha256']=='cc1cc7e6423bd35fd767e8a1e3822f10dbda98de9a01656d3bd65e6f094c0546','Protocol source differs')
text=source.read_text()
for fragment in ['acceptedSix==6 && acceptedTwo==2 && refusedThree==3 && preservedFourteen==14 && acceptance.count==25','row.bodyContact==false && row.marginContact==false && !row.initialBodyContact && !row.initialMarginContact','"fullFootprintSupportVerified":false','"continuousSourceClearanceGuarantee":false','"preservedUnrunJourneyStages":9']:
 require(fragment in text,'Acceptance or limitation predicate changed')
require(sorted(s['fixtureRequests'].values())==[12,13] and s['rawCoffeeDataUsed'] is False,'Fixture denominator changed')
ids=s['acceptanceIDs'];require(sorted(map(len,ids.values()))==[2,3,6,14],'Acceptance group membership differs')
lines=(P/'BOUNDED_LOG.txt').read_text().splitlines()
logged=[json.loads(x.split('BLIND_CI_RECEIPT=',1)[1]) for x in lines if 'BLIND_CI_RECEIPT=' in x]
require(logged==e['receipts'],'Stored receipt metadata differs from log')
loggedv=json.loads(next(x.split('EDT_HISTORICAL_SOURCE_VIEW ',1)[1] for x in lines if 'EDT_HISTORICAL_SOURCE_VIEW ' in x));require(loggedv==v,'Provenance differs from log')
failed=json.loads((P/'PREVIOUS_FAILED_RUN.json').read_text());require(failed['conclusion']=='failure' and failed['runID']==41008743162 and failed['nativeControlsExecuted'] is False,'Prior failure not preserved')
print(json.dumps({'status':'saved-evidence-consistent','nativeExecutedByThisCheck':False,'fullResultRowsAvailable':False,'originalControls':50,'hookChecks':51,'candidateRequests':25,'completeNoObstacleContactRoutesImpliedByPredicate':8,'preservedRefusalsAndFailuresImpliedByPredicate':17,'artifactCount':0,'roomAccuracyOrLiveSafetyEstablished':False},sort_keys=True))
