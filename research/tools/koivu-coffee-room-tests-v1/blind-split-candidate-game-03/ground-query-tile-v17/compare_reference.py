"""Paired frozen-pose original V6 versus tiled-query scorer; no navigation episode."""
from pathlib import Path
import hashlib,importlib.util,json,sys,time
import numpy as np
HERE=Path(__file__).resolve().parent;GAME=HERE.parent;WS=GAME.parent
sys.path.insert(0,str(GAME/'ground-obb-v6'))
from oriented_ground_obb_container import GroundOBBReferenceContainer
from oriented_ground_tiled_container import GroundTiledReferenceContainer
sys.path.insert(0,str(GAME/'camera-approach-executor-14'))
from ground_setup import shared_ground
from oriented_container import OrientedReferenceContainer
# Explicitly bind the same original v3 helper despite historical reused names.
sys.path.insert(0,str(GAME/'ground-follow-v3'))
p=GAME/'ground-follow-v3/run_ground_pilot.py'
spec=importlib.util.spec_from_file_location('tile17_frozen_v3',p);v3=importlib.util.module_from_spec(spec);sys.modules[spec.name]=v3;spec.loader.exec_module(v3)
plane_support_height=v3.plane_support_height
sys.path.insert(0,str(WS/'blind-opus-reference-scoring-audit-02/source'))
from score_reference import load_surface,transform
from reference_geometry import serial_vtk
TICKS=(0,9,15,28,30,45,60,75,90,106)

def sha(p):
 h=hashlib.sha256()
 with Path(p).open('rb')as f:
  while b:=f.read(1024**2):h.update(b)
 return h.hexdigest()
def verify(expected):
 if sha(HERE/'FROZEN.json')!=expected:raise ValueError('manifest changed')
 for p,h in json.loads((HERE/'FROZEN.json').read_text())['files'].items():
  if sha(WS/p)!=h:raise ValueError('source/input changed: '+p)
def dump(p,d):p.write_text(json.dumps(d,indent=2,allow_nan=False)+'\n')
class IdentityV6(GroundOBBReferenceContainer):
 """Original V6 method unchanged; capture ordered candidate identity afterward."""
 def __init__(self,*args,**kwargs):
  self.identity_rows=[];self.identity_seconds=0.
  super().__init__(*args,**kwargs)
 def contact_corners(self,corners):
  result=super().contact_corners(corners)
  began=time.perf_counter();self.check();n=self.ids.GetNumberOfIds()
  ids=np.fromiter((self.ids.GetId(i)for i in range(n)),dtype='<i8',count=n)
  ordered=hashlib.sha256(ids.tobytes()).hexdigest();ids.sort()
  digest=hashlib.sha256(ids.tobytes()).hexdigest();self.check();elapsed=time.perf_counter()-began
  self.identity_seconds+=elapsed
  self.identity_rows.append({'candidateCount':n,'sortedCandidateIDsSHA256':digest,'nativeCandidateOrderSHA256':ordered,'identityCaptureSeconds':elapsed,'hashEncoding':'sorted original cell IDs, little-endian signed int64'})
  return result

def main(expected):
 verify(expected);out=HERE/'run-01/result';out.mkdir(exist_ok=False);started=time.perf_counter();runtime=serial_vtk()
 route=json.loads((GAME/'FIRST_ROUTE.json').read_text());old=json.loads((GAME/'ground-follow-v3/run-01/result/RESULT.json').read_text())
 with np.load(GAME/'ground-follow-v3/run-01/result/ACTOR_TRACE.npz',allow_pickle=False)as z:trace=z['trace'];columns=list(z['columns'])
 assert len(trace)==108 and old['arrival'] and old['actualBodyContactEvents']==old['marginContactEvents']==0
 print(json.dumps({'phase':'reference_load_begin'}),flush=True);surface,mesh_info,reader=load_surface()
 with np.load(GAME/'inputs/koivu_5cm_v2_pipeline2_out.npz',allow_pickle=False)as z:level={'R':z['R'],'t':z['t']}
 A=np.asarray(json.loads((WS/'blind-koivu-faro-acquisition-04/selected-reference/icp_iphone.json').read_text())['gt_transformation'])
 base=OrientedReferenceContainer(surface,transform(level,A));initial=old['initialReferenceSupport']['probes']
 seeds=[int(p['referenceCellID'])for p in initial];support_points=[[p['modelXZ'][0],p['modelHeightY'],p['modelXZ'][1]]for p in initial]
 path=np.vstack((route['start'],route['nativeInitialRoute']['points'],route['goal']))
 ground_started=time.perf_counter();print(json.dumps({'phase':'same_ground_tiled_setup_begin'}),flush=True)
 def progress(row):dump(out/'GROUND_QUERY.json',row);print(json.dumps({'phase':'same_ground_query_ready','candidateCells':row['candidateCells'],'querySeconds':row['nativeQuery']['queryWallSeconds']}),flush=True)
 ground=shared_ground(base,[path],seeds,support_points,progress)
 ignored=('originalMeshMTime','candidateCap')
 for key,value in old['groundComponent'].items():
  if key not in ignored and ground.receipt[key]!=value:raise AssertionError('old frozen ground receipt mismatch: '+key)
 assert ground.receipt['candidateCells']<=2_000_000 and len(ground.ground_cell_ids)==427785
 ground_seconds=time.perf_counter()-ground_started
 dump(out/'GROUND_IDENTITY.json',{'priorSemanticReceiptFieldsEqualExcept':list(ignored),'groundCellCount':len(ground.ground_cell_ids),'originalCandidateCapStillSatisfied':True,'querySource':'executed stage14 shared_ground; same original fixed v3 route envelope','groundSetupSeconds':ground_seconds,'physicalAuthority':False})
 original=IdentityV6(surface,base.transform,ground=ground)
 optimized=GroundTiledReferenceContainer(surface,base.transform,ground=ground)
 xyz=[columns.index(k)for k in ('x','y','z')];proposed=[columns.index(k)for k in ('proposedX','proposedY','proposedZ')]
 rows=[];original_seconds=optimized_seconds=0.;candidate_count=skipped=bounds_rejected=exact=0;preview_differences=0
 for tick in TICKS:
  saved=trace[tick];assert int(saved[columns.index('tick')])==tick
  begin=np.asarray(old['settledStart'])if tick==0 else trace[tick-1,xyz]
  end=saved[proposed];yaw=float(route['initialYawRadians'])if tick==0 else float(trace[tick-1,columns.index('yaw')]);dyaw=float(saved[columns.index('yawDelta')])
  midpoint=(begin+end)*.5;probes=base.support_probes(midpoint,yaw+dyaw*.5)
  assert len(probes['probes'])==9 and all(p['hit']and ground.is_ground(int(p['referenceCellID']))for p in probes['probes'])
  midpoint[1]=plane_support_height(probes,ground)
  for half,(a,b,ay)in enumerate(((begin,midpoint,yaw),(midpoint,end,yaw+dyaw*.5))):
   order=('original','optimized')if len(rows)%2==0 else('optimized','original');outputs={};elapsed={};n=len(optimized.optimization_rows);differences={};identity_before=original.identity_seconds
   for which in order:
    obj=original if which=='original'else optimized;t=time.perf_counter();outputs[which]=obj.swept_contacts(a,b,ay,dyaw*.5);elapsed[which]=time.perf_counter()-t
   if len(optimized.optimization_rows)!=n+2 or len(original.identity_rows)!=n+2:raise AssertionError('exactly two logical body/margin query receipts required')
   if set(outputs['original'])!=set(outputs['optimized']):raise AssertionError('sweep schema changed')
   for outer in outputs['original']:
    if outer not in ('actualBody','horizontalMargin') and outputs['original'][outer]!=outputs['optimized'][outer]:raise AssertionError('outer sweep field changed')
   for k,body in enumerate(('actualBody','horizontalMargin')):
    before=outputs['original'][body];after=outputs['optimized'][body]
    if set(before)!=set(after):raise AssertionError('original collision result schema changed')
    delta=[key for key in before if before[key]!=after[key]]
    allowed=[]if before['contact']else['skippedGroundCandidateIDsFirst16']
    if any(key not in allowed for key in delta):raise AssertionError(('physical/contact result mismatch',tick,half,body,delta))
    differences[body]=delta;preview_differences+=bool(delta)
    if original.identity_rows[n+k]['sortedCandidateIDsSHA256']!=optimized.optimization_rows[n+k]['sortedCandidateIDsSHA256']:raise AssertionError('native versus tiled candidate-ID set mismatch')
    candidate_count+=after['candidateTriangles'];skipped+=after['skippedGroundCandidateCount'];bounds_rejected+=after['rejectedNonGroundBoundsCandidates'];exact+=after['exactNonGroundTriangleTests']
    assert after['candidateTriangles']==after['skippedGroundCandidateCount']+after['rejectedNonGroundBoundsCandidates']+after['exactNonGroundTriangleTests']
    optimized.optimization_rows[n+k]['savedCase']={'tick':tick,'half':half,'body':body}
   if v3.contact_status(outputs['original'])!=v3.contact_status(outputs['optimized']):raise AssertionError('episode contact classification changed')
   original_seconds+=elapsed['original'];optimized_seconds+=elapsed['optimized']
   rows.append({'tick':tick,'half':half,'executionOrder':list(order),'originalWallSecondsIncludingIdentityCapture':elapsed['original'],'originalCandidateIdentityCaptureSeconds':original.identity_seconds-identity_before,'originalWallSecondsExcludingIdentityCapture':elapsed['original']-(original.identity_seconds-identity_before),'optimizedWallSeconds':elapsed['optimized'],'onlyPermittedDiagnosticDifferences':differences,'physicalContactAndClassificationEquality':True})
  print(json.dumps({'phase':'saved_pose_compared','tick':tick,'originalSeconds':original_seconds,'optimizedSeconds':optimized_seconds}),flush=True)
 assert len(optimized.optimization_rows)==40 and original.box_queries==40
 assert original.triangle_queries==exact
 assert optimized.triangle_queries==sum(row['actualExactTriangleCounterDelta']for row in optimized.optimization_rows)
 assert optimized.box_queries==sum(row['actualBoxQueryCounterDelta']for row in optimized.optimization_rows)
 assert all(row['completed'] and row['nativeBoundsCallsTotal']==row['tiledQuery']['tileQueries']+int(row['fallbackUsed'])for row in optimized.optimization_rows)
 historical=json.loads((GAME/'query-profile-16/run-01/result/PROFILE.json').read_text())
 assert (candidate_count,skipped,bounds_rejected,exact)==tuple(historical[k]for k in ('candidateTriangles','groundCandidates','nonGroundBoundsRejected','exactTriangleTests'))
 result={'scope':'Exact original geometry with tiled broad-phase and original ordered positive-contact fallback, compared on frozen saved poses; no navigation episode','pass':True,'ticks':list(TICKS),'halfSweeps':len(rows),'logicalBoxComparisons':len(optimized.optimization_rows),'physicalContactAndClassificationEquality':True,'negativeSkippedGroundPreviewOrderDifferences':preview_differences,'onlyPermittedOriginalFieldDifference':'negative skippedGroundCandidateIDsFirst16 preview order','originalWallSecondsIncludingIdentityCapture':original_seconds,'originalCandidateIdentityCaptureSeconds':original.identity_seconds,'originalWallSecondsExcludingIdentityCapture':original_seconds-original.identity_seconds,'optimizedWallSeconds':optimized_seconds,'speedupRatioExcludingOriginalIdentityCapture':(original_seconds-original.identity_seconds)/optimized_seconds if optimized_seconds else None,'speedupRatioIncludingOriginalIdentityCapture':original_seconds/optimized_seconds if optimized_seconds else None,'timingCaveat':'Alternating pair order on a shared loaded locator; same process Linux diagnostic, no iPhone latency or statistical benchmark claim','candidateTriangles':candidate_count,'groundCandidates':skipped,'nonGroundBoundsRejected':bounds_rejected,'returnedExactTriangleTestCounts':exact,'actualOriginalTriangleQueries':original.triangle_queries,'actualOptimizedTriangleQueriesIncludingPrepassAndFallback':optimized.triangle_queries,'actualOptimizedLogicalPrepassAndFallbackBoxCounter':optimized.box_queries,'groundSetupSeconds':ground_seconds,'exactCandidateSetHashesEqual':True,'originalCandidateIdentityRows':original.identity_rows,'queryRows':optimized.optimization_rows,'pairs':rows,'runtime':runtime,'referenceMesh':mesh_info,'totalWallSeconds':time.perf_counter()-started,'oldResultsChanged':False,'geometryOrGroundOrBodyChanged':False,'navigationEpisodes':0,'physicalAuthority':False}
 verify(expected);dump(out/'EQUIVALENCE.json',result);print(json.dumps({'phase':'terminal','pass':True,'originalSeconds':original_seconds,'optimizedSeconds':optimized_seconds,'speedupRatio':result['speedupRatioExcludingOriginalIdentityCapture']}),flush=True)
if __name__=='__main__':main(sys.argv[1])
