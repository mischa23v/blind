"""Same shared ground classification; tiled native bounds query performed once."""
from pathlib import Path
import sys,hashlib
import numpy as np
from vtk.util.numpy_support import vtk_to_numpy
HERE=Path(__file__).resolve().parent;GAME=HERE.parent/'blind-split-candidate-game-03'
sys.path.insert(0,str(HERE))
from tiled_bounds import find_cells_tiled
import importlib.util as _iu
_resource_path=HERE/'ground_classifier_resource.py'
_resource_spec=_iu.spec_from_file_location('conditioned59_ground_classifier_resource',_resource_path)
_resource=_iu.module_from_spec(_resource_spec);sys.modules[_resource_spec.name]=_resource;_resource_spec.loader.exec_module(_resource)
GroundSupport,CANDIDATE_CAP=_resource.GroundSupport,_resource.CANDIDATE_CAP

def shared_ground(scorer,paths,initial_support_cell_ids,initial_support_points,progress):
    scorer.check();route=np.vstack(paths)
    if route.ndim!=2 or route.shape[1]!=3 or len(route)<2 or not np.isfinite(route).all():raise ValueError('finite fixed route required')
    lo=np.array([route[:,0].min()-.8,-.25,route[:,2].min()-.8]);hi=np.array([route[:,0].max()+.8,.25,route[:,2].max()+.8])
    corners=np.array([[x,y,z]for x in(lo[0],hi[0])for y in(lo[1],hi[1])for z in(lo[2],hi[2])])
    reference=corners@scorer.transform[:3,:3].T+scorer.transform[:3,3]
    bounds=np.column_stack((reference.min(0),reference.max(0))).reshape(-1)
    original,query=find_cells_tiled(scorer.surface.locator,bounds,check=scorer.check,unique_cap=CANDIDATE_CAP)
    progress({'candidateCells':len(original),'candidateCap':CANDIDATE_CAP,'gameBounds':np.column_stack((lo,hi)).reshape(-1).tolist(),
        'nativeQuery':query,'capIsComputeGuardNotPhysicalConstraint':True,'sameReferenceBoundsAndSortedIDs':True})
    # Exact extraction/within/classification logic from frozen v3 from_scorer.
    mesh=scorer.mesh
    if mesh.GetNumberOfCells()!=mesh.GetNumberOfPolys() or np.any(original<0) or np.any(original>=mesh.GetNumberOfCells()):raise ValueError('triangle-only original mesh required')
    offsets=vtk_to_numpy(mesh.GetPolys().GetOffsetsArray());conn=vtk_to_numpy(mesh.GetPolys().GetConnectivityArray());points=vtk_to_numpy(mesh.GetPoints().GetData())
    if not np.all(offsets[original+1]-offsets[original]==3):raise ValueError('nontriangle candidate')
    tri=conn[offsets[original,None]+np.arange(3)];vertex_ids=np.unique(tri)
    if np.any(vertex_ids<0)or np.any(vertex_ids>=len(points)):raise ValueError('invalid original vertex IDs')
    model=points[vertex_ids].astype(np.float64)@scorer.inverse[:3,:3].T+scorer.inverse[:3,3]
    local=np.searchsorted(vertex_ids,tri);within=np.zeros(len(tri),bool)
    for start in range(0,len(tri),32768):
        stop=min(start+32768,len(tri));p=model[local[start:stop]]
        within[start:stop]=(p[:,:,1].min(1)>=lo[1])&(p[:,:,1].max(1)<=hi[1])&(p[:,:,0].max(1)>=lo[0])&(p[:,:,0].min(1)<=hi[0])&(p[:,:,2].max(1)>=lo[2])&(p[:,:,2].min(1)<=hi[2])
    component=GroundSupport.from_geometry(original,tri,vertex_ids,model,within,initial_support_cell_ids);scorer.check()
    transform=np.array(scorer.transform,dtype=float,copy=True);transform.setflags(write=False)
    component.receipt.update(patchGameBounds=np.column_stack((lo,hi)).reshape(-1).tolist(),patchRule='frozen route envelope plus0.8m; Y[-.25,.25]',fullReferenceAdjacencyBuilt=False,fullReferenceTransformedCopy=False,originalMeshMTime=int(mesh.GetMTime()),referenceTransformSHA256=hashlib.sha256(transform.tobytes()).hexdigest())
    component.receipt['originalInitialSupportPointsModelXYZ']=np.asarray(initial_support_points,float).tolist()
    component.receipt['groundSetupQuery']=query;component.receipt['onlyClassifierSourceChange']='stage59 nonrecursive sliver normal conditioning after unchanged52 baseline;2mm residual retained'
    return GroundSupport(component.ground_cell_ids,component.receipt,scorer.surface,mesh,int(mesh.GetMTime()),transform,component.plane_coefficients)
