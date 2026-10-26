"""Tiny authored VTK fixtures only; no recorded frame, FARO mesh or game run."""
from pathlib import Path
import sys
import unittest
import numpy as np
import vtk
from reference_band_box import ReferenceBandBox, GeometryFailure
from reference_geometry import ReferenceSurface, serial_vtk

WS = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(WS / 'blind-koivu-game-07'))
from reference_container import ReferenceContainer, Container


def mesh(triangles, transform=None):
    transform = np.eye(4) if transform is None else np.asarray(transform)
    points = vtk.vtkPoints(); points.SetDataTypeToDouble()
    cells = vtk.vtkCellArray()
    for tri in triangles:
        cells.InsertNextCell(3)
        for p in tri:
            q = transform @ [*p, 1.]
            cells.InsertCellPoint(points.InsertNextPoint(*q[:3]))
    value = vtk.vtkPolyData(); value.SetPoints(points); value.SetPolys(cells)
    return value


def floor(y=0.):
    return [[[-3,y,-3],[3,y,-3],[3,y,3]], [[-3,y,-3],[3,y,3],[-3,y,3]]]


def transform():
    a = np.eye(4); theta = .49
    a[:3,:3] = 1.02079084*np.asarray([[np.cos(theta),-np.sin(theta),0],
                                     [np.sin(theta),np.cos(theta),0],[0,0,1]])
    a[:3,3] = [2,-3,4]
    return a


class BandBoxTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls): serial_vtk()

    def scorer(self, triangles, a=None, **kwargs):
        a = np.eye(4) if a is None else a
        return ReferenceBandBox(ReferenceSurface(mesh(triangles,a)), a, **kwargs)

    def test_one_to_one_point_five_cm_band(self):
        s = self.scorer([[[0,.012,0],[.01,.012,0],[0,.012,.01]]])
        self.assertTrue(s.contact([-.025,.01,-.025],[.025,.015,.025])['contact'])
        self.assertFalse(s.contact([-.025,.015,-.025],[.025,.025,.025])['contact'])

    def test_one_point_five_to_two_point_five_cm_band(self):
        s = self.scorer([[[0,.02,0],[.01,.02,0],[0,.02,.01]]])
        self.assertFalse(s.contact([-.025,.01,-.025],[.025,.015,.025])['contact'])
        self.assertTrue(s.contact([-.025,.015,-.025],[.025,.025,.025])['contact'])

    def test_contained_triangle_fallback(self):
        s = self.scorer([[[0,.012,0],[.01,.012,0],[0,.012,.01]]])
        r = s.contact([-.025,.01,-.025],[.025,.015,.025])
        self.assertTrue(r['contact']); self.assertEqual(r['reason'],'containedTriangleVertex')

    def test_crossing_without_vertex_inside(self):
        s = self.scorer([[[-1,.012,-1],[1,.012,-1],[0,.012,1]]])
        self.assertTrue(s.contact([-.025,.01,-.025],[.025,.015,.025])['contact'])

    def test_closed_vertical_band_boundary_is_shared(self):
        s = self.scorer([[[0,.015,0],[.01,.015,0],[0,.015,.01]]])
        for low, high in ((.01,.015),(.015,.025)):
            r = s.contact([-.025,low,-.025],[.025,high,.025])
            self.assertTrue(r['contact']); self.assertTrue(r['closedBoundaries'])

    def test_closed_horizontal_side_boundary(self):
        s = self.scorer([[[.025,.011,-.01],[.025,.014,-.01],[.025,.011,.01]]])
        self.assertTrue(s.contact([-.025,.01,-.025],[.025,.015,.025])['contact'])

    def test_no_hit_is_not_a_clearance_or_coverage_claim(self):
        s = self.scorer(floor())
        r = s.contact([-.025,.01,-.025],[.025,.015,.025])
        self.assertFalse(r['contact']); self.assertFalse(r['physicalClearanceEstablished'])
        self.assertFalse(r['measuredCoverageEstablished']); self.assertFalse(r['closedSolidContainmentClassified'])

    def test_no_implicit_floor_exclusion(self):
        s = self.scorer(floor())
        self.assertTrue(s.contact([-.025,-.001,-.025],[.025,.001,.025])['contact'])

    def test_invalid_bounds_rejected(self):
        s = self.scorer(floor())
        for lo, hi in (([0,0,0],[0,1,1]),([1,0,0],[0,1,1]),
                       ([np.nan,0,0],[1,1,1]),([0,0],[1,1,1])):
            with self.subTest(lo=lo), self.assertRaises(ValueError): s.contact(lo,hi)

    def test_invalid_caps_rejected(self):
        for cap in (0,-1,True,1.5,200001):
            with self.subTest(cap=cap), self.assertRaises(ValueError):
                self.scorer(floor(),maximum_candidate_cells=cap)

    def test_candidate_cap_fails_not_clear(self):
        s = self.scorer(floor(.012),maximum_candidate_cells=1)
        with self.assertRaises(GeometryFailure): s.contact([-.025,.01,-.025],[.025,.015,.025])

    def test_mesh_mutation_retires_box_and_probe_answers(self):
        s = self.scorer(floor()); s.surface.mesh.Modified()
        with self.assertRaises(GeometryFailure): s.contact([0,.1,0],[1,.2,1])
        with self.assertRaises(GeometryFailure): s.floor_probes([0,0],[.05,.05],ray_top=.15,ray_bottom=-.25)

    def test_latched_vtk_error_retires_contact(self):
        s = self.scorer(floor(.012)); s.box.InvokeEvent('ErrorEvent')
        with self.assertRaises(GeometryFailure): s.contact([-.025,.01,-.025],[.025,.015,.025])

    def test_positive_similarity_equivalence(self):
        triangles = floor()+[[[0,.012,0],[.01,.012,0],[0,.012,.01]]]
        plain = self.scorer(triangles); moved = self.scorer(triangles,transform())
        for low, high in (([-.025,.01,-.025],[.025,.015,.025]),([1,.01,1],[1.05,.015,1.05])):
            self.assertEqual(plain.contact(low,high)['contact'],moved.contact(low,high)['contact'])

    def test_transform_is_private_and_invalid_similarity_rejected(self):
        a = transform(); s = self.scorer(floor(),a); old = s.transform.copy(); a[0,3] = 999
        np.testing.assert_array_equal(s.transform,old); self.assertFalse(s.transform.flags.writeable)
        bad = np.eye(4); bad[0,0] = 2
        with self.assertRaises(GeometryFailure): self.scorer(floor(),bad)

    def test_golden_agreement_with_unchanged_whole_body_scorer(self):
        triangles = floor()+[[[0,.01,0],[.1,.01,0],[0,.01,.1]],
                             [[.8,0,-2],[.8,2,-2],[.8,1,2]]]
        for a in (np.eye(4),transform()):
            surface = ReferenceSurface(mesh(triangles,a))
            generic = ReferenceBandBox(surface,a); old = ReferenceContainer(surface,a); c = Container()
            for start,end in (([-1,0,1],[-1,0,1]),([0,0,0],[0,0,0]),([.3,0,1],[1.3,0,1])):
                lo = np.minimum(start,end)+[-c.half_extent,c.floor_contact_exclusion,-c.half_extent]
                hi = np.maximum(start,end)+[c.half_extent,c.height,c.half_extent]
                self.assertEqual(generic.contact(lo,hi)['contact'],old.swept_contact(start,end)['contact'])

    def test_fixed_floor_probe_pattern_and_height_only(self):
        for a in (np.eye(4),transform()):
            s = self.scorer(floor(-.02),a)
            r = s.floor_probes([0,0],[.04,.08],ray_top=.15,ray_bottom=-.25)
            self.assertEqual((r['hitCount'],r['missingCount']),(5,0))
            np.testing.assert_allclose([p['modelXZ']for p in r['probes']],
                                       [[.02,.04],[.01,.02],[.01,.06],[.03,.02],[.03,.06]])
            np.testing.assert_allclose([p['modelHeightY']for p in r['probes']],[-.02]*5,atol=1e-12)
            self.assertFalse(r['semanticFloorEstablished']); self.assertFalse(r['physicalClearanceEstablished'])
            self.assertFalse(r['continuousSupportProven'])

    def test_missing_probes_remain_missing(self):
        s = self.scorer(floor())
        r = s.floor_probes([5,5],[5.05,5.05],ray_top=.15,ray_bottom=-.25)
        self.assertEqual((r['hitCount'],r['missingCount']),(0,5))
        self.assertTrue(all(p['modelHeightY'] is None and p['referenceCellID'] is None for p in r['probes']))

    def test_probe_takes_nearest_surface_without_floor_label(self):
        s = self.scorer(floor(-.02)+floor(.1))
        r = s.floor_probes([0,0],[.05,.05],ray_top=.15,ray_bottom=-.25)
        np.testing.assert_allclose([p['modelHeightY']for p in r['probes']],[.1]*5)
        self.assertFalse(r['semanticFloorEstablished'])

    def test_invalid_probe_intervals_rejected(self):
        s = self.scorer(floor())
        for lo, hi, top, bottom in (([0,0],[0,1],.15,-.25),([0,0],[1,1],-.25,.15),
                                    ([0,0],[1,1],np.nan,0)):
            with self.assertRaises(ValueError): s.floor_probes(lo,hi,ray_top=top,ray_bottom=bottom)


if __name__ == '__main__': unittest.main(verbosity=2)
