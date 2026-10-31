"""Conditional scale inference, not calibrated accuracy. No ICP/Sim3/pose fitting."""
import os
for key in ('OPENBLAS_NUM_THREADS','OMP_NUM_THREADS','MKL_NUM_THREADS','NUMEXPR_NUM_THREADS'):os.environ[key]='1'
import argparse,csv,hashlib,json,math,time
from pathlib import Path
import numpy as np
from PIL import Image

CAP=.25
MIN_COVERAGE=.35
MIN_VISIBLE=.25
MIN_PIXELS=64
MAX_PIXELS=512
SCALES=np.geomspace(1e-6,1.,25)

def rotation(q):
    q=np.asarray(q,dtype=float);norm=np.linalg.norm(q)
    if not np.isfinite(q).all() or not np.isfinite(norm) or abs(norm-1)>1e-3:raise ValueError('Invalid quaternion or norm deviation>0.001')
    q/=norm;x,y,z,w=q
    return np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],
        [2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],
        [2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])

def pose_map(path,C):
    poses={}
    for r in csv.DictReader(open(path),skipinitialspace=True):
        i=int(r['frame']);t=np.array([float(r[k]) for k in ('x','y','z')]);R=rotation([float(r[k]) for k in ('qx','qy','qz','qw')])@C
        if i in poses or not np.isfinite(t).all() or not np.isfinite(R).all():raise ValueError('Invalid pose')
        poses[i]=(R,t)
    return poses

def ray_samples(depth,confidence,K):
    # Frozen deterministic subset; never choose pixels based on candidate scale.
    v,u=np.nonzero((confidence==2)&(depth>0)&(depth<65535))
    if len(u)<MIN_PIXELS:return None
    take=np.linspace(0,len(u)-1,min(MAX_PIXELS,len(u)),dtype=int);u=u[take];v=v[take]
    rays=np.column_stack(((u-K[0,2])/K[0,0],(v-K[1,2])/K[1,1],np.ones(len(u))))
    return rays*depth[v,u,None]

def direction(q,target,conf,K,R,t,s):
    if q is None:return {'eligible':False,'reason':'insufficient_source_confidence','score':None,'coverage':0.,'visible_coverage':0.}
    X=(s*q)@R.T+t;z=X[:,2];n=len(z);h,w=target.shape
    safe=np.isfinite(X).all(axis=1)&(z>1e-12)
    uf=np.full(n,-1e9);vf=np.full(n,-1e9)
    uf[safe]=K[0,0]*X[safe,0]/z[safe]+K[0,2];vf[safe]=K[1,1]*X[safe,1]/z[safe]+K[1,2]
    inside=safe&(uf>=-.5)&(uf<w-.5)&(vf>=-.5)&(vf<h-.5)
    idx=np.flatnonzero(inside);u=np.rint(uf[idx]).astype(int);v=np.rint(vf[idx]).astype(int)
    # Avoid banker-rounding producing endpoint width/height on exactly-half pixels.
    valid=(u>=0)&(u<w)&(v>=0)&(v<h);idx=idx[valid];u=u[valid];v=v[valid]
    valid=(conf[v,u]==2)&(target[v,u]>0)&(target[v,u]<65535);idx=idx[valid];u=u[valid];v=v[valid]
    ratio=z[idx]/(s*target[v,u]);visible=ratio<=1.05
    residual=np.abs(np.log(ratio));loss=np.full(n,CAP)
    # Occluded/missing samples keep a fixed penalty; never disappear from denominator.
    loss[idx[visible]]=np.minimum(residual[visible],CAP)
    coverage=len(idx)/n;vis=float(visible.sum())/n
    eligible=len(idx)>=MIN_PIXELS and coverage>=MIN_COVERAGE and vis>=MIN_VISIBLE
    return {'eligible':bool(eligible),'score':float(loss.mean()) if eligible else None,
        'coverage':coverage,'visible_coverage':vis,'occlusion_fraction':float((~visible).sum())/n,
        'consistent_fraction':float((residual<.05).sum())/n,'source_samples':n,
        'median_visible_log_residual':float(np.median(residual[visible])) if visible.any() else None}

def pair_score(pair,s):
    a=direction(pair['qi'],pair['dj'],pair['cj'],pair['K'],pair['R'],pair['t'],s)
    b=direction(pair['qj'],pair['di'],pair['ci'],pair['K'],pair['R'].T,-pair['R'].T@pair['t'],s)
    ok=a['eligible'] and b['eligible']
    return {'eligible':bool(ok),'score':(a['score']+b['score'])/2 if ok else None,'forward':a,'reverse':b}

def profile(pairs,scales):
    out=[]
    for s in scales:
        metrics=[pair_score(p,float(s)) for p in pairs];ok=all(x['eligible'] for x in metrics)
        out.append({'scale_m_per_unit':float(s),'score':float(np.mean([x['score'] for x in metrics])) if ok else None,'pairs':metrics})
    return out

def fit(pairs):
    coarse=profile(pairs,SCALES);finite=[(r['score'],i) for i,r in enumerate(coarse) if r['score'] is not None]
    if not finite:return {'status':'inconclusive_no_coverage','profile':coarse,'best':None}
    _,i=min(finite)
    if i in (0,len(coarse)-1):return {'status':'inconclusive_boundary_minimum','profile':coarse,'best':coarse[i]}
    refine=profile(pairs,np.geomspace(SCALES[i-1],SCALES[i+1],11));allp=coarse+refine
    best=min((r for r in allp if r['score'] is not None),key=lambda r:r['score'])
    finite_scores=[r['score'] for r in coarse if r['score'] is not None]
    flat=max(finite_scores)-min(finite_scores)<1e-3
    near=[r['scale_m_per_unit'] for r in allp if r['score'] is not None and r['score']<=best['score']+.01]
    status='inconclusive_flat_profile' if flat else 'inconclusive_broad_profile' if max(near)/min(near)>4 else 'conditional_candidate_only'
    return {'status':status,'best':best,'profile':allp,
        'score_within_0p01_scale_range_not_confidence_interval':[min(near),max(near)]}

def make_pair(di,dj,ci,cj,K,R,t):
    return dict(di=di,dj=dj,ci=ci,cj=cj,K=K,R=R,t=t,qi=ray_samples(di,ci,K),qj=ray_samples(dj,cj,K))

def synthetic_checks():
    K=np.array([[60.,0,31.5],[0,60.,23.5],[0,0,1]]);shape=(48,64);true=.001
    conf=np.full(shape,2,np.uint8);di=np.full(shape,2./true);pairs=[]
    for dz in (.12,.16,.20,.24):
        pairs.append(make_pair(di,np.full(shape,(2.-dz)/true),conf,conf,K,np.eye(3),np.array([.02,0,-dz])))
    fit_ok=fit(pairs);estimate=fit_ok['best']['scale_m_per_unit']
    assert abs(math.log(estimate/true))<.05,('Known scale recovery failed',estimate)
    occluded=[]
    for p in pairs:
        dj=p['dj'].copy();dj[18:30,24:40]=.8/true
        occluded.append(make_pair(p['di'],dj,p['ci'],p['cj'],K,p['R'],p['t']))
    oc=fit(occluded);assert oc['best'] and abs(math.log(oc['best']['scale_m_per_unit']/true))<.15
    zero=make_pair(di,di,conf,conf,K,np.eye(3),np.zeros(3));zr=fit([zero])
    assert zr['status'].startswith('inconclusive'), 'Degenerate scene must not yield accepted scale'
    zs=profile([zero],SCALES);scores=[r['score'] for r in zs];assert max(scores)-min(scores)<1e-9
    missing=make_pair(di,di,conf,np.zeros(shape,np.uint8),K,np.eye(3),np.array([0,0,-.2]))
    assert fit([missing])['status']=='inconclusive_no_coverage'
    assert pair_score(pairs[0],1e-6)['score'] is None, 'Tiny scale must not win via zero overlap'
    # Off-grid scale and genuine rotation: analytic target image of a fixed world plane.
    offgrid=.00037;theta=math.radians(5);R=np.array([[math.cos(theta),0,math.sin(theta)],[0,1,0],[-math.sin(theta),0,math.cos(theta)]])
    t=np.array([.02,0,-.15]);v,u=np.indices(shape);rays=np.stack(((u-K[0,2])/K[0,0],(v-K[1,2])/K[1,1],np.ones(shape)),axis=-1)
    normal=R@np.array([0.,0.,1.]);target_z=(2.+normal@t)/(rays@normal)
    rotated=fit([make_pair(np.full(shape,2./offgrid),target_z/offgrid,conf,conf,K,R,t)])
    assert rotated['best'] and abs(math.log(rotated['best']['scale_m_per_unit']/offgrid))<.08, 'Off-grid rotated known-scale recovery failed'
    lateral=fit([make_pair(di,di,conf,conf,K,np.eye(3),np.array([.15,0,0]))])
    assert lateral['status'].startswith('inconclusive'), 'Featureless lateral-plane scale is unobservable'
    return {'known_scale_recovered':estimate,'occlusion_recovered':oc['best']['scale_m_per_unit'],
        'zero_translation_status':zr['status'],'missing_overlap_rejected':True,'tiny_scale_rejected':True,
        'offgrid_true_scale':offgrid,'offgrid_rotated_recovered':rotated['best']['scale_m_per_unit'],'featureless_lateral_status':lateral['status'],
        'meaning':'Implementation checks only; no evidence of real dataset encoding'}

def real_run(manifest_path,images_path):
    m=json.loads(Path(manifest_path).read_text());raw=Path(m['pose_path'])
    if hashlib.sha256(raw.read_bytes()).hexdigest()!=m['pose_sha256']:raise ValueError('Pose CSV changed after pair freeze')
    if hashlib.sha256(Path(m['camera_matrix_path']).read_bytes()).hexdigest()!=m['camera_matrix_sha256']:raise ValueError('Camera matrix changed after pair freeze')
    receipt=json.loads((Path(images_path)/'receipt.json').read_text())
    if receipt['manifest_sha256']!=hashlib.sha256(Path(manifest_path).read_bytes()).hexdigest():raise ValueError('Extraction used another split')
    K=np.asarray(m['geometry_assumptions']['K']);C=np.asarray(m['geometry_assumptions']['optical_to_arkit_camera']);poses=pose_map(raw,C)
    data={};mask_audit={}
    for i in {p[k] for p in m['pairs'] for k in ('i','j')}:
        values=[]
        for kind in ('depth','confidence'):
            f=Path(images_path)/f'{kind}_{i:06d}.png'
            if hashlib.sha256(f.read_bytes()).hexdigest()!=receipt['files'][f.name]:raise ValueError('Extracted sample changed')
            with Image.open(f) as im:arr=np.asarray(im).copy()
            if arr.shape!=(192,256):raise ValueError('Unexpected image shape')
            if kind=='depth' and arr.dtype!=np.uint16:raise ValueError('Unexpected depth dtype')
            if kind=='confidence' and (arr.dtype!=np.uint8 or not set(np.unique(arr))<={0,1,2}):raise ValueError('Unexpected confidence encoding')
            values.append(arr)
        data[i]=values
        depth,confidence=values
        mask_audit[str(i)]={'pixels':int(depth.size),'depth_zero_count':int((depth==0).sum()),
            'depth_65535_count':int((depth==65535).sum()),'dtype_saturated_max_code_count':int((depth==np.iinfo(depth.dtype).max).sum()),
            'raw_min':int(depth.min()),'raw_max':int(depth.max()),
            'confidence_counts':{str(c):int((confidence==c).sum()) for c in (0,1,2)},
            'numeric_mask_kept':int(((depth>0)&(depth<65535)&(confidence==2)).sum()),
            'excluded_code_reason':'0 and65535 excluded conservatively; exported invalid/saturation semantics unverified; no metric-range cutoff'}
    groups={'development':[],'holdout':[]}
    for spec in m['pairs']:
        i,j=spec['i'],spec['j'];Ri,ti=poses[i];Rj,tj=poses[j]
        groups[spec['split']].append(make_pair(*[data[x][k] for x,k in ((i,0),(j,0),(i,1),(j,1))],K,Rj.T@Ri,Rj.T@(ti-tj)))
    dev=groups['development'];hold=groups['holdout'];result=fit(dev)
    # Holdout never influences scale fitting, selection or refinement.
    s=result['best']['scale_m_per_unit'] if result['best'] else None
    held=profile(hold,[s])[0] if s else None
    zero=[dict(p,t=np.zeros(3)) for p in dev]
    shuffled=[dict(p,R=dev[(i+1)%len(dev)]['R'],t=dev[(i+1)%len(dev)]['t']) for i,p in enumerate(dev)]
    controls={'zero_translation':profile(zero,SCALES),'cyclic_pose_shuffle':profile(shuffled,SCALES)}
    # Preregistered heuristic gates, not statistical confidence or calibration proof.
    reasons=[]
    if result['status']!='conditional_candidate_only':reasons.append(result['status'])
    if not result['best'] or result['best']['score']>.15:reasons.append('development_residual_too_large')
    if held is None or held['score'] is None:
        reasons.append('heldout_insufficient_coverage')
    else:
        for h in held['pairs']:
            if h['score']>.15 or h['score']>result['best']['score']+.03:
                reasons.append('heldout_residual_not_consistent_with_development');break
            for d in ('forward','reverse'):
                v=h[d]['median_visible_log_residual']
                if v is None or v>.10:reasons.append('heldout_visible_residual_too_large')
    interval=result.get('score_within_0p01_scale_range_not_confidence_interval')
    if interval and interval[1]/interval[0]>4:reasons.append('broad_near_minimum_profile')
    zscores=[r['score'] for r in controls['zero_translation'] if r['score'] is not None]
    if not zscores or max(zscores)-min(zscores)>1e-3:reasons.append('zero_translation_control_uninformative_or_nonflat')
    if result['best'] and zscores and min(zscores)<result['best']['score']+.01:
        reasons.append('zero_translation_fits_equally_well_or_better')
    sscores=[r['score'] for r in controls['cyclic_pose_shuffle'] if r['score'] is not None]
    if result['best'] and sscores and min(sscores)<result['best']['score']+.01:
        reasons.append('shuffled_poses_not_worse_enough')
    decision={'status':'inconclusive' if reasons else 'candidate_survives_preregistered_internal_checks',
        'reasons':sorted(set(reasons)),
        'threshold_status':'Declared diagnostic design choices before selected depths are read; NOT accuracy specifications or confidence intervals',
        'thresholds':{'max_development_or_holdout_score':.15,'max_holdout_score_increase':.03,
            'max_holdout_median_visible_log_error':.10,'max_near_minimum_scale_factor':4,
            'max_zero_translation_profile_range':1e-3,'min_zero_translation_score_increase':.01,'min_shuffled_best_score_increase':.01}}
    return {'interpretation':'Conditional internal-consistency diagnostic; NOT documented units, calibration or independent accuracy',
        'manifest_sha256':hashlib.sha256(Path(manifest_path).read_bytes()).hexdigest(),'assumptions':m['geometry_assumptions'],
        'raw_code_and_confidence_mask_audit':mask_audit,
        'development':result,'heldout_at_development_scale_only':held,'controls':controls,'diagnostic_decision':decision,
        'heldout_missing_or_ineligible':held is None or held['score'] is None,
        'heldout_preregistered_residual_gate_failed':any(x.startswith('heldout_') and 'coverage' not in x for x in reasons),
        'quaternion_normalization':m['quaternion_normalization'],'publication':'private samples only; no raw public redistribution'}

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--synthetic-only',action='store_true');ap.add_argument('--approve-real-run',action='store_true')
    ap.add_argument('--manifest');ap.add_argument('--images');ap.add_argument('--out',required=True);a=ap.parse_args()
    started=time.monotonic();tests=synthetic_checks()
    if a.synthetic_only:r={'synthetic_tests':tests}
    else:
        if not a.approve_real_run or not a.manifest or not a.images:raise SystemExit('Real execution requires root CPU-slot/review clearance and explicit flag')
        r=real_run(a.manifest,a.images);r['synthetic_tests']=tests
    r['wall_seconds']=time.monotonic()-started;Path(a.out).write_text(json.dumps(r,indent=2));print(a.out)

if __name__=='__main__':main()
