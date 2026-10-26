import numpy as np
from scipy import ndimage
from classify import grid
m=np.load('policyD.npz');lo=m['lo']
hi=m['highObstacle']|m['low1']
lab,n=ndimage.label(hi,structure=np.ones((3,3)));sz=np.bincount(lab.ravel())
small=(sz[lab]<=3)&hi
# surrounded by walk: dilate small blob and check neighbours walk
print('obstacle blobs <=3 columns:',int(small.sum()),'columns in',len(np.unique(lab[small])),'blobs')
A,_=grid(np.load('m2_occ.npy'),np.load('m2_free.npy'))
z0=-lo[2]
P=np.load('m2_level_points.npy');F=np.load('m2_level_frames.npy');C=np.load('m2_level_cams.npy')
k=np.floor(P/.05).astype(int)-lo
ok=np.all((k>=0)&(k<A.shape),1)
smallvox=np.zeros(A.shape,bool)
for (i,j) in zip(*np.nonzero(small)):
  smallvox[i,j,:]=(A[i,j,:]==2)
smallvox[:,:,:z0+1]=False
sel=ok.copy();sel[ok]=smallvox[k[ok,0],k[ok,1],k[ok,2]]
key=(k[sel,0]*A.shape[1]+k[sel,1])*A.shape[2]+k[sel,2];fr=F[sel];rng=np.linalg.norm(P[sel]-C[F[sel]],axis=1)
u,inv=np.unique(key,return_inverse=True)
nfr=np.array([len(np.unique(fr[inv==q])) for q in range(len(u))]);nhit=np.bincount(inv)
hz=(u%A.shape[2]-z0)*.05
print('voxels',len(u),'distinct frames per voxel p50/p90/max',np.percentile(nfr,[50,90]),nfr.max(),' single-frame voxels',int((nfr==1).sum()))
print('hits per voxel p50/p90',np.percentile(nhit,[50,90]),' heights (m) p10/50/90',np.round(np.percentile(hz,[10,50,90]),2),' range of hits p50',np.round(np.median(rng),2))
