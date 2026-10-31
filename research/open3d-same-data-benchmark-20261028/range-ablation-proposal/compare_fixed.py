from pathlib import Path
import json
import numpy as np
from scipy.ndimage import label
P=Path(__file__).resolve().parent;F=P.parent/'fresh-run';V=P/'run';D=P.parent/'error-tail-diagnostic'
selection=json.loads((D/'TRACE_POINT_SELECTION.json').read_text());records=[]
for p in selection['points']:
 name=p['sourceFrame'];u,v=p['pixel']
 with np.load(V/'evaluation/tsdf'/f'{name}.npz')as a:i=np.flatnonzero((a['row']==v)&(a['column']==u));assert len(i)==1;z=float(a['axialMetres'][i[0]])
 records.append({'id':p['id'],'pixel':[u,v],'baseline4mAxial':p['tsdfAxialMetres'],'variant5mAxial':z if np.isfinite(z) else None,'faroAxial':p['faroAxialMetres'],'missingIsNotFree':True})
regions=[]
for name in ['frame_00228','frame_00197']:
 with np.load(F/'evaluation/tsdf'/f'{name}.npz')as a:r=a['row'];c=a['column'];base=a['axialMetres']
 with np.load(F/'evaluation/faro'/f'{name}.npz')as a:ref=a['axialMetres']
 with np.load(V/'evaluation/tsdf'/f'{name}.npz')as a:pred=a['axialMetres'];assert np.array_equal(r,a['row'])and np.array_equal(c,a['column'])
 if name=='frame_00228':
  labs,n=label((np.isfinite(base)&np.isfinite(ref)&(abs(base-ref)>.5)).reshape(249,185));counts=np.bincount(labs.ravel());counts[0]=0;m=labs.ravel()==counts.argmax();assert m.sum()==4166
 else:m=(c>=160)&(c<=600)&(r>=780)&(r<=970)&np.isfinite(base)&np.isfinite(ref);assert m.sum()==5328
 rec={'frame':name,'fixedBaselineSelectedSamples':int(m.sum())}
 for label_,p in [('baseline4m',base),('variant5m',pred)]:
  q=m&np.isfinite(p)&np.isfinite(ref);e=p[q]-ref[q];rec[label_]={'paired':int(q.sum()),'missingPrediction':int((m&~np.isfinite(p)).sum()),'medianAbsolute':float(np.median(abs(e))) if len(e) else None,'p95Absolute':float(np.quantile(abs(e),.95)) if len(e) else None,'signedMin':float(e.min()) if len(e)else None,'signedMedian':float(np.median(e))if len(e)else None,'signedMax':float(e.max())if len(e)else None}
 regions.append(rec)
out={'postHocDevelopmentOnly':True,'points':records,'fixedRegions':regions,'all29Baseline':json.loads((F/'COMMON_GEOMETRY_RESULTS.json').read_text()),'all29Variant':json.loads((V/'COMMON_GEOMETRY_RESULTS.json').read_text()),'noAutomaticWinnerSelection':True,'physicalAuthority':False}
(V/'COMPARISON.json').write_text(json.dumps(out,indent=2)+'\n')
