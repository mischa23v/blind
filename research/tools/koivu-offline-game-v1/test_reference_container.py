"""Authored evaluator fixtures only; never recorded-room trial counts."""
import unittest
import numpy as np
import vtk
from reference_container import ReferenceContainer, Container
from reference_geometry import ReferenceSurface, serial_vtk


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


def floor(y=0., lo=-3., hi=3.):
    return [[[lo,y,lo],[hi,y,lo],[hi,y,hi]],[[lo,y,lo],[hi,y,hi],[lo,y,hi]]]


class ReferenceContainerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls): serial_vtk()

    def scorer(self, triangles, transform=None):
        transform = np.eye(4) if transform is None else transform
        return ReferenceContainer(ReferenceSurface(mesh(triangles, transform)), transform)

    def test_clear_endpoints_do_not_hide_intermediate_thin_wall(self):
        s=self.scorer([[[0,0,-2],[0,2,-2],[0,1,2]]])
        self.assertFalse(s.swept_contact([-1,0,0],[-1,0,0])['contact'])
        self.assertFalse(s.swept_contact([1,0,0],[1,0,0])['contact'])
        self.assertTrue(s.swept_contact([-1,0,0],[1,0,0])['contact'])

    def test_wholly_contained_triangle_is_not_lost(self):
        s=self.scorer([[[0,.5,0],[.1,.5,0],[0,.6,.1]]])
        result=s.swept_contact([0,0,0],[0,0,0])
        self.assertTrue(result['contact'])
        self.assertEqual(result['reason'],'containedTriangleVertex')

    def test_large_crossing_triangle_with_no_vertex_inside(self):
        s=self.scorer([[[-3,.5,-3],[3,.5,-3],[0,.5,3]]])
        self.assertTrue(s.swept_contact([0,0,0],[0,0,0])['contact'])

    def test_near_feet_one_centimetre_geometry_retained(self):
        s=self.scorer([[[0,.01,0],[.1,.01,0],[0,.01,.1]]])
        self.assertTrue(s.swept_contact([0,0,0],[0,0,0])['contact'])

    def test_head_height_geometry_retained(self):
        s=self.scorer([[[0,1.59,0],[.1,1.59,0],[0,1.59,.1]]])
        self.assertTrue(s.swept_contact([0,0,0],[0,0,0])['contact'])

    def test_positive_similarity_equivalence(self):
        a=np.eye(4);theta=.49
        a[:3,:3]=1.02079084*np.asarray([[np.cos(theta),-np.sin(theta),0],
                                     [np.sin(theta),np.cos(theta),0],[0,0,1]])
        a[:3,3]=[2,-3,4]
        triangles=floor()+[[[0,.5,0],[.1,.5,0],[0,.6,.1]]]
        plain=self.scorer(triangles); transformed=self.scorer(triangles,a)
        for p in [[0,0,0],[1,0,1]]:
            self.assertEqual(plain.swept_contact(p,p)['contact'],transformed.swept_contact(p,p)['contact'])
            self.assertTrue(transformed.swept_support(p,p)['sampledSupportKnown'])

    def test_flat_support_offset_does_not_pass_on_spread_only(self):
        s=self.scorer(floor(y=-.20))
        result=s.swept_support([0,0,0],[0,0,0])
        self.assertEqual(result['missing'],0)
        self.assertLess(result['heightSpreadMetres'],1e-12)
        self.assertFalse(result['sampledSupportKnown'])

    def test_swept_support_hole_between_endpoints(self):
        triangles=[]
        for low,high in [(-3,-.15),(.15,3)]:
            triangles += [[[low,0,-3],[high,0,-3],[high,0,3]],
                          [[low,0,-3],[high,0,3],[low,0,3]]]
        s=self.scorer(triangles)
        self.assertTrue(s.swept_support([-1,0,0],[-1,0,0])['sampledSupportKnown'])
        self.assertTrue(s.swept_support([1,0,0],[1,0,0])['sampledSupportKnown'])
        self.assertFalse(s.swept_support([-1,0,0],[1,0,0])['sampledSupportKnown'])

    def test_square_corner_missing_support_is_not_disk_clearance(self):
        # A diamond under the centre has no support under the square corners.
        s=self.scorer([[[0,0,-.38],[.38,0,0],[0,0,.38]],
                       [[0,0,-.38],[0,0,.38],[-.38,0,0]]])
        self.assertFalse(s.swept_support([0,0,0],[0,0,0])['sampledSupportKnown'])

    def test_floor_contact_exclusion_is_small_and_explicit(self):
        s=self.scorer(floor())
        result=s.swept_contact([0,0,0],[0,0,0])
        self.assertFalse(result['contact'])
        self.assertEqual(result['floorContactExclusionMetres'],.002)
        self.assertFalse(result['closedSolidContainmentClassified'])

    def test_exact_side_boundary_contact(self):
        r=Container().half_extent
        s=self.scorer([[[r,.1,-.1],[r,.5,-.1],[r,.1,.1]]])
        self.assertTrue(s.swept_contact([0,0,0],[0,0,0])['contact'])

    def test_transform_cannot_change_through_external_array(self):
        a=np.eye(4);s=self.scorer(floor(),a)
        a[0,3]=100
        self.assertEqual(s.transform[0,3],0)
        self.assertFalse(s.transform.flags.writeable)
        self.assertTrue(s.swept_support([0,0,0],[0,0,0])['sampledSupportKnown'])

    def test_latched_error_blocks_positive_contact_and_cached_support(self):
        s=self.scorer(floor()+[[[0,.5,0],[.1,.5,0],[0,.6,.1]]])
        s._support_height(1,0,1)
        s.box.InvokeEvent('ErrorEvent')
        with self.assertRaises(RuntimeError): s.swept_contact([0,0,0],[0,0,0])
        with self.assertRaises(RuntimeError): s._support_height(1,0,1)

    def test_reference_mutation_retires_cached_answers(self):
        s=self.scorer(floor());s._support_height(1,0,1)
        s.surface.mesh.Modified()
        with self.assertRaises(RuntimeError): s._support_height(1,0,1)

    def test_descending_step_is_not_flat_floor_noise(self):
        triangles=[]
        for low,high,y in [(-3,0,0),(0,3,-.2)]:
            triangles += [[[low,y,-3],[high,y,-3],[high,y,3]],
                          [[low,y,-3],[high,y,3],[low,y,3]]]
        s=self.scorer(triangles)
        result=s.swept_support([-.4,0,0],[.4,0,0])
        self.assertFalse(result['sampledSupportKnown'])
        self.assertGreater(result['samplesBelowFootAssociation'],0)
        self.assertTrue(result['supportSpreadExceedsLimit'])

    def test_sloping_surface_is_not_flattened_by_reference_scoring(self):
        s=self.scorer([[[-3,-.3,-3],[3,.3,-3],[3,.3,3]],
                       [[-3,-.3,-3],[3,.3,3],[-3,-.3,3]]])
        result=s.swept_support([0,0,0],[.02,0,0])
        self.assertFalse(result['sampledSupportKnown'])
        self.assertTrue(result['supportSpreadExceedsLimit'])


if __name__ == '__main__': unittest.main(verbosity=2)
