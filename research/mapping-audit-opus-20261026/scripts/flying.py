"""Provenance of phone-map obstacle columns the reference does not confirm: are their hits from
depth-discontinuity ('flying pixel') samples? Diagnostic only; nothing removed."""
import sys,os,json,numpy as np
sys.argv=['x'];import pipeline as PL
PL.T0=0
d=sys.argv and os.environ['KOIVU_LONG_CAPTURE']
T=PL.load_frames(d);P,F,DISC=PL.lidar_samples(d,T)
o=np.load(os.environ['KOIVU_PIPELINE_OUT'])
R=o['R'];t=o['t'];lo=o['lo'];RES=.05
Pl=P@R.T+t+[0,0,RES/2];h=Pl[:,2]-RES/2
sup=o['support'];hi=o['highObstacle'];cov=o['ref_n']>0;refgeom=(o['ref_low_max']>-np.inf)|(o['ref_body_max']>-np.inf)
H,W=sup.shape
i=np.floor(Pl[:,0]/RES).astype(int)-lo[0];j=np.floor(Pl[:,1]/RES).astype(int)-lo[1];ok=(i>=0)&(i<H)&(j>=0)&(j<W)&(h>.075)&(h<1.775)
col=(i*W+j)[ok];dc=DISC[ok]
tot=np.bincount(col,minlength=H*W);disc=np.bincount(col,weights=dc.astype(float),minlength=H*W)
frac=np.where(tot>0,disc/np.maximum(tot,1),np.nan).reshape(H,W);tot=tot.reshape(H,W)
falseHi=hi&sup&cov&~refgeom;trueHi=hi&sup&cov&refgeom
print('body-band hits per column: false p50',np.median(tot[falseHi]),' true p50',np.median(tot[trueHi]))
print('fraction of body-band hits that are discontinuity samples: false p25/50/75',np.round(np.nanpercentile(frac[falseHi],[25,50,75]),2),' true p25/50/75',np.round(np.nanpercentile(frac[trueHi],[25,50,75]),2))
print('false columns with >50% discontinuity hits:',int((frac[falseHi]>.5).sum()),'/',int(falseHi.sum()),'  true:',int((frac[trueHi]>.5).sum()),'/',int(trueHi.sum()))
# what if discontinuity samples were EXCLUDED from body-band obstacle evidence (diagnostic, counts only)
nondisc=(tot-disc.reshape(H,W))
print('false columns with ZERO non-discontinuity body hits:',int(((nondisc[falseHi])==0).sum()),'  true columns that would lose all body hits:',int(((nondisc[trueHi])==0).sum()))
