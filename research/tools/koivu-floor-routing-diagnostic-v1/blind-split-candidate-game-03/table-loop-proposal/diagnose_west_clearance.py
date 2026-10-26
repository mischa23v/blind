"""Read-only saved-phone-map attribution, not a new route or body model."""
from pathlib import Path
import hashlib,json,math,os,resource,signal,sys,time
HERE=Path(__file__).resolve().parent;GAME=HERE.parent
sys.path.insert(0,str(GAME/'source'))
import numpy as np
from scipy import ndimage
from candidate_map import modules,SPLIT_SHA,META_SHA,sha,PHONE_KEYS

def main():
 resource.setrlimit(resource.RLIMIT_CPU,(30,30));signal.signal(signal.SIGALRM,lambda *_:(_ for _ in ()).throw(TimeoutError('45 second cap')));signal.alarm(45)
 start=time.monotonic();out=HERE/'WEST_CLEARANCE_DIAGNOSTIC.json'
 if out.exists():raise FileExistsError(out)
 split=GAME/'inputs/koivu_5cm_occthres_split0.7.npz';meta=GAME/'inputs/koivu_5cm_v2_pipeline2_out.npz';proposal=HERE/'run-03/artifacts/PROPOSAL.json'
 pins={str(p.relative_to(GAME.parent)):sha(p) for p in (split,meta,proposal,Path(__file__))}
 if sha(split)!=SPLIT_SHA or sha(meta)!=META_SHA:raise ValueError('input pin')
 r=json.loads(proposal.read_text());rr,_=modules()
 with np.load(split,allow_pickle=False)as z:mask=z['walk'].copy()
 with np.load(meta,allow_pickle=False)as z:lo=z['lo'].copy()
 origin=lo[:2]*.05;target=np.asarray(r['targetComponent']['sourceCellIndices'],int);target_centres=origin+(target+.5)*.05
 low=np.array(r['targetComponent']['sourceBoundsMinXY']);high=np.array(r['targetComponent']['sourceBoundsMaxXY'])
 clearance=ndimage.distance_transform_edt(mask)*.05-.05*math.sqrt(2)/2
 allwalk=np.argwhere(mask);xy=origin+(allwalk+.5)*.05;vals=clearance[allwalk[:,0],allwalk[:,1]]
 west=xy[:,0]<=low[0];rows=np.flatnonzero(west);disc=vals>=.375
 fits=[]
 for k in rows:
  x,y=xy[k];head=next((j*5 for j in range(72)if rr.rect_ok(mask,tuple(origin),float(x),float(y),math.radians(j*5))),None)
  if head is not None:fits.append({'sourceIJ':allwalk[k].tolist(),'sourceXY':xy[k].tolist(),'firstSampledHeadingDegrees':head,'discClearanceLowerBoundMetres':float(vals[k])})
 order=rows[np.argsort(-vals[rows],kind='stable')][:10]
 eroded_labels,n=ndimage.label(mask&(clearance>=.375),structure=ndimage.generate_binary_structure(2,1))
 components=np.bincount(eroded_labels.ravel())[1:]
 result={'scope':'saved phone mask only; finite sampled fit and distance-transform diagnostic, not physical clearance or a route',
   'sourceInputSHA256':pins,'targetBoundsSourceXY':[low.tolist(),high.tolist()], 'targetMinimumCellCentreX':float(target_centres[:,0].min()),
   'globalDiscFitCentres':int(disc.sum()),'minimumDiscFitCentreX':float(xy[disc,0].min())if disc.any()else None,
   'westHalfPlaneWalkCentres':len(rows),'westHalfPlaneDiscFitCentres':int((disc&west).sum()),
   'westMaximumDiscClearanceLowerBoundMetres':float(vals[rows].max())if len(rows)else None,
   'westTopClearanceCentres':[{'sourceIJ':allwalk[k].tolist(),'sourceXY':xy[k].tolist(),'discClearanceLowerBoundMetres':float(vals[k])}for k in order],
   'westSampledRectangleFitCentres':len(fits),'westFirstRectangleFits':fits[:20],
   'rectangleDimensionsIncludingMarginsMetres':{'forward':.60,'lateral':.75},'sampledHeadings':72,'headingStepDegrees':5,'rectangleSpatialSamplingMetres':.025,
   'discFit4Components':int(n),'discFitComponentSizesDescending':sorted(map(int,components),reverse=True),
   'clearanceRule':'upstream EDT(mask)*.05-.05*sqrt(2)/2; unchanged radius .375',
   'referenceInputsUsed':False,'routeQueriesExecuted':0,'movementEpisodesExecuted':0,'physicalAuthority':False,
   'counterInterpretation':'rectangle-only diagnostic does not weaken or replace the actual native disc planner',
   'wallSeconds':time.monotonic()-start,'peakRSSBytes':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss*1024}
 if result['peakRSSBytes']>256*1024**2:raise RuntimeError('RSS cap')
 for p,h in pins.items():
  if sha(GAME.parent/p)!=h:raise ValueError('source/input changed')
 result['pinsVerifiedBeforeAfter']=True
 raw=(json.dumps(result,indent=2,allow_nan=False)+'\n').encode()
 if len(raw)>65536:raise RuntimeError('output cap')
 with out.open('xb')as f:f.write(raw)
 signal.alarm(0);print(json.dumps(result))
if __name__=='__main__':main()
