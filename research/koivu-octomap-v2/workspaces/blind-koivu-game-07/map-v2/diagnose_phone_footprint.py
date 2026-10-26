"""Read-only phone-map feasibility diagnostic, not alternative route selection.

SciPy labels index-adjacent eligible cells; actual Swift NavigationSurface alone
answers full footprint fit. No FARO, occupancy refit, radius or margin changes.
"""
from pathlib import Path
import hashlib,json,sys,time
import numpy as np
from scipy import ndimage
ROOT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT.parent))
from game_model import PhoneModel,sha,HALF_EXTENT,BODY_RADIUS,HEIGHT,MARGIN
SURFACE=ROOT/'run-01/map/SURFACE.json'
SURFACE_SHA='7421a58b88a3f80c0b10501854be6e49ff29a78b0ef51eceeb113a0b36343129'


def components(mask,resolution,diagonal):
    structure=ndimage.generate_binary_structure(2,2 if diagonal else 1)
    labels,n=ndimage.label(mask,structure=structure)
    counts=np.bincount(labels.ravel())[1:]
    entries=[]
    for i,count in enumerate(counts,1):
        z,x=np.nonzero(labels==i)
        entries.append({'cells':int(count),'areaSquareModelMetres':float(count*resolution**2),
            'indexBoundsXZ':[int(x.min()),int(x.max()),int(z.min()),int(z.max())],
            'axisAlignedExtentModelMetres':[(int(x.max())-int(x.min())+1)*resolution,(int(z.max())-int(z.min())+1)*resolution]})
    entries.sort(key=lambda x:(-x['cells'],x['indexBoundsXZ']))
    return {'connectivity':8 if diagonal else 4,'componentCount':int(n),'components':entries,
        'meaning':'Cell-index adjacency only; not a route or full-body clearance proof'}


def main():
    target=ROOT/'PHONE_FOOTPRINT_DIAGNOSTIC.json'
    if target.exists():raise ValueError('refuse diagnostic overwrite')
    start=time.monotonic();pins={}
    for p in [Path(__file__),ROOT.parent/'game_model.py',ROOT.parent/'SurfaceGameWorker.swift',ROOT.parent/'build/surface-worker',SURFACE]:
        pins[str(p.relative_to(ROOT.parent))] = sha(p)
    model=PhoneModel(SURFACE,SURFACE_SHA)
    try:
        s=model.surface;w=s['width'];h=s['depth'];r=s['resolution'];o=s['origin']
        mask=np.zeros(w*h,bool);mask[model.eligible]=True;mask=mask.reshape(h,w)
        indices=model.eligible;points=[(o['x']+(i%w+.5)*r,0.,o['z']+(i//w+.5)*r)for i in indices]
        fits=[]
        for i in range(0,len(points),4096):fits.extend(model.native.permits([(p,p)for p in points[i:i+4096]]))
        fitmask=np.zeros(w*h,bool);fitindices=[i for i,fit in zip(indices,fits)if fit];fitmask[fitindices]=True
        d={'scope':'Offline phone-only footprint diagnostic; not additional selected routes or game episodes','sourceAndInputPins':pins,
           'surfaceSHA256':SURFACE_SHA,'eligibleCells':len(indices),'allEligibleCellCentresChecked':len(points),'fullBodyFitCellCentres':len(fitindices),
           'fullBodyFitSurfaceIndices':fitindices,'eligible4Neighbour':components(mask,r,False),'eligible8Neighbour':components(mask,r,True),
           'bodyFit4Neighbour':components(fitmask.reshape(h,w),r,False),'body':{'height':HEIGHT,'halfExtent':HALF_EXTENT,'nativeCylinderRadius':BODY_RADIUS,'margin':MARGIN,'totalRequestedPlanningRadius':BODY_RADIUS+MARGIN},
           'nativeRecastBuildError':model.build_error,'nativeRecastConstructed':model.engine is not None,
           'noFAROInput':True,'noGeometryOrRadiusChanges':True,'routesReplacedOrResampled':False,'gameEpisodesExecuted':0,'physicalAuthority':False}
    finally:model.close()
    if sha(SURFACE)!=SURFACE_SHA:raise ValueError('surface changed during diagnostic')
    d['wallSeconds']=time.monotonic()-start
    target.write_text(json.dumps(d,indent=2,allow_nan=False)+'\n')
    print(json.dumps({k:d[k]for k in ['eligibleCells','fullBodyFitCellCentres','nativeRecastBuildError','nativeRecastConstructed','wallSeconds']}))

if __name__=='__main__':main()
