"""Fixed held-out processed-depth consistency check; not physical truth or navigation."""
from pathlib import Path
import argparse, hashlib, json, math, os, resource, sys, time
import numpy as np
from PIL import Image, __version__ as PIL_VERSION
import vtk
from vtk.util.numpy_support import vtk_to_numpy
ROOT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT.parent/'blind-koivu-reference-comparison-06'))
from reference_geometry import ReferenceSurface, checked_camera, serial_vtk, plane_mesh, GeometryFailure
RANGES=['positive_below015','015_to_below1','1_to_below2','2_to_below3','3_to_below4','4_to_below5','5_and_above']
EDGES={-1:'missing_centre',0:'scheduled_raster_boundary',1:'missing_neighbour',2:'delta_le_002',3:'delta_gt002_le010',4:'delta_gt010'}

def dump(path,obj):path.write_text(json.dumps(obj,indent=2,sort_keys=True,allow_nan=False)+'\n')
def digest(path):
 h=hashlib.sha256()
 with Path(path).open('rb') as f:
  for b in iter(lambda:f.read(1<<20),b''):h.update(b)
 return h.hexdigest()
def rays(rows,cols,fx,fy,cx,cy):
 vals=np.asarray([fx,fy,cx,cy],float)
 if not np.isfinite(vals).all() or fx<=0 or fy<=0:raise GeometryFailure('invalid K')
 r=np.asarray(rows,float);c=np.asarray(cols,float)
 if r.shape!=c.shape or not np.isfinite(r).all() or not np.isfinite(c).all():raise GeometryFailure('invalid pixels')
 return np.column_stack(((c-cx)/fx,-(r-cy)/fy,-np.ones(r.size)))
def edges(z):
 z=np.asarray(z);v=np.isfinite(z)&(z>0);e=np.full(z.shape,-1,np.int8)
 e[v]=0
 if min(z.shape)<3:return e
 core=z[1:-1,1:-1];cv=v[1:-1,1:-1]
 n=np.stack((z[:-2,1:-1],z[2:,1:-1],z[1:-1,:-2],z[1:-1,2:]))
 nv=(np.isfinite(n)&(n>0)).all(0)
 delta=np.max(np.abs(n-core),axis=0)
 ce=e[1:-1,1:-1];ce[cv&~nv]=1
 ce[cv&nv&(delta<=.02)]=2;ce[cv&nv&(delta>.02)&(delta<=.10)]=3;ce[cv&nv&(delta>.10)]=4
 return e

def stats(v):
 v=np.asarray(v,np.float64);a=np.abs(v);result={'count':int(v.size)}
 fields=['meanSigned','signedP05','signedP50','signedP95','MAE','absoluteP50','absoluteP90','absoluteP95','absoluteP99','maximumAbsolute']
 if not v.size:return dict(result,**{k:None for k in fields})
 if not np.isfinite(v).all():raise GeometryFailure('nonfinite paired error')
 q=np.quantile(v,[.05,.5,.95],method='linear');aq=np.quantile(a,[.5,.9,.95,.99],method='linear')
 return dict(result,**dict(zip(fields,map(float,[v.mean(),*q,a.mean(),*aq,a.max()]))))
def masks(z):return [(z>0)&(z<.15),(z>=.15)&(z<1),(z>=1)&(z<2),(z>=2)&(z<3),(z>=3)&(z<4),(z>=4)&(z<5),z>=5]
def summarize(raw,pred,es,ep):
 raw=np.asarray(raw);pred=np.asarray(pred);z=raw.astype(np.float64)*.001
 sv=z>0;mv=np.isfinite(pred)&(pred>0);domain=sv&(z<4);outside=z>=4;pair=sv&mv;primary=domain&mv;error=pred-z
 state=np.where(~sv,0,np.where(domain,1,2))
 cross=[[int(((state==i)&(mv==bool(j))).sum())for j in range(2)]for i in range(3)]
 assert sum(map(sum,cross))==raw.size
 groups={'scheduled':int(raw.size),'sensorStateByMeshNoHitHit':cross,'sensorStateNames':['zero_missing','positive_below4','positive_4_and_above'],'meshColumns':['no_hit','hit'],'bothPositive':int(pair.sum()),'sensorOnly':int((sv&~mv).sum()),'meshOnly':int((~sv&mv).sum()),'neither':int((~sv&~mv).sum())}
 assert sum(groups[k]for k in ['bothPositive','sensorOnly','meshOnly','neither'])==raw.size
 def subset(m):return {'scheduled':int(m.sum()),'meshHit':int((m&mv).sum()),'primaryStatistics':stats(error[m&primary]),'allPositiveStatistics':stats(error[m&pair])}
 range_result=[{'label':label,**subset(m)}for label,m in zip(RANGES,masks(z))]
 assert sum(x['scheduled']for x in range_result)==int(sv.sum())
 edge_results={}
 for name,e in [('heldoutSensor',es),('predictedMesh',ep)]:
  if not np.isin(e,list(EDGES)).all():raise GeometryFailure('invalid edge class')
  edge_results[name]=[{'label':label,'code':code,**subset(e==code)}for code,label in EDGES.items()]
  assert sum(x['scheduled']for x in edge_results[name])==raw.size
 return {'availability':groups,'primaryStatistics':stats(error[primary]),'allPositiveStatistics':stats(error[pair]),'outOfDomainStatistics':stats(error[outside&mv]),'bySensorDepth':range_result,'byEdge':edge_results}

def conventions():
 runtime=serial_vtk();tests=[]
 ray=rays(np.array([45]),np.array([60]),100,100,50,40)
 assert np.allclose(ray[0]*2,[.2,-.1,-2],rtol=0,atol=1e-14)
 assert abs(100*(ray[0,0]/-ray[0,2])+50-60)<1e-12
 assert abs(100*(-ray[0,1]/-ray[0,2])+40-45)<1e-12
 tests.append({'name':'integer_asymmetric_projection_backprojection','passed':True})
 for reverse in [False,True]:
  d,ids,_=ReferenceSurface(plane_mesh([-2,-4,-1],reverse=reverse)).query(np.eye(4),np.eye(4),ray)
  assert abs(d[0]-1)<1e-10 and ids[0] in (4,5)
  tests.append({'name':'nearest_unsorted_reverse_'+str(reverse),'passed':True})
 c=np.eye(4);th=.31;c[:3,:3]=[[np.cos(th),0,np.sin(th)],[0,1,0],[-np.sin(th),0,np.cos(th)]];c[:3,3]=[.4,-.3,.2]
 surface=ReferenceSurface(plane_mesh([-2,-4],c));d,_,_=surface.query(c,np.eye(4),ray)
 assert abs(d[0]-2)<1e-10 and np.linalg.norm(ray[0]*2)>2
 tests.append({'name':'pose_inverse_axial_not_range','passed':True})
 surface=ReferenceSurface(plane_mesh([-2,-4]));d,ids,_=surface.query(np.eye(4),np.eye(4),np.array([[100.,0.,-1.],[0.,0.,1.]]))
 assert np.isnan(d).all() and (ids==-1).all()
 tests.append({'name':'no_hit_and_backward_ray_retained','passed':True})
 raw=np.array([[0,1000,4000],[5000,1000,0]],np.uint16);pred=np.array([[2.,5.,3.],[np.nan,np.nan,np.nan]])
 a=summarize(raw,pred,edges(raw*.001),edges(pred));assert a['availability']['sensorStateByMeshNoHitHit']==[[1,1],[1,1],[1,1]]
 assert a['primaryStatistics']['count']==1 and a['primaryStatistics']['meanSigned']==4 and a['outOfDomainStatistics']['meanSigned']==-1
 tests.append({'name':'all_six_categories_and_prediction_above4_preserved','passed':True})
 z=np.ones((5,5));z[2,2]=np.nan;e=edges(z);assert e[2,2]==-1 and e[1,2]==1 and e[1,1]==2 and e[0,0]==0
 z=np.ones((5,5));z[2,2]=1.05;assert edges(z)[2,2]==3;z[2,2]=1.2;assert edges(z)[2,2]==4
 tests.append({'name':'edge_bins_and_missing_centre_counted','passed':True})
 return {'tests':tests,'runtime':runtime,'recordedRays':0,'physicalAuthority':False}

def validate_mesh(path):
 errors=[];r=vtk.vtkPLYReader();r.AddObserver('ErrorEvent',lambda *args:errors.append('VTK reader ErrorEvent'));r.SetFileName(str(path));r.Update()
 if errors:raise GeometryFailure(';'.join(errors))
 mesh=r.GetOutput();xyz=vtk_to_numpy(mesh.GetPoints().GetData());off=vtk_to_numpy(mesh.GetPolys().GetOffsetsArray());indices=vtk_to_numpy(mesh.GetPolys().GetConnectivityArray())
 assert xyz.shape==(242293,3) and mesh.GetNumberOfCells()==461256 and mesh.GetNumberOfPolys()==461256
 assert np.isfinite(xyz).all() and len(off)==461257 and (np.diff(off)==3).all() and off[0]==0 and off[-1]==len(indices) and indices.min()>=0 and indices.max()<len(xyz)
 with Path(path).open('rb') as f:
  header=[]
  while True:
   line=f.readline();assert line and len(header)<30;header.append(line)
   if line==b'end_header\n':break
  expected=[b'ply\n',b'format binary_little_endian 1.0\n',b'comment Created by Open3D\n',b'element vertex 242293\n',b'property double x\n',b'property double y\n',b'property double z\n',b'property uchar red\n',b'property uchar green\n',b'property uchar blue\n',b'element face 461256\n',b'property list uchar uint vertex_indices\n',b'end_header\n']
  assert header==expected
  direct=np.fromfile(f,dtype=[('xyz','<f8',3),('rgb','u1',3)],count=242293)
 assert len(direct)==len(xyz) and np.isfinite(direct['xyz']).all()
 delta=np.abs(direct['xyz']-xyz);max_delta=float(delta.max());assert max_delta<=1e-6
 report={'vertices':len(xyz),'triangles':mesh.GetNumberOfCells(),'originalPLYCoordinateType':'float64','VTKCoordinateType':mesh.GetPoints().GetData().GetDataTypeAsString(),'maxAbsoluteReadbackCoordinateDifferenceM':max_delta,'allVerticesAndTriangleIndicesChecked':True,'geometryFiltered':False,'bounds':list(mesh.GetBounds())}
 mesh.GetPointData().Initialize();mesh.GetCellData().Initialize()
 return mesh,report

def main():
 if sys.flags.optimize:raise RuntimeError('assertions must be active')
 parser=argparse.ArgumentParser();parser.add_argument('--mode',choices=['conventions','evaluate'],required=True);parser.add_argument('--output',type=Path,required=True);parser.add_argument('--frozen',type=Path,required=True);parser.add_argument('--frozen-sha',required=True);args=parser.parse_args()
 assert len(args.frozen_sha)==64 and digest(args.frozen)==args.frozen_sha
 out=args.output;out.mkdir(exist_ok=False);frozen=json.loads(args.frozen.read_text());paths=frozen['paths']
 allowed=sorted(os.sched_getaffinity(0));os.sched_setaffinity(0,{allowed[0]})
 if args.mode=='conventions':dump(out/'result.json',conventions());return
 runtime=serial_vtk();runtime.update(numpyVersion=np.__version__,pillowVersion=PIL_VERSION,pythonVersion=sys.version);start=time.monotonic()
 def emit(x):print(json.dumps(dict(x,wallSeconds=time.monotonic()-start,CPUSeconds=time.process_time(),peakRSSBytes=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss*1024)),flush=True)
 training=json.loads(Path(paths['trainingFreeze']).read_text());frame_ids=frozen['frameIDs'];assert frame_ids==training['excludedTestIDs'] and len(frame_ids)==29 and len(set(frame_ids))==29
 assert not set(frame_ids)&{r['frameID']for r in training['trainingFrames']}
 assert Path(paths['testSplit']).read_text().splitlines()==frame_ids
 doc=json.loads(Path(paths['pose']).read_text());frames=doc['frames'];by_name={Path(f['file_path']).stem:f for f in frames};assert len(by_name)==len(frames)==294
 emit({'phase':'mesh_load'});mesh,mesh_report=validate_mesh(paths['mesh']);dump(out/'MESH_READER_REPORT.json',mesh_report)
 surface=ReferenceSurface(mesh,progress=emit)
 rr,cc=np.meshgrid(np.arange(0,994,4),np.arange(0,738,4),indexing='ij');assert rr.shape==(249,185) and rr.size==46065
 all_raw=[];all_pred=[];all_es=[];all_ep=[];metrics=[];artifacts=[]
 for i,name in enumerate(frame_ids):
  f=by_name[name];assert (f['h'],f['w'])==(994,738) and Path(f['depth_file_path']).stem==name
  pose,pose_check=checked_camera(f['transform_matrix'])
  distortion={k:v for d in (doc,f)for k,v in d.items()if k in ('k1','k2','k3','k4','p1','p2','distortion_params')}
  assert not distortion or not any(np.any(np.asarray(v)!=0)for v in distortion.values())
  with Image.open(Path(paths['depthDirectory'])/(name+'.png'))as im:raw=np.asarray(im)
  assert raw.shape==(994,738) and raw.dtype==np.uint16
  sample=raw[::4,::4].copy();ray=rays(rr.ravel(),cc.ravel(),*[f[k]for k in ('fl_x','fl_y','cx','cy')])
  pred,cells,query=surface.query(pose,np.eye(4),ray,label=name);pred=pred.reshape(rr.shape);cells=cells.reshape(rr.shape)
  assert np.array_equal(np.isfinite(pred),cells>=0) and np.all(pred[np.isfinite(pred)]>0)
  es=edges(sample.astype(np.float64)*.001);ep=edges(pred);m=summarize(sample,pred,es,ep)
  query={k.replace('Faro','PhoneMap'):v for k,v in query.items()};query['rayTransform']='identity @ original camera_to_phone';query['legacyHelperSecondTransformWasIdentity']=True
  row={'frameID':name,'index':i,'poseCheck':pose_check,'intrinsics':{k:f[k]for k in ('fl_x','fl_y','cx','cy','h','w')},'query':query,**m};metrics.append(row);dump(out/(name+'-metrics.json'),row)
  path=out/(name+'-rays.npz');np.savez_compressed(path,row=rr.astype(np.uint16),column=cc.astype(np.uint16),sensorU16Millimetres=sample,predictedAxialMetres=pred,hitCellID=cells,sensorEdgeCode=es,meshEdgeCode=ep)
  artifacts.append({'path':path.name,'bytes':path.stat().st_size,'sha256':digest(path)})
  all_raw.append(sample.ravel());all_pred.append(pred.ravel());all_es.append(es.ravel());all_ep.append(ep.ravel())
  emit({'phase':'frame_complete','index':i,'frameID':name,'availability':m['availability'],'primaryStatistics':m['primaryStatistics']})
 pooled=summarize(np.concatenate(all_raw),np.concatenate(all_pred),np.concatenate(all_es),np.concatenate(all_ep));assert pooled['availability']['scheduled']==1335885
 result={'scope':'Fixed held-out same-capture processed-depth TSDF consistency; not physical accuracy, clearance or navigation','frameCount':29,'frameIDs':frame_ids,'sampleStride':4,'pixelOffset':0.0,'residualSign':'predicted mesh axial depth minus held-out processed sensor axial depth','primaryDomain':'0 < measured sensor depth < 4 m; predicted depth is not range-filtered','runtime':runtime,'mesh':mesh_report,'pooledRayWeighted':pooled,'frames':metrics,'artifacts':artifacts,'FAROUsed':False,'fittingPerformed':False,'originalConfidence':'unavailable and not fabricated','originalTracking':'unavailable and not fabricated','missingMeshImpliesFree':False,'physicalAuthority':False,'navigationCalled':False}
 dump(out/'result.json',result);emit({'phase':'complete','availability':pooled['availability'],'primaryStatistics':pooled['primaryStatistics']})
if __name__=='__main__':main()
