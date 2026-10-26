"""Discriminate cause of view-dependent floor height: per-frame floor plane (tilt, offset) across all 294
frames; whether frames 62-64 are offset on NON-floor surfaces too (rigid pose error) vs a shared
calibration/depth-scale bias. Phone data only; no reference."""
import numpy as np,json,os
from PIL import Image
from scipy.spatial import cKDTree
d=os.environ['KOIVU_LONG_CAPTURE']
T=json.load(open(d+'/transformations.json'))['frames']
o=np.load(os.environ['KOIVU_PIPELINE2_OUT']);R=o['R'];t=o['t']
def frame_pts(i,dcx=0.,dcy=0.,s=1.):
  f=T[i];dep=np.array(Image.open(os.path.join(d,f['depth_file_path'][2:]))).astype(np.float64)*.001*s
  h,w=dep.shape;rr=np.arange(h);cc=np.arange(w);rs=rr[(rr+15)%4==2];cs=cc[(cc+15)%4==2]
  dd=dep[np.ix_(rs,cs)];Rr,Cc=np.meshgrid(rs.astype(float),cs.astype(float),indexing='ij')
  rays=np.stack(((Cc+.5-(f['cx']+dcx))/f['fl_x'],-(Rr+.5-(f['cy']+dcy))/f['fl_y'],-np.ones_like(Rr)),-1)
  c=np.array(f['transform_matrix']);p=(rays*dd[...,None]).reshape(-1,3)@c[:3,:3].T+c[:3,3]
  cam=c[:3,3]@R.T+t;pl=p@R.T+t;rng=dd.reshape(-1)
  return pl,cam,rng,(Rr.reshape(-1),Cc.reshape(-1))
def floor_fit(pl,rng):
  m=(np.abs(pl[:,2])<.15)&(rng<4.0)
  q=pl[m]
  if len(q)<800 or np.ptp(q[:,0])<.8 or np.ptp(q[:,1])<.8:return None
  w=np.ones(len(q),bool)
  for it in range(6):
    A=np.c_[q[w,0],q[w,1],np.ones(w.sum())];k=np.linalg.lstsq(A,q[w,2],rcond=None)[0]
    r=q[:,2]-(q[:,0]*k[0]+q[:,1]*k[1]+k[2]);w=np.abs(r)<max(.02,3*1.4826*np.median(np.abs(r[w])))
    if w.sum()<500:return None
  cx,cy=np.median(q[w,0]),np.median(q[w,1])
  return dict(tilt=float(np.degrees(np.arctan(np.hypot(k[0],k[1])))),offset_at_centroid=float(k[0]*cx+k[1]*cy+k[2]),n=int(w.sum()),resid_mad=float(1.4826*np.median(np.abs(r[w]))),k=k.tolist())
rows=[]
for i in range(len(T)):
  pl,cam,rng,_=frame_pts(i);r=floor_fit(pl,rng)
  if r:r['frame']=i;r['camH']=float(cam[2]);rows.append(r)
tilt=np.array([r['tilt'] for r in rows]);off=np.array([r['offset_at_centroid'] for r in rows]);fr=np.array([r['frame'] for r in rows])
print('frames with floor fit',len(rows),'| tilt deg p10/50/90',np.round(np.percentile(tilt,[10,50,90]),2),'| offset cm p5/50/95',np.round(np.percentile(off*100,[5,50,95]),2))
for j in (60,61,62,63,64,65,66,69,116,117,118,119,150,200):
  r=[x for x in rows if x['frame']==j]
  if r:r=r[0];print(f'  frame {j}: tilt {r["tilt"]:.2f} deg, offset {r["offset_at_centroid"]*100:+.2f} cm, camH {r["camH"]:.2f} m, resid {r["resid_mad"]*1000:.1f} mm, n {r["n"]}')
json.dump(rows,open('per_frame_floor.json','w'))
# correlation of tilt with time: is it bursts (pose glitches) or systematic (calibration)?
bad=fr[(tilt>1.2)|(np.abs(off)>.03)];print('frames tilt>1.2deg or |offset|>3cm:',len(bad),bad.tolist()[:60])
