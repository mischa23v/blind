import numpy as np
P=np.load('m2_level_points.npy');F=np.load('m2_level_frames.npy');OFF=.025
h=P[:,2]-OFF
fl=np.abs(h)<.08
# per-frame floor offset using per-5cm-column medians relative to consensus
k=np.floor(P[fl,:2]/.05).astype(int);key=k[:,0]*100000+k[:,1];hf=h[fl];ff=F[fl]
u,inv=np.unique(key,return_inverse=True)
# consensus per column = median over all samples
order=np.argsort(inv);invs=inv[order];hs=hf[order]
b=np.searchsorted(invs,np.arange(len(u)+1));cons=np.array([np.median(hs[b[i]:b[i+1]]) for i in range(len(u))])
res=hf-cons[inv]
off=np.array([np.median(res[ff==j]) if (ff==j).sum()>500 else np.nan for j in range(294)])
print('per-frame median floor offset (cm): p5/p50/p95',np.round(np.nanpercentile(off*100,[5,50,95]),2),'min/max',np.round(np.nanmin(off*100),2),np.round(np.nanmax(off*100),2),'frames with floor',np.isfinite(off).sum())
print('frames |offset|>2cm',np.flatnonzero(np.abs(off)>.02).tolist())
print('column consensus height (cm) p1/p50/p99',np.round(np.percentile(cons*100,[1,50,99]),2))
print('residual |res| p50/p95/p99 (cm)',np.round(np.percentile(np.abs(res)*100,[50,95,99]),2))
np.save('frame_floor_offset.npy',off)
# smooth trend over time?
import itertools
print('offset by frame (every 10):',[round(float(o*100),1) if np.isfinite(o) else None for o in off[::10]])
