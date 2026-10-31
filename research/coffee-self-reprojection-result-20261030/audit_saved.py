#!/usr/bin/env python3
"""Saved-array/source-pixel diagnostic only. Does not load the OctoMap library."""
import os
for k in ('OPENBLAS_NUM_THREADS','OMP_NUM_THREADS','MKL_NUM_THREADS'):os.environ[k]='1'
import pathlib,json,hashlib,importlib.util,resource,time
resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,)*2);resource.setrlimit(resource.RLIMIT_CPU,(120,)*2);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
import numpy as np
from PIL import Image
H=pathlib.Path(__file__).resolve().parent;R=H.parents[1];W=R.parent;A=W/'coffee-self-reprojection-attempt-001'
def load(p,name):
 s=importlib.util.spec_from_file_location(name,p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
metric=load(R/'research/coffee-self-reprojection-source-20261030/metrics.py','metric');pose=load(R/'research/coffee-shared-pose-occupancy-source-20261029/pose_contract.py','pose');proj=load(R/'research/coffee-table-retention-default-guard-source-20261029/retention.py','projector')
r=json.loads((A/'RESULT.json').read_text());assert r['status']=='completed-self-versus-fused-diagnostic'
metadata=json.loads((W/'coffee-recovered-source/transformations.json').read_text());frames={pathlib.Path(x['file_path']).stem:x for x in metadata['frames']};frozen=json.loads((R/'research/coffee-shared-pose-occupancy-source-20261029/FRAME_SELECTION.json').read_text());old=json.loads((W/'coffee-shared-pose-attempt-001/RESULT.json').read_text())
def keys(world):
 # Literal upstream max-depth key arithmetic: Float32 point promoted to double,
 # scaled by inverse resolution 20, floor, plus key offset32768.
 k=np.floor(world.astype(np.float32).astype(np.float64)*20).astype(np.int64)+32768
 assert ((k>=0)&(k<65536)).all()
 return (k[:,0].astype(np.uint64)<<32)|(k[:,1].astype(np.uint64)<<16)|k[:,2].astype(np.uint64)
output={'status':'incomplete','nativeLibraryLoaded':False,'thresholdsChanged':False,'sourceResultSHA256':sha(A/'RESULT.json'),'scope':'exploratory deterministic pixel-to-occupied-key attribution; not validation','frames':[]};start=time.monotonic()
for i,n in enumerate(r['buildFrames']):
 f=frames[n];dp=W/'coffee-depth-diagnosis/depth'/(n+'.png');assert sha(dp)==frozen['depthSHA256'][n]
 with Image.open(dp)as im:d=np.asarray(im)
 points,rr,cc=proj.project(d,f);t,origin=pose.frame_contract(f);world=np.column_stack(pose.transform_coordinates(points[:,0],points[:,1],points[:,2],t));assert hashlib.sha256(world.tobytes()).hexdigest()==old['frames'][i]['worldFloat64SHA256']
 camera=np.column_stack(((cc-f['cx'])/f['fl_x'],(rr-f['cy'])/f['fl_y'],np.ones(len(rr))));rot=np.asarray([x[:3]for x in t[:3]]);reprojected=np.asarray(origin)+(camera@rot.T)*points[:,2,None];projection_error=float(np.max(np.abs(reprojected-world)));assert projection_error<1e-12
 k=keys(world);order=np.argsort(k,kind='stable');sortedkeys=k[order];inv=np.asarray(metric.inverse3([row[:3]for row in t[:3]]));row={'frame':n,'depthSHA256':sha(dp),'maxFullRasterRayProjectionWorldDifferenceMetres':projection_error,'cases':[]}
 for kind in ('single','fused'):
  record=next(x for x in r['cases']if x['frame']==n and x['kind']==kind);p=A/record['derivedEvidence']['path'];assert sha(p)==record['derivedEvidence']['sha256']
  with np.load(p,allow_pickle=False)as data:idx=data['pixelIndex'].copy();centers=data['observedCenter'].copy();center_res=data['centerAxial'].copy();entry=data['entryAxial'].copy()
  pr=idx//738;pc=idx%738;assert len(np.unique(idx))==len(idx)and ((pr%8)==0).all()and((pc%8)==0).all();z=d[pr,pc].astype(np.float64)/1000;assert((z>0)&(z<4)).all()
  recomputed=(centers-np.asarray(origin))@inv[2]-z;association_error=float(np.max(np.abs(recomputed-center_res)))if len(z)else 0;assert association_error<1e-12
  for field,values in [('centerAxialResidualMetres',center_res),('entryAxialResidualMetres',entry)]:assert metric.distributions(values)==record[field]
  case={'kind':kind,'hitCount':len(idx),'maxCenterResidualAssociationDifferenceMetres':association_error}
  if kind=='single':
   hitkeys=keys(centers);left=np.searchsorted(sortedkeys,hitkeys,'left');right=np.searchsorted(sortedkeys,hitkeys,'right');assert (right>left).all()
   pixel_distance=[];source_minus_target=[];axial_interval_distance=[];selected_count=0
   for j,(lo,hi)in enumerate(zip(left,right)):
    support=order[lo:hi];dist2=(rr[support]-pr[j])**2+(cc[support]-pc[j])**2;mind=dist2.min();ties=support[dist2==mind]
    # Report all nearest-pixel tie depths as a median, deterministic no cherry pick.
    delta=np.median(points[ties,2])-z[j];pixel_distance.append(float(np.sqrt(mind)));source_minus_target.append(float(delta));low=points[support,2].min();high=points[support,2].max();axial_interval_distance.append(float(max(low-z[j],0,z[j]-high)));selected_count+=int(mind==0)
   case.update(allHitsHaveOriginalEndpointInSameNativeKey=True,ownPixelInHitKey=selected_count,nearestSupportingPixelDistance=metric.distributions(pixel_distance),nearestSupportingSourceMinusTargetAxialMetres=metric.distributions(source_minus_target),targetDistanceOutsideSupportingDepthIntervalMetres=metric.distributions(axial_interval_distance),method='all original full-raster endpoints in exact returned hit key; nearest image pixel with median across all distance ties; no cutoff')
  row['cases'].append(case)
 output['frames'].append(row)
output['status']='completed-saved-array-and-original-pixel-audit';output['wallSeconds']=time.monotonic()-start
with(H/'PIXEL_ASSOCIATION_AUDIT.json').open('x')as f:json.dump(output,f,indent=2,allow_nan=False);f.write('\n')
print(json.dumps(output,indent=2))
