"""Fixed saved-pose equivalence check, not a new navigation episode."""
from pathlib import Path
import hashlib,json,sys,time
import numpy as np
HERE=Path(__file__).resolve().parent;ROOT=HERE.parent;WS=ROOT.parent
sys.path.insert(0,str(ROOT/'ground-follow-v3'))
from ground_support import GroundSupport
from run_ground_pilot import plane_support_height
sys.path.insert(0,str(ROOT/'ground-follow-v2'))
from oriented_ground_container import GroundedReferenceContainer
from oriented_container import OrientedReferenceContainer
from oriented_ground_skip_container import GroundSkippingReferenceContainer
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
 if sha(HERE/'FROZEN_COMPARISON.json')!=expected:raise ValueError('manifest changed')
 for p,h in json.loads((HERE/'FROZEN_COMPARISON.json').read_text())['files'].items():
  if sha(WS/p)!=h:raise ValueError('source/input changed: '+p)
def contact_identity(row):
 keys=('contact','candidateTriangles','firstReferenceCellID','reason','nonGroundContactCount','firstTriangleModelHeightRange','firstTriangleHeightRelativeToStartFootRange','sweep')
 return {k:row.get(k)for k in keys}
def main(expected):
 verify(expected);out=HERE/'compare-01/result';out.mkdir(exist_ok=False);start=time.monotonic();runtime=serial_vtk()
 route=json.loads((ROOT/'FIRST_ROUTE.json').read_text());oldresult=json.loads((ROOT/'ground-follow-v3/run-01/result/RESULT.json').read_text())
 with np.load(ROOT/'ground-follow-v3/run-01/result/ACTOR_TRACE.npz',allow_pickle=False)as a:trace=a['trace'];columns=list(a['columns'])
 assert len(trace)==108 and oldresult['arrival'] and oldresult['actualBodyContactEvents']==oldresult['marginContactEvents']==0
 surface,mesh_info,reader=load_surface()
 with np.load(ROOT/'inputs/koivu_5cm_v2_pipeline2_out.npz',allow_pickle=False)as m:level={'R':m['R'],'t':m['t']}
 A=np.asarray(json.loads((WS/'blind-koivu-faro-acquisition-04/selected-reference/icp_iphone.json').read_text())['gt_transformation'])
 base=OrientedReferenceContainer(surface,transform(level,A));initial=oldresult['initialReferenceSupport']['probes']
 seeds=[int(p['referenceCellID'])for p in initial];points=[[p['modelXZ'][0],p['modelHeightY'],p['modelXZ'][1]]for p in initial]
 path=np.vstack((route['start'],route['nativeInitialRoute']['points'],route['goal']))
 print(json.dumps({'phase':'rebuild_exact_frozen_ground'}),flush=True)
 ground=GroundSupport.from_scorer(base,path,seeds,points)
 assert ground.receipt==oldresult['groundComponent'] or all(ground.receipt[k]==oldresult['groundComponent'][k]for k in ground.receipt if k!='originalMeshMTime')
 slow=GroundedReferenceContainer(surface,base.transform,ground=ground)
 fast=GroundSkippingReferenceContainer(surface,base.transform,ground=ground)
 rows=[];slow_time=0.;fast_time=0.;ground_reports=0;skipped=0
 xyz=[columns.index(k)for k in ('x','y','z')];proposed=[columns.index(k)for k in ('proposedX','proposedY','proposedZ')]
 for tick in TICKS:
  row=trace[tick];assert int(row[columns.index('tick')])==tick
  begin=np.asarray(oldresult['settledStart'])if tick==0 else trace[tick-1,xyz]
  end=row[proposed];yaw=float(route['initialYawRadians'])if tick==0 else float(trace[tick-1,columns.index('yaw')]);dyaw=float(row[columns.index('yawDelta')])
  middle=(begin+end)*.5;probes=base.support_probes(middle,yaw+dyaw*.5)
  assert len(probes['probes'])==9 and all(p['hit']and ground.is_ground(int(p['referenceCellID']))for p in probes['probes'])
  middle[1]=plane_support_height(probes,ground)
  for half,(a,b,ay)in enumerate(((begin,middle,yaw),(middle,end,yaw+dyaw*.5))):
   t=time.monotonic();old=slow.swept_contacts(a,b,ay,dyaw*.5);s=time.monotonic()-t;slow_time+=s
   t=time.monotonic();new=fast.swept_contacts(a,b,ay,dyaw*.5);f=time.monotonic()-t;fast_time+=f
   for body in ('actualBody','horizontalMargin'):
    if contact_identity(old[body])!=contact_identity(new[body]):raise AssertionError((tick,half,body,contact_identity(old[body]),contact_identity(new[body])))
    assert new[body]['groundContactCount']is None
    ground_reports+=old[body]['groundContactCount'];skipped+=new[body]['skippedGroundCandidateCount']
   rows.append({'tick':tick,'half':half,'slowWallSeconds':s,'fastWallSeconds':f,'identicalNonGroundContacts':True,'actualBodyContact':new['actualBody']['contact'],'marginContact':new['horizontalMargin']['contact']})
  print(json.dumps({'phase':'saved_pose_compared','tick':tick,'slowSeconds':slow_time,'fastSeconds':fast_time}),flush=True)
 result={'scope':'Exact ground-ID exclusion equivalence on frozen real-reference saved poses, not navigation episodes','pass':True,'ticks':list(TICKS),'halfSweeps':len(rows),'bodyMarginComparisons':2*len(rows),'contactIdentityFields':['contact','candidate count','first original non-ground ID','reason','non-ground count','height range','sweep'],
  'timingScope':'Linux CPU diagnostic; slow always precedes fast on shared warm locator/cache, not unbiased benchmarking or iPhone latency','slowWallSeconds':slow_time,'fastWallSeconds':fast_time,'speedupRatio':slow_time/fast_time if fast_time else None,'slowTriangleQueries':slow.triangle_queries,'fastTriangleQueries':fast.triangle_queries,'originalGroundTriangleContactReports':ground_reports,'fastGroundContactReports':None,'skippedGroundCandidates':skipped,'groundContactsMeasuredByFastScorer':False,
  'groundCellCount':len(ground.ground_cell_ids),'groundClassifierUnchanged':True,'rawObstacleGeometryUnchanged':True,'physicalAuthority':False,'newNavigationEpisodes':0,'rows':rows,'runtime':runtime,'referenceMesh':mesh_info,'wallSeconds':time.monotonic()-start}
 verify(expected);(out/'EQUIVALENCE.json').write_text(json.dumps(result,indent=2,allow_nan=False)+'\n');print(json.dumps({'phase':'terminal','pass':True,'speedupRatio':result['speedupRatio']}),flush=True)
if __name__=='__main__':main(sys.argv[1])
