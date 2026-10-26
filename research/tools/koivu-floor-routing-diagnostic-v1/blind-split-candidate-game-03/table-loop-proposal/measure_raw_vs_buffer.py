"""Same west cells/headings: raw body versus buffer, diagnostic ONLY.
No production body, margin, mask, route, clearance authority or controller change.
"""
from pathlib import Path
import hashlib,json,math,resource,signal,shutil,sys,time
HERE=Path(__file__).resolve().parent;GAME=HERE.parent;WS=GAME.parent
sys.path.insert(0,str(GAME/'source'))
import numpy as np
from candidate_map import modules,SPLIT_SHA,META_SHA,sha

def samples(forward,lateral):
 x,y=np.meshgrid(np.arange(-forward/2,forward/2+1e-9,.025),np.arange(-lateral/2,lateral/2+1e-9,.025),indexing='ij')
 return np.c_[x.ravel(),y.ravel()]
def fits(mask,origin,x,y,theta,points):
 c,s=math.cos(theta),math.sin(theta);xx=x+points[:,0]*c-points[:,1]*s;yy=y+points[:,0]*s+points[:,1]*c
 i=np.floor((xx-origin[0])/.05).astype(int);j=np.floor((yy-origin[1])/.05).astype(int)
 inside=(i>=0)&(i<mask.shape[0])&(j>=0)&(j<mask.shape[1])
 return bool(inside.all() and mask[i,j].all())
def main():
 resource.setrlimit(resource.RLIMIT_CPU,(30,30));signal.signal(signal.SIGALRM,lambda *_:(_ for _ in()).throw(TimeoutError('45 second cap')));signal.alarm(45);start=time.monotonic()
 if shutil.disk_usage(HERE).free<768*1024**2+65536:raise RuntimeError('disk reserve')
 rr,_=modules();raw=samples(.30,.45);buffer=samples(.60,.75);np.testing.assert_array_equal(buffer,rr.RB)
 fixture=np.zeros((80,80),bool);fixture[:,35:45]=True
 assert fits(fixture,(0,0),2.,2.,0.,raw) and not fits(fixture,(0,0),2.,2.,0.,buffer)
 for i in range(16):
  a=i*math.pi/8;assert fits(fixture,(0,0),2.,2.,a,buffer)==bool(rr.rect_ok(fixture,(0,0),2.,2.,a))
 split=GAME/'inputs/koivu_5cm_occthres_split0.7.npz';meta=GAME/'inputs/koivu_5cm_v2_pipeline2_out.npz';prop=HERE/'run-03/artifacts/PROPOSAL.json';old=HERE/'WEST_CLEARANCE_DIAGNOSTIC.json'
 pins={str(p.relative_to(WS)):sha(p)for p in [split,meta,prop,old,Path(__file__)]}
 assert sha(split)==SPLIT_SHA and sha(meta)==META_SHA
 r=json.loads(prop.read_text());previous=json.loads(old.read_text());west_bound=r['targetComponent']['sourceBoundsMinXY'][0]
 with np.load(split,allow_pickle=False)as z:mask=z['walk'].copy()
 with np.load(meta,allow_pickle=False)as z:origin=z['lo'][:2]*.05
 ij=np.argwhere(mask);xy=origin+(ij+.5)*.05;selected=np.flatnonzero(xy[:,0]<=west_bound)
 assert len(selected)==previous['westHalfPlaneWalkCentres']==344
 rows=[];count_raw=count_buffer=raw_poses=buffer_poses=0
 for k in selected:
  x,y=xy[k];rh=[];bh=[]
  for angle in range(0,360,5):
   th=math.radians(angle)
   if fits(mask,origin,x,y,th,raw):rh.append(angle)
   if fits(mask,origin,x,y,th,buffer):bh.append(angle)
  count_raw+=bool(rh);count_buffer+=bool(bh);raw_poses+=len(rh);buffer_poses+=len(bh)
  if rh or bh:rows.append({'sourceIJ':ij[k].tolist(),'sourceXY':xy[k].tolist(),'rawBodyHeadingsDegrees':rh,'bufferHeadingsDegrees':bh})
 assert count_buffer==previous['westSampledRectangleFitCentres']==0
 result={'scope':'measurement only; body/margin/planner unchanged, no route or physical clearance claim','westWalkCellCentres':len(selected),'headingsPerCentre':72,'totalCandidatePoses':len(selected)*72,'rawBodyDimensionsForwardLateralMetres':[.30,.45],'bufferDimensionsForwardLateralMetres':[.60,.75],'unchangedMarginEachSideMetres':.15,'rawBodySomeHeadingFitCentres':int(count_raw),'bufferSomeHeadingFitCentres':int(count_buffer),'rawBodyFittingPoses':raw_poses,'bufferFittingPoses':buffer_poses,'fittingCentres':rows,'pointSampleSpacingMetres':.025,'fixtureChecks':17,'sameBufferSamplesAsUpstream':True,'westMaximumEDTClearanceLowerBoundMetres':previous['westMaximumDiscClearanceLowerBoundMetres'],'widthMeaning':'rectangles include margins geometrically; EDT radius lower bound is not a measured corridor width','sourceInputSHA256':pins,'referenceInputsUsed':False,'nativeRouteQueries':0,'movementEpisodes':0,'physicalAuthority':False,'permissionsUnchanged':True}
 for p,h in pins.items():assert sha(WS/p)==h
 result.update(sourceInputsVerifiedBeforeAfter=True,wallSeconds=time.monotonic()-start,observedPeakRSSBytes=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss*1024)
 assert result['observedPeakRSSBytes']<256*1024**2
 data=(json.dumps(result,indent=2)+'\n').encode();assert len(data)<1024**2
 if shutil.disk_usage(HERE).free-len(data)<768*1024**2:raise RuntimeError('disk reserve terminal')
 with (HERE/'RAW_BODY_VS_BUFFER.json').open('xb')as f:f.write(data)
 signal.alarm(0);print(json.dumps({k:v for k,v in result.items()if k not in ['fittingCentres','sourceInputSHA256']}))
if __name__=='__main__':main()
