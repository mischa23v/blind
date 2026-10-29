"""Verbatim read_mesh/triangle_chunks from frozen stock-route worker; VTK 9.3.1."""
import numpy as np
import vtk
from vtk.util.numpy_support import vtk_to_numpy
def read_mesh(path,vertices,faces):
    errors=[];reader=vtk.vtkPLYReader();reader.AddObserver('ErrorEvent',lambda *args:errors.append('PLY ErrorEvent'))
    reader.SetFileName(str(path));reader.Update();assert not errors,errors
    mesh=reader.GetOutput()
    assert mesh.GetNumberOfPoints()==vertices and mesh.GetNumberOfCells()==faces
    assert mesh.GetNumberOfPolys()==faces and mesh.GetNumberOfVerts()==0 and mesh.GetNumberOfLines()==0 and mesh.GetNumberOfStrips()==0
    xyz=vtk_to_numpy(mesh.GetPoints().GetData());polys=mesh.GetPolys()
    offsets=vtk_to_numpy(polys.GetOffsetsArray());ids=vtk_to_numpy(polys.GetConnectivityArray())
    assert xyz.shape==(vertices,3) and np.isfinite(xyz).all()
    assert len(offsets)==faces+1 and offsets[0]==0 and offsets[-1]==3*faces and np.all(np.diff(offsets)==3),'triangles required; no triangulation/cleanup'
    assert len(ids)==3*faces and np.all(ids>=0) and np.all(ids<vertices)
    return mesh,xyz,ids.reshape(-1,3)

def triangle_chunks(vertices,faces):
    for start in range(0,len(faces),200000):
        p=vertices[faces[start:start+200000]]
        yield np.ascontiguousarray(p[:,:,[0,2,1]]*np.array([1,1,-1]),np.float32)

