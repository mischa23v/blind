"""Paired frozen-pose V6 timing attribution, not a navigation episode."""
from pathlib import Path
import hashlib,importlib.util,json,sys,time
import numpy as np
HERE=Path(__file__).resolve().parent;GAME=HERE.parent;WS=GAME.parent
sys.path.insert(0,str(GAME/'ground-obb-v6'))
from oriented_ground_obb_container import GroundOBBReferenceContainer
from profiled_v6 import ProfiledGroundOBBReferenceContainer
sys.path.insert(0,str(GAME/'camera-approach-executor-14'))
from ground_setup import shared_ground
from oriented_container import OrientedReferenceContainer
# Explicitly bind the same original v3 helper despite historical reused names.
sys.path.insert(0,str(GAME/'ground-follow-v3'))
p=GAME/'ground-follow-v3/run_ground_pilot.py'
spec=importlib.util.spec_from_file_location('profile16_frozen_v3',p);v3=importlib.util.module_from_spec(spec);sys.modules[spec.name]=v3;spec.loader.exec_module(v3)
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
 original=GroundOBBReferenceContainer(surface,base.transform,ground=ground)
 profiled=ProfiledGroundOBBReferenceContainer(surface,base.transform,ground=ground)
 xyz=[columns.index(k)for k in ('x','y','z')];proposed=[columns.index(k)for k in ('proposedX','proposedY','proposedZ')]
 rows=[];original_seconds=profiled_seconds=0.;candidate_count=skipped=bounds_rejected=exact=0
 for tick in TICKS:
  saved=trace[tick];assert int(saved[columns.index('tick')])==tick
  begin=np.asarray(old['settledStart'])if tick==0 else trace[tick-1,xyz]
  end=saved[proposed];yaw=float(route['initialYawRadians'])if tick==0 else float(trace[tick-1,columns.index('yaw')]);dyaw=float(saved[columns.index('yawDelta')])
  midpoint=(begin+end)*.5;probes=base.support_probes(midpoint,yaw+dyaw*.5)
  assert len(probes['probes'])==9 and all(p['hit']and ground.is_ground(int(p['referenceCellID']))for p in probes['probes'])
  midpoint[1]=plane_support_height(probes,ground)
  for half,(a,b,ay)in enumerate(((begin,midpoint,yaw),(midpoint,end,yaw+dyaw*.5))):
   order=('original','profiled')if len(rows)%2==0 else('profiled','original');outputs={};elapsed={};n=len(profiled.profile_rows)
   for which in order:
    obj=original if which=='original'else profiled;t=time.perf_counter();outputs[which]=obj.swept_contacts(a,b,ay,dyaw*.5);elapsed[which]=time.perf_counter()-t
   if outputs['original']!=outputs['profiled']:raise AssertionError(('complete output mismatch',tick,half))
   if len(profiled.profile_rows)!=n+2:raise AssertionError('exactly two profiled body/margin box queries required')
   for k,body in enumerate(('actualBody','horizontalMargin')):
    row=outputs['profiled'][body];candidate_count+=row['candidateTriangles'];skipped+=row['skippedGroundCandidateCount'];bounds_rejected+=row['rejectedNonGroundBoundsCandidates'];exact+=row['exactNonGroundTriangleTests']
    assert row['candidateTriangles']==row['skippedGroundCandidateCount']+row['rejectedNonGroundBoundsCandidates']+row['exactNonGroundTriangleTests']
    profiled.profile_rows[n+k]['savedCase']={'tick':tick,'half':half,'body':body}
   original_seconds+=elapsed['original'];profiled_seconds+=elapsed['profiled']
   rows.append({'tick':tick,'half':half,'executionOrder':list(order),'originalWallSeconds':elapsed['original'],'profiledWallSeconds':elapsed['profiled'],'completeOutputEquality':True})
  print(json.dumps({'phase':'saved_pose_profiled','tick':tick,'originalSeconds':original_seconds,'profiledSeconds':profiled_seconds}),flush=True)
 assert len(profiled.profile_rows)==40 and original.box_queries==profiled.box_queries==40 and original.triangle_queries==profiled.triangle_queries==exact
 phases={key:sum(float(row['phaseSeconds'][key])for row in profiled.profile_rows)for key in profiled.profile_rows[0]['phaseSeconds']}
 timed=sum(float(row['contactTimedWallSeconds'])for row in profiled.profile_rows)
 phase_sum=sum(phases.values())
 owner_seconds=sum(float(row['ownerCheck']['seconds'])for row in profiled.profile_rows)
 attribution={'phaseSeconds':phases,'summedContactTimedSeconds':timed,'exclusivePhaseSumSeconds':phase_sum,'timedMinusPhaseSumSeconds':timed-phase_sum,'phaseShareOfContactTime':{k:v/timed for k,v in phases.items()},'phaseShareOfWholeInstrumentedSweeps':{k:v/profiled_seconds for k,v in phases.items()},'outsideContactTimingAndWrapperSeconds':profiled_seconds-timed,'largestPhase':max(phases,key=phases.get),'nativeQueryExceedsHalfWholeInstrumentedCost':phases['nativeFindCellsWithinBounds']>profiled_seconds*.5,'nestedOwnerCheckSeconds':owner_seconds,'nestedOwnerCheckCount':sum(row['ownerCheck']['count']for row in profiled.profile_rows),'nestedTimingsMustNotBeAddedAgain':True}
 result={'scope':'Instrumentation-only attribution of frozen V6 on the same saved poses; no navigation episode','pass':True,'ticks':list(TICKS),'halfSweeps':len(rows),'boxQueries':len(profiled.profile_rows),'completeOutputEquality':True,'originalWallSeconds':original_seconds,'instrumentedWallSeconds':profiled_seconds,'elapsedDifferenceInstrumentedMinusOriginalSeconds':profiled_seconds-original_seconds,'timingCaveat':'Alternating pair order on a shared loaded locator; single process Linux timing, no iPhone latency or statistical benchmark claim','candidateTriangles':candidate_count,'groundCandidates':skipped,'nonGroundBoundsRejected':bounds_rejected,'exactTriangleTests':exact,'ownerTimingIsNestedNotAdditive':True,'groundSetupSeconds':ground_seconds,'attribution':attribution,'queryRows':profiled.profile_rows,'pairs':rows,'runtime':runtime,'referenceMesh':mesh_info,'totalWallSeconds':time.perf_counter()-started,'oldResultsChanged':False,'newOptimizationImplemented':False,'navigationEpisodes':0,'physicalAuthority':False}
 verify(expected);dump(out/'PROFILE.json',result);print(json.dumps({'phase':'terminal','pass':True,'originalSeconds':original_seconds,'instrumentedSeconds':profiled_seconds}),flush=True)
if __name__=='__main__':main(sys.argv[1])
