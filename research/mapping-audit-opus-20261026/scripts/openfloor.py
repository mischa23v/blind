"""Pre-declared refinement of the safety metric (declared before the holdout threshold run is read):
  edge miss  = walkable column with reference geometry >=2.5 cm (low band) or any body/head-band geometry (overhang), within 0.15 m (the margin) of a still-blocked column
  OPEN-FLOOR miss = same, but farther than 0.15 m from any blocked column  -> the real safety failure class
Criterion: open-floor misses must not increase vs baseline; edge misses are reported as boundary tightness."""
import sys,numpy as np
from scipy import ndimage
d=sys.argv[1]
o=np.load(d+'/pipeline2_out.npz');cov=o['ref_n']>0;low=o['ref_low_max'];body=o['ref_body_max'];lo=o['lo'];RES=float(o['res']) if 'res' in o.files else .05
def report(name,w):
  dblk=ndimage.distance_transform_edt(w)*RES;m=w&cov&((low>=.025)|(body>-np.inf))   # low objects OR overhead/body-band geometry (overhangs)
  edge=m&(dblk<=.15);openf=m&(dblk>.15)
  rows=[(int(i),int(j),round(float((i+lo[0])*RES),2),round(float((j+lo[1])*RES),2),round(float(low[i,j]*100),1),round(float(body[i,j]*100),1) if body[i,j]>-np.inf else None,round(float(dblk[i,j]),2)) for i,j in np.argwhere(openf)]
  print(f'{name:28s} walkable {int(w.sum()):6d}  edge misses {int(edge.sum()):4d}  OPEN-FLOOR misses {int(openf.sum()):3d}  ',rows[:8])
import glob,os
for f in sorted(glob.glob(d+'/occthres_*.npz')):report(os.path.basename(f),np.load(f)['walk'])
for k in ('D1','D1_noUngrounded','TSDF_surface'):
  if f'{k}__walk' in o.files:report(k,o[f'{k}__walk'])
