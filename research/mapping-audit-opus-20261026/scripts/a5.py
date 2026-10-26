import numpy as np
P=np.load('samples.npy');F=np.load('sampleframe.npy')
s=(P[:,2]>-1.40)&(P[:,2]<-1.16);Q=P[s];FQ=F[s]
C=.2;ix=np.floor(Q[:,0]/C).astype(int);iy=np.floor(Q[:,1]/C).astype(int)
key=ix*10000+iy
order=np.argsort(key);key=key[order];Q=Q[order];FQ=FQ[order]
u,start,cnt=np.unique(key,return_index=True,return_counts=True)
rows=[]
for k,s0,n in zip(u,start,cnt):
  if n<300:continue
  z=Q[s0:s0+n,2];hst,e=np.histogram(z,bins=np.arange(-1.40,-1.159,.005));m=e[np.argmax(hst)]+.0025
  near=z[np.abs(z-m)<.06]
  if len(near)<200:continue
  med=np.median(near);mad=1.4826*np.median(np.abs(near-med))
  # per-frame offsets within cell
  fr=FQ[s0:s0+n][np.abs(z-m)<.06];offs=[np.median(near[fr==j])-med for j in np.unique(fr) if (fr==j).sum()>=20]
  rows.append((k//10000*C+C/2,k%10000*C+C/2 if k%10000<5000 else (k%10000-10000)*C+C/2,med,mad,len(near),np.ptp(offs) if offs else 0,np.std(offs) if len(offs)>1 else 0, np.percentile(np.abs(near-med),99)))
r=np.array(rows)
print('floor cells (20cm)',len(r))
print('floor median height p5/50/95',np.round(np.percentile(r[:,2],[5,50,95]),3))
A=np.c_[r[:,0],r[:,1],np.ones(len(r))];k=np.linalg.lstsq(A,r[:,2],rcond=None)[0];e=r[:,2]-A@k
print('plane over cell medians: slope x,y (cm/m) %.2f %.2f, tilt %.2f deg, residual std %.3f, p95 |res| %.3f'%(k[0]*100,k[1]*100,np.degrees(np.arctan(np.hypot(k[0],k[1]))),np.std(e),np.percentile(np.abs(e),95)))
print('within-cell robust sigma p50/p90',np.round(np.percentile(r[:,3],[50,90]),4))
print('within-cell 99th pct |dev| p50/p90',np.round(np.percentile(r[:,7],[50,90]),4))
print('per-frame offset std within cell p50/p90',np.round(np.percentile(r[:,6],[50,90]),4),' range p50/p90',np.round(np.percentile(r[:,5],[50,90]),4))
print('x extent',r[:,0].min(),r[:,0].max(),'y extent',r[:,1].min(),r[:,1].max())
np.save('floorcells.npy',r)
