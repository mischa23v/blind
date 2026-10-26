import numpy as np,json
from classify import grid
boxes=json.load(open('inj_boxes.json'))
base=np.load('policyD.npz');lo=base['lo']
def cls(occA,freeA,occN,freeN):
  A,la=grid(occA,freeA);N,ln=grid(occN,freeN)
  def at(G,lg,i,j,k):
    ii,jj,kk=i+lo[0]-lg[0],j+lo[1]-lg[1],k-lg[2]
    return int(G[ii,jj,kk])
  return A,la,N,ln,at
A,la,N,ln,at=cls(np.load('inj_occ.npy'),np.load('inj_free.npy'),np.load('inj_occ_near.npy'),np.load('inj_free_near.npy'))
A0,la0,N0,ln0,at0=cls(np.load('m2_occ.npy'),np.load('m2_free.npy'),np.load('m3_occ_2.0.npy'),np.load('m3_free_2.0.npy'))
names={0:'unknown',1:'free',2:'occupied'}
for b in boxes:
  i,j=b['col'];res=[]
  for di in (-1,0,1):
    for dj in (-1,0,1):
      ci,cj=i+di,j+dj
      l1A=at(A,la,ci,cj,1);l1N=at(N,ln,ci,cj,1);l2A=at(A,la,ci,cj,2);l2N=at(N,ln,ci,cj,2)
      low1=(l1N==2)or(l1A==2 and l1N!=1);hi=(l2A==2)or(l2N==2)
      res.append(low1 or hi)
  i0=b['col'];base_blk=not base['walk'][i,j]
  print(f"{b['name']:20s} rays {b['raysHit']:5d} frames {b['framesHit']:3d} | centre col layer+1 all={names[at(A,la,i,j,1)]:8s} near={names[at(N,ln,i,j,1)]:8s} layer+2 all={names[at(A,la,i,j,2)]:8s} | 3x3 cols blocked {sum(res)}/9 (baseline blocked before insert: {base_blk})")
