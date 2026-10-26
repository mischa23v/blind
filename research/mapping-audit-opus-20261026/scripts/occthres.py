"""Pre-declared variant: upstream OctoMap occupancy threshold raised from 0.5 (default) to 0.6/0.7/0.8, i.e. a
voxel needs more net hit evidence before it counts as occupied. No custom filter. Scored SAFETY-FIRST against
the reference (miss rate must not rise vs baseline), then routes. usage: occthres.py <room> <long_capture_dir> <runs2_dir_of_room>"""
import sys,os,json,numpy as np,octomap,time
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
import pipeline as PL,pipeline2 as P2
from pipeline import load_frames,lidar_samples,level_frame,score
room,d,rundir=sys.argv[1:4];os.chdir(rundir)
o=np.load('pipeline2_out.npz');lo=o['lo'];R=o['R'];t=o['t'];state=o['state'];rw=o['refWalk'];RES=.05
ref={k[4:]:o[k] for k in o.files if k.startswith('ref_')};cov=ref['n']>0;refgeom=(ref['low_max']>-np.inf)|(ref['body_max']>-np.inf)
T=load_frames(d);cams=np.array([f['transform_matrix'] for f in T])[:,:3,3]
P,F,_=lidar_samples(d,T);Pl=(P@R.T+t+[0,0,RES/2]);Cl=cams@R.T+t+[0,0,RES/2];oi=np.argsort(F,kind='stable');Pl=Pl[oi];F=F[oi]
def tree(maxrange):
  tr=octomap.OcTree(RES);b=np.searchsorted(F,np.arange(len(Cl)+1))
  for i in range(len(Cl)):tr.insertPointCloud(Pl[b[i]:b[i+1]],Cl[i],maxrange=maxrange)
  tr.updateInnerOccupancy();return tr
tA=tree(-1.);tN=tree(PL.THRESHOLDS['near_m']);print('trees built',flush=True)
shape=o['D1__walk'].shape+(int(np.ceil(1.85/RES))+int(np.ceil(.20/RES))+1,);z0=int(np.ceil(.20/RES))
base=None;out={};SPLIT=os.environ.get('SPLIT')=='1';sup05=None
for thr in (0.5,0.6,0.7,0.8):
  for tr in (tA,tN):tr.setOccupancyThres(thr)
  oA,fA=tA.extractPointCloud();oN,fN=tN.extractPointCloud()
  A=P2.grid3(oA,fA,lo,shape,RES);N=P2.grid3(oN,fN,lo,shape,RES)
  if thr==0.5:sup05=(A[:,:,P2.band_layers(RES,z0,shape[2])[0]]==2).any(2)
  D=P2.classify(A,N,z0,RES,support_override=(sup05 if SPLIT else None));walk=D['walk']
  r={}
  for mk,mm in (('permissive',walk),('statClear',walk&(state=='clear'))):
    sc=score(mm,ref);sc['missRatePct']=round(100*sc['refLow25']/max(sc['n'],1),3);sc['refWalkPhoneBlocked']=int((rw&~mm).sum());r[mk]=sc
  if base is None:base=walk
  newly=walk&~base&cov;r['unblockedVsBase']=int(newly.sum());r['unblockedVsBase_refGeom']=int((newly&refgeom).sum());r['unblockedVsBase_refLow25']=int((newly&(ref['low_max']>=.025)).sum())
  r['occupiedLeavesAll']=int(len(oA));out[thr]=r;print(json.dumps({'thr':thr,**r}),flush=True)
  np.savez(f'occthres_{"split" if SPLIT else ""}{thr}.npz',**D)
  for mk,mm in (('permissive',walk),('statClear',walk&(state=='clear'))):P2.run_routes(mm,lo,RES,os.environ['RECAST_ADAPTER_DIR'],f'{room} {"split-support " if SPLIT else ""}thr={thr} {mk}')
json.dump(out,open('OCCTHRES_SPLIT_RESULTS.json' if SPLIT else 'OCCTHRES_RESULTS.json','w'),indent=1)
