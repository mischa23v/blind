"""Independent saved-array arithmetic recount only. No image/native/fit imports."""
from pathlib import Path
import hashlib,json,resource,signal,time,sys
START=time.monotonic();resource.setrlimit(resource.RLIMIT_CPU,(2,2));resource.setrlimit(resource.RLIMIT_FSIZE,(1024**2,1024**2))
signal.signal(signal.SIGALRM,lambda *_:(_ for _ in()).throw(TimeoutError('two-second wall cap')));signal.alarm(2)
import numpy as np
HERE=Path(__file__).resolve().parent;FIT=HERE.parent;DIAG=FIT.parent
paths={'result':FIT/'run-01/result/RESULT.json','residuals':FIT/'run-01/result/WESTERN_ENDPOINT_PLANE_RESIDUALS.npz','rawEndpoints':DIAG/'west-depth-run-01/result/SELECTED_ENDPOINTS.npz','rawResult':DIAG/'west-depth-run-01/result/RESULT.json','fitFreeze':FIT/'FROZEN.json','fitRunReceipt':FIT/'run-01/RUN_RECEIPT.json','source':Path(__file__)}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
pins={k:sha(p)for k,p in paths.items()}
r=json.loads(paths['result'].read_text());old=json.loads(paths['rawResult'].read_text());run=json.loads(paths['fitRunReceipt'].read_text())
assert run['success']and run['frozenManifestSHA256']==pins['fitFreeze']
with np.load(paths['residuals'],allow_pickle=False)as z:data={k:z[k]for k in z.files}
with np.load(paths['rawEndpoints'],allow_pickle=False)as z:raw={k:z[k]for k in z.files}
assert set(data)=={'frame','i','j','row','col','depthMM','range','globalHeight','fitSignedResidual','fittedPlaneHeight','fitValid'}
for k in ('frame','i','j','row','col','depthMM','range'):assert np.array_equal(data[k],raw[k]),k
assert np.array_equal(data['globalHeight'],raw['level'][:,2])
assert len(r['frames'])==294 and [x['poseIndex']for x in r['frames']]==list(range(294))
assert r['validFrames']==sum(bool(x['valid'])for x in r['frames'])==236
assert r['invalidFrames']==sum(not x['valid']for x in r['frames'])==58
n=len(data['frame']);assert n==old['selectedEndpointCount']
assert sum(x['sourceSamples']for x in r['frames'])==old['all294SourceSamples']

def stats(x):
 return {'n':len(x),'p05_p50_p95Metres':np.percentile(x,[5,50,95]).tolist()if len(x)else None,'minMetres':float(x.min())if len(x)else None,'maxMetres':float(x.max())if len(x)else None}

def same(a,b):
 if isinstance(a,dict):assert set(a)==set(b);[same(a[k],b[k])for k in a]
 elif isinstance(a,list):assert len(a)==len(b);[same(x,y)for x,y in zip(a,b)]
 elif a is None:assert b is None
 elif isinstance(a,(int,np.integer)):assert a==b
 else:assert np.isclose(a,b,rtol=0,atol=1e-12),(a,b)

max_residual_error=0.;max_height_error=0.;finite_planes=0
for row in r['frames']:
 m=data['frame']==row['poseIndex'];p=raw['level'][m]
 assert int(m.sum())==row['westernCellEndpoints']
 assert np.all(data['fitValid'][m]==row['valid'])
 if 'planeABCD'in row:
  plane=np.asarray(row['planeABCD']);expected=p@plane[:3]+plane[3]
  height=-(p[:,0]*plane[0]+p[:,1]*plane[1]+plane[3])/plane[2]if abs(plane[2])>=1e-12 else np.full(len(p),np.nan)
  finite_planes+=1
 else:expected=height=np.full(len(p),np.nan)
 assert np.allclose(data['fitSignedResidual'][m],expected,rtol=0,atol=1e-12,equal_nan=True)
 assert np.allclose(data['fittedPlaneHeight'][m],height,rtol=0,atol=1e-12,equal_nan=True)
 if len(p)and np.isfinite(expected).all():max_residual_error=max(max_residual_error,float(abs(data['fitSignedResidual'][m]-expected).max()))
 if len(p)and np.isfinite(height).all():max_height_error=max(max_height_error,float(abs(data['fittedPlaneHeight'][m]-height).max()))
 same(stats(data['globalHeight'][m]),row['westernEndpointGlobalHeight'])
 same(stats(data['fitSignedResidual'][m][np.isfinite(data['fitSignedResidual'][m])]),row['westernEndpointFitResidual'])
oldcells={tuple(c['sourceIJ']):c for c in old['cells']};seen=set()
for row in r['westernCells']:
 ij=tuple(row['sourceIJ']);assert ij not in seen;seen.add(ij);assert row['phoneFlags']==oldcells[ij]['flags']
 m=(data['i']==ij[0])&(data['j']==ij[1]);valid=m&data['fitValid'];near=valid&(data['range']<=2)&(abs(data['globalHeight'])<=.1)
 assert row['allEndpointCount']==int(m.sum())and row['validPlaneEndpointCount']==int(valid.sum())
 assert int(m.sum())==oldcells[ij]['allViews']['heightMetres']['n']
 for key,field in [('globalHeight','globalHeight'),('fittedPlaneHeight','fittedPlaneHeight'),('signedResidual','fitSignedResidual')]:same(stats(data[field][near]),row['conditionalNearAbsGlobalHeightBelow10cm'][key])
 same(stats(data['fitSignedResidual'][valid]),row['validViewSignedResidualAllHeights'])
assert seen==set(oldcells)and len(seen)==57
assert sum(c['allEndpointCount']for c in r['westernCells'])==n
assert sum(c['validPlaneEndpointCount']for c in r['westernCells'])==int(data['fitValid'].sum())
assert all(sha(paths[k])==h for k,h in pins.items())
peak=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss*1024
assert peak<=256*1024**2 and time.monotonic()-START<=2
result={'confirmed':True,'scope':'Saved-array association and arithmetic recount only; no depth reread, native fit, reference or navigation','frameCount':294,'validFrames':236,'invalidFrames':58,'westernCells':57,'rawEndpointCount':n,'exactAssociationFields':['frame','i','j','row','col','depthMM','range','globalHeight == raw.level[:,2]'],'perFrameWesternSummariesReconciled':True,'perCellSummariesAndOriginalFlagsReconciled':True,'savedPlaneResidualEquationReconciled':True,'maximumResidualArithmeticDifferenceMetres':max_residual_error,'maximumFittedHeightArithmeticDifferenceMetres':max_height_error,'numericComparisonAbsoluteTolerance':1e-12,'sourceInputHashesVerifiedBeforeAfter':True,'pins':{k:{'path':str(paths[k]),'sha256':h}for k,h in pins.items()},'wallSeconds':time.monotonic()-START,'peakRSSBytes':peak,'physicalAuthority':False}
signal.alarm(0)
with(HERE/'RECOUNT.json').open('x')as f:json.dump(result,f,indent=2,allow_nan=False);f.write('\n')
print(json.dumps(result),flush=True)
