import numpy as np
from PIL import Image
from classify import grid,columns
st,lo=grid(np.load('m2_occ.npy'),np.load('m2_free.npy'));c=columns(st,lo)
P=np.load('m2_level_points.npy');F=np.load('m2_level_frames.npy');C=np.load('m2_level_cams.npy')
h=P[:,2]-.025;rng=np.linalg.norm(P-C[F],axis=1)
s=(np.abs(h)<.12)&(rng<2.0)
i=np.floor(P[s,0]/.05).astype(int)-lo[0];j=np.floor(P[s,1]/.05).astype(int)-lo[1]
H,W=c['walk'].shape;ok=(i>=0)&(i<H)&(j>=0)&(j<W);i,j,hh=i[ok],j[ok],h[s][ok]
key=i*W+j;o=np.argsort(key);key=key[o];hh=hh[o];u,st0=np.unique(key,return_index=True);en=np.r_[st0[1:],len(key)]
med=np.full(H*W,np.nan)
for a,b,k in zip(st0,en,u):
  if b-a>=20: med[k]=np.median(hh[a:b])
med=med.reshape(H,W)
print('near-range floor median height (cm) over columns p1/5/50/95/99',np.round(np.nanpercentile(med*100,[1,5,50,95,99]),2))
pur=c['support']&c['below']&~c['obstacle'];gr=c['walk']
print('purple(below) columns median floor height cm p10/50/90',np.round(np.nanpercentile(med[pur]*100,[10,50,90]),2),' green',np.round(np.nanpercentile(med[gr]*100,[10,50,90]),2))
v=np.clip((med+.05)/.10,0,1);img=np.zeros((H,W,3),np.uint8)+40
m=np.isfinite(med);img[m,0]=(255*v[m]).astype(np.uint8);img[m,2]=(255*(1-v[m])).astype(np.uint8);img[m,1]=60
Image.fromarray(np.transpose(img,(1,0,2))[::-1]).resize((W*3,H*3),Image.NEAREST).save('floor_height.png')
np.save('floor_med_near.npy',med)
