"""Post-outcome read-only full-mesh rays at three saved rejected candidate poses."""
from pathlib import Path
import os,sys,json,csv,hashlib
for k in ('OPENBLAS_NUM_THREADS','OMP_NUM_THREADS','MKL_NUM_THREADS'):os.environ[k]='1'
H=Path(__file__).resolve().parents[1]/'evaluator-forward-recovery-02';sys.path.insert(0,str(H))
import numpy as np
import physics_primitives as motion
from runtime import verify,sha
from oriented_container import OrientedReferenceContainer,BodyGeometry
EXPECTED='3d17b1b816abd553fde50ea9702e35b4bcd380d10b18375f5535be2a5101b525'
verify(EXPECTED)
manifest=json.loads((H/'CACHE_MANIFEST.json').read_text())
for n,s in manifest['files'].items():assert sha(H/n)==s
runtime=motion.serial_vtk();surface,mi,reader=motion.load_surface();frames=json.loads((H/'inputs/PHONE_FRAME_METADATA_ONLY.json').read_text())['frames']['original'];T=motion.transform({k:np.array(frames[k]) for k in ('R','t')},np.array(json.loads((H/'inputs/icp_iphone.json').read_text())['gt_transformation']));base=OrientedReferenceContainer(surface,T,BodyGeometry(width=.45,depth=.3,height=1.6,horizontal_margin=0.));inverse=np.linalg.inv(T)
cache=json.loads((H/'caches/pair-03/RESULT.json').read_text());assert hashlib.sha256(T.tobytes()).hexdigest()==cache['referenceTransformSHA256']
with np.load(H/'caches/pair-03/GROUND_IDS.npz',allow_pickle=False) as z: ids=z['groundIDs'].copy()
plan=json.loads((H/'plans/pair-03.json').read_text());bounds=np.asarray(plan['sourceFloorEvaluationBoundsXYZ']);rows=[]
for i in (16,17,18):
 p=H/f'episodes/episode-{i:03d}/result';r=json.loads((p/'RESULT.json').read_text());assert r['status']=='unknownReferenceSupportDuringMotion'
 with (p/'ACTUAL_TRACE_PARTIAL.csv').open() as f:
  for a in csv.DictReader(f):last=a
 state=np.array([float(last[k]) for k in ('x','y','z')]);proposed=np.array([float(last[k]) for k in ('proposedX','proposedY','proposedZ')]);yaw=float(last['yaw']);dyaw=float(last['yawDelta']);assert np.array_equal(state,np.array(r['finalPosition']));queries=[]
 for label,point,angle in [('start',state,yaw),('midpoint',(state+proposed)*.5,yaw+dyaw*.5),('rejectedEndpoint',proposed,yaw+dyaw)]:
  raw=base.support_probes(point,angle)
  for probe in raw['probes']:
   if probe['hit']:
    face=probe['referenceCellID'];pos=np.searchsorted(ids,face);probe['inFrozenGroundIDs']=bool(pos<len(ids) and ids[pos]==face)
    cell=base.mesh.GetCell(face);xyz=np.array([base.mesh.GetPoint(cell.GetPointId(j)) for j in range(3)]);model=xyz@inverse[:3,:3].T+inverse[:3,3];probe['triangleModelXYZ']=model.tolist();probe['triangleEntirelyInsideFrozenEvaluationBounds']=bool(np.all(model>=bounds[0]) and np.all(model<=bounds[1]))
   x,z=probe['modelXZ'];probe['xzInsideFrozenEvaluationEnvelope']=bool(bounds[0,0]<=x<=bounds[1,0] and bounds[0,2]<=z<=bounds[1,2])
  queries.append({'label':label,'savedCandidatePointXYZ':point.tolist(),'yawRadians':angle,'raw':raw})
 expected=r['terminal']['support'][-1]
 if i in (16,18):assert queries[-1]['raw']['missingCount']>0
 else:assert queries[-1]['raw']['missingCount']==0 and 10030019 in [p['referenceCellID'] for p in queries[-1]['raw']['probes']]
 rows.append({'episodeIndex':i,'resultSHA256':sha(p/'RESULT.json'),'csvSHA256':sha(p/'ACTUAL_TRACE_PARTIAL.csv'),'unchangedEpisodeTerminalSupport':expected,'queries':queries})
verify(EXPECTED)
out=H/'reviews/SUPPORT_RAY_DIAGNOSTIC.json';assert not out.exists();out.write_text(json.dumps({'scope':'separate evaluator-only full-reference ray query at saved rejected poses; no actor replay or changed episode result','referenceMesh':mi,'frozenManifestSHA256':EXPECTED,'cacheManifestSHA256':sha(H/'CACHE_MANIFEST.json'),'referenceTransformSHA256':hashlib.sha256(T.tobytes()).hexdigest(),'frozenEvaluationBoundsXYZ':bounds.tolist(),'rows':rows,'physicalAuthority':False},indent=2)+'\n');print(json.dumps({'output':str(out),'bytes':out.stat().st_size,'sha256':sha(out)}))
