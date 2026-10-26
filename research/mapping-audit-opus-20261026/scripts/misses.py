import numpy as np
from scipy import ndimage
ref=np.load('ref_columns.npz');st=np.load('lowband_stat.npz');D=np.load('policyD.npz')
walk=D['walk'];lowmax=ref['low_max'];cov=ref['n']>0;state=st['state'];mean=st['mean'];n=st['n']
miss=walk&cov&(lowmax>=.025)
blocked=~walk
d=ndimage.distance_transform_edt(walk)*.05   # distance to nearest non-walkable column (centre)
print('planner-walkable columns with reference low geometry >=2.5cm:',int(miss.sum()))
print(' reference height cm p10/50/90:',np.round(np.percentile(lowmax[miss]*100,[10,50,90]),1))
print(' distance to nearest D1-blocked column (m) p10/50/90:',np.round(np.percentile(d[miss],[10,50,90]),2),' within 0.375 m:',int((d[miss]<=.375).sum()),' beyond 0.375:',int((d[miss]>.375).sum()))
print(' phone statistic state at those columns:',dict(zip(*[x.tolist() for x in np.unique(state[miss],return_counts=True)])))
print(' phone mean height cm p10/50/90:',np.round(np.nanpercentile(mean[miss]*100,[10,50,90]),2),' samples p50',np.median(n[miss]))
far=miss&(d>.375)
print(' the beyond-margin misses: heights cm',np.round(np.sort(lowmax[far]*100),1).tolist())
print(' their phone mean cm',np.round(mean[far]*100,2).tolist(),' flagged far-only:',int((far&D['lowUnresolvedFlag']).sum()),'/',int(far.sum()))
lab,k=ndimage.label(miss,structure=np.ones((3,3)));print(' miss blobs:',k)
np.save('ref_miss.npy',miss)
