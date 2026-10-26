"""Small, read-only independent checks of the published floor diagnostic.

Uses saved arrays and three original depth frames; no fusion or reference query.
Run from repository root with the existing isolated audit Python environment.
"""
import ast
import argparse
import hashlib
import json
import os
from pathlib import Path
import sys
import time
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'artifacts/mapping-audit-20261026'
PACK = BASE / 'checkpoint-7506ad9/research/tools/koivu-floor-routing-diagnostic-v1'
GAME = PACK / 'blind-split-candidate-game-03'
DIAG = GAME / 'body-margin-variants-07/diagnosis'
BRANCH = BASE / 'checkpoint-57fdf25/research/mapping-audit-opus-20261026'
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path, default=BASE/'REVIEW_7506AD9_REPRODUCED.json')
OUT = parser.parse_args().output.resolve()

def read(p): return json.loads(p.read_text(encoding='utf-8'))
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def functions(path, names, env):
    tree = ast.parse(path.read_text(encoding='utf-8'))
    nodes = [n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name in names]
    assert len(nodes) == len(names)
    exec(compile(ast.Module(body=nodes, type_ignores=[]), str(path), 'exec'), env)
    return env

def main():
    start = time.monotonic()
    m = read(PACK/'MANIFEST.json')
    for row in m['files']:
        p = PACK/row['path']
        assert p.stat().st_size == row['bytes'] and sha(p) == row['sha256'], str(p)
    expected = {r['path'] for r in m['files']} | {'MANIFEST.json', 'VALIDATION.json'}
    actual = {p.relative_to(PACK).as_posix() for p in PACK.rglob('*') if p.is_file()}
    assert expected == actual
    out = dict(checkpoint='7506ad9', comparator='57fdf25', packetFiles=len(actual),
               manifestPayloadFiles=len(m['files']), allPacketHashesMatch=True)
    copies = {'pipeline.py': PACK/'blind-opus-reference-scoring-audit-02/upstream/scripts/pipeline.py',
              'pipeline2.py': GAME/'upstream/scripts/pipeline2.py',
              'occthres.py': GAME/'upstream/scripts/occthres.py',
              'routes_rect.py': GAME/'upstream/scripts/routes_rect.py'}
    out['sourceEqualityTo57fdf25'] = {k: sha(v)==sha(BRANCH/'scripts'/k) for k,v in copies.items()}
    assert all(out['sourceEqualityTo57fdf25'].values())
    src = BRANCH/'derived/pipeline-outputs'
    meta_path = src/'koivu_5cm_v2_pipeline2_out.npz'
    mask_path = src/'koivu_5cm_occthres_split0.7.npz'
    assert sha(meta_path)=='a2fc5c13f86bf7033131347fd9b6d61db23ab716d12d668a3d969b9e87dbf48d'
    assert sha(mask_path)=='b294d92cfd9136d00de510239c2b85a9d68d878dcf7dac1a64b144d8880cb076'
    meta = np.load(meta_path, allow_pickle=False)
    mask = np.load(mask_path, allow_pickle=False)
    R,t,lo,res = meta['R'],meta['t'],meta['lo'],float(meta['res'])
    pose_path = BASE/'prepared/transformations.json'
    assert sha(pose_path)=='c496c8dc6474679766db8abd92da9c756104a752bb9e4519fd462fe294af90c3'
    frames = read(pose_path)['frames']
    poses = np.array([f['transform_matrix'] for f in frames])
    cam = poses[:,:3,3]@R.T+t
    ij = np.floor(cam[:,:2]/res).astype(int)-lo[:2]
    assert ((ij>=0)&(ij<np.array(mask['walk'].shape))).all()
    blocked = ~mask['walk'][ij[:,0],ij[:,1]]
    west = (cam[:,0]<-3)&(cam[:,1]>1)&(cam[:,1]<3.5)
    wc = np.unique(ij[west],axis=0)
    bc = np.unique(ij[west&blocked],axis=0)
    proxy=np.array([-1.225,-.075])
    angles=np.unwrap(np.arctan2(cam[:,1]-proxy[1],cam[:,0]-proxy[0]))
    roi=read(GAME/'room-scale-readonly-audit/WESTERN_PASSAGE_CAMERA_CELLS.json')['rows']
    env=functions(DIAG/'western_depth_residuals.py', ['project','verify_roi'], {'np':np})
    env['verify_roi'](roi,frames,R,t,lo,res,mask)
    out['trajectory'] = dict(frames=len(frames),blockedRecords=int(blocked.sum()),
        westRecords=int(west.sum()),westBlockedRecords=int((west&blocked).sum()),
        westUniqueCells=len(wc),westBlockedUniqueCells=len(bc),
        westLowBlockedCells=int(mask['low1'][bc[:,0],bc[:,1]].sum()),
        westMissingSupportBlockedCells=int((~mask['support'][bc[:,0],bc[:,1]]).sum()),
        frame214ReturnXYMetres=float(np.linalg.norm(cam[213,:2]-cam[0,:2])),
        frame214Return3DMetres=float(np.linalg.norm(cam[213]-cam[0])),
        frame214AngularSweepTurns=float((angles[213]-angles[0])/(2*np.pi)),
        all71SavedROIAssociationsMatch=True)
    out['coordinateChecks']=dict(levelDeterminant=float(np.linalg.det(R)),
        levelOrthogonalityMaxError=float(np.max(abs(R@R.T-np.eye(3)))),
        poseRotationSingularValueRange=[float(np.linalg.svd(poses[:,:3,:3],compute_uv=False).min()),float(np.linalg.svd(poses[:,:3,:3],compute_uv=False).max())])
    raw=np.load(DIAG/'west-depth-run-01/result/SELECTED_ENDPOINTS.npz',allow_pickle=False)
    fit=np.load(DIAG/'phone-plane-fit-01/run-01/result/WESTERN_ENDPOINT_PLANE_RESIDUALS.npz',allow_pickle=False)
    result=read(DIAG/'phone-plane-fit-01/run-01/result/RESULT.json')
    for k in ('frame','i','j','row','col','depthMM','range'):
        assert np.array_equal(raw[k],fit[k]),k
    assert np.array_equal(raw['level'][:,2],fit['globalHeight'])
    maxerr=0.
    for r in result['frames']:
        use=fit['frame']==r['poseIndex']
        if 'planeABCD' not in r: continue
        p=np.array(r['planeABCD'])
        if use.any(): maxerr=max(maxerr,float(np.max(abs(raw['level'][use]@p[:3]+p[3]-fit['fitSignedResidual'][use]))))
    out['savedResiduals']=dict(endpoints=len(raw['frame']),associationFieldsExact=True,
        maxResidualEquationErrorMetres=maxerr,validFits=sum(r['valid'] for r in result['frames']),
        invalidFits=sum(not r['valid'] for r in result['frames']))
    groups={}
    for name,predicate in [('lowObstacle',lambda i,j:bool(mask['low1'][i,j])),
                           ('missingSupport',lambda i,j:not bool(mask['support'][i,j]))]:
        cells=[(i,j) for i,j in bc if predicate(i,j)]
        selections=[(raw['i']==i)&(raw['j']==j) for i,j in cells]
        groups[name]=dict(cells=len(cells),endpoints=sum(int(s.sum()) for s in selections),
            cellsWithNearEndpoints=sum(bool(np.any(s&(raw['range']<=2))) for s in selections),
            cellsWithNearLowBandEndpoints=sum(bool(np.any(s&(raw['range']<=2)&(raw['level'][:,2]>.025)&(raw['level'][:,2]<=.075))) for s in selections))
    out['blockedEvidenceGroups']=groups
    same=(raw['i']==44)&(raw['j']==171)&(abs(raw['level'][:,2])<.1)
    near=raw['level'][same&(raw['range']<=2),2];far=raw['level'][same&(raw['range']>2),2]
    out['exampleCell44_171']=dict(conditionalHeightWindowMetres=[-.1,.1],nearCount=len(near),farCount=len(far),
        nearMedianMetres=float(np.median(near)),farMedianMetres=float(np.median(far)),
        nearMinusFarMedianMetres=float(np.median(near)-np.median(far)),
        note='Same nominal XY cell, not established exact surface correspondences.')
    # Three real source frames, using both independent diagnostic projection and original AST.
    orig=functions(copies['pipeline.py'],['lidar_samples'],{'np':np,'os':os,'Image':Image})
    depthroot=BASE/'prepared'
    manifest=read(PACK/'blind-koivu-game-07/map/depths/DEPTH_INPUT_MANIFEST.json')
    frame_checks=[]
    for fi in (61,62,63):
        f=frames[fi];entry=manifest['files'][fi]
        depthpath=next(depthroot.rglob(entry['file']))
        assert sha(depthpath)==entry['sha256'] and Path(f['depth_file_path']).name==entry['file']
        dep=np.asarray(Image.open(depthpath))
        p,rr,cc,mm,jump=env['project'](dep,f)
        fake=dict(f,depth_file_path='./'+depthpath.name)
        op=orig['lidar_samples'](str(depthpath.parent),[fake])[0]
        assert np.array_equal(p,op)
        level=p@R.T+t
        lookup={(int(a),int(b)):j for j,(a,b) in enumerate(zip(rr,cc))}
        selected=np.flatnonzero(raw['frame']==fi)
        indices=np.array([lookup[int(raw['row'][j]),int(raw['col'][j])] for j in selected])
        assert np.array_equal(level[indices],raw['level'][selected])
        r=result['frames'][fi];plane=np.array(r['planeABCD'])
        q=level[indices];delta=q@plane[:3]+plane[3]
        zcentre=-(q[:,0].mean()*plane[0]+q[:,1].mean()*plane[1]+plane[3])/plane[2]
        alternative_camera_delta=np.c_[-.5*mm[indices]*.001/f['fl_x'],.5*mm[indices]*.001/f['fl_y'],np.zeros(len(indices))]
        alternative_height_delta=(alternative_camera_delta@poses[fi,:3,:3].T@R.T)[:,2]
        frame_checks.append(dict(poseIndex=fi,frameID=Path(f['depth_file_path']).stem,
            sourceHashVerified=True,allSourceSamplesMatchOriginalAST=True,savedEndpointsExact=len(indices),
            globalMedianMetres=float(np.median(q[:,2])),fitMedianResidualMetres=float(np.median(delta)),
            planeTiltDegrees=r['tiltDegrees'],planeHeightAtSelectedCentroidMetres=float(zcentre),
            planeABCD=r['planeABCD'],inliers=r['inliers'],candidates=r['candidates'],
            halfPixelAlternativeMaxHeightChangeMM=float(abs(alternative_height_delta).max()*1000)))
    out['threeFrameChecks']=frame_checks
    # Re-fit saved sufficient floor rows, no all-frame depth/fusion repeat.
    rows=np.load(DIAG/'floor-fit-indexing/run-01/result/FLOOR_ROWS.npz',allow_pickle=False)
    old=rows['originalRows'];fixed=rows['correctedRows']
    keys=rows['signedKeys'];y=keys%100000;y=np.where(y<50000,y,y-100000);x=(keys-y)//100000
    assert np.allclose(fixed[:,:2],np.c_[x,y]*.2+.1,rtol=0,atol=1e-12)
    fe=functions(DIAG/'floor-fit-indexing/floor_fit_impact.py',['plane'],{'np':np})
    ko,Ro,to,_=fe['plane'](old);kf,Rf,tf,_=fe['plane'](fixed)
    assert np.allclose(Ro,R,rtol=0,atol=1e-12) and np.allclose(to,t,rtol=0,atol=1e-12)
    xy=(wc+lo[:2]+.5)*res;phone=(np.c_[xy,np.zeros(len(xy))]-t)@R
    shift=phone@Rf[2]+tf[2]-(phone@Ro[2]+to[2])
    out['signedKey']=dict(rows=len(old),changedRows=int((old[:,0]!=fixed[:,0]).sum()),
        westernMaxAbsHeightShiftMM=float(abs(shift).max()*1000))
    join=read(GAME/'west-saved-reference-join-10/RESULT.json')
    br=[r for r in join['rows'] if not r['phoneFlags']['walk']]
    tr=[r for r in br if r['savedTriangleColumnAvailable']]
    for row in join['rows']:
        i,j=row['sourceIJ']
        assert all(bool(mask[k][i,j])==v for k,v in row['phoneFlags'].items())
    out['referenceJoinRecount']=dict(blockedCells=len(br),triangleChecked=len(tr),
        triangleCheckedLowFlags=sum(r['phoneFlags']['low1'] for r in tr),
        allSavedContactsZero=all(not np.any(r['savedTriangleContacts']) for r in tr),
        allFiveSavedSupportProbesHit=all(r['savedFloorProbeHits']==5 for r in tr),
        savedFloorHeightRangeMetres=[min(min(r['savedFloorProbeHeights']) for r in tr),max(max(r['savedFloorProbeHeights']) for r in tr)],
        originalTriangleArraysIndependentlyReloaded=False,newReferenceQueries=0)
    out['limits']=['No native fit rerun, no full fusion, no reference mesh queries, no new route/movement.',
        'Three source frames reprojected; other frames checked through saved arrays only.',
        'Exact arithmetic and hashes do not establish physical accuracy.']
    out['wallSeconds']=time.monotonic()-start
    OUT.parent.mkdir(parents=True,exist_ok=True)
    OUT.write_text(json.dumps(out,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(out,indent=2))

if __name__=='__main__':main()
