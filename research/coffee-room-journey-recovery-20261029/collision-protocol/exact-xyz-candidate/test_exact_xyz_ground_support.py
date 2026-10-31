"""Authored, NOT RUN: exact-edge candidate regressions, not real-world evidence."""
import math, unittest
import numpy as np
from ground_support import GroundSupport, GroundSupportUnavailable
from exact_xyz_ground_support import ExactXYZGroundSupport, MODE


def arrays(vertices,triangles):
    v=np.asarray(vertices,dtype=np.float64);t=np.asarray(triangles,dtype=np.int64)
    p=v[t];normal=np.cross(p[:,1]-p[:,0],p[:,2]-p[:,0]);norm=np.linalg.norm(normal,axis=1)
    ny=np.full(len(t),np.nan);good=norm>0;ny[good]=np.abs(normal[good,1])/norm[good]
    return v,t,ny


def classify(vertices,triangles,seeds=None,ids=None,bounds=None):
    v,t,ny=arrays(vertices,triangles)
    return ExactXYZGroundSupport.from_candidates(
        np.arange(len(t),dtype=np.int64) if ids is None else np.asarray(ids,dtype=np.int64),
        t,ny,np.ones(len(t),bool) if bounds is None else np.asarray(bounds,bool),
        [0]*9 if seeds is None else seeds,vertex_coordinates=v)


class ExactEdgeTests(unittest.TestCase):
    def test_exact_duplicate_coordinate_uv_style_seam_joins_only_candidate(self):
        v=[[0,0,0],[1,0,0],[0,0,1],[0,0,1],[1,0,1],[1,0,0]]
        t=[[0,1,2],[3,4,5]];seeds=[0]*8+[1];points,tri,ny=arrays(v,t)
        with self.assertRaises(GroundSupportUnavailable):
            GroundSupport.from_candidates(np.arange(2),tri,ny,np.ones(2,bool),seeds)
        before=points.copy();g=ExactXYZGroundSupport.from_candidates(np.arange(2),tri,ny,np.ones(2,bool),seeds,vertex_coordinates=points)
        self.assertEqual(g.ground_cell_ids.tolist(),[0,1]);np.testing.assert_array_equal(points,before)
        self.assertEqual(g.receipt['groundAdjacencyMode'],MODE)
        self.assertFalse(g.receipt['positionWelding']);self.assertFalse(g.receipt['originalMeshCoordinatesChanged'])

    def test_epsilon_separated_edge_stays_disconnected(self):
        e=1e-12
        v=[[0,0,0],[1,0,0],[0,0,1],[e,0,1],[1+e,0,1],[1+e,0,0]]
        with self.assertRaises(GroundSupportUnavailable):classify(v,[[0,1,2],[3,4,5]],[0]*8+[1])
        self.assertEqual(classify(v,[[0,1,2],[3,4,5]]).ground_cell_ids.tolist(),[0])

    def test_duplicate_vertex_only_touch_does_not_join(self):
        v=[[0,0,0],[1,0,0],[0,0,1],[0,0,0],[-1,0,0],[0,0,-1]]
        with self.assertRaises(GroundSupportUnavailable):classify(v,[[0,1,2],[3,4,5]],[0]*8+[1])

    def test_stacked_layers_remain_separate(self):
        v=[[0,0,0],[1,0,0],[0,0,1],[0,.01,0],[1,.01,0],[0,.01,1]]
        self.assertEqual(classify(v,[[0,1,2],[3,4,5]]).ground_cell_ids.tolist(),[0])
        with self.assertRaises(GroundSupportUnavailable):classify(v,[[0,1,2],[3,4,5]],[0]*8+[1])

    def test_one_cm_riser_and_top_not_admitted(self):
        v=[[0,0,0],[1,0,0],[0,0,1],[1,0,1],[1,.01,0],[1,.01,1],[2,.01,0],[2,.01,1]]
        t=[[0,1,2],[1,3,2],[1,4,3],[4,5,3],[4,6,5],[6,7,5]]
        self.assertEqual(classify(v,t).ground_cell_ids.tolist(),[0,1])

    def test_all_nine_and_five_degree_limit_unchanged(self):
        with self.assertRaises(GroundSupportUnavailable):classify([[0,0,0],[1,0,0],[0,0,1]],[[0,1,2]],[0]*8)
        y=math.tan(math.radians(5.715404165))
        with self.assertRaises(GroundSupportUnavailable):classify([[0,0,0],[1,y,0],[0,0,1]],[[0,1,2]])

    def test_original_face_ids_and_patch_filter_preserved(self):
        v=[[0,0,0],[1,0,0],[0,0,1],[0,0,1],[1,0,1],[1,0,0]]
        g=classify(v,[[0,1,2],[3,4,5]],[91]*9,[91,4],[True,False])
        self.assertEqual(g.ground_cell_ids.tolist(),[91]);self.assertFalse(g.ground_cell_ids.flags.writeable)
        with self.assertRaises(GroundSupportUnavailable):classify(v,[[0,1,2],[3,4,5]],[91]*8+[4],[91,4],[True,False])

    def test_nonfinite_or_nondouble_coordinates_refused(self):
        points,tri,ny=arrays([[0,0,0],[1,0,0],[0,0,1]],[[0,1,2]])
        for v in (points.astype(np.float32),np.full((3,3),np.nan)):
            with self.assertRaises(ValueError):ExactXYZGroundSupport.from_candidates(np.array([0]),tri,ny,np.array([True]),[0]*9,vertex_coordinates=v)


class CandidateBoundContactTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        from reference_geometry import serial_vtk
        serial_vtk()

    def test_one_cm_riser_remains_non_ground_contact(self):
        from test_oriented_ground_container import scene
        from oriented_ground_container import GroundedReferenceContainer,OrientedReferenceContainer
        surface=scene([[0,0,-.1],[0,.01,-.1],[0,.01,.1]],[[0,1,2]])
        original=OrientedReferenceContainer(surface,np.eye(4))
        probes=original.support_probes([-1,0,0],0)
        g=ExactXYZGroundSupport.from_scorer(original,[[-1,0,0],[1,0,0]],[p['referenceCellID']for p in probes['probes']])
        candidate=GroundedReferenceContainer(surface,np.eye(4),ground=g)
        r=candidate.swept_contacts([0,0,0],[0,0,0],0,0)['actualBody']
        self.assertTrue(r['contact']);self.assertFalse(g.is_ground(2));self.assertGreater(r['nonGroundContactCount'],0)
        self.assertEqual(g.receipt['groundAdjacencyMode'],MODE)
        self.assertFalse(r['physicalAuthority']);self.assertFalse(r['lowHeightAloneExcluded'])

    def test_owner_mutation_retires_candidate(self):
        from test_oriented_ground_container import scene
        from oriented_container import OrientedReferenceContainer
        surface=scene();original=OrientedReferenceContainer(surface,np.eye(4))
        probes=original.support_probes([-1,0,0],0)
        g=ExactXYZGroundSupport.from_scorer(original,[[-1,0,0],[1,0,0]],[p['referenceCellID']for p in probes['probes']])
        surface.mesh.Modified()
        with self.assertRaises(GroundSupportUnavailable):g.is_ground(0)

if __name__=='__main__':unittest.main()
