"""SOURCE ONLY: native fixed15 marking + exact-XYZ adjacency, not floor truth.
Connectivity/from_scorer adapted from pinned GroundSupport; original unchanged.
No native library loads at module import. Only explicit admitted construction loads.
"""
import ctypes, hashlib, pathlib, stat
import numpy as np
import vtk
from vtk.util.numpy_support import vtk_to_numpy
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components
from ground_support import GroundSupport, GroundSupportUnavailable

MODE='recast-signed15-exact-xyz-v1'
POLICY='published-rcMarkWalkableTriangles-fixed15-initial-eligibility-v1'

class NativeTriangleEligibility:
 def __init__(self,library_path,expected_sha256):
  if ctypes.sizeof(ctypes.c_int)!=4 or ctypes.sizeof(ctypes.c_float)!=4:raise RuntimeError('requires 32-bit C int/float ABI')
  p=pathlib.Path(library_path)
  if p.is_symlink() or not stat.S_ISREG(p.stat().st_mode):raise ValueError('regular native classifier required')
  actual=hashlib.sha256(p.read_bytes()).hexdigest()
  if actual!=expected_sha256:raise RuntimeError('native classifier hash mismatch')
  self.library=ctypes.CDLL(str(p.resolve()))
  version=self.library.coffee_mark_walkable_15_abi_version;version.argtypes=[];version.restype=ctypes.c_int
  angle=self.library.coffee_mark_walkable_15_slope_degrees;angle.argtypes=[];angle.restype=ctypes.c_float
  if version()!=1 or angle()!=15.:raise RuntimeError('native classifier ABI/policy mismatch')
  self.mark=self.library.coffee_mark_walkable_15
  self.mark.argtypes=[ctypes.POINTER(ctypes.c_float),ctypes.c_int,ctypes.POINTER(ctypes.c_int),ctypes.c_int,ctypes.POINTER(ctypes.c_ubyte)]
  self.mark.restype=ctypes.c_int
  self.receipt={'policy':POLICY,'wrapperSHA256':actual,'abiVersion':1,'slopeDegrees':15.,'normalPredicate':'signed normalY > cosf(15/180*RC_PI)','inputPrecision':'float32 as frozen planner','initialTriangleMarkingOnly':True}
 def classify(self,vertex_coordinates,triangle_vertex_ids):
  points=np.asarray(vertex_coordinates);tri=np.asarray(triangle_vertex_ids)
  if points.dtype!=np.float64 or points.ndim!=2 or points.shape[1]!=3 or not np.isfinite(points).all():raise ValueError('finite original float64 vertices required')
  if tri.ndim!=2 or tri.shape[1]!=3 or not np.issubdtype(tri.dtype,np.integer) or np.any(tri<0) or np.any(tri>=len(points)):raise ValueError('invalid original triangle IDs')
  if len(points)>2000000 or len(tri)>2000000:raise ValueError('bounded classifier cardinality exceeded')
  vertices=np.ascontiguousarray(points,dtype=np.float32);triangles=np.ascontiguousarray(tri,dtype=np.int32)
  if not np.isfinite(vertices).all():raise ValueError('float32 vertex conversion overflow')
  mask=np.zeros(len(triangles),dtype=np.uint8)
  if len(triangles):
   code=self.mark(vertices.ctypes.data_as(ctypes.POINTER(ctypes.c_float)),len(vertices),triangles.ctypes.data_as(ctypes.POINTER(ctypes.c_int)),len(triangles),mask.ctypes.data_as(ctypes.POINTER(ctypes.c_ubyte)))
   if code!=0:raise RuntimeError('native triangle eligibility failed: '+str(code))
  if np.any(mask>1):raise RuntimeError('invalid native eligibility mask')
  return mask.astype(bool)

class NativePlannerGroundSupport(GroundSupport):
 @classmethod
 def from_candidates(cls,cell_ids,triangle_vertex_ids,normal_y_absolute,eligible_bounds,seed_ids,*,vertex_coordinates,native_classifier):
  ids=np.asarray(cell_ids);tri=np.asarray(triangle_vertex_ids);ny=np.asarray(normal_y_absolute,float);bounds=np.asarray(eligible_bounds,bool);seeds=np.asarray(seed_ids)
  if ids.ndim!=1 or not np.issubdtype(ids.dtype,np.integer) or len(ids)>2000000 or len(np.unique(ids))!=len(ids) or np.any(ids<0):raise ValueError('invalid bounded original cell IDs')
  if tri.shape!=(len(ids),3) or not np.issubdtype(tri.dtype,np.integer) or np.any(tri<0) or ny.shape!=(len(ids),)or bounds.shape!=(len(ids),):raise ValueError('invalid candidate triangle data')
  if seeds.shape!=(9,)or not np.issubdtype(seeds.dtype,np.integer) or np.any(seeds<0):raise GroundSupportUnavailable('all nine valid initial support IDs required')
  # Native published rcMarkWalkableTriangles owns eligibility; no Python normal predicate.
  slope=native_classifier.classify(vertex_coordinates,tri)
  points=np.asarray(vertex_coordinates)
  if points.dtype!=np.float64 or points.ndim!=2 or points.shape[1]!=3 or not np.isfinite(points).all():raise ValueError('finite original float64 points required')
  unique,canonical=np.unique(points,axis=0,return_inverse=True)
  tri=canonical[tri]
  keep=slope&bounds;kept_ids=ids[keep];kept_tri=tri[keep]
  if not len(kept_ids):raise GroundSupportUnavailable('no slope-eligible ground candidates')
  unique_seeds=np.unique(seeds);id_order=np.argsort(kept_ids);sorted_ids=kept_ids[id_order];pos=np.searchsorted(sorted_ids,unique_seeds)
  if np.any(pos>=len(sorted_ids)) or not np.array_equal(sorted_ids[np.minimum(pos,len(sorted_ids)-1)],unique_seeds):raise GroundSupportUnavailable('initial support seed absent, outside patch or not slope eligible')
  # An edge means the same two exact original-coordinate keys. No geometry welding,
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
  receipt={'scope':'Independent simulation-world ground contact component, not sensed clearance','candidateCells':int(len(ids)),'slopeEligibleCells':int(slope.sum()),'patchAndSlopeEligibleCells':int(keep.sum()),'edgeConnectedComponents':int(component_count),'groundCellCount':int(len(accepted)),'initialSupportSeedIDs':seeds.tolist(),'uniqueInitialSeedCount':int(len(unique_seeds)),'allSeedsRequired':True,'maximumSlopeDegrees':15.,'normalConvention':'Recast signed source-frame Y normal; original winding and float32 inputs','connectivity':'shared exact original float64 XYZ endpoint edges; SciPy connected_components directed=False','groundAdjacencyMode':MODE,'triangleEligibilityPolicy':POLICY,'nativeEligibility':native_classifier.receipt,'initialMarkingIsFinalWalkability':False,'originalFaceIDsPreserved':True,'originalMeshCoordinatesChanged':False,'coincidentSeparateSheetsDisambiguated':False,'stepUpAllowanceMetres':0.,'positionWelding':False,'referenceGeometryMaySteer':False,'physicalAuthority':False,'lowHeightAloneAdmitsGround':False,'semanticGroundLabelsAvailable':False}
  return cls(accepted,receipt)
 @classmethod
 def from_scorer(cls,scorer,frozen_route_points,initial_support_cell_ids,*,native_classifier):
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
  component=cls.from_candidates(original,tri,ny,within,initial_support_cell_ids,vertex_coordinates=points,native_classifier=native_classifier);scorer.check()
  component.receipt.update({'patchGameBounds':np.column_stack((lo,hi)).reshape(-1).tolist(),'patchRule':'fixed route XZ envelope plus0.8m; nominal Y[-0.25,0.25], never grown after contact','candidateCap':2000000,'fullReferenceAdjacencyBuilt':False,'fullReferenceTransformedCopy':False,'originalMeshMTime':int(mesh.GetMTime())})
  transform=np.asarray(scorer.transform,dtype=np.float64).copy();transform.setflags(write=False)
  component.receipt['referenceTransformSHA256']=hashlib.sha256(transform.tobytes()).hexdigest()
  return cls(component.ground_cell_ids,component.receipt,scorer.surface,mesh,int(mesh.GetMTime()),transform)
