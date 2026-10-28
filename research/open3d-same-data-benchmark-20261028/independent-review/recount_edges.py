"""Independent post-hoc edge recount from saved arrays; no imported evaluator code."""
from pathlib import Path
import hashlib,json
import numpy as np
H=Path(__file__).resolve().parent; R=H.parent/'fresh-run'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
p=R/'EXPLORATORY_EDGE_STRATA.json'; report=json.loads(p.read_text()); protocol=json.loads((R/'EVALUATOR_FROZEN.json').read_text())
refs=[]; preds=[]; codes=[]; hashes={}
for name in protocol['frameIDs']:
 paths=[R/'evaluation'/mode/(name+'.npz') for mode in ['faro','tsdf']]
 a,b=[np.load(path,allow_pickle=False) for path in paths]
 z=a['axialMetres'].reshape(249,185); out=np.full(z.shape,-1,dtype=np.int8)
 valid=np.isfinite(z)&(z>0);out[valid]=0
 # Independent implementation: accumulate neighbour validity and maximum delta.
 core=z[1:-1,1:-1]; good=valid[1:-1,1:-1].copy();delta=np.zeros(core.shape)
 for n in [z[:-2,1:-1],z[2:,1:-1],z[1:-1,:-2],z[1:-1,2:]]:
  good &= np.isfinite(n)&(n>0)
  delta=np.maximum(delta,np.where(np.isfinite(n),np.abs(n-core),0))
 inner=np.where(delta<=.02,2,np.where(delta<=.10,3,4));inner=np.where(good,inner,1);inner=np.where(valid[1:-1,1:-1],inner,-1)
 out[1:-1,1:-1]=inner
 refs.append(z.ravel().copy());preds.append(b['axialMetres'].copy());codes.append(out.ravel());a.close();b.close()
 for path in paths:hashes[str(path.relative_to(R))]=sha(path)
ref=np.concatenate(refs);pred=np.concatenate(preds);code=np.concatenate(codes);pair=np.isfinite(ref)&np.isfinite(pred);err=pred-ref
checks=0;maxdiff=0.
def equal(actual,expected):
 global checks,maxdiff
 checks+=1
 if isinstance(expected,float):
  diff=abs(actual-expected);maxdiff=max(maxdiff,diff);assert diff<1e-12,(actual,expected)
 else:assert actual==expected,(actual,expected)
rows=[]
for row in report['rows']:
 mask=code==row['code']; e=err[mask&pair];ab=np.abs(e)
 equal(int(mask.sum()),row['scheduled']);equal(len(e),row['paired'])
 equal(int((ab>.1).sum()),row['absoluteDifferenceAbove10cm']);equal(int((ab>.5).sum()),row['absoluteDifferenceAbove50cm'])
 s={'count':len(e)}
 fields=['meanSigned','signedP05','signedP50','signedP95','MAE','absoluteP50','absoluteP90','absoluteP95','absoluteP99','maximumAbsolute']
 vals=[np.mean(e),*np.quantile(e,[.05,.5,.95]),np.mean(ab),*np.quantile(ab,[.5,.9,.95,.99]),np.max(ab)] if len(e) else [None]*len(fields)
 s.update(zip(fields,vals))
 for k,v in s.items():equal(v,row['statistics'][k])
 rows.append({'code':row['code'],'scheduled':int(mask.sum()),'paired':len(e)})
equal(sum(x['scheduled']for x in rows),1335885);equal(sum(x['paired']for x in rows),1187988)
result={'status':'passed','checks':checks,'maximumFloatingDifference':maxdiff,'reviewedScriptSHA256':sha(R/'diagnose_reference_edges.py'),'reviewedResultSHA256':sha(p),'savedArraySHA256':hashes,'strata':rows,'scope':'Independent class assignment and all saved statistics recounted from existing arrays. No new reconstruction or raycast. Post-hoc descriptive strata only, no selection or retuning.','interpretation':'Large residuals persist in the sampled locally smooth reference-depth stratum. This does not establish their physical cause or identify real hazards.','missingMeasuredReferenceMask':'No measured-versus-completed reference mask or hazard ground truth is available; these strata cannot establish physical false-clear or false-block rates.'}
(H/'EDGE_REVIEW.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items()if k!='savedArraySHA256'},indent=2))
