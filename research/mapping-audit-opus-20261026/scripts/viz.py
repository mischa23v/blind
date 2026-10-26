import numpy as np,sys
from PIL import Image
from classify import grid,columns
st,lo=grid(np.load('m2_occ.npy'),np.load('m2_free.npy'));c=columns(st,lo)
cams=np.load('m2_level_cams.npy')
H,W=c['walk'].shape
img=np.full((H,W,3),40,np.uint8)
img[c['unknown']]=(90,90,90)
img[c['support']]=(200,200,120)          # support but something else
img[c['obstacle']]=(200,60,60)
img[c['support']&c['below']&~c['obstacle']]=(160,60,200)
img[c['walk']]=(80,200,90)
for p in cams:
  i,j=int(np.floor(p[0]/.05))-lo[0],int(np.floor(p[1]/.05))-lo[1]
  if 0<=i<H and 0<=j<W: img[i,j]=(255,255,255)
Image.fromarray(np.transpose(img,(1,0,2))[::-1]).resize((W*3,H*3),Image.NEAREST).save('m2_topdown.png')
print(H,W)
