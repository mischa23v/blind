"""Diagnostic: statistical low-band test per 5 cm column using ALL ranges, with a
range-dependent noise model calibrated on near-resolved floor and per-frame vertical
bias removed. Thresholds chosen now, NOT frozen. Keeps three states: clear / object / unresolved."""
import numpy as np,json
P=np.load('m2_level_points.npy');F=np.load('m2_level_frames.npy');C=np.load('m2_level_cams.npy')
D=np.load('policyD.npz');lo=D['lo'];walk=D['walk'];flag=D['lowUnresolvedFlag'];sup=D['support']
off=np.load('frame_floor_offset.npy');off=np.where(np.isfinite(off),off,0.)
H,W=walk.shape
h=P[:,2]-.025-off[F]                       # height above plane, per-frame bias removed (declared pose refinement)
rng=np.linalg.norm(P-C[F],axis=1)
band=(h>-.10)&(h<.25)                      # samples that can speak about floor/low band
i=np.floor(P[band,0]/.05).astype(int)-lo[0];j=np.floor(P[band,1]/.05).astype(int)-lo[1]
ok=(i>=0)&(i<H)&(j>=0)&(j<W);i,j=i[ok],j[ok];hb=h[band][ok];rb=rng[band][ok];fb=F[band][ok]
col=i*W+j
# noise model sigma(range) from columns resolved clear by the near tier (walk & ~flag), MAD-based
cal=(walk&~flag).ravel()[col]
edges=np.array([0,1.0,1.5,2.0,2.5,3.0,3.5,4.5,8.0]);sig=[]
for a,b in zip(edges[:-1],edges[1:]):
  m=cal&(rb>=a)&(rb<b);x=hb[m]
  sig.append(1.4826*np.median(np.abs(x-np.median(x))) if m.sum()>500 else np.nan)
sig=np.array(sig);print('sigma(range) cm per bin',np.round(sig*100,2),'edges',edges.tolist())
sig=np.where(np.isfinite(sig),sig,np.nanmax(sig))
s_i=sig[np.clip(np.searchsorted(edges,rb,side='right')-1,0,len(sig)-1)]
w=1/s_i**2
n=np.bincount(col,minlength=H*W);Sw=np.bincount(col,weights=w,minlength=H*W);Swh=np.bincount(col,weights=w*hb,minlength=H*W)
nfr=np.zeros(H*W,int);u=np.unique(col*1000+fb);np.add.at(nfr,u//1000,1)
with np.errstate(invalid='ignore',divide='ignore'):
  mean=Swh/Sw;se=1/np.sqrt(Sw)
# tail test: fraction of samples above 2.5 cm + 2 sigma_i vs 2.3% expected
tail=np.bincount(col,weights=(hb>.025+2*s_i).astype(float),minlength=H*W)/np.maximum(n,1)
# decisions (diagnostic thresholds)
enough=(n>=30)&(nfr>=3)
clear=enough&(mean+3*se<.025)&(tail<.07)
obj=enough&((mean-3*se>.010)|(tail>.15))
state=np.full(H*W,'unresolved',dtype=object);state[clear]='clear';state[obj]='object'
state=state.reshape(H,W);mean=mean.reshape(H,W);n=n.reshape(H,W);tail=tail.reshape(H,W)
def cnt(mask):v,c=np.unique(state[mask],return_counts=True);return dict(zip(v.tolist(),c.tolist()))
print('near-resolved walk columns (calibration set):',cnt(walk&~flag))
print('FLAGGED (far-only) walk columns:',cnt(walk&flag))
print('supported columns blocked by D1 low1 (positive low occupancy):',cnt(D['low1']&sup&~D['highObstacle']))
# injected boxes: what does the statistic say at their columns (boxes NOT inserted here -> should be whatever the real floor is)
np.savez('lowband_stat.npz',state=state.astype('U10'),mean=mean,n=n,tail=tail,sigma=sig,edges=edges)
# new walk: block unresolved and object
walk2=walk&(state=='clear');walk2_perm=walk&(state!='object')
print('walk columns: D1 permissive',int(walk.sum()),' | strict (flagged blocked)',int((walk&~flag).sum()),' | statistical clear only',int(walk2.sum()),' | statistical object-blocked only',int(walk2_perm.sum()))
np.save('walk_statclear.npy',walk2);np.save('walk_statperm.npy',walk2_perm)
