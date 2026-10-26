"""Fixture: render axis-aligned boxes into the REAL recorded rays (level frame), then rerun
the same OctoMap fusion + policy D1 classification. Tests pipeline retention only; the
inserted surfaces are noise-free, so this is not sensor detection evidence."""
import numpy as np,octomap,json
from scipy import ndimage
m=np.load('policyD.npz');lo=m['lo'];walk=m['walk']
d=ndimage.distance_transform_edt(walk)
green=walk&~m['lowUnresolvedFlag'];blue=walk&m['lowUnresolvedFlag']
def pick(mask,avoid=[]):
  dd=np.where(mask,d,0).astype(float)
  for a in avoid: dd[max(0,a[0]-30):a[0]+30,max(0,a[1]-30):a[1]+30]=0
  return np.unravel_index(np.argmax(dd),dd.shape)
g1=pick(green);g2=pick(green,[g1]);b1=pick(blue);b2=pick(blue,[b1])
boxes=[]
for (i,j),h,name in ((g1,.04,'near-zone 4cm'),(g2,.08,'near-zone 8cm'),(b1,.04,'far-only-zone 4cm'),(b2,.08,'far-only-zone 8cm')):
  cx,cy=(i+lo[0]+.5)*.05,(j+lo[1]+.5)*.05
  boxes.append(dict(name=name,col=[int(i),int(j)],lo=[cx-.05,cy-.05,.025],hi=[cx+.05,cy+.05,.025+h]))  # floor plane at z=0.025 in tree coords
print(json.dumps(boxes,indent=1))
P=np.load('m2_level_points.npy').astype(np.float64);F=np.load('m2_level_frames.npy');C=np.load('m2_level_cams.npy')
O=C[F];D=P-O;tmin=np.zeros(len(P));tmax=np.ones(len(P))
best=np.ones(len(P))
for b in boxes:
  t0=np.zeros(len(P));t1=np.ones(len(P))
  for a in range(3):
    with np.errstate(divide='ignore',invalid='ignore'):
      ta=(b['lo'][a]-O[:,a])/D[:,a];tb=(b['hi'][a]-O[:,a])/D[:,a]
    lo_=np.minimum(ta,tb);hi_=np.maximum(ta,tb)
    par=D[:,a]==0;inside=(O[:,a]>=b['lo'][a])&(O[:,a]<=b['hi'][a])
    lo_[par]=np.where(inside[par],-np.inf,np.inf);hi_[par]=np.where(inside[par],np.inf,-np.inf)
    t0=np.maximum(t0,lo_);t1=np.minimum(t1,hi_)
  hit=(t0<=t1)&(t0<best)&(t0>0)
  b['raysHit']=int(hit.sum());b['framesHit']=int(len(np.unique(F[hit])))
  best[hit]=t0[hit]
Q=O+D*best[:,None]
print([(b['name'],b['raysHit'],b['framesHit']) for b in boxes])
def fuse(maxrange):
  t=octomap.OcTree(.05);bnd=np.searchsorted(F,np.arange(len(C)+1))
  for i in range(len(C)):t.insertPointCloud(Q[bnd[i]:bnd[i+1]],C[i],maxrange=maxrange)
  t.updateInnerOccupancy();return t.extractPointCloud()
oa,fa=fuse(-1.);on,fn=fuse(2.0)
np.save('inj_occ.npy',oa);np.save('inj_free.npy',fa);np.save('inj_occ_near.npy',on);np.save('inj_free_near.npy',fn)
json.dump(boxes,open('inj_boxes.json','w'),indent=1)
