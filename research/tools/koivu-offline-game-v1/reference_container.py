"""Conservative game-container scoring against an immutable reference surface.

Upstream VTK owns intersection/containment. The reference never supplies a route,
body-pose correction, floor correction, sensor packet or clearance to the planner.
This is a surface-contact model, not a proof of solid occupancy/physical support.
"""
from dataclasses import dataclass
import math
import sys
from pathlib import Path
import numpy as np
import vtk

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'blind-koivu-reference-comparison-06'))
from reference_geometry import checked_similarity, GeometryFailure


@dataclass(frozen=True)
class Container:
    half_extent: float = math.hypot(.45, .30) / 2
    height: float = 1.6
    floor_contact_exclusion: float = .002
    support_spacing: float = .05
    support_association: float = .02
    support_spread: float = .02


class ReferenceContainer:
    def __init__(self, surface, game_to_reference, container=Container(), *, maximum_candidate_cells=200000):
        self.surface = surface
        accepted, self.transform_receipt = checked_similarity(game_to_reference)
        self.transform = np.array(accepted, dtype=float, copy=True)
        self.inverse = np.linalg.inv(self.transform)
        self.transform.setflags(write=False); self.inverse.setflags(write=False)
        # Single-owner reference object: no mesh mutations are allowed after
        # construction. This detects ordinary VTK Modified() changes, not a
        # sandbox against a caller secretly writing a shared NumPy buffer.
        self.mesh_revision = surface.mesh.GetMTime()
        self.errors = []
        self.container = container
        if not (0 < container.half_extent < 2 and .5 <= container.height <= 3
                and 0 <= container.floor_contact_exclusion < .01
                and .01 <= container.support_spacing <= .1
                and 0 < container.support_association <= .02
                and 0 < container.support_spread <= .02):
            raise ValueError('invalid experimental container')
        if isinstance(maximum_candidate_cells, bool) or not isinstance(maximum_candidate_cells, int) or not 1 <= maximum_candidate_cells <= 200000:
            raise ValueError('invalid broad-phase candidate cap')
        self.maximum_candidate_cells = maximum_candidate_cells
        self.cell = vtk.vtkGenericCell()
        self.ray_cell = vtk.vtkGenericCell()
        self.box = vtk.vtkHexahedron()
        self.box.GetPoints().SetDataTypeToDouble()
        for obj in (self.cell, self.ray_cell, self.box, self.surface.locator):
            obj.AddObserver('ErrorEvent', lambda *_: self.errors.append('VTK evaluator ErrorEvent'))
        for i in range(8):
            self.box.GetPointIds().SetId(i, i)
        self.ids = vtk.vtkIdList()
        self.support_cache = {}
        self.support_native_queries = 0
        self.collision_native_queries = 0

    def check(self):
        if self.surface.mesh.GetMTime() != self.mesh_revision:
            raise GeometryFailure('reference mesh changed after evaluator construction')
        if self.errors or self.surface.errors:
            raise GeometryFailure(';'.join(self.errors + self.surface.errors))

    @staticmethod
    def point(value):
        p = np.asarray(value, dtype=float)
        if p.shape != (3,) or not np.isfinite(p).all():
            raise ValueError('invalid game body foot point')
        return p

    def transformed(self, point):
        return self.transform[:3, :3] @ point + self.transform[:3, 3]

    def swept_contact(self, start, end):
        self.check()
        start, end = self.point(start), self.point(end)
        c = self.container
        if abs(start[1] - end[1]) > 1e-9:
            raise ValueError('level game cannot silently follow a different floor')
        low = np.minimum(start, end) + [-c.half_extent, c.floor_contact_exclusion, -c.half_extent]
        high = np.maximum(start, end) + [c.half_extent, c.height, c.half_extent]
        # VTK hexahedron order. This is the full translational sweep enclosure;
        # a yaw-independent square also encloses every intermediate body yaw.
        corners = np.asarray([[low[0], low[1], low[2]], [high[0], low[1], low[2]],
                              [high[0], high[1], low[2]], [low[0], high[1], low[2]],
                              [low[0], low[1], high[2]], [high[0], low[1], high[2]],
                              [high[0], high[1], high[2]], [low[0], high[1], high[2]]])
        q = corners @ self.transform[:3, :3].T + self.transform[:3, 3]
        if not np.isfinite(q).all():
            raise GeometryFailure('nonfinite transformed container')
        for i, p in enumerate(q):
            self.box.GetPoints().SetPoint(i, p)
        self.box.GetPoints().Modified()
        bounds = np.column_stack((q.min(axis=0), q.max(axis=0))).reshape(-1)
        self.ids.Reset()
        self.surface.locator.FindCellsWithinBounds(bounds, self.ids)
        count = self.ids.GetNumberOfIds()
        if count > self.maximum_candidate_cells:
            raise GeometryFailure('reference broad-phase candidate cap; not scored clear')
        closest, pcoords, weights = [0.] * 3, [0.] * 3, [0.] * 8
        sub_id, distance2 = vtk.reference(0), vtk.reference(0.)
        for i in range(count):
            cell_id = self.ids.GetId(i)
            if not 0 <= cell_id < self.surface.mesh.GetNumberOfCells():
                raise GeometryFailure('invalid reference broad-phase cell ID')
            self.surface.mesh.GetCell(cell_id, self.cell)
            if self.cell.GetCellType() != vtk.VTK_TRIANGLE or self.cell.GetNumberOfPoints() != 3:
                raise GeometryFailure('reference cell is not a triangle')
            self.collision_native_queries += 1
            intersects = self.cell.IntersectWithCell(self.box)
            if intersects not in (0, 1):
                raise GeometryFailure('invalid VTK cell intersection status')
            if intersects:
                return self._contact(True, count, int(cell_id), 'boundaryIntersection', float(start[1]))
            # IntersectWithCell alone returns false for an enclosed triangle.
            # Explicit upstream volumetric containment is therefore mandatory.
            for vertex in range(3):
                inside = self.box.EvaluatePosition(self.cell.GetPoints().GetPoint(vertex),
                    closest, sub_id, pcoords, distance2, weights)
                if inside not in (0, 1):
                    raise GeometryFailure('invalid VTK hexahedron containment status')
                if inside:
                    return self._contact(True, count, int(cell_id), 'containedTriangleVertex', float(start[1]))
        if self.surface.errors:
            raise GeometryFailure(';'.join(self.surface.errors))
        return self._contact(False, count, None, 'noReferenceSurfaceContact', float(start[1]))

    def _contact(self, contact, candidates, cell_id, reason, foot_y):
        self.check()
        row = {'contact': contact, 'candidateTriangles': candidates, 'firstReferenceCellID': cell_id,
                'reason': reason, 'kind': 'conservativeSweptPlayerContainerSurfaceContact',
                'closedSolidContainmentClassified': False,
                'floorContactExclusionMetres': self.container.floor_contact_exclusion}
        if contact:
            heights=[float((self.inverse[:3,:3] @ self.cell.GetPoints().GetPoint(i)+self.inverse[:3,3])[1]-foot_y)
                     for i in range(3)]
            row['firstTriangleHeightRelativeToFootMetres']=[min(heights),max(heights)]
            row['nearFootOrFloorRegistrationAmbiguity']=max(heights)<=.03
            row['physicalObstacleEstablished']=False
        return row

    def _support_height(self, x, foot_y, z):
        self.check()
        # Exact endpoints plus immutable surface/transform owner. No rounding,
        # moving floor, nearest supported point or pose correction is cached.
        key = (float(x), float(foot_y), float(z))
        if key in self.support_cache:
            return self.support_cache[key]
        a = self.transformed(np.asarray([x, foot_y + .15, z]))
        b = self.transformed(np.asarray([x, foot_y - .25, z]))
        if not np.isfinite(a).all() or not np.isfinite(b).all():
            raise GeometryFailure('nonfinite support ray')
        t, sub, cell_id = vtk.reference(0.), vtk.reference(0), vtk.reference(0)
        point, pcoords = [0.] * 3, [0.] * 3
        hit = self.surface.locator.IntersectWithLine(a, b, 1e-7, t, point,
                                                   pcoords, sub, cell_id, self.ray_cell)
        self.support_native_queries += 1
        self.check()
        if hit not in (0, 1):
            raise GeometryFailure('reference support ray failure')
        if not hit:
            value = None
        else:
            local = self.inverse[:3, :3] @ point + self.inverse[:3, 3]
            if (not np.isfinite(local).all() or not 0 <= float(t) <= 1
                    or not 0 <= int(cell_id) < self.surface.mesh.GetNumberOfCells()
                    or np.linalg.norm(np.asarray(point)-(a+float(t)*(b-a))) > 1e-6):
                raise GeometryFailure('invalid support hit')
            if abs(local[0]-x) > 1e-6 or abs(local[2]-z) > 1e-6:
                raise GeometryFailure('support hit/transform inconsistency')
            value = float(local[1])
        # The finite cache is only an acceleration; an uncached exact query has
        # identical meaning. No observation or absence is manufactured at cap.
        if len(self.support_cache) < 50000:
            self.support_cache[key] = value
        return value

    def swept_support(self, start, end):
        self.check()
        start, end = self.point(start), self.point(end)
        if abs(start[1]-end[1]) > 1e-9:
            raise ValueError('changed foot plane')
        c = self.container
        low = np.minimum(start[[0, 2]], end[[0, 2]]) - c.half_extent
        high = np.maximum(start[[0, 2]], end[[0, 2]]) + c.half_extent
        # Fixed game-frame lattice covers the swept square's bounding area;
        # outward rounding is conservative. Exact four corners are additional.
        ix = range(math.floor(low[0]/c.support_spacing), math.ceil(high[0]/c.support_spacing)+1)
        iz = range(math.floor(low[1]/c.support_spacing), math.ceil(high[1]/c.support_spacing)+1)
        if len(ix)*len(iz)+4 > 10000:
            raise GeometryFailure('reference support probe cap; not scored supported')
        probes = {(i*c.support_spacing, j*c.support_spacing) for i in ix for j in iz}
        probes.update((float(x), float(z)) for x in (low[0], high[0]) for z in (low[1], high[1]))
        heights = [self._support_height(x, start[1], z) for x, z in sorted(probes)]
        finite = [v for v in heights if v is not None]
        missing = len(heights)-len(finite)
        spread = max(finite)-min(finite) if finite else None
        maximum_error = max(abs(v-start[1]) for v in finite) if finite else None
        known = bool(missing == 0 and spread <= c.support_spread and maximum_error <= c.support_association)
        self.check()
        return {'sampledSupportKnown': known, 'samples': len(probes), 'missing': missing,
                'heightSpreadMetres': spread, 'maximumFootPlaneErrorMetres': maximum_error,
                'samplesBelowFootAssociation': sum(v < start[1]-c.support_association for v in finite),
                'samplesAboveFootAssociation': sum(v > start[1]+c.support_association for v in finite),
                'supportSpreadExceedsLimit': spread is not None and spread > c.support_spread,
                'minimumHeight': min(finite) if finite else None,
                'maximumHeight': max(finite) if finite else None,
                'continuousSupportProven': False, 'measuredReferenceSupportMaskAvailable': False,
                'meaning': 'finite reference-surface support model only; no floor correction applied'}
