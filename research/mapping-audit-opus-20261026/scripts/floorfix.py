"""Floor-constrained per-frame correction, validated on held-out non-floor geometry.

Rules fixed before running:
- Flag a frame if its own robust floor plane (LiDAR-native samples <=4 m, +-15 cm of the consensus plane, in the
  level frame) has |offset at centroid| > 2.5 cm or tilt > 1.2 deg.
- Candidate correction for a flagged frame: the 3-DOF rigid motion (roll, pitch about the frame's floor centroid,
  plus vertical shift) that maps its floor plane onto the consensus plane. No yaw / horizontal change: the floor
  cannot observe those.
- Validation uses only that frame's NON-floor points (0.20-2.2 m) against non-floor points of UNFLAGGED frames at
  least 25 frames away (correction never sees them): median nearest-neighbour distance, 2 cm voxels.
- Accept the correction only if it reduces that distance by >= 10 % AND >= 2 mm. Otherwise keep the recorded
  pose and list the frame as pose-inconsistent (for gating; its observations are not deleted).
- Unflagged frames are never changed.
usage: floorfix.py <long_capture_dir> <out_dir>
"""
import sys,os,json,time
import numpy as np
from scipy.spatial import cKDTree
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
import pipeline as PL
RULE=dict(flag_offset=.025,flag_tilt=1.2,nonfloor=(.20,2.2),max_range=4.0,min_gap=25,accept_rel=.10,accept_abs=.002,voxel=.02)

def floor_fit(pl,rng):
    m=(np.abs(pl[:,2])<.15)&(rng<RULE['max_range']);q=pl[m]
    if len(q)<800 or np.ptp(q[:,0])<.8 or np.ptp(q[:,1])<.8:return None
    w=np.ones(len(q),bool)
    for it in range(6):
        A=np.c_[q[w,0],q[w,1],np.ones(w.sum())];k=np.linalg.lstsq(A,q[w,2],rcond=None)[0]
        r=q[:,2]-(q[:,0]*k[0]+q[:,1]*k[1]+k[2]);w=np.abs(r)<max(.02,3*1.4826*np.median(np.abs(r[w])))
        if w.sum()<500:return None
    cx,cy=np.median(q[w,0]),np.median(q[w,1])
    return dict(k=k,c=np.array([cx,cy,k[0]*cx+k[1]*cy+k[2]]),tilt=float(np.degrees(np.arctan(np.hypot(k[0],k[1])))),offset=float(k[0]*cx+k[1]*cy+k[2]))

def correction(fit):
    n=np.array([-fit['k'][0],-fit['k'][1],1.]);n/=np.linalg.norm(n);z=np.array([0,0,1.])
    v=np.cross(n,z);s=np.linalg.norm(v);c=n@z
    Rm=np.eye(3) if s<1e-12 else np.eye(3)+np.array([[0,-v[2],v[1]],[v[2],0,-v[0]],[-v[1],v[0],0]])+(lambda K:K@K)(np.array([[0,-v[2],v[1]],[v[2],0,-v[0]],[-v[1],v[0],0]]))*((1-c)/s**2)
    p=fit['c'];M=np.eye(4);M[:3,:3]=Rm;M[:3,3]=p-Rm@p;M[2,3]-=p[2]   # rotate about centroid, then drop centroid to z=0
    return M

def voxel(p,v):
    k=np.floor(p/v).astype(np.int64);_,i=np.unique(k,axis=0,return_index=True);return p[i]

def main():
    d,out=sys.argv[1:3];os.makedirs(out,exist_ok=True);PL.T0=time.time()
    J=json.load(open(os.path.join(d,'transformations.json')));T=J['frames'];n=len(T);C0=np.array([f['transform_matrix'] for f in T])
    P,F,_=PL.lidar_samples(d,T);R,t=PL.level_frame(P,C0[:,:3,3]);L=np.eye(4);L[:3,:3]=R;L[:3,3]=t;Li=np.linalg.inv(L)
    o=np.argsort(F,kind='stable');P=P[o];F=F[o];b=np.searchsorted(F,np.arange(n+1))
    lvl=[P[b[i]:b[i+1]]@R.T+t for i in range(n)];cams=C0[:,:3,3]@R.T+t
    fits={};flag=set()
    for i in range(n):
        rng=np.linalg.norm(lvl[i]-cams[i],axis=1);f=floor_fit(lvl[i],rng)
        if f:fits[i]=f
        if f and (abs(f['offset'])>RULE['flag_offset'] or f['tilt']>RULE['flag_tilt']):flag.add(i)
    nf=[voxel(x[(x[:,2]>RULE['nonfloor'][0])&(x[:,2]<RULE['nonfloor'][1])&(np.linalg.norm(x-cams[i],axis=1)<RULE['max_range'])],RULE['voxel']) for i,x in enumerate(lvl)]
    unflagged=[i for i in range(n) if i not in flag]
    decisions={};C1=C0.copy()
    for i in sorted(flag):
        tgt=[j for j in unflagged if abs(j-i)>=RULE['min_gap']]
        tree=cKDTree(np.concatenate([nf[j] for j in tgt]))
        if len(nf[i])<300:decisions[i]=dict(decision='kept-recorded',reason='too few non-floor points');continue
        M=correction(fits[i]);src=nf[i];src2=src@M[:3,:3].T+M[:3,3]
        d0=float(np.median(tree.query(src)[0]));d1=float(np.median(tree.query(src2)[0]))
        ok=(d0-d1)>=max(RULE['accept_rel']*d0,RULE['accept_abs'])
        decisions[i]=dict(decision='corrected' if ok else 'kept-recorded:pose-inconsistent',offset_cm=round(fits[i]['offset']*100,2),tilt_deg=round(fits[i]['tilt'],2),nonfloorNN_mm_before=round(d0*1000,1),nonfloorNN_mm_after=round(d1*1000,1))
        if ok:C1[i]=Li@M@L@C0[i]
    acc=[i for i,v in decisions.items() if v['decision']=='corrected'];rej=[i for i,v in decisions.items() if v['decision']!='corrected']
    PL.log(stage='floorfix',framesWithFloorFit=len(fits),flagged=len(flag),corrected=len(acc),keptPoseInconsistent=len(rej),noFloorFit=n-len(fits))
    J2=dict(J);J2['frames']=[dict(f,transform_matrix=C1[i].tolist()) for i,f in enumerate(T)];J2['pose_refinement']=dict(method='floor-constrained 3-DOF per-frame correction validated on held-out non-floor geometry',rules=RULE)
    json.dump(J2,open(os.path.join(out,'transformations.json'),'w'))
    for sub in ('depth','images'):
        if not os.path.exists(os.path.join(out,sub)):os.symlink(os.path.join(os.path.abspath(d),sub),os.path.join(out,sub))
    json.dump(dict(rules=RULE,log=PL.LOG,flagged=sorted(flag),corrected=sorted(acc),poseInconsistent=sorted(rej),decisions={str(k):v for k,v in decisions.items()}),open(os.path.join(out,'FLOORFIX_RECEIPT.json'),'w'),indent=1)
    d0=np.array([v['nonfloorNN_mm_before'] for v in decisions.values() if 'nonfloorNN_mm_before' in v]);d1=np.array([v['nonfloorNN_mm_after'] for v in decisions.values() if 'nonfloorNN_mm_after' in v])
    print('non-floor NN distance mm over flagged frames: before p50',np.median(d0),' after p50',np.median(d1),' improved',int((d1<d0).sum()),'of',len(d0))
if __name__=='__main__':main()
