import numpy as np
from PIL import Image
from scipy import ndimage
m=np.load('policyD.npz');lo=m['lo'];cams=np.load('m2_level_cams.npy')
H,W=m['walk'].shape;img=np.full((H,W,3),40,np.uint8)
img[m['highUnknown']]=(90,90,90)
img[m['highObstacle']]=(200,60,60)
img[m['low1']&~m['highObstacle']]=(255,150,0)
img[(m['deepBelow']|m['nearDip'])&~m['highObstacle']]=(160,60,200)
img[m['walk']]=(60,150,70)
img[m['walk']&m['lowUnresolvedFlag']]=(60,110,160)
d=ndimage.distance_transform_edt(m['walk'])*.05-.05*np.sqrt(2)/2
img[d>=.3704]=(120,230,120);img[d>=.4204]=(230,255,230)
for p in cams:
  i,j=int(np.floor(p[0]/.05))-lo[0],int(np.floor(p[1]/.05))-lo[1]
  if 0<=i<H and 0<=j<W: img[i,j]=(255,255,0)
Image.fromarray(np.transpose(img,(1,0,2))[::-1]).resize((W*3,H*3),Image.NEAREST).save('policyD_topdown.png')
# low1 provenance among cells bordering walkable
