#!/usr/bin/env python3
"""UNEXECUTED separate observation-only fixed two-view diagnostic. No mesh, planner or physical authority."""
import os
for k in ('OPENBLAS_NUM_THREADS','OMP_NUM_THREADS','MKL_NUM_THREADS'):os.environ[k]='1'
import argparse,hashlib,importlib.util,io,json,math,pathlib,resource,signal,tarfile,time
H=pathlib.Path(__file__).resolve().parent;R=H.parents[1];W=R.parent
BUILD=('frame_00290','frame_00357','frame_00391');HOLD=('frame_00232','frame_00370')
def require(ok,why):
 if not ok:raise ValueError(why)
def sha(p):
 with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def load(p,name):
 s=importlib.util.spec_from_file_location(name,p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
def check(p,digest,cap):require(p.is_file() and not p.is_symlink() and p.stat().st_size<=cap and sha(p)==digest,'input drift: '+str(p))
def extract_two(archive,dest,expected):
 # Only two frozen PNG members may be materialized. No RGB/other depth opened.
 require(not dest.exists(),'fresh extraction directory required');dest.mkdir()
 wanted={f'room_datasets/coffee_room/iphone/long_capture/depth/{n}.png':n for n in HOLD};seen=set();receipt=[];count=total=0
 with tarfile.open(archive,'r|gz') as tar:
  for item in tar:
   count+=1;require(count<=2000,'archive member count cap')
   if item.name not in wanted:continue
   require(item.name not in seen and item.isfile() and not item.issym() and not item.islnk() and 0<item.size<=1024**2,'unsafe/duplicate selected member');seen.add(item.name)
   require(item.name==expected[wanted[item.name]],'member differs from frozen selection');total+=item.size;require(total<=2*1024**2,'selected extraction total cap')
   stream=tar.extractfile(item);require(stream is not None,'selected member unavailable');data=stream.read(1024**2+1);require(len(data)==item.size,'selected member length')
   target=dest/(wanted[item.name]+'.png')
   with target.open('xb')as f:f.write(data)
   receipt.append({'frame':wanted[item.name],'member':item.name,'bytes':len(data),'sha256':sha(target)})
 require(seen==set(wanted),'selected depth missing; no replacement');return receipt

def main():
 p=argparse.ArgumentParser();p.add_argument('--library',type=pathlib.Path,required=True);p.add_argument('--library-sha256',required=True);p.add_argument('--controls-receipt',type=pathlib.Path,required=True);p.add_argument('--controls-sha256',required=True);p.add_argument('--output',type=pathlib.Path,required=True);p.add_argument('--run-heldout',action='store_true');a=p.parse_args()
 require(a.run_heldout and os.environ.get('COFFEE_HELDOUT_OUTER_GUARD')=='180','explicit bounded admission required');require(not a.output.exists(),'fresh output required')
 resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,)*2);resource.setrlimit(resource.RLIMIT_CPU,(120,)*2);resource.setrlimit(resource.RLIMIT_FSIZE,(32*1024**2,)*2);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
 def stop(*_):raise TimeoutError('internal175second limit')
 signal.signal(signal.SIGALRM,stop);signal.alarm(175);start=time.monotonic();a.output.mkdir(parents=False)
 result={'status':'incomplete','physicalAuthority':False,'routeAcceptance':False,'sameCaptureConsistencyNotSensorAccuracy':True,'alongRayResidualDefinition':'voxel-entry projection minus measured endpoint projection, both using actual Float32 native origin/direction; axial uses original supplied exact inverse','rayMaxRangeDefinition':'4m axial envelope multiplied by original world-direction norm; native range is voxel-center based','frames':[],'buildFrames':list(BUILD),'heldoutFrames':list(HOLD),'quantiles':'linear interpolation at (n-1)*p; all finite residuals, no clipping','limits':{'CPUSeconds':120,'outerWallSeconds':180,'addressSpaceBytes':512*1024**2,'CPUCount':1,'fileBytes':32*1024**2}}
 pinned=[]
 try:
  manifest=json.loads((H/'MANIFEST.json').read_text())
  for x in manifest['files']:check(H/x['path'],x['sha256'],x['bytes'])
  pins=json.loads((H/'INPUT_PINS.json').read_text())
  for name,digest in pins['inputs'].items():
   f=W/name[12:] if name.startswith('@WORKSPACE@/') else R/name
   check(f,digest,200*1024**2);pinned.append((f,digest))
  require(isinstance(pins['admittedLibrarySHA256'],str) and len(pins['admittedLibrarySHA256'])==64,'new actual binary/control admission still pending');require(a.library_sha256==pins['admittedLibrarySHA256'] and a.controls_sha256==pins['admittedControlsReceiptSHA256'],'unadmitted runtime hashes');check(a.library,a.library_sha256,2*1024**2);check(a.controls_receipt,a.controls_sha256,65536)
  controls=json.loads(a.controls_receipt.read_text());require(controls['status']=='completed-controls-only' and controls['librarySHA256']==a.library_sha256,'native controls not passed for candidate');require(controls['buildReceiptSHA256']==pins['admittedBuildReceiptSHA256'],'build receipt mismatch')
  require([(x['name'],x['testsRun'],x['expected'],x['failures'],x['errors'],x['skipped'],x['success'])for x in controls['suites']]==[('original',16,16,0,0,0,True),('read-only-rays',22,22,0,0,0,True),('observation-only-rays',10,10,0,0,0,True)],'all48controls required')
  raydir=R/'research/coffee-octomap-observation-rays-source-20261030';require(controls['sourceManifestSHA256']==sha(raydir/'MANIFEST.json'),'wrong ray control source')
  primary=json.loads((R/'research/coffee-heldout-depth-result-20261030/RESULT.json').read_text());require(primary['status']=='completed-readonly-consistency-diagnostic' and primary['exactBaselineRecreated'],'original primary evidence missing');primary_rows={x['frame']:x for x in primary['frames']};result['primaryResultSHA256']=sha(R/'research/coffee-heldout-depth-result-20261030/RESULT.json');result['primaryResultsRetained']=primary['frames'];result['observationMode']='upstream ignoreUnknown=true; first observed occupied voxel, visibility unverified; never clearance';result['residualsAreObservedVoxelAgreementNotSurfaceTruth']=True
  original=R/'research/coffee-shared-pose-occupancy-source-20261029';plan=R/'research/coffee-heldout-pose-overlap-plan-20261030'
  selection=json.loads((plan/'HOLDOUT_SELECTION.json').read_text());frozen=json.loads((original/'FRAME_SELECTION.json').read_text());binding=json.loads((plan/'BASELINE_BINDING.json').read_text())
  metadata=json.loads((W/'coffee-recovered-source/transformations.json').read_text());frames={pathlib.Path(f['file_path']).stem:f for f in metadata['frames']};require(len(frames)==len(metadata['frames']),'duplicate frame metadata')
  require(metadata['camera_model']=='OPENCV'and metadata['orientation_override']=='none','metadata conventions')
  pose=load(original/'pose_contract.py','fixed_pose');metric=load(H/'metrics.py','heldout_metrics');projector=load(R/'research/coffee-table-retention-default-guard-source-20261029/retention.py','fixed_projection')
  transforms={n:pose.frame_contract(frames[n])for n in BUILD+HOLD}
  for n in BUILD+HOLD:
   f=frames[n];require(f['depth_file_path']=='./depth/'+n+'.png' and f['file_path']=='./images/'+n+'.jpg','pose/raster association')
   t,origin=transforms[n];require(all(abs(v)<100 for v in origin),'native origin domain')
   # Metadata-only range feasibility before any holdout raster access.
   maximum=max(4*math.sqrt(1+((u-f['cx'])/f['fl_x'])**2+((v-f['cy'])/f['fl_y'])**2) for u in(0,737)for v in(0,993));require(maximum<=8,'fixed axial4m exceeds ray ABI bound; stop, no clamp')
  for n in BUILD:check(W/'coffee-depth-diagnosis/depth'/(n+'.png'),frozen['depthSHA256'][n],1024**2)
  raybinding=load(raydir/'ray_binding.py','admitted_ray_binding')
  import numpy as np
  from PIL import Image
  tree,rays=raybinding.open_reviewed_tree(a.library,a.library_sha256,resolution=.05)
  def payload():
   state=rays.state();require(state['leaves']<=500000 and state['treeNodes']<=500000,'map cap')
   leaves=tree.leaves();digests={}
   for k,v in leaves.items():
    stream=io.BytesIO();np.lib.format.write_array(stream,v,allow_pickle=False);data=stream.getvalue();digests[k+'.npy']={'sha256':hashlib.sha256(data).hexdigest(),'bytes':len(data)}
   return {'state':state,'defaults':tree.defaults(),'payload':digests}
  def safe_world(world):require(np.isfinite(world).all() and (np.abs(world)<100).all(),'native endpoint domain; reject entire frame, never filter')
  def readdepth(dp):
   with Image.open(dp) as im:
    require(im.size==(738,994),'raster dimension');d=np.asarray(im)
   require(d.dtype==np.uint16,'uint16 axial millimetres required');return d
  try:
   oldreceipt=json.loads((W/'coffee-shared-pose-attempt-001/RESULT.json').read_text());require(oldreceipt['status']=='completed-observation-not-validation','baseline result incomplete')
   for scan,n in enumerate(BUILD):
    f=frames[n];t,origin=transforms[n];d=readdepth(W/'coffee-depth-diagnosis/depth'/(n+'.png'));points,rr,cc=projector.project(d,f);require(len(points)==frozen['acceptedPointCounts'][n],'training count drift')
    world=np.column_stack(pose.transform_coordinates(points[:,0],points[:,1],points[:,2],t));safe_world(world)
    require(hashlib.sha256(world.tobytes()).hexdigest()==oldreceipt['frames'][scan]['worldFloat64SHA256'],'training world arithmetic drift')
    ins=tree.insert(scan,world,origin);require(ins==oldreceipt['frames'][scan]['nativeInsertion'],'training insertion receipt drift');del d,points,rr,cc,world
   baseline=payload();expected={x['member']:{'sha256':x['uncompressedNPYSHA256'],'bytes':x['uncompressedBytes']}for x in binding['uncompressedMembers']};require(baseline['payload']==expected,'exact baseline payload drift; no scoring')
   require(baseline==primary['baseline'],'primary baseline state/default/payload drift');result['exactBaselineRecreated']=True;result['baseline']=baseline
   # Heldout bytes are opened only after construction is frozen and exact baseline established.
   candidates=selection['heldoutFrames']
   members={x['frameID']:x['member']for x in candidates};require(tuple(members)==HOLD,'holdout order changed')
   archive=W/'coffee-semantic-coverage/coffee_room_iphone.tar.gz';check(archive,selection['archiveSHA256'],selection['archiveBytes']);result['extraction']=extract_two(archive,a.output/'depth',members);check(archive,selection['archiveSHA256'],selection['archiveBytes']);require(result['extraction']==primary['extraction'],'exact heldout bytes differ from primary')
   for n in HOLD:
    before=payload();require(before==baseline,'map changed before holdout')
    f=frames[n];t,origin=transforms[n];inv=metric.inverse3([row[:3]for row in t[:3]]);d=readdepth(a.output/'depth'/(n+'.png'));points,rr,cc=projector.project(d,f);world=np.column_stack(pose.transform_coordinates(points[:,0],points[:,1],points[:,2],t));safe_world(world);keys=tree.keys(world)
    def counts(k):
     s=tree.query_keys(k);known=s['known'].astype(bool);occupied=s['occupied'].astype(bool)&known;conflict=(s['hitScans']>0)&(s['freeScans']>0)
     return {'total':len(k),'knownOccupied':int(occupied.sum()),'knownNotOccupied':int((known&~occupied).sum()),'unknown':int((~known).sum()),'hitFreeConflict':int(conflict.sum())}
    row={'frame':n,'rasterPixels':738*994,'zeroDepthPixels':int((d==0).sum()),'rangeExcludedPixels':int((d>=4000).sum()),'acceptedPixels':len(points),'endpointPixelWeighted':counts(keys),'endpointDistinctKeyWeighted':counts(np.unique(keys,axis=0))}
    grid=(rr%8==0)&(cc%8==0);gr=rr[grid];gc=cc[grid];z=points[grid,2].copy();del points,world,keys,rr,cc
    camera=np.column_stack(((gc-f['cx'])/f['fl_x'],(gr-f['cy'])/f['fl_y'],np.ones(len(gr))));rot=np.asarray([x[:3]for x in t[:3]]);directions=camera@rot.T;limits=4*np.linalg.norm(directions,axis=1);require(np.isfinite(limits).all()and(limits<=8).all(),'ray ABI range bound')
    statuses=[];primary_statuses=[];entry_z=[];center_z=[];radial=[];ray_conflicts=0
    for first in range(0,len(z),256):
     conservative=rays.cast(origin,directions[first:first+256],limits[first:first+256]);primary_statuses.extend(x['status']for x in conservative)
     batch=rays.cast_observed(origin,directions[first:first+256],limits[first:first+256])
     for j,out in enumerate(batch):
      idx=first+j;statuses.append(out['status'])
      if out['status']!='observed-hit-visibility-unverified':continue
      require(out['terminalKnown']==1 and out['terminalOccupied']==1,'scored hit must be known occupied');ez=metric.axial(out['entry'],origin,inv);cz=metric.axial(out['center'],origin,inv)
      require(math.isfinite(ez)and math.isfinite(cz)and ez>0,'invalid predicted axial point')
      entry_z.append(ez-float(z[idx]));center_z.append(cz-float(z[idx]));native_origin=np.asarray(origin,dtype=np.float32).astype(np.float64);native_direction=directions[idx].astype(np.float32).astype(np.float64);measured_world=np.asarray(origin)+directions[idx]*float(z[idx]);measured_projected=float(np.dot(measured_world-native_origin,native_direction)/np.linalg.norm(native_direction));radial.append(float(out['entryProjectedRange'])-measured_projected)
      ray_conflicts+=out['hitScans']>0 and out['freeScans']>0
    row.update(fixedGridCandidates=metric.GRID_COUNT,fixedGridZeroDepth=int((d[::8,::8]==0).sum()),fixedGridRangeExcluded=int((d[::8,::8]>=4000).sum()),fixedGridValid=len(z),observationRayStatuses=metric.partition(statuses,len(z)),primaryRayStatuses=metric.primary_partition(primary_statuses,len(z)),hitTerminalConflicts=ray_conflicts,entryAxialResidualMetres=metric.distributions(entry_z),centerAxialResidualMetres=metric.distributions(center_z),entryAlongRayResidualMetres=metric.distributions(radial))
    require(row['fixedGridZeroDepth']+row['fixedGridRangeExcluded']+len(z)==metric.GRID_COUNT,'full grid denominator');require(len(entry_z)==row['observationRayStatuses']['observed-hit-visibility-unverified'],'all valid hits scored')
    require(row['primaryRayStatuses']==primary_rows[n]['rayStatuses'],'primary status counts changed')
    for key in ('rasterPixels','zeroDepthPixels','rangeExcludedPixels','acceptedPixels','endpointPixelWeighted','endpointDistinctKeyWeighted','fixedGridCandidates','fixedGridZeroDepth','fixedGridRangeExcluded','fixedGridValid'):require(row[key]==primary_rows[n][key],'primary denominator/endpoint drift: '+key)
    require(row['observationRayStatuses']['hit-known-prefix']==0,'observation must never claim known-prefix clearance')
    del d,camera,directions,limits,z,gr,gc
    after=payload();require(after==before==baseline,'heldout mutated map');row['beforeAfterPayloadEqual']=True;result['frames'].append(row)
  finally:tree.close()
  for f,digest in pinned:check(f,digest,200*1024**2)
  check(a.library,a.library_sha256,2*1024**2);check(a.controls_receipt,a.controls_sha256,65536)
  result.update(status='completed-observation-only-consistency-diagnostic',librarySHA256=a.library_sha256,controlsReceiptSHA256=a.controls_sha256,sourceManifestSHA256=sha(H/'MANIFEST.json'))
 except Exception as e:result.update(status='failed',error=type(e).__name__+': '+str(e));raise
 finally:
  u=resource.getrusage(resource.RUSAGE_SELF);result.update(wallSeconds=time.monotonic()-start,cpuSeconds=u.ru_utime+u.ru_stime,peakRSSKiB=u.ru_maxrss)
  with(a.output/'RESULT.json').open('x')as f:json.dump(result,f,indent=2,allow_nan=False);f.write('\n')
  signal.alarm(0)
if __name__=='__main__':main()
