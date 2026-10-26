"""Colour-assisted per-frame pose correction (Open3D colored ICP, Park et al. 2017), held-out acceptance.

Rules fixed before running:
- Start from the floor-corrected poses (floorfix). Candidates: frames floorfix flagged (corrected or not).
- Target = coloured points of UNFLAGGED frames with EVEN index, >= 25 frames away. Held-out validation set =
  UNFLAGGED frames with ODD index, >= 25 frames away (never used by the registration).
- Multi-scale coloured ICP (voxel 6 cm then 3 cm), rigid, scale fixed to 1.
- Accept only if (a) median nearest-neighbour distance of the frame's non-floor points (0.20-2.2 m) to the held-out
  set improves by >= 10 % and >= 2 mm, (b) the frame's floor plane afterwards is within 2.5 cm / 1.2 deg of the
  consensus or no worse than before, (c) the correction is <= 30 cm and <= 5 deg. Otherwise keep the pose.
usage: coloricp.py <floorfix_dir (with transformations.json, depth, images)> <out_dir>
"""
import sys,os,json,time,math
import numpy as np,open3d as o3d
from PIL import Image
from scipy.spatial import cKDTree
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
import pipeline as PL
from floorfix import floor_fit
reg=o3d.pipelines.registration
RULE=dict(min_gap=25,scales=[(.06,.12),(.03,.06)],accept_rel=.10,accept_abs=.002,max_trans=.30,max_rot_deg=5.,flag_offset=.025,flag_tilt=1.2,nonfloor=(.20,2.2),max_range=4.0)

def colored_points(d,f,C):
    dep=np.array(Image.open(os.path.join(d,f['depth_file_path'][2:]))).astype(np.float64)*.001
    img=np.asarray(Image.open(os.path.join(d,f['file_path'][2:])).convert('RGB')).astype(np.float64)/255.
    h,w=dep.shape;rr=np.arange(h);cc=np.arange(w);rs=rr[(rr+15)%4==2];cs=cc[(cc+15)%4==2]
    dd=dep[np.ix_(rs,cs)];col=img[np.ix_(rs,cs)].reshape(-1,3)
    R_,C_=np.meshgrid(rs.astype(float),cs.astype(float),indexing='ij')
    rays=np.stack(((C_+.5-f['cx'])/f['fl_x'],-(R_+.5-f['cy'])/f['fl_y'],-np.ones_like(R_)),-1)
    p=(rays*dd[...,None]).reshape(-1,3);r=dd.reshape(-1);m=(r>0)&(r<RULE['max_range'])
    return p[m]@C[:3,:3].T+C[:3,3],col[m]

def pcd(p,c,v):
    x=o3d.geometry.PointCloud(o3d.utility.Vector3dVector(p));x.colors=o3d.utility.Vector3dVector(c);x=x.voxel_down_sample(v)
    x.estimate_normals(o3d.geometry.KDTreeSearchParamHybrid(radius=v*2,max_nn=30));return x

def main():
    d,out=sys.argv[1:3];os.makedirs(out,exist_ok=True);PL.T0=time.time()
    J=json.load(open(os.path.join(d,'transformations.json')));T=J['frames'];n=len(T);C0=np.array([f['transform_matrix'] for f in T])
    ff=json.load(open(os.path.join(d,'FLOORFIX_RECEIPT.json')));flagged=set(ff['flagged'])
    P,F,_=PL.lidar_samples(d,T);R,t=PL.level_frame(P,C0[:,:3,3])
    world=[colored_points(d,T[i],C0[i]) for i in range(n)]
    lv=lambda p:p@R.T+t
    cams=lv(C0[:,:3,3])
    unfl=[i for i in range(n) if i not in flagged]
    decisions={};C1=C0.copy()
    for i in sorted(flagged):
        tg=[j for j in unfl if abs(j-i)>=RULE['min_gap'] and j%2==0];va=[j for j in unfl if abs(j-i)>=RULE['min_gap'] and j%2==1]
        if len(tg)<20 or len(va)<20:decisions[i]=dict(decision='kept',reason='too few target/validation frames');continue
        tp=np.concatenate([world[j][0] for j in tg]);tc=np.concatenate([world[j][1] for j in tg])
        vp=np.concatenate([world[j][0] for j in va]);vl=lv(vp);vnf=vl[(vl[:,2]>RULE['nonfloor'][0])&(vl[:,2]<RULE['nonfloor'][1])]
        vt=cKDTree(vnf[np.unique(np.floor(vnf/.02).astype(np.int64),axis=0,return_index=True)[1]])
        sp,sc=world[i];M=np.eye(4)
        try:
            for v,dist in RULE['scales']:
                s=pcd(sp,sc,v);tgt=pcd(tp,tc,v)
                r=reg.registration_colored_icp(s,tgt,dist,M,reg.TransformationEstimationForColoredICP(),reg.ICPConvergenceCriteria(relative_fitness=1e-6,relative_rmse=1e-6,max_iteration=40))
                M=r.transformation
        except RuntimeError as e:
            decisions[i]=dict(decision='kept',reason='colored ICP failed: '+str(e)[:80]);continue
        ang=math.degrees(math.acos(np.clip((np.trace(M[:3,:3])-1)/2,-1,1)));tr=float(np.linalg.norm(M[:3,3]))
        sl=lv(sp);snf=sl[(sl[:,2]>RULE['nonfloor'][0])&(sl[:,2]<RULE['nonfloor'][1])]
        sp2=sp@M[:3,:3].T+M[:3,3];sl2=lv(sp2);snf2=sl2[(sl2[:,2]>RULE['nonfloor'][0])&(sl2[:,2]<RULE['nonfloor'][1])]
        if len(snf)<300:decisions[i]=dict(decision='kept',reason='too few non-floor points');continue
        d0=float(np.median(vt.query(snf)[0]));d1=float(np.median(vt.query(snf2)[0]))
        cam2=lv((M@C0[i])[:3,3]);f0=floor_fit(sl,np.linalg.norm(sl-cams[i],axis=1));f1=floor_fit(sl2,np.linalg.norm(sl2-cam2,axis=1))
        floor_ok=True
        if f1 is not None:
            good1=abs(f1['offset'])<=RULE['flag_offset'] and f1['tilt']<=RULE['flag_tilt']
            nw=f0 is not None and abs(f1['offset'])<=abs(f0['offset'])+.002 and f1['tilt']<=f0['tilt']+.2
            floor_ok=good1 or nw
        ok=(d0-d1)>=max(RULE['accept_rel']*d0,RULE['accept_abs']) and floor_ok and tr<=RULE['max_trans'] and ang<=RULE['max_rot_deg']
        decisions[i]=dict(decision='corrected' if ok else 'kept',heldoutNN_mm_before=round(d0*1000,1),heldoutNN_mm_after=round(d1*1000,1),trans_cm=round(tr*100,1),rot_deg=round(ang,2),
                          floor_before=None if f0 is None else [round(f0['offset']*100,2),round(f0['tilt'],2)],floor_after=None if f1 is None else [round(f1['offset']*100,2),round(f1['tilt'],2)],floorOK=bool(floor_ok))
        if ok:C1[i]=M@C0[i]
        print(i,decisions[i],flush=True)
    acc=[i for i,v in decisions.items() if v['decision']=='corrected']
    PL.log(stage='coloricp',candidates=len(flagged),corrected=len(acc))
    J2=dict(J);J2['frames']=[dict(f,transform_matrix=C1[i].tolist()) for i,f in enumerate(T)];J2['pose_refinement_2']=dict(method='Open3D colored ICP, held-out odd-frame validation',rules=RULE,open3d=o3d.__version__)
    json.dump(J2,open(os.path.join(out,'transformations.json'),'w'))
    for sub in ('depth','images'):
        if not os.path.exists(os.path.join(out,sub)):os.symlink(os.path.realpath(os.path.join(d,sub)),os.path.join(out,sub))
    ff2=dict(ff);ff2['coloricp']=dict(rules=RULE,corrected=sorted(acc),decisions={str(k):v for k,v in decisions.items()})
    json.dump(ff2,open(os.path.join(out,'FLOORFIX_RECEIPT.json'),'w'),indent=1)
    json.dump(dict(rules=RULE,corrected=sorted(acc),decisions={str(k):v for k,v in decisions.items()},log=PL.LOG),open(os.path.join(out,'COLORICP_RECEIPT.json'),'w'),indent=1)
if __name__=='__main__':main()
