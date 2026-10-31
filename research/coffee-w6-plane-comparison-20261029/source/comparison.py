"""Fixed-source W6 hypothesis comparison. No map edits, source fitting to reference, or routes.
Projection/range rules are copied explicitly from the retained Coffee trace; every
legacy fixed-point training observation is rechecked. Same-ray candidate/baseline
intersection is a separate bounded analytic observation, not a support classifier.
"""
from pathlib import Path
import hashlib,json,math,struct,subprocess

def sha(path):
 h=hashlib.sha256()
 with Path(path).open('rb') as f:
  for b in iter(lambda:f.read(1048576),b''):h.update(b)
 return h.hexdigest()
def dump(out,name,value):
 with (out/name).open('x') as f:json.dump(value,f,indent=2,allow_nan=False);f.write('\n')
def require(ok,why):
 if not ok:raise RuntimeError(why)
def range_status(d):return 'zeroDepth' if d==0 else 'excludedByTSDF4m' if d>=4 else 'admittedTSDFDepth'
def residual_class(r):return 'nearerThan4cm_possibleOcclusion' if r<-.04 else 'fartherThan4cm' if r>.04 else 'within4cm_notIdentity'

def run(root,packet,out,binary,native_env,verify_loaded):
 import numpy as np
 from PIL import Image
 runtime=json.loads((packet/'PYTHON_RUNTIME_INPUTS.json').read_text());runtime_roots={Path(r['path']).name:Path(r['path']).resolve(strict=True) for r in runtime['roots']}
 require(Path(np.__file__).resolve(strict=True).is_relative_to(runtime_roots['numpy']) and Path(Image.__file__).resolve(strict=True).is_relative_to(runtime_roots['PIL']),'imported modules outside frozen runtime trees')
 # Reuse original projection, pixel and depth-range semantics, not source imagery labels.
 def observation(point,f,pose,inv,depth):
  wp=np.asarray(point);c=inv@np.r_[wp,1];z=float(-c[2]);o={'pointAxialMetres':z,'pointRangeMetres':float(np.linalg.norm(c[:3]))}
  if z<=0:o['status']='behindCamera';return o
  u=f['fl_x']*c[0]/z+f['cx'];v=-f['fl_y']*c[1]/z+f['cy'];x=int(np.floor(u+.5));y=int(np.floor(v+.5));o['projectedPixel']=[float(u),float(v)]
  if not(0<=x<f['w'] and 0<=y<f['h']):o['status']='outsideRaster';return o
  value=float(depth[y,x])/1000;o.update(samplePixel=[x,y],sensorAxialMetres=value,status=range_status(value),exactly4m=value==4.)
  patch=depth[max(0,y-1):min(f['h'],y+2),max(0,x-1):min(f['w'],x+2)].astype(float)/1000.;positive=patch[patch>0];o['fixed3x3DepthMetres']=patch.tolist();o['positive3x3DepthRangeMetres']=[float(positive.min()),float(positive.max())] if len(positive) else None
  if value>0:
   residual=value-z;endpoint=pose@np.asarray([(x-f['cx'])/f['fl_x']*value,-(y-f['cy'])/f['fl_y']*value,-value,1.]);o.update(depthMinusPointMetres=residual,descriptiveResidualClass=residual_class(residual),withinOriginal20cmAxialTruncation=abs(residual)<=.2,sampledDepthEndpointDatasetXYZ=endpoint[:3].tolist(),sampledEndpointMinusFixedPointDatasetXYZ=(endpoint[:3]-wp).tolist())
  return o
 def triangle_ray(origin,direction,tri):
  a,b,c=tri;n=np.cross(b-a,c-a);den=float(np.dot(n,direction))
  if not math.isfinite(den) or abs(den)<=1e-12:return None,'baseline_parallel_or_degenerate'
  t=float(np.dot(n,a-origin)/den)
  if not math.isfinite(t) or t<=0:return None,'baseline_nonpositive_intersection'
  p=origin+t*direction;v0=b-a;v1=c-a;v2=p-a;d00=np.dot(v0,v0);d01=np.dot(v0,v1);d11=np.dot(v1,v1);d20=np.dot(v2,v0);d21=np.dot(v2,v1);det=d00*d11-d01*d01
  if not math.isfinite(float(det)) or det<=1e-24:return None,'baseline_degenerate_triangle'
  u=float((d11*d20-d01*d21)/det);v=float((d00*d21-d01*d20)/det)
  if u< -1e-9 or v< -1e-9 or u+v>1+1e-9:return None,'same_pixel_outside_original_triangle'
  return t,'baseline_original_triangle_hit'
 # Tiny independent analytical observation fixtures, not route/source support tests.
 identity=np.eye(4);identity[:3,:3]=[[0.,-1.,0.],[1.,0.,0.],[0.,0.,1.]];identity[:3,3]=[1,2,3];camera=np.asarray([.4,-.2,-2,1.]);world=identity@camera
 f={'fl_x':100.,'fl_y':100.,'cx':50.,'cy':40.,'w':100,'h':100};d=np.full((100,100),2000,dtype=np.uint16);o=observation(world[:3],f,identity,np.linalg.inv(identity),d)
 require(o['samplePixel']==[70,50] and o['depthMinusPointMetres']==0 and range_status(4)=='excludedByTSDF4m','projection/range fixture')
 t,why=triangle_ray(np.asarray([.2,.2,1.]),np.asarray([0.,0.,-1.]),np.asarray([[0.,0.,0.],[1.,0.,0.],[0.,1.,0.]]));require(t==1.,'same ray triangle fixture')
 t,why=triangle_ray(np.asarray([2.,2.,1.]),np.asarray([0.,0.,-1.]),np.asarray([[0.,0.,0.],[1.,0.,0.],[0.,1.,0.]]));require(t is None and why=='same_pixel_outside_original_triangle','triangle containment fixture')
 require(int(np.floor(70.5+.5))==71 and range_status(0)=='zeroDepth' and range_status(3.999)=='admittedTSDFDepth','rounding and depth fixtures')
 dump(out,'OBSERVATION_FIXTURES.json',{'nonzeroRotationAndTranslation':True,'negativeCameraZAndY':True,'nearestIntegerHalfUp':True,'zeroAndExact4mExclusion':True,'sameRayTriangleIntersection':True,'outsideTriangleRefused':True,'physicalAuthority':False})
 settings=json.loads((packet/'SETTINGS.json').read_text());fixed=json.loads((packet/'FIXED_INPUTS.json').read_text());data=json.loads((packet/'DATA_INPUTS.json').read_text())
 mesh=root/'research/coffee-original-pose-tsdf-comparator-20261028/fusion-v1/unfiltered-tsdf-mesh.ply'
 mesh_before=sha(mesh)
 base=root/'research/coffee-original-pose-tsdf-comparator-20261028/acquisition-v1/selected/room_datasets/coffee_room/iphone/long_capture'
 poses=json.loads((base/'transformations.json').read_text());by={Path(f['file_path']).stem:f for f in poses['frames']}
 legacy=json.loads((root/'research/coffee-original-pose-tsdf-comparator-20261028/fixed-gap-frame-trace-v1/FIXED_WITNESS_FRAME_TRACE.json').read_text())
 old={(p['pointID'],v['frameID']):v for p in legacy['points'] for v in p['observations']}
 require(len(by)==388 and len(data['frames'])==388,'exact388 posed frames');require(len({r['frameID'] for r in data['frames']})==388,'frame overlap')
 require([r['frameID'] for r in data['frames'] if r['split']=='heldout']==(base/'test.txt').read_text().splitlines(),'heldout identity')
 # Exact existing Open3D source representation, not a general-purpose PLY reader.
 header=[]
 with mesh.open('rb') as f:
  for _ in range(32):
   line=f.readline(512);header.append(line)
   if line==b'end_header\n':break
  else:raise RuntimeError('bounded PLY header refused')
 expected=['ply','format binary_little_endian 1.0','comment Created by Open3D','element vertex 136847','property double x','property double y','property double z','property uchar red','property uchar green','property uchar blue','element face 268806','property list uchar uint vertex_indices','end_header']
 require([x.decode().rstrip('\n') for x in header]==expected,'original PLY schema');offset=sum(map(len,header))
 require(mesh.stat().st_size==offset+136847*27+268806*13,'PLY byte length')
 vv=np.memmap(mesh,mode='r',offset=offset,dtype=np.dtype([('xyz','<f8',(3,)),('rgb','u1',(3,))]),shape=(136847,))
 ff=np.memmap(mesh,mode='r',offset=offset+136847*27,dtype=np.dtype([('n','u1'),('ids','<u4',(3,))]),shape=(268806,))
 vertices=np.asarray(vv['xyz']);faces=np.asarray(ff['ids']);require(bool(np.isfinite(vertices).all() and (ff['n']==3).all() and (faces<len(vertices)).all()),'whole source bounds/indices')
 centre=next(p['datasetWorldPoint'] for p in fixed['controlsAndLegacyW6'] if p['pointID']=='W6');half=settings['patchWidthMetres']/2;zlo,zhi=settings['sourceDisplayZBand']
 xyzlo=np.asarray([centre[0]-half,centre[1]-half,zlo]);xyzhi=np.asarray([centre[0]+half,centre[1]+half,zhi])
 require(all(not bool(((np.asarray(p['datasetWorldPoint'])[:2]>=xyzlo[:2])&(np.asarray(p['datasetWorldPoint'])[:2]<=xyzhi[:2])).all()) for p in fixed['controlsAndLegacyW6'] if p['pointID'] in ['W0','W2','W7']),'controls must remain outside fit patch')
 triangles=vertices[faces];lo=triangles.min(1);hi=triangles.max(1);candidate_ids=np.flatnonzero(((hi>=xyzlo)&(lo<=xyzhi)).all(1))
 ids=np.flatnonzero(((vertices>=xyzlo)&(vertices<=xyzhi)).all(1))
 require(3<=len(ids)<=settings['pointCountCap'] and len(candidate_ids)<=settings['triangleCandidateCap'],'whole patch count cap refused')
 # PCL PointXYZ uses Float32; this named fit-only conversion never modifies mesh bytes.
 points32=np.asarray(vertices[ids],dtype='<f4');require(bool(np.isfinite(points32).all()),'Float32 cast overflow')
 bits=points32.view('<u4');canonical=b'blind.coffee.w6.pcl-input.v1\0'+struct.pack('<I',len(ids))+b''.join(struct.pack('<IIII',int(i),*map(int,b)) for i,b in zip(ids,bits))
 text='W6_PCL_POINTS_V1 '+str(len(ids))+'\n'+''.join(str(int(i))+' '+' '.join(format(float(x),'.17g') for x in p)+'\n' for i,p in zip(ids,points32))
 dump(out,'PATCH_INPUT_RECEIPT.json',{'sourceMeshSHA256':sha(mesh),'pointCount':len(ids),'candidateTriangleCount':len(candidate_ids),'boundsDatasetP':[xyzlo.tolist(),xyzhi.tolist()],'originalVertexIDs':ids.tolist(),'originalTriangleCandidateIDs':candidate_ids.tolist(),'fitOnlyFloat32InputSHA256':hashlib.sha256(canonical).hexdigest(),'sourceVerticesRetained':True,'physicalAuthority':False})
 with (out/'fit.stdout').open('xb') as stdout,(out/'fit.stderr').open('xb') as stderr:
  proc=subprocess.run([str(binary),'--fit-once'],input=text.encode(),stdout=stdout,stderr=stderr,env=native_env,cwd=out)
 require(proc.returncode==0,'native fixed fit refused unexpectedly');native=json.loads((out/'fit.stdout').read_text());require(native['schema']==1 and native['mode']=='fit_once' and native['PCLVersion']=='1.15.0' and native['physicalAuthority'] is False and native['sourceGeometryMutated'] is False,'fit receipt schema/version/authority')
 require(native['inputFloat32Bits']==[[int(i),*map(int,b)] for i,b in zip(ids,bits)],'all native input bits must roundtrip');verify_loaded(native['loadedObjects'])
 fitted=native['fit'];plane=np.asarray(fitted['normalizedPlaneDatasetP'],float) if fitted['accepted'] else None
 if plane is not None:
  require(plane.shape==(4,) and np.isfinite(plane).all() and plane[2]>0 and abs(np.linalg.norm(plane[:3])-1)<1e-5,'returned plane bounds')
  require(plane[2]/np.linalg.norm(plane[:3])>=math.cos(math.radians(15)),'optimized plane tilt')
  require(set(fitted['inlierOriginalVertexIDs'])<=set(map(int,ids)) and len(set(fitted['inlierOriginalVertexIDs']))==len(fitted['inlierOriginalVertexIDs']),'inlier identities')
 facet_report=[]
 for ray in fixed['W6NineRays']:
  a,b,c=vertices[faces[ray['sourceTriangleID']]];normal=np.cross(b-a,c-a);length=float(np.linalg.norm(normal));require(length>0 and math.isfinite(length),'fixed source triangle degenerate')
  nz=float(normal[2]/length);angle=math.degrees(math.acos(max(-1.,min(1.,nz))))
  facet_report.append({'rayID':ray['id'],'sourceTriangleID':ray['sourceTriangleID'],'storedSignedNormalZ':ray['storedSignedNormalZ'],'sourceFloat64SignedNormalZ':nz,'sourceFloat64AngleDegrees':angle,'sourceFloat64FacetFails15Degrees':angle>15,'candidateNormalAngleDegrees':None if plane is None else math.degrees(math.acos(max(-1.,min(1.,float(plane[2]/np.linalg.norm(plane[:3])))))),'hypothesisOnlyNotRecastRequery':True,'sourceFacetUnchanged':True,'physicalAuthority':False})
 dump(out,'FIXED_FACET_REPORT.json',{'schema':1,'nineOriginalSourceFacets':facet_report,'noPromotionToSupport':True,'physicalAuthority':False})
 controls=[];observations=[];legacy_matches=0;loaded_hashes={};paired=[]
 for row in data['frames']:
  name=row['frameID'];f=by[name];path=root/row['depthPath'];require(path.stat().st_size==row['bytes'] and sha(path)==row['sha256'],'depth drift');loaded_hashes[name]=row['sha256']
  with Image.open(path) as image:depth=np.asarray(image)
  require(depth.dtype==np.uint16 and depth.shape==(994,738) and (f['h'],f['w'])==depth.shape,'depth/intrinsics shape')
  require(all(math.isfinite(float(f[k])) for k in ['fl_x','fl_y','cx','cy']) and f['fl_x']>0 and f['fl_y']>0,'calibration validity')
  pose=np.asarray(f['transform_matrix'],float);require(pose.shape==(4,4) and np.isfinite(pose).all() and np.max(abs(pose[3]-[0,0,0,1]))<1e-12 and np.max(abs(pose[:3,:3].T@pose[:3,:3]-np.eye(3)))<1e-5 and abs(np.linalg.det(pose[:3,:3])-1)<1e-5,'pose validity');inv=np.linalg.inv(pose)
  for p in fixed['controlsAndLegacyW6']:
   o=observation(p['datasetWorldPoint'],f,pose,inv,depth);record={'pointID':p['pointID'],'frameID':name,'split':row['split'],**o};controls.append(record)
   if row['split']=='training':
    previous=old[(p['pointID'],name)]
    current={'frameID':name,'trainingIndex':row['splitIndex'],**o}
    require(current==previous,'full legacy fixed observation changed: '+p['pointID']+'/'+name);legacy_matches+=1
  for ray in fixed['W6NineRays']:
   bearing=math.atan2(float(pose[1,3]-centre[1]),float(pose[0,3]-centre[0]));sector=int(math.floor((bearing+math.pi)/(math.pi/2)))%4
   o=observation(ray['baselineDatasetWorldPoint'],f,pose,inv,depth);r={'rayID':ray['id'],'sourceTriangleID':ray['sourceTriangleID'],'frameID':name,'split':row['split'],'splitIndex':row['splitIndex'],'frameOrderQuartile':min(3,row['splitIndex']*4//(350 if row['split']=='training' else 38)),'cameraAzimuthSectorDatasetP':sector,**o};observations.append(r)
   if o['status']!='admittedTSDFDepth':r['pairStatus']='source_depth_not_admitted';continue
   if plane is None:r['pairStatus']='hypothesis_not_fitted';continue
   x,y=o['samplePixel'];direction=pose[:3,:3]@np.asarray([(x-f['cx'])/f['fl_x'],-(y-f['cy'])/f['fl_y'],-1.]);origin=pose[:3,3]
   t,status=triangle_ray(origin,direction,vertices[faces[ray['sourceTriangleID']]])
   if t is None:r['pairStatus']=status;continue
   den=float(np.dot(plane[:3],direction))
   if not math.isfinite(den) or abs(den)<=1e-12:r['pairStatus']='candidate_parallel';continue
   tc=float(-(np.dot(plane[:3],origin)+plane[3])/den);pc=origin+tc*direction
   if not math.isfinite(tc) or tc<=0:r['pairStatus']='candidate_nonpositive_intersection';continue
   if not bool(((pc>=xyzlo)&(pc<=xyzhi)).all()):r['pairStatus']='candidate_outside_fixed_patch';continue
   value=o['sensorAxialMetres'];rb=value-t;rc=value-tc
   r.update(pairStatus='same_pixel_paired',baselineTriangleAxialMetres=t,candidatePlaneAxialMetres=tc,baselineResidualMetres=rb,candidateResidualMetres=rc,baselineResidualClass=residual_class(rb),candidateResidualClass=residual_class(rc),candidateIntersectionDatasetP=pc.tolist(),cameraOriginDatasetP=origin.tolist())
   paired.append(r)
 require(legacy_matches==1400 and len(controls)==1552 and len(observations)==3492,'fixed case counts')
 def stats(values):
  if not values:return None
  x=np.asarray(values,float);return {'count':len(x),'medianAbs':float(np.median(abs(x))),'p95Abs':float(np.quantile(abs(x),.95)),'worstAbs':float(max(abs(x))),'medianSigned':float(np.median(x)),'minSigned':float(min(x)),'maxSigned':float(max(x))}
 def summarize(allrows):
  pr=[r for r in allrows if r['pairStatus']=='same_pixel_paired']
  return {'allPointFrameCases':len(allrows),'pairStatusCounts':{k:sum(r['pairStatus']==k for r in allrows) for k in sorted({r['pairStatus'] for r in allrows})},'pairedCases':len(pr),'distinctPairedFrames':len({r['frameID'] for r in pr}),'distinctPairedFramePixels':len({(r['frameID'],*r['samplePixel']) for r in pr}),'baseline':stats([r['baselineResidualMetres'] for r in pr]),'candidate':stats([r['candidateResidualMetres'] for r in pr]),'baselineCompatibleCases':sum(abs(r['baselineResidualMetres'])<=.04 for r in pr),'candidateCompatibleCases':sum(abs(r['candidateResidualMetres'])<=.04 for r in pr)}
 summaries={};strata={}
 for split in ['training','heldout']:
  allrows=[r for r in observations if r['split']==split];summaries[split]=summarize(allrows)
  strata[split]={key:{str(group):summarize([r for r in allrows if r[key]==group]) for group in range(4)} for key in ['frameOrderQuartile','cameraAzimuthSectorDatasetP']}
 held=summaries['heldout'];progress=bool(plane is not None and held['pairedCases'] and held['candidateCompatibleCases'] and held['candidate']['medianAbs']<held['baseline']['medianAbs'] and held['candidate']['p95Abs']<=held['baseline']['p95Abs'])
 status='CONDITIONAL_LOCAL_RESIDUAL_CRITERIA_MET_NOT_SUPPORT' if progress else 'INCONCLUSIVE_NO_HELDOUT_COMPATIBLE_EVIDENCE' if not held['pairedCases'] or not held['candidateCompatibleCases'] else 'HYPOTHESIS_CRITERIA_NOT_MET'
 control_summary={}
 for point in ['W0','W2','W7','W6']:
  control_summary[point]={}
  for split in ['training','heldout']:
   rr=[r for r in controls if r['pointID']==point and r['split']==split];ad=[r for r in rr if r['status']=='admittedTSDFDepth'];control_summary[point][split]={'statusCounts':{s:sum(r['status']==s for r in rr) for s in sorted({r['status'] for r in rr})},'descriptiveCompatibleCount':sum(abs(r['depthMinusPointMetres'])<=.04 for r in ad),'signedAndAbsResiduals':stats([r['depthMinusPointMetres'] for r in ad])}
 dump(out,'OBSERVATIONS.json',{'schema':1,'samePixelW6':observations,'untouchedControlAndLegacyPoints':controls,'depthHashes':loaded_hashes,'legacyTrainingObservationsExactlyMatched':legacy_matches,'physicalAuthority':False})
 mesh_after=sha(mesh);require(mesh_before==mesh_after,'source mesh changed during comparison')
 result={'schema':1,'completedComparison':True,'hypothesisStatus':status,'localDiagnosticProgressionCriteriaMet':progress,'conditionalPairedEvidenceOnly':True,'minimumDistinctFrameRequirementBeyondNonzero':False,'pairedCasesNotIndependentSamples':True,'fit':fitted,'pairedResidualSummary':summaries,'descriptiveStrata':strata,'untouchedControlSummary':control_summary,'sourceMeshSHA256Before':mesh_before,'sourceMeshSHA256After':mesh_after,'legacyTrainingObservationsExactlyMatched':legacy_matches,'controlsRemainUnresolvedOrOriginalEvidence':True,'W0SupportFilled':False,'W2W7GeometryRemoved':False,'allOriginalGeometryRetained':True,'sourceConfidenceOrCalibrationInvented':False,'rawProcessedDepthNotIndependentLidar':True,'fullRouteOutcomesUnchanged':{'complete':2,'partial':16,'associationFailure':2,'requeried':False},'newRoutesQueried':0,'sourceGeometryMutated':False,'routePolicyChanged':False,'actualPhysicalCoverageKnown':False,'physicalAuthority':False}
 dump(out,'COMPARISON.json',result);return result
