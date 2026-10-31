"""NEW world-only ground-component variant; frozen prior scorer is unchanged.

Only slope/edge/seed-membership-confirmed ORIGINAL ground face IDs are exempted
from obstacle contact. Height alone never excludes a triangle. All non-ground
triangles remain obstacles, including centimetre tops, risers, walls and heads.
The existing continuous body/margin OBB sweep and nine native rays are inherited.
This changes simulation-world contact modelling, not a phone map or controller.
"""
from pathlib import Path
import sys
import numpy as np
import vtk

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'source'))
from oriented_container import OrientedReferenceContainer,BodyGeometry,GeometryFailure


class GroundedReferenceContainer(OrientedReferenceContainer):
    def __init__(self,surface,model_to_reference,*,ground,body=BodyGeometry(),maximum_candidate_cells=200000):
        self._ground=ground
        super().__init__(surface,model_to_reference,body,maximum_candidate_cells=maximum_candidate_cells)
        self.check()

    @property
    def ground(self):return self._ground

    def check(self):
        super().check()
        # Ground slope and patch bounds were computed in this exact model frame.
        self._ground.assert_matches(self.surface,self.transform)

    def contact_corners(self,corners):
        """Same VTK core, but ground membership is checked AFTER intersection.

        Continue through all candidates after the first non-ground hit so the
        separately reported ground/non-ground face counts are complete for the
        query. One contact event is not one event per dense mesh triangle.
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
        closest,pcoords,weights=[0.]*3,[0.]*3,[0.]*8
        sub_id,distance2=vtk.reference(0),vtk.reference(0.)
        ground_hits=0;obstacle_hits=0;first=None;ground_ids=[]
        for i in range(count):
            cell_id=int(self.ids.GetId(i))
            if not 0<=cell_id<self.mesh.GetNumberOfCells():raise GeometryFailure('invalid reference broad-phase cell ID')
            self.mesh.GetCell(cell_id,self.cell)
            if self.cell.GetCellType()!=vtk.VTK_TRIANGLE or self.cell.GetNumberOfPoints()!=3:
                raise GeometryFailure('reference cell is not a triangle')
            self.triangle_queries+=1
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
            if self._ground.is_ground(cell_id):
                ground_hits+=1
                if len(ground_ids)<16:ground_ids.append(cell_id)
            else:
                obstacle_hits+=1
                if first is None:first=self._oriented_result(True,count,cell_id,reason)
        self.check()
        result=first if first is not None else self._oriented_result(False,count,None,'noNonGroundReferenceSurfaceContact')
        result.update(groundContactCount=ground_hits,nonGroundContactCount=obstacle_hits,
            groundContactEvent=ground_hits>0,groundContactFaceIDsFirst16=ground_ids,
            groundContactFaceIDsTruncated=ground_hits>len(ground_ids),
            completeCandidateContactCounts=True,groundExemption='confirmed immutable original face-ID component only',
            lowHeightAloneExcluded=False,groundComponentDoesNotEstablishSemanticFloor=True)
        return result
