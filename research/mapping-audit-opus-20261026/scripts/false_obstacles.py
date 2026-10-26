import numpy as np
from scipy import ndimage
from classify import grid
ref=np.load('ref_columns.npz');D=np.load('policyD.npz');lo=D['lo']
cov=ref['n']>0;refgeom=(ref['low_max']>-np.inf)|(ref['body_max']>-np.inf)
sup=D['support'];hiO=D['highObstacle'];low1=D['low1']
A,la=grid(np.load('m2_occ.npy'),np.load('m2_free.npy'));N,ln=grid(np.load('m3_occ_2.0.npy'),np.load('m3_free_2.0.npy'))
NN=np.zeros_like(A);off=ln-la;sh=np.array(N.shape)
sl=tuple(slice(max(0,o),min(a,o+s)) for o,a,s in zip(off,A.shape,sh));sl2=tuple(slice(max(0,-o),max(0,-o)+(t.stop-t.start)) for o,t in zip(off,sl));NN[sl]=N[sl2];N=NN
z0=-la[2]
falseHi=hiO&sup&cov&~refgeom;trueHi=hiO&sup&cov&refgeom
print('D1 high-obstacle supported columns: reference-confirmed',int(trueHi.sum()),' NOT confirmed (false)',int(falseHi.sum()))
dtrue=ndimage.distance_transform_edt(~(refgeom&cov))*.05
print(' false columns distance to nearest reference geometry (m) p10/50/90:',np.round(np.percentile(dtrue[falseHi],[10,50,90]),2),' >0.20 m:',int((dtrue[falseHi]>.2).sum()))
# lowest occupied layer in body band for false vs true, and whether that layer is occupied in the NEAR tree
body=A[:,:,z0+2:z0+36]==2;bodyN=N[:,:,z0+2:z0+36]==2
def lowest(mask,G):
  out=[]
  for i,j in np.argwhere(mask):
    k=np.flatnonzero(G[i,j]);out.append((k[0]+2)*5 if len(k) else -1)
  return np.array(out)
lf=lowest(falseHi,body|bodyN);lt=lowest(trueHi,body|bodyN)
print(' lowest occupied height (cm) false: p10/50/90',np.percentile(lf,[10,50,90]),' true:',np.percentile(lt,[10,50,90]))
nearSeen=np.array([bodyN[i,j].any() for i,j in np.argwhere(falseHi)]);print(' false columns whose body-band occupancy is also in the NEAR (<=2 m) tree:',int(nearSeen.sum()),'/',len(nearSeen))
# count occupied layers (thickness) false vs true
tf=np.array([(body|bodyN)[i,j].sum() for i,j in np.argwhere(falseHi)]);tt=np.array([(body|bodyN)[i,j].sum() for i,j in np.argwhere(trueHi)])
print(' occupied body layers per column false p50/p90',np.percentile(tf,[50,90]),' true',np.percentile(tt,[50,90]))
# low1 false
falseLow=low1&sup&~hiO&cov&~refgeom;print('D1 low-band positive columns (not high): total',int((low1&sup&~hiO&cov).sum()),' reference-confirmed',int((low1&sup&~hiO&cov&refgeom).sum()),' false',int(falseLow.sum()),' false within 0.2 m of ref geometry:',int((dtrue[falseLow]<=.2).sum()))
np.save('false_hi.npy',falseHi)
