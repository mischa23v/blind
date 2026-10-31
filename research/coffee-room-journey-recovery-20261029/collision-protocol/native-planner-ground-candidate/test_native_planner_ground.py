"""SOURCE ONLY: authored native-policy fixtures, never run during preparation."""
import math,unittest,json,pathlib
from types import SimpleNamespace
import numpy as np
from ground_support import GroundSupport,GroundSupportUnavailable
from native_planner_ground import NativeTriangleEligibility,NativePlannerGroundSupport,MODE,POLICY
from support_functions_native import connected_support

NATIVE_LIBRARY_PATH=None
NATIVE_LIBRARY_SHA256=None

def triangle(slope):
    # Upward winding: (v1-v0) cross (v2-v0) has positive Y.
    return np.array([[0,0,0],[0,0,1],[1,math.tan(math.radians(slope)),0]],dtype=np.float64)

def classify(native,v,t,seeds=None,ids=None,bounds=None):
    v=np.asarray(v,dtype=np.float64);t=np.asarray(t,dtype=np.int64)
    return NativePlannerGroundSupport.from_candidates(np.arange(len(t))if ids is None else np.asarray(ids),t,np.zeros(len(t)),np.ones(len(t),bool)if bounds is None else np.asarray(bounds,bool),[0]*9 if seeds is None else seeds,vertex_coordinates=v,native_classifier=native)

class NativeEligibilityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if NATIVE_LIBRARY_PATH is None or NATIVE_LIBRARY_SHA256 is None:raise RuntimeError('admitted compiled wrapper and SHA256 required; no skipped native controls')
        cls.native=NativeTriangleEligibility(NATIVE_LIBRARY_PATH,NATIVE_LIBRARY_SHA256)

    def test_fixed15_threshold_straddles_and_reports_identity(self):
        for slope,expected in ((0,True),(6.7,True),(14.99,True),(15.01,False),(60,False)):
            with self.subTest(slope=slope):self.assertEqual(self.native.classify(triangle(slope),np.array([[0,1,2]]))[0],expected)
        self.assertEqual(self.native.receipt['slopeDegrees'],15.);self.assertEqual(self.native.receipt['policy'],POLICY)

    def test_negative_winding_not_absolute_normal(self):
        v=triangle(0)
        self.assertTrue(self.native.classify(v,np.array([[0,1,2]]))[0])
        self.assertFalse(self.native.classify(v,np.array([[0,2,1]]))[0])
        with self.assertRaises(GroundSupportUnavailable):classify(self.native,v,[[0,2,1]])

    def test_saved_original_blocker_triangles_keep_original5_rejection(self):
        fixture=json.loads((pathlib.Path(__file__).parent/'BLOCKER_TRIANGLES.json').read_text())
        for row in fixture['faces']:
            v=np.array(row['originalXYZ'],dtype=np.float64);t=np.array([[0,1,2]]);ny=np.array([abs(row['normalFloat64'][1])])
            with self.subTest(originalFaceID=row['originalFaceID']):
                with self.assertRaises(GroundSupportUnavailable):GroundSupport.from_candidates(np.array([0]),t,ny,np.array([True]),[0]*9)
                self.assertEqual(classify(self.native,v,t).ground_cell_ids.tolist(),[0])

    def test_exact_xyz_seam_and_stable_original_face_ids(self):
        v=[[0,0,0],[1,0,0],[0,0,1],[0,0,1],[1,0,1],[1,0,0]]
        g=classify(self.native,v,[[0,2,1],[3,4,5]],[91]*8+[4],[91,4])
        self.assertEqual(g.ground_cell_ids.tolist(),[4,91]);self.assertEqual(g.receipt['groundAdjacencyMode'],MODE)
        self.assertEqual(g.receipt['maximumSlopeDegrees'],15.);self.assertFalse(g.receipt['initialMarkingIsFinalWalkability'])

    def test_epsilon_gap_and_point_only_touch_stay_disconnected(self):
        e=1e-12
        for v,t in (([[0,0,0],[1,0,0],[0,0,1],[e,0,1],[1+e,0,1],[1+e,0,0]],[[0,2,1],[3,4,5]]),([[0,0,0],[1,0,0],[0,0,1],[0,0,0],[-1,0,0],[0,0,-1]],[[0,2,1],[3,5,4]])):
            with self.assertRaises(GroundSupportUnavailable):classify(self.native,v,t,[0]*8+[1])

    def test_stacked_layers_remain_separate(self):
        v=[[0,0,0],[0,0,1],[1,0,0],[0,.01,0],[0,.01,1],[1,.01,0]]
        self.assertEqual(classify(self.native,v,[[0,1,2],[3,4,5]]).ground_cell_ids.tolist(),[0])
        with self.assertRaises(GroundSupportUnavailable):classify(self.native,v,[[0,1,2],[3,4,5]],[0]*8+[1])

    def test_nine_seeds_and_patch_bounds_remain_required(self):
        for seeds,bounds in (([0]*8,[True]),([0]*9,[False])):
            with self.assertRaises(GroundSupportUnavailable):classify(self.native,triangle(0),[[0,1,2]],seeds,bounds=bounds)

    def test_inputs_unchanged_and_invalid_inputs_refused(self):
        v=triangle(3);t=np.array([[0,1,2]],dtype=np.int64);a=v.copy();b=t.copy();self.native.classify(v,t)
        np.testing.assert_array_equal(v,a);np.testing.assert_array_equal(t,b)
        with self.assertRaises(ValueError):self.native.classify(v,np.array([[0,1,99]]))
        bad=v.copy();bad[0,0]=np.nan
        with self.assertRaises(ValueError):self.native.classify(bad,t)

    def test_support_receipt_names_native_policy_without_five_degree_claim(self):
        probes={'probes':[{'hit':True,'modelHeightY':0.,'referenceCellID':0}for _ in range(9)]}
        result=connected_support(probes,SimpleNamespace(is_ground=lambda _:True),0.)
        self.assertTrue(result['acceptedFiniteSupportModel']);self.assertIn('signed15',result['supportPolicy']);self.assertNotIn('<=5',result['supportPolicy'])

    def test_one_cm_vertical_riser_remains_non_ground_raw_contact(self):
        import vtk
        from reference_geometry import ReferenceSurface,serial_vtk
        from oriented_container import OrientedReferenceContainer
        from oriented_ground_container import GroundedReferenceContainer
        serial_vtk();points=vtk.vtkPoints();points.SetDataTypeToDouble()
        for p in [[-3,0,-3],[3,0,-3],[3,0,3],[-3,0,3],[0,0,-.1],[0,.01,-.1],[0,.01,.1]]:points.InsertNextPoint(*p)
        cells=vtk.vtkCellArray()
        for t in [[0,2,1],[0,3,2],[4,5,6]]:
            cells.InsertNextCell(3)
            for i in t:cells.InsertCellPoint(i)
        mesh=vtk.vtkPolyData();mesh.SetPoints(points);mesh.SetPolys(cells);surface=ReferenceSurface(mesh)
        raw=OrientedReferenceContainer(surface,np.eye(4));probes=raw.support_probes([-1,0,0],0)
        ground=NativePlannerGroundSupport.from_scorer(raw,[[-1,0,0],[1,0,0]],[p['referenceCellID']for p in probes['probes']],native_classifier=self.native)
        scored=GroundedReferenceContainer(surface,np.eye(4),ground=ground)
        before=raw.swept_contacts([0,0,0],[0,0,0],0,0);after=scored.swept_contacts([0,0,0],[0,0,0],0,0)
        self.assertTrue(before['actualBody']['contact']);self.assertTrue(after['actualBody']['contact']);self.assertFalse(ground.is_ground(2));self.assertGreater(after['actualBody']['nonGroundContactCount'],0)
        self.assertFalse(after['actualBody']['physicalAuthority']);surface.mesh.Modified()
        with self.assertRaises(GroundSupportUnavailable):ground.is_ground(0)

if __name__=='__main__':unittest.main()
