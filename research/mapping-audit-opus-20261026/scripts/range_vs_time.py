"""Depth-bias vs pose-drift discriminator (from the research report): regress each frame's floor offset on its
median floor-sample range; compare with how much the offset is explained by temporal neighbours."""
import sys,os,json,numpy as np
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
import pipeline as PL;PL.T0=0
from floorfix import floor_fit
d=sys.argv[1];T=json.load(open(d+'/transformations.json'))['frames'];C=np.array([f['transform_matrix'] for f in T])
P,F,_=PL.lidar_samples(d,T);R,t=PL.level_frame(P,C[:,:3,3]);o=np.argsort(F,kind='stable');P=P[o];F=F[o];b=np.searchsorted(F,np.arange(len(T)+1));cams=C[:,:3,3]@R.T+t
rows=[]
for i in range(len(T)):
  pl=P[b[i]:b[i+1]]@R.T+t;rng=np.linalg.norm(pl-cams[i],axis=1);f=floor_fit(pl,rng)
  if f:
    m=(np.abs(pl[:,2]-(pl[:,0]*f['k'][0]+pl[:,1]*f['k'][1]+f['k'][2]))<.02)&(rng<4)
    rows.append((i,f['offset'],float(np.median(rng[m])),cams[i][2]))
r=np.array(rows);i,off,rg,camh=r.T
A=np.c_[rg,np.ones(len(rg))];k=np.linalg.lstsq(A,off,rcond=None)[0];res=off-A@k
r2_range=1-np.var(res)/np.var(off)
# temporal: predict each frame's offset by the median of its +-3 neighbours (excluding itself)
pred=np.array([np.median([off[j] for j in range(len(i)) if 0<abs(i[j]-i[q])<=3]) if any(0<abs(i[j]-i[q])<=3 for j in range(len(i))) else np.nan for q in range(len(i))])
ok=np.isfinite(pred);r2_time=1-np.var(off[ok]-pred[ok])/np.var(off[ok])
print(f'{os.path.basename(os.path.dirname(os.path.dirname(d)))}: frames {len(off)} | offset vs floor range slope {k[0]*100:+.2f} cm per m, R^2 {r2_range:.3f} | offset predicted by +-3 neighbouring frames R^2 {r2_time:.3f} | corr(offset, camera height) {np.corrcoef(off,camh)[0,1]:+.2f}')
