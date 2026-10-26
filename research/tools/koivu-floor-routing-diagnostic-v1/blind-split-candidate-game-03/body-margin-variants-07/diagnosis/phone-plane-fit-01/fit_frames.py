"""Released Open3D per-view plane-fit diagnostic; no mapper/route adoption."""
from pathlib import Path
from io import BytesIO
import hashlib,json,math,sys,importlib
import numpy as np
from PIL import Image
from scipy.spatial import ConvexHull,QhullError
HERE=Path(__file__).resolve().parent;DIAG=HERE.parent;GAME=DIAG.parents[1];WS=GAME.parent
ENV=WS/'blind-open3d-author-baseline-10/environment/target'
sys.path.insert(0,str(ENV));sys.path.insert(0,str(DIAG))
import open3d as o3d
import western_depth_residuals as wd
PARAMS={'floorCandidateAbsHeightMetres':.12,'floorCandidateMaximumCameraRangeMetres':4.,'distanceThresholdMetres':.01,'ransacN':3,'numIterations':1000,'probability':.99999999,'seedResetEachFrame':0,'minimumInliers':100,'minimumInlierFraction':.5,'maximumTiltDegrees':5.,'minimumHorizontalHullAreaSquareMetres':.25,'minimumHorizontalPrincipalSpanMetres':.1}

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def stats(x):
 x=np.asarray(x)
 return {'n':len(x),'p05_p50_p95Metres':np.percentile(x,[5,50,95]).tolist()if len(x)else None,'minMetres':float(x.min())if len(x)else None,'maxMetres':float(x.max())if len(x)else None}
def fit(points):
 if len(points)<PARAMS['minimumInliers']:return {'valid':False,'reason':'tooFewCandidates','candidates':len(points)},None
 cloud=o3d.geometry.PointCloud(o3d.utility.Vector3dVector(np.asarray(points,dtype=np.float64)))
 o3d.utility.random.seed(PARAMS['seedResetEachFrame'])
 try:plane,inliers=cloud.segment_plane(distance_threshold=PARAMS['distanceThresholdMetres'],ransac_n=3,num_iterations=1000,probability=PARAMS['probability'])
 except RuntimeError as e:return {'valid':False,'reason':'nativeFitUnavailable','candidates':len(points),'nativeMessage':str(e)},None
 plane=np.asarray(plane,dtype=np.float64);idx=np.asarray(inliers)
 if plane.shape!=(4,)or not np.isfinite(plane).all()or np.linalg.norm(plane[:3])<=1e-12:
  return {'valid':False,'reason':'degenerateNativePlane','candidates':len(points)},None
 if idx.ndim!=1 or (idx.size and idx.dtype.kind not in 'iu')or np.any(idx<0)or np.any(idx>=len(points))or len(np.unique(idx))!=len(idx):
  return {'valid':False,'reason':'invalidNativeInlierIndices','candidates':len(points)},None
 plane/=np.linalg.norm(plane[:3])
 if plane[2]<0:plane=-plane
 idx=idx.astype(np.int64);q=points[idx];fraction=len(idx)/len(points)
 tilt=float(np.degrees(np.arccos(np.clip(plane[2],-1.,1.))))
 area=0.;span=0.
 if len(q)>=3:
  xy=q[:,:2];_,_,vh=np.linalg.svd(xy-xy.mean(0),full_matrices=False)
  spans=np.ptp((xy-xy.mean(0))@vh.T,axis=0);span=float(spans.min())
  try:area=float(ConvexHull(xy).volume)
  except QhullError:pass
 reasons=[]
 if len(idx)<100:reasons.append('tooFewInliers')
 if fraction<.5:reasons.append('minorityPlane')
 if tilt>5.:reasons.append('notLevel')
 if area<.25 or span<.1:reasons.append('insufficient2DCoverage')
 residual=points@plane[:3]+plane[3]
 return {'valid':not reasons,'reason':'ok'if not reasons else'+'.join(reasons),'candidates':len(points),'inliers':len(idx),'inlierFraction':fraction,'planeABCD':plane.tolist(),'tiltDegrees':tilt,'horizontalHullAreaSquareMetres':area,'minimumHorizontalPrincipalSpanMetres':span,'candidateSignedResidual':stats(residual),'inlierSignedResidual':stats(residual[idx]),'inliersAreNotClearance':True},plane

def run(out,expected):
 if sha(HERE/'FROZEN.json')!=expected:raise ValueError('freeze changed')
 frozen=json.loads((HERE/'FROZEN.json').read_text())
 def check():
  for p,h in frozen['files'].items():
   if sha(WS/p)!=h:raise ValueError('source/input changed: '+p)
 check()
 prior=json.loads((WS/'blind-open3d-author-baseline-10/koivu/RECOVERED_RESULT.json').read_text())
 modules={}
 for name,old in prior['modules'].items():
  m=importlib.import_module(name);p=Path(m.__file__).resolve();h=sha(p)
  if h!=old['sha256']:raise ValueError('previous verified module differs: '+name)
  modules[name]={'path':str(p),'sha256':h}
 if o3d.__version__!='0.19.0':raise ValueError('Open3D version')
 out=Path(out);out.mkdir(exist_ok=False)
 frames=json.loads(wd.POSE.read_text())['frames'];manifest=json.loads((wd.DEPTH/'DEPTH_INPUT_MANIFEST.json').read_text());roi=json.loads(wd.ROI.read_text())
 if len(frames)!=294 or len(manifest['files'])!=294:raise ValueError('fixed294-frame association')
 with np.load(wd.META,allow_pickle=False)as z:R=z['R'];t=z['t'];lo=z['lo'];res=float(z['res'])
 with np.load(wd.MASK,allow_pickle=False)as z:flags={k:z[k]for k in wd.KEYS}
 wd.verify_roi(roi['rows'],frames,R,t,lo,res,flags)
 cells=np.unique(np.asarray([r['sourceIJ']for r in roi['rows']],dtype=int),axis=0);H,W=flags['walk'].shape
 wanted=np.zeros(H*W,bool);wanted[cells[:,0]*W+cells[:,1]]=True
 rows=[];chunks=[]
 for fi,(f,e)in enumerate(zip(frames,manifest['files'])):
  raw=(wd.DEPTH/e['file']).read_bytes()
  if hashlib.sha256(raw).hexdigest()!=e['sha256']or fi!=e['poseIndex']or Path(f['depth_file_path']).name!=e['file']:raise ValueError('source association')
  with Image.open(BytesIO(raw))as im:dep=np.asarray(im)
  if dep.shape!=(994,738)or dep.dtype!=np.uint16:raise ValueError('source raster')
  p,rr,cc,mm,jump=wd.project(dep,f);level=p@R.T+t;cam=np.asarray(f['transform_matrix'])[:3,3]
  ranges=np.linalg.norm(p.astype(np.float64)-cam,axis=1)
  candidate=(abs(level[:,2])<=.12)&(ranges<=4.)
  info,plane=fit(level[candidate]);info.update(poseIndex=fi,frameID=Path(f['depth_file_path']).stem,sourceSamples=len(p),excludedCandidateSamples=int((~candidate).sum()))
  ij=np.floor(level[:,:2]/res).astype(int)-lo[:2];inside=(ij[:,0]>=0)&(ij[:,0]<H)&(ij[:,1]>=0)&(ij[:,1]<W)
  selected=np.zeros(len(p),bool);selected[inside]=wanted[ij[inside,0]*W+ij[inside,1]];q=np.flatnonzero(selected)
  residual=np.full(len(q),np.nan)if plane is None else level[q]@plane[:3]+plane[3]
  localheight=np.full(len(q),np.nan)if plane is None or abs(plane[2])<1e-12 else -(level[q,0]*plane[0]+level[q,1]*plane[1]+plane[3])/plane[2]
  chunks.append({'frame':np.full(len(q),fi,np.uint16),'i':ij[q,0].astype(np.int16),'j':ij[q,1].astype(np.int16),'row':rr[q].astype(np.uint16),'col':cc[q].astype(np.uint16),'depthMM':mm[q],'range':ranges[q],'globalHeight':level[q,2],'fitSignedResidual':residual,'fittedPlaneHeight':localheight,'fitValid':np.full(len(q),info['valid'],bool)})
  info['westernCellEndpoints']=len(q)
  info['westernEndpointGlobalHeight']=stats(level[q,2]);info['westernEndpointFitResidual']=stats(residual[np.isfinite(residual)])
  rows.append(info)
  if fi%30==0:print(json.dumps({'phase':'fit','poseIndex':fi,'valid':info['valid']}),flush=True)
 data={k:np.concatenate([c[k]for c in chunks])for k in chunks[0]}
 cellrows=[]
 for i,j in cells:
  use=(data['i']==i)&(data['j']==j);valid=use&data['fitValid'];near=valid&(data['range']<=2)&(abs(data['globalHeight'])<=.1)
  cellrows.append({'sourceIJ':[int(i),int(j)],'phoneFlags':{k:bool(flags[k][i,j])for k in wd.KEYS},'allEndpointCount':int(use.sum()),'validPlaneEndpointCount':int(valid.sum()),'conditionalNearAbsGlobalHeightBelow10cm':{'globalHeight':stats(data['globalHeight'][near]),'fittedPlaneHeight':stats(data['fittedPlaneHeight'][near]),'signedResidual':stats(data['fitSignedResidual'][near])},'validViewSignedResidualAllHeights':stats(data['fitSignedResidual'][valid])})
 check()
 for name,m in modules.items():
  if sha(m['path'])!=m['sha256']:raise ValueError('loaded module changed')
 result={'scope':'Phone-only all-frame plane-fit comparison, no map edit, no automatic clearing or navigation','parameters':PARAMS,'frames':rows,'westernCells':cellrows,'validFrames':sum(r['valid']for r in rows),'invalidFrames':sum(not r['valid']for r in rows),'affectedPoseIndicesPredeclared':[61,62,63],'affectedOriginalFrameIDs':[Path(frames[i]['depth_file_path']).stem for i in [61,62,63]],'fixedRegularControlsPoseIndex':[0,41,83,125,167,209,251,293],'all294FramesReported':True,'nativeGridDuplicateHandling':'Original source stride selects one pixel from each complete 4x4 exported-depth block; no voxel deduplication, no point-centre substitution and no across-frame merging. Distinct views are not statistically independent.','originalConfidence':'unavailable','tracking':'unavailable','modules':modules,'physicalAuthority':False,'mapperAdopted':False,'FAROUsed':False,'limitations':['The +/-12cm candidate band presumes a level-room floor near the supplied plane; this is not general stair or multilevel segmentation.','The1cm RANSAC estimation tolerance is not a clearance threshold. Inliers and residuals, including possible1cm toys, remain raw unresolved evidence.','Plane hull area is estimation support only; it does not fill holes or establish walkable support anywhere.','Plane differences can be depth/pose/export disagreement or actual nonlevel surfaces. No poses or endpoints are shifted.','All raw endpoints/source masks are preserved; this fit output produces no walk mask.']}
 np.savez_compressed(out/'WESTERN_ENDPOINT_PLANE_RESIDUALS.npz',**data)
 (out/'RESULT.json').write_text(json.dumps(result,indent=2,allow_nan=False)+'\n')
 print(json.dumps({'validFrames':result['validFrames'],'invalidFrames':result['invalidFrames'],'affectedFrames':[rows[i]for i in [61,62,63]]}),flush=True)
if __name__=='__main__':run(sys.argv[1],sys.argv[2])
