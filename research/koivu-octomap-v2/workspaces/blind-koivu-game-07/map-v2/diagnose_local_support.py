"""Read saved endpoint extents and masks; no revised plane, occupancy or route."""
from pathlib import Path
import hashlib,json,numpy as np
from scipy.ndimage import binary_dilation
R=Path(__file__).resolve().parent
paths={R.parent/'map/run-01/map/MAP.npz':'1961eef94bc98f5d89d4986c8b62d7352d0e2046e1dbfa3e6baf767a54e7646d',R/'run-01/map/SURFACE_EVIDENCE.npz':'c4b80a0305a82fd7dfe1e7de8d8a5da6396634dd8afd832663f5eb31baffdfd8',R/'FOOTPRINT_NEIGHBOURHOODS.npz':'3d7b8eaecec72bd54e0ab9afdabe98dacfc990d8245aeed9b33c4c95549f0c60'}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def quant(x):return None if len(x)==0 else {str(q):float(np.quantile(x,q))for q in (0,.05,.5,.95,1)}
for p,digest in paths.items():assert sha(p)==digest
raw=np.load(next(iter(paths)));e=np.load(R/'run-01/map/SURFACE_EVIDENCE.npz');n=np.load(R/'FOOTPRINT_NEIGHBOURHOODS.npz');ij=raw['voxelIndices'];lo=raw['voxelMinimumObservedY'];hi=raw['voxelMaximumObservedY'];views=raw['voxelSourceFrameCount'];w=int(raw['surfaceWidth']);h=int(raw['surfaceDepth']);total=w*h;s=(ij[:,2]//2)*w+ij[:,0]//2
region=n['footprintNeighbourMask'].ravel();centres=n['eligibleCentreMask'];stencil=n['stationaryStencil'];support=e['support'];quad=(ij[:,2]%2)*2+ij[:,0]%2;within=(lo>=-.03)&(hi<=.03)
quadrants={}
for required in (1,2):
 q=np.zeros((total,4),bool);valid=within&(views>=required);q[s[valid],quad[valid]]=True;quadrants[required]=q.sum(1)
missing=region&~support;positive=e['rawObstacle']&e['rawOccupiedAny'];relevant=positive&region[s];floor=within&region[s];below=e['rawBelowFloorContradiction']&region[s]
bands=[]
for lower,upper in [(.03,.1),(.1,.3),(.3,.8),(.8,1.4),(1.4,1.75)]:
 selected=positive&(hi>lower)&(lo<upper);mask=np.zeros(total,bool);mask[s[selected]]=True;near=binary_dilation(mask.reshape(h,w),structure=stencil)
 bands.append({'actualObservedHeightInterval':[lower,upper],'overlapRule':'maximumY>lower and minimumY<upper','nativeOccupiedRawVoxelsInNeighbourRegion':int((selected&region[s]).sum()),'touchedCellsInNeighbourRegion':int((mask&region).sum()),'eligibleCentresWhoseFootprintTouchesThisEvidence':int((near&centres).sum())})
repeat=[]
for required in (1,2,5,10):
 selected=positive&(views>=required);mask=np.zeros(total,bool);mask[s[selected]]=True;near=binary_dilation(mask.reshape(h,w),structure=stencil)
 repeat.append({'minimumDistinctOriginalFrames':required,'positiveVoxelsInNeighbourRegion':int((selected&region[s]).sum()),'eligibleCentresTouched':int((near&centres).sum()),'meaning':'Descriptive repetition only, not a confidence filter or removal rule'})
result={'scope':'Saved-mask local support/height diagnosis only; no changed criteria or proposed physical clearance','eligibleCentres':int(centres.sum()),'footprintNeighbourCells':int(region.sum()),'supportedNeighbourCells':int((region&support).sum()),'missingSupportNeighbourCells':int(missing.sum()),'missingSupportQuadHistograms':{str(required):{str(k):int((missing&(quadrants[required]==k)).sum())for k in range(5)}for required in (1,2)},'missingSupportWithAllFourQuadsAtOneFrameButNotTwo':int((missing&(quadrants[1]==4)&(quadrants[2]<4)).sum()),'groundBandRawVoxelCountInRegion':int(floor.sum()),'groundBandObservedYMinQuantiles':quant(lo[floor]),'groundBandObservedYMaxQuantiles':quant(hi[floor]),'groundBandMidExtentQuantiles_NotRawPointQuantiles':quant(((lo+hi)/2)[floor]),'belowFloorRawVoxelCountInRegion':int(below.sum()),'belowFloorObservedYMinQuantiles':quant(lo[below]),'belowFloorObservedYMaxQuantiles':quant(hi[below]),'nativeOccupiedHeightBands':bands,'nativeOccupiedFrameRepetition':repeat,'caveats':['Ground-band candidates are model-defined, not semantic floor labels.','Quantiles describe saved voxel observed endpoint extrema, not every raw point or independent height error.','Height/repetition classes may overlap; no voxel is deleted or reclassified.','A declared level-support variant would be a new controlled model, not proof of sensed support, stairs, drops or toys.'],'inputHashes':{str(p.relative_to(R.parent)):digest for p,digest in paths.items()},'sourceSHA256':sha(Path(__file__)),'FAROUsed':False,'mapChanged':False,'gameEpisodes':0}
for p,digest in paths.items():assert sha(p)==digest
with (R/'LOCAL_SUPPORT_DIAGNOSIS.json').open('x')as f:f.write(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
