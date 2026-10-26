"""Reference-only feasibility (EVALUATOR GEOMETRY AS A HYPOTHETICAL PERFECT MAP). Answers: do
2-6 m routes exist in Koivu for the declared person+margin at all? Not a planner result."""
import numpy as np,math,routes_rect as R
from scipy import ndimage
ref=np.load('ref_columns.npz');D=np.load('policyD.npz')
cov=ref['n']>0;floor=np.isfinite(ref['floor_h'])
blocked=(ref['low_max']>-np.inf)|(ref['body_max']>-np.inf)   # any geometry 1.5 cm .. 1.8 m above plane
walk=cov&floor&~blocked
# keep only the main connected region (the room interior), drop outside-room floor fragments
lab,k=ndimage.label(walk,structure=np.ones((3,3)));sz=np.bincount(lab.ravel());sz[0]=0;walk=lab==np.argmax(sz)
print('reference walkable columns (main region):',int(walk.sum()),'=%.1f m2'%(walk.sum()*.0025))
d=ndimage.distance_transform_edt(walk)*.05-.05*math.sqrt(2)/2
for r in (.2704,.3704,.375,.4204,.5324):
  v=d>=r;l,n=ndimage.label(v,structure=np.ones((3,3)))
  if n:s=np.bincount(l.ravel())[1:];ys,xs=np.nonzero(l==1+np.argmax(s));ext=np.hypot(np.ptp(ys),np.ptp(xs))*.05
  else:ext=0
  print(f' disc r={r:.4f}: centres {int(v.sum())}, largest component extent {ext:.2f} m')
np.save('ref_walk.npy',walk)
R.run(walk,'REFERENCE-ONLY map, rectangle 0.45x0.30 + 0.15 margin')
