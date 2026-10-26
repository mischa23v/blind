"""Conservative box-local triangle bounds before unchanged VTK exact checks.

Only all-three-vertex separation from one padded box axis can reject a triangle.
The original mesh arrays are zero-copy views and never edited. Ground classifier,
physics, body/margin sweeps, contact counts/order and VTK exact predicates remain.
Ground contact counts stay unmeasured. No measured speedup is asserted here.
"""
from pathlib import Path
import sys
import time as _profile_time
import hashlib as _profile_hashlib
import numpy as np
import vtk
from vtk.util.numpy_support import vtk_to_numpy
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'ground-vector-v5'))
from oriented_ground_vector_container import GroundVectorReferenceContainer,GeometryFailure

# Verified primary source: VTK v9.3.1 vtkHexahedron.cxx lines24-27,155-168.
VTK_SOURCE='https://raw.githubusercontent.com/Kitware/VTK/v9.3.1/Common/DataModel/vtkHexahedron.cxx'
OUTSIDE_PARAM_TOLERANCE=1e-6
NEWTON_CONVERGENCE=1e-5
CHUNK_TRIANGLES=32768

ORIGINAL_V6_SHA256='7005ab752d855edfdb1295b401ea8ad9d66516a5813f716f1a7818677bb1c222'
_profile_original=ROOT/'ground-obb-v6/oriented_ground_obb_container.py'
if _profile_hashlib.sha256(_profile_original.read_bytes()).hexdigest()!=ORIGINAL_V6_SHA256:
    raise RuntimeError('frozen v6 instrumentation source changed')
PROFILE_PHASES=('validationTransformBoxSetup', 'nativeFindCellsWithinBounds', 'getIdArrayExtraction', 'vectorizedGroundSplit', 'zeroCopyOBBFilter', 'exactPredicateLoopAndSetup', 'resultAssemblyTail')

class ProfiledGroundOBBReferenceContainer(GroundVectorReferenceContainer):
    def __init__(self,*args,**kwargs):
        self.profile_rows=[];self._profile_active=None
        super().__init__(*args,**kwargs)
        if vtk.vtkVersion.GetVTKVersion()!='9.3.1':raise GeometryFailure('bounds tolerance is pinned to VTK 9.3.1')
        if self.mesh.GetNumberOfCells()!=self.mesh.GetNumberOfPolys():raise GeometryFailure('triangle-polydata cell indexing required')
        self._polys=self.mesh.GetPolys()
        self._vtk_arrays=(self.mesh.GetPoints().GetData(),self._polys.GetOffsetsArray(),self._polys.GetConnectivityArray())
        self._array_revisions=tuple(a.GetMTime()for a in self._vtk_arrays)
        self._points,self._offsets,self._connectivity=tuple(vtk_to_numpy(a)for a in self._vtk_arrays)
        if (self._points.shape!=(self.mesh.GetNumberOfPoints(),3) or self._points.dtype.kind!='f'
                or self._offsets.shape!=(self.mesh.GetNumberOfCells()+1,) or self._offsets.dtype.kind not in 'iu'
                or self._connectivity.ndim!=1 or self._connectivity.dtype.kind not in 'iu'
                or self._offsets[0]!=0 or self._offsets[-1]!=len(self._connectivity)):
            raise GeometryFailure('invalid zero-copy triangle arrays')
        for a in (self._points,self._offsets,self._connectivity):a.setflags(write=False)
        self._reference_coordinate_scale=max(1.,float(np.max(np.abs(self.mesh.GetBounds()))))
        if not np.isfinite(self._reference_coordinate_scale):raise GeometryFailure('nonfinite reference bounds')
        self.check()

    def check(self):
        _profile_check_started=_profile_time.perf_counter()
        try:
            super().check()
            if hasattr(self,'_vtk_arrays'):
                current=(self.mesh.GetPoints().GetData(),self.mesh.GetPolys().GetOffsetsArray(),self.mesh.GetPolys().GetConnectivityArray())
                if (self.mesh.GetPolys()!=self._polys or any(a!=b for a,b in zip(current,self._vtk_arrays))
                        or tuple(a.GetMTime()for a in current)!=self._array_revisions):
                    raise GeometryFailure('zero-copy mesh array owner or revision changed')
        finally:
            self._profile_note_nested('ownerCheck',_profile_check_started)

    def _filter_box_bounds(self,ids,q):
        """Stable mask only; no SAT replacement or triangle-intersection code."""
        self.check()
        edges=np.column_stack((q[1]-q[0],q[3]-q[0],q[4]-q[0]))
        lengths=np.linalg.norm(edges,axis=0)
        determinant=float(np.linalg.det(edges));condition=float(np.linalg.cond(edges))
        receipt={'kind':'all-three-vertices separated from one padded affine box axis',
            'vtkVersion':'9.3.1','outsideParamTolerance':OUTSIDE_PARAM_TOLERANCE,
            'newtonConvergence':NEWTON_CONVERGENCE,'source':VTK_SOURCE,
            'chunkTriangles':CHUNK_TRIANGLES,'originalGeometryChanged':False,
            'meshArrayCopies':False,'fallbackAllExact':False}
        # Preserve the original exact error/containment behavior in degenerate
        # numerical regimes rather than using a fast rejection to hide it.
        if not np.isfinite(condition) or condition>1e4 or abs(determinant)<=1e-18:
            receipt.update(fallbackAllExact=True,reason='ill-conditioned or tiny-volume affine box')
            return ids,receipt
        inverse=np.linalg.inv(edges)
        coordinate_scale=max(self._reference_coordinate_scale,float(np.max(np.abs(q))),float(lengths.sum()))
        numeric_pad=256*np.finfo(np.float64).eps*coordinate_scale
        reference_pad=(OUTSIDE_PARAM_TOLERANCE+NEWTON_CONVERGENCE)*float(lengths.sum())+numeric_pad
        param_pad=reference_pad*np.sum(np.abs(inverse),axis=1)
        if not np.isfinite(param_pad).all():raise GeometryFailure('nonfinite conservative box padding')
        receipt.update(referencePadding=reference_pad,numericalPadding=numeric_pad,
            parametricPadding=param_pad.tolist(),paddingRule='(1e-6+1e-5)*sum(referenceEdgeLengths)+256*float64eps*coordinateScale; inverse-row L1 mapping')
        keep=np.ones(len(ids),dtype=bool)
        for start in range(0,len(ids),CHUNK_TRIANGLES):
            stop=min(start+CHUNK_TRIANGLES,len(ids));take=ids[start:stop]
            first=self._offsets[take];last=self._offsets[take+1]
            if np.any(last-first!=3):raise GeometryFailure('non-ground reference cell is not a triangle')
            addresses=first[:,None]+np.arange(3)
            if np.any(addresses<0)or np.any(addresses>=len(self._connectivity)):raise GeometryFailure('invalid connectivity address')
            vertex_ids=self._connectivity[addresses]
            if np.any(vertex_ids<0)or np.any(vertex_ids>=len(self._points)):raise GeometryFailure('invalid original triangle vertex ID')
            points=self._points[vertex_ids].astype(np.float64,copy=False)
            if not np.isfinite(points).all():raise GeometryFailure('nonfinite original triangle points')
            local=(points-q[0])@inverse.T
            if not np.isfinite(local).all():raise GeometryFailure('nonfinite affine triangle coordinates')
            separated=np.any((local.max(axis=1)<-param_pad)|(local.min(axis=1)>1.+param_pad),axis=1)
            keep[start:stop]=~separated
        self.check()
        return ids[keep],receipt

    def contact_corners(self,corners):
        """One validated candidate array, one immutable-ground membership mask.

        Candidate cap precedes extraction/filtering; non-ground ordering and
        exact VTK checks remain unchanged. Ground contacts are unmeasured.
        """
        self._profile_begin()
        try:
            self.check()
            corners=np.asarray(corners,dtype=float)
            if corners.shape!=(8,3) or not np.isfinite(corners).all():
                raise ValueError('finite eight-corner hexahedron required')
            edges=np.column_stack((corners[1]-corners[0],corners[3]-corners[0],corners[4]-corners[0]))
            lengths=np.linalg.norm(edges,axis=0)
            if np.any(lengths<=0) or not np.isfinite(lengths).all():raise ValueError('positive OBB extents required')
            unit=edges/lengths
            if not np.allclose(unit.T@unit,np.eye(3),atol=1e-10,rtol=0) or np.linalg.det(unit)<=0:
                raise ValueError('proper orthogonal OBB required')
            v0=corners[0];x,y,z=edges.T
            expected=np.asarray([v0,v0+x,v0+x+y,v0+y,v0+z,v0+x+z,v0+x+y+z,v0+y+z])
            if not np.allclose(corners,expected,atol=1e-10,rtol=0):raise ValueError('VTK OBB corner order mismatch')
            q=corners@self.transform[:3,:3].T+self.transform[:3,3]
            if not np.isfinite(q).all():raise GeometryFailure('nonfinite transformed OBB')
            for i,p in enumerate(q):self.box.GetPoints().SetPoint(i,p)
            self.box.GetPoints().Modified()
            bounds=np.column_stack((q.min(axis=0),q.max(axis=0))).reshape(-1)
            self.ids.Reset()
            self._profile_mark('nativeFindCellsWithinBounds')
            self.surface.locator.FindCellsWithinBounds(bounds,self.ids)
            self._profile_mark('validationTransformBoxSetup')
            self.box_queries+=1;self.check()
            count=self.ids.GetNumberOfIds()
            if count>self.maximum_candidate_cells:raise GeometryFailure('reference broad-phase candidate cap; not scored clear')
            self._profile_mark('getIdArrayExtraction')
            candidate_ids=np.fromiter((self.ids.GetId(i)for i in range(count)),dtype=np.int64,count=count)
            self._profile_mark('vectorizedGroundSplit')
            non_ground_ids,skipped_ids_array=self._split_candidate_ids(candidate_ids)
            self._profile_mark('zeroCopyOBBFilter')
            exact_ids,bounds_receipt=self._filter_box_bounds(non_ground_ids,q)
            self._profile_mark('validationTransformBoxSetup')
            self.check()
            self._profile_mark('exactPredicateLoopAndSetup')
            closest,pcoords,weights=[0.]*3,[0.]*3,[0.]*8
            sub_id,distance2=vtk.reference(0),vtk.reference(0.)
            skipped_ground=len(skipped_ids_array);skipped_ids=skipped_ids_array[:16].tolist()
            obstacle_hits=0;first=None;tested_non_ground=0
            for original_id in exact_ids:
                cell_id=int(original_id)
                self.mesh.GetCell(cell_id,self.cell)
                if self.cell.GetCellType()!=vtk.VTK_TRIANGLE or self.cell.GetNumberOfPoints()!=3:
                    raise GeometryFailure('reference cell is not a triangle')
                self.triangle_queries+=1;tested_non_ground+=1
                intersects=self.cell.IntersectWithCell(self.box)
                if intersects not in (0,1):raise GeometryFailure('invalid VTK cell intersection status')
                reason='boundaryIntersection'if intersects else None
                if not intersects:
                    for vertex in range(3):
                        inside=self.box.EvaluatePosition(self.cell.GetPoints().GetPoint(vertex),
                            closest,sub_id,pcoords,distance2,weights)
                        if inside not in (0,1):raise GeometryFailure('invalid VTK hexahedron containment status')
                        if inside:reason='containedTriangleVertex';break
                if reason is None:continue
                obstacle_hits+=1
                if first is None:first=self._oriented_result(True,count,cell_id,reason)
            self.check()
            self._profile_mark('resultAssemblyTail')
            result=first if first is not None else self._oriented_result(False,count,None,'noNonGroundReferenceSurfaceContact')
            result.update(groundContactCount=None,nonGroundContactCount=obstacle_hits,
                groundContactEvent=None,groundContactFaceIDsFirst16=None,
                groundContactFaceIDsTruncated=None,groundContactMeasurement='unmeasured: classified ground skipped before GetCell and exact intersection',
                skippedGroundCandidateCount=skipped_ground,skippedGroundCandidateIDsFirst16=skipped_ids,
                skippedGroundCandidateIDsTruncated=skipped_ground>len(skipped_ids),
                skippedGroundCandidatesAreContacts=False,exactNonGroundTriangleTests=tested_non_ground,
                completeCandidateContactCounts=False,completeNonGroundCandidateContactCounts=True,
                groundExemption='confirmed immutable original face-ID component only',
                lowHeightAloneExcluded=False,groundComponentDoesNotEstablishSemanticFloor=True)
            result.update(rejectedNonGroundBoundsCandidates=int(len(non_ground_ids)-len(exact_ids)),
                nonGroundBoundsFilter=bounds_receipt)
            return result
        except BaseException as _profile_error:
            self._profile_active['exceptionType']=type(_profile_error).__name__
            raise
        finally:
            self._profile_finish()

    # Timing metadata is separate from every original collision result.
    def _profile_begin(self):
        self._profile_active={'index':len(self.profile_rows),'exceptionType':None,
            'phaseSeconds':{name:0. for name in PROFILE_PHASES},
            'ownerCheck':{'count':0,'seconds':0.,'byPhase':{}},
            'resultHelper':{'count':0,'seconds':0.,'byPhase':{}},
            'nestedTimesAreAdditiveToPhases':False,
            'ownerCheckIncludesInheritedOwnerChecks':True,
            'resultHelperIncludesItsOwnerCheck':True,
            'OBBFilterIncludesOwnerChecks':True,
            'exactLoopIncludesFirstHitResultHelper':True,
            'scope':'one contact_corners body; external swept_contacts checks excluded',
            'timingOverheadIncluded':True,'geometryOrPredicateChanged':False}
        self._profile_phase='validationTransformBoxSetup'
        self._profile_started=self._profile_cursor=_profile_time.perf_counter()

    def _profile_mark(self,phase):
        now=_profile_time.perf_counter()
        self._profile_active['phaseSeconds'][self._profile_phase]+=now-self._profile_cursor
        self._profile_phase=phase;self._profile_cursor=now

    def _profile_note_nested(self,kind,started):
        elapsed=_profile_time.perf_counter()-started
        if self._profile_active is not None:
            row=self._profile_active[kind];row['count']+=1;row['seconds']+=elapsed
            phase=row['byPhase'].setdefault(self._profile_phase,{'count':0,'seconds':0.})
            phase['count']+=1;phase['seconds']+=elapsed

    def _profile_finish(self):
        now=_profile_time.perf_counter();row=self._profile_active
        row['phaseSeconds'][self._profile_phase]+=now-self._profile_cursor
        row['contactTimedWallSeconds']=now-self._profile_started
        row['exclusivePhaseSumSeconds']=sum(row['phaseSeconds'].values())
        row['completed']=row['exceptionType'] is None
        self.profile_rows.append(row);self._profile_active=None

    def _oriented_result(self,*args,**kwargs):
        _profile_nested_started=_profile_time.perf_counter()
        try:
            return super()._oriented_result(*args,**kwargs)
        finally:
            self._profile_note_nested('resultHelper',_profile_nested_started)
