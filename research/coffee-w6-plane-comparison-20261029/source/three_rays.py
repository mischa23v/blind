"""Three root-requested read-only camera rays using released VTK; never refits/routes."""
from pathlib import Path
import json,hashlib,math,sys,os,time,resource
H=Path(__file__).resolve().parent;ROOT=H.parents[2];start=time.monotonic()
def sha(p):
 h=hashlib.sha256()
 with p.open('rb') as f:
  for b in iter(lambda:f.read(1048576),b''):h.update(b)
 return h.hexdigest()
manifest=json.loads((H/'INPUTS.json').read_text())
for row in manifest['files']:
 p=Path(row['path']);assert p.stat().st_size==row['bytes'] and sha(p)==row['sha256']
import numpy as np
import vtk
from PIL import Image
assert vtk.vtkVersion.GetVTKVersion()=='9.3.1'
assert vtk.vtkSMPTools.SetBackend('Sequential');vtk.vtkSMPTools.Initialize(1)
C=ROOT/'research/coffee-original-pose-tsdf-comparator-20261028';sys.path.insert(0,str(C/'reference-route-evaluator-v1'));from tile_geometry import native_surface
mesh=C/'fusion-v1/unfiltered-tsdf-mesh.ply'
with mesh.open('rb') as f:
 header=b''
 for _ in range(32):
  line=f.readline(512);header+=line
  if line==b'end_header\n':break
 else:raise RuntimeError('PLY header bound')
vv=np.memmap(mesh,mode='r',offset=len(header),dtype=np.dtype([('xyz','<f8',(3,)),('rgb','u1',(3,))]),shape=(136847,));ff=np.memmap(mesh,mode='r',offset=len(header)+136847*27,dtype=np.dtype([('n','u1'),('ids','<u4',(3,))]),shape=(268806,));assert bool((ff['n']==3).all() and (ff['ids']<len(vv)).all())
v=np.asarray(vv['xyz']);faces=np.asarray(ff['ids']);surface=native_surface(v,faces,np.arange(len(faces)))
B=C/'acquisition-v1/selected/room_datasets/coffee_room/iphone/long_capture';poses=json.loads((B/'transformations.json').read_text());f=next(f for f in poses['frames'] if Path(f['file_path']).stem=='frame_00217');pose=np.asarray(f['transform_matrix'],float)
obs=json.loads((ROOT/'coordination/coffee-w6-plane-hypothesis-20261029/attempt4/run/OBSERVATIONS.json').read_text());rows=[r for r in obs['samePixelW6'] if r['split']=='heldout' and r['pairStatus']=='same_pixel_paired'];assert len(rows)==3 and {r['frameID'] for r in rows}=={'frame_00217'}
with Image.open(B/'depth/frame_00217.png') as image:depth=np.asarray(image);assert depth.shape==(994,738) and depth.dtype==np.uint16
with Image.open(B/'images/frame_00217.jpg') as image:rgbsize=image.size;orientation=image.getexif().get(274);assert rgbsize==(738,994)
results=[]
for r in rows:
 x,y=r['samplePixel'];assert float(depth[y,x])/1000==r['sensorAxialMetres']
 direction=pose[:3,:3]@np.asarray([(x-f['cx'])/f['fl_x'],-(y-f['cy'])/f['fl_y'],-1.]);origin=pose[:3,3]
 points=vtk.vtkPoints();points.SetDataTypeToDouble();ids=vtk.vtkIdList();cell=vtk.vtkGenericCell()
 status=surface['locator'].IntersectWithLine(origin.tolist(),(origin+direction*5.).tolist(),1e-7,points,ids,cell)
 assert status in (0,1) and points.GetNumberOfPoints()==ids.GetNumberOfIds() and points.GetNumberOfPoints()<=256
 hits=[]
 for i in range(points.GetNumberOfPoints()):
  p=np.asarray(points.GetPoint(i),float);tri=int(ids.GetId(i));t=float(np.dot(p-origin,direction)/np.dot(direction,direction));offset=float(np.linalg.norm(p-(origin+t*direction)));assert offset<1e-6 and 0<=t<=5.+1e-6 and 0<=tri<len(faces)
  hits.append({'sourceTriangleID':tri,'axialMetres':t,'pointDatasetP':p.tolist(),'perpendicularRayErrorMetres':offset,'sourceVertexRGB':vv['rgb'][faces[tri]].tolist()})
 hits.sort(key=lambda h:(h['axialMetres'],h['sourceTriangleID']));positive=[h for h in hits if h['axialMetres']>1e-7]
 baseline=[h for h in hits if h['sourceTriangleID']==r['sourceTriangleID']];assert baseline and min(abs(h['axialMetres']-r['baselineTriangleAxialMetres']) for h in baseline)<1e-7
 nearest=positive[0] if positive else None;delta=None if nearest is None else nearest['axialMetres']-r['sensorAxialMetres']
 results.append({'rayID':r['rayID'],'frameID':r['frameID'],'pixel':[x,y],'sensorAxialMetres':r['sensorAxialMetres'],'baselineTriangleAxialMetres':r['baselineTriangleAxialMetres'],'nearestMappedSurface':nearest,'nearestMinusSensorAxialMetres':delta,'withinInherited4cmDescriptiveBand':None if delta is None else abs(delta)<=.04,'allSegmentHits':hits,'rawDepth3x3':depth[y-1:y+2,x-1:x+2].tolist()})
for row in manifest['files']:
 p=Path(row['path']);assert p.stat().st_size==row['bytes'] and sha(p)==row['sha256']
mods=[]
for name in ['vtkmodules.vtkCommonCore','vtkmodules.vtkCommonDataModel','numpy']:
 p=Path(sys.modules[name].__file__);mods.append({'name':name,'path':str(p),'sha256':sha(p)})
result={'schema':1,'scope':'exact three paired heldout rays only; unchanged full Float64 source; 5m axial segment; no fit/map/route change','VTKVersion':vtk.vtkVersion.GetVTKVersion(),'VTKBackend':vtk.vtkSMPTools.GetBackend(),'meshSHA256':sha(mesh),'rayCount':3,'rays':results,'rgbSize':rgbsize,'RGBEXIFOrientation':orientation,'runtimeModules':mods,'completeRuntimeClosureAttested':False,'externalCalibrationValidated':False,'physicalAuthority':False,'uploadAllowed':False,'CPUSeconds':resource.getrusage(resource.RUSAGE_SELF).ru_utime+resource.getrusage(resource.RUSAGE_SELF).ru_stime,'wallSeconds':time.monotonic()-start,'maxRSSKiB':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss}
with (H/'RESULT.json').open('x') as out:json.dump(result,out,indent=2,allow_nan=False);out.write('\n')
print(json.dumps({'rayCount':3,'VTKVersion':result['VTKVersion'],'nearestMinusSensorAxialMetres':[r['nearestMinusSensorAxialMetres'] for r in results],'baselineFacesRecovered':True,'sourceUnchanged':True,'physicalAuthority':False}))
