"""Pre-declare two alternative object thresholds BEFORE the holdout; report each on Koivu (dev room)."""
import numpy as np
st=np.load('lowband_stat.npz');ref=np.load('ref_columns.npz');D=np.load('policyD.npz')
mean=st['mean'];tail=st['tail'];n=st['n'];walk=D['walk'];cov=ref['n']>0;low=ref['low_max']
cand=walk|(D['low1']&D['support']&~D['highObstacle'])
# approximate SE from sigma model is not saved; use mean thresholds only here
variants={'V0 current: mean>1cm(3SE) or tail>15%':(st['state']=='object'),
          'V1: mean>2.5cm only':(mean>.025)&(n>=30),
          'V2: mean>2.5cm or tail>30%':((mean>.025)|(tail>.30))&(n>=30),
          'V3: mean>4cm only':(mean>.04)&(n>=30)}
for k,obj in variants.items():
  o=obj&cand&cov;real=(low[o]>=.025).sum()
  missed=cand&cov&(low>=.025)&~obj
  print(f'{k:40s} object calls {int(o.sum()):5d}, reference-real {int(real):4d} ({100*real/max(o.sum(),1):4.1f}%), reference low objects NOT called {int(missed.sum()):4d} of {int((cand&cov&(low>=.025)).sum())}')
