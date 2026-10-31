"""One frozen pair × condition, supplied synthetic pose, unchanged stage76 movement."""
from pathlib import Path
import os,json,sys,time,hashlib
for k in('OPENBLAS_NUM_THREADS','OMP_NUM_THREADS','MKL_NUM_THREADS'):os.environ[k]='1'
from runtime import H,sha,save,verify

def main(expected,episode_index):
 verify(expected);matrix=json.loads((H/'MATRIX.json').read_text());schedule=matrix['episodes'][episode_index];assert schedule['episodeIndex']==episode_index;index=schedule['pairIndex'];row=matrix['plans'][index]
 os.environ['FROZEN_EPISODE_SESSION_ID']=f"stage84-pair{index}-{schedule['conditionID']}-seed{schedule['seed']}"
 import numpy as np
 import loop_episode as e
 from pose_delivery import condition_by_id
 from loop_map import load_plan
 from ground_classifier_resource import GroundSupport
 from oriented_container import OrientedReferenceContainer,BodyGeometry
 frozen_caches=json.loads((H/'CACHE_MANIFEST.json').read_text());assert frozen_caches['evaluatorManifestSHA256']==expected
 for p,h in frozen_caches['files'].items():
  if sha(H/p)!=h:raise ValueError('changed immutable evaluator cache: '+p)
 out=H/'episodes'/f'episode-{episode_index:03d}'/'result';out.mkdir(parents=True,exist_ok=False);cache=H/'caches'/f'pair-{index:02d}'/'RESULT.json';cache_record=frozen_caches['records'][index];assert cache_record['pairIndex']==index;r=json.loads(cache.read_text())if cache.exists()else{'status':'cacheError','reason':'cache worker did not produce terminal result'}
 if cache_record['status']=='computeBudgetOrInfrastructureFailure':r={'status':'cacheError','reason':'cache process exceeded budget or failed; partial result not admitted'}
 plan=load_plan(H/row['path'],row['sha256']);start=time.monotonic()
 if r['status']!='membershipReady':
  save(out/'RESULT.json',{'status':{'invalidInitialSupport':'invalidInitialEvaluatorSupport','membershipUnavailable':'evaluatorFloorClassificationUnavailable','cacheError':'evaluatorInfrastructureFailure'}.get(r['status'],'evaluatorCacheNotReady'),'arrival':False,'motionExecuted':False,'actualDistanceMetres':0.,'ticks':0,'cacheStatus':r['status'],'cacheReason':r.get('reason'),'schedule':schedule,'physicalAuthority':False});return
 if r['planSHA256']!=row['sha256']:raise ValueError('wrong pair cache')
 motion=e.motion;runtime=motion.serial_vtk();surface,mi,reader=motion.load_surface();frames=json.loads((H/'inputs/PHONE_FRAME_METADATA_ONLY.json').read_text())['frames']['original'];meta={k:np.array(frames[k])for k in('R','t')};A=np.array(json.loads((H/'inputs/icp_iphone.json').read_text())['gt_transformation']);T=motion.transform(meta,A)
 if hashlib.sha256(T.tobytes()).hexdigest()!=r['referenceTransformSHA256']:raise ValueError('wrong reference registration')
 base=OrientedReferenceContainer(surface,T,BodyGeometry(width=.45,depth=.30,height=1.6,horizontal_margin=0.));plane=np.array(r['fixedActivePlane']);plane.setflags(write=False);tt=np.array(T,copy=True);tt.setflags(write=False)
 with np.load(cache.parent/'GROUND_IDS.npz',allow_pickle=False)as z:ids=z['groundIDs'].copy()
 if ids.ndim!=1 or not len(ids)or not np.all(np.diff(ids)>0)or ids.min()<0 or ids.max()>=mi['triangles']:raise ValueError('invalid frozen original ground IDs')
 ids.setflags(write=False);receipt={**r['groundReceipt'],'planeCoefficientsYEqualsAXPlusBZPlusC':plane.tolist(),'fixedDatumSource':'unchanged original scene plane provenance only','pairIndex':index,'sourceSeedsNotReachedBodyPose':True};ground=GroundSupport(ids,receipt,surface,base.mesh,int(base.mesh.GetMTime()),tt,plane)
 result=e.episode(plan,base,[ground],out,condition_by_id(schedule['conditionID']),schedule['seed']);result.update(schedule=schedule,referenceMesh=mi,runtime=runtime,wallSeconds=time.monotonic()-start,pairPlanSHA256=row['sha256'],cacheResultSHA256=sha(cache),evaluatorManifestSHA256=expected,cacheManifestSHA256=sha(H/'CACHE_MANIFEST.json'),worldOrReferenceNeverSelectsHorizontalRoute=True,sourceROIManuallyAssisted=True,sourceExclusionUnknown=True,physicalWorldGeometryChanged=False,physicalAuthority=False,sourceConfidenceUnavailable=True)
 verify(expected);save(out/'RESULT.json',result);print(json.dumps({k:result[k]for k in('status','arrival','motionExecuted','actualDistanceMetres','ticks')}),flush=True)
if __name__=='__main__':main(sys.argv[1],int(sys.argv[2]))
