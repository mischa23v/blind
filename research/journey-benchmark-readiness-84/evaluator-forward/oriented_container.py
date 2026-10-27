"""Independent simulation scorer: actual rectangle and horizontal margin buffer.

No planner, map, recorded data loader or physical permit. +X is forward at yaw
zero; positive yaw turns forward towards +Z. An explicit actual physics yaw
increment avoids inventing motion from cues or inferring a short turn from poses.

Each translated/rotated rectangle is conservatively enclosed in a midpoint-yaw
OBB. Translation contributes half its absolute projection on each OBB axis;
rotation contributes 2*r*sin(abs(deltaYaw)/4) on BOTH horizontal axes. This is a
continuous enclosure, not point/angle sampling. False-positive enclosure overlap
is possible and remains a separately labelled conservative result.

VTK owns triangle/box intersection and contained-vertex evaluation. The core is
copied from the frozen generic reference_band_box.py; that file and the previous
game scorer are not modified. Complete closed-solid containment is NOT solved.
"""
from dataclasses import dataclass
from pathlib import Path
import math
import sys
import numpy as np
import vtk

WS = Path(__file__).resolve().parents[2]
sys.path.insert(0,str(Path(__file__).resolve().parent))
from reference_band_box import ReferenceBandBox, GeometryFailure


@dataclass(frozen=True)
class BodyGeometry:
    width: float = .45
    depth: float = .30
    height: float = 1.60
    horizontal_margin: float = .15
    floor_contact_exclusion: float = .002

    def validate(self):
        values = np.array([self.width, self.depth, self.height,
                           self.horizontal_margin, self.floor_contact_exclusion])
        if (not np.isfinite(values).all() or not 0 < self.width <= 2
                or not 0 < self.depth <= 2 or not .5 <= self.height <= 3
                or not 0 <= self.horizontal_margin <= 1
                or not 0 <= self.floor_contact_exclusion < .01):
            raise ValueError('invalid declared experimental body geometry')


def sweep_enclosure(start, end, start_yaw, actual_yaw_delta, *, half_forward,
                    half_lateral, height, floor_contact_exclusion):
    """Return eight ordered OBB corners enclosing the entire motion increment.

    Translation must follow the straight start/end segment; yaw must remain on
    the explicitly supplied turn interval. Simultaneous or turn-then-translate
    motion is enclosed. A larger excursion is a different physics increment and
    must not be hidden in these endpoints. No movement is authorized here.
    """
    start = ReferenceBandBox.vector(start, 3, 'actual start foot point')
    end = ReferenceBandBox.vector(end, 3, 'actual end foot point')
    values = np.asarray([start_yaw, actual_yaw_delta, half_forward, half_lateral,
                         height, floor_contact_exclusion], dtype=float)
    if (not np.isfinite(values).all() or abs(actual_yaw_delta) > 2*math.pi
            or half_forward <= 0 or half_lateral <= 0 or height <= 0
            or not 0 <= floor_contact_exclusion < height):
        raise ValueError('invalid bounded sweep geometry')
    middle_yaw = float(start_yaw + actual_yaw_delta*.5)
    c, s = math.cos(middle_yaw), math.sin(middle_yaw)
    forward, lateral = np.array([c,s]), np.array([-s,c])
    delta = end[[0,2]] - start[[0,2]]
    projected_half_translation = .5*np.abs([delta@forward, delta@lateral])
    corner_radius = math.hypot(half_forward,half_lateral)
    rotation_pad = 2*corner_radius*math.sin(abs(actual_yaw_delta)*.25)
    extent = np.array([half_forward,half_lateral]) + projected_half_translation + rotation_pad
    centre = start[[0,2]]*.5 + end[[0,2]]*.5
    bottom = min(start[1],end[1]) + floor_contact_exclusion
    top = max(start[1],end[1]) + height
    # Same VTK hexahedron order as the frozen axis-aligned scorer.
    local = [(-extent[0],bottom,-extent[1]), (extent[0],bottom,-extent[1]),
             (extent[0],top,-extent[1]), (-extent[0],top,-extent[1]),
             (-extent[0],bottom,extent[1]), (extent[0],bottom,extent[1]),
             (extent[0],top,extent[1]), (-extent[0],top,extent[1])]
    corners = []
    for x,y,z in local:
        horizontal = centre+forward*x+lateral*z
        corners.append([horizontal[0],y,horizontal[1]])
    corners = np.asarray(corners)
    if not np.isfinite(corners).all():
        raise GeometryFailure('nonfinite swept OBB')
    return corners, {'midpointYawRadians':middle_yaw,
        'actualYawDeltaRadians':float(actual_yaw_delta),
        'cornerRadiusMetres':corner_radius,
        'halfProjectedTranslationMetres':projected_half_translation.tolist(),
        'rotationPaddingMetresPerHorizontalAxis':rotation_pad,
        'enclosingHalfExtentsForwardLateral':extent.tolist(),
        'verticalBoundsMetres':[float(bottom),float(top)],
        'floorContactExclusionMetres':float(floor_contact_exclusion),
        'continuousMotionEnclosed':True,'conservativeEnclosureMayOvercount':True}


class OrientedReferenceContainer(ReferenceBandBox):
    def __init__(self, surface, model_to_reference, body=BodyGeometry(), *, maximum_candidate_cells=200000):
        body.validate()
        super().__init__(surface,model_to_reference,maximum_candidate_cells=maximum_candidate_cells)
        self.body = body

    def contact_corners(self, corners):
        """Additive oriented-box entry; no changes to the frozen axis-box helper."""
        self.check()
        corners = np.asarray(corners,dtype=float)
        if corners.shape != (8,3) or not np.isfinite(corners).all():
            raise ValueError('finite eight-corner hexahedron required')
        edges = np.column_stack((corners[1]-corners[0],corners[3]-corners[0],corners[4]-corners[0]))
        lengths = np.linalg.norm(edges,axis=0)
        if np.any(lengths <= 0) or not np.isfinite(lengths).all():
            raise ValueError('positive OBB extents required')
        unit = edges/lengths
        if not np.allclose(unit.T@unit,np.eye(3),atol=1e-10,rtol=0) or np.linalg.det(unit) <= 0:
            raise ValueError('proper orthogonal OBB required')
        v0 = corners[0];x,y,z = edges.T
        expected = np.asarray([v0,v0+x,v0+x+y,v0+y,v0+z,v0+x+z,v0+x+y+z,v0+y+z])
        if not np.allclose(corners,expected,atol=1e-10,rtol=0):
            raise ValueError('VTK OBB corner order mismatch')
        q = corners@self.transform[:3,:3].T+self.transform[:3,3]
        if not np.isfinite(q).all():
            raise GeometryFailure('nonfinite transformed OBB')
        for i,p in enumerate(q):self.box.GetPoints().SetPoint(i,p)
        self.box.GetPoints().Modified()
        bounds = np.column_stack((q.min(axis=0),q.max(axis=0))).reshape(-1)
        self.ids.Reset();self.surface.locator.FindCellsWithinBounds(bounds,self.ids)
        self.box_queries += 1;self.check()
        count = self.ids.GetNumberOfIds()
        if count > self.maximum_candidate_cells:
            raise GeometryFailure('reference broad-phase candidate cap; not scored clear')
        closest,pcoords,weights = [0.]*3,[0.]*3,[0.]*8
        sub_id,distance2 = vtk.reference(0),vtk.reference(0.)
        for i in range(count):
            cell_id = self.ids.GetId(i)
            if not 0 <= cell_id < self.mesh.GetNumberOfCells():
                raise GeometryFailure('invalid reference broad-phase cell ID')
            self.mesh.GetCell(cell_id,self.cell)
            if self.cell.GetCellType() != vtk.VTK_TRIANGLE or self.cell.GetNumberOfPoints() != 3:
                raise GeometryFailure('reference cell is not a triangle')
            self.triangle_queries += 1
            intersects = self.cell.IntersectWithCell(self.box)
            if intersects not in (0,1):raise GeometryFailure('invalid VTK cell intersection status')
            if intersects:return self._oriented_result(True,count,int(cell_id),'boundaryIntersection')
            for vertex in range(3):
                inside = self.box.EvaluatePosition(self.cell.GetPoints().GetPoint(vertex),
                    closest,sub_id,pcoords,distance2,weights)
                if inside not in (0,1):raise GeometryFailure('invalid VTK hexahedron containment status')
                if inside:return self._oriented_result(True,count,int(cell_id),'containedTriangleVertex')
        return self._oriented_result(False,count,None,'noReferenceSurfaceContact')

    def _oriented_result(self,contact,count,cell_id,reason):
        self.check()
        result={'contact':contact,'candidateTriangles':count,'firstReferenceCellID':cell_id,
                'reason':reason,'closedBoundaries':True,'closedSolidContainmentClassified':False,
                'measuredCoverageEstablished':False,'physicalClearanceEstablished':False,
                'physicalAuthority':False}
        if contact:
            heights=[float((self.inverse[:3,:3]@self.cell.GetPoints().GetPoint(i)+self.inverse[:3,3])[1])
                     for i in range(3)]
            if not np.isfinite(heights).all():raise GeometryFailure('nonfinite contact triangle heights')
            result['firstTriangleModelHeightRange']=[min(heights),max(heights)]
            result['heightRangeIsWholeTriangleNotContactPoint']=True
        return result

    def swept_contacts(self,start,end,start_yaw,actual_yaw_delta):
        """Score BOTH raw body and independent horizontal-margin enclosure.

        A margin contact is not a physical-body contact. Neither score is fed
        back to the controller. The episode owner determines terminal outcome;
        collision prevention must not correct a pose and claim successful motion.
        """
        self.check();b=self.body;result={}
        for name,pad in (('actualBody',0.),('horizontalMargin',b.horizontal_margin)):
            corners,receipt=sweep_enclosure(start,end,start_yaw,actual_yaw_delta,
                half_forward=b.depth*.5+pad,half_lateral=b.width*.5+pad,
                height=b.height,floor_contact_exclusion=b.floor_contact_exclusion)
            result[name]={**self.contact_corners(corners),'sweep':receipt}
            if result[name]['contact']:
                result[name]['firstTriangleHeightRelativeToStartFootRange']=[
                    v-float(start[1])for v in result[name]['firstTriangleModelHeightRange']]
        result['bodyDimensionsWidthDepthHeight']=[b.width,b.depth,b.height]
        result['horizontalMarginMetres']=b.horizontal_margin
        result['marginExtendsVerticalHeight']=False
        result['actualBodyContactIsConservativeEnclosureOverlap']=True
        result['physicalAuthority']=False
        return result

    def support_probes(self,foot,yaw):
        """Nine fixed first-hit rays: centre, quadrants and actual body corners.

        This finite pattern is NOT continuous footprint/sweep support evidence.
        No floor-following correction, route, semantic floor or acceptance flag.
        Endpoints are ABSOLUTE model Y=+.15 and -.25; supplied foot Y is NOT
        used to move the probe window after a world setup chooses a foot height.
        """
        self.check();foot=self.vector(foot,3,'actual foot point')
        if not math.isfinite(yaw):raise ValueError('finite actual yaw required')
        c,s=math.cos(yaw),math.sin(yaw);f=np.array([c,s]);l=np.array([-s,c])
        local=[(0.,0.)]+[(x*self.body.depth*.25,z*self.body.width*.25)
                          for x,z in ((-1,-1),(-1,1),(1,-1),(1,1))]
        local += [(x*self.body.depth*.5,z*self.body.width*.5)
                  for x,z in ((-1,-1),(-1,1),(1,-1),(1,1))]
        rows=[]
        for x,z in local:
            p=foot[[0,2]]+f*x+l*z
            rows.append(self._floor_ray(p[0],p[1],.15,-.25))
        self.check()
        return {'probes':rows,'hitCount':sum(r['hit']for r in rows),
                'missingCount':sum(not r['hit']for r in rows),
                'pattern':'centre, four raw-body quadrant centres and four actual rectangle corners',
                'rayTopModelY':.15,'rayBottomModelY':-.25,'rayIntervalIsAbsolute':True,
                'continuousSupportProven':False,'semanticFloorEstablished':False,
                'measuredCoverageEstablished':False,'physicalClearanceEstablished':False,
                'physicalAuthority':False}
