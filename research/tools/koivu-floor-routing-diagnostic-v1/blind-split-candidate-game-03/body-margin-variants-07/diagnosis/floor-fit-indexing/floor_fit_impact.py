"""Additive signed-key X decoding diagnostic. No map, fusion, reference, or routes.

Reproduce original source rows and R/t first. Correct only decoded row X using
signed Y. Report numerical plane changes, not reclassified map or physical floor.
"""
from pathlib import Path
from io import BytesIO
from types import SimpleNamespace
import ast,hashlib,json,os,sys
import numpy as np
import PIL
from PIL import Image
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent
GAME=HERE.parents[2];WS=GAME.parent
SOURCE=WS/'blind-opus-reference-scoring-audit-02/upstream/scripts/pipeline.py'
POSE=WS/'blind-mushroom-koivu-acquisition-01/selected/room_datasets/koivu/iphone/long_capture/transformations.json'
DEPTH=WS/'blind-koivu-game-07/map/depths'
MANIFEST=DEPTH/'DEPTH_INPUT_MANIFEST.json'
META=GAME/'inputs/koivu_5cm_v2_pipeline2_out.npz'
MASK=GAME/'inputs/koivu_5cm_occthres_split0.7.npz'
ROI=GAME/'room-scale-readonly-audit/WESTERN_PASSAGE_CAMERA_CELLS.json'
MATCH_ATOL=1e-12

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def source_functions():
 tree=ast.parse(SOURCE.read_text());functions=[n for n in tree.body if isinstance(n,ast.FunctionDef)and n.name in ('lidar_samples','level_frame')]
 if len(functions)!=2:raise ValueError('original function identity')
 # No upstream module import: it imports OctoMap and contains reference scoring.
 env={'np':np,'os':os,'Image':Image,'THRESHOLDS':{'floor_search':(-2.6,-.4),'floor_cell':.2},'log':lambda **kw:None}
 exec(compile(ast.Module(body=functions,type_ignores=[]),str(SOURCE),'exec'),env)
 return env

def project(dep,f):
 # Same evaluation order and final Float32 conversion as source lidar_samples.
 dep=dep.astype(np.float64)*.001
 h,w=dep.shape;rr=np.arange(h);cc=np.arange(w);rs=rr[(rr+15)%4==2];cs=cc[(cc+15)%4==2]
 dd=dep[np.ix_(rs,cs)]
 R,C=np.meshgrid(rs.astype(np.float64)-.5+.5,cs.astype(np.float64)-.5+.5,indexing='ij')
 rays=np.stack(((C+.5-f['cx'])/f['fl_x'],-(R+.5-f['cy'])/f['fl_y'],-np.ones_like(R)),-1)
 c=np.array(f['transform_matrix']);p=(rays*dd[...,None]).reshape(-1,3)@c[:3,:3].T+c[:3,3]
 v=dd.reshape(-1)>0
 return p[v].astype(np.float32)

def decode(keys,corrected):
 y=keys%100000;y=np.where(y<50000,y,y-100000)
 x=(keys-y)//100000 if corrected else keys//100000
 return np.c_[x,y]

def plane(rows):
 A=np.c_[rows[:,:2],np.ones(len(rows))];k=np.linalg.lstsq(A,rows[:,2],rcond=None)[0]
 n=np.array([-k[0],-k[1],1.]);n/=np.linalg.norm(n);x=np.array([1.,0,0]);x-=n*x.dot(n);x/=np.linalg.norm(x);y=np.cross(n,x)
 R=np.stack((x,y,n));t=-R@np.array([0,0,k[2]])
 residual=rows[:,2]-A@k
 return k,R,t,residual

def rows_from_source(P,cams):
 lo,hi=(-2.6,-.4);zc=np.median(cams[:,2]);Q=P[(P[:,2]>zc+lo)&(P[:,2]<zc+hi)]
 hist,edges=np.histogram(Q[:,2],bins=np.arange(zc+lo,zc+hi,.01));z0=edges[np.argmax(hist)]+.005
 Q=Q[np.abs(Q[:,2]-z0)<.12]
 C=.2;k=np.floor(Q[:,:2]/C).astype(int)
 if np.any(abs(k[:,1])>=50000):raise ValueError('signed-key injectivity not established')
 key=k[:,0]*100000+k[:,1];order=np.argsort(key);key=key[order];Q=Q[order]
 u,st,cnt=np.unique(key,return_index=True,return_counts=True);accepted=[];zmed=[];counts=[];nearcounts=[]
 for kk,s0,n in zip(u,st,cnt):
  if n<300:continue
  z=Q[s0:s0+n,2];h,e=np.histogram(z,bins=np.arange(z0-.12,z0+.12,.005));m=e[np.argmax(h)]+.0025;near=z[np.abs(z-m)<.06]
  if len(near)<200:continue
  accepted.append(kk);zmed.append(np.median(near));counts.append(n);nearcounts.append(len(near))
 keys=np.asarray(accepted,dtype=np.int64)
 old=np.c_[decode(keys,False)*C+C/2,np.asarray(zmed)]
 fixed=np.c_[decode(keys,True)*C+C/2,np.asarray(zmed)]
 if len(old)<3 or np.linalg.matrix_rank(np.c_[fixed[:,:2],np.ones(len(fixed))])!=3:raise ValueError('fit rank')
 return old,fixed,keys,np.array(counts),np.array(nearcounts),hist,edges,float(z0),int(len(Q))

def summary(a):
 a=np.asarray(a)
 return {'n':int(a.size),'min':float(a.min()),'p05_p50_p95':np.percentile(a,[5,50,95]).tolist(),'max':float(a.max()),'mean':float(a.mean()),'std':float(a.std()),'maxAbs':float(abs(a).max())}

def fixture_checks(env):
 keys=np.array([0,100001,-1,-100001,100000-1,-100000+1],np.int64)
 expect=np.array([[0,0],[1,1],[0,-1],[-1,-1],[1,-1],[-1,1]])
 if not np.array_equal(decode(keys,True),expect):raise AssertionError('signed decode fixture')
 if not np.array_equal(decode(keys,True)[:,0]-decode(keys,False)[:,0],(expect[:,1]<0).astype(int)):raise AssertionError('one-cell shift fixture')
 d=np.arange(16*20,dtype=np.uint16).reshape(16,20)*11
 f={'depth_file_path':'./ignored','cx':8.2,'cy':7.3,'fl_x':21.,'fl_y':19.,'transform_matrix':[[1,0,0,.17],[0,0,-1,.4],[0,1,0,-.8],[0,0,0,1]]}
 prior=env['Image'];env['Image']=SimpleNamespace(open=lambda _:d)
 try:p=env['lidar_samples']('/ignored',[f])[0]
 finally:env['Image']=prior
 if not np.array_equal(p,project(d,f)):raise AssertionError('exact original projection fixture')
 return 3

def main(out,expected):
 frozen=HERE/'FROZEN.json'
 if sha(frozen)!=expected:raise ValueError('frozen SHA mismatch before parse')
 pins=json.loads(frozen.read_text())['files']
 def check():
  for rel,h in pins.items():
   if sha(WS/rel)!=h:raise ValueError('input/source changed: '+rel)
 check();out=Path(out);out.mkdir(exist_ok=False)
 env=source_functions();fixtures=fixture_checks(env)
 frames=json.loads(POSE.read_text())['frames'];manifest=json.loads(MANIFEST.read_text())
 if len(frames)!=294 or len(manifest['files'])!=294 or manifest['poseSHA256']!=sha(POSE):raise ValueError('294 frame association')
 cams=np.array([f['transform_matrix']for f in frames])[:,:3,3];zc=np.median(cams[:,2]);chunks=[];counts=[]
 for fi,(f,e)in enumerate(zip(frames,manifest['files'])):
  if e['poseIndex']!=fi or Path(f['depth_file_path']).name!=e['file'] or Path(e['file']).name!=e['file']:raise ValueError('depth path association')
  raw=(DEPTH/e['file']).read_bytes()
  if len(raw)!=e['bytes'] or hashlib.sha256(raw).hexdigest()!=e['sha256']:raise ValueError('depth bytes')
  with Image.open(BytesIO(raw))as im:dep=np.asarray(im)
  if dep.shape!=(994,738)or dep.dtype!=np.uint16:raise ValueError('depth raster')
  p=project(dep,f)
  if not np.isfinite(p).all():raise ValueError('nonfinite source point')
  use=(p[:,2]>zc-2.6)&(p[:,2]<zc-.4);chunks.append(p[use]);counts.append({'poseIndex':fi,'sourcePositiveSamples':len(p),'floorSearchSamples':int(use.sum())})
  if fi%50==0:print(json.dumps({'phase':'source_samples','frame':fi}),flush=True)
 # Stream only points the source's FIRST floor-search predicate retains. That
 # predicate is repeated unchanged by both fits; removed points cannot enter rows.
 P=np.concatenate(chunks);del chunks
 old,fixed,keys,ns,nnear,hist,edges,z0,band_count=rows_from_source(P,cams)
 ko,Ro,to,eo=plane(old);kf,Rf,tf,ef=plane(fixed)
 oracleR,oraclet=env['level_frame'](P,cams);del P
 if not np.array_equal(Ro,oracleR)or not np.array_equal(to,oraclet):raise ValueError('row reconstruction differs from original source function')
 with np.load(META,allow_pickle=False)as z:Rs=z['R'];ts=z['t'];lo=z['lo'];res=float(z['res'])
 with np.load(MASK,allow_pickle=False)as z:shape=z['walk'].shape
 if res!=.05 or shape!=(241,250):raise ValueError('fixed map extent')
 deltaR=float(abs(Ro-Rs).max());deltat=float(abs(to-ts).max());matches=deltaR<=MATCH_ATOL and deltat<=MATCH_ATOL
 # FIXED original level-grid plane points, not changed cell assignment. This is
 # the correction's height shift at the same nominal physical points, not floor truth.
 ij=np.indices(shape).reshape(2,-1).T;xy=(ij+lo[:2]+.5)*res
 original_level=np.c_[xy,np.zeros(len(xy))];phone=(original_level-ts)@Rs
 oldh=phone@Ro[2]+to[2];newh=phone@Rf[2]+tf[2];shift=newh-oldh
 corners=np.array([[lo[0]*res,lo[1]*res],[(lo[0]+shape[0])*res,lo[1]*res],[(lo[0]+shape[0])*res,(lo[1]+shape[1])*res],[lo[0]*res,(lo[1]+shape[1])*res]])
 cp=(np.c_[corners,np.zeros(4)]-ts)@Rs
 corner_shift=(cp@Rf[2]+tf[2])-(cp@Ro[2]+to[2])
 roi=json.loads(ROI.read_text());cells=np.unique(np.array([r['sourceIJ']for r in roi['rows']],np.int64),axis=0);western=[]
 for i,j in cells:
  if not(0<=i<shape[0]and 0<=j<shape[1]):raise ValueError('ROI outside fixed map')
  q=i*shape[1]+j
  western.append({'sourceIJ':[int(i),int(j)],'sourceCellCentreXY':xy[q].tolist(),'oldHeight':float(oldh[q]),'correctedHeight':float(newh[q]),'heightShiftMetres':float(shift[q]),'cameraFrameRecords':[r['frameIndex1Based']for r in roi['rows']if r['sourceIJ']==[int(i),int(j)]]})
 np.savez_compressed(out/'FLOOR_ROWS.npz',signedKeys=keys,originalRows=old,correctedRows=fixed,sourceCellSampleCounts=ns,nearModeSampleCounts=nnear,globalHistogram=hist,globalHistogramEdges=edges,originalCoefficients=ko,correctedCoefficients=kf,originalR=Ro,originalT=to,correctedR=Rf,correctedT=tf)
 np.savez_compressed(out/'FIXED_MAP_HEIGHT_SHIFTS.npz',sourceIJ=ij.astype(np.int16),sourceXY=xy,originalHeight=oldh,correctedHeight=newh,heightShift=shift,lo=lo,res=res)
 def fit(k,R,t,e):return {'planeZEqualsAxPlusByPlusC':k.tolist(),'tiltDegrees':float(np.degrees(np.arctan(np.hypot(k[0],k[1])))),'R':R.tolist(),'t':t.tolist(),'rowVerticalResidualMetres':summary(e)}
 physical_old=fixed[:,2]-np.c_[fixed[:,:2],np.ones(len(fixed))]@ko
 result={'scope':'Signed-key floor row X decoding only; no fusion, map changes, routes, reference, or physical floor labels.','causalForSuppliedTransform':bool(matches),'suppliedTransformMatch':{'absoluteTolerance':MATCH_ATOL,'maxAbsRDelta':deltaR,'maxAbsTDelta':deltat,'originalSourceFunctionBitwiseEqualToRowReconstruction':True},'fixturesPassed':fixtures,'frames':counts,'sourceSamples':sum(r['sourcePositiveSamples']for r in counts),'floorSearchSamples':sum(r['floorSearchSamples']for r in counts),'floorPeakZ':z0,'floorPeakBandSamples':band_count,'floorRows':len(old),'rowsWithCorrectedX':int((old[:,0]!=fixed[:,0]).sum()),'correction':'signedY=key%100000; if signedY>=50000: signedY-=100000; x=(key-signedY)//100000. Only row X changed; all source grouping, medians, Y/Z, thresholds and least-squares algorithm unchanged.','original':fit(ko,Ro,to,eo),'corrected':fit(kf,Rf,tf,ef),'originalPlaneResidualAtCorrectDecodedXY':summary(physical_old),'coefficientDelta':(kf-ko).tolist(),'fixedMapNominalPlaneHeightShiftMetres':summary(shift),'mapExtentCornerXY':corners.tolist(),'mapExtentCornerHeightShiftMetres':corner_shift.tolist(),'westernUniqueCells':len(western),'westernCameraRecords':len(roi['rows']),'westernHeightShiftMetres':summary(np.array([r['heightShiftMetres']for r in western])),'westernCells':western,'runtime':{'numpy':np.__version__,'Pillow':PIL.__version__,'Python':sys.version},'limitations':['Height shifts evaluate the same supplied-map nominal plane points, not measured floor elevations or recomputed cell assignments.','If the original recomputed R/t does not match supplied R/t within the predeclared tolerance, effects are isolated source-reconstruction effects, not causal attribution of the supplied map.','This does not determine a correct local floor, uncertainty, low-obstacle labels, or physical passage.','No native fusion or navigation was rerun.']}
 check()
 # Every original depth is rehashed after computation, not only its manifest.
 for e in manifest['files']:
  if sha(DEPTH/e['file'])!=e['sha256']:raise ValueError('depth changed after')
 result['sourceAnd294DepthHashesVerifiedBeforeAfter']=True
 with (out/'RESULT.json').open('x')as f:json.dump(result,f,indent=2,allow_nan=False);f.write('\n')
 print(json.dumps({k:result[k]for k in ('causalForSuppliedTransform','suppliedTransformMatch','floorRows','rowsWithCorrectedX','coefficientDelta','fixedMapNominalPlaneHeightShiftMetres','westernHeightShiftMetres')}),flush=True)
if __name__=='__main__':main(sys.argv[1],sys.argv[2])
