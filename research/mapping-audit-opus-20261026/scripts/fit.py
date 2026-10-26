import numpy as np,sys
from scipy import ndimage
from classify import grid,columns
def fits(walk,label):
  d=ndimage.distance_transform_edt(walk)*.05  # centre-to-nearest blocked centre
  clear=d-.05/2  # conservative: to nearest blocked cell edge >= centre distance - half cell (axis); use half-diagonal for safety
  clear=d-.05*np.sqrt(2)/2
  out=[]
  for r in (.2704,.3704,.4204,.5324,.60):
    v=clear>=r;lab,n=ndimage.label(v,structure=np.ones((3,3)))
    sizes=np.bincount(lab.ravel())[1:] if n else np.array([0])
    big=sizes.max() if n else 0
    # extent of largest component
    if n:
      ys,xs=np.nonzero(lab==1+np.argmax(sizes));ext=np.hypot(np.ptp(ys),np.ptp(xs))*.05
    else: ext=0
    out.append(f'r={r:.4f}: valid centres {int(v.sum())} ({v.sum()*.0025:.2f} m2), components {n}, largest {big} cells, largest diag extent {ext:.2f} m')
  print(label);[print('  ',o) for o in out]
st,lo=grid(np.load('m2_occ.npy'),np.load('m2_free.npy'));c=columns(st,lo)
fits(c['walk'],'M2 all-range OctoMap, own column rules (below-floor from all ranges)')
fits(c['support']&~c['obstacle']&~c['unknown'],'M2 without below-floor blocking (diagnostic only)')
for n in ('2.0','1.5'):
  m=np.load(f'm3_cols_{n}.npz');fits(m['walk'],f'M3 near-range low band <= {n} m')
