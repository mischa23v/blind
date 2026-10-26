"""Export saved map neighbourhoods for attribution only, not planning."""
from pathlib import Path
import json,sys
import numpy as np
from scipy import ndimage
ROOT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT.parent))
from game_model import sha,BODY_RADIUS,MARGIN
sp=ROOT/'run-01/map/SURFACE.json';d=json.loads((ROOT/'BLOCKER_NEIGHBOURHOODS.json').read_text())
if sha(sp)!=d['surfaceSHA256']:raise ValueError('saved surface changed')
s=json.loads(sp.read_text());r=s['resolution'];w=s['width'];h=s['depth'];radius=BODY_RADIUS+MARGIN
mask=np.array([not c['blocked'] and c['clearance']==1.75 and c['floor']==0 for c in s['cells']]).reshape(h,w)
reach=int(np.ceil((radius+r*.5)/r));offset=np.arange(-reach,reach+1);distance=np.maximum(np.abs(offset)*r-r*.5,0)
stencil=np.hypot(distance[:,None],distance[None,:])<=radius
if int(mask.sum())!=359 or int(stencil.sum())!=109:raise ValueError('diagnostic count mismatch')
union=ndimage.binary_dilation(mask,structure=stencil,border_value=0)
path=ROOT/'FOOTPRINT_NEIGHBOURHOODS.npz'
with path.open('xb')as f:np.savez_compressed(f,eligibleCentreMask=mask,footprintNeighbourMask=union,footprintNeighbourFlatIndices=np.flatnonzero(union),stationaryStencil=stencil)
receipt={'purpose':'Local saved-map blocker attribution only; no altered map or route selection','shapeDepthWidth':[h,w],'eligibleCentres':int(mask.sum()),'unionNeighbourCells':int(union.sum()),'radiusWithMargin':radius,'resolution':r,'sourceSHA256':sha(Path(__file__)),'surfaceSHA256':sha(sp),'outputSHA256':sha(path),'FAROUsed':False,'physicalAuthority':False}
(ROOT/'FOOTPRINT_NEIGHBOURHOODS_RECEIPT.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(receipt))
