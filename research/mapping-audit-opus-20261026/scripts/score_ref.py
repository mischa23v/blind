"""Evaluator scoring of planner-side column classes against reference columns. Development-room
result (Koivu); thresholds below were chosen BEFORE seeing these numbers but are not a holdout."""
import numpy as np,json
from scipy import ndimage
ref=np.load('ref_columns.npz');st=np.load('lowband_stat.npz');D=np.load('policyD.npz')
state=st['state'];walk=D['walk'];flag=D['lowUnresolvedFlag'];sup=D['support']
lowmax=ref['low_max'];bodymax=ref['body_max'];cov=ref['n']>0
def score(mask,label):
  m=mask&cov;n=int(m.sum());nc=int((mask&~cov).sum())
  o25=int((lowmax[m]>=.025).sum());o40=int((lowmax[m]>=.04).sum());o80=int((lowmax[m]>=.08).sum());body=int((bodymax[m]>-np.inf).sum())
  print(f'{label:52s} n={n:6d} (no ref cov {nc:4d}) | ref low geom >=2.5cm: {o25:5d} ({100*o25/max(n,1):5.1f}%)  >=4cm: {o40:5d} ({100*o40/max(n,1):5.1f}%)  >=8cm: {o80:5d}  | ref body-band geom: {body:5d} ({100*body/max(n,1):5.1f}%)')
print('--- planner classes vs reference (reference low geometry = any mesh vertex 1.5–30 cm above plane in the column; floor is at -0.15±1 cm) ---')
score(walk&~flag&(state=='clear'),'near-resolved & stat clear')
score(walk&flag&(state=='clear'),'far-only & stat clear (newly resolved)')
score(walk&~flag&(state=='object'),'near-clear vs stat-object CONFLICT')
score(walk&flag&(state=='object'),'far-only & stat object')
score(D['low1']&sup&~D['highObstacle']&(state=='object'),'D1 low-occupied & stat object')
score(D['low1']&sup&~D['highObstacle']&(state=='clear'),'D1 low-occupied & stat clear')
score(walk&(state=='unresolved'),'walk & stat unresolved')
score(D['highObstacle']&sup,'D1 high obstacle (supported columns)')
obs=D['highObstacle']|D['low1'];lab,k=ndimage.label(obs,structure=np.ones((3,3)));sz=np.bincount(lab.ravel());speck=(sz[lab]<=3)&obs
score(speck,'D1 isolated specks (<=3 cols)')
print('--- safety view: planner-walkable columns where reference has low geometry ---')
for lbl,m in (('D1 permissive walk',walk),('D1 strict walk',walk&~flag),('stat clear walk',walk&(state=='clear')),('stat object-blocked walk',walk&(state!='object'))):score(m,lbl)
# reference-defined low objects inside the D1 support region: how big are they?
refobj=cov&sup&(lowmax>=.025)&(bodymax==-np.inf)
lab,k=ndimage.label(refobj,structure=np.ones((3,3)));sz=np.bincount(lab.ravel())[1:]
print('reference low-only objects within supported area:',int(refobj.sum()),'columns in',k,'blobs; sizes 1:',int((sz==1).sum()),'2-3:',int(((sz>1)&(sz<=3)).sum()),'4-10:',int(((sz>3)&(sz<=10)).sum()),'>10:',int((sz>10).sum()),'| height p50/p90 cm',np.round(np.percentile(lowmax[refobj]*100,[50,90]),1))
np.save('ref_lowobj.npy',refobj)
