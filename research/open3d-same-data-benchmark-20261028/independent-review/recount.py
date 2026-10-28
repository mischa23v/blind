"""Independent bounded array/hash recount; no reconstruction or full mesh raycast."""
from pathlib import Path
import hashlib, json, math, time
import numpy as np
from PIL import Image

H=Path(__file__).resolve().parent; R=H.parent/'fresh-run'
checks=0; floats=0; max_delta=0.; started=time.monotonic()
def check(condition):
 global checks
 assert condition
 checks+=1
def digest(path):
 h=hashlib.sha256()
 with Path(path).open('rb') as f:
  for b in iter(lambda:f.read(1048576),b''):h.update(b)
 return h.hexdigest()
def compare(a,b):
 global floats,max_delta
 if isinstance(a,dict):
  check(set(a)==set(b))
  for k in a:compare(a[k],b[k])
 elif isinstance(a,list):
  check(len(a)==len(b))
  for x,y in zip(a,b):compare(x,y)
 elif isinstance(a,float):
  check(isinstance(b,(int,float)) and math.isfinite(b)); delta=abs(a-b)
  check(delta<=1e-12);floats+=1;max_delta=max(max_delta,delta)
 else:check(a==b)
def stats(x):
 x=np.asarray(x,dtype=np.float64)
 keys=['meanSigned','signedP05','signedP50','signedP95','MAE','absoluteP50','absoluteP90','absoluteP95','absoluteP99','maximumAbsolute']
 if len(x)==0:return dict(count=0,**dict.fromkeys(keys))
 check(np.isfinite(x).all());a=np.abs(x)
 values=[float(np.mean(x)),*np.quantile(x,[.05,.5,.95]).tolist(),float(np.mean(a)),*np.quantile(a,[.5,.9,.95,.99]).tolist(),float(max(a))]
 return dict(count=len(x),**dict(zip(keys,values)))
labels=['positive_below015','015_to_below1','1_to_below2','2_to_below3','3_to_below4','4_to_below5','5_and_above']
def bins(z):return [(z>0)&(z<.15),(z>=.15)&(z<1),(z>=1)&(z<2),(z>=2)&(z<3),(z>=3)&(z<4),(z>=4)&(z<5),z>=5]
def geometry(ref,pred):
 rv=np.isfinite(ref)&(ref>0);pv=np.isfinite(pred)&(pred>0);pair=rv&pv
 def subset(mask):
  e=pred[pair&mask]-ref[pair&mask]
  return {'scheduled':int(mask.sum()),'statistics':stats(e),'earlyWithinLate':{str(t):{'earlier':int(np.count_nonzero(e< -t)),'within':int(np.count_nonzero(abs(e)<=t)),'later':int(np.count_nonzero(e>t))}for t in [.02,.05,.1]}}
 return {'availability':{'scheduled':len(ref),'paired':int(pair.sum()),'referenceOnly':int((rv&~pv).sum()),'TSDFOnly':int((~rv&pv).sum()),'neither':int((~rv&~pv).sum())},'all':subset(np.ones(len(ref),bool)),'referenceBelow4m':subset(rv&(ref<4)),'referenceAtLeast4m':subset(rv&(ref>=4)),'byReferenceDepth':[dict(label=label,**subset(mask))for label,mask in zip(labels,bins(ref))]}
def sensor(raw,pred):
 z=raw.astype(np.float64)/1000;sv=z>0;pv=np.isfinite(pred)&(pred>0);pair=sv&pv;domain=sv&(z<4);e=pred-z
 states=[~sv,domain,z>=4]
 def subset(mask):return {'scheduled':int(mask.sum()),'meshHit':int((mask&pv).sum()),'primaryStatistics':stats(e[mask&domain&pv]),'allPositiveStatistics':stats(e[mask&pair])}
 return {'availability':{'scheduled':len(raw),'sensorStateByMeshNoHitHit':[[int((m&~pv).sum()),int((m&pv).sum())]for m in states],'sensorStateNames':['zero_missing','positive_below4','positive_4_and_above'],'meshColumns':['no_hit','hit'],'bothPositive':int(pair.sum()),'sensorOnly':int((sv&~pv).sum()),'meshOnly':int((~sv&pv).sum()),'neither':int((~sv&~pv).sum())},'primaryStatistics':stats(e[domain&pv]),'allPositiveStatistics':stats(e[pair]),'outOfDomainStatistics':stats(e[(z>=4)&pv]),'bySensorDepth':[dict(label=label,**subset(mask))for label,mask in zip(labels,bins(z))]}

protocol=json.loads((R/'EVALUATOR_FROZEN.json').read_text());fusion=json.loads((R/'FUSION_FROZEN.json').read_text());contract=json.loads((H.parent/'DATA_CONTRACT.json').read_text());result=json.loads((R/'COMMON_GEOMETRY_RESULTS.json').read_text())
base=R/'inputs/room_datasets/koivu/iphone/long_capture'
doc=json.loads((base/'transformations.json').read_text());frames={Path(x['file_path']).stem:x for x in doc['frames']}
ids=protocol['frameIDs'];train=[x['frameID']for x in fusion['trainingFrames']]
check(len(ids)==len(set(ids))==29);check(len(train)==len(set(train))==265);check(not set(ids)&set(train));check(set(ids)|set(train)==set(frames));check(len(frames)==len(doc['frames'])==294)
check(ids==fusion['excludedTestIDs']==contract['excludedTestIDs']==(base/'test.txt').read_text().splitlines());check(train==contract['trainingIDs'])
for path,h in protocol['pins'].items():check(digest(path)==h)
restored={x['member']:x for x in json.loads((R/'RESTORE_RECEIPT.json').read_text())['selected']}
records={mode:json.loads((R/'evaluation'/mode/'RESULT.json').read_text())for mode in ['tsdf','faro']}
rr,cc=np.meshgrid(np.arange(0,994,4),np.arange(0,738,4),indexing='ij');rr=rr.ravel();cc=cc.ravel();check(len(rr)==46065)
refs=[];preds=[];raws=[];a=np.array(json.loads((R/'inputs/room_datasets/koivu/icp_iphone.json').read_text())['gt_transformation']);scale=float(np.linalg.svd(a[:3,:3],compute_uv=False).mean())
for i,name in enumerate(ids):
 arrays={}
 for mode in ['tsdf','faro']:
  row=records[mode]['records'][i];check(row['frameID']==name)
  path=R/'evaluation'/mode/(name+'.npz');check(digest(path)==row['fileSHA256'])
  with np.load(path,allow_pickle=False)as x:
   check(set(x.files)=={'row','column','axialMetres','cellID'});check(np.array_equal(x['row'],rr));check(np.array_equal(x['column'],cc));d=x['axialMetres'].copy();cells=x['cellID'].copy()
  check(d.shape==cells.shape==(46065,));check(np.array_equal(np.isfinite(d),cells>=0));check(np.all(d[np.isfinite(d)]>0));check(row['positiveHits']==int(np.isfinite(d).sum()));arrays[mode]=d
 rawpath=base/'depth'/(name+'.png');entry=restored[str(rawpath.relative_to(R/'inputs'))];check(rawpath.stat().st_size==entry['bytes']);check(digest(rawpath)==entry['sha256'])
 with Image.open(rawpath)as im:raw=np.asarray(im).copy()
 check(raw.dtype==np.uint16 and raw.shape==(994,738));raws.append(raw[::4,::4].ravel());refs.append(arrays['faro']);preds.append(arrays['tsdf'])
 compare(dict(frameID=name,**geometry(refs[-1],preds[-1])),result['frames'][i])
 f=frames[name];pose=np.array(f['transform_matrix']);flip=np.diag([1,-1,-1,1]);check(np.max(abs(pose[3]-[0,0,0,1]))<1e-10)
 check(np.max(abs(pose[:3,:3].T@pose[:3,:3]-np.eye(3)))<1e-5)
 for r,c in [(0,0),(496,368),(992,736)]:
  cv=np.array([(c-f['cx'])/f['fl_x'],(r-f['cy'])/f['fl_y'],1.,1.]);gl=np.array([cv[0],-cv[1],-1.,1.]);check(np.max(abs(pose@flip@cv-pose@gl))<1e-12)
  # Synthetic point on the same ray proves inverse registration returns camera axial distance, not FARO range.
  point=a@pose@np.r_[gl[:3]*2.,1.];back=np.linalg.inv(a@pose)@point;check(abs(-back[2]-2)<1e-12)
check(result['views']==29 and result['scheduledRays']==1335885)
ref=np.concatenate(refs);pred=np.concatenate(preds);raw=np.concatenate(raws)
compare(geometry(ref,pred),result['pooled']);compare(sensor(raw,pred),result['heldoutProcessedSensorConsistency'])
out={'status':'passed','scope':'Independent saved-array/hash/count/statistic and coordinate-algebra review; no duplicate fusion or full mesh raycasting','checksPassed':checks,'floatingComparisons':floats,'maximumStatisticDifference':max_delta,'trainingFrames':265,'excludedFrames':29,'scheduledRays':len(ref),'arrayFilesRehashed':58,'heldoutDepthFilesRehashed':29,'registrationScale':scale,'pooledAvailability':result['pooled']['availability'],'pooledAllPairedStatistics':result['pooled']['all']['statistics'],'elapsedSeconds':time.monotonic()-started,'reviewedFileSHA256':{n:digest(R/n)for n in ['evaluate_common.py','run_evaluation.py','summarize_common.py','EVALUATOR_FROZEN.json','COMMON_GEOMETRY_RESULTS.json']},'limitations':['No independent full reference raycast repeated','Same-capture supplied poses are not live localization','Integer-pixel rays are deliberate and consistent with Open3D fusion; earlier half-pixel reference scores are a different protocol','Author reference registration includes scale and was not refitted here','Child evaluator did not receive expected freeze-file hash; freeze is locally mutable','Secondary sensor-depth hashes verified in this review, not listed individually in evaluator launch pins','FARO edited/completed-face mask unavailable; errors are not physical hazard labels','No navigation, clearance or safe-use percentage established']}
(H/'REVIEW.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out,indent=2))
