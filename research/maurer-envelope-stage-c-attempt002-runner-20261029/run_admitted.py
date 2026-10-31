"""One-shot explicit admission-commit glue; export only the fixed reviewed scalar schema, never raw output."""
import hashlib,json,math,os,pathlib,re,subprocess,sys
from validate_envelope import validate_envelope
from validate_receipts import validate as validate_receipts
from validate_failure import validate_failure,validate_matrix
HERE=pathlib.Path(__file__).resolve().parent
SOURCE='b78b97365d458bcacdd7db19cf221a5bfd22ad7e3f712c55ed59061fd3e0a165'
REVIEW='72fb69bbce0f96f8131af3d085990f079334321d7448d17029a4c05ed8772fda'
CAPS={'CPUSeconds':120,'wallSeconds':300,'observedRSSBytes':2147483648,'observedOutputBytes':134217728}
def require(ok,why):
 if not ok: raise ValueError(why)
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def scalar_aggregate(value):
 base={'schema','status','nativeCommandsCompleted','sourcePinsBefore','sourcePinsAfter','toolPinsBefore','toolPinsAfter','physicalAuthority','appActivation','frozenInputSHA256','actual003CandidateReceiptsExactMatch'}
 require(base<=set(value)<=base|{'resources','routeAcceptance','observerGroupsPassed','candidateReceipts','pathDigestEncoding','failureEvidence','matrixObservation','lastValidResourceSample','envelopeWorkReceipts'},'aggregate keys')
 require(value['schema']=='blind.exact-seed-radius-envelope-stage-c.aggregate.v2','aggregate schema')
 require(value['status'] in ['started','failed-or-inconclusive','passed-fixed-source-route-matrix'],'aggregate status')
 require(type(value['nativeCommandsCompleted']) is int and 0<=value['nativeCommandsCompleted']<=31,'command count')
 for k in ['sourcePinsBefore','sourcePinsAfter','toolPinsBefore','toolPinsAfter','physicalAuthority','appActivation']:require(type(value[k]) is bool,'boolean field')
 require(type(value['actual003CandidateReceiptsExactMatch']) is bool,'exact parity flag type')
 require(value['physicalAuthority'] is False and value['appActivation'] is False,'no authority')
 if 'resources' in value:
  r=value['resources'];numeric={'wallSeconds','observedAggregateCPUSeconds','observedPeakRSSBytes','observedPeakOutputBytes','finalOwnedOutputBytes'}
  require(set(r)==numeric|{'terminalObservationCompleted','measurementBoundary','limitBreached','exportReserveUnavailable'},'resource keys')
  require(all(type(r[k]) in (int,float) and math.isfinite(r[k]) and r[k]>=0 for k in numeric),'resource values')
  require(all(type(r[k]) is int for k in ['observedPeakRSSBytes','observedPeakOutputBytes','finalOwnedOutputBytes']),'resource byte integers')
  require(type(r['terminalObservationCompleted']) is bool and type(r['exportReserveUnavailable']) is bool,'resource flags')
  require(r['measurementBoundary']=='terminal-guard-observation-before-bounded-metadata-export-refresh','measurement boundary')
  require(type(r['limitBreached']) is dict and set(r['limitBreached'])=={'cpu','wall','rss','output'} and all(type(v) is bool for v in r['limitBreached'].values()),'cap flags')
  require(r['finalOwnedOutputBytes']<=r['observedPeakOutputBytes'],'final output peak')
 if 'lastValidResourceSample' in value:
  sample=value['lastValidResourceSample'];fields={'sampleIndex','wallSeconds','observedAggregateCPUSeconds','observedPeakRSSBytes','observedPeakOutputBytes','completeTerminalObservation','capComplianceEstablished'}
  require(type(sample) is dict and set(sample)==fields,'last sample keys')
  require(type(sample['sampleIndex']) is int and 1<=sample['sampleIndex']<=1000000,'last sample index')
  require(all(type(sample[k]) in (int,float) and math.isfinite(sample[k]) and sample[k]>=0 for k in ['wallSeconds','observedAggregateCPUSeconds']),'last sample numeric')
  require(all(type(sample[k]) is int and 0<=sample[k]<=9223372036854775807 for k in ['observedPeakRSSBytes','observedPeakOutputBytes']),'last sample bytes')
  require(sample['completeTerminalObservation'] is False and sample['capComplianceEstablished'] is False,'last sample incomplete')
 if 'observerGroupsPassed' in value:require(type(value['observerGroupsPassed']) is int and value['observerGroupsPassed']==21,'observer count')
 if 'routeAcceptance' in value:
  r=value['routeAcceptance'];bools={'all50OriginalControlsReproduced','candidateGoalsMet','allCandidateInitialContactsUnchanged','allCandidateLayoutsMatched'};counts={'candidateRequests':25,'retainedSixNoContactCorridors':6,'completeNoContactCorners':2,'retainedThreeTypedRefusals':3,'preservedOtherFourteenFailures':14}
  require(set(r)==bools|set(counts),'acceptance keys');require(all(type(r[k]) is bool for k in bools),'acceptance booleans');require(all(type(r[k]) is int and r[k]==v for k,v in counts.items()),'acceptance counts')
 if value['status']=='passed-fixed-source-route-matrix':
  require(value['actual003CandidateReceiptsExactMatch'] is True and len(value.get('envelopeWorkReceipts',[]))==25,'passing exact parity and work receipts')
  require('resources' in value and 'lastValidResourceSample' not in value,'passing complete resource observations required')
  require(value['resources']['terminalObservationCompleted'] is True and value['resources']['exportReserveUnavailable'] is False and not any(value['resources']['limitBreached'].values()),'passing terminal observations')
  require(all(value['resources'][k]<=v for k,v in {'wallSeconds':CAPS['wallSeconds'],'observedAggregateCPUSeconds':CAPS['CPUSeconds'],'observedPeakRSSBytes':CAPS['observedRSSBytes'],'observedPeakOutputBytes':CAPS['observedOutputBytes']}.items()),'passing resource cap breach')
  require(value['nativeCommandsCompleted']==31 and all(value[k] is True for k in ['sourcePinsBefore','sourcePinsAfter','toolPinsBefore','toolPinsAfter']),'passing postchecks')
  require(value.get('observerGroupsPassed')==21 and 'routeAcceptance' in value and all(value['routeAcceptance'][k] is True for k in bools),'passing acceptance')
 return value

def main():
 repo=pathlib.Path(os.environ['GITHUB_WORKSPACE']).resolve();temp=pathlib.Path(os.environ['RUNNER_TEMP']).resolve()
 commit=os.environ['GITHUB_SHA']
 require(re.fullmatch('[0-9a-f]{40}',commit),'commit grammar')
 require(os.environ.get('GITHUB_REPOSITORY')=='mischa23v/blind' and os.environ.get('GITHUB_RUN_ATTEMPT')=='1','repository/attempt')
 require(os.environ.get('GITHUB_EVENT_NAME')=='push' and os.environ.get('GITHUB_REF')=='refs/heads/codex/recovery-hazard-order-20261027','explicit push branch')
 admission_path='research/maurer-envelope-stage-c-attempt002-runner-20261029/ADMISSION_ENVELOPE_002.json'
 root_admission=json.loads((repo/admission_path).read_text())
 require(set(root_admission)=={'schema','marker','nonce','expectedParentCommit','sourceManifestSHA256','sourceReviewSHA256','launchManifestSHA256','workflowSHA256','runnerSHA256','exportValidatorSHA256','failureValidatorSHA256','envelopeValidatorSHA256','limits','acceptObservedToolchainPolicy'},'root admission fields')
 require(root_admission['schema']==1 and root_admission['marker']=='ROOT_ADMITTED_SINGLE_STAGE_C_MATRIX' and root_admission['nonce']=='maurer-envelope-20261029-second-fixed-50-plus-25-output-race','explicit one-shot root marker')
 require(root_admission['sourceManifestSHA256']==SOURCE and root_admission['sourceReviewSHA256']==REVIEW and root_admission['limits']==CAPS and root_admission['acceptObservedToolchainPolicy'] is True,'root scope')
 require(root_admission['workflowSHA256']==digest(repo/'.github/workflows/maurer-envelope-stage-c-attempt002.yml') and root_admission['runnerSHA256']==digest(HERE/'run_admitted.py') and root_admission['exportValidatorSHA256']==digest(HERE/'validate_receipts.py') and root_admission['failureValidatorSHA256']==digest(HERE/'validate_failure.py'),'admitted execution glue')
 require(root_admission['envelopeValidatorSHA256']==digest(HERE/'validate_envelope.py'),'admitted envelope validator')
 def git(*args):return subprocess.check_output(['/usr/bin/git',*args],cwd=repo,text=True,timeout=5).strip()
 require(git('rev-parse','HEAD')==commit and git('rev-parse','HEAD^')==root_admission['expectedParentCommit'],'exact admission head/parent')
 require(git('diff-tree','--no-commit-id','--name-only','-r','HEAD').splitlines()==[admission_path],'admission-only commit required')
 require(git('diff-tree','--no-commit-id','--diff-filter=A','--name-only','-r','HEAD').splitlines()==[admission_path],'fresh admission file required')
 require(REVIEW!='0'*64,'source review not finalized')
 launch=root_admission['launchManifestSHA256'];require(re.fullmatch('[0-9a-f]{64}',launch),'launch hash grammar')
 launcher=repo/'research/maurer-envelope-stage-c-attempt002-launch-20261029';packet=repo/'research/maurer-envelope-stage-c-source-20261029'
 require(digest(launcher/'LAUNCH_MANIFEST.json')==launch,'exact admitted launcher')
 require(digest(packet/'CANDIDATE_MANIFEST.json')==SOURCE,'exact source packet')
 admission=temp/'blind-envelope-stage-c-attempt002-admission.private.json'
 document={'schema':1,'attemptID':'envelope002','stage':'C','singleAttempt':True,'sourceManifestSHA256':SOURCE,'sourceReviewSHA256':REVIEW,'launchManifestSHA256':launch,'repositoryCommit':commit,'freePublicAppleRunner':True,'limits':CAPS,'acknowledgesObservedPollingLimits':True,'toolPinPolicy':'validate-installed-Xcode-27.0-freeze-executable-hashes-before-compile-and-check-after'}
 with admission.open('x') as f:json.dump(document,f)
 output=temp/'blind-exact-seed-radius-envelope-stage-c-attempt002';public=temp/'blind-envelope-stage-c-attempt002-public-aggregate';public.mkdir(exist_ok=False)
 with (temp/'blind-envelope-stage-c-attempt002-launch-stdout.private.txt').open('xb') as stdout,(temp/'blind-envelope-stage-c-attempt002-launch-stderr.private.txt').open('xb') as stderr:
  result=subprocess.run([sys.executable,str(launcher/'launch_stage_c.py'),'--repository',str(repo),'--source-packet',str(packet),'--admission',str(admission),'--output',str(output)],stdout=stdout,stderr=stderr)
 raw=output/'AGGREGATE.review-required.json';require(raw.stat().st_size<=131072,'aggregate byte cap');value=scalar_aggregate(json.loads(raw.read_text()))
 require(digest(launcher/'LAUNCH_MANIFEST.json')==launch,'launch manifest changed before export')
 launch_pins=json.loads((launcher/'LAUNCH_MANIFEST.json').read_text())['files']
 schema_path=launcher/'PUBLIC_AGGREGATE_SCHEMA.json';require(digest(schema_path)==launch_pins['PUBLIC_AGGREGATE_SCHEMA.json']['sha256'],'schema changed before export')
 schema=json.loads(schema_path.read_text())
 request_path=repo/'research/native-floor-import-repair-20261028/strict-endpoint-probe/REQUESTS_49A.json';require(digest(request_path)=='e5d2e07c7564869d2abde1d4a947e022d1a166c64641a81f2b92fcdbab73ac51','requests changed before export')
 requests=json.loads(request_path.read_text(),parse_int=lambda v:-0.0 if v=='-0' else int(v));validate_receipts(value,schema,requests)
 reference_path=launcher/'ACTUAL003_EXPECTED_ENVELOPE.json';require(digest(reference_path)=='cfae06b474540a7e0bed91c09ced9f6ad47add1eda4e49da03354aae3d5da4cc' and digest(reference_path)==launch_pins['ACTUAL003_EXPECTED_ENVELOPE.json']['sha256'],'exact actual003 reference')
 validate_envelope(value,requests,json.loads(reference_path.read_text()))
 masks_path=repo/'research/native-floor-import-repair-20261028/edt-navigation-probe/EDT_MASK_INPUTS.json';require(digest(masks_path)=='13f436a77608178789c6ba19db1f6de7f91d07229b3af3771106d7c4b218ed2a','masks changed before export')
 recipe_path=packet/'prepared-stage-c-final/BUILD_RECIPE.json';source_pins=json.loads((packet/'CANDIDATE_MANIFEST.json').read_text())['files'];require(digest(packet/'CANDIDATE_MANIFEST.json')==SOURCE and digest(recipe_path)==source_pins['prepared-stage-c-final/BUILD_RECIPE.json']['sha256'],'recipe changed before export')
 if 'failureEvidence' in value:validate_failure(value['failureEvidence'],json.loads(recipe_path.read_text()),schema)
 if 'matrixObservation' in value:validate_matrix(value['matrixObservation'],requests,json.loads(masks_path.read_text()))
 require(value['status']!='failed-or-inconclusive' or 'failureEvidence' in value,'failure context required')
 require(value['status']!='passed-fixed-source-route-matrix' or len(value.get('candidateReceipts',[]))==25 and 'failureEvidence' not in value and value.get('matrixObservation',{}).get('candidateGoalsMet') is True,'passing candidate receipts')
 envelope={'sourceCommit':commit,'sourceManifestSHA256':SOURCE,'launchManifestSHA256':launch,'launcherExit':result.returncode,'aggregate':value}
 (public/'AGGREGATE.json').write_text(json.dumps(envelope,indent=2)+'\n');print(json.dumps(envelope,sort_keys=True))
 require(result.returncode==0 and value['status']=='passed-fixed-source-route-matrix','native attempt did not pass')
if __name__=='__main__':main()
