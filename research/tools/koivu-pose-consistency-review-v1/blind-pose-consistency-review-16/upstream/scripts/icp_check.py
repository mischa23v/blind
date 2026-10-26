"""Rigid-pose test with released Open3D ICP (point-to-plane): align each test frame to a cloud built from
temporally distant frames using ONLY non-floor points (0.20-2.2 m above plane), then measure the frame's
floor offset/tilt before vs after. If the non-floor alignment also removes the floor offset, the frame's
pose (not depth calibration or floor shape) is wrong. Control frames from good periods must stay ~unchanged."""
import numpy as np,json,open3d as o3d,sys
sys.argv=[sys.argv[0]];import cause as C
rows={r['frame']:r for r in json.load(open('per_frame_floor.json'))}
def cloud(frames):
  P=[];
  for i in frames:
    pl,cam,rng,_=C.frame_pts(i);m=(rng<4.0);P.append(pl[m])
  return np.concatenate(P)
def nonfloor(p):return p[(p[:,2]>.20)&(p[:,2]<2.2)]
def floorfit(p):
  m=(np.abs(p[:,2])<.15);q=p[m];w=np.ones(len(q),bool)
  for it in range(6):
    A=np.c_[q[w,0],q[w,1],np.ones(w.sum())];k=np.linalg.lstsq(A,q[w,2],rcond=None)[0];r=q[:,2]-(q[:,0]*k[0]+q[:,1]*k[1]+k[2]);w=np.abs(r)<max(.02,3*1.4826*np.median(np.abs(r[w])))
  cx,cy=np.median(q[w,0]),np.median(q[w,1]);return float(np.degrees(np.arctan(np.hypot(k[0],k[1])))),float(k[0]*cx+k[1]*cy+k[2])
out=[]
tests=[62,61,63,60,118,104,200,150,250,30]
for f in tests:
  others=[j for j in range(0,294,3) if abs(j-f)>25]
  tgt=o3d.geometry.PointCloud(o3d.utility.Vector3dVector(nonfloor(cloud(others))));tgt=tgt.voxel_down_sample(.02);tgt.estimate_normals(o3d.geometry.KDTreeSearchParamHybrid(radius=.08,max_nn=30))
  pl,cam,rng,_=C.frame_pts(f);pl=pl[rng<4.0]
  src=o3d.geometry.PointCloud(o3d.utility.Vector3dVector(nonfloor(pl))).voxel_down_sample(.02)
  reg=o3d.pipelines.registration.registration_icp(src,tgt,.10,np.eye(4),o3d.pipelines.registration.TransformationEstimationPointToPlane(),o3d.pipelines.registration.ICPConvergenceCriteria(max_iteration=60))
  Tm=reg.transformation;pa=pl@Tm[:3,:3].T+Tm[:3,3]
  t0,o0=floorfit(pl);t1,o1=floorfit(pa)
  ang=float(np.degrees(np.arccos(np.clip((np.trace(Tm[:3,:3])-1)/2,-1,1))))
  row=dict(frame=f,fitness=round(reg.fitness,3),rmse_mm=round(reg.inlier_rmse*1000,1),icpRot_deg=round(ang,2),icpTrans_cm=np.round(Tm[:3,3]*100,2).tolist(),floorTilt_before=round(t0,2),floorTilt_after=round(t1,2),floorOffset_before_cm=round(o0*100,2),floorOffset_after_cm=round(o1*100,2))
  out.append(row);print(json.dumps(row),flush=True)
json.dump(out,open('icp_check.json','w'),indent=1)
