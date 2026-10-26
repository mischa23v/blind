"""Pinned external source arithmetic only: no ICP, fusion, map edits or route calls."""
from pathlib import Path
import ast, hashlib, json, os, sys
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parent;WS=ROOT.parent
POSE=WS/'blind-mushroom-koivu-acquisition-01/selected/room_datasets/koivu/iphone/long_capture/transformations.json'
DEPTH=WS/'blind-koivu-game-07/map/depths'
META=WS/'blind-split-candidate-game-03/inputs/koivu_5cm_v2_pipeline2_out.npz'

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def run(out,expected):
    frozen=ROOT/'FROZEN.json'
    if sha(frozen)!=expected:raise ValueError('freeze mismatch')
    pins=json.loads(frozen.read_text())['files']
    def check():
        for p,h in pins.items():
            if sha(WS/p)!=h:raise ValueError('changed input/source: '+p)
    check();out=Path(out);out.mkdir(exist_ok=False)
    T=json.loads(POSE.read_text())['frames'];manifest=json.loads((DEPTH/'DEPTH_INPUT_MANIFEST.json').read_text())
    if len(T)!=294 or len(manifest['files'])!=294:raise ValueError('frame count')
    for i,(f,e) in enumerate(zip(T,manifest['files'])):
        if e['poseIndex']!=i or Path(f['depth_file_path']).name!=e['file'] or sha(DEPTH/e['file'])!=e['sha256']:raise ValueError('depth association')
    with np.load(META,allow_pickle=False) as z:o={k:z[k]for k in z.files}
    # Only filesystem redirection. Original frame dictionaries and source function ASTs are unaltered.
    inputdir=ROOT/'input'
    if not (inputdir/'depth').is_symlink() or (inputdir/'depth').resolve()!=DEPTH.resolve():raise ValueError('local depth binding')
    source=ROOT/'upstream/scripts/cause.py';tree=ast.parse(source.read_text())
    funcs=[n for n in tree.body if isinstance(n,ast.FunctionDef)]
    if [n.name for n in funcs]!=['frame_pts','floor_fit']:raise ValueError('unexpected pinned functions')
    ns=dict(np=np,os=os,Image=Image,T=T,R=o['R'],t=o['t'],d=str(inputdir))
    exec(compile(ast.Module(body=funcs,type_ignores=[]),str(source),'exec'),ns)
    rows=[];zero_depth=0;axial_vs_euclidean={'at2m':0,'at4m':0};total=0
    for i in range(len(T)):
        pl,cam,rng,pixels=ns['frame_pts'](i)
        zero_depth+=int((rng==0).sum());total+=len(rng)
        euc=np.linalg.norm(pl-cam,axis=1)
        axial_vs_euclidean['at2m']+=int(np.count_nonzero((rng<=2)!=(euc<=2)))
        axial_vs_euclidean['at4m']+=int(np.count_nonzero((rng<4)!=(euc<4)))
        r=ns['floor_fit'](pl,rng)
        if r:r['frame']=i;r['camH']=float(cam[2]);rows.append(r)
    original=json.loads((ROOT/'upstream/per_frame_floor.json').read_text())
    if [r['frame']for r in rows]!=[r['frame']for r in original]:raise ValueError('fit availability differs')
    maxima={k:0. for k in ('tilt','offset_at_centroid','resid_mad','k','camH')}
    for a,b in zip(rows,original):
        if a['n']!=b['n']:raise ValueError('inlier count differs')
        for k in maxima:maxima[k]=max(maxima[k],float(np.max(np.abs(np.asarray(a[k])-np.asarray(b[k])))))
    # Execute the exact gate AST from its first `bad` assignment onward, retaining original thresholds,
    # axial-depth selection, full-precision points, D1 flags, and saved reference-column proxy.
    gate=ROOT/'upstream/scripts/gate_check.py';g=ast.parse(gate.read_text())
    start=next(i for i,n in enumerate(g.body)if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name)and t.id=='bad'for t in n.targets))
    from types import SimpleNamespace
    gn=dict(np=np,C=SimpleNamespace(frame_pts=ns['frame_pts']),o=o,rows={r['frame']:r for r in rows},lo=o['lo'],RES=.05,H=o['D1__walk'].shape[0],W=o['D1__walk'].shape[1])
    exec(compile(ast.Module(body=g.body[start:],type_ignores=[]),str(gate),'exec'),gn)
    low=gn['low1'];gh,bh,nh=gn['gh'],gn['bh'],gn['nh'];real=gn['real']
    groups={'onlyInconsistent':gn['onlybad'],'anyConsistent':gn['anygood'],'noNearBandHits':low&(bh==0)&(gh==0)&(nh==0),
            'hasNoFitButNoConsistent':low&(nh>0)&(gh==0)}
    union=np.zeros_like(low)
    counts={}
    for k,m in groups.items():
        if np.any(union&m):raise ValueError('group overlap')
        union|=m;counts[k]={'cells':int(m.sum()),'suppliedReferenceVertexProxyPositive':int((m&real).sum()),
          'suppliedReferenceCoverageCells':int((m&gn['cov']).sum()),'noReferenceCoverageCells':int((m&~gn['cov']).sum())}
    if not np.array_equal(union,low):raise ValueError('gate groups incomplete')
    np.savez_compressed(out/'GATE_COUNTS.npz',goodHits=gh,badHits=bh,noFitHits=nh,lowD1=low,**groups)
    (out/'REPRODUCED_PLANES.json').write_text(json.dumps(rows,indent=2,allow_nan=False)+'\n')
    result={'scope':'Exact pinned cause/gate arithmetic reproduction; no ICP/pose correction/fusion/map/route operations',
      'frames':len(T),'fits':len(rows),'samples':total,'zeroAxialDepthSamples':zero_depth,
      'maxAbsoluteDifferenceFromSavedPlaneFields':maxima,'savedPlanesMatchWithin1eMinus10':all(v<=1e-10 for v in maxima.values()),
      'inconsistentFrames':len(gn['bad']),'noFitFrames':len(gn['nofit']),'D1LowSupportedNotHighCells':int(low.sum()),'groups':counts,
      'axialVsEuclideanThresholdMembershipDisagreementsAllSamples':axial_vs_euclidean,
      'rangeMeaning':'Original source uses axial depth, NOT Euclidean OctoMap maxrange; disagreement counts are diagnostic only.',
      'referenceMeaning':'Supplied ref_n/ref_low_max/ref_body_max vertex-column proxy evaluated AFTER phone-only counts; no mesh or reference registration used.',
      'frameMeaning':'frame fields are zero-based pose indices, not original image IDs','physicalAuthority':False,
      'limitations':['Full ICP transformations and before-registration correspondence metrics are absent from external results.','No-fit and inconsistent evidence is not cleared.','D1 is distinct from the active split0.7 routing mask.','Float64 projection is faithfully reproduced, not silently substituted with original fusion Float32 sequence.','No near axial-band sample does not prove far-only native occupancy provenance.']}
    check();(out/'RESULT.json').write_text(json.dumps(result,indent=2,allow_nan=False)+'\n');print(json.dumps(result))

if __name__=='__main__':run(sys.argv[1],sys.argv[2])
