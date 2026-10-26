"""Acceptance check for refined poses (decided before running posegraph):
 1) remove the global rigid gauge (Kabsch on camera centres + mean rotation) and report residual per-frame change;
 2) per-frame floor planes (floor was NOT used by the registration) before vs after, in each pose set's own level frame;
 3) previously-consistent frames that become inconsistent must be <= 2 % of them.
usage: validate_poses.py <orig_long_capture> <refined_dir>"""
import sys,os,json,numpy as np
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
import pipeline as PL
from cause import floor_fit
from PIL import Image
PL.T0=0
def per_frame(d):
  T=json.load(open(d+'/transformations.json'))['frames'];C=np.array([f['transform_matrix'] for f in T])
  P,F,_=PL.lidar_samples(d,T);R,t=PL.level_frame(P,C[:,:3,3])
  rows={}
  b=np.searchsorted(F,np.arange(len(T)+1)) if np.all(np.diff(F)>=0) else None
  o=np.argsort(F,kind='stable');P=P[o];F=F[o];b=np.searchsorted(F,np.arange(len(T)+1))
  cams=C[:,:3,3]
  for i in range(len(T)):
    pl=P[b[i]:b[i+1]]@R.T+t;rng=np.linalg.norm(pl-(cams[i]@R.T+t),axis=1)
    r=floor_fit(pl,rng)
    if r:rows[i]=r
  return C,rows
def kabsch(A,B):
  ca,cb=A.mean(0),B.mean(0);H=(A-ca).T@(B-cb);U,S,Vt=np.linalg.svd(H);D=np.diag([1,1,np.sign(np.linalg.det(Vt.T@U.T))]);Rm=Vt.T@D@U.T;return Rm,cb-Rm@ca
d0,d1=sys.argv[1:3]
C0,r0=per_frame(d0);C1,r1=per_frame(d1)
Rg,tg=kabsch(C1[:,:3,3],C0[:,:3,3])
c1=C1[:,:3,3]@Rg.T+tg;dT=np.linalg.norm(c1-C0[:,:3,3],axis=1)
dR=[np.degrees(np.arccos(np.clip((np.trace(C0[i,:3,:3].T@(Rg@C1[i,:3,:3]))-1)/2,-1,1))) for i in range(len(C0))]
print('after removing global rigid gauge: residual camera shift cm p50/p90/max',np.round(np.percentile(dT*100,[50,90,100]),2),' rotation deg p50/p90/max',np.round(np.percentile(dR,[50,90,100]),2))
def bad(r):return abs(r['offset_at_centroid'])>.025 or r['tilt']>1.2
common=sorted(set(r0)&set(r1))
o0=np.array([r0[i]['offset_at_centroid'] for i in common]);o1=np.array([r1[i]['offset_at_centroid'] for i in common])
t0=np.array([r0[i]['tilt'] for i in common]);t1=np.array([r1[i]['tilt'] for i in common])
print('frames with floor fit before/after',len(r0),len(r1),' common',len(common))
print('floor offset |cm| p50/p90 before',np.round(np.percentile(np.abs(o0)*100,[50,90]),2),' after',np.round(np.percentile(np.abs(o1)*100,[50,90]),2))
print('floor tilt deg p50/p90 before',np.round(np.percentile(t0,[50,90]),2),' after',np.round(np.percentile(t1,[50,90]),2))
b0=set(i for i in common if bad(r0[i]));b1=set(i for i in common if bad(r1[i]));good0=set(common)-b0
print('inconsistent frames before',len(b0),' after',len(b1),' fixed',len(b0-b1),' newly inconsistent (were good)',len(b1&good0),'of',len(good0),'=%.1f%%'%(100*len(b1&good0)/max(len(good0),1)))
for i in (60,61,62,63,64,116,117,118,119,200,250,30):
  if i in r0 and i in r1:print(f'  frame {i}: offset {r0[i]["offset_at_centroid"]*100:+.2f} -> {r1[i]["offset_at_centroid"]*100:+.2f} cm, tilt {r0[i]["tilt"]:.2f} -> {r1[i]["tilt"]:.2f} deg')
json.dump(dict(residualShift_cm=np.percentile(dT*100,[50,90,100]).tolist(),residualRot_deg=np.percentile(dR,[50,90,100]).tolist(),before=len(b0),after=len(b1),newlyBad=len(b1&good0),good0=len(good0),fixed=len(b0-b1),
  absOffset_cm_p50_p90={'before':np.percentile(np.abs(o0)*100,[50,90]).tolist(),'after':np.percentile(np.abs(o1)*100,[50,90]).tolist()},tilt_deg_p50_p90={'before':np.percentile(t0,[50,90]).tolist(),'after':np.percentile(t1,[50,90]).tolist()}),open(d1+'/POSE_VALIDATION.json','w'),indent=1)
