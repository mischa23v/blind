#!/usr/bin/env python3
"""Prepared fixed construction-view self-versus-fused diagnostic; no holdout reads."""
import os
for k in ('OPENBLAS_NUM_THREADS','OMP_NUM_THREADS','MKL_NUM_THREADS'):os.environ[k]='1'
import argparse,hashlib,importlib.util,io,json,math,pathlib,resource,signal,time
H=pathlib.Path(__file__).resolve().parent;R=H.parents[1];W=R.parent
BUILD=('frame_00290','frame_00357','frame_00391')
def require(ok,why):
 if not ok:raise ValueError(why)
def sha(p):
 with p.open('rb')as f:return hashlib.file_digest(f,'sha256').hexdigest()
def check(p,digest,cap):require(p.is_file()and not p.is_symlink()and p.stat().st_size<=cap and sha(p)==digest,'input drift '+str(p))
def load(p,name):
 s=importlib.util.spec_from_file_location(name,p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
def support_summary(masks,self_index):
 require(all(isinstance(x,int)and 0<=x<8 for x in masks),'invalid support mask')
 counts={str(k):masks.count(k)for k in range(8)}
 return {'total':len(masks),'occupiedBySingleViewMask':counts,'selfViewOccupied':sum(bool(x&(1<<self_index))for x in masks),'otherViewOnlyOccupied':sum(x!=0 and not x&(1<<self_index)for x in masks),'noSingleViewOccupied':counts['0']}
def main():
 p=argparse.ArgumentParser();p.add_argument('--library',type=pathlib.Path,required=True);p.add_argument('--library-sha256',required=True);p.add_argument('--controls-receipt',type=pathlib.Path,required=True);p.add_argument('--controls-sha256',required=True);p.add_argument('--output',type=pathlib.Path,required=True);p.add_argument('--run-self',action='store_true');a=p.parse_args()
 require(a.run_self and os.environ.get('COFFEE_SELF_OUTER_GUARD')=='180','explicit bounded admission');require(not a.output.exists(),'fresh output required')
 resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,)*2);resource.setrlimit(resource.RLIMIT_CPU,(120,)*2);resource.setrlimit(resource.RLIMIT_FSIZE,(32*1024**2,)*2);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
 def stop(*_):raise TimeoutError('internal175second limit')
 signal.signal(signal.SIGALRM,stop);signal.alarm(175);start=time.monotonic();a.output.mkdir(parents=False)
 result={'status':'incomplete','physicalAuthority':False,'routeAcceptance':False,'heldoutDepthRead':False,'sameViewConsistencyNotAccuracy':True,'buildFrames':list(BUILD),'cases':[],'supportAttributionDefinition':'occupied singleton-map support at fused hit voxel center; not physical object identity or proof of occlusion','limits':{'CPUSeconds':120,'outerWallSeconds':180,'addressSpaceBytes':512*1024**2,'CPUCount':1,'fileBytes':32*1024**2}}
 pinned=[]
 try:
  manifest=json.loads((H/'MANIFEST.json').read_text())
  for e in manifest['files']:check(H/e['path'],e['sha256'],e['bytes'])
  pins=json.loads((H/'INPUT_PINS.json').read_text())
  for name,digest in pins['inputs'].items():
   f=W/name[12:]if name.startswith('@WORKSPACE@/')else R/name;check(f,digest,200*1024**2);pinned.append((f,digest))
  require(a.library_sha256==pins['admittedLibrarySHA256']and a.controls_sha256==pins['admittedControlsReceiptSHA256'],'unadmitted runtime');check(a.library,a.library_sha256,2*1024**2);check(a.controls_receipt,a.controls_sha256,65536)
  controls=json.loads(a.controls_receipt.read_text());raydir=R/'research/coffee-octomap-observation-rays-source-20261030'
  require(controls['status']=='completed-controls-only'and controls['librarySHA256']==a.library_sha256 and controls['buildReceiptSHA256']==pins['admittedBuildReceiptSHA256']and controls['sourceManifestSHA256']==sha(raydir/'MANIFEST.json'),'wrong native control receipt')
  require([(x['name'],x['testsRun'],x['expected'],x['failures'],x['errors'],x['skipped'],x['success'])for x in controls['suites']]==[('original',16,16,0,0,0,True),('read-only-rays',22,22,0,0,0,True),('observation-only-rays',10,10,0,0,0,True)],'all48controls required')
  original=R/'research/coffee-shared-pose-occupancy-source-20261029';pose=load(original/'pose_contract.py','fixed_pose');metric=load(H/'metrics.py','fixed_metrics');projector=load(R/'research/coffee-table-retention-default-guard-source-20261029/retention.py','fixed_projection');raybinding=load(raydir/'ray_binding.py','fixed_rays')
  metadata=json.loads((W/'coffee-recovered-source/transformations.json').read_text());frames={pathlib.Path(f['file_path']).stem:f for f in metadata['frames']};require(len(frames)==len(metadata['frames'])and metadata['camera_model']=='OPENCV'and metadata['orientation_override']=='none','metadata contract')
  frozen=json.loads((original/'FRAME_SELECTION.json').read_text());old=json.loads((W/'coffee-shared-pose-attempt-001/RESULT.json').read_text());primary=json.loads((R/'research/coffee-heldout-depth-result-20261030/RESULT.json').read_text());require(old['status']=='completed-observation-not-validation'and primary['exactBaselineRecreated'],'baseline not admitted')
  import numpy as np
  from PIL import Image
  def safe(points):require(np.isfinite(points).all()and(np.abs(points)<100).all(),'native coordinate domain')
  def frame_data(n):
   f=frames[n];require(f['depth_file_path']=='./depth/'+n+'.png'and f['file_path']=='./images/'+n+'.jpg','frame association');t,origin=pose.frame_contract(f);safe(np.asarray(origin));dp=W/'coffee-depth-diagnosis/depth'/(n+'.png');check(dp,frozen['depthSHA256'][n],1024**2)
   with Image.open(dp)as im:
    require(im.size==(738,994),'raster dimensions');d=np.asarray(im)
   require(d.dtype==np.uint16,'depth type');points,rr,cc=projector.project(d,f);require(len(points)==frozen['acceptedPointCounts'][n],'point count drift');world=np.column_stack(pose.transform_coordinates(points[:,0],points[:,1],points[:,2],t));safe(world);require(hashlib.sha256(world.tobytes()).hexdigest()==old['frames'][BUILD.index(n)]['worldFloat64SHA256'],'projection arithmetic drift')
   return f,t,origin,d,points,rr,cc,world
  def snapshot(tree,rays):
   state=rays.state();require(state['leaves']<=500000 and state['treeNodes']<=500000,'map cap');leaves=tree.leaves();digests={}
   for k,v in leaves.items():
    stream=io.BytesIO();np.lib.format.write_array(stream,v,allow_pickle=False);data=stream.getvalue();digests[k+'.npy']={'sha256':hashlib.sha256(data).hexdigest(),'bytes':len(data)}
   return {'state':state,'defaults':tree.defaults(),'payload':digests}
  def construct(names):
   tree,rays=raybinding.open_reviewed_tree(a.library,a.library_sha256,resolution=.05)
   try:
    for local_scan,n in enumerate(names):
     f,t,origin,d,points,rr,cc,world=frame_data(n);insert=tree.insert(local_scan,world,origin)
     if len(names)==3:require(insert==old['frames'][BUILD.index(n)]['nativeInsertion'],'original insertion counters drift')
    return tree,rays
   except BaseException:tree.close();raise
  def evaluate(tree,rays,n,kind):
   before=snapshot(tree,rays);f,t,origin,d,points,rr,cc,world=frame_data(n);grid=(rr%8==0)&(cc%8==0);gr=rr[grid];gc=cc[grid];z=points[grid,2].copy();del points,world,rr,cc
   camera=np.column_stack(((gc-f['cx'])/f['fl_x'],(gr-f['cy'])/f['fl_y'],np.ones(len(gr))));rot=np.asarray([x[:3]for x in t[:3]]);directions=camera@rot.T;limits=4*np.linalg.norm(directions,axis=1);require(np.isfinite(limits).all()and(limits<=8).all(),'fixed range outside ABI');inv=metric.inverse3([row[:3]for row in t[:3]])
   row={'kind':kind,'frame':n,'rasterPixels':738*994,'zeroDepthPixels':int((d==0).sum()),'rangeExcludedPixels':int((d>=4000).sum()),'fixedGridCandidates':metric.GRID_COUNT,'fixedGridZeroDepth':int((d[::8,::8]==0).sum()),'fixedGridRangeExcluded':int((d[::8,::8]>=4000).sum()),'fixedGridValid':len(z),'mapBefore':before,'mapLeafSizeCounts':{str(float(size)):int(count)for size,count in zip(*np.unique(tree.leaves()['xyzSizeProbability'][:,3],return_counts=True))},'nativeIntersectionBoxMetres':.05}
   require(row['fixedGridZeroDepth']+row['fixedGridRangeExcluded']+len(z)==metric.GRID_COUNT,'grid denominator')
   statuses=[];conservative=[];ezs=[];czs=[];radials=[];centers=[];indices=[];conflicts=0
   for first in range(0,len(z),256):
    conservative.extend(x['status']for x in rays.cast(origin,directions[first:first+256],limits[first:first+256]))
    for j,out in enumerate(rays.cast_observed(origin,directions[first:first+256],limits[first:first+256])):
     idx=first+j;statuses.append(out['status'])
     if out['status']!='observed-hit-visibility-unverified':continue
     require(out['terminalKnown']==1 and out['terminalOccupied']==1,'hit occupancy');ez=metric.axial(out['entry'],origin,inv);cz=metric.axial(out['center'],origin,inv);require(math.isfinite(ez)and math.isfinite(cz)and ez>0,'invalid axial entry')
     ezs.append(ez-float(z[idx]));czs.append(cz-float(z[idx]));native_origin=np.asarray(origin,dtype=np.float32).astype(np.float64);native_direction=directions[idx].astype(np.float32).astype(np.float64);measured_world=np.asarray(origin)+directions[idx]*float(z[idx]);projected=float(np.dot(measured_world-native_origin,native_direction)/np.linalg.norm(native_direction));radials.append(float(out['entryProjectedRange'])-projected);centers.append(out['center']);indices.append(int(gr[idx])*738+int(gc[idx]));conflicts+=out['hitScans']>0 and out['freeScans']>0
   centers=np.asarray(centers,dtype=np.float64).reshape((-1,3));safe(centers)
   row.update(primaryRayStatuses=metric.primary_partition(conservative,len(z)),observationRayStatuses=metric.partition(statuses,len(z)),entryAxialResidualMetres=metric.distributions(ezs),centerAxialResidualMetres=metric.distributions(czs),entryAlongRayResidualMetres=metric.distributions(radials),hitTerminalConflicts=conflicts)
   require(row['observationRayStatuses']['hit-known-prefix']==0 and len(ezs)==row['observationRayStatuses']['observed-hit-visibility-unverified'],'all observed hits only');require(snapshot(tree,rays)==before,'queries mutated map');row['beforeAfterPayloadEqual']=True
   # Exact paired evidence retained for external audit; these are derived geometry, not images.
   out=a.output/(kind+'_'+n+'.npz');np.savez(out,pixelIndex=np.asarray(indices,dtype=np.int32),observedCenter=centers,entryAxial=np.asarray(ezs),centerAxial=np.asarray(czs),entryAlongRay=np.asarray(radials));row['derivedEvidence']={'path':out.name,'sha256':sha(out),'bytes':out.stat().st_size}
   result['cases'].append(row);return centers
  # One map resident at a time. Fused map first, exact primary payload mandatory.
  fused_centers={};supports={};known_supports={};support_states={n:{}for n in BUILD}
  tree,rays=construct(BUILD)
  try:
   require(snapshot(tree,rays)==primary['baseline'],'exact original fused map drift');result['exactBaselineRecreated']=True
   for n in BUILD:fused_centers[n]=evaluate(tree,rays,n,'fused');supports[n]=np.zeros(len(fused_centers[n]),dtype=np.uint8);known_supports[n]=np.zeros(len(fused_centers[n]),dtype=np.uint8)
  finally:tree.close()
  for index,n in enumerate(BUILD):
   tree,rays=construct((n,))
   try:
    evaluate(tree,rays,n,'single');before=snapshot(tree,rays)
    for target in BUILD:
     centers=fused_centers[target]
     if len(centers):
      keys=tree.keys(centers);q=tree.query_keys(keys);known=q['known'].astype(bool);occupied=known&q['occupied'].astype(bool);supports[target][occupied]|=1<<index;known_supports[target][known]|=1<<index
      support_states[target][n]={'total':len(centers),'knownOccupied':int(occupied.sum()),'knownNotOccupied':int((known&~occupied).sum()),'unknown':int((~known).sum())}
     else:support_states[target][n]={'total':0,'knownOccupied':0,'knownNotOccupied':0,'unknown':0}
    require(snapshot(tree,rays)==before,'support attribution mutated single-view map')
   finally:tree.close()
  result['singletonKeyStatesAtFusedHits']=support_states
  for n in BUILD:
   fused=next(x for x in result['cases']if x['kind']=='fused'and x['frame']==n);single=next(x for x in result['cases']if x['kind']=='single'and x['frame']==n)
   for k in ('rasterPixels','zeroDepthPixels','rangeExcludedPixels','fixedGridCandidates','fixedGridZeroDepth','fixedGridRangeExcluded','fixedGridValid'):require(fused[k]==single[k],'self/fused denominator drift')
  result['fusedHitSingleViewSupport']={n:support_summary([int(x)for x in supports[n]],i)for i,n in enumerate(BUILD)}
  for n in BUILD:
   out=a.output/('support_'+n+'.npz');np.savez(out,occupiedSingletonMask=supports[n],knownSingletonMask=known_supports[n]);result['fusedHitSingleViewSupport'][n]['derivedEvidence']={'path':out.name,'sha256':sha(out),'bytes':out.stat().st_size}
  for f,digest in pinned:check(f,digest,200*1024**2)
  check(a.library,a.library_sha256,2*1024**2);check(a.controls_receipt,a.controls_sha256,65536);result.update(status='completed-self-versus-fused-diagnostic',librarySHA256=a.library_sha256,controlsReceiptSHA256=a.controls_sha256,sourceManifestSHA256=sha(H/'MANIFEST.json'))
 except Exception as e:result.update(status='failed',error=type(e).__name__+': '+str(e));raise
 finally:
  u=resource.getrusage(resource.RUSAGE_SELF);result.update(wallSeconds=time.monotonic()-start,cpuSeconds=u.ru_utime+u.ru_stime,peakRSSKiB=u.ru_maxrss)
  with(a.output/'RESULT.json').open('x')as f:json.dump(result,f,indent=2,allow_nan=False);f.write('\n')
  signal.alarm(0)
if __name__=='__main__':main()
