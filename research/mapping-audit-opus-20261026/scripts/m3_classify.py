import numpy as np,sys,json
from classify import grid
NEAR=sys.argv[1] if len(sys.argv)>1 else '2.0'
TOP=1.75
A,lo=grid(np.load('m2_occ.npy'),np.load('m2_free.npy'),TOP)
N,lo2=grid(np.load(f'm3_occ_{NEAR}.npy'),np.load(f'm3_free_{NEAR}.npy'),TOP)
# align N into A's index frame
NN=np.zeros_like(A);sh=np.array(N.shape);off=lo2-lo
sl=tuple(slice(max(0,o),min(a,o+s)) for o,a,s in zip(off,A.shape,sh));sl2=tuple(slice(max(0,-o),max(0,-o)+(t.stop-t.start)) for o,t in zip(off,sl))
NN[sl]=N[sl2];N=NN
z0=-lo[2];L=int(round(TOP/.05))
sup=N[:,:,z0]==2
low=N[:,:,z0+1:z0+3];lowobs=(low==2).any(2);lowunk=(low==0).any(2)
hiA=A[:,:,z0+3:z0+L+1];hiN=N[:,:,z0+3:z0+L+1]
hiobs=((hiA==2)|(hiN==2)).any(2);hiunk=((hiA==0)&(hiN==0)).any(2)
below=(N[:,:,z0-2:z0]==2).any(2)
walk=sup&~lowobs&~lowunk&~hiobs&~hiunk&~below
r=dict(support=sup,lowObstacle=lowobs,lowUnknown=lowunk,highObstacle=hiobs,highUnknown=hiunk,belowFloor=below,walk=walk)
print('near',NEAR,{k:int(v.sum()) for k,v in r.items()},'walk m2 %.2f'%(walk.sum()*.0025))
# far-only low occupancy overridden by near-free (reported, not hidden)
farlow=(A[:,:,z0+1:z0+3]==2).any(2)
print('columns where all-range tree has low-band occupancy but near tree says free (would be overridden):',int((farlow&~lowobs&~lowunk&sup).sum()))
np.savez(f'm3_cols_{NEAR}.npz',lo=lo,**r,farLowOverridden=farlow&~lowobs&~lowunk&sup)
