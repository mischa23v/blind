"""Finite-grid topology only; no native path, physical clearance or target change."""
from pathlib import Path
import json,hashlib,resource,signal,time
import numpy as np
from scipy import ndimage
HERE=Path(__file__).resolve().parent;GAME=HERE.parent
FOUR=ndimage.generate_binary_structure(2,1);EIGHT=np.ones((3,3),int)
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def analyse(mask,target,probe):
 labels,n=ndimage.label(mask,structure=FOUR);result=[]
 for k in range(1,n+1):
  component=labels==k;bg,count=ndimage.label(~component,structure=EIGHT)
  exterior=set(map(int,np.r_[bg[0],bg[-1],bg[:,0],bg[:,-1]]));holes=[]
  target_labels=bg[target[:,0],target[:,1]]
  for h in range(1,count+1):
   if h in exterior:continue
   overlap=int((target_labels==h).sum())
   holes.append({'background8Region':h,'regionCells':int((bg==h).sum()),'targetCellsEnclosed':overlap,'allTargetCellsEnclosed':overlap==len(target),'fixedTargetProbeEnclosed':bool(bg[tuple(probe)]==h)})
  result.append({'foreground4Component':k,'eligibleCentreCells':int(component.sum()),'boundedComplement8Regions':holes})
 return {'foreground4Components':int(n),'componentsWithAnyBoundedRegion':sum(bool(r['boundedComplement8Regions'])for r in result),'anyRegionEnclosesAllTarget':any(h['allTargetCellsEnclosed']for r in result for h in r['boundedComplement8Regions']),'anyRegionEnclosesFixedProbe':any(h['fixedTargetProbeEnclosed']for r in result for h in r['boundedComplement8Regions']),'components':result}
def main():
 resource.setrlimit(resource.RLIMIT_CPU,(30,30));signal.signal(signal.SIGALRM,lambda *_:(_ for _ in()).throw(TimeoutError('45 second cap')));signal.alarm(45);start=time.monotonic()
 # Independent toy topology fixtures; no data-dependent changes.
 ring=np.zeros((9,9),bool);ring[1:8,1:8]=True;ring[3:6,3:6]=False;q=np.array([[4,4]])
 assert analyse(ring,q,q[0])['anyRegionEnclosesFixedProbe']
 broken=ring.copy();broken[:5,4]=False
 assert not analyse(broken,q,q[0])['anyRegionEnclosesFixedProbe']
 diagonal=ring.copy();diagonal[1,1]=False;diagonal[2,2]=False;diagonal[3,3]=False
 assert not analyse(diagonal,q,q[0])['anyRegionEnclosesFixedProbe']
 split=GAME/'inputs/koivu_5cm_occthres_split0.7.npz';prop=HERE/'run-03/artifacts/PROPOSAL.json'
 pins={str(p.relative_to(GAME.parent)):sha(p)for p in [split,prop,Path(__file__)]}
 assert sha(split)=='b294d92cfd9136d00de510239c2b85a9d68d878dcf7dac1a64b144d8880cb076'
 assert sha(prop)=='45f034606811b7896dea48ff2d0ebc68166b70a090400338cd1900f65b38b78a'
 r=json.loads(prop.read_text());target=np.asarray(r['targetComponent']['sourceCellIndices'],int)
 # Distance to centroid using integer numerator; exact ties use original flat order.
 numer=target*len(target)-target.sum(axis=0);distance=np.square(numer).sum(axis=1);order=np.lexsort((target[:,1],target[:,0],distance));probe=target[order[0]]
 with np.load(split,allow_pickle=False)as z:mask=z['walk'].copy()
 assert mask.shape==(241,250) and mask.dtype==np.bool_
 d=ndimage.distance_transform_edt(mask)*.05-.05*np.sqrt(2)/2;eligible=mask&(d>=.375)
 result={'scope':'finite-grid enclosing-region diagnostic; no native path or physical-room impossibility proof','fixtureChecksPassed':3,'fixedOriginalTargetCells':len(target),'fixedTargetNearestCentroidCell':probe.tolist(),'targetChanged':False,'probeMeaning':'diagnostic original target cell nearest centroid; not a verified semantic table centre','rawPermissiveWalkTopology':analyse(mask,target,probe),'unchangedDiscCentreTopology':analyse(eligible,target,probe),'connectivity':'foreground4/background8, border-connected complement is exterior','bodyDiscRule':'unchanged EDT*.05-.05*sqrt(2)/2 >= .375','rawWalkIsNotAlternativeClearance':True,'continuousOrOrientationAwareRouteImpossibilityEstablished':False,'physicalAuthority':False,'referenceInputsUsed':False,'nativeQueries':0,'movementEpisodes':0,'sourceInputSHA256':pins}
 for p,h in pins.items():assert sha(GAME.parent/p)==h
 result.update(pinsVerifiedBeforeAfter=True,wallSeconds=time.monotonic()-start,peakRSSBytes=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss*1024)
 assert result['peakRSSBytes']<=256*1024**2
 data=(json.dumps(result,indent=2)+'\n').encode();assert len(data)<1024**2
 with (HERE/'CENTRE_TOPOLOGY.json').open('xb')as f:f.write(data)
 signal.alarm(0)
 print(json.dumps({k:v for k,v in result.items()if k not in ['rawPermissiveWalkTopology','unchangedDiscCentreTopology','sourceInputSHA256']}))
 for mode in ['rawPermissiveWalkTopology','unchangedDiscCentreTopology']:print(mode,json.dumps({k:v for k,v in result[mode].items()if k!='components'}))
if __name__=='__main__':main()
