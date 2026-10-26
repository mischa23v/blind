import numpy as np,sys
from PIL import Image
m=np.load(f'm3_cols_{sys.argv[1]}.npz');lo=m['lo'];cams=np.load('m2_level_cams.npy')
H,W=m['walk'].shape;img=np.full((H,W,3),40,np.uint8)
img[m['highUnknown']|m['lowUnknown']]=(90,90,90)
img[m['support']]=(200,200,120)
img[m['support']&m['lowUnknown']]=(60,120,200)
img[m['highObstacle']]=(200,60,60)
img[m['lowObstacle']&~m['highObstacle']]=(255,150,0)
img[m['belowFloor']&~m['highObstacle']]=(160,60,200)
img[m['walk']]=(80,200,90)
for p in cams:
  i,j=int(np.floor(p[0]/.05))-lo[0],int(np.floor(p[1]/.05))-lo[1]
  if 0<=i<H and 0<=j<W: img[i,j]=(255,255,255)
Image.fromarray(np.transpose(img,(1,0,2))[::-1]).resize((W*3,H*3),Image.NEAREST).save(f'm3_topdown_{sys.argv[1]}.png')
s=m['support'];print('support columns:',int(s.sum()),' of which lowUnknown',int((s&m['lowUnknown']).sum()),' lowObstacle',int((s&m['lowObstacle']).sum()),' highObstacle',int((s&m['highObstacle']).sum()),' highUnknown',int((s&m['highUnknown']).sum()),' below',int((s&m['belowFloor']).sum()))
