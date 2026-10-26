import numpy as np,octomap,time
from classify import grid,columns
Pl=np.load('m2_level_points.npy').astype(np.float64);Fs=np.load('m2_level_frames.npy');Cl=np.load('m2_level_cams.npy')
t=octomap.OcTree(.05);b=np.searchsorted(Fs,np.arange(len(Cl)+1));t0=time.time()
for i in range(len(Cl)):t.insertPointCloud(Pl[b[i]:b[i+1]],Cl[i],maxrange=-1.,discretize=True)
t.updateInnerOccupancy();occ,emp=t.extractPointCloud();print('discretize=True secs',round(time.time()-t0,1),'occ',len(occ),'free',len(emp))
for lab,(o,f) in (('full rays',(np.load('m2_occ.npy'),np.load('m2_free.npy'))),('one ray per endpoint voxel',(occ,emp))):
  st,lo=grid(o,f);c=columns(st,lo)
  print(lab,{k:int(v.sum()) for k,v in c.items()},'support&~obstacle&~unknown',int((c['support']&~c['obstacle']&~c['unknown']).sum()))
