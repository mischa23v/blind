"""Pipeline v2: same inputs/evaluator as pipeline.py, adds (a) configurable voxel size, bands in metres,
(b) saved fused clouds, (c) pre-declared 'ungrounded small blob' variant, (d) optional Open3D TSDF
surface comparator. Every variant is scored first on SAFETY (walkable columns touching reference
geometry) and only then on routes. Planner side never reads the reference.

usage: pipeline2.py <long_capture_dir> <icp.json> <gt_mesh.ply> <out_dir> <recast_dir> <res_m> [tsdf]
"""
import sys,os,json,math,time
import numpy as np
from scipy import ndimage
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
import pipeline as PL
from pipeline import load_frames,lidar_samples,level_frame,fuse,frame_offsets,lowband_stat,ref_columns,score,log

RULES=dict(tsdf_volume_note='Uniform volume; Scalable returned empty in open3d-cpu 0.20.0',floor_band=(-.025,.025),low_band=(.025,.075),body_band=(.075,1.775),dip_band=(-.075,-.025),deep_below=-.075,
           ungrounded_max_voxels_at5cm=24,grounded_structure_voxels_at5cm=200,ground_touch_top=.075,
           tsdf_voxel=.025,tsdf_trunc=.08,tsdf_depth_trunc=4.0)

def layers(res,a,b):
    """layer indices k whose span (k-0.5)res..(k+0.5)res lies within [a,b)"""
    k0=int(math.ceil(a/res-.5+1e-9));k1=int(math.floor(b/res-.5-1e-9));return k0,k1

def grid3(occ,free,lo,shape,res):
    st=np.zeros(shape,np.int8)
    for pts,v in ((free,1),(occ,2)):
        k=np.floor(pts/res+1e-6).astype(int)-lo;m=np.all((k>=0)&(k<shape),1);k=k[m];st[k[:,0],k[:,1],k[:,2]]=v
    return st

def band_layers(res,z0,nlayers):
    """Tile layers into floor / low / body / dip / deep by layer-centre height (no gaps, no overlap)."""
    k=np.arange(nlayers)-z0;h=k*res;e=1e-9
    floor=np.abs(h)<=RULES['floor_band'][1]+e
    low=(h>RULES['floor_band'][1]+e)&(h<=RULES['low_band'][1]+e)
    body=(h>RULES['low_band'][1]+e)&(h<=RULES['body_band'][1]+e)
    dip=(h<-RULES['floor_band'][1]-e)&(h>=RULES['dip_band'][0]-e)
    deep=h<RULES['dip_band'][0]-e
    return floor,low,body,dip,deep

def classify(A,N,z0,res,occ_override=None,support_override=None):
    """D1 rules in metre bands. occ_override: optional bool grid replacing 'occupied' evidence in low+body bands
    (used by the TSDF variant and the ungrounded-blob variant); free/unknown coverage always from the OctoMap trees."""
    fl,lw,bd,dp,dpp=band_layers(res,z0,A.shape[2])
    occA=(A==2) if occ_override is None else occ_override;occN=(N==2) if occ_override is None else (occ_override&(N!=0))
    sup=(A[:,:,fl]==2).any(2) if support_override is None else support_override
    deep=(A[:,:,dpp]==2).any(2)
    dipN=(N[:,:,dp]==2).any(2)
    lowN_occ=occN[:,:,lw].any(2);lowA_occ=occA[:,:,lw].any(2);lowN_free=(N[:,:,lw]==1).all(2);lowN_unk=(N[:,:,lw]==0).any(2);lowA_unk=(A[:,:,lw]==0).any(2)
    low1=lowN_occ|(lowA_occ&~lowN_free);lowUnres=lowN_unk&~lowA_occ
    hi=occA[:,:,bd].any(2)|occN[:,:,bd].any(2);hiUnk=((A[:,:,bd]==0)&(N[:,:,bd]==0)).any(2)
    blocked=~sup|deep|dipN|low1|hi|hiUnk|(lowA_unk&lowN_unk);walk=~blocked
    return dict(support=sup,deepBelow=deep,nearDip=dipN,low1=low1,lowUnresolvedFlag=lowUnres&walk,highObstacle=hi,highUnknown=hiUnk,walk=walk)

def ungrounded_mask(A,z0,res):
    """Pre-declared rule: a 26-connected blob of occupied voxels above the floor band that (i) never touches
    the floor/ground-touch band and (ii) has fewer than 'ungrounded_max' voxels and is not part of a
    structure blob (>= 'structure' voxels) is treated as NOT obstacle evidence. Scaled by voxel volume."""
    scale=(0.05/res)**3;small=RULES['ungrounded_max_voxels_at5cm']*scale;bigv=RULES['grounded_structure_voxels_at5cm']*scale
    occ=A==2;lab,k=ndimage.label(occ,structure=np.ones((3,3,3)));size=np.bincount(lab.ravel())
    touch=np.zeros(k+1,bool);top=z0+int(math.floor(RULES['ground_touch_top']/res+1e-9))+1;low=lab[:,:,:top];touch[np.unique(low[low>0])]=True
    ung=~touch&(size<small)&(size<bigv);ung[0]=False
    return ung[lab],dict(blobs=int(k),ungroundedBlobs=int(ung.sum()),ungroundedVoxels=int(size[ung].sum()))

def tsdf_surface(d,T,P_world):
    import open3d as o3d
    from PIL import Image
    I=o3d.pipelines.integration
    lo_=P_world.min(0)-.1;hi_=P_world.max(0)+.1;length=float(np.max(hi_-lo_));vox=RULES['tsdf_voxel'];resn=int(math.ceil(length/vox))
    vol=I.UniformTSDFVolume(length=resn*vox,resolution=resn,sdf_trunc=RULES['tsdf_trunc'],color_type=I.TSDFVolumeColorType.NoColor,origin=lo_)
    flip=np.diag([1.,-1.,-1.,1.]);t0=time.time()
    for f in T:
        dep=np.ascontiguousarray(np.array(Image.open(os.path.join(d,f['depth_file_path'][2:]))).astype(np.uint16));h,w=dep.shape
        rgbd=o3d.geometry.RGBDImage.create_from_color_and_depth(o3d.geometry.Image(np.zeros((h,w,3),np.uint8)),o3d.geometry.Image(dep),depth_scale=1000.,depth_trunc=RULES['tsdf_depth_trunc'],convert_rgb_to_intensity=True)
        K=o3d.camera.PinholeCameraIntrinsic(w,h,f['fl_x'],f['fl_y'],f['cx']-.5,f['cy']-.5)   # half-pixel -> Open3D integer-centre convention
        vol.integrate(rgbd,K,np.linalg.inv(np.array(f['transform_matrix'])@flip))
    P=np.asarray(vol.extract_point_cloud().points)
    log(stage='tsdf',version=o3d.__version__,volume='UniformTSDFVolume',voxel=vox,resolution=resn,trunc=RULES['tsdf_trunc'],surfacePoints=int(len(P)),seconds=round(time.time()-t0,1))
    return P

def down2(mask):
    H,W=mask.shape;H2,W2=H//2,W//2;m=mask[:H2*2,:W2*2].reshape(H2,2,W2,2);return m.all(axis=(1,3))

def run_routes(mask,lo,res,recast,label):
    import io,contextlib,routes_rect as RR
    if res!=.05:
        mask=down2(mask);lo2=np.array([lo[0]//2,lo[1]//2,lo[2]])
    else:lo2=lo
    np.savez('policyD.npz',lo=lo2)
    buf=io.StringIO()
    with contextlib.redirect_stdout(buf):RR.run(mask,label)
    s=buf.getvalue().strip();print(s,flush=True);return s

def main():
    PL.T0=time.time();d,icp,ply,out,recast,res=sys.argv[1:7];res=float(res);tsdf='tsdf' in sys.argv[7:];PL.RES=res;RES=res
    if 'strictfloor' in sys.argv[7:]:RULES['floor_band']=(-.0125,.0125);RULES['strictfloorNote']='floor band = centre layer only; low band starts at the first layer above it'
    os.makedirs(out,exist_ok=True);os.chdir(out)
    T=load_frames(d);cams=np.array([f['transform_matrix'] for f in T])[:,:3,3]
    P,F,DISC=lidar_samples(d,T);log(stage='samples',frames=len(T),samples=int(len(P)),res=res)
    R,t=level_frame(P,cams);Pl=(P@R.T+t+[0,0,RES/2]).astype(np.float32);Cl=cams@R.T+t+[0,0,RES/2]
    o=np.argsort(F,kind='stable');Pl=Pl[o];F=F[o]
    occA,freeA=fuse(Pl,F,Cl,-1.);occN,freeN=fuse(Pl,F,Cl,PL.THRESHOLDS['near_m']);log(stage='fusion',occAll=len(occA),freeAll=len(freeA),occNear=len(occN),freeNear=len(freeN))
    np.savez_compressed('fused_clouds.npz',occA=occA.astype(np.float32),freeA=freeA.astype(np.float32),occN=occN.astype(np.float32),freeN=freeN.astype(np.float32))
    allk=np.floor(np.r_[occA,freeA]/RES+1e-6).astype(int);lo=allk.min(0);hi=allk.max(0);lo[2]=-int(math.ceil(.20/RES));hi[2]=int(math.ceil(1.85/RES));shape=hi-lo+1
    A=grid3(occA,freeA,lo,shape,RES);N=grid3(occN,freeN,lo,shape,RES);z0=-lo[2];H,W=shape[:2]
    variants={}
    D=classify(A,N,z0,RES);variants['D1']=D
    off=frame_offsets(Pl[:,2]-RES/2,F,Pl,len(T))
    state,mean,n,tail=lowband_stat(Pl,F,Cl,D,lo,H,W,off)
    ung,uinfo=ungrounded_mask(A,z0,RES);log(stage='ungrounded',**uinfo)
    occ_ng=(A==2)&~ung;variants['D1_noUngrounded']=classify(A,N,z0,RES,occ_override=occ_ng)
    if tsdf:
        S=tsdf_surface(d,T,P);Sl=S@R.T+t+[0,0,RES/2];k=np.floor(Sl/RES+1e-6).astype(int)-lo;m=np.all((k>=0)&(k<shape),1);k=k[m]
        occT=np.zeros(shape,bool);occT[k[:,0],k[:,1],k[:,2]]=True
        # TSDF floor: columns where TSDF surface lies in the floor band
        variants['TSDF_surface']=classify(A,N,z0,RES,occ_override=occT)
        variants['TSDF_surface']['support']&=occT[:,:,band_layers(RES,z0,shape[2])[0]].any(2)
        variants['TSDF_surface']['walk']&=variants['TSDF_surface']['support']
        np.save('tsdf_surface_level.npy',Sl.astype(np.float32))
    ref=ref_columns(icp,ply,R,t,lo,H,W);cov=ref['n']>0;refgeom=(ref['low_max']>-np.inf)|(ref['body_max']>-np.inf)
    rw=cov&np.isfinite(ref['floor_h'])&~refgeom;lab,k=ndimage.label(rw,structure=np.ones((3,3)));s=np.bincount(lab.ravel());s[0]=0;rw=lab==np.argmax(s)
    results={}
    for name,V in variants.items():
        walk=V['walk'];masks={'permissive':walk,'statClear':walk&(state=='clear')}
        r={}
        for mk,mm in masks.items():
            sc=score(mm,ref);sc['refWalkPhoneBlocked']=int((rw&~mm).sum());sc['refWalk']=int(rw.sum())
            sc['missRatePct']=round(100*sc['refLow25']/max(sc['n'],1),3)
            r[mk]=sc
        # safety of what this variant UNBLOCKS relative to D1
        if name!='D1':
            newly=walk&~variants['D1']['walk']&cov;r['unblockedVsD1']=int(newly.sum());r['unblockedVsD1_refGeom']=int((newly&refgeom).sum());r['unblockedVsD1_refLow25']=int((newly&(ref['low_max']>=.025)).sum())
        results[name]=r;log(stage='variant',name=name,**r)
    np.savez('pipeline2_out.npz',lo=lo,R=R,t=t,res=RES,state=state,refWalk=rw,ungrounded=ung,**{f'{nm}__{k}':v for nm,V in variants.items() for k,v in V.items()},**{'ref_'+k:v for k,v in ref.items()})
    for name,V in variants.items():
        for mk,mm in (('permissive',V['walk']),('statClear',V['walk']&(state=='clear'))):run_routes(mm,lo,RES,recast,f'{name}/{mk}')
    run_routes(rw,lo,RES,recast,'REFERENCE-ONLY')
    json.dump(dict(rules=RULES,thresholds=PL.THRESHOLDS,res=RES,tsdf=tsdf,log=PL.LOG,results=results),open('PIPELINE2_RECEIPT.json','w'),indent=1,default=str)
if __name__=='__main__':main()
