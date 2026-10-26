"""Focused authored ground/non-ground fixtures; no real mesh or episode."""
import unittest
from pathlib import Path
import sys
sys.path.append(str(Path(__file__).resolve().parents[1]/'ground-follow-v2'))
import numpy as np
import vtk
from oriented_ground_container import GroundedReferenceContainer,OrientedReferenceContainer
from ground_support import GroundSupport
from reference_geometry import ReferenceSurface,serial_vtk


def scene(extra_vertices=(),extra_triangles=(),ground_y=0.):
    vertices=[[-3,ground_y,-3],[3,ground_y,-3],[3,ground_y,3],[-3,ground_y,3]]
    vertices.extend(extra_vertices)
    triangles=[[0,1,2],[0,2,3]]+[[i+4 for i in t]for t in extra_triangles]
    points=vtk.vtkPoints();points.SetDataTypeToDouble()
    for p in vertices:points.InsertNextPoint(*p)
    cells=vtk.vtkCellArray()
    for t in triangles:
        cells.InsertNextCell(3)
        for i in t:cells.InsertCellPoint(i)
    mesh=vtk.vtkPolyData();mesh.SetPoints(points);mesh.SetPolys(cells)
    return ReferenceSurface(mesh)


def scorer(surface):
    original=OrientedReferenceContainer(surface,np.eye(4))
    # Initial support on the same floor, away from every authored object.
    probes=original.support_probes([-1,0,0],0)
    ids=[p['referenceCellID']for p in probes['probes']]
    ground=GroundSupport.from_scorer(original,[[-1,0,0],[1,0,0]],ids,[[p['modelXZ'][0],p['modelHeightY'],p['modelXZ'][1]]for p in probes['probes']])
    return GroundedReferenceContainer(surface,np.eye(4),ground=ground),original


class GroundedCollisionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):serial_vtk()

    def test_ground_only_overlap_is_excluded_and_counted(self):
        g,old=scorer(scene(ground_y=.01))
        self.assertTrue(old.swept_contacts([0,0,0],[0,0,0],0,0)['actualBody']['contact'])
        result=g.swept_contacts([0,0,0],[0,0,0],0,0)
        for k in ('actualBody','horizontalMargin'):
            self.assertFalse(result[k]['contact']);self.assertEqual(result[k]['groundContactCount'],2)
            self.assertEqual(result[k]['nonGroundContactCount'],0);self.assertTrue(result[k]['groundContactEvent'])

    def test_detached_flat_one_cm_top_remains_contact(self):
        g,_=scorer(scene([[0,.01,0],[.02,.01,0],[0,.01,.02]],[[0,1,2]]))
        self.assertFalse(g.ground.is_ground(2))
        r=g.swept_contacts([0,0,0],[0,0,0],0,0)['actualBody']
        self.assertTrue(r['contact']);self.assertEqual(r['firstReferenceCellID'],2)
        self.assertEqual(r['groundContactCount'],0);self.assertFalse(r['lowHeightAloneExcluded'])

    def test_one_cm_riser_remains_contact(self):
        g,_=scorer(scene([[0,0,-.1],[0,.01,-.1],[0,.01,.1]],[[0,1,2]]))
        r=g.swept_contacts([0,0,0],[0,0,0],0,0)['actualBody']
        self.assertTrue(r['contact']);self.assertFalse(g.ground.is_ground(2))

    def test_wall_and_head_are_unchanged_obstacles(self):
        for vertices in ([[0,.5,-.1],[0,1.5,-.1],[0,.5,.1]],
                         [[-.1,1.59,-.1],[.1,1.59,-.1],[0,1.59,.1]]):
            with self.subTest(vertices=vertices):
                g,old=scorer(scene(vertices,[[0,1,2]]))
                before=old.swept_contacts([0,0,0],[0,0,0],0,0)
                after=g.swept_contacts([0,0,0],[0,0,0],0,0)
                self.assertEqual(before['actualBody']['contact'],after['actualBody']['contact'])
                self.assertTrue(after['actualBody']['contact'])

    def test_ground_counts_finish_after_non_ground_contact(self):
        # Both actual overlaps are counted, never a broadphase-only exemption.
        g,_=scorer(scene([[0,.02,0],[.02,.02,0],[0,.02,.02]],[[0,1,2]],ground_y=.01))
        r=g.swept_contacts([0,0,0],[0,0,0],0,0)['actualBody']
        self.assertTrue(r['contact']);self.assertEqual(r['groundContactCount'],2)
        self.assertEqual(r['nonGroundContactCount'],1)
        np.testing.assert_allclose(r['firstTriangleModelHeightRange'],[.02,.02])

    def test_ground_broadphase_without_intersection_is_not_counted(self):
        g,_=scorer(scene())
        r=g.swept_contacts([0,0,0],[0,0,0],0,0)['actualBody']
        self.assertFalse(r['contact']);self.assertEqual(r['groundContactCount'],0)

    def test_cannot_reuse_ground_face_ids_with_other_mesh_or_transform(self):
        g,_=scorer(scene())
        with self.assertRaises(RuntimeError):GroundedReferenceContainer(scene(),np.eye(4),ground=g.ground)
        t=np.eye(4);t[0,3]=1
        with self.assertRaises(RuntimeError):GroundedReferenceContainer(g.surface,t,ground=g.ground)

    def test_mutation_retires_ground_exemption_and_support_probes(self):
        g,_=scorer(scene());g.surface.mesh.Modified()
        with self.assertRaises(RuntimeError):g.swept_contacts([0,0,0],[0,0,0],0,0)
        with self.assertRaises(RuntimeError):g.support_probes([0,0,0],0)

    def test_inherited_ground_probes_return_heights_not_acceptance(self):
        g,_=scorer(scene(ground_y=.01));r=g.support_probes([0,0,0],0)
        self.assertEqual(r['hitCount'],9)
        np.testing.assert_allclose([p['modelHeightY']for p in r['probes']],[.01]*9)
        self.assertFalse(r['semanticFloorEstablished']);self.assertFalse(r['physicalClearanceEstablished'])


if __name__=='__main__':unittest.main(verbosity=2)
