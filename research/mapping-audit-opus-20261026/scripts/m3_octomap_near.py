"""Second OctoMap tree: only beams up to NEAR m (OctoMap maxrange), for the low band."""
import numpy as np,octomap,time,sys
NEAR=float(sys.argv[1]) if len(sys.argv)>1 else 2.0
Pl=np.load('m2_level_points.npy').astype(np.float64);Fs=np.load('m2_level_frames.npy');Cl=np.load('m2_level_cams.npy')
tree=octomap.OcTree(.05);b=np.searchsorted(Fs,np.arange(len(Cl)+1));t0=time.time()
for i in range(len(Cl)):
  tree.insertPointCloud(Pl[b[i]:b[i+1]],Cl[i],maxrange=NEAR)
tree.updateInnerOccupancy();occ,emp=tree.extractPointCloud()
np.save(f'm3_occ_{NEAR}.npy',occ);np.save(f'm3_free_{NEAR}.npy',emp);print('near',NEAR,'occ',len(occ),'free',len(emp),'secs',round(time.time()-t0,1))
