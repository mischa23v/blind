"""SOURCE-ONLY candidate: exact XYZ keys for adjacency, never geometry welding.
The original GroundSupport and its published/default policy are immutable.
from_scorer below is copied from the pinned upstream adapter with one call-site
addition (vertex_coordinates=points). No locator, patch, slope or seed change.
"""
import hashlib
import numpy as np
import vtk
from vtk.util.numpy_support import vtk_to_numpy
from ground_support import GroundSupport, GroundSupportUnavailable

MODE = 'exact-xyz-shared-edge-v1'

class ExactXYZGroundSupport(GroundSupport):
 @classmethod
 def from_candidates(cls,cell_ids,triangle_vertex_ids,normal_y_absolute,eligible_bounds,seed_ids,*,vertex_coordinates):
  points=np.asarray(vertex_coordinates)
  tri=np.asarray(triangle_vertex_ids)
  if points.ndim!=2 or points.shape[1]!=3 or points.dtype!=np.float64 or not np.isfinite(points).all():
   raise ValueError('exact XYZ candidate requires finite source float64 vertices')
  if tri.ndim!=2 or tri.shape[1]!=3 or not np.issubdtype(tri.dtype,np.integer) or np.any(tri<0) or np.any(tri>=len(points)):
   raise ValueError('invalid original candidate vertex IDs')
  # Equality of all three existing coordinates only. No epsilon/rounding,
  # transformed-coordinate rewrite, point-only adjacency or mesh mutation.
  unique,canonical=np.unique(points,axis=0,return_inverse=True)
  component=GroundSupport.from_candidates(cell_ids,canonical[tri],normal_y_absolute,eligible_bounds,seed_ids)
  receipt=dict(component.receipt)
  receipt.update({'groundAdjacencyMode':MODE,
   'connectivity':'shared undirected edges of exactly equal original float64 XYZ endpoints',
   'originalVertexIDAdjacency':False,'exactCoordinateAdjacencyOnly':True,
   'originalMeshCoordinatesChanged':False,'originalFaceIDsPreserved':True,
   'positionWelding':False,'weldToleranceMetres':None,
   'sourceVertexCount':int(len(points)),'uniqueExactXYZCount':int(len(unique)),
   'coincidentSeparateSheetsDisambiguated':False})
  return cls(component.ground_cell_ids,receipt)
 @classmethod
 def from_scorer(cls,scorer,frozen_route_points,initial_support_cell_ids):
  scorer.check();route=np.asarray(frozen_route_points,float)
  if route.ndim!=2 or route.shape[1]!=3 or len(route)<2 or not np.isfinite(route).all():raise ValueError('finite fixed route required to bound patch')
  lo=np.array([route[:,0].min()-.8,-.25,route[:,2].min()-.8]);hi=np.array([route[:,0].max()+.8,.25,route[:,2].max()+.8])
  corners=np.asarray([[x,y,z]for x in (lo[0],hi[0])for y in (lo[1],hi[1])for z in (lo[2],hi[2])]);reference=corners@scorer.transform[:3,:3].T+scorer.transform[:3,3]
  if not np.isfinite(reference).all():raise ValueError('invalid patch transform')
  ids=vtk.vtkIdList();scorer.surface.locator.FindCellsWithinBounds(np.column_stack((reference.min(0),reference.max(0))).reshape(-1),ids);scorer.check()
  if ids.GetNumberOfIds()>2000000:raise GroundSupportUnavailable('two-million candidate cap; not ground')
  original=np.unique(np.fromiter((ids.GetId(i)for i in range(ids.GetNumberOfIds())),np.int64,count=ids.GetNumberOfIds()))
  mesh=scorer.mesh
  if mesh.GetNumberOfCells()!=mesh.GetNumberOfPolys()or np.any(original<0)or np.any(original>=mesh.GetNumberOfCells()):raise ValueError('triangle-only original mesh required')
  offsets=vtk_to_numpy(mesh.GetPolys().GetOffsetsArray());conn=vtk_to_numpy(mesh.GetPolys().GetConnectivityArray());points=vtk_to_numpy(mesh.GetPoints().GetData())
  if not np.all(offsets[original+1]-offsets[original]==3):raise ValueError('patch includes nontriangle cells')
  tri=conn[offsets[original,None]+np.arange(3)];ny=np.full(len(tri),np.nan);within=np.zeros(len(tri),bool)
  if np.any(tri<0)or np.any(tri>=len(points)):raise ValueError('invalid original triangle vertex IDs')
  # Chunked coordinate conversion avoids duplicating the full reference mesh.
  for start in range(0,len(tri),32768):
   end=min(start+32768,len(tri));p=points[tri[start:end]].astype(np.float64)@scorer.inverse[:3,:3].T+scorer.inverse[:3,3]
   if not np.isfinite(p).all():raise ValueError('nonfinite model-frame patch triangle')
   normal=np.cross(p[:,1]-p[:,0],p[:,2]-p[:,0]);norm=np.linalg.norm(normal,axis=1);good=norm>0
   ny[start:end][good]=np.abs(normal[good,1])/norm[good]
   within[start:end]=(p[:,:,1].min(1)>=lo[1])&(p[:,:,1].max(1)<=hi[1])&(p[:,:,0].max(1)>=lo[0])&(p[:,:,0].min(1)<=hi[0])&(p[:,:,2].max(1)>=lo[2])&(p[:,:,2].min(1)<=hi[2])
  component=cls.from_candidates(original,tri,ny,within,initial_support_cell_ids,vertex_coordinates=points);scorer.check()
  component.receipt.update({'patchGameBounds':np.column_stack((lo,hi)).reshape(-1).tolist(),'patchRule':'fixed route XZ envelope plus0.8m; nominal Y[-0.25,0.25], never grown after contact','candidateCap':2000000,'fullReferenceAdjacencyBuilt':False,'fullReferenceTransformedCopy':False,'originalMeshMTime':int(mesh.GetMTime())})
  transform=np.asarray(scorer.transform,dtype=np.float64).copy();transform.setflags(write=False)
  component.receipt['referenceTransformSHA256']=hashlib.sha256(transform.tobytes()).hexdigest()
  return cls(component.ground_cell_ids,component.receipt,scorer.surface,mesh,int(mesh.GetMTime()),transform)
