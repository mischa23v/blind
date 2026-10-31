"""Evaluator-only closed band boxes using the existing VTK contact core.

Model coordinates are +Y up, with horizontal X/Z. Callers supply explicit
low/high bounds and the positive similarity to the immutable reference mesh.
No floor exclusion, body size, inferred support or missing-space clearance is
silently applied. Adjacent closed bands can both report a boundary contact;
their union, not their sum, owns an all-band contact count.

The intersection + contained-triangle-vertex core is adapted from the tested
blind-koivu-game-07/reference_container.py; that historical scorer is unchanged.
One ordered owner must serialize queries. No mesh loading or planner imports.
"""
from pathlib import Path
import sys
import numpy as np
import vtk

WS = Path(__file__).resolve().parents[2]
sys.path.insert(0,str(Path(__file__).resolve().parent))
from reference_geometry import checked_similarity, GeometryFailure


class ReferenceBandBox:
    def __init__(self, surface, model_to_reference, *, maximum_candidate_cells=200000):
        accepted, self.transform_receipt = checked_similarity(model_to_reference)
        self.transform = np.array(accepted, dtype=float, copy=True)
        self.inverse = np.linalg.inv(self.transform)
        self.transform.setflags(write=False)
        self.inverse.setflags(write=False)
        if (isinstance(maximum_candidate_cells, bool)
                or not isinstance(maximum_candidate_cells, int)
                or not 1 <= maximum_candidate_cells <= 200000):
            raise ValueError('invalid broad-phase candidate cap')
        self.maximum_candidate_cells = maximum_candidate_cells
        self.surface = surface
        self.mesh = surface.mesh
        self.mesh_revision = self.mesh.GetMTime()
        self.errors = []
        self.cell = vtk.vtkGenericCell()
        self.ray_cell = vtk.vtkGenericCell()
        self.box = vtk.vtkHexahedron()
        self.box.GetPoints().SetDataTypeToDouble()
        for obj in (self.cell, self.ray_cell, self.box, surface.locator):
            obj.AddObserver('ErrorEvent', lambda *_: self.errors.append('VTK band evaluator ErrorEvent'))
        for i in range(8):
            self.box.GetPointIds().SetId(i, i)
        self.ids = vtk.vtkIdList()
        self.box_queries = 0
        self.triangle_queries = 0
        self.floor_ray_queries = 0
        self.check()

    def check(self):
        if (self.surface.mesh is not self.mesh or self.mesh.GetMTime() != self.mesh_revision
                or self.surface.locator.GetDataSet() != self.mesh):
            raise GeometryFailure('reference mesh changed after band evaluator construction')
        if self.errors or self.surface.errors:
            raise GeometryFailure(';'.join(self.errors + self.surface.errors))

    @staticmethod
    def vector(value, size, label):
        a = np.asarray(value, dtype=float)
        if a.shape != (size,) or not np.isfinite(a).all():
            raise ValueError('invalid ' + label)
        return a

    def contact(self, low, high):
        """First triangle-surface contact with the supplied closed 3D box.

        No contact means no intersecting reference surface, NOT known free
        volume. Closed-solid containment and measured coverage are unavailable.
        """
        self.check()
        low = self.vector(low, 3, 'box low')
        high = self.vector(high, 3, 'box high')
        if np.any(low >= high):
            raise ValueError('box needs strictly positive extents on every axis')
        corners = np.asarray([[low[0], low[1], low[2]], [high[0], low[1], low[2]],
                              [high[0], high[1], low[2]], [low[0], high[1], low[2]],
                              [low[0], low[1], high[2]], [high[0], low[1], high[2]],
                              [high[0], high[1], high[2]], [low[0], high[1], high[2]]])
        q = corners @ self.transform[:3, :3].T + self.transform[:3, 3]
        if not np.isfinite(q).all():
            raise GeometryFailure('nonfinite transformed band box')
        for i, p in enumerate(q):
            self.box.GetPoints().SetPoint(i, p)
        self.box.GetPoints().Modified()
        bounds = np.column_stack((q.min(axis=0), q.max(axis=0))).reshape(-1)
        self.ids.Reset()
        self.surface.locator.FindCellsWithinBounds(bounds, self.ids)
        self.box_queries += 1
        self.check()
        count = self.ids.GetNumberOfIds()
        if count > self.maximum_candidate_cells:
            raise GeometryFailure('reference broad-phase candidate cap; not scored clear')
        closest, pcoords, weights = [0.] * 3, [0.] * 3, [0.] * 8
        sub_id, distance2 = vtk.reference(0), vtk.reference(0.)
        for i in range(count):
            cell_id = self.ids.GetId(i)
            if not 0 <= cell_id < self.mesh.GetNumberOfCells():
                raise GeometryFailure('invalid reference broad-phase cell ID')
            self.mesh.GetCell(cell_id, self.cell)
            if self.cell.GetCellType() != vtk.VTK_TRIANGLE or self.cell.GetNumberOfPoints() != 3:
                raise GeometryFailure('reference cell is not a triangle')
            self.triangle_queries += 1
            intersects = self.cell.IntersectWithCell(self.box)
            if intersects not in (0, 1):
                raise GeometryFailure('invalid VTK cell intersection status')
            if intersects:
                return self._result(True, count, int(cell_id), 'boundaryIntersection', low, high)
            # Upstream IntersectWithCell misses a wholly enclosed triangle.
            for vertex in range(3):
                inside = self.box.EvaluatePosition(self.cell.GetPoints().GetPoint(vertex),
                    closest, sub_id, pcoords, distance2, weights)
                if inside not in (0, 1):
                    raise GeometryFailure('invalid VTK hexahedron containment status')
                if inside:
                    return self._result(True, count, int(cell_id), 'containedTriangleVertex', low, high)
        return self._result(False, count, None, 'noReferenceSurfaceContact', low, high)

    def _result(self, contact, count, cell_id, reason, low, high):
        self.check()
        return {'contact': contact, 'candidateTriangles': count, 'firstReferenceCellID': cell_id,
                'reason': reason, 'modelLow': low.tolist(), 'modelHigh': high.tolist(),
                'closedBoundaries': True, 'implicitFloorExclusion': False,
                'closedSolidContainmentClassified': False, 'measuredCoverageEstablished': False,
                'physicalClearanceEstablished': False, 'physicalAuthority': False}

    def _floor_ray(self, x, z, top, bottom):
        self.check()
        a = self.transform[:3, :3] @ [x, top, z] + self.transform[:3, 3]
        b = self.transform[:3, :3] @ [x, bottom, z] + self.transform[:3, 3]
        if not np.isfinite(a).all() or not np.isfinite(b).all():
            raise GeometryFailure('nonfinite floor-probe ray')
        t, sub, cell_id = vtk.reference(0.), vtk.reference(0), vtk.reference(0)
        point, pcoords = [0.] * 3, [0.] * 3
        hit = self.surface.locator.IntersectWithLine(a, b, 1e-7, t, point,
                                                   pcoords, sub, cell_id, self.ray_cell)
        self.floor_ray_queries += 1
        self.check()
        if hit not in (0, 1):
            raise GeometryFailure('reference floor-probe ray failure')
        height = None
        if hit:
            local = self.inverse[:3, :3] @ point + self.inverse[:3, 3]
            if (not np.isfinite(local).all() or not 0 <= float(t) <= 1
                    or not 0 <= int(cell_id) < self.mesh.GetNumberOfCells()
                    or np.linalg.norm(np.asarray(point) - (a + float(t) * (b-a))) > 1e-6
                    or abs(local[0]-x) > 1e-6 or abs(local[2]-z) > 1e-6
                    or self.ray_cell.GetCellType() != vtk.VTK_TRIANGLE):
                raise GeometryFailure('invalid/contradictory floor-probe hit')
            height = float(local[1])
        self.check()
        return {'modelXZ': [float(x), float(z)], 'hit': bool(hit), 'modelHeightY': height,
                'referenceCellID': int(cell_id) if hit else None,
                'rayFraction': float(t) if hit else None}

    def floor_probes(self, low_xz, high_xz, *, ray_top, ray_bottom):
        """Five fixed first-hit rays: centre and four quadrant centres.

        A hit is not semantically identified as floor. There is no acceptance
        threshold, surface following, support/coverage proof or clearance output.
        """
        self.check()
        low = self.vector(low_xz, 2, 'floor-probe footprint low')
        high = self.vector(high_xz, 2, 'floor-probe footprint high')
        vertical = self.vector([ray_top, ray_bottom], 2, 'floor-probe vertical bounds')
        if np.any(low >= high) or vertical[0] <= vertical[1]:
            raise ValueError('positive footprint and descending floor-probe interval required')
        locations = [(low + high) / 2]
        locations.extend(low + (high-low)*np.asarray([x, z])
                         for x, z in ((.25, .25), (.25, .75), (.75, .25), (.75, .75)))
        rows = [self._floor_ray(p[0], p[1], vertical[0], vertical[1]) for p in locations]
        self.check()
        return {'probes': rows, 'hitCount': sum(r['hit'] for r in rows),
                'missingCount': sum(not r['hit'] for r in rows),
                'rayTopModelY': float(vertical[0]), 'rayBottomModelY': float(vertical[1]),
                'pattern': 'centre and four quadrant centres', 'continuousSupportProven': False,
                'measuredCoverageEstablished': False, 'semanticFloorEstablished': False,
                'physicalClearanceEstablished': False, 'physicalAuthority': False}
