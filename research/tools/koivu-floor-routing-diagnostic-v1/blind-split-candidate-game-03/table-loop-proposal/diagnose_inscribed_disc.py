"""Measurement-only inscribed-disc topology; padded rectangle and planner unchanged."""
from pathlib import Path
import hashlib,json,math,resource,signal,time,shutil
import numpy as np
from scipy import ndimage
from topology_quick import analyse
HERE=Path(__file__).resolve().parent;GAME=HERE.parent
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
 resource.setrlimit(resource.RLIMIT_CPU,(30,30));signal.signal(signal.SIGALRM,lambda *_:(_ for _ in()).throw(TimeoutError('45 second bound')));signal.alarm(45);start=time.monotonic()
 if shutil.disk_usage(HERE).free<768*1024**2+1024**2:raise RuntimeError('reserve')
 split=GAME/'inputs/koivu_5cm_occthres_split0.7.npz';prop=HERE/'run-03/artifacts/PROPOSAL.json';previous=HERE/'CENTRE_TOPOLOGY.json'
 pins={str(p.relative_to(GAME.parent)):sha(p)for p in [split,prop,previous,HERE/'topology_quick.py',Path(__file__)]}
 assert sha(split)=='b294d92cfd9136d00de510239c2b85a9d68d878dcf7dac1a64b144d8880cb076'
 assert sha(prop)=='45f034606811b7896dea48ff2d0ebc68166b70a090400338cd1900f65b38b78a'
 with np.load(split,allow_pickle=False)as z:mask=z['walk'].copy()
 r=json.loads(prop.read_text());target=np.asarray(r['targetComponent']['sourceCellIndices'],int);probe=np.array(json.loads(previous.read_text())['fixedTargetNearestCentroidCell'])
 d=ndimage.distance_transform_edt(mask)*.05-.05*math.sqrt(2)/2
 axis=np.arange(-7,8);dx,dz=np.meshgrid(axis,axis,indexing='ij');nearest_x=np.maximum(np.abs(dx)*.05-.025,0);nearest_z=np.maximum(np.abs(dz)*.05-.025,0)
 stencil=np.hypot(nearest_x,nearest_z)<=.30+1e-12
 assert stencil[7,7] and stencil[13,7] and not stencil[14,7] and stencil[11,11] and not stencil[12,12]
 exact=ndimage.binary_erosion(mask,structure=stencil,border_value=0)
 result={'scope':'measurement only, no changed planner/rectangle/margin or accepted route','unchangedPaddedRectangleForwardLateralMetres':[.60,.75],'inscribedDiscRadiusMetres':.30,'originalDiscRadiusMetres':.375,'fixedOriginalTargetCells':len(target),'fixedTargetProbe':probe.tolist(),'conservativeEDT030':analyse(mask&(d>=.30),target,probe),'circleCellIntersection030':analyse(exact,target,probe),'exactStencilCells':int(stencil.sum()),'exactStencilRule':'all offset square cells whose closed box intersects radius.30 disc at the query cell centre; circle-to-cell nearest distance,1e-12m numeric boundary allowance','continuousRouteImpossibilityEstablished':False,'circleMeaning':'Necessary geometric subset of the padded rectangle at a sampled centre; does not establish oriented rectangle fit or continuous connectivity','EDTMeaning':'conservative sufficient distance lower-bound criterion, not an exact necessary condition','sourceInputSHA256':pins,'referenceInputsUsed':False,'nativeQueries':0,'movementEpisodes':0,'physicalAuthority':False}
 for p,h in pins.items():assert sha(GAME.parent/p)==h
 result.update(pinsVerifiedBeforeAfter=True,wallSeconds=time.monotonic()-start,observedPeakRSSBytes=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss*1024)
 assert result['observedPeakRSSBytes']<256*1024**2
 data=(json.dumps(result,indent=2)+'\n').encode();assert len(data)<1024**2 and shutil.disk_usage(HERE).free-len(data)>=768*1024**2
 with (HERE/'INSCRIBED_DISC_TOPOLOGY.json').open('xb')as f:f.write(data)
 signal.alarm(0)
 for name in ['conservativeEDT030','circleCellIntersection030']:print(name,json.dumps({k:v for k,v in result[name].items()if k!='components'}), 'eligibleCells',sum(x['eligibleCentreCells']for x in result[name]['components']))
 print(json.dumps({k:result[k]for k in ['wallSeconds','observedPeakRSSBytes','exactStencilCells']}))
if __name__=='__main__':main()
