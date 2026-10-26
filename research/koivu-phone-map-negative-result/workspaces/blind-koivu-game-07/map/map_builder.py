"""Phone-only offline level-model builder. Never imports reference geometry or live policies."""
from pathlib import Path
import hashlib,itertools,json,math,os,resource,shutil,sys,time
import numpy as np
from PIL import Image
from scipy.ndimage import minimum_filter
ROOT=Path(__file__).resolve().parent
WS=ROOT.parents[1]
POSE=WS/'blind-mushroom-koivu-acquisition-01/selected/room_datasets/koivu/iphone/long_capture/transformations.json'
VOX=.05;CELL=.1;BAND=.03;RESERVE=768*1024**2

def sha(p):
 h=hashlib.sha256()
 with Path(p).open('rb') as f:
  for b in iter(lambda:f.read(1024**2),b''):h.update(b)
 return h.hexdigest()

def log(phase,**values):print(json.dumps({'phase':phase,'monotonic':time.monotonic(),**values}),flush=True)

def checked_camera(frame):
 c=np.asarray(frame['transform_matrix'],float);k=np.array([frame[x] for x in ('fl_x','fl_y','cx','cy')],float)
 if c.shape!=(4,4) or not np.isfinite(c).all() or not np.isfinite(k).all() or np.any(k[:2]<=0):raise ValueError('bad calibration')
 if np.max(np.abs(c[3]-[0,0,0,1]))>1e-10 or np.max(np.abs(c[:3,:3].T@c[:3,:3]-np.eye(3)))>1e-5 or abs(np.linalg.det(c[:3,:3])-1)>1e-5:raise ValueError('bad rigid camera')
 if any(abs(float(frame.get(n,0)))>0 for n in ('k1','k2','k3','k4','p1','p2')):raise ValueError('unsupported nonzero distortion')
 return c,k

def depth_read(entry,frame):
 path=ROOT/'depths'/entry['file']
 if sha(path)!=entry['sha256']:raise ValueError('depth hash changed')
 with Image.open(path) as im:d=np.array(im)
 if d.ndim!=2 or d.shape!=(int(frame['h']),int(frame['w'])) or d.dtype not in (np.dtype('int32'),np.dtype('uint16')) or d.min()<0 or d.max()>65535:raise ValueError('unexpected original depth raster')
 return d.astype(np.float64)*.001

def points_from_depth(depth,frame):
 c,k=checked_camera(frame);rr,cc=np.indices(depth.shape,dtype=np.float64)
 rays=np.stack(((cc+.5-k[2])/k[0],-(rr+.5-k[3])/k[1],-np.ones_like(rr)),axis=-1)
 valid=np.isfinite(depth)&(depth>0)
 points=(rays[valid]*depth[valid,None])@c[:3,:3].T+c[:3,3]
 if not np.isfinite(points).all():raise ValueError('nonfinite projected endpoint')
 return points,int((~valid).sum())

def grid(points,origin,shape):
 if not np.isfinite(points).all():raise ValueError('nonfinite grid endpoint')
 q=np.floor((points-origin)/VOX).astype(np.int64);inside=np.all((q>=0)&(q<shape),axis=1)
 q=q[inside];key=(q[:,0]*shape[1]+q[:,1])*shape[2]+q[:,2]
 return key,inside

def indices(keys,shape):return np.column_stack((keys//(shape[1]*shape[2]),(keys//shape[2])%shape[1],keys%shape[2]))

def fit_floor(centres,camera_z):
 low,high=float(np.median(camera_z)-2.5),float(np.median(camera_z)-.5)
 eligible=centres[(centres[:,2]>=low)&(centres[:,2]<=high)]
 if len(eligible)<200:raise ValueError('insufficient low-plane candidate hits')
 zb=np.floor(eligible[:,2]/VOX).astype(int);values,counts=np.unique(zb,return_counts=True);mode=int(values[np.argmax(counts)]);height=(mode+.5)*VOX
 p=eligible[np.abs(eligible[:,2]-height)<=.075+1e-10]
 initial=len(p)
 for iteration in range(3):
  if len(p)<200 or np.ptp(p[:,0])<1 or np.ptp(p[:,1])<1:raise ValueError('insufficient plane extent')
  design=np.column_stack((p[:,:2],np.ones(len(p))))
  fit,_,rank,_=np.linalg.lstsq(design,p[:,2],rcond=None)
  if rank!=3 or not np.isfinite(fit).all():raise ValueError('rank-deficient or nonfinite plane')
  residual=p[:,2]-(p[:,0]*fit[0]+p[:,1]*fit[1]+fit[2]);p=p[np.abs(residual)<=BAND]
  if len(p)<200 or np.ptp(p[:,0])<1 or np.ptp(p[:,1])<1:raise ValueError('plane extent lost during refit')
 a,b,c=fit;normal=np.array([-a,-b,1.]);norm=np.linalg.norm(normal);normal/=norm
 tilt=float(np.degrees(np.arccos(normal[2])))
 if tilt>5 or len(p)<200 or np.ptp(p[:,0])<1 or np.ptp(p[:,1])<1:raise ValueError('invalid fitted level model')
 x=np.array([1.,0.,0.]);x-=normal*np.dot(x,normal);x/=np.linalg.norm(x);z=np.cross(x,normal)
 m=np.eye(4);m[:3,:3]=np.stack((x,normal,z));m[1,3]=-c/norm
 return m,{'assumedInitialUp':[0,0,1],'floorModel':'phone-only fixed mode and three least-squares trims; not measured gravity','modeHeight':height,'candidateRange':[low,high],'initialVoxelCentres':initial,'retainedVoxelCentres':len(p),'planeABC':fit.tolist(),'tiltDegrees':tilt,'retainedResidualMax':float(np.max(np.abs(p[:,2]-(p[:,0]*a+p[:,1]*b+c)))),'floorBandMetres':BAND}

def free_observed(points,depth,frame,phone_to_app):
 camera,_=checked_camera(frame);app_to_cam=np.linalg.inv(camera)@np.linalg.inv(phone_to_app)
 p=points@app_to_cam[:3,:3].T+app_to_cam[:3,3];z=-p[:,2];fx,fy,cx,cy=(float(frame[n]) for n in ('fl_x','fl_y','cx','cy'))
 with np.errstate(divide='ignore',invalid='ignore'):
  u=fx*p[:,0]/z+cx-.5;v=-fy*p[:,1]/z+cy-.5
 valid=np.isfinite(u)&np.isfinite(v)&np.isfinite(z)&(z>=.15)
 # Nearest source pixel centre; actual neighbourhood minimum, no interpolation.
 cc=np.zeros(len(p),np.int64);rr=np.zeros(len(p),np.int64);cc[valid]=np.floor(u[valid]+.5).astype(np.int64);rr[valid]=np.floor(v[valid]+.5).astype(np.int64)
 valid&=(rr>=1)&(cc>=1)&(rr<depth.shape[0]-1)&(cc<depth.shape[1]-1)
 result=np.zeros(len(p),bool);ids=np.flatnonzero(valid)
 minimum=minimum_filter(depth,size=3,mode='constant',cval=0.)
 observed=minimum[rr[ids],cc[ids]]
 result[ids]=(observed>=.15)&(observed<=8.)&(observed>=z[ids]+.05)
 return result

def accumulate(keys,y,hits,views,ymin,ymax):
 unique,num=np.unique(keys,return_counts=True);hits[unique]+=num.astype(np.uint32);views[unique]+=1
 np.minimum.at(ymin,keys,y);np.maximum.at(ymax,keys,y)

def surface_classification(ijk,vmin,vmax,vviews,width,height):
 total=width*height;x=ijk[:,0];z=ijk[:,2];surface=(z//2)*width+x//2
 ground=(vmin>=-BAND)&(vmax<=BAND)&(vviews>=2)
 quads=np.zeros((total,4),bool);quads[surface[ground],(z[ground]%2)*2+x[ground]%2]=True
 support=quads.all(1);block=np.zeros(total,bool)
 obstacle=(vmax>BAND)&(vmin<1.75);contradiction=(vmin< -BAND)&(vmax>-.25)
 block[surface[obstacle|contradiction]]=True;block|=~support
 return support,block,obstacle,contradiction,ground

def verify_frozen(expected):
 frozen=ROOT/'FROZEN.json'
 if sha(frozen)!=expected:raise ValueError('frozen cut hash mismatch')
 config=json.loads(frozen.read_text())
 for path,digest in config['files'].items():
  if sha(WS/path)!=digest:raise ValueError('frozen source/input pin mismatch: '+path)
 return config

def build(output,expected):
 output=Path(output);output.mkdir(exist_ok=False);started=time.monotonic()
 frozen=verify_frozen(expected)
 manifest=json.loads((ROOT/'depths/DEPTH_INPUT_MANIFEST.json').read_text());selection=json.loads((ROOT/'DEPTH_SELECTION.json').read_text());frames=json.loads(POSE.read_text())['frames']
 if len(frames)!=294 or len(manifest['files'])!=294 or sha(POSE)!=manifest['poseSHA256']:raise ValueError('frozen input set mismatch')
 if [{k:e[k] for k in ('poseIndex','member','bytes')} for e in manifest['files']]!=selection['members'] or manifest['selectionSHA256']!=sha(ROOT/'DEPTH_SELECTION.json') or sum(e['bytes'] for e in manifest['files'])!=selection['bytes']:raise ValueError('selection/manifest identity mismatch')
 pins=frozen['files']
 (output/'INPUT_SOURCE_PINS.json').write_text(json.dumps(pins,indent=2)+'\n')
 for entry,frame in zip(manifest['files'],frames):
  if Path(frame['depth_file_path']).name!=entry['file']:raise ValueError('pose/depth mismatch')
  checked_camera(frame)
 cams=np.array([f['transform_matrix'] for f in frames]);lo=np.floor((cams[:,:3,3].min(0)-3)/VOX)*VOX;hi=np.ceil((cams[:,:3,3].max(0)+3)/VOX)*VOX;shape=np.rint((hi-lo)/VOX).astype(int)
 if np.prod(shape)>30000000:raise ValueError('initial grid cap')
 hit=np.zeros(int(np.prod(shape)),bool);counts={'scheduledPixels':0,'missingDepthPixels':0,'outsideInitialROIPoints':0,'insideInitialROIPoints':0}
 log('initial_occupancy_start',shape=shape.tolist())
 for i,(entry,frame) in enumerate(zip(manifest['files'],frames)):
  d=depth_read(entry,frame);p,missing=points_from_depth(d,frame);keys,inside=grid(p,lo,shape);hit[keys]=True
  counts['scheduledPixels']+=d.size;counts['missingDepthPixels']+=missing;counts['outsideInitialROIPoints']+=int((~inside).sum());counts['insideInitialROIPoints']+=int(inside.sum())
  if i%25==0:log('initial_occupancy',frame=i)
 if counts['scheduledPixels']!=counts['missingDepthPixels']+counts['outsideInitialROIPoints']+counts['insideInitialROIPoints']:raise ValueError('pixel accounting mismatch')
 occupied=np.flatnonzero(hit);centres=lo+(indices(occupied,shape)+.5)*VOX;transform,floor_report=fit_floor(centres,cams[:,2,3]);del hit,occupied,centres
 log('floor_model',**floor_report)
 corners=np.asarray(list(itertools.product(*zip(lo,hi))));ac=corners@transform[:3,:3].T+transform[:3,3];alo=np.floor(ac.min(0)/CELL)*CELL;ahi=np.ceil(ac.max(0)/CELL)*CELL;ashape=np.rint((ahi-alo)/VOX).astype(int)
 if np.prod(ashape)>40000000:raise ValueError('aligned grid cap')
 n=int(np.prod(ashape));hits=np.zeros(n,np.uint32);views=np.zeros(n,np.uint16);ymin=np.full(n,np.inf,np.float64);ymax=np.full(n,-np.inf,np.float64)
 log('aligned_occupancy_start',shape=ashape.tolist())
 for i,(entry,frame) in enumerate(zip(manifest['files'],frames)):
  d=depth_read(entry,frame);p,_=points_from_depth(d,frame);_,inside=grid(p,lo,shape);p=p[inside];p=p@transform[:3,:3].T+transform[:3,3];keys,inside=grid(p,alo,ashape)
  if not inside.all():raise ValueError('transformed ROI escaped enclosing bounds')
  accumulate(keys,p[:,1],hits,views,ymin,ymax)
  if i%25==0:log('aligned_occupancy',frame=i)
 occupied=np.flatnonzero(hits);ijk=indices(occupied,ashape);vmin=ymin[occupied].astype(float);vmax=ymax[occupied].astype(float);vhits=hits[occupied];vviews=views[occupied]
 if int(vhits.astype(np.uint64).sum())!=counts['insideInitialROIPoints']:raise ValueError('aligned hit accounting mismatch')
 del hits,views,ymin,ymax
 # Surface coordinates are row-major app Z * width + app X. Aligned5cm cells pair exactly into10cm cells.
 width=int(ashape[0]//2);height=int(ashape[2]//2);total=width*height
 if width*2!=ashape[0] or height*2!=ashape[2] or total>250000:raise ValueError('surface dimensions')
 support,block,obstacle,contradiction,ground=surface_classification(ijk,vmin,vmax,vviews,width,height)
 eligible=np.flatnonzero(~block);coverage=np.zeros((len(eligible),90),bool)
 base=np.column_stack((alo[0]+(eligible%width)*CELL,alo[2]+(eligible//width)*CELL))
 horizontal=np.array([[.05,.05],[.005,.005],[.005,.095],[.095,.005],[.095,.095]])
 heights=np.arange(18)*.1+.05
 samples=np.empty((len(eligible),5,18,3));samples[:,:,:,0]=base[:,None,None,0]+horizontal[None,:,None,0];samples[:,:,:,2]=base[:,None,None,1]+horizontal[None,:,None,1];samples[:,:,:,1]=heights[None,None,:];samples=samples.reshape(-1,3)
 covered=coverage.reshape(-1);log('coverage_start',candidateCells=len(eligible),samples=len(samples))
 for i,(entry,frame) in enumerate(zip(manifest['files'],frames)):
  pending=np.flatnonzero(~covered)
  if len(pending):covered[pending]|=free_observed(samples[pending],depth_read(entry,frame),frame,transform)
  if i%25==0:log('coverage',frame=i,pendingSamples=int((~covered).sum()))
 clear=np.zeros(total,bool);clear[eligible]=coverage.all(1)
 cells=[{'floor':0. if support[i] else None,'clearance':1.75 if clear[i] else None,'blocked':bool(block[i]),'floorUncertainty':None} for i in range(total)]
 surface_json={'level':'koivu-offline-estimated-v1','origin':{'x':float(alo[0]),'y':0.,'z':float(alo[2])},'resolution':CELL,'width':width,'depth':height,'cells':cells}
 (output/'SURFACE.json').write_text(json.dumps(surface_json,separators=(',',':'))+'\n')
 np.savez_compressed(output/'MAP.npz',voxelIndices=ijk.astype(np.int16),voxelOrigin=alo,voxelResolution=np.array(VOX),voxelMinimumObservedY=vmin,voxelMaximumObservedY=vmax,voxelHitCount=vhits,voxelSourceFrameCount=vviews,voxelObstacle=obstacle,voxelFloorContradiction=contradiction,surfaceSupport=support,surfaceBlocked=block,surfaceSampledClearance=clear,surfaceCandidateIndices=eligible,surfaceSampleCoverage=coverage,phoneToApp=transform,appToPhone=np.linalg.inv(transform),surfaceWidth=np.array(width),surfaceDepth=np.array(height),surfaceOrigin=np.array([alo[0],0,alo[2]]),surfaceResolution=np.array(CELL))
 report={'status':'complete offline estimated map; no navigation run','inputFrames':len(frames),'inputDepthSHA256':{e['file']:e['sha256'] for e in manifest['files']},'floor':floor_report,'phoneToApp':transform.tolist(),'appToPhone':np.linalg.inv(transform).tolist(),'initialROI':[lo.tolist(),hi.tolist()],'counts':{**counts,'occupiedVoxels':len(ijk),'surfaceCells':total,'supportedCells':int(support.sum()),'positiveBlockedOrUnknownSupportCells':int(block.sum()),'candidateSupportedUnblockedCells':len(eligible),'fullySampledClearanceCells':int(clear.sum()),'positiveObstacleVoxels':int(obstacle.sum()),'floorContradictionVoxels':int(contradiction.sum()),'groundBandVoxelCount':int(ground.sum())},'seconds':time.monotonic()-started,'confidence':'unavailable; not invented','tracking':'unavailable; not invented','gravity':'phone+Z seed and estimated plane, not measured','clearance':'finite-sampled model only; not physical or continuous-volume proof','groundBandAmbiguityMetres':BAND,'noFAROInput':True,'outputs':{n:sha(output/n) for n in ('SURFACE.json','MAP.npz')}}
 if shutil.disk_usage(ROOT).free<RESERVE:raise ValueError('disk reserve')
 if sum(p.stat().st_size for p in output.iterdir() if p.is_file())>64*1024**2:raise ValueError('output cap')
 for path,digest in pins.items():
  if sha(WS/path)!=digest:raise ValueError('source changed')
 for e in manifest['files']:
  if sha(ROOT/'depths'/e['file'])!=e['sha256']:raise ValueError('input changed')
 verify_frozen(expected)
 (output/'MAP_RECEIPT.json').write_text(json.dumps(report,indent=2)+'\n');log('complete',**report['counts'],seconds=report['seconds'])

if __name__=='__main__':build(sys.argv[1],sys.argv[2])
