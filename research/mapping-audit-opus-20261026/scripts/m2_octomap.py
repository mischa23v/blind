"""Diagnostic baseline: released OctoMap 1.10 (octomap-python 1.10.0.0) occupancy fusion
over LiDAR-native samples (one per 4x4 nearest-upscaled block) in a measured level frame.
Not app code. No FARO input."""
import numpy as np,octomap,time,json,sys
from common import *
RES=.05
P=np.load('samples.npy').astype(np.float64);F=np.load('sampleframe.npy');cams=np.load('cams.npy')
# Level frame from robust plane over 20cm floor-cell medians (a5.py); floor -> z=0
r=np.load('floorcells.npy');A=np.c_[r[:,0],r[:,1],np.ones(len(r))];k=np.linalg.lstsq(A,r[:,2],rcond=None)[0]
n=np.array([-k[0],-k[1],1.]);n/=np.linalg.norm(n)
x=np.array([1.,0,0]);x-=n*x.dot(n);x/=np.linalg.norm(x);y=np.cross(n,x)
R=np.stack((x,y,n));t=-R@np.array([0,0,k[2]])
OFF=RES/2  # floor plane at the centre of voxel layer 0: layer k spans heights [k*RES-OFF,k*RES+OFF)
def lvl(p):return p@R.T+t+[0,0,OFF]
Pl=lvl(P);Cl=lvl(cams)
json.dump({'plane':k.tolist(),'R':R.tolist(),'t':t.tolist(),'offset':OFF},open('m2_frame.json','w'))
tree=octomap.OcTree(RES)
t0=time.time()
order=np.argsort(F,kind='stable');Pl=Pl[order];Fs=F[order]
b=np.searchsorted(Fs,np.arange(len(cams)+1))
for i in range(len(cams)):
  tree.insertPointCloud(Pl[b[i]:b[i+1]],Cl[i],maxrange=-1.)
  if i%50==0:print('frame',i,round(time.time()-t0,1),flush=True)
tree.updateInnerOccupancy()
print('insert secs',time.time()-t0,'leaves',tree.getNumLeafNodes(),'probs hit/miss/thr/clamp',tree.getProbHit(),tree.getProbMiss(),tree.getOccupancyThres(),tree.getClampingThresMin(),tree.getClampingThresMax())
tree.writeBinary(b'm2.bt')
occ,emp=tree.extractPointCloud()
np.save('m2_occ.npy',occ);np.save('m2_free.npy',emp);np.save('m2_level_points.npy',Pl.astype(np.float32));np.save('m2_level_frames.npy',Fs);np.save('m2_level_cams.npy',Cl)
print('occupied',len(occ),'free',len(emp),'total secs',time.time()-t0)
