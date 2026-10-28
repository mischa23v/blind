"""Prepared comparison; run only under an authorized single-CPU RSS/wall supervisor."""
import os
for key in ('OMP_NUM_THREADS','OPENBLAS_NUM_THREADS','MKL_NUM_THREADS'): os.environ[key]='1'
from pathlib import Path
import json,hashlib,argparse,sys,time
import numpy as np
import vtk
from vtk.util.numpy_support import vtk_to_numpy,numpy_to_vtk
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
FRESH=ROOT/'research/open3d-same-data-benchmark-20261028/fresh-run'
sys.path.insert(0,str(FRESH/'source'))
from reference_geometry import ReferenceSurface,checked_similarity,serial_vtk,plane_mesh

def sha(p):
 h=hashlib.sha256()
 with open(p,'rb') as f:
  for b in iter(lambda:f.read(1048576),b''):h.update(b)
 return h.hexdigest()
def dump(p,x):p.write_text(json.dumps(x,indent=2,sort_keys=True)+'\n')
def verify(pins):
 for p,h in pins.items():
  if sha(p)!=h:raise RuntimeError('pin changed: '+p)
def registered(p,a):return p@a[:3,:3].T+a[:3,3]
def sample(p,side=.04):
 # Real point representatives, not voxel centroids or voxel centres.
 if p.ndim!=2 or p.shape[1]!=3 or not np.isfinite(p).all():raise RuntimeError('invalid point input')
 if len(p)==0:raise RuntimeError('empty input')
 key=np.floor(p/side).astype(np.int64)
 centre=(key+.5)*side;d=np.sum((p-centre)**2,axis=1)
 order=np.lexsort((p[:,2],p[:,1],p[:,0],d,key[:,2],key[:,1],key[:,0]))
 k=key[order];take=np.r_[True,np.any(k[1:]!=k[:-1],axis=1)]
 return p[order[take]].copy()
def read_points(path):
 r=vtk.vtkPLYReader();errors=[];r.AddObserver('ErrorEvent',lambda *x:errors.append(str(x)))
 r.SetFileName(str(path));r.Update()
 if errors or r.GetOutput().GetNumberOfPoints()==0:raise RuntimeError('PLY read error '+str(errors))
 return vtk_to_numpy(r.GetOutput().GetPoints().GetData()).astype(np.float64,copy=True)
def summary(d):
 finite=np.isfinite(d);v=d[finite]
 return {'scheduled':len(d),'valid':int(finite.sum()),'invalid':int((~finite).sum()),
 'meanMetres':float(np.mean(v)) if len(v) else None,
 'medianMetres':float(np.median(v)) if len(v) else None,
 'p95Metres':float(np.percentile(v,95)) if len(v) else None,
 'p99Metres':float(np.percentile(v,99)) if len(v) else None,
 'maxMetres':float(np.max(v)) if len(v) else None,
 'within':{str(t):{'count':int(np.sum(v<=t)),'fractionOfScheduled':float(np.sum(v<=t)/len(d))} for t in (.02,.05,.1,.2,.5)}}
def closest_surface(surface,points):
 cp=[0.,0.,0.];cid=vtk.reference(-1);sub=vtk.reference(-1);dist=vtk.reference(float('nan'));cell=vtk.vtkGenericCell()
 distances=np.full(len(points),np.nan);ids=np.full(len(points),-1,dtype=np.int64)
 for i,p in enumerate(points):
  cid.set(-1);dist.set(float('nan'))
  surface.locator.FindClosestPoint(p.tolist(),cp,cell,cid,sub,dist)
  if surface.errors:raise RuntimeError(str(surface.errors))
  if not(0<=int(cid)<surface.mesh.GetNumberOfCells()) or not np.isfinite(float(dist)) or float(dist)<0:raise RuntimeError('invalid closest triangle query')
  geometric=np.linalg.norm(p-np.asarray(cp))
  if abs(geometric**2-float(dist))>1e-8*max(1.,float(dist)):raise RuntimeError('closest squared-distance mismatch')
  distances[i]=np.sqrt(float(dist));ids[i]=int(cid)
  if i%4096==0:print(json.dumps({'phase':'forward','done':i,'total':len(points)}),flush=True)
 return distances,ids

def reference_samples(a):
 manifest=json.loads((FRESH/'EVALUATOR_FROZEN.json').read_text());frames=json.loads((FRESH/'inputs/room_datasets/koivu/iphone/long_capture/transformations.json').read_text())['frames'];by={Path(f['file_path']).stem:f for f in frames}
 parts=[];scheduled=missing=0
 for name in manifest['frameIDs']:
  f=by[name]
  with np.load(FRESH/'evaluation/faro'/(name+'.npz')) as z:
   d=z['axialMetres'];ok=np.isfinite(d);scheduled+=len(d);missing+=int((~ok).sum())
   if np.any(d[ok]<=0):raise RuntimeError('invalid axial depth')
   rays=np.column_stack(((z['column'][ok]-f['cx'])/f['fl_x'],-(z['row'][ok]-f['cy'])/f['fl_y'],-np.ones(ok.sum())))
   pose=np.asarray(f['transform_matrix']);phone=(rays*d[ok,None])@pose[:3,:3].T+pose[:3,3]
   parts.append(registered(phone,a))
 points=np.concatenate(parts)
 return sample(points),{'scheduledOriginalRays':scheduled,'missingReferenceRaysExcludedButNotFree':missing,'finiteOriginalReferenceHits':len(points)}
def closest_points(points,queries):
 poly=vtk.vtkPolyData();vp=vtk.vtkPoints();vp.SetData(numpy_to_vtk(points,deep=True));poly.SetPoints(vp)
 loc=vtk.vtkStaticPointLocator();loc.SetDataSet(poly);loc.BuildLocator();d=np.empty(len(queries))
 for i,q in enumerate(queries):
  idx=loc.FindClosestPoint(q.tolist())
  if not 0<=idx<len(points):raise RuntimeError('invalid point locator result')
  d[i]=np.linalg.norm(q-points[idx])
 return d

def fixtures():
 # Analytic fixtures only; no recorded data queries.
 p=np.array([[.001,.001,.001],[.019,.02,.02],[.021,.02,.02],[-.001,0.,0.],[-.039,0.,0.]])
 s=sample(p);assert len(s)==2 and np.allclose(s[1],[.019,.02,.02])
 assert np.array_equal(s,sample(p[::-1]))
 surf=ReferenceSurface(plane_mesh([-2.]));d,_=closest_surface(surf,np.array([[0.,0.,-1.5],[0.,0.,-2.], [0.,0.,-3.]]));assert np.allclose(d,[.5,0.,1.])
 a=np.eye(4);a[:3,:3]*=2.;a[:3,3]=[1.,2.,3.]
 assert np.allclose(registered(np.array([[1.,2.,3.]]),a),[[3.,6.,9.]])
 assert np.allclose(closest_points(np.array([[0.,0.,0.],[2.,0.,0.]]),np.array([[.5,0.,0.],[2.,0.,0.]])),[.5,0.])
 return {'passed':True,'recordedQueries':0}

def main(args):
 os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});runtime=serial_vtk()
 frozen=HERE/'FROZEN.json'
 if sha(frozen)!=args.expected_freeze:raise RuntimeError('unexpected protocol hash')
 protocol=json.loads(frozen.read_text());verify(protocol['pins'])
 launch=json.loads(Path(args.inputs).read_text());verify(launch['pins'])
 if launch['protocolSHA256']!=args.expected_freeze:raise RuntimeError('launch protocol mismatch')
 out=Path(args.out);out.mkdir(parents=True,exist_ok=False)
 dump(out/'FIXTURES.json',fixtures())
 a,check=checked_similarity(np.asarray(json.loads((FRESH/'inputs/room_datasets/koivu/icp_iphone.json').read_text())['gt_transformation']))
 refs,refmeta=reference_samples(a);np.save(out/'reference_samples_faro_metres.npy',refs)
 # Read FARO once, no transformation, cleaning, smoothing, or triangulation.
 errors=[];reader=vtk.vtkPLYReader();reader.AddObserver('ErrorEvent',lambda *x:errors.append(str(x)));reader.SetFileName(str(FRESH/'inputs/room_datasets/koivu/gt_mesh.ply'));reader.Update()
 if errors:raise RuntimeError(str(errors))
 mesh=reader.GetOutput()
 if mesh.GetNumberOfCells()!=mesh.GetNumberOfPolys() or mesh.GetPolys().IsHomogeneous()!=3:raise RuntimeError('reference must contain original triangles only; no triangulation permitted')
 mesh.GetPointData().Initialize();mesh.GetCellData().Initialize()
 surface=ReferenceSurface(mesh,progress=lambda x:print(json.dumps(x),flush=True))
 results={}
 for label,path in launch['clouds'].items():
  if path not in launch['pins']:raise RuntimeError('unpinned cloud')
  raw=read_points(path);p=sample(registered(raw,a));count=len(raw);del raw
  d,ids=closest_surface(surface,p);reverse=closest_points(p,refs)
  target=out/(label+'.npz');np.savez_compressed(target,pointsFaroMetres=p,forwardDistanceMetres=d,referenceCellID=ids,reverseReferencePointDistanceMetres=reverse)
  results[label]={'rawOutputPointCount':count,'common4cmPointCount':len(p),'forwardUnsignedPointToReferenceTriangle':summary(d),'reverseVisibleReferenceToSampledOutputPoint':summary(reverse),'arraySHA256':sha(target)}
 verify(protocol['pins']);verify(launch['pins'])
 dump(out/'RESULT.json',{'status':'completed','runtime':runtime,'protocolSHA256':args.expected_freeze,'launchSHA256':sha(args.inputs),'registration':check,'referenceSampling':refmeta,'reference4cmPointCount':len(refs),'referenceSamplesSHA256':sha(out/'reference_samples_faro_metres.npy'),'results':results,'physicalSafetyEstablished':False,'missingReferenceMeansFree':False,'surfaceReconstructionPerformed':False})
if __name__=='__main__':
 ap=argparse.ArgumentParser();ap.add_argument('--inputs',required=True);ap.add_argument('--out',required=True);ap.add_argument('--expected-freeze',required=True);main(ap.parse_args())
