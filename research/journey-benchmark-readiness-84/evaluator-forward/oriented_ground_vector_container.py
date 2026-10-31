"""Exact vectorized ground membership; frozen v4 scorer remains unchanged.

Ground membership alone is batched with NumPy searchsorted. Candidate cap,
original order and exact NON-ground VTK tests are preserved. This is a
single-owner immutable-ground contract, not a new classifier or physics model.
No ground-contact counts are measured, and no speed improvement is assumed.
"""
from pathlib import Path
import sys
import numpy as np
import vtk
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(Path(__file__).resolve().parent))
from oriented_ground_skip_container import GroundSkippingReferenceContainer,GeometryFailure


class GroundVectorReferenceContainer(GroundSkippingReferenceContainer):
    def __init__(self,*args,**kwargs):
        super().__init__(*args,**kwargs)
        ids=self._ground.ground_cell_ids
        if (not isinstance(ids,np.ndarray) or ids.ndim!=1 or ids.dtype.kind not in 'iu'
                or ids.flags.writeable or not ids.flags.owndata):
            raise GeometryFailure('ground IDs must be owned read-only one-dimensional integer data')
        if (np.any(ids<0) or np.any(ids>=self.mesh.GetNumberOfCells())
                or np.any(ids[1:]<=ids[:-1])):
            raise GeometryFailure('ground IDs must be strictly sorted unique valid original cell IDs')
        self._ground_ids=ids
        self._ground_ids_shape=ids.shape
        self._ground_ids_dtype=ids.dtype
        self.check()

    def check(self):
        super().check()
        # Membership data is frozen by its validated single owner. Detect
        # replacement, shape/dtype edits and write-enable; never silently sort,
        # copy a changed classifier, or rescan all ground IDs at every box.
        if hasattr(self,'_ground_ids'):
            ids=self._ground.ground_cell_ids
            if (ids is not self._ground_ids or ids.flags.writeable or not ids.flags.owndata
                    or ids.shape!=self._ground_ids_shape or ids.dtype!=self._ground_ids_dtype):
                raise GeometryFailure('immutable ground-ID owner contract changed')

    def _split_candidate_ids(self,candidate_ids):
        """Validate once and retain exact locator order, including duplicates."""
        ids=np.asarray(candidate_ids)
        if (ids.ndim!=1 or ids.dtype.kind not in 'iu' or np.any(ids<0)
                or np.any(ids>=self.mesh.GetNumberOfCells())):
            raise GeometryFailure('invalid reference broad-phase cell ID array')
        if len(self._ground_ids):
            positions=np.searchsorted(self._ground_ids,ids)
            bounded=np.minimum(positions,len(self._ground_ids)-1)
            is_ground=(positions<len(self._ground_ids))&(self._ground_ids[bounded]==ids)
        else:is_ground=np.zeros(len(ids),dtype=bool)
        return ids[~is_ground],ids[is_ground]

    def contact_corners(self,corners):
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
        self.ids.Reset();self.surface.locator.FindCellsWithinBounds(bounds,self.ids)
        self.box_queries+=1;self.check()
        count=self.ids.GetNumberOfIds()
        if count>self.maximum_candidate_cells:raise GeometryFailure('reference broad-phase candidate cap; not scored clear')
        candidate_ids=np.fromiter((self.ids.GetId(i)for i in range(count)),dtype=np.int64,count=count)
        non_ground_ids,skipped_ids_array=self._split_candidate_ids(candidate_ids)
        self.check()
        closest,pcoords,weights=[0.]*3,[0.]*3,[0.]*8
        sub_id,distance2=vtk.reference(0),vtk.reference(0.)
        skipped_ground=len(skipped_ids_array);skipped_ids=skipped_ids_array[:16].tolist()
        obstacle_hits=0;first=None;tested_non_ground=0
        for original_id in non_ground_ids:
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
        return result
