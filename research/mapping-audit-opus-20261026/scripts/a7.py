import numpy as np
P=np.load('m2_level_points.npy');F=np.load('m2_level_frames.npy');C=np.load('m2_level_cams.npy');OFF=.025
h=P[:,2]-OFF;fl=np.abs(h)<.10
rng=np.linalg.norm(P[fl]-C[F[fl]],axis=1);hf=h[fl]
# incidence: elevation angle of ray
dz=C[F[fl],2]-P[fl,2];inc=np.degrees(np.arcsin(np.clip(dz/rng,-1,1)))
k=np.floor(P[fl,:2]/.05).astype(int);key=k[:,0]*100000+k[:,1]
u,inv=np.unique(key,return_inverse=True)
near=rng<2.0
med=np.full(len(u),np.nan)
o=np.argsort(inv[near]);iv=inv[near][o];hs=hf[near][o];b=np.searchsorted(iv,np.arange(len(u)+1))
for i in range(len(u)):
  if b[i+1]-b[i]>=10: med[i]=np.median(hs[b[i]:b[i+1]])
res=hf-med[inv];ok=np.isfinite(res)
print('residual vs near-range (<2m) column median, by range band:')
for a,bb in ((0,1.5),(1.5,2.5),(2.5,3.5),(3.5,4.5),(4.5,7)):
  m=ok&(rng>=a)&(rng<bb)
  if m.sum()>1000:print(f'  range {a}-{bb} m: n={m.sum():8d} p50 {np.median(res[m])*100:+.2f} cm, |res| p95 {np.percentile(np.abs(res[m]),95)*100:.2f} p99 {np.percentile(np.abs(res[m]),99)*100:.2f} cm')
for a,bb in ((0,20),(20,35),(35,50),(50,90)):
  m=ok&(inc>=a)&(inc<bb)
  if m.sum()>1000:print(f'  incidence {a}-{bb} deg: n={m.sum():8d} |res| p95 {np.percentile(np.abs(res[m]),95)*100:.2f} p99 {np.percentile(np.abs(res[m]),99)*100:.2f} cm')
