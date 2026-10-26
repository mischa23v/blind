"""Three bounded rigid ICP comparisons using non-floor points only for fitting.

Phone-only diagnostic; never modifies poses or supplies a movement map.
"""
import argparse,json,math,time
from pathlib import Path
import numpy as np
from PIL import Image
import open3d as o3d
from local_support import paths,load,dump,sha,funcs

def main(ws,out):
    began=time.monotonic();packet,branch,diag=paths(ws)
    poses=load(ws/'prepared/transformations.json')['frames'];fits=load(diag/'phone-plane-fit-01/run-01/result/RESULT.json')['frames']
    transforms=np.array([f['transform_matrix']for f in poses]);cams=transforms[:,:3,3]
    meta=np.load(branch/'derived/pipeline-outputs/koivu_5cm_v2_pipeline2_out.npz');R,t=meta['R'],meta['t']
    project=funcs(diag/'western_depth_residuals.py',['project'],{'np':np})['project']
    selected=[]
    for source in (61,62,63):
        valid=np.array([r['valid']for r in fits]);different=abs(np.arange(len(poses))-source)>=30
        direction=transforms[:,:3,2]@transforms[source,:3,2];distance=np.linalg.norm(cams-cams[source],axis=1)
        candidates=np.flatnonzero(valid&different&(direction>math.cos(math.radians(60))))
        if not len(candidates):raise ValueError('No independently viewed target')
        target=int(candidates[np.argmin(distance[candidates])]);selected.append(dict(source=source,target=target,cameraDistance=float(distance[target]),viewAngleDegrees=float(np.degrees(np.arccos(np.clip(direction[target],-1,1))))))
    # Freeze target choice before any registration result; no floor-height closeness selection.
    dump(out/'REGISTRATION_FROZEN.json',dict(sourceSHA256=sha(Path(__file__)),pairs=selected,
        sourceFrames=[61,62,63],targetRule='nearest camera among valid-floor frames at least 30 indices apart and optical axes within 60 degrees',
        maximumCorrespondenceDistanceMetres=.20,iterations=50,voxelMetres=.05,withScaling=False,
        fitPointSelection='original global level height >0.2 m and camera range <=4 m',floorUsedForFitting=False,
        mapOrPoseUpdatesAllowed=False))
    rows=[]
    def points(i):
        f=poses[i];d=ws/'prepared/depth'/Path(f['depth_file_path']).name
        p=project(np.asarray(Image.open(d)),f)[0].astype(float);q=p@R.T+t
        ranges=np.linalg.norm(p-cams[i],axis=1);nonfloor=q[(q[:,2]>.2)&(ranges<=4)]
        floor=q[(abs(q[:,2])<=.12)&(ranges<=4)]
        cloud=o3d.geometry.PointCloud(o3d.utility.Vector3dVector(nonfloor)).voxel_down_sample(.05)
        return cloud,floor,sha(d)
    reg=o3d.pipelines.registration
    for pair in selected:
        i,j=pair['source'],pair['target'];source,floor,hs=points(i);target,_,ht=points(j)
        before=reg.evaluate_registration(source,target,.20,np.eye(4))
        result=reg.registration_icp(source,target,.20,np.eye(4),reg.TransformationEstimationPointToPoint(with_scaling=False),reg.ICPConvergenceCriteria(max_iteration=50))
        reverse=reg.registration_icp(target,source,.20,np.eye(4),reg.TransformationEstimationPointToPoint(with_scaling=False),reg.ICPConvergenceCriteria(max_iteration=50))
        T=result.transformation;plane=np.array(fits[j]['planeABCD']);after_floor=floor@T[:3,:3].T+T[:3,3]
        pre=floor@plane[:3]+plane[3];post=after_floor@plane[:3]+plane[3]
        cycle=reverse.transformation@T
        row={**pair,'sourceDepthSHA256':hs,'targetDepthSHA256':ht,'sourceFitPoints':len(source.points),'targetFitPoints':len(target.points),
            'nonfloorBeforeFitness':float(before.fitness),'nonfloorBeforeRMSE':float(before.inlier_rmse),'nonfloorAfterFitness':float(result.fitness),'nonfloorAfterRMSE':float(result.inlier_rmse),
            'rigidCorrection':T.tolist(),'rotationDegrees':float(np.degrees(np.arccos(np.clip((np.trace(T[:3,:3])-1)/2,-1,1)))),
            'translationNormMetres':float(np.linalg.norm(T[:3,3])),'rotationSingularValues':np.linalg.svd(T[:3,:3],compute_uv=False).tolist(),
            'reverseCycleTranslationMetres':float(np.linalg.norm(cycle[:3,3])),
            'floorMedianSignedResidualBeforeMetres':float(np.median(pre)),'floorMedianSignedResidualAfterMetres':float(np.median(post)),
            'floorMedianAbsoluteResidualBeforeMetres':float(np.median(abs(pre))),'floorMedianAbsoluteResidualAfterMetres':float(np.median(abs(post))),
            'limitation':'Per-view candidate floor was excluded from registration but target plane is a saved broad fit, not physical truth; ICP local minima, overlap and plane extrapolation remain possible.'}
        rows.append(row);print(json.dumps(row),flush=True)
    dump(out/'REGISTRATION_DIAGNOSTIC.json',dict(Open3D=o3d.__version__,rows=rows,wallSeconds=time.monotonic()-began,scaleChanged=False,posesChanged=False,FAROUsed=False,adoptedForMapping=False))

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--audit-root',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args();main(a.audit_root.resolve(),a.out.resolve())
