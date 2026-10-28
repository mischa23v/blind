from pathlib import Path
import json,hashlib,numpy as np
s=Path(__file__).resolve().parent;o=s/'zup-native-grid';checks={}
dtype=np.dtype([('x','<f4'),('y','<f4'),('z','<f4'),('size','<f4'),('p','<f4'),('type','<i4'),('ref','<i4'),('occ','<i4')]);a=np.memmap(o/'leaves_dataset_world.bin',dtype=dtype,mode='r')
r={k:v for k,v in (l.split('=',1)for l in(o/'RESULT.txt').read_text().splitlines())}
checks['leafRecordCount']=len(a)==int(r['leafRecords']);checks['finiteCoordinatesAndProbabilities']=all(np.isfinite(a[k]).all()for k in ['x','y','z','size','p']);checks['nativeProbabilityDeterminesOccupied']=np.array_equal(a['p']>=.5,a['occ']==1);checks['observedProbabilityBounds']=bool(((a['p']>0)&(a['p']<1)).all());checks['positiveLeafSizes']=bool((a['size']>0).all())
for name,predicate in [('occupied_leaf_indices',a['occ']==1),('free_leaf_indices',a['occ']==0),('native_ground_occupied_leaf_indices',(a['occ']==1)&(a['type']==1)),('other_occupied_leaf_indices',(a['occ']==1)&(a['type']!=1))]:
 ix=np.fromfile(o/(name+'.u64'),dtype='<u8');checks[name]=np.array_equal(ix,np.flatnonzero(predicate))
checks['all265OccupancyFrames']=len((o/'FRAMES.tsv').read_text().splitlines())==266
m=dict(l.split('\t',1)for l in(s/'zup-mapper/PARAMETERS.tsv').read_text().splitlines());p=dict(l.split('\t',1)for l in(o/'PARAMETERS.tsv').read_text().splitlines());changes={k:[m.get(k),v]for k,v in p.items()if m.get(k)!=v};checks['onlyRayTracingParameterChanged']=changes=={'Grid/RayTracing':['false','true']}
x=json.loads((s/'zup-common-surface/RESULT.json').read_text());old=json.loads((s.parent/'common-surface-reader-fixed/RESULT.json').read_text());checks['sameFrozenReferenceSamples']=x['referenceSamplesSHA256']==old['referenceSamplesSHA256'];checks['referenceCount127774']=x['reference4cmPointCount']==127774
npz=np.load(s/'zup-common-surface/octomap_zup_regenerated.npz');rr=x['results']['octomap_zup_regenerated']
for key,metric in [('forwardDistanceMetres','forwardUnsignedPointToReferenceTriangle'),('reverseReferencePointDistanceMetres','reverseVisibleReferenceToSampledOutputPoint')]:
 v=npz[key];q=rr[metric];checks[key+'_summary']=bool(len(v)==q['valid']==q['scheduled'] and np.isfinite(v).all() and abs(float(v.mean())-q['meanMetres'])<1e-12 and abs(float(np.median(v))-q['medianMetres'])<1e-12 and abs(float(np.percentile(v,95))-q['p95Metres'])<1e-12)
result={'passed':all(checks.values()),'checks':{k:bool(v)for k,v in checks.items()},'parameterChanges':changes,'freeLeavesWithHistoricalObstacleType':int(((a['occ']==0)&(a['type']==100)).sum()),'freeLeavesWithHistoricalGroundType':int(((a['occ']==0)&(a['type']==1)).sum()),'doesNotEstablishPhysicalSafety':True};(s/'ZUP_OUTPUT_CHECKS.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result));assert result['passed']
