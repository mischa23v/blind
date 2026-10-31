"""Independent bounded array/denominator recount; no geometry queries or engines."""
from pathlib import Path
import os
os.environ['OPENBLAS_NUM_THREADS']='1'
import json,hashlib,numpy as np
ROOT=Path(__file__).resolve().parents[3]
B=ROOT/'research/rtabmap-same-data-benchmark-20261028';OUT=B/'fresh-run/common-surface-reader-fixed';F=ROOT/'research/open3d-same-data-benchmark-20261028/fresh-run'
checks=0

def ck(x):
 global checks
 assert x
 checks+=1

def sha(p):
 h=hashlib.sha256()
 with open(p,'rb')as f:
  for x in iter(lambda:f.read(1048576),b''):h.update(x)
 return h.hexdigest()

def select(p):
 # Independent grouping/minimum-at implementation, not evaluator lexsort over all keys.
 keys=np.floor(p/.04).astype(np.int64)
 unique,inv=np.unique(keys,axis=0,return_inverse=True)
 squared=np.sum((p-(keys+.5)*.04)**2,axis=1)
 minima=np.full(len(unique),np.inf);np.minimum.at(minima,inv,squared)
 candidate=np.where(squared==minima[inv])[0]
 q=p[candidate];groups=inv[candidate]
 order=np.lexsort((q[:,2],q[:,1],q[:,0],groups));groups=groups[order]
 chosen=candidate[order[np.r_[True,groups[1:]!=groups[:-1]]]]
 ck(len(chosen)==len(unique))
 return p[chosen]

def summary(d,stored):
 ck(np.isfinite(d).all());ck(len(d)==stored['scheduled']==stored['valid']);ck(stored['invalid']==0)
 expected={'meanMetres':np.mean(d),'medianMetres':np.median(d),'p95Metres':np.percentile(d,95),'p99Metres':np.percentile(d,99),'maxMetres':np.max(d)}
 for k,v in expected.items():ck(abs(float(v)-stored[k])<1e-12)
 for threshold,record in stored['within'].items():
  n=int(np.count_nonzero(d<=float(threshold)));ck(n==record['count']);ck(abs(n/len(d)-record['fractionOfScheduled'])<1e-15)

result=json.loads((OUT/'RESULT.json').read_text());A=np.array(json.loads((F/'inputs/room_datasets/koivu/icp_iphone.json').read_text())['gt_transformation'])
refs=np.load(OUT/'reference_samples_faro_metres.npy');ck(sha(OUT/'reference_samples_faro_metres.npy')==result['referenceSamplesSHA256'])
frameinfo={Path(f['file_path']).stem:f for f in json.loads((F/'inputs/room_datasets/koivu/iphone/long_capture/transformations.json').read_text())['frames']}
parts=[];scheduled=missing=0
for name in json.loads((F/'EVALUATOR_FROZEN.json').read_text())['frameIDs']:
 f=frameinfo[name]
 with np.load(F/'evaluation/faro'/(name+'.npz'))as z:
  good=np.isfinite(z['axialMetres']);scheduled+=len(good);missing+=int(np.count_nonzero(~good));d=z['axialMetres'][good]
  optical=np.column_stack(((z['column'][good]-f['cx'])/f['fl_x']*d,(z['row'][good]-f['cy'])/f['fl_y']*d,d))
  C=np.array(f['transform_matrix'])@np.diag([1.,-1.,-1.,1.]);phone=optical@C[:3,:3].T+C[:3,3]
  parts.append(phone@A[:3,:3].T+A[:3,3])
expected=select(np.concatenate(parts));del parts
ck(expected.shape==refs.shape);max_ref_error=float(np.max(abs(expected-refs)));ck(max_ref_error<1e-12)
ck(scheduled==result['referenceSampling']['scheduledOriginalRays']);ck(missing==result['referenceSampling']['missingReferenceRaysExcludedButNotFree']);ck(scheduled-missing==result['referenceSampling']['finiteOriginalReferenceHits']);ck(len(refs)==result['reference4cmPointCount'])
records={}
for label,record in result['results'].items():
 path=OUT/(label+'.npz');ck(sha(path)==record['arraySHA256'])
 with np.load(path)as z:
  p=z['pointsFaroMetres'];d=z['forwardDistanceMetres'];reverse=z['reverseReferencePointDistanceMetres'];ids=z['referenceCellID']
  ck(len(p)==len(d)==len(ids)==record['common4cmPointCount']);ck(len(reverse)==len(refs));ck(np.all((ids>=0)&(ids<17801112)));ck(np.all(d>=0));ck(np.all(reverse>=0))
  summary(d,record['forwardUnsignedPointToReferenceTriangle']);summary(reverse,record['reverseVisibleReferenceToSampledOutputPoint'])
  raw=np.load(OUT/(label+'_decoded_points.npy'));ck(len(raw)==record['rawOutputPointCount']);transformed=raw@A[:3,:3].T+A[:3,3];sample=select(transformed)
  ck(np.array_equal(sample,p));records[label]={'nativeDecoded':len(raw),'fourCmSamples':len(p),'allForwardAndReverseDenominatorsRecounted':True,'actualPointSelectionMatchesIndependentGrouping':True}
report={'status':'passed','checks':checks,'recordedGeometryQueries':0,'independentEngineRerun':False,'referenceProjectionAlternativeOpticalConventionMaxErrorMetres':max_ref_error,'referenceSampleCount':len(refs),'scheduledReferenceRays':scheduled,'missingReferenceRays':missing,'arms':records,'resultSHA256':sha(OUT/'RESULT.json'),'scriptSHA256':sha(Path(__file__)),'scope':'all saved summary numbers, input sampling and reference point projection; not independent closest-point recomputation or physical accuracy'}
(Path(__file__).parent/'COMMON_RESULT_REVIEW.json').write_text(json.dumps(report,indent=2,sort_keys=True)+'\n');print(json.dumps(report,indent=2))
