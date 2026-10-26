"""Experimental observed-support adapter over preserved Koivu/Open3D/OctoMap evidence.

No reference imports, pose correction, scale fitting or plane-point deletion.
"""
import argparse,ast,hashlib,json,math,time
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage

HERE=Path(__file__).resolve().parent
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def load(p):return json.loads(Path(p).read_text())
def dump(p,data):Path(p).write_bytes((json.dumps(data,indent=2,allow_nan=False)+'\n').encode())
def funcs(path,names,env):
    tree=ast.parse(Path(path).read_text());nodes=[n for n in tree.body if isinstance(n,ast.FunctionDef)and n.name in names]
    assert len(nodes)==len(names);exec(compile(ast.Module(body=nodes,type_ignores=[]),str(path),'exec'),env);return env

def frame_evidence(level,ranges,plane,valid,lo,shape,cfg):
    """Actual endpoints only. Convex hulls and plane extents never populate cells."""
    count=int(np.prod(shape));result={k:np.zeros(count,bool)for k in ('support','positive','ambiguous','negative')}
    result['supportHeight']=np.full(count,np.nan,np.float32)
    result['explainedKeys']=np.empty((0,3),int)
    if not valid:return result
    ij=np.floor(level[:,:2]/cfg['gridMetres']).astype(int)-lo[:2]
    inside=(ij>=0).all(1)&(ij<shape).all(1)
    take=inside&(ranges<=cfg['maximumSupportObservationRangeMetres'])&(abs(level[:,2])<=cfg['nearSurfaceCandidateAbsGlobalHeightMetres'])
    p=level[take];ij=ij[take];key=ij[:,0]*shape[1]+ij[:,1]
    residual=p@np.asarray(plane)[:3]+plane[3]
    tol=cfg['floorResidualBandMetres'];high=cfg['positiveResidualObstacleThresholdMetres']
    for name,select in [('support',abs(residual)<=tol),('positive',residual>high),('ambiguous',(residual>tol)&(residual<=high)),('negative',residual< -tol)]:
        result[name][np.unique(key[select])]=True
    keep=abs(residual)<=tol
    n=np.bincount(key[keep],minlength=count);total=np.bincount(key[keep],weights=p[keep,2],minlength=count)
    result['supportHeight'][n>0]=total[n>0]/n[n>0]
    result['explainedKeys']=np.unique(np.floor((p[keep]+[0,0,cfg['gridMetres']/2])/cfg['gridMetres']).astype(int),axis=0)
    return result

def combine(support_heights,positive,ambiguous,negative,cfg):
    n=np.isfinite(support_heights).sum(0)
    import warnings
    with warnings.catch_warnings():
        warnings.simplefilter('ignore',RuntimeWarning)
        height=np.nanmedian(support_heights,axis=0)
        spread=np.nanmax(support_heights,axis=0)-np.nanmin(support_heights,axis=0)
    support=(n>=cfg['minimumSupportViews'])&(spread<=cfg['maximumSupportViewHeightSpreadMetres'])
    obstacle=positive>=cfg['minimumPositiveResidualViews']
    unresolved=((positive>0)&~obstacle)|(ambiguous>0)|(negative>0)|~support
    return dict(support=support,floorHeight=height,floorViewSpread=spread,supportViews=n,
                lowObstacle=obstacle,lowOrSupportUnresolved=unresolved)

def paths(ws):
    packet=ws/'checkpoint-7506ad9/research/tools/koivu-floor-routing-diagnostic-v1'
    branch=ws/'checkpoint-57fdf25/research/mapping-audit-opus-20261026'
    diag=packet/'blind-split-candidate-game-03/body-margin-variants-07/diagnosis'
    return packet,branch,diag

def freeze(ws,out):
    _,branch,_=paths(ws);inputs=branch/'derived/pipeline-outputs'
    with np.load(inputs/'koivu_5cm_v2_pipeline2_out.npz')as m:lo=m['lo'];R=m['R'];t=m['t']
    with np.load(inputs/'koivu_5cm_occthres_split0.7.npz')as m:mask=m['walk']
    cfg=load(HERE/'PROTOCOL.json');res=cfg['gridMetres']
    radius=math.hypot(cfg['bodyWidthMetres'],cfg['bodyDepthMetres'])/2+cfg['horizontalMarginMetres']
    d=ndimage.distance_transform_edt(mask)*res-res*math.sqrt(2)/2
    candidates=np.argwhere(d>=radius);rng=np.random.default_rng(cfg['trialSelection']['seed'])
    if len(candidates)<2:raise ValueError('Baseline cannot supply frozen pairs')
    xy=(candidates+lo[:2]+.5)*res;proxy=np.array([-1.225,-.075]);angles=np.arctan2(xy[:,1]-proxy[1],xy[:,0]-proxy[0])
    pairs=[]
    for idx in rng.permutation(len(candidates)):
        dist=np.linalg.norm(xy-xy[idx],axis=1);da=abs((angles-angles[idx]+np.pi)%(2*np.pi)-np.pi)
        targets=np.flatnonzero((dist>=2)&(dist<=6)&(da>=np.pi/2))
        if not len(targets):continue
        j=int(rng.choice(targets));direction=xy[j]-xy[idx]
        pairs.append(dict(pair=len(pairs),startXY=xy[idx].tolist(),goalXY=xy[j].tolist(),startIJ=candidates[idx].tolist(),goalIJ=candidates[j].tolist(),initialYaw=float(np.arctan2(direction[1],direction[0]))))
        if len(pairs)==20:break
    if len(pairs)!=20:raise ValueError('Cannot freeze twenty baseline pairs')
    out.mkdir(parents=True,exist_ok=False)
    dump(out/'FROZEN.json',dict(protocol=cfg,protocolSHA256=sha(HERE/'PROTOCOL.json'),mapperSourceSHA256=sha(Path(__file__)),
        baselineMaskSHA256=sha(inputs/'koivu_5cm_occthres_split0.7.npz'),baselineMetadataSHA256=sha(inputs/'koivu_5cm_v2_pipeline2_out.npz'),
        pairs=pairs,baselineCircumscribedCircleCandidates=len(candidates),radiusMetres=radius,
        selectionReadsCorrectedMap=False,selectionReadsReference=False,selectionReadsCameraPath=False,
        targetMeaning='Fixed geometric centre from prior diagnostic, not verified semantic table; opposite-side pairs are not complete loops'))
    print(json.dumps({'frozenPairs':20,'trialAttempts':100,'baselineCandidates':len(candidates)}),flush=True)

def build(ws,out):
    start=time.monotonic();frozen=load(out/'FROZEN.json');cfg=frozen['protocol']
    assert sha(HERE/'PROTOCOL.json')==frozen['protocolSHA256']and sha(Path(__file__))==frozen['mapperSourceSHA256']
    packet,branch,diag=paths(ws);inputs=branch/'derived/pipeline-outputs'
    meta=np.load(inputs/'koivu_5cm_v2_pipeline2_out.npz');R,t,lo=meta['R'],meta['t'],meta['lo']
    old=np.load(inputs/'koivu_5cm_occthres_split0.7.npz');shape=old['walk'].shape;ncell=int(np.prod(shape));res=cfg['gridMetres']
    poses=load(ws/'prepared/transformations.json')['frames']
    fits=load(diag/'phone-plane-fit-01/run-01/result/RESULT.json')['frames']
    manifest=load(packet/'blind-koivu-game-07/map/depths/DEPTH_INPUT_MANIFEST.json')['files']
    project=funcs(diag/'western_depth_residuals.py',['project'],{'np':np})['project']
    heights=np.full((len(poses),ncell),np.nan,np.float32)
    votes={k:np.zeros(ncell,np.uint16)for k in ('positive','ambiguous','negative')}
    nz=42;explained=np.zeros((*shape,nz),np.uint16);valid=0
    for fi,(pose,fit,row)in enumerate(zip(poses,fits,manifest)):
        pth=ws/'prepared/depth'/row['file'];assert sha(pth)==row['sha256']and row['poseIndex']==fi and Path(pose['depth_file_path']).name==row['file']
        raw=np.asarray(Image.open(pth));phone=project(raw,pose)[0];level=phone@R.T+t
        ranges=np.linalg.norm(phone.astype(float)-np.asarray(pose['transform_matrix'])[:3,3],axis=1)
        evidence=frame_evidence(level,ranges,fit.get('planeABCD'),fit['valid'],lo,shape,cfg)
        heights[fi]=evidence['supportHeight'];valid+=bool(fit['valid'])
        for k in votes:votes[k]+=evidence[k]
        keys=evidence['explainedKeys']-lo
        inside=(keys>=0).all(1)&(keys<np.array(explained.shape)).all(1);keys=keys[inside]
        if len(keys):explained[keys[:,0],keys[:,1],keys[:,2]]+=1
        if fi%40==0:print(json.dumps({'phase':'observations','frame':fi,'validFits':valid}),flush=True)
    data={k:v.reshape(shape)for k,v in combine(heights,**votes,cfg=cfg).items()};del heights
    # Step/slope discontinuities use observed support, never missing-neighbour interpolation.
    edges=np.zeros(shape,bool);h=data['floorHeight'];sup=data['support'];edge_limit=res*math.tan(math.radians(cfg['maximumNeighbourSlopeDegrees']))+2*cfg['floorResidualBandMetres']
    for ax in (0,1):
        a=[slice(None),slice(None)];b=a.copy();a[ax]=slice(0,-1);b[ax]=slice(1,None);a,b=tuple(a),tuple(b)
        bad=sup[a]&sup[b]&(abs(h[a]-h[b])>edge_limit);edges[a]|=bad;edges[b]|=bad
    # Reuse original full-ray occupied/free states (threshold 0.5), no new fusion or hidden reference.
    clouds=np.load(inputs/'koivu_5cm_v2_fused_clouds.npz');A=np.zeros((*shape,nz),np.uint8)
    for key,value in [('freeA',1),('occA',2),('occN',2)]:
        k=np.floor(clouds[key]/res+1e-6).astype(int)-lo;ok=(k>=0).all(1)&(k<np.array(A.shape)).all(1);k=k[ok];A[k[:,0],k[:,1],k[:,2]]=value
    # Bounds of each original voxel, relative to unshifted measured support.
    centre=(np.arange(nz)+lo[2])*res;bottom=centre-res/2;top=centre+res/2
    interval=(top[None,None,:]>h[:,:,None]+cfg['floorResidualBandMetres'])&(bottom[None,None,:]<h[:,:,None]+cfg['bodyHeightMetres']+cfg['verticalMarginMetres'])
    near_support=(abs(centre[None,None,:]-h[:,:,None])<=res/2+cfg['floorResidualBandMetres'])
    floor_explained=(explained>=cfg['minimumSupportViews'])&near_support&sup[:,:,None]
    occupied=((A==2)&interval&~floor_explained).any(2)
    unknown=((A==0)&interval&~floor_explained).any(2)
    occupied|=old['highObstacle']|old['deepBelow']|old['nearDip'];unknown|=old['highUnknown']
    walk=sup&~data['lowObstacle']&~data['lowOrSupportUnresolved']&~edges&~occupied&~unknown
    data.update(stepEdge=edges,occupiedBodyOrHead=occupied,unknownBodyOrHead=unknown,walk=walk,lo=lo,R=R,t=t,res=np.array(res))
    for k,v in votes.items():data[k+'Views']=v.reshape(shape)
    np.savez_compressed(out/'PHONE_MAP.npz',**data)
    reasons={k:int(data[k].sum())for k in ('support','lowObstacle','lowOrSupportUnresolved','stepEdge','occupiedBodyOrHead','unknownBodyOrHead','walk')}
    circle=ndimage.distance_transform_edt(walk)*res-res*np.sqrt(2)/2>=frozen['radiusMetres']
    report=dict(protocolSHA256=frozen['protocolSHA256'],sourceSHA256=sha(Path(__file__)),frames=294,validPlanes=valid,counts=reasons,
        baselineWalkCells=int(old['walk'].sum()),newlyAdmittedCells=int((walk&~old['walk']).sum()),newlyWithheldCells=int((~walk&old['walk']).sum()),
        correctedCircumscribedCircleCentres=int(circle.sum()),mapSHA256=sha(out/'PHONE_MAP.npz'),FAROUsed=False,
        parametersCalibratedForPhysicalSafety=False,posesOrDepthChanged=False,wallSeconds=time.monotonic()-start,
        limitation='Finite-cell observation adapter; strict positive/negative residual evidence is deliberately unresolved rather than deleted. No physical clearance guarantee.')
    dump(out/'MAP_RESULT.json',report);print(json.dumps(report),flush=True)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('mode',choices=['freeze','build']);p.add_argument('--audit-root',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
    (freeze if a.mode=='freeze'else build)(a.audit_root.resolve(),a.out.resolve())
