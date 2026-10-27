"""World-only planar support, with local residual-bounded original ground faces.

A broad initial edge-connected low-slope component supplies geometry for ONE
fixed robust world-support plane and fixed 20 cm local classification patches.
No contact-specific refit, route feedback, mesh modification or missing-surface
fill. The 2 mm local residual is an explicit unresolved microgeometry band,
not proof that objects below it can be detected. Non-ground triangles remain.
"""
from dataclasses import dataclass
import math, hashlib
import numpy as np
from scipy.optimize import least_squares
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components
from scipy.spatial import cKDTree
import vtk
from vtk.util.numpy_support import vtk_to_numpy

RESIDUAL = .002
PLANE_SLOPE = 5.
RAW_SLOPE = 45.
PATCH_HALF_WIDTH = .10
PATCH_LATTICE = .10
CANDIDATE_CAP = 6_000_000

SLIVER_QUALITY = .01

def triangle_quality(q):
    """Minimum altitude/longest3Dedge; dimensionless geometry conditioning."""
    q=np.asarray(q,float);e=np.stack((q[:,1]-q[:,0],q[:,2]-q[:,1],q[:,0]-q[:,2]),axis=1)
    longest2=np.max(np.sum(e*e,axis=2),axis=1);area2=np.linalg.norm(np.cross(q[:,1]-q[:,0],q[:,2]-q[:,0]),axis=1)
    return np.divide(area2,longest2,out=np.zeros(len(q)),where=longest2>0)

def edge_keys(tri):
    t=np.asarray(tri,np.uint64)
    if t.size and t.max()>=2**32:raise ValueError('vertex ID packing bound')
    return np.concatenate([(np.minimum(t[:,a],t[:,b])<<np.uint64(32))|np.maximum(t[:,a],t[:,b])for a,b in((0,1),(1,2),(2,0))])

def conditioned_additions(ids,tri,within,quality,fit_ok,patch_tilt,residual,base_ids):
    """One pass against frozen BASE accepted edges; no candidate-fed propagation."""
    ids=np.asarray(ids);base_mask=np.isin(ids,base_ids,assume_unique=True)
    candidate=(~base_mask)&within&np.isfinite(quality)&(quality>0)&(quality<SLIVER_QUALITY)&fit_ok&np.isfinite(patch_tilt)&(patch_tilt<=PLANE_SLOPE)&np.isfinite(residual)&(residual<=RESIDUAL)
    ix=np.flatnonzero(candidate)
    if not len(ix):return np.array([],dtype=ids.dtype),{'conditioningCandidates':0,'edgeAdjacentAdmissions':0}
    keys=np.unique(edge_keys(tri[base_mask]));ck=edge_keys(tri[ix]);loc=np.searchsorted(keys,ck);hit=(loc<len(keys))
    if len(keys):hit&=keys[np.minimum(loc,len(keys)-1)]==ck
    else:hit[:]=False
    adjacent=hit.reshape(3,len(ix)).any(0);added=ids[ix[adjacent]]
    return added,{'conditioningCandidates':len(ix),'edgeAdjacentAdmissions':len(added),'candidateWithoutBaselineEdge':int((~adjacent).sum()),'qualityCriterion':'0 < minimumAltitude/longest3DEdge <0.01','independentPatchTiltMaxDegrees':PLANE_SLOPE,'unchangedAllVertexResidualMaxMetres':RESIDUAL,'adjacency':'exact shared original vertex-ID edge with baseline accepted component only','onePassNonRecursive':True,'newFacesEnteredTraining':False,'addedOriginalFaceIDs':added.tolist(),'sub2mmVerticalRidgesRemainAmbiguous':True}

class GroundSupportUnavailable(RuntimeError): pass

def robust_plane(points, sample_cap):
    p=np.asarray(points,float)
    if p.ndim!=2 or p.shape[1]!=3 or len(p)<3 or not np.isfinite(p).all():
        raise GroundSupportUnavailable('finite spanning floor points required')
    # Stable original-ID ordering is supplied by the caller. Sampling is only
    # for fitting; every candidate vertex is checked, never discarded.
    q=p if len(p)<=sample_cap else p[np.linspace(0,len(p)-1,sample_cap,dtype=np.int64)]
    centre=q[:,[0,2]].mean(axis=0)
    A=np.column_stack((q[:,0]-centre[0],q[:,2]-centre[1],np.ones(len(q))))
    start,_,rank,singular=np.linalg.lstsq(A,q[:,1],rcond=None)
    if rank!=3 or singular[-1]<=1e-8: raise GroundSupportUnavailable('floor patch rank deficient')
    fit=least_squares(lambda x:A@x-q[:,1],start,loss='soft_l1',f_scale=RESIDUAL,
                      max_nfev=100,ftol=1e-10,xtol=1e-10,gtol=1e-10)
    if not fit.success or not np.isfinite(fit.x).all():raise GroundSupportUnavailable('floor fit failed')
    a,b,c=fit.x;tilt=math.degrees(math.atan(math.hypot(a,b)))
    if tilt>PLANE_SLOPE:raise GroundSupportUnavailable('fitted floor slope exceeds declared 5 degrees')
    plane=np.array([a,b,c-a*centre[0]-b*centre[1]])
    residuals=p[:,1]-(plane[0]*p[:,0]+plane[1]*p[:,2]+plane[2])
    return plane,{'points':len(p),'fitPoints':len(q),'tiltDegrees':tilt,
                  'absoluteResidualQuantilesMetres':dict(zip(['p0','p50','p95','p99','p100'],map(float,np.quantile(np.abs(residuals),[0,.5,.95,.99,1])))),
                  'residualAbove2mmPoints':int((np.abs(residuals)>RESIDUAL).sum()),'fitEvaluations':int(fit.nfev)}

def seeded_component(ids,tri,keep,seeds):
    kept_ids=ids[keep];kept_tri=tri[keep]
    if not len(kept_ids):raise GroundSupportUnavailable('no eligible ground candidates')
    unique_seeds=np.unique(seeds);order_ids=np.argsort(kept_ids);sorted_ids=kept_ids[order_ids]
    pos=np.searchsorted(sorted_ids,unique_seeds)
    if np.any(pos>=len(sorted_ids)) or not np.array_equal(sorted_ids[np.minimum(pos,len(sorted_ids)-1)],unique_seeds):
        raise GroundSupportUnavailable('one of nine initial support faces is ineligible')
    n=len(kept_ids)
    edges=np.concatenate((kept_tri[:,[0,1]],kept_tri[:,[1,2]],kept_tri[:,[2,0]]));edges.sort(axis=1)
    owner=np.tile(np.arange(n,dtype=np.int32),3);order=np.lexsort((edges[:,1],edges[:,0]));edges=edges[order];owner=owner[order]
    same=np.all(edges[1:]==edges[:-1],axis=1)
    graph=coo_matrix((np.ones(int(same.sum()),np.uint8),(owner[:-1][same],owner[1:][same])),shape=(n,n)).tocsr()
    del edges,owner,order,same,kept_tri
    count,labels=connected_components(graph,directed=False,return_labels=True)
    if not np.all(labels[order_ids[pos]]==labels[order_ids[pos]][0]):
        raise GroundSupportUnavailable('initial support seeds are disconnected')
    result=np.sort(kept_ids[labels==labels[order_ids[pos]][0]]).astype(np.int64,copy=False)
    return result,int(count)

@dataclass(frozen=True)
class GroundSupport:
    ground_cell_ids: np.ndarray
    receipt: dict
    surface: object=None
    mesh: object=None
    mesh_revision: int|None=None
    reference_transform: np.ndarray|None=None
    plane_coefficients: np.ndarray|None=None
    def check(self):
        if self.surface is None or self.mesh is None or self.reference_transform is None:raise GroundSupportUnavailable('unbound reference owner')
        if self.surface.mesh is not self.mesh or self.mesh.GetMTime()!=self.mesh_revision or self.surface.locator.GetDataSet()!=self.mesh:raise GroundSupportUnavailable('ground reference owner changed')
        if getattr(self.surface,'errors',[]):raise GroundSupportUnavailable('reference locator error')
    def assert_matches(self,surface,transform=None):
        self.check()
        if surface is not self.surface or (transform is not None and not np.array_equal(transform,self.reference_transform)):raise GroundSupportUnavailable('wrong reference surface or transform')
    def plane_height(self,x,z):
        if self.mesh is not None:self.check()
        if self.plane_coefficients is None or not np.isfinite([x,z]).all():raise GroundSupportUnavailable('invalid plane query')
        a,b,c=self.plane_coefficients;return float(a*x+b*z+c)
    def is_ground(self,cell_id):
        if self.mesh is not None:self.check()
        if isinstance(cell_id,bool) or not isinstance(cell_id,(int,np.integer)):return False
        i=int(np.searchsorted(self.ground_cell_ids,int(cell_id)))
        return i<len(self.ground_cell_ids) and int(self.ground_cell_ids[i])==int(cell_id)
    def contains(self,cell_id):return self.is_ground(cell_id)
    def contains_all(self,cell_ids):
        a=np.asarray(cell_ids);return a.ndim==1 and a.size>0 and all(self.is_ground(x)for x in a)
    @classmethod
    def from_geometry(cls,cell_ids,triangles,vertex_ids,model_points,within,seed_ids):
        ids=np.asarray(cell_ids);tri=np.asarray(triangles);vid=np.asarray(vertex_ids);p=np.asarray(model_points,float);within=np.asarray(within,bool);seeds=np.asarray(seed_ids)
        if ids.ndim!=1 or len(ids)>CANDIDATE_CAP or not np.issubdtype(ids.dtype,np.integer) or np.any(ids<0) or len(np.unique(ids))!=len(ids):raise ValueError('invalid candidate IDs')
        if tri.shape!=(len(ids),3) or not np.issubdtype(tri.dtype,np.integer) or within.shape!=(len(ids),):raise ValueError('invalid triangles or bounds')
        if vid.ndim!=1 or not np.issubdtype(vid.dtype,np.integer) or np.any(np.diff(vid)<=0) or p.shape!=(len(vid),3) or not np.isfinite(p).all():raise ValueError('invalid original vertex table')
        if seeds.shape!=(9,) or not np.issubdtype(seeds.dtype,np.integer) or np.any(seeds<0):raise GroundSupportUnavailable('all nine initial support IDs required')
        local=np.searchsorted(vid,tri)
        if np.any(local>=len(vid)) or not np.array_equal(vid[np.minimum(local,len(vid)-1)],tri):raise ValueError('missing original vertices')
        ny=np.full(len(ids),np.nan);quality=np.zeros(len(ids));centres=np.empty((len(ids),2))
        for start in range(0,len(ids),32768):
            stop=min(start+32768,len(ids));q=p[local[start:stop]];quality[start:stop]=triangle_quality(q);normal=np.cross(q[:,1]-q[:,0],q[:,2]-q[:,0]);norm=np.linalg.norm(normal,axis=1);ok=norm>0
            ny[start:stop][ok]=np.abs(normal[ok,1])/norm[ok];centres[start:stop]=q[:,:,[0,2]].mean(axis=1)
        # Training selection exactly preserves the first v2 model; it is never
        # expanded from a later contact or from a successful-route condition.
        training_keep=within&np.isfinite(ny)&(ny>=math.cos(math.radians(PLANE_SLOPE)))
        #52: only deferred seed cases change bootstrap admission order.
        eligible_seed_ids=np.intersect1d(np.asarray(seeds,np.int64),ids[training_keep])
        deferred_seed_ids=np.setdiff1d(np.asarray(seeds,np.int64),eligible_seed_ids)
        if not len(eligible_seed_ids):raise GroundSupportUnavailable('all original seeds ineligible for training')
        # Rank/noncollinearity is assessed from the whole coherent training
        # component by the unchanged robust_plane, not by an arbitrary seed count.
        training_ids,training_components=seeded_component(ids,tri,training_keep,eligible_seed_ids)
        training_mask=np.isin(ids,training_ids,assume_unique=True)
        #Original extraction retained: shared vertices supported by eligible faces
        #are legitimate evidence; no ineligible face is admitted to training.
        training_vertex_indices=np.unique(local[training_mask]);training_points=p[training_vertex_indices]
        broad,broad_stats=robust_plane(training_points,50000)
        tree=cKDTree(training_points[:,[0,2]])
        tiles=np.floor(centres/PATCH_LATTICE).astype(np.int64)
        unique_tiles,inverse=np.unique(tiles,axis=0,return_inverse=True)
        max_residual=np.full(len(ids),np.inf);local_fit_ok=np.zeros(len(ids),bool)
        patch_stats=[];patch_tilts=np.full(len(unique_tiles),np.inf);ordered=np.argsort(inverse,kind='stable');starts=np.searchsorted(inverse[ordered],np.arange(len(unique_tiles)+1))
        for k,tile in enumerate(unique_tiles):
            members=ordered[starts[k]:starts[k+1]]
            centre=(tile+.5)*PATCH_LATTICE
            neighbours=tree.query_ball_point(centre,PATCH_HALF_WIDTH*math.sqrt(2))
            neighbours=np.asarray(sorted(neighbours),dtype=np.int64)
            if len(neighbours):neighbours=neighbours[np.all(np.abs(training_points[neighbours][:,[0,2]]-centre)<=PATCH_HALF_WIDTH+1e-12,axis=1)]
            try:plane,stats=robust_plane(training_points[neighbours],4096)
            except GroundSupportUnavailable as e:
                patch_stats.append({'tile':tile.tolist(),'status':'unknown','reason':str(e),'trainingPoints':len(neighbours)});continue
            for start in range(0,len(members),32768):
                take=members[start:start+32768];q=p[local[take]]
                max_residual[take]=np.max(np.abs(q[:,:,1]-(plane[0]*q[:,:,0]+plane[1]*q[:,:,2]+plane[2])),axis=1)
                local_fit_ok[take]=True
            patch_tilts[k]=stats['tiltDegrees'];patch_stats.append({'tile':tile.tolist(),'status':'fit','planeYEqualsAXPlusBZPlusC':plane.tolist(),**stats})
        raw_guard=np.isfinite(ny)&(ny>=math.cos(math.radians(RAW_SLOPE)))
        residual_ok=local_fit_ok&(max_residual<=RESIDUAL)
        keep=training_mask | (within&raw_guard&residual_ok)
        accepted,components=seeded_component(ids,tri,keep,seeds)
        baseline_accepted=accepted.copy();added,conditioning=conditioned_additions(ids,tri,within,quality,local_fit_ok,patch_tilts[inverse],max_residual,baseline_accepted)
        accepted=np.union1d(baseline_accepted,added);conditioning['baselineGroundCells']=len(baseline_accepted);conditioning['baselineIDsSHA256']=hashlib.sha256(baseline_accepted.tobytes()).hexdigest()
        accepted.setflags(write=False);broad.setflags(write=False)
        receipt={'scope':'controlled planar simulation support with local residual-bounded original ground faces; not sensing clearance',
            'normalConditioning':conditioning,'candidateCells':len(ids),'candidateCap':CANDIDATE_CAP,'groundCellCount':len(accepted),
            'initialSupportSeedIDs':seeds.tolist(),'allSeedsRequired':True,'seedAdmissionOrder':'eligible coherent noncollinear subset bootstraps fits, ALL original seeds required after unchanged local recovery','eligibleTrainingSeedIDs':eligible_seed_ids.tolist(),'deferredSeedIDs':deferred_seed_ids.tolist(),'deferredSeedFacesExcludedFromTraining':True,'eligibleFaceSharedVerticesRetained':True,'recoveredOriginalSeedIDs':np.intersect1d(accepted,deferred_seed_ids).tolist(),'trainingGroundCells':len(training_ids),'trainingEdgeComponents':training_components,
            'trainingVertices':len(training_points),'trainingRule':'unchanged v2 seed-connected original faces with absolute Y normal slope <=5 degrees',
            'broadPlaneCoefficientsYEqualsAXPlusBZPlusC':broad.tolist(),'planeCoefficientsYEqualsAXPlusBZPlusC':broad.tolist(),'broadPlaneFit':broad_stats,
            'fitMethod':'SciPy least_squares soft_l1, initial NumPy lstsq, deterministic original-ID ordered sampling',
            'fitScaleMetres':RESIDUAL,'maximumLocalEveryVertexResidualMetres':RESIDUAL,'maximumFitSlopeDegrees':PLANE_SLOPE,'rawSteepEdgeGuardDegrees':RAW_SLOPE,
            'patchWidthMetres':2*PATCH_HALF_WIDTH,'patchLatticeMetres':PATCH_LATTICE,'patchOriginModelXZ':[0.,0.],
            'patchAssignment':'original triangle centroid; every original triangle vertex tested against assigned local plane',
            'localFitCells':int(local_fit_ok.sum()),'localResidualEligibleCells':int(residual_ok.sum()),'rawGuardEligibleCells':int(raw_guard.sum()),
            'patchAndLocalEligibleCells':int(keep.sum()),'edgeConnectedComponents':components,'patchFits':patch_stats,
            'originalSeedComponentRetained':True,'localResidualGuardAppliesToRecoveredFacesOnly':True,'newlyEligibleFaces':int((keep&~training_mask).sum()),'newlyConnectedGroundFaces':int(len(accepted)-len(training_ids)),
            'connectivity':'original vertex-ID shared edges only; SciPy connected_components undirected',
            'fitFrozenBeforeMotion':True,'positionWelding':False,'surfaceGeometryChanged':False,'stepUpAllowanceMetres':0.,
            'physicalAuthority':False,'referenceGeometryMaySteer':False,'semanticGroundLabelsAvailable':False,
            'unresolvedMicrogeometryBandMetres':RESIDUAL,'lowObjectsWithinBandNotProvenDetectable':True,
            'groundResidualDoesNotEstablishContinuousSupport':True}
        return cls(accepted,receipt,plane_coefficients=broad)
    @classmethod
    def from_scorer(cls,scorer,frozen_route_points,initial_support_cell_ids,initial_support_points=None):
        scorer.check();route=np.asarray(frozen_route_points,float)
        if route.ndim!=2 or route.shape[1]!=3 or len(route)<2 or not np.isfinite(route).all():raise ValueError('finite fixed route required')
        lo=np.array([route[:,0].min()-.8,-.25,route[:,2].min()-.8]);hi=np.array([route[:,0].max()+.8,.25,route[:,2].max()+.8])
        corners=np.array([[x,y,z]for x in(lo[0],hi[0])for y in(lo[1],hi[1])for z in(lo[2],hi[2])]);reference=corners@scorer.transform[:3,:3].T+scorer.transform[:3,3]
        found=vtk.vtkIdList();scorer.surface.locator.FindCellsWithinBounds(np.column_stack((reference.min(0),reference.max(0))).reshape(-1),found);scorer.check()
        if found.GetNumberOfIds()>CANDIDATE_CAP:raise GroundSupportUnavailable('candidate cap')
        original=np.unique(np.fromiter((found.GetId(i)for i in range(found.GetNumberOfIds())),np.int64,count=found.GetNumberOfIds()))
        mesh=scorer.mesh
        if mesh.GetNumberOfCells()!=mesh.GetNumberOfPolys() or np.any(original<0) or np.any(original>=mesh.GetNumberOfCells()):raise ValueError('triangle-only original mesh required')
        offsets=vtk_to_numpy(mesh.GetPolys().GetOffsetsArray());conn=vtk_to_numpy(mesh.GetPolys().GetConnectivityArray());points=vtk_to_numpy(mesh.GetPoints().GetData())
        if not np.all(offsets[original+1]-offsets[original]==3):raise ValueError('nontriangle candidate')
        tri=conn[offsets[original,None]+np.arange(3)];vertex_ids=np.unique(tri)
        if np.any(vertex_ids<0)or np.any(vertex_ids>=len(points)):raise ValueError('invalid original vertex IDs')
        # Only local patch vertices are copied/transformed, never the full mesh.
        model=points[vertex_ids].astype(np.float64)@scorer.inverse[:3,:3].T+scorer.inverse[:3,3]
        local=np.searchsorted(vertex_ids,tri);within=np.zeros(len(tri),bool)
        for start in range(0,len(tri),32768):
            stop=min(start+32768,len(tri));p=model[local[start:stop]]
            within[start:stop]=(p[:,:,1].min(1)>=lo[1])&(p[:,:,1].max(1)<=hi[1])&(p[:,:,0].max(1)>=lo[0])&(p[:,:,0].min(1)<=hi[0])&(p[:,:,2].max(1)>=lo[2])&(p[:,:,2].min(1)<=hi[2])
        component=cls.from_geometry(original,tri,vertex_ids,model,within,initial_support_cell_ids);scorer.check()
        transform=np.array(scorer.transform,dtype=float,copy=True);transform.setflags(write=False)
        component.receipt.update(patchGameBounds=np.column_stack((lo,hi)).reshape(-1).tolist(),patchRule='frozen route envelope plus0.8m; Y[-.25,.25]',fullReferenceAdjacencyBuilt=False,fullReferenceTransformedCopy=False,originalMeshMTime=int(mesh.GetMTime()),referenceTransformSHA256=hashlib.sha256(transform.tobytes()).hexdigest())
        if initial_support_points is not None:component.receipt['originalInitialSupportPointsModelXYZ']=np.asarray(initial_support_points,float).tolist()
        return cls(component.ground_cell_ids,component.receipt,scorer.surface,mesh,int(mesh.GetMTime()),transform,component.plane_coefficients)
