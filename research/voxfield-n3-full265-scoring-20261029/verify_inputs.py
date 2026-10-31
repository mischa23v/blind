"""Read-only N3 admission, preserved N2 results, and frozen original cache checks."""
from pathlib import Path
import hashlib,json
H=Path(__file__).resolve().parent;W=H.parent.parent
R=W/'research/open3d-same-data-benchmark-20261028/fresh-run'
N2=W/'coordination/voxfield-recovered-full265-same-protocol-score'
V=W/'coordination/accuracy-methods-review-20261029/voxfield-feasibility/n3-reconstruction/full265-retry1'
FAILED=V.parent/'full265'
ARMS=['C1_N3']
N2_FREEZE_SHA='f18050b5af9ea282ac3d3466262ef3a005091608a0e4811b039ba7246576d699'
def digest(path):
 h=hashlib.sha256()
 with Path(path).open('rb') as f:
  for block in iter(lambda:f.read(1<<20),b''):h.update(block)
 return h.hexdigest()
def source_check():
 frozen=json.loads((H/'SOURCE_FREEZE.json').read_text())
 for path,expected in frozen['pins'].items():assert digest(path)==expected,('source_changed',path)
 return frozen
def admission(arm):
 assert arm in ARMS
 a=json.loads((H/'SCORE_ADMISSION.json').read_text())
 assert a['status']=='admitted' and a['authorizedBy']=='root'
 assert a['sourceFreezeSHA256']==digest(H/'SOURCE_FREEZE.json') and a['arms']==ARMS
 for key in ['allMapperOutputsIndependentlyAdmitted','scoreSourceIndependentlyReviewed','sequentialExclusiveSlotRequired','freshEmptyMapNoResume','sameInputKernelConfiguration','onlyN3NormalProviderChange','originalInterruptedAttemptRemainsQuarantined']:
  assert a[key] is True,('root_admission_gate',key)
 expected_paths={'mapperOutputFreeze':V/'run/FUSION_OUTPUT_FREEZE.json','mapperOutputAdmission':V/'OUTPUT_ADMISSION.json','mapperResource':V/'RESOURCE.json','mapperIndependentReview':V/'INDEPENDENT_COMPLETED_REVIEW.json','mapperN2LedgerMatch':V/'run/N2_INPUT_LEDGER_MATCH.json','scoreSourceReview':H/'INDEPENDENT_SOURCE_REVIEW.json','originalInterruptedAdmission':FAILED/'INTERRUPTED_OUTPUT_ADMISSION.json','previousN2OutputFreeze':N2/'OUTPUT_FREEZE.json'}
 for key,path in expected_paths.items():
  pin=a[key];assert Path(pin['path'])==path
  assert digest(path)==pin['sha256'],('admission_evidence_changed',key)
 assert a['previousN2OutputFreeze']['sha256']==N2_FREEZE_SHA
 failed=json.loads((FAILED/'INTERRUPTED_OUTPUT_ADMISSION.json').read_text())
 assert failed['admitted'] is False and failed['partialOutputsQuarantined'] is True
 assert failed['requiresNewReviewedFreshMapRun'] is True
 admitted=json.loads((V/'OUTPUT_ADMISSION.json').read_text())
 assert admitted['admittedForSubsequentReview'] is True and admitted['partialOutputsQuarantined'] is False
 assert admitted['accuracyEvaluated'] is False and admitted['scoringRequiresSeparateAdmission'] is True
 resource=json.loads((V/'RESOURCE.json').read_text())
 assert resource['exitCode']==0 and resource['stopReason'] is None and resource['frozenIntegrityPassed'] is True
 ledger=json.loads((V/'run/N2_INPUT_LEDGER_MATCH.json').read_text())
 assert ledger['frames']==265 and ledger['allNonNormalPreflightFieldsEqual'] is True
 assert ledger['pointCoordinatesCheckedAgainstOriginalKDepthPerPixel'] is True
 assert set(ledger['ignoredFields'])=={'normal_reasons_valid_boundary_missing_discontinuity_nonfinite_degenerate','range_band_by_normal_reason','preflight_seconds'}
 f=json.loads((V/'run/FUSION_OUTPUT_FREEZE.json').read_text())
 assert f['frames']==265 and set(f['arms'])=={'C1_N3'} and f['guardAdmissionRequired'] is True
 assert f['referenceUsedByMapper'] is False and f['accuracyEvaluated'] is False
 pin=f['arms']['C1_N3'];assert Path(pin['path'])==V/'run/C1_N3_native_mesh.ply'
 assert pin['bytes']>0 and len(pin['sha256'])==64 and pin['submitted']==164771607
 return a,f,expected_paths
def verify(arm):
 source_check();a,f,evidence=admission(arm);checked={}
 def check(path,expected):
  path=Path(path);actual=digest(path);assert actual==expected,(str(path),actual,expected);checked[str(path)]=actual
 check(H/'SCORE_ADMISSION.json',digest(H/'SCORE_ADMISSION.json'))
 check(H/'SOURCE_FREEZE.json',a['sourceFreezeSHA256'])
 for key,path in evidence.items():check(path,a[key]['sha256'])
 for pin in f['arms'].values():
  assert Path(pin['path']).stat().st_size==pin['bytes'];check(pin['path'],pin['sha256'])
 # Prior N2 scores are immutable reference comparisons, not tuning inputs.
 prior=json.loads((N2/'OUTPUT_FREEZE.json').read_text())
 assert prior['status']=='completed_independently_recounted' and len(prior['outputPins'])==118
 assert prior['arms']==['B','C0','C1'] and prior['viewsPerArm']==29 and prior['scheduledRaysPerArm']==1335885
 for path,pin in prior['outputPins'].items():
  assert Path(path).stat().st_size==pin['bytes'];check(path,pin['sha256'])
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
