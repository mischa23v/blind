"""Evaluator-only immutable stage59 floor IDs for one predeclared source pair."""
from pathlib import Path
import os,json,sys,time,gzip
for k in('OPENBLAS_NUM_THREADS','OMP_NUM_THREADS','MKL_NUM_THREADS'):os.environ[k]='1'
import numpy as np
from runtime import H,sha,save,verify
from loop_map import load_plan
import physics_primitives as motion
from oriented_container import OrientedReferenceContainer,BodyGeometry
from ground_setup import shared_ground, _resource
GroundSupportUnavailable=_resource.GroundSupportUnavailable
class InitialSupportRejected(Exception):pass
from local_support import validate_support_pose

def main(expected,index):
 verify(expected);matrix=json.loads((H/'MATRIX.json').read_text());row=matrix['plans'][index];assert row['pairIndex']==index
 plan=load_plan(H/row['path'],row['sha256']);out=H/'caches'/f'pair-{index:02d}';out.mkdir(parents=True,exist_ok=False);start=time.monotonic()
 result={'pairIndex':index,'planSHA256':row['sha256'],'sourceQuerySHA256':plan['sourceQuerySHA256'],'status':'cacheNotPrepared','movementExecuted':False,'physicalAuthority':False,'floorPolicy':'unchanged stage59 classifier, nine probes at original source start and source tangent yaw; no eligible-start search','initialYawRadians':plan['initialYawRadians'],'originalStart':plan['start']}
 try:
  runtime=motion.serial_vtk();surface,mi,reader=motion.load_surface()
  frames=json.loads((H/'inputs/PHONE_FRAME_METADATA_ONLY.json').read_text())['frames']['original'];meta={k:np.array(frames[k])for k in('R','t')};A=np.array(json.loads((H/'inputs/icp_iphone.json').read_text())['gt_transformation']);T=motion.transform(meta,A)
  base=OrientedReferenceContainer(surface,T,BodyGeometry(width=.45,depth=.30,height=1.6,horizontal_margin=0.));raw=base.support_probes(np.array(plan['start']),plan['initialYawRadians']);numeric=motion.support_check(raw);result.update(initialSupport=raw,numericInitialSupport=numeric,referenceMesh=mi,runtime=runtime)
  if not numeric['acceptedFiniteSupportModel']:raise InitialSupportRejected('original source-start support rejected; no replacement')
  validate_support_pose(raw,np.array(plan['start']),plan['initialYawRadians'])
  seeds=[int(p['referenceCellID'])for p in raw['probes']];points=[[p['modelXZ'][0],p['modelHeightY'],p['modelXZ'][1]]for p in raw['probes']]
  ground=shared_ground(base,[np.array(plan['originalFramePath'])],seeds,points,lambda r:print(json.dumps({'phase':'candidateQuery',**r}),flush=True))
  expected_bounds=np.asarray(plan['sourceFloorEvaluationBoundsXYZ']);observed=np.asarray(ground.receipt['patchGameBounds']).reshape(3,2).T
  if not np.array_equal(expected_bounds,observed):raise ValueError('source-derived bounds mismatch')
  fixed=json.loads((H/'HISTORICAL_SELECTED_PLAN.json').read_text())['floorPolicy']['fixedPlaneCoefficients'];fits=ground.receipt.pop('patchFits')
  with gzip.open(out/'PATCH_FITS.json.gz','wt')as f:json.dump(fits,f,separators=(',',':'))
  np.savez_compressed(out/'GROUND_IDS.npz',groundIDs=ground.ground_cell_ids)
  result.update(status='membershipReady',groundCells=len(ground.ground_cell_ids),seedIDs=seeds,seedPoints=points,groundReceipt=ground.receipt,membershipSHA256=sha(out/'GROUND_IDS.npz'),patchFitsSHA256=sha(out/'PATCH_FITS.json.gz'),referenceTransformSHA256=sha_transform(T),fixedActivePlane=fixed,diagnosticMembershipBroadPlane=ground.plane_coefficients.tolist(),activeHeightLaw='local observed max9 during movement; fixed plane provenance only',referenceInputsNeverSentToPlanner=True,sourceStartNeverChanged=True)
 except InitialSupportRejected as e:result.update(status='invalidInitialSupport',reason=repr(e))
 except GroundSupportUnavailable as e:result.update(status='membershipUnavailable',reason=repr(e),details=getattr(e,'details',{}),classificationUnknownNotInvalidStart=True)
 except Exception as e:result.update(status='cacheError',reason=repr(e),details=getattr(e,'details',{}),infrastructureFailureNotInvalidStart=True)
 result['wallSeconds']=time.monotonic()-start;save(out/'RESULT.json',result);verify(expected);print(json.dumps({'pairIndex':index,'status':result['status'],'wallSeconds':result['wallSeconds']}),flush=True)
def sha_transform(t):
 import hashlib
 return hashlib.sha256(t.tobytes()).hexdigest()
if __name__=='__main__':main(sys.argv[1],int(sys.argv[2]))
