"""Read-only attribution of saved map blockers near the fixed body footprint.

NumPy builds the stationary circle/cell-intersection stencil from the already
frozen NavigationSurface radius. SciPy dilation counts neighbourhood evidence;
this does not change maps, issue routes, or replace actual Swift validation.
"""
from pathlib import Path
import json,sys
import numpy as np
from scipy import ndimage
ROOT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT.parent))
from game_model import sha,BODY_RADIUS,MARGIN
SURFACE_SHA='7421a58b88a3f80c0b10501854be6e49ff29a78b0ef51eceeb113a0b36343129'
EVIDENCE_SHA='c4b80a0305a82fd7dfe1e7de8d8a5da6396634dd8afd832663f5eb31baffdfd8'


def main():
    output=ROOT/'BLOCKER_NEIGHBOURHOODS.json'
    if output.exists():raise ValueError('refuse diagnostic overwrite')
    sp=ROOT/'run-01/map/SURFACE.json';ep=ROOT/'run-01/map/SURFACE_EVIDENCE.npz'
    if sha(sp)!=SURFACE_SHA or sha(ep)!=EVIDENCE_SHA:raise ValueError('saved input hash mismatch')
    s=json.loads(sp.read_bytes());w=s['width'];h=s['depth'];r=s['resolution'];radius=BODY_RADIUS+MARGIN
    with np.load(ep)as e:
        masks={name:e[key].copy().reshape(h,w)for name,key in {
            'missingOriginalFloorSupport':'surfaceMissingSupport',
            'retainedBelowFloorContradiction':'surfaceBelowFloorContradiction',
            'positiveNativeOccupied':'surfacePositiveOccupied',
            'positiveNativeUnknownOrUnresolved':'surfacePositiveUnresolved'}.items()}
        blocked=e['blocked'].copy().reshape(h,w);clear=e['surfaceClearanceKnown'].copy().reshape(h,w)
    masks['additionalVolumeCoverageMissing']=~blocked&~clear
    eligible=~blocked&clear
    union=np.logical_or.reduce(list(masks.values()))
    if not np.array_equal(union,~eligible):raise ValueError('saved blocker decomposition mismatch')
    reach=int(np.ceil((radius+r*.5)/r));offset=np.arange(-reach,reach+1)
    distance=np.maximum(np.abs(offset)*r-r*.5,0)
    stencil=np.hypot(distance[:,None],distance[None,:])<=radius
    near={name:ndimage.binary_dilation(mask,structure=stencil,border_value=0)for name,mask in masks.items()}
    z,x=np.indices((h,w));boundary=(x+.5)*r-radius<0
    boundary|=(z+.5)*r-radius<0;boundary|=(x+.5)*r+radius>=w*r;boundary|=(z+.5)*r+radius>=h*r
    near['surfaceBoundary']=boundary
    signatures={}
    for zz,xx in zip(*np.nonzero(eligible)):
        signature=' + '.join(name for name,mask in near.items()if mask[zz,xx])or 'none'
        signatures[signature]=signatures.get(signature,0)+1
    union_near=np.logical_or.reduce(list(near.values()))
    result={'scope':'Saved phone-map blocker neighbourhood diagnosis only; no modified map or route/controller output',
        'surfaceSHA256':SURFACE_SHA,'surfaceEvidenceSHA256':EVIDENCE_SHA,'sourceSHA256':sha(Path(__file__)),
        'bodyRadiusWithMarginMetres':radius,'resolutionMetres':r,'stationaryFootprintIntersectedCellOffsets':int(stencil.sum()),
        'eligibleCentres':int(eligible.sum()),'neighbourhoodBlockerCentreCounts':{name:int((mask&eligible).sum())for name,mask in near.items()},
        'overlappingBlockerSignatures':dict(sorted(signatures.items(),key=lambda x:(-x[1],x[0]))),
        'eligibleCentresWithoutAnyNeighbourhoodBlocker':int((eligible&~union_near).sum()),
        'originalActualSwiftFitResult':'0 of 359 eligible centres fit; see PHONE_FOOTPRINT_DIAGNOSTIC.json',
        'interpretation':'Counts overlap. A below-floor contradiction is a model conflict, not independently proven stairs or obstacle truth. No floor band, support prior, body margin or occupied state changed.',
        'geometryOrCriteriaChanged':False,'FAROUsed':False,'gameEpisodesExecuted':0,'physicalAuthority':False}
    if sha(sp)!=SURFACE_SHA or sha(ep)!=EVIDENCE_SHA:raise ValueError('saved inputs changed')
    output.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))

if __name__=='__main__':main()
