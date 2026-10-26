"""Tiny analytic nearest-hit ordering diagnostic; no recorded data or full mesh."""
import json,resource,signal,hashlib
from pathlib import Path
import vtk
from reference_geometry import plane_mesh,serial_vtk
resource.setrlimit(resource.RLIMIT_CPU,(30,30));signal.alarm(45)
runtime=serial_vtk();mesh=plane_mesh([-2.,-4.,-1.]);rows=[]
for cls in [vtk.vtkCellTreeLocator,vtk.vtkStaticCellLocator]:
 loc=cls();loc.SetDataSet(mesh);loc.SetNumberOfCellsPerNode(64)
 if hasattr(loc,'SetNumberOfBuckets'):loc.SetNumberOfBuckets(6)
 loc.BuildLocator();t=vtk.reference(0.);sub=vtk.reference(0);cid=vtk.reference(0);point=[0.,0.,0.];pc=[0.,0.,0.];cell=vtk.vtkGenericCell()
 hit=loc.IntersectWithLine([0.,0.,0.],[0.,0.,-10.],1e-7,t,point,pc,sub,cid,cell)
 rows.append({'locator':cls.__name__,'inputPlaneAxialOrder':[2.,4.,1.],'expectedNearestAxial':1.,'hit':int(hit),'returnedAxial':-point[2] if hit else None,'cellID':int(cid) if hit else None,'matchesNearest':bool(hit and abs(point[2]+1.)<=1e-10)})
result={'scope':'Analytic engine ordering diagnostic only; no recorded frames/mesh/sensor data','runtime':runtime,'sourceSHA256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'results':rows}
p=Path(__file__).with_name('LOCATOR_ORDERING_RESULT.json')
with p.open('x') as f:json.dump(result,f,indent=2);f.write('\n')
print(json.dumps(result,indent=2))
