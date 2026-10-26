"""Single fixed-frame offline exported-depth/reference comparison; no detector/navigation."""
from pathlib import Path
import argparse,hashlib,json,math,time,resource
import numpy as np
from PIL import Image
import vtk
from vtk.util.numpy_support import vtk_to_numpy
from reference_geometry import ReferenceSurface,checked_camera,checked_similarity,camera_rays,serial_vtk,convention_tests,GeometryFailure
ROOT=Path(__file__).resolve().parent
INDICES=[0,4,8,12,16,20,24,28]
EXPECTED_NAMES=[f'frame_{i+1:05d}' for i in INDICES]

def dump(path,value):path.write_text(json.dumps(value,indent=2,sort_keys=True,allow_nan=False)+'\n')
def digest(path):
 h=hashlib.sha256()
 with path.open('rb') as f:
  for b in iter(lambda:f.read(1024**2),b''):h.update(b)
 return h.hexdigest()
def statistics(values):
 v=np.asarray(values,dtype=np.float64)
 if not len(v):return {'count':0,'meanSigned':None,'medianSigned':None,'MAE':None,'medianAbsolute':None,'p90Absolute':None,'p95Absolute':None}
 if not np.isfinite(v).all():raise GeometryFailure('nonfinite paired discrepancy')
 a=np.abs(v)
 return {'count':len(v),'meanSigned':float(np.mean(v)),'medianSigned':float(np.median(v)),'MAE':float(np.mean(a)),
  'medianAbsolute':float(np.median(a)),'p90Absolute':float(np.quantile(a,.90,method='linear')),'p95Absolute':float(np.quantile(a,.95,method='linear'))}
def edge_categories(reference):
 h,w=reference.shape;result=np.full((h,w),-1,dtype=np.int8);valid=np.isfinite(reference)&(reference>0)
 for row in range(h):
  for col in range(w):
   if not valid[row,col]:continue
   if row==0 or row==h-1 or col==0 or col==w-1:result[row,col]=0;continue
   neighbours=np.asarray([reference[row-1,col],reference[row+1,col],reference[row,col-1],reference[row,col+1]])
   if not np.isfinite(neighbours).all() or np.any(neighbours<=0):result[row,col]=1;continue
   delta=float(np.max(np.abs(neighbours-reference[row,col])))
   result[row,col]=2 if delta<=.02 else (3 if delta<=.10 else 4)
 return result
EDGE_NAMES=['raster_boundary','reference_support_boundary','reference_delta_le_002','reference_delta_gt002_le010','reference_delta_gt010']
def range_masks(r):return [r<.15,(r>=.15)&(r<1),(r>=1)&(r<2),(r>=2)&(r<3),(r>=3)&(r<=5),r>5]
RANGE_NAMES=['positive_below015','015_to_below1','1_to_below2','2_to_below3','3_to5_inclusive','above5']
def main():
 args=argparse.ArgumentParser();args.add_argument('--mode',choices=['conventions','evaluate'],required=True);args.add_argument('--output',type=Path,required=True);a=args.parse_args()
 out=a.output;out.mkdir(exist_ok=False)
 if a.mode=='conventions':
  result=convention_tests();dump(out/'CONVENTION_RESULTS.json',result);print(json.dumps(result,indent=2),flush=True);return
 convention_file=ROOT/'run-conventions/comparison/CONVENTION_RESULTS.json'
 if not convention_file.is_file():raise GeometryFailure('required convention result missing')
 convention=json.loads(convention_file.read_text());convention_receipt=json.loads((ROOT/'run-conventions/RUN_RECEIPT.json').read_text())
 if convention.get('recordedFramesEvaluated')!=0 or len(convention.get('tests',[]))!=6 or not convention_receipt.get('sourceAndInputHashesVerifiedBeforeAndAfter'):raise GeometryFailure('invalid convention prerequisite')
 prior_pins={p['path']:p['sha256'] for p in convention_receipt['pins']}
 for name in ['comparison.py','reference_geometry.py','run_bounded.py']:
  source=ROOT/name
  if prior_pins.get(str(source))!=digest(source):raise GeometryFailure('convention source cut differs from evaluation')
 data=json.loads((ROOT/'DATA_CONFIG.json').read_text());runtime=serial_vtk();started=time.monotonic()
 def emit(item):
  item=dict(item);item.update(wallElapsedSeconds=time.monotonic()-started,childCPUSeconds=time.process_time(),childPeakRSSKiB=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss)
  print(json.dumps(item),flush=True)
 original=json.loads(Path(data['originalPoses']).read_text());associated=json.loads(Path(data['associatedPoses']).read_text())
 a_matrix,registration=checked_similarity(json.loads(Path(data['alignment']).read_text())['gt_transformation'])
 by_name={Path(f['file_path']).stem:f for f in associated['frames']}
 if len(by_name)!=len(associated['frames']):raise GeometryFailure('duplicate associated filenames')
 selected=[];association=[]
 for index,name in zip(INDICES,EXPECTED_NAMES):
  old=original['frames'][index]
  if Path(old['file_path']).stem!=name or name not in by_name:raise GeometryFailure('fixed input association changed')
  f=by_name[name];camera,check=checked_camera(f['transform_matrix'])
  if (f['w'],f['h'])!=(738,994):raise GeometryFailure('processed resolution mismatch')
  for k in ['fl_x','fl_y','cx','cy']:
   if not math.isfinite(f[k]) or (k in ['fl_x','fl_y'] and f[k]<=0):raise GeometryFailure('invalid original calibration')
  distortion={k:v for owner in [associated,f] for k,v in owner.items() if k in ['k1','k2','k3','k4','p1','p2','distortion_params']}
  if distortion and any(np.any(np.asarray(v)!=0) for v in distortion.values()):raise GeometryFailure('nonzero supplied distortion needs protocol review')
  association.append({'sourceIndex':index,'basename':name,'camera':check,'suppliedDistortionFields':distortion,
   'originalVsAssociatedPoseMaxDifference':float(np.max(np.abs(camera-np.asarray(old['transform_matrix'])))),
   'originalVsAssociatedCalibrationMaxDifference':max(float(abs(f[k]-old[k])) for k in ['fl_x','fl_y','cx','cy','w','h'])})
  selected.append((name,f,camera))
 dump(out/'ASSOCIATION_REPORT.json',{'registration':registration,'frames':association,'distortionStatus':'author pinhole assumption; absent fields do not establish measured undistortion','posesFittedHere':False,'confidence':'unavailable and unused','tracking':'unavailable and unused'})
 emit({'phase':'load_original_reference_mesh','vertices':8940320,'faces':17801112})
 reader=vtk.vtkPLYReader();errors=[];reader.AddObserver('ErrorEvent',lambda *args:errors.append('VTK PLY ErrorEvent'));reader.SetFileName(data['mesh']);reader.Update()
 if errors:raise GeometryFailure(';'.join(errors))
 mesh=reader.GetOutput()
 if mesh.GetNumberOfPoints()!=8940320 or mesh.GetNumberOfPolys()!=17801112 or mesh.GetNumberOfCells()!=17801112:raise GeometryFailure('reader changed expected mesh topology/counts')
 coordinate_type=mesh.GetPoints().GetData().GetDataTypeAsString()
 coordinates=vtk_to_numpy(mesh.GetPoints().GetData())
 for start in range(0,len(coordinates),262144):
  if not np.isfinite(coordinates[start:start+262144]).all():raise GeometryFailure('nonfinite mesh vertex')
 offsets=vtk_to_numpy(mesh.GetPolys().GetOffsetsArray());connectivity=vtk_to_numpy(mesh.GetPolys().GetConnectivityArray())
 if len(offsets)!=17801113 or offsets[0]!=0 or offsets[-1]!=len(connectivity):raise GeometryFailure('invalid cell offsets')
 for start in range(0,len(offsets)-1,262144):
  if not np.all(np.diff(offsets[start:min(start+262145,len(offsets))])==3):raise GeometryFailure('reference cell not triangle')
 for start in range(0,len(connectivity),262144):
  chunk=connectivity[start:start+262144]
  if np.any(chunk<0) or np.any(chunk>=8940320):raise GeometryFailure('invalid mesh vertex index')
 del coordinates,offsets,connectivity,chunk
 # Normals/colors are not used for two-sided triangle intersection. No geometry is modified.
 mesh.GetPointData().Initialize();mesh.GetCellData().Initialize()
 mesh_info={'vertices':mesh.GetNumberOfPoints(),'faces':mesh.GetNumberOfPolys(),'boundsFaroCoordinates':list(mesh.GetBounds()),
  'VTKPointScalarType':coordinate_type,'originalPLYCoordinates':'float64','unusedPointCellAttributesReleased':True,'geometrySimplified':False,'meshTransformed':False,
  'allVerticesFiniteAndCellStructureChecked':True,'VTKPolyDataAllocatedKiB':mesh.GetActualMemorySize(),'meshSHA256':data['meshSHA256']}
 dump(out/'MESH_READER_REPORT.json',mesh_info);emit({'phase':'mesh_loaded_and_validated','mesh':mesh_info})
 surface=ReferenceSurface(mesh,progress=emit)
 rr,cc=np.meshgrid(np.arange(0,994,4),np.arange(0,738,4),indexing='ij');flat_r=rr.ravel();flat_c=cc.ravel()
 if rr.size!=46065:raise GeometryFailure('fixed schedule mismatch')
 frames=[];all_errors=[];pooled_ranges=[[] for _ in RANGE_NAMES];pooled_edges=[[] for _ in EDGE_NAMES]
 totals={'scheduled':0,'paired':0,'sensorOnly':0,'referenceOnly':0,'neither':0};artifacts=[]
 for frame_id,(name,f,camera) in enumerate(selected):
  frame_start=time.monotonic();depth_path=Path(data['depthDirectory'])/(name+'.png')
  with Image.open(depth_path) as im:raw=np.asarray(im)
  if raw.shape!=(994,738) or raw.dtype!=np.uint16:raise GeometryFailure('original processed depth dtype/dimensions')
  sensor=raw[::4,::4].astype(np.float64)*.001;sv=np.isfinite(sensor)&(sensor>0)
  rays=camera_rays(flat_r,flat_c,f['fl_x'],f['fl_y'],f['cx'],f['cy'])
  reference,cells,query=surface.query(camera,a_matrix,rays,label=name);reference=reference.reshape(rr.shape);rv=np.isfinite(reference)&(reference>0)
  paired=sv&rv;status=np.full(rr.shape,3,dtype=np.uint8);status[paired]=0;status[sv&~rv]=1;status[~sv&rv]=2
  count={'scheduled':rr.size,'paired':int(paired.sum()),'sensorOnly':int((sv&~rv).sum()),'referenceOnly':int((~sv&rv).sum()),'neither':int((~sv&~rv).sum())}
  if sum(count[k] for k in ['paired','sensorOnly','referenceOnly','neither'])!=46065:raise GeometryFailure('per-frame denominator mismatch')
  for k,v in count.items():totals[k]+=v
  discrepancy=sensor-reference;errors_for_frame=discrepancy[paired];all_errors.append(errors_for_frame)
  ranges=[]
  for i,(label,mask) in enumerate(zip(RANGE_NAMES,range_masks(reference))):
   values=discrepancy[paired&mask];pooled_ranges[i].append(values);ranges.append({'label':label,'referenceValidCount':int((rv&mask).sum()),'statistics':statistics(values)})
  edge=edge_categories(reference);edges=[]
  for i,label in enumerate(EDGE_NAMES):
   values=discrepancy[paired&(edge==i)];pooled_edges[i].append(values);edges.append({'label':label,'referenceValidCount':int((rv&(edge==i)).sum()),'statistics':statistics(values)})
  if sum(x['statistics']['count'] for x in edges)!=count['paired'] or sum(x['statistics']['count'] for x in ranges)!=count['paired']:raise GeometryFailure('stratified denominator mismatch')
  tiles=[]
  for tr in range(6):
   for tc in range(8):
    mask=(flat_r*6//994==tr)&(flat_c*8//738==tc);states=status.ravel()[mask]
    tiles.append({'row':tr,'column':tc,'scheduled':len(states),'paired':int((states==0).sum()),'sensorOnly':int((states==1).sum()),'referenceOnly':int((states==2).sum()),'neither':int((states==3).sum())})
  output=out/(name+'-scheduled-rays.npz');np.savez_compressed(output,row=rr.astype(np.uint16),column=cc.astype(np.uint16),sensorAxialNominalMetres=sensor,referenceAxialRegisteredNominalMetres=reference,status=status,referenceEdgeCategory=edge,referenceCellID=cells.reshape(rr.shape))
  artifacts.append({'path':output.name,'bytes':output.stat().st_size,'sha256':digest(output)})
  row={'sourceIndex':INDICES[frame_id],'basename':name,'counts':count,'allPairedStatistics':statistics(errors_for_frame),'byReferenceDepth':ranges,'byReferenceEdge':edges,'imageTiles':tiles,
   'query':query,'wallSeconds':time.monotonic()-frame_start,'sourceConfidence':'unavailable','referenceMeasuredSupport':'unknown for author-cleaned mesh; no edit mask supplied'}
  frames.append(row);dump(out/(name+'-metrics.json'),row);emit({'phase':'frame_complete','basename':name,'counts':count,'statistics':row['allPairedStatistics'],'wallSeconds':row['wallSeconds']})
 if totals['scheduled']!=368520 or sum(totals[k] for k in ['paired','sensorOnly','referenceOnly','neither'])!=368520:raise GeometryFailure('full fixed denominator mismatch')
 result={'scope':'Offline fixed-author-registration processed iPhone depth vs cleaned FARO-derived mesh discrepancy; NOT raw physical accuracy or obstacle/navigation safety',
  'frameCount':8,'fixedIndices':INDICES,'sampleStride':4,'pixelOffset':.5,'totals':totals,'allPairedStatistics':statistics(np.concatenate(all_errors)),
  'byReferenceDepth':[{'label':label,'statistics':statistics(np.concatenate(values))} for label,values in zip(RANGE_NAMES,pooled_ranges)],
  'byReferenceEdge':[{'label':label,'statistics':statistics(np.concatenate(values))} for label,values in zip(EDGE_NAMES,pooled_edges)],
  'registration':registration,'runtime':runtime,'frames':frames,'rayArtifacts':artifacts,'wallSeconds':time.monotonic()-started,
  'confidenceFabricated':False,'trackingFabricated':False,'registrationFittedHere':False,'detectorOrNavigationCalled':False,'absoluteAccuracyEstablished':False,
  'meshMeasuredVsCompletedSurfaceMaskAvailable':False,'sourceDataVerification':'Required by external bounded runner before and after; consult terminal runner receipt'}
 dump(out/'COMPARISON_RESULTS.json',result);emit({'phase':'complete','totals':totals,'allPairedStatistics':result['allPairedStatistics']})
if __name__=='__main__':main()
