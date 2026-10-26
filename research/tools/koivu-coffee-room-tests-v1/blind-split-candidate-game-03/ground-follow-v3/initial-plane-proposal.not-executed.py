"""Controlled planar support model, world only; no route or pose controller.

Fit ONE plane to the nine original initial support hits. Ground membership is
only the shared-edge seed component of original triangles whose EVERY vertex
lies within the pre-existing 2 mm residual tolerance. A separate raw 45 degree
facet guard rejects vertical risers, while the fitted plane remains <=5 degrees.
Original obstacle coordinates, contact tests, support rays and missing surfaces
are never replaced. This is a declared game support assumption, not a detector.
"""
from dataclasses import dataclass
import math,hashlib
import numpy as np
from scipy.optimize import least_squares
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components
import vtk
from vtk.util.numpy_support import vtk_to_numpy

class GroundSupportUnavailable(RuntimeError):pass

PLANE_RESIDUAL_METRES = .002  # existing world floor-contact tolerance, not fitted to a contact
MAXIMUM_PLANE_SLOPE_DEGREES = 5.
MAXIMUM_RAW_FACET_SLOPE_DEGREES = 45.  # steep-edge guard, NOT walkability

def fit_support_plane(initial_support_points):
 points=np.asarray(initial_support_points,dtype=np.float64)
 if points.shape!=(9,3) or not np.isfinite(points).all():
  raise GroundSupportUnavailable('exactly nine finite original support hits required')
 centre=points[:,[0,2]].mean(axis=0)
 design=np.column_stack((points[:,0]-centre[0],points[:,2]-centre[1],np.ones(9)))
 initial,residual,rank,singular=np.linalg.lstsq(design,points[:,1],rcond=None)
 if rank!=3 or singular[-1]<=1e-8:
  raise GroundSupportUnavailable('initial support hits do not span a plane')
 result=least_squares(lambda q:design@q-points[:,1],initial,loss='soft_l1',
                      f_scale=PLANE_RESIDUAL_METRES,max_nfev=100,
                      ftol=1e-12,xtol=1e-12,gtol=1e-12)
 if not result.success or not np.isfinite(result.x).all():
  raise GroundSupportUnavailable('initial support plane fit did not converge')
 residuals=design@result.x-points[:,1]
 tilt=math.degrees(math.atan(float(np.linalg.norm(result.x[:2]))))
 if tilt>MAXIMUM_PLANE_SLOPE_DEGREES or np.max(np.abs(residuals))>PLANE_RESIDUAL_METRES:
  raise GroundSupportUnavailable('initial support is not the declared planar model')
 a,b,c=result.x;plane=np.array([a,b,c-a*centre[0]-b*centre[1]],dtype=np.float64)
 plane.setflags(write=False)
 receipt={'fitMethod':'SciPy least_squares soft_l1, initial NumPy least_squares',
          'fitInput':'exactly nine initial original support ray hits; never later contacts',
          'initialSupportPointsModelXYZ':points.tolist(),
          'planeCoefficientsYEqualsAXPlusBZPlusC':plane.tolist(),
          'planeSlopeDegrees':tilt,'initialFitResidualsMetres':residuals.tolist(),
          'initialFitMaximumAbsoluteResidualMetres':float(np.max(np.abs(residuals))),
          'robustLossScaleMetres':PLANE_RESIDUAL_METRES,'fitEvaluations':int(result.nfev),
          'fitFrozenBeforeMotion':True,'surfaceGeometryChanged':False}
 return plane,receipt


@dataclass(frozen=True)
class GroundSupport:
 ground_cell_ids: np.ndarray
 receipt: dict
 surface: object=None
 mesh: object=None
 mesh_revision: int|None=None
 reference_transform: np.ndarray|None=None
 plane_coefficients: np.ndarray|None=None
 def plane_height(self,x,z):
  if self.plane_coefficients is None or not np.isfinite([x,z]).all():raise GroundSupportUnavailable("invalid fixed plane query")
  a,b,c=self.plane_coefficients;return float(a*x+b*z+c)
 def check(self):
  if self.surface is None or self.mesh is None or self.reference_transform is None:raise GroundSupportUnavailable('ground component is not bound to a reference owner')
  if self.surface.mesh is not self.mesh or self.mesh.GetMTime()!=self.mesh_revision or self.surface.locator.GetDataSet()!=self.mesh:raise GroundSupportUnavailable('ground reference owner changed')
  if getattr(self.surface,'errors',[]):raise GroundSupportUnavailable('reference locator error')
 def assert_matches(self,surface,transform=None):
  self.check()
  if surface is not self.surface or (transform is not None and not np.array_equal(transform,self.reference_transform)):raise GroundSupportUnavailable('ground component belongs to another surface or transform')
 def contains(self,cell_id):return self.is_ground(cell_id)
 def is_ground(self,cell_id):
  if self.mesh is not None:self.check()
  if isinstance(cell_id,bool) or not isinstance(cell_id,(int,np.integer)):return False
  i=int(np.searchsorted(self.ground_cell_ids,int(cell_id)))
  return i<len(self.ground_cell_ids) and int(self.ground_cell_ids[i])==int(cell_id)
 def contains_all(self,cell_ids):
  a=np.asarray(cell_ids);return a.ndim==1 and a.size>0 and all(self.is_ground(x)for x in a)
 @classmethod
 def from_candidates(cls,cell_ids,triangle_vertex_ids,normal_y_absolute,eligible_bounds,seed_ids,vertex_max_residual,plane,fit_receipt):
  ids=np.asarray(cell_ids);tri=np.asarray(triangle_vertex_ids);ny=np.asarray(normal_y_absolute,float);bounds=np.asarray(eligible_bounds,bool);seeds=np.asarray(seed_ids)
  if ids.ndim!=1 or not np.issubdtype(ids.dtype,np.integer) or len(ids)>2000000 or len(np.unique(ids))!=len(ids) or np.any(ids<0):raise ValueError('invalid bounded original cell IDs')
  if tri.shape!=(len(ids),3) or not np.issubdtype(tri.dtype,np.integer) or np.any(tri<0) or ny.shape!=(len(ids),)or bounds.shape!=(len(ids),):raise ValueError('invalid candidate triangle data')
  if seeds.shape!=(9,)or not np.issubdtype(seeds.dtype,np.integer) or np.any(seeds<0):raise GroundSupportUnavailable('all nine valid initial support IDs required')
  residuals=np.asarray(vertex_max_residual,float);plane=np.asarray(plane,float).copy()
  if residuals.shape!=(len(ids),) or plane.shape!=(3,) or not np.isfinite(plane).all():raise ValueError('invalid fixed plane residual data')
  if math.degrees(math.atan(float(np.linalg.norm(plane[:2]))))>MAXIMUM_PLANE_SLOPE_DEGREES:raise GroundSupportUnavailable('plane tilt exceeds model')
  plane.setflags(write=False)
  slope=np.isfinite(ny)&(ny>=math.cos(math.radians(MAXIMUM_RAW_FACET_SLOPE_DEGREES)))&(ny<=1.+1e-12)
  residual_ok=np.isfinite(residuals)&(residuals>=0)&(residuals<=PLANE_RESIDUAL_METRES)
  keep=slope&bounds&residual_ok;kept_ids=ids[keep];kept_tri=tri[keep]
  if not len(kept_ids):raise GroundSupportUnavailable('no slope-eligible ground candidates')
  unique_seeds=np.unique(seeds);id_order=np.argsort(kept_ids);sorted_ids=kept_ids[id_order];pos=np.searchsorted(sorted_ids,unique_seeds)
  if np.any(pos>=len(sorted_ids)) or not np.array_equal(sorted_ids[np.minimum(pos,len(sorted_ids)-1)],unique_seeds):raise GroundSupportUnavailable('initial support seed absent, outside patch or not slope eligible')
  # An edge means the same two original vertex IDs. No positional welding,
  # point-only joins, height-nearness joins, diagonal fill or component hopping.
  n=len(kept_ids);edge=np.concatenate((kept_tri[:,[0,1]],kept_tri[:,[1,2]],kept_tri[:,[2,0]]),axis=0);edge.sort(axis=1)
  owner=np.tile(np.arange(n,dtype=np.int32),3);order=np.lexsort((edge[:,1],edge[:,0]));edge=edge[order];owner=owner[order]
  shared=np.all(edge[1:]==edge[:-1],axis=1);left=owner[:-1][shared];right=owner[1:][shared]
  adjacency=coo_matrix((np.ones(len(left),np.uint8),(left,right)),shape=(n,n)).tocsr()
  del edge,owner,order,shared,left,right,kept_tri
  component_count,labels=connected_components(adjacency,directed=False,return_labels=True)
  seed_labels=labels[id_order[pos]]
  if not np.all(seed_labels==seed_labels[0]):raise GroundSupportUnavailable('initial support seeds lie in disconnected edge components')
  accepted=np.sort(kept_ids[labels==seed_labels[0]]).astype(np.int64,copy=False);accepted.setflags(write=False)
  receipt={'scope':'Independent simulation-world ground contact component, not sensed clearance','candidateCells':int(len(ids)),'slopeEligibleCells':int(slope.sum()),'patchAndSlopeEligibleCells':int(keep.sum()),'edgeConnectedComponents':int(component_count),'groundCellCount':int(len(accepted)),'initialSupportSeedIDs':seeds.tolist(),'uniqueInitialSeedCount':int(len(unique_seeds)),'allSeedsRequired':True,'maximumPlaneSlopeDegrees':MAXIMUM_PLANE_SLOPE_DEGREES,'rawFacetSteepEdgeGuardDegrees':MAXIMUM_RAW_FACET_SLOPE_DEGREES,'maximumEveryVertexPlaneResidualMetres':PLANE_RESIDUAL_METRES,'planeResidualEligibleCells':int(residual_ok.sum()),'residualRejectedCells':int((~residual_ok).sum()),'normalConvention':'absolute model-frame Y normal; two-sided reference winding','connectivity':'shared original vertex-ID edges only; SciPy connected_components directed=False','stepUpAllowanceMetres':0.,'positionWelding':False,'referenceGeometryMaySteer':False,'physicalAuthority':False,'lowHeightAloneAdmitsGround':False,'semanticGroundLabelsAvailable':False}
  receipt.update(fit_receipt)
  receipt["groundModel"]="single initial-support plane, original shared-edge connected residual-bounded triangle membership"
  return cls(accepted,receipt,plane_coefficients=plane)
 @classmethod
 def from_scorer(cls,scorer,frozen_route_points,initial_support_cell_ids,initial_support_points):
  scorer.check();route=np.asarray(frozen_route_points,float)
  if route.ndim!=2 or route.shape[1]!=3 or len(route)<2 or not np.isfinite(route).all():raise ValueError('finite fixed route required to bound patch')
  plane,fit_receipt=fit_support_plane(initial_support_points)
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
  tri=conn[offsets[original,None]+np.arange(3)];ny=np.full(len(tri),np.nan);within=np.zeros(len(tri),bool);residuals=np.full(len(tri),np.inf)
  if np.any(tri<0)or np.any(tri>=len(points)):raise ValueError('invalid original triangle vertex IDs')
  # Chunked coordinate conversion avoids duplicating the full reference mesh.
  for start in range(0,len(tri),32768):
   end=min(start+32768,len(tri));p=points[tri[start:end]].astype(np.float64)@scorer.inverse[:3,:3].T+scorer.inverse[:3,3]
   if not np.isfinite(p).all():raise ValueError('nonfinite model-frame patch triangle')
   normal=np.cross(p[:,1]-p[:,0],p[:,2]-p[:,0]);norm=np.linalg.norm(normal,axis=1);good=norm>0
   ny[start:end][good]=np.abs(normal[good,1])/norm[good]
   residuals[start:end]=np.max(np.abs(p[:,:,1]-(plane[0]*p[:,:,0]+plane[1]*p[:,:,2]+plane[2])),axis=1)
   within[start:end]=(p[:,:,1].min(1)>=lo[1])&(p[:,:,1].max(1)<=hi[1])&(p[:,:,0].max(1)>=lo[0])&(p[:,:,0].min(1)<=hi[0])&(p[:,:,2].max(1)>=lo[2])&(p[:,:,2].min(1)<=hi[2])
  component=cls.from_candidates(original,tri,ny,within,initial_support_cell_ids,residuals,plane,fit_receipt);scorer.check()
  component.receipt.update({'patchGameBounds':np.column_stack((lo,hi)).reshape(-1).tolist(),'patchRule':'fixed route XZ envelope plus0.8m; nominal Y[-0.25,0.25], never grown after contact','candidateCap':2000000,'fullReferenceAdjacencyBuilt':False,'fullReferenceTransformedCopy':False,'originalMeshMTime':int(mesh.GetMTime())})
  transform=np.asarray(scorer.transform,dtype=np.float64).copy();transform.setflags(write=False)
  component.receipt['referenceTransformSHA256']=hashlib.sha256(transform.tobytes()).hexdigest()
  return cls(component.ground_cell_ids,component.receipt,scorer.surface,mesh,int(mesh.GetMTime()),transform,component.plane_coefficients)
