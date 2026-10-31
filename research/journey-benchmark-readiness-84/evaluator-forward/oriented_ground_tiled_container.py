"""Tiled negative-query prepass; positives replay the original v6 ordering.

Full original geometry, enclosure, membership, OBB filter and exact predicates
remain. Only a negative result may expose sorted skipped-ground preview IDs.
Any positive prepass returns the original same-box v6 result, preserving first
contact identity/height/reason and near-foot classification. Extra work is
explicit in optimization_rows and cumulative counters; no speed is promised.
"""
from pathlib import Path
import hashlib,sys,time
import numpy as np
import vtk
ROOT=Path(__file__).resolve().parents[1]
V6_SHA='9f42c2e09fd53fb2a5778ad0ba965fd3cf1b9a5167e2f91f3161575908ec55d3'
TILER_SHA='9a7015950867f095e2990c117918423496f9d659ca50c5e7f6a0f765e4d18188'
for _path,_expected in ((Path(__file__).resolve().parent/'oriented_ground_obb_container.py',V6_SHA),
                        (Path(__file__).resolve().parent/'tiled_bounds.py',TILER_SHA)):
    if hashlib.sha256(_path.read_bytes()).hexdigest()!=_expected:
        raise RuntimeError('frozen tiled scorer dependency changed: '+str(_path))
sys.path.insert(0,str(Path(__file__).resolve().parent))
from oriented_ground_obb_container import GroundOBBReferenceContainer,GeometryFailure
sys.path.insert(0,str(Path(__file__).resolve().parent))
from tiled_bounds import find_cells_tiled,TiledBoundsUnavailable


class GroundTiledReferenceContainer(GroundOBBReferenceContainer):
    def __init__(self,*args,**kwargs):
        self.optimization_rows=[];self._v17_active=None
        super().__init__(*args,**kwargs)

    def _tiled_candidates(self,bounds):
        try:
            ids,receipt=find_cells_tiled(self.surface.locator,bounds,check=self.check,
                                        unique_cap=self.maximum_candidate_cells)
        except TiledBoundsUnavailable as error:
            self._v17_active['tiledFailureDetails']=error.details
            if error.details.get('uniqueIDs',0)>self.maximum_candidate_cells:
                raise GeometryFailure('reference broad-phase candidate cap; not scored clear')from error
            raise GeometryFailure('tiled query unavailable; not scored clear: '+str(error))from error
        self._v17_active['tiledQuery']=receipt
        digest_began=time.perf_counter()
        self._v17_active['sortedCandidateIDsSHA256']=hashlib.sha256(ids.astype('<i8',copy=False).tobytes(order='C')).hexdigest()
        self._v17_active['candidateDigestWallSeconds']=time.perf_counter()-digest_began
        return ids

    def contact_corners(self,corners):
        row={'index':len(self.optimization_rows),'completed':False,'exceptionType':None,
            'tiledQuery':None,'tiledFailureDetails':None,'sortedCandidateIDsSHA256':None,
            'candidateIDEncoding':'sorted unique original IDs, signed int64 little-endian, C order',
            'candidateDigestWallSeconds':None,'candidateDigestIncludedInPrepassTime':True,'prepassWallSeconds':0.,
            'fallbackWallSeconds':0.,'fallbackUsed':False,'fallbackCompleted':False,
            'prepassContact':None,'prepassFirstReferenceCellID':None,
            'prepassExactTriangleTests':0,'fallbackExactTriangleTests':0,
            'prepassBoxQueryDelta':0,'fallbackBoxQueryDelta':0,
            'returnedResultCountsDescribeReturnedPassOnly':True,
            'candidateOrderPolicy':'sorted union prepass; ANY positive replays original native order',
            'permittedNegativeResultDifferenceFields':['skippedGroundCandidateIDsFirst16'],
            'newCollisionGeometry':False,'physicalAuthority':False}
        self._v17_active=row;began=time.perf_counter()
        boxes_before=self.box_queries;triangles_before=self.triangle_queries
        try:
            pre_began=time.perf_counter()
            try:
                prepass=self._tiled_contact_corners(corners)
            finally:
                row['prepassWallSeconds']=time.perf_counter()-pre_began
                row['prepassExactTriangleTests']=self.triangle_queries-triangles_before
                row['prepassBoxQueryDelta']=self.box_queries-boxes_before
            row['prepassContact']=prepass['contact']
            row['prepassFirstReferenceCellID']=prepass['firstReferenceCellID']
            if prepass['contact']:
                row['fallbackUsed']=True;fallback_began=time.perf_counter()
                fallback_boxes=self.box_queries;fallback_triangles=self.triangle_queries
                try:
                    result=GroundOBBReferenceContainer.contact_corners(self,corners)
                finally:
                    row['fallbackWallSeconds']=time.perf_counter()-fallback_began
                    row['fallbackExactTriangleTests']=self.triangle_queries-fallback_triangles
                    row['fallbackBoxQueryDelta']=self.box_queries-fallback_boxes
                row['fallbackCompleted']=True
                if not result['contact']:
                    raise GeometryFailure('positive tiled prepass disagrees with original result; not scored clear')
                for field in ('candidateTriangles','nonGroundContactCount','skippedGroundCandidateCount',
                              'rejectedNonGroundBoundsCandidates','exactNonGroundTriangleTests'):
                    if prepass[field]!=result[field]:
                        raise GeometryFailure('tiled/original contact count disagreement: '+field)
            else:
                result=prepass
            row['returnedContact']=result['contact'];row['returnedFirstReferenceCellID']=result['firstReferenceCellID']
            row['returnedPassExactTriangleTests']=result['exactNonGroundTriangleTests']
            row['completed']=True
            return result
        except BaseException as error:
            row['exceptionType']=type(error).__name__
            raise
        finally:
            row['totalWallSeconds']=time.perf_counter()-began
            row['actualBoxQueryCounterDelta']=self.box_queries-boxes_before
            row['actualExactTriangleCounterDelta']=self.triangle_queries-triangles_before
            # On an interrupted/failed native call, no completed-call count is
            # invented. Successful rows report every tile plus original replay.
            row['nativeBoundsCallsTotal']=(row['tiledQuery']['tileQueries']+int(row['fallbackUsed']))if row['completed']else None
            row['fallbackNativeBoundsCalls']=int(row['fallbackUsed'])if row['completed']else None
            self.optimization_rows.append(row);self._v17_active=None

    def _tiled_contact_corners(self,corners):
        """One validated candidate array, one immutable-ground membership mask.

        Candidate cap precedes extraction/filtering; non-ground ordering and
        exact VTK checks remain unchanged. Ground contacts are unmeasured.
        """
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
        self.ids.Reset();candidate_ids=self._tiled_candidates(bounds)
        self.box_queries+=1;self.check()
        count=len(candidate_ids)
        if count>self.maximum_candidate_cells:raise GeometryFailure('reference broad-phase candidate cap; not scored clear')
        non_ground_ids,skipped_ids_array=self._split_candidate_ids(candidate_ids)
        exact_ids,bounds_receipt=self._filter_box_bounds(non_ground_ids,q)
        self.check()
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
