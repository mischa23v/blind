"""How far outside real geometry does the phone map block, and does uniform obstacle inflation of the
REFERENCE map alone reproduce the route collapse? (Reference-only erosion = diagnostic, FARO geometry.)"""
import sys,numpy as np,math
from scipy import ndimage
from PIL import Image
import routes_rect as R
for room in ('koivu','coffee_room'):
  o=np.load(__import__('os').environ['RUNS_DIR']+'/'+room+'/pipeline_out.npz')
  walk=o['walk'];rw=o['refWalk'];cov=o['ref_n']>0;refgeom=(o['ref_low_max']>-np.inf)|(o['ref_body_max']>-np.inf)
  d=ndimage.distance_transform_edt(~(refgeom&cov))*.05
  fb=rw&~walk
  print(f'[{room}] ref-walkable but phone-blocked: {int(fb.sum())}; distance to nearest reference geometry (m) p25/50/75/90:',np.round(np.percentile(d[fb],[25,50,75,90]),2),' >0.15 m:',int((d[fb]>.15).sum()))
  lo=o['lo'];np.savez('policyD.npz',lo=lo)
  import io,contextlib
  for k in (0,1,2,3):
    er=ndimage.binary_erosion(rw,structure=np.ones((3,3)),iterations=k) if k else rw
    buf=io.StringIO()
    with contextlib.redirect_stdout(buf):R.run(er,f'{room} REFERENCE eroded {k*5} cm')
    print('  ',buf.getvalue().strip()[:400])
  H,W=walk.shape;img=np.full((H,W,3),40,np.uint8);img[cov]=(70,70,70);img[cov&refgeom]=(150,60,60);img[rw&~walk]=(60,90,200);img[rw&walk]=(80,200,90);img[walk&~rw&cov]=(255,200,0)
  Image.fromarray(np.transpose(img,(1,0,2))[::-1]).resize((W*3,H*3),Image.NEAREST).save(f'{room}_ref_vs_phone.png')
