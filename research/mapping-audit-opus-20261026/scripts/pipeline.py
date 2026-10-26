"""One parameterised diagnostic pipeline so the development room (Koivu) and the holdout room run
IDENTICAL code and thresholds. Planner side never reads the reference; the evaluator section does.

usage: pipeline.py <long_capture_dir> <icp_iphone.json> <gt_mesh.ply> <out_dir> [recast_dir]
Thresholds are the values pre-declared on Koivu before the holdout was opened (see THRESHOLDS).
"""
import sys,os,json,math,time
import numpy as np,octomap
from PIL import Image
from scipy import ndimage

THRESHOLDS=dict(voxel=.05,near_m=2.0,floor_cell=.2,floor_search=(-2.6,-0.4),band_top=1.75,
                stat_min_n=30,stat_min_frames=3,clear_mean_plus3se=.025,clear_tail=.07,obj_mean_minus3se=.010,obj_tail=.15,
                sigma_edges=[0,1.0,1.5,2.0,2.5,3.0,3.5,4.5,8.0],body=(.45,.30),margin=.15,disc=None,ref_low_band=(.015,.30),ref_body_band=(.30,1.80))
THRESHOLDS['disc']=THRESHOLDS['body'][0]/2+THRESHOLDS['margin']
RES=THRESHOLDS['voxel']
LOG=[]
def log(**k):k['t']=round(time.time()-T0,1);LOG.append(k);print(json.dumps(k),flush=True)

def load_frames(d):
    T=json.load(open(os.path.join(d,'transformations.json')))['frames'];return T
def lidar_samples(d,T):
    P=[];F=[];DISC=[]
    for i,f in enumerate(T):
        dep=np.array(Image.open(os.path.join(d,f['depth_file_path'][2:]))).astype(np.float64)*.001
        h,w=dep.shape;rr=np.arange(h);cc=np.arange(w);rs=rr[(rr+15)%4==2];cs=cc[(cc+15)%4==2]
        dd=dep[np.ix_(rs,cs)]
        # depth-discontinuity flag per LiDAR sample: max abs diff to 4 block neighbours > 0.3 m (diagnostic only; nothing removed)
        pad=np.pad(dd,1,mode='edge');jump=np.max(np.stack([np.abs(dd-pad[:-2,1:-1]),np.abs(dd-pad[2:,1:-1]),np.abs(dd-pad[1:-1,:-2]),np.abs(dd-pad[1:-1,2:])]),0)>.3
        R,C=np.meshgrid(rs.astype(np.float64)-.5+.5,cs.astype(np.float64)-.5+.5,indexing='ij')  # block centre = pixel centre of row/col index (rs,cs) +0.5 -> rs+.5 ; here rs already the centre pixel
        rays=np.stack(((C+.5-f['cx'])/f['fl_x'],-(R+.5-f['cy'])/f['fl_y'],-np.ones_like(R)),-1)
        c=np.array(f['transform_matrix']);p=(rays*dd[...,None]).reshape(-1,3)@c[:3,:3].T+c[:3,3]
        v=dd.reshape(-1)>0;P.append(p[v].astype(np.float32));F.append(np.full(v.sum(),i,np.int16));DISC.append(jump.reshape(-1)[v])
    return np.concatenate(P),np.concatenate(F),np.concatenate(DISC)

def level_frame(P,cams):
    lo,hi=THRESHOLDS['floor_search'];zc=np.median(cams[:,2])
    s=(P[:,2]>zc+lo)&(P[:,2]<zc+hi);Q=P[s]
    hist,e=np.histogram(Q[:,2],bins=np.arange(zc+lo,zc+hi,.01));z0=e[np.argmax(hist)]+.005
    Q=Q[np.abs(Q[:,2]-z0)<.12]
    C=THRESHOLDS['floor_cell'];k=np.floor(Q[:,:2]/C).astype(int);key=k[:,0]*100000+k[:,1]
    o=np.argsort(key);key=key[o];Q=Q[o];u,st,cnt=np.unique(key,return_index=True,return_counts=True);rows=[]
    for kk,s0,n in zip(u,st,cnt):
        if n<300:continue
        z=Q[s0:s0+n,2];h,e=np.histogram(z,bins=np.arange(z0-.12,z0+.12,.005));m=e[np.argmax(h)]+.0025;near=z[np.abs(z-m)<.06]
        if len(near)<200:continue
        rows.append(((kk//100000)*C+C/2,(kk%100000 if kk%100000<50000 else kk%100000-100000)*C+C/2,np.median(near)))
    r=np.array(rows);A=np.c_[r[:,0],r[:,1],np.ones(len(r))];k=np.linalg.lstsq(A,r[:,2],rcond=None)[0]
    n=np.array([-k[0],-k[1],1.]);n/=np.linalg.norm(n);x=np.array([1.,0,0]);x-=n*x.dot(n);x/=np.linalg.norm(x);y=np.cross(n,x)
    R=np.stack((x,y,n));t=-R@np.array([0,0,k[2]])
    log(stage='floor',cells=len(r),tilt_deg=float(np.degrees(np.arctan(np.hypot(k[0],k[1])))),floor_z=float(k[2]),resid_std=float(np.std(r[:,2]-A@k)))
    return R,t

def fuse(Pl,Fs,Cl,maxrange):
    tree=octomap.OcTree(RES);b=np.searchsorted(Fs,np.arange(len(Cl)+1))
    for i in range(len(Cl)):tree.insertPointCloud(Pl[b[i]:b[i+1]].astype(np.float64),Cl[i],maxrange=maxrange)
    tree.updateInnerOccupancy();occ,emp=tree.extractPointCloud();return occ,emp

def grid(occ,free,lo,shape):
    st=np.zeros(shape,np.int8)
    for pts,v in ((free,1),(occ,2)):
        k=np.floor(pts/RES+1e-6).astype(int)-lo;m=np.all((k>=0)&(k<shape),1);k=k[m];st[k[:,0],k[:,1],k[:,2]]=v
    return st

def policy_d1(A,N,z0):
    L=int(round(THRESHOLDS['band_top']/RES))
    sup=A[:,:,z0]==2;deep=(A[:,:,:z0-1]==2).any(2);dipN=N[:,:,z0-1]==2
    l1A=A[:,:,z0+1];l1N=N[:,:,z0+1];low1=(l1N==2)|((l1A==2)&(l1N!=1));lowUnres=(l1N==0)&(l1A!=2)
    body=A[:,:,z0+2:z0+L+1];bodyN=N[:,:,z0+2:z0+L+1];hi=((body==2)|(bodyN==2)).any(2);hiUnk=((body==0)&(bodyN==0)).any(2)
    blocked=~sup|deep|dipN|low1|hi|hiUnk|((l1A==0)&(l1N==0));walk=~blocked
    return dict(support=sup,deepBelow=deep,nearDip=dipN,low1=low1,lowUnresolvedFlag=lowUnres&walk,highObstacle=hi,highUnknown=hiUnk,walk=walk)

def frame_offsets(h,F,P,nfr):
    fl=np.abs(h)<.08;k=np.floor(P[fl,:2]/RES).astype(int);key=k[:,0]*100000+k[:,1];hf=h[fl];ff=F[fl]
    u,inv=np.unique(key,return_inverse=True);o=np.argsort(inv);invs=inv[o];hs=hf[o];b=np.searchsorted(invs,np.arange(len(u)+1))
    cons=np.array([np.median(hs[b[i]:b[i+1]]) for i in range(len(u))]);res=hf-cons[inv]
    off=np.array([np.median(res[ff==j]) if (ff==j).sum()>500 else 0. for j in range(nfr)]);return off

def lowband_stat(Pl,F,Cl,D,lo,H,W,off):
    T=THRESHOLDS;h=Pl[:,2]-RES/2-off[F];rng=np.linalg.norm(Pl-Cl[F],axis=1)
    band=(h>-.10)&(h<.25);i=np.floor(Pl[band,0]/RES).astype(int)-lo[0];j=np.floor(Pl[band,1]/RES).astype(int)-lo[1]
    ok=(i>=0)&(i<H)&(j>=0)&(j<W);i,j=i[ok],j[ok];hb=h[band][ok];rb=rng[band][ok];fb=F[band][ok];col=i*W+j
    cal=(D['walk']&~D['lowUnresolvedFlag']).ravel()[col];edges=np.array(T['sigma_edges']);sig=[]
    for a,b in zip(edges[:-1],edges[1:]):
        m=cal&(rb>=a)&(rb<b);x=hb[m];sig.append(1.4826*np.median(np.abs(x-np.median(x))) if m.sum()>500 else np.nan)
    sig=np.array(sig);sig=np.where(np.isfinite(sig),sig,np.nanmax(sig));s_i=sig[np.clip(np.searchsorted(edges,rb,side='right')-1,0,len(sig)-1)];w=1/s_i**2
    n=np.bincount(col,minlength=H*W);Sw=np.bincount(col,weights=w,minlength=H*W);Swh=np.bincount(col,weights=w*hb,minlength=H*W)
    nfr=np.zeros(H*W,int);u=np.unique(col*1000+fb);np.add.at(nfr,u//1000,1)
    with np.errstate(invalid='ignore',divide='ignore'):mean=Swh/Sw;se=1/np.sqrt(Sw)
    tail=np.bincount(col,weights=(hb>.025+2*s_i).astype(float),minlength=H*W)/np.maximum(n,1)
    enough=(n>=T['stat_min_n'])&(nfr>=T['stat_min_frames'])
    clear=enough&(mean+3*se<T['clear_mean_plus3se'])&(tail<T['clear_tail']);obj=enough&((mean-3*se>T['obj_mean_minus3se'])|(tail>T['obj_tail']))
    state=np.full(H*W,'unresolved',dtype='U10');state[clear]='clear';state[obj]='object'
    log(stage='stat',sigma_cm=np.round(sig*100,2).tolist())
    return state.reshape(H,W),mean.reshape(H,W),n.reshape(H,W),tail.reshape(H,W)

def ref_columns(icp,ply,R,t,lo,H,W):
    A=np.array(json.load(open(icp))['gt_transformation']);Ainv=np.linalg.inv(A)
    with open(ply,'rb') as f:
        hdr=b''
        while not hdr.endswith(b'end_header\n'):hdr+=f.readline()
        lines=hdr.decode().split('\n');nv=int([l for l in lines if l.startswith('element vertex')][0].split()[-1])
        props=[l.split() for l in lines if l.startswith('property') and 'list' not in l]
        tm={'double':'<f8','float':'<f4','uchar':'u1','uint8':'u1','int':'<i4','uint':'<u4'}
        dt=np.dtype([(q[2],tm[q[1]]) for q in props]);V=np.fromfile(f,dtype=dt,count=nv);V=np.c_[V['x'],V['y'],V['z']].astype(np.float64)
    P=(V@Ainv[:3,:3].T+Ainv[:3,3])@R.T+t+[0,0,RES/2];h=P[:,2]-RES/2
    i=np.floor(P[:,0]/RES).astype(int)-lo[0];j=np.floor(P[:,1]/RES).astype(int)-lo[1];ok=(i>=0)&(i<H)&(j>=0)&(j<W);col=(i*W+j)[ok];h=h[ok]
    n=np.bincount(col,minlength=H*W)
    def bandmax(a,b):
        m=(h>=a)&(h<b);out=np.full(H*W,-np.inf);np.maximum.at(out,col[m],h[m]);return out
    lowmax=bandmax(*THRESHOLDS['ref_low_band']);bodymax=bandmax(*THRESHOLDS['ref_body_band'])
    fl=(h>-.06)&(h<.06);fh=np.bincount(col[fl],weights=h[fl],minlength=H*W)/np.maximum(np.bincount(col[fl],minlength=H*W),1);fh[np.bincount(col[fl],minlength=H*W)==0]=np.nan
    log(stage='ref',vertices=int(nv),scale=float(np.linalg.svd(A[:3,:3],compute_uv=False)[0]),ref_floor_vs_plane_cm_p5_50_95=np.round(np.nanpercentile(fh*100,[5,50,95]),2).tolist())
    return dict(n=n.reshape(H,W),low_max=lowmax.reshape(H,W),body_max=bodymax.reshape(H,W),floor_h=fh.reshape(H,W))

def score(mask,ref):
    cov=ref['n']>0;m=mask&cov;n=int(m.sum())
    return dict(n=n,noRefCov=int((mask&~cov).sum()),refLow25=int((ref['low_max'][m]>=.025).sum()),refLow40=int((ref['low_max'][m]>=.04).sum()),refBody=int((ref['body_max'][m]>-np.inf).sum()))

def routes(mask,lo,recast_dir,label):
    sys.path.insert(0,recast_dir);sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
    import routes_rect as RR
    import io,contextlib
    buf=io.StringIO()
    with contextlib.redirect_stdout(buf):
        np.savez('policyD.npz',lo=lo);RR.run(mask,label)
    out=buf.getvalue().strip();print(out);return out

def main():
    global T0;T0=time.time()
    d,icp,ply,out=sys.argv[1:5];recast=sys.argv[5] if len(sys.argv)>5 else None;os.makedirs(out,exist_ok=True);os.chdir(out)
    T=load_frames(d);cams=np.array([f['transform_matrix'] for f in T])[:,:3,3]
    P,F,DISC=lidar_samples(d,T);log(stage='samples',frames=len(T),samples=int(len(P)),discontinuityFraction=float(DISC.mean()))
    R,t=level_frame(P,cams);Pl=(P@R.T+t+[0,0,RES/2]).astype(np.float32);Cl=cams@R.T+t+[0,0,RES/2]
    o=np.argsort(F,kind='stable');Pl=Pl[o];F=F[o];DISC=DISC[o]
    occA,freeA=fuse(Pl,F,Cl,-1.);occN,freeN=fuse(Pl,F,Cl,THRESHOLDS['near_m']);log(stage='fusion',occAll=len(occA),freeAll=len(freeA),occNear=len(occN),freeNear=len(freeN))
    allk=np.floor(np.r_[occA,freeA]/RES+1e-6).astype(int);lo=allk.min(0);hi=allk.max(0);lo[2]=-4;hi[2]=int(round(THRESHOLDS['band_top']/RES))+1;shape=hi-lo+1
    A=grid(occA,freeA,lo,shape);N=grid(occN,freeN,lo,shape);z0=-lo[2];H,W=shape[:2]
    D=policy_d1(A,N,z0);log(stage='D1',**{k:int(v.sum()) for k,v in D.items()})
    off=frame_offsets(Pl[:,2]-RES/2,F,Pl,len(T));log(stage='frameOffsets_cm',p5_50_95=np.round(np.percentile(off*100,[5,50,95]),2).tolist(),maxAbs=float(np.max(np.abs(off))*100))
    state,mean,n,tail=lowband_stat(Pl,F,Cl,D,lo,H,W,off)
    walk=D['walk'];flag=D['lowUnresolvedFlag']
    masks={'d1Permissive':walk,'d1Strict':walk&~flag,'statClearOnly':walk&(state=='clear'),'statObjectBlocked':walk&(state!='object')}
    counts={k:int(v.sum()) for k,v in masks.items()};counts['statStates_walk']={s:int(((state==s)&walk).sum()) for s in ('clear','object','unresolved')};counts['statStates_flagged']={s:int(((state==s)&walk&flag).sum()) for s in ('clear','object','unresolved')}
    log(stage='walk',**counts)
    # discontinuity provenance of high obstacles (diagnostic)
    ref=ref_columns(icp,ply,R,t,lo,H,W)
    cov=ref['n']>0;refgeom=(ref['low_max']>-np.inf)|(ref['body_max']>-np.inf)
    sc={k:score(v,ref) for k,v in masks.items()}
    sc['statObject']=score((state=='object')&(walk|(D['low1']&D['support']&~D['highObstacle'])),ref)
    sc['d1HighObstacleSupported']=score(D['highObstacle']&D['support'],ref)
    obs=D['highObstacle']|D['low1'];lab,k=ndimage.label(obs,structure=np.ones((3,3)));sz=np.bincount(lab.ravel());sc['isolatedSpecks']=score((sz[lab]<=3)&obs,ref)
    falseHi=D['highObstacle']&D['support']&cov&~refgeom;sc['falseHighObstacleColumns']=int(falseHi.sum())
    # reference-only walk and feasibility
    rw=cov&np.isfinite(ref['floor_h'])&~refgeom;lab,k=ndimage.label(rw,structure=np.ones((3,3)));s=np.bincount(lab.ravel());s[0]=0;rw=lab==np.argmax(s)
    sc['refWalk']=int(rw.sum());sc['refWalkPhoneBlocked']=int((rw&~walk).sum());sc['phoneWalkRefNot']=int((walk&~rw&cov).sum())
    log(stage='score',**sc)
    np.savez('pipeline_out.npz',lo=lo,R=R,t=t,state=state,mean=mean,n=n,tail=tail,refWalk=rw,**{k:v for k,v in D.items()},**{'ref_'+k:v for k,v in ref.items()})
    if recast:
        for k,m in masks.items():routes(m,lo,recast,f'{k}')
        routes(rw,lo,recast,'REFERENCE-ONLY (evaluator geometry, not a planner map)')
    json.dump(dict(thresholds=THRESHOLDS,log=LOG),open('PIPELINE_RECEIPT.json','w'),indent=1,default=str)
if __name__=='__main__':main()
