"""Read-only frozen source/cache/output admission checks; never runs a query."""
from pathlib import Path
import hashlib,json
H=Path(__file__).resolve().parent
W=H.parent.parent
R=W/'research/open3d-same-data-benchmark-20261028/fresh-run'
V=W/'coordination/accuracy-methods-review-20261029/voxfield-feasibility/full265-d1-n2/run'
C1=V.parent.parent/'full265-c1-recovery'
ARMS=['B','C0','C1']
def digest(path):
 h=hashlib.sha256()
 with Path(path).open('rb') as f:
  for block in iter(lambda:f.read(1<<20),b''):h.update(block)
 return h.hexdigest()
def source_check():
 frozen=json.loads((H/'SOURCE_FREEZE.json').read_text())
 for path,expected in frozen['pins'].items():
  assert digest(path)==expected,('source_changed',path)
 return frozen
def admission(arm):
 assert arm in ARMS
 a=json.loads((H/'SCORE_ADMISSION.json').read_text())
 assert a['status']=='admitted' and a['authorizedBy']=='root'
 assert a['sourceFreezeSHA256']==digest(H/'SOURCE_FREEZE.json')
 assert a['arms']==ARMS and a['allMapperOutputsIndependentlyAdmitted'] is True
 assert a['scoreSourceIndependentlyReviewed'] is True and a['sequentialExclusiveSlotRequired'] is True
 for key in ['mapperOutputFreeze','mapperOutputAdmission','scoreSourceReview']:
  pin=a[key];assert Path(pin['path']).is_file()
  assert digest(pin['path'])==pin['sha256'],('admission_evidence_changed',key)
 # Explicit root recovery amendment: do not rewrite or reinterpret the failed batch.
 assert Path(a['mapperOutputAdmission']['path'])==V.parent/'RECOVERED_OUTPUT_ADMISSION.json'
 recovery=json.loads(Path(a['mapperOutputAdmission']['path']).read_text())
 assert recovery['status']=='admitted' and recovery['authorizedBy']=='root'
 for key in ['admittedForScoring','recoveryAmendment','originalBatchRemainsQuarantined','allThreeArmsIndependentlyReviewed','sameInputKernelConfiguration','c1StartedEmpty']:
  assert recovery[key] is True,('recovery_gate',key)
 for key in ['tsdfResume','fittingPerformed','referenceUsedByMapper']:
  assert recovery[key] is False,('recovery_gate',key)
 assert recovery['framesPerArm']==265
 assert recovery['meshFreeze']==a['mapperOutputFreeze']
 expected_paths={'originalBatchAdmission':V.parent/'OUTPUT_ADMISSION.json','c1RunAdmission':C1/'OUTPUT_ADMISSION.json','c1Resource':C1/'RESOURCE.json','c1OutputFreeze':C1/'run/FUSION_OUTPUT_FREEZE.json'}
 for key,expected_path in expected_paths.items():
  pin=recovery[key];assert Path(pin['path'])==expected_path
  assert digest(pin['path'])==pin['sha256'],('recovery_evidence_changed',key)
 original=json.loads((V.parent/'OUTPUT_ADMISSION.json').read_text())
 assert original['admittedForSubsequentReview'] is False and original['partialOutputsQuarantined'] is True
 c1_admission=json.loads((C1/'OUTPUT_ADMISSION.json').read_text())
 assert c1_admission['admittedForSubsequentReview'] is True and c1_admission['partialOutputsQuarantined'] is False
 assert c1_admission['accuracyEvaluated'] is False and c1_admission['scoringRequiresSeparateAdmission'] is True
 resource=json.loads((C1/'RESOURCE.json').read_text())
 assert resource['exitCode']==0 and resource['stopReason'] is None and resource['frozenIntegrityPassed'] is True
 assert set(recovery['independentArmReviews'])==set(ARMS)
 for arm_review in recovery['independentArmReviews'].values():
  assert digest(arm_review['path'])==arm_review['sha256']
 f=json.loads(Path(a['mapperOutputFreeze']['path']).read_text())
 assert f['frames']==265 and set(f['arms'])==set(ARMS)
 assert f['referenceUsedByMapper'] is False and f['accuracyEvaluated'] is False
 assert f['guardAdmissionRequired'] is True
 for name,pin in f['arms'].items():
  assert Path(pin['path'])==(C1/'run' if name=='C1' else V)/(name+'_native_mesh.ply')
  assert pin['bytes']>0 and len(pin['sha256'])==64
 assert len({pin['submitted'] for pin in f['arms'].values()})==1
 c1_freeze=json.loads((C1/'run/FUSION_OUTPUT_FREEZE.json').read_text())
 assert c1_freeze['frames']==265 and set(c1_freeze['arms'])=={'C1'}
 assert c1_freeze['referenceUsedByMapper'] is False and c1_freeze['accuracyEvaluated'] is False
 assert c1_freeze['arms']['C1']==f['arms']['C1']
 return a,f
def verify(arm):
 source_check();a,f=admission(arm);checked={}
 def check(path,expected):
  path=Path(path);actual=digest(path)
  assert actual==expected,(str(path),actual,expected)
  checked[str(path)]=actual
 check(H/'SCORE_ADMISSION.json',digest(H/'SCORE_ADMISSION.json'))
 check(H/'SOURCE_FREEZE.json',a['sourceFreezeSHA256'])
 for key in ['mapperOutputFreeze','mapperOutputAdmission','scoreSourceReview']:
  check(a[key]['path'],a[key]['sha256'])
 recovery=json.loads(Path(a['mapperOutputAdmission']['path']).read_text())
 for key in ['originalBatchAdmission','c1RunAdmission','c1Resource','c1OutputFreeze']:
  check(recovery[key]['path'],recovery[key]['sha256'])
 for pin in recovery['independentArmReviews'].values():check(pin['path'],pin['sha256'])
 for pin in f['arms'].values():
  assert Path(pin['path']).stat().st_size==pin['bytes']
  check(pin['path'],pin['sha256'])
 check(R/'EVALUATOR_FROZEN.json','8e96c22a447da8406d352b8caf76c16c97a3e5b0a37a8197770829f07592ebd1')
 p=json.loads((R/'EVALUATOR_FROZEN.json').read_text())
 for path,expected in p['pins'].items():check(path,expected)
 train=json.loads((R/'FUSION_FROZEN.json').read_text())
 assert p['frameIDs']==train['excludedTestIDs'] and len(p['frameIDs'])==29
 assert len(train['trainingFrames'])==265 and not set(p['frameIDs'])&{r['frameID'] for r in train['trainingFrames']}
 # Original unchanged summary also reads heldout processed-sensor PNGs.
 for name in p['frameIDs']:
  path=R/'inputs/room_datasets/koivu/iphone/long_capture/depth'/(name+'.png')
  check(path,train['pins'][str(path)])
 for mode,expected in [('faro','2d7a889bd4609f9441a692baa4487d83739f6c9922bf10d2ff8abea8d928cc2c'),('tsdf','209a5c0cf42244bc4385308b944609bef9cdf6f29dddeff93a06441e31f229a4')]:
  d=R/'evaluation'/mode;check(d/'RESULT.json',expected);result=json.loads((d/'RESULT.json').read_text())
  assert result['status']=='completed' and result['scheduledRays']==1335885 and result['sampleStride']==4 and result['pixelOffset']==0
  assert [r['frameID'] for r in result['records']]==p['frameIDs']
  mesh=R/('inputs/room_datasets/koivu/gt_mesh.ply' if mode=='faro' else 'fusion/unfiltered-tsdf-mesh.ply')
  assert result['meshSHA256']==p['pins'][str(mesh)]
  for record in result['records']:
   assert record['scheduled']==46065
   check(d/(record['frameID']+'.npz'),record['fileSHA256'])
 check(R/'COMMON_GEOMETRY_RESULTS.json','ed1aaf510b8c0dcfc8ba93d1a177a054299933022cc454f9122c580308075df0')
 return {'status':'verified','arm':arm,'checked':checked,'cachedFAROReusedWithoutRequery':True,'sourceOutputsModified':False}
