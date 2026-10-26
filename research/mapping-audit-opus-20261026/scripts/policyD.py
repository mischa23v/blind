import numpy as np
from scipy import ndimage
from classify import grid
TOP=1.75
A,lo=grid(np.load('m2_occ.npy'),np.load('m2_free.npy'),TOP)
N,lo2=grid(np.load('m3_occ_2.0.npy'),np.load('m3_free_2.0.npy'),TOP)
NN=np.zeros_like(A);off=lo2-lo;sh=np.array(N.shape)
sl=tuple(slice(max(0,o),min(a,o+s)) for o,a,s in zip(off,A.shape,sh));sl2=tuple(slice(max(0,-o),max(0,-o)+(t.stop-t.start)) for o,t in zip(off,sl));NN[sl]=N[sl2];N=NN
z0=-lo[2];L=int(round(TOP/.05))
sup=A[:,:,z0]==2
deep=(A[:,:,:z0-1]==2).any(2)                       # >=7.5 cm below plane, all ranges
dipN=N[:,:,z0-1]==2                                 # 2.5-7.5 cm below, near evidence
dipFarOnly=(A[:,:,z0-1]==2)&(N[:,:,z0-1]==0)
l1A=A[:,:,z0+1];l1N=N[:,:,z0+1]
low1=(l1N==2)|((l1A==2)&(l1N!=1))                    # near occupied, or fused all-range occupied unless near says free
low1Unresolved=(l1N==0)&(l1A!=2)                     # no near view, no positive evidence: below 7.5cm unresolved
body=A[:,:,z0+2:z0+L+1];bodyN=N[:,:,z0+2:z0+L+1]
hi=((body==2)|(bodyN==2)).any(2);hiUnk=((body==0)&(bodyN==0)).any(2)
blocked=~sup|deep|dipN|low1|hi|hiUnk|(l1A==0)&(l1N==0)
walk=~blocked
info=dict(support=sup,deepBelow=deep,nearDip=dipN,farOnlyDipFlag=dipFarOnly&walk,low1=low1,lowUnresolvedFlag=low1Unresolved&walk,highObstacle=hi,highUnknown=hiUnk,walk=walk)
print({k:int(v.sum()) for k,v in info.items()})
np.savez('policyD.npz',lo=lo,**info)
d=ndimage.distance_transform_edt(walk)*.05-.05*np.sqrt(2)/2
for r in (.2704,.3704,.4204,.5324,.60):
  v=d>=r;lab,n=ndimage.label(v,structure=np.ones((3,3)));sz=np.bincount(lab.ravel())[1:]
  big=sz.max() if n else 0
  ext=0
  if n:
    ys,xs=np.nonzero(lab==1+np.argmax(sz));ext=np.hypot(np.ptp(ys),np.ptp(xs))*.05
  print(f'r={r:.4f}: valid centres {int(v.sum())} ({v.sum()*.0025:.2f} m2) comps {n} largest {big} diag {ext:.2f} m')
