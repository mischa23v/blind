"""Same phone data, established native occupancy fusion; no reference/route inputs."""
from pathlib import Path
import hashlib,json,shutil,sys,time
import numpy as np
ROOT=Path(__file__).resolve().parent;WS=ROOT.parents[1]
sys.path.insert(0,str(ROOT.parent/'map'));import map_builder as original
sys.path.insert(0,str(WS/'blind-octomap-reuse-08'));from octomap_engine import OctoMap
import surface_import
V1=ROOT.parent/'map/run-01/map';RESERVE=768*1024**2

def verify(expected):
 p=ROOT/'FROZEN.json'
 if original.sha(p)!=expected:raise ValueError('frozen v2 hash mismatch')
 config=json.loads(p.read_text())
 for name,digest in config['files'].items():
  if original.sha(WS/name)!=digest:raise ValueError('v2 source/input changed: '+name)
 original.verify_frozen('d69e2c1bd61ebb61d307056e53f5c8b653e06eb9ae8189667fa425500461b350')
 return config

def packed(q):return (q[:,0].astype(np.uint64)<<32)|(q[:,1].astype(np.uint64)<<16)|q[:,2].astype(np.uint64)
def native_unpack(k):return np.column_stack(((k>>32)&65535,(k>>16)&65535,k&65535)).astype(np.uint16)
def log(phase,**args):print(json.dumps({'phase':phase,'monotonic':time.monotonic(),**args}),flush=True)
def associate_points(points,origin,resolution,raw_keys,centre_keys,tree):
 q=np.floor((points-origin)/resolution).astype(np.int64);code=packed(q);index=np.searchsorted(raw_keys,code)
 if np.any(index>=len(raw_keys))or not np.array_equal(raw_keys[index],code):raise ValueError('raw membership differs from v1')
 pf=np.ascontiguousarray(points,np.float32);actual_keys=tree.keys(pf);equal=np.all(actual_keys==centre_keys[index],axis=1)
 return index,pf,actual_keys,equal,float(np.max(np.abs(points-pf.astype(np.float64))))

def run(output,expected):
 started=time.monotonic();config=verify(expected);out=Path(output);out.mkdir(exist_ok=False)
 raw=np.load(V1/'MAP.npz');receipt=json.loads((V1/'MAP_RECEIPT.json').read_text());manifest=json.loads((original.ROOT/'depths/DEPTH_INPUT_MANIFEST.json').read_text());frames=json.loads(original.POSE.read_text())['frames']
 if len(frames)!=294 or len(manifest['files'])!=294:raise ValueError('fixed frame count')
 (out/'INPUT_SOURCE_PINS.json').write_text(json.dumps(config,indent=2)+'\n')
 ijk=raw['voxelIndices'].astype(np.int64);raw_keys=packed(ijk)
 if np.any(raw_keys[1:]<=raw_keys[:-1]):raise ValueError('raw voxel key order')
 origin=raw['voxelOrigin'];resolution=float(raw['voxelResolution']);transform=raw['phoneToApp'];lo,hi=np.array(receipt['initialROI']);shape=np.rint((hi-lo)/resolution).astype(int)
 hit_total=np.zeros(len(ijk),np.uint32);default_seen=np.zeros(len(ijk),bool);deviations=set();deviation_pixels=0;max_conversion=0.;max_origin_conversion=0.;scans=[];missing=0;outside=0
 with OctoMap(.05)as tree:
  defaults=tree.defaults()
  if not np.allclose(list(defaults.values()),[.05,.7,.4,.5,.1192,.971],atol=1e-7,rtol=0):raise ValueError('native defaults changed')
  centre_keys=tree.keys(origin+(ijk+.5)*resolution)
  with (out/'SCANS.jsonl').open('x')as scanlog:
   for i,(entry,frame) in enumerate(zip(manifest['files'],frames)):
    if entry['poseIndex']!=i or Path(frame['depth_file_path']).name!=entry['file']:raise ValueError('original frame association')
    depth=original.depth_read(entry,frame);points,nmissing=original.points_from_depth(depth,frame);_,inside=original.grid(points,lo,shape);outside+=int((~inside).sum());missing+=nmissing;points=points[inside];points=points@transform[:3,:3].T+transform[:3,3]
    index,pf,actual_keys,equal,conversion=associate_points(points,origin,resolution,raw_keys,centre_keys,tree)
    unique,count=np.unique(index,return_counts=True);hit_total[unique]+=count.astype(np.uint32);max_conversion=max(max_conversion,conversion)
    default_seen[index[equal]]=True;deviation_pixels+=int((~equal).sum())
    if (~equal).any():
     pairs=np.unique(np.column_stack((index[~equal].astype(np.uint64),packed(actual_keys[~equal]))),axis=0)
     deviations.update((int(a),int(b))for a,b in pairs)
     if len(deviations)>1000000:raise ValueError('native association deviation cap')
    cam=np.asarray(frame['transform_matrix'])[:3,3];cam=transform[:3,:3]@cam+transform[:3,3];max_origin_conversion=max(max_origin_conversion,float(np.max(np.abs(cam-cam.astype(np.float32).astype(float)))))
    start=time.monotonic();stats=tree.insert(i,pf,cam);stats.update({'file':entry['file'],'sha256':entry['sha256'],'nativeInsertWallSeconds':time.monotonic()-start,'float32MaxCoordinateConversion':conversion,'nativeBoundaryDifferentPixels':int((~equal).sum())});scans.append(stats);scanlog.write(json.dumps(stats)+'\n');scanlog.flush()
    if i%10==0:log('native_fusion',frame=i,**{k:stats[k]for k in ('originalPoints','occupiedKeys','freeKeys','treeNodes','conflictKeys')},seconds=time.monotonic()-started)
    if shutil.disk_usage(ROOT).free<RESERVE:raise ValueError('disk reserve')
  if missing!=0 or outside!=0 or not np.array_equal(hit_total,raw['voxelHitCount']):raise ValueError('full original hit accounting changed')
  base=np.flatnonzero(default_seen);deviant=np.array(sorted(deviations),dtype=np.uint64).reshape(-1,2);raw_index=np.concatenate((base,deviant[:,0].astype(np.int64)));pair_keys=np.concatenate((centre_keys[base],native_unpack(deviant[:,1])),axis=0);association_complete=np.zeros(len(ijk),bool);association_complete[raw_index]=True
  if not association_complete.all():raise ValueError('missing raw/native association')
  native=tree.query_keys(pair_keys);native_query_index=np.arange(len(pair_keys),dtype=np.int64)
  log('classify_start',associationPairs=len(pair_keys),boundaryDeviations=len(deviant))
  classified=surface_import.classify(ijk,raw['voxelMinimumObservedY'],raw['voxelMaximumObservedY'],raw['voxelSourceFrameCount'],int(raw['surfaceWidth']),int(raw['surfaceDepth']),raw_index,native_query_index,native,association_complete)
  # Classification contract is separately authored/reviewed; no native threshold ownership here.
  support=classified['support'];blocked=classified['blocked'];eligible=np.flatnonzero(~blocked);width=int(raw['surfaceWidth']);height=int(raw['surfaceDepth']);surface_origin=raw['surfaceOrigin'];base_xy=np.column_stack((surface_origin[0]+(eligible%width)*.1,surface_origin[2]+(eligible//width)*.1))
  horizontal=np.array([[.05,.05],[.005,.005],[.005,.095],[.095,.005],[.095,.095]]);heights=np.arange(18)*.1+.05;samples=np.empty((len(eligible),5,18,3));samples[:,:,:,0]=base_xy[:,None,None,0]+horizontal[None,:,None,0];samples[:,:,:,2]=base_xy[:,None,None,1]+horizontal[None,:,None,1];samples[:,:,:,1]=heights[None,None,:];samples=samples.reshape(-1,3);projected=np.zeros(len(samples),bool)
  log('coverage_start',candidateCells=len(eligible),sampleCount=len(samples))
  for i,(entry,frame)in enumerate(zip(manifest['files'],frames)):
   pending=np.flatnonzero(~projected)
   if len(pending):projected[pending]|=original.free_observed(samples[pending],original.depth_read(entry,frame),frame,transform)
   if i%50==0:log('coverage',frame=i,pending=int((~projected).sum()))
  query=tree.query(samples);coverage=surface_import.combine_coverage(projected.reshape(len(eligible),90),query)
  clear=np.zeros(width*height,bool);clear[eligible]=coverage['cellClearanceEstimated']
  cells=[{'floor':0. if support[i]else None,'clearance':1.75 if clear[i]else None,'blocked':bool(blocked[i]),'floorUncertainty':None}for i in range(width*height)]
  surface={'level':'koivu-offline-estimated-octomap-v2','origin':{'x':float(surface_origin[0]),'y':0.,'z':float(surface_origin[2])},'resolution':.1,'width':width,'depth':height,'cells':cells}
  (out/'SURFACE.json').write_text(json.dumps(surface,separators=(',',':'))+'\n')
  leaves=tree.leaves();np.savez_compressed(out/'OCTOMAP_LEAVES.npz',**leaves)
  np.savez_compressed(out/'RAW_NATIVE_ASSOCIATIONS.npz',rawIndex=raw_index,nativeKeys=pair_keys,nativeQueryIndex=native_query_index,associationComplete=association_complete,defaultKeyObserved=default_seen,**native)
  arrays={k:v for k,v in classified.items()if isinstance(v,np.ndarray)};arrays.update({'eligibleCells':eligible,'projectedSampleCoverage':projected.reshape(len(eligible),90),'surfaceClearanceKnown':clear});arrays.update({'coverage_'+k:v for k,v in coverage.items()if isinstance(v,np.ndarray)})
  np.savez_compressed(out/'SURFACE_EVIDENCE.npz',**arrays)
  summary={'status':'complete estimated occupancy map only; zero games','frames':294,'inputPixels':int(hit_total.astype(np.uint64).sum()),'missingPixels':missing,'outsideROI':outside,'nativeDefaults':defaults,'rawVoxels':len(ijk),'associationPairs':len(pair_keys),'nonCentreKeyAssociations':len(deviant),'nativeBoundaryDifferentPixels':deviation_pixels,'maxFloat32PointConversion':max_conversion,'maxFloat32OriginConversion':max_origin_conversion,'nativeLeaves':len(leaves['logOdds']),'nativeConflictedLeafCount':int(((leaves['hitScans']>0)&(leaves['freeScans']>0)).sum()),'surfaceSupportedCells':int(support.sum()),'surfaceUnblockedCells':len(eligible),'surfaceClearanceCells':int(clear.sum()),'classificationCounts':{k:int(v.sum()) for k,v in classified.items()if isinstance(v,np.ndarray) and v.dtype==np.bool_},'coverageCounts':{k:int(v.sum()) for k,v in coverage.items()if isinstance(v,np.ndarray) and v.dtype==np.bool_},'seconds':time.monotonic()-started,'rawV1MapSHA256':original.sha(V1/'MAP.npz'),'FAROUsed':False,'physicalAuthority':False,'outputs':{p.name:original.sha(p)for p in out.iterdir()if p.is_file()}}
 verify(expected)
 for entry in manifest['files']:
  if original.sha(original.ROOT/'depths'/entry['file'])!=entry['sha256']:raise ValueError('source depth changed')
 data=json.dumps(summary,indent=2)+'\n'
 if sum(p.stat().st_size for p in out.iterdir()if p.is_file())+len(data.encode())>64*1024**2 or shutil.disk_usage(ROOT).free<RESERVE:raise ValueError('output/reserve bound')
 (out/'MAP_RECEIPT.json').write_text(data);log('complete',**summary)
if __name__=='__main__':run(sys.argv[1],sys.argv[2])
