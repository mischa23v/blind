import numpy as np
from classify import grid
A,lo=grid(np.load('m2_occ.npy'),np.load('m2_free.npy'))
z0=-lo[2];sup=A[:,:,z0]==2
print('all-range tree, supported columns:',int(sup.sum()))
for k in (-3,-2,-1,1,2,3,4):
  occ=A[:,:,z0+k]==2
  print(f' layer {k:+d} ({k*5-2.5:+.1f}..{k*5+2.5:+.1f} cm): occupied in {int((sup&occ).sum())} supported columns')
# isolated-ness: of supported columns with layer +1 occupied, how many have no occupancy in layers +2..+4 (thin low band only)
l1=(A[:,:,z0+1]==2)&sup;up=(A[:,:,z0+2:z0+5]==2).any(2)
print('layer+1 occupied with nothing in +2..+4:',int((l1&~up).sum()),' with something above:',int((l1&up).sum()))
