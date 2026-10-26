"""Authored physical-result and positive native-order replay equivalence."""
from pathlib import Path
from unittest.mock import patch
import hashlib,math,sys,unittest
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'ground-obb-v6'))
import test_oriented_ground_obb_container as fixture
from oriented_ground_obb_container import GroundOBBReferenceContainer,GeometryFailure
from oriented_ground_tiled_container import GroundTiledReferenceContainer
from build_tiled_source import ORIGINAL,EXPECTED,OLD_QUERY,NEW_QUERY
from run_pilot import contact_status


class TiledScorerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):fixture.serial_vtk()
    def pair(self,extras=(),transform=None,cap=200000,ordered=False):
        surface=fixture.scene(extras,transform=transform)
        if ordered:
            surface.locator.AutomaticOff();surface.locator.SetDivisions(12,12,12);surface.locator.BuildLocator()
        _,original=fixture.pair(surface,transform,cap)
        fast=GroundTiledReferenceContainer(surface,original.transform,ground=original.ground,maximum_candidate_cells=cap)
        return original,fast
    def same(self,old,new):
        if old['contact']:self.assertEqual(old,new)
        else:
            self.assertEqual(set(old),set(new))
            for key in old:
                if key!='skippedGroundCandidateIDsFirst16':self.assertEqual(old[key],new[key],key)
            self.assertEqual(new['skippedGroundCandidateIDsFirst16'],sorted(new['skippedGroundCandidateIDsFirst16']))
    def rows(self,fast):
        for row in fast.optimization_rows:
            self.assertTrue(row['completed']);self.assertIsNone(row['exceptionType'])
            self.assertEqual(row['actualExactTriangleCounterDelta'],row['prepassExactTriangleTests']+row['fallbackExactTriangleTests'])
            self.assertEqual(row['actualBoxQueryCounterDelta'],row['prepassBoxQueryDelta']+row['fallbackBoxQueryDelta'])
            self.assertEqual(row['nativeBoundsCallsTotal'],row['tiledQuery']['tileQueries']+int(row['fallbackUsed']))
            self.assertEqual(row['fallbackNativeBoundsCalls'],int(row['fallbackUsed']))
            self.assertTrue(row['returnedResultCountsDescribeReturnedPassOnly'])
            self.assertGreaterEqual(row['totalWallSeconds'],row['prepassWallSeconds']+row['fallbackWallSeconds'])
    def compare(self,pair,start=(0,0,0),end=(0,0,0),yaw=0,delta=0):
        old,fast=pair;a=old.swept_contacts(start,end,yaw,delta);b=fast.swept_contacts(start,end,yaw,delta)
        for key in a:
            if key in('actualBody','horizontalMargin'):self.same(a[key],b[key])
            else:self.assertEqual(a[key],b[key])
        self.assertEqual(contact_status(a),contact_status(b));self.rows(fast)
        self.assertEqual(sum(r['actualExactTriangleCounterDelta']for r in fast.optimization_rows),fast.triangle_queries)
        self.assertEqual(sum(r['actualBoxQueryCounterDelta']for r in fast.optimization_rows),fast.box_queries)
        return a,b,fast
    def test_mechanical_contact_body_diff_only_query(self):
        original=ORIGINAL.read_text();self.assertEqual(hashlib.sha256(original.encode()).hexdigest(),EXPECTED)
        method=original[original.index('    def contact_corners(self,corners):'):]
        generated=(Path(__file__).parent/'oriented_ground_tiled_container.py').read_text()
        copied=generated[generated.index('    def _tiled_contact_corners(self,corners):'):]
        restored=copied.replace('    def _tiled_contact_corners(self,corners):','    def contact_corners(self,corners):',1).replace(NEW_QUERY,OLD_QUERY)
        self.assertEqual(restored,method)
    def test_ground_only_negative_has_no_fallback(self):
        _,b,fast=self.compare(self.pair())
        self.assertFalse(b['actualBody']['contact'])
        self.assertTrue(all(not r['fallbackUsed']for r in fast.optimization_rows))
    def test_candidate_digest_matches_sorted_native_original_IDs(self):
        old,fast=self.pair([[[0,.5,0],[.01,.5,0],[0,.5,.01]]],ordered=True)
        corners=fixture.box_corners();old.contact_corners(corners)
        native=np.fromiter((old.ids.GetId(i)for i in range(old.ids.GetNumberOfIds())),dtype=np.int64)
        expected=hashlib.sha256(np.sort(native).astype('<i8',copy=False).tobytes(order='C')).hexdigest()
        fast.contact_corners(corners);row=fast.optimization_rows[0]
        self.assertEqual(row['sortedCandidateIDsSHA256'],expected)
        self.assertGreaterEqual(row['candidateDigestWallSeconds'],0.)
        self.assertTrue(row['candidateDigestIncludedInPrepassTime'])
    def test_contained_positive_exact_original_result(self):
        _,b,fast=self.compare(self.pair([[[0,.5,0],[.01,.5,0],[0,.5,.01]]]))
        self.assertTrue(b['actualBody']['contact'])
        self.assertTrue(all(r['fallbackUsed']and r['fallbackCompleted']for r in fast.optimization_rows))
        self.assertTrue(all(r['actualExactTriangleCounterDelta']==2*r['returnedPassExactTriangleTests']for r in fast.optimization_rows))
    def test_native_first_id_differs_from_sorted_prepass_and_is_restored(self):
        extras=[[[0,.5,.1],[.01,.5,.1],[0,.5,.11]],[[0,.02,-.1],[.01,.02,-.1],[0,.02,-.09]]]
        a,b,fast=self.compare(self.pair(extras,ordered=True))
        self.assertEqual(fast.optimization_rows[0]['prepassFirstReferenceCellID'],2)
        self.assertEqual(a['actualBody']['firstReferenceCellID'],3)
        self.assertEqual(b['actualBody']['firstReferenceCellID'],3)
        self.assertEqual(contact_status(b),'firstContactTriangleNearFootAmbiguous')
        self.assertEqual(b['actualBody']['nonGroundContactCount'],2)
    def test_thin_one_cm_riser_preserved(self):
        _,b,_=self.compare(self.pair([[[0,.01,-.01],[0,.02,-.01],[0,.02,.01]]]))
        self.assertTrue(b['actualBody']['contact'])
    def test_head_contact_preserved(self):
        _,b,_=self.compare(self.pair([[[-.1,1.59,-.1],[.1,1.59,-.1],[0,1.59,.1]]]))
        self.assertTrue(b['actualBody']['contact'])
    def test_margin_only_fallback_keeps_raw_body_clear(self):
        _,b,fast=self.compare(self.pair([[[.25,.5,-.01],[.25,.7,-.01],[.25,.5,.01]]]))
        self.assertFalse(b['actualBody']['contact']);self.assertTrue(b['horizontalMargin']['contact'])
        self.assertFalse(fast.optimization_rows[0]['fallbackUsed']);self.assertTrue(fast.optimization_rows[1]['fallbackUsed'])
    def test_rotated_swept_similarity(self):
        self.compare(self.pair([[[.18,.5,.18],[.19,.6,.18],[.18,.5,.19]]],fixture.similarity()),
            start=(-.01,0,0),end=(.01,.001,.005),yaw=.3,delta=math.radians(1))
    def test_closed_and_tolerance_admitted_faces_preserved(self):
        corners=fixture.box_corners()
        for axis in range(3):
            for coordinate in(0.,1.,-.5e-6,1+.5e-6):
                with self.subTest(axis=axis,coordinate=coordinate):
                    old,fast=self.pair([fixture.model_triangle(corners,axis,coordinate)],fixture.similarity())
                    a=old.contact_corners(corners);b=fast.contact_corners(corners)
                    self.assertTrue(a['contact']);self.assertEqual(a,b);self.rows(fast)
    def test_negative_bounds_rejection_avoids_fallback(self):
        corners=fixture.box_corners();old,fast=self.pair([fixture.model_triangle(corners,0,1.05)],fixture.similarity())
        a=old.contact_corners(corners);b=fast.contact_corners(corners);self.same(a,b)
        self.assertFalse(b['contact']);self.assertEqual(b['exactNonGroundTriangleTests'],0);self.assertFalse(fast.optimization_rows[0]['fallbackUsed'])
    def test_candidate_cap_not_truncated_or_scored_clear(self):
        old,fast=self.pair(cap=1)
        for scorer in(old,fast):
            with self.assertRaises(GeometryFailure):scorer.contact_corners(fixture.box_corners())
        self.assertFalse(fast.optimization_rows[0]['completed']);self.assertIsNone(fast.optimization_rows[0]['nativeBoundsCallsTotal'])
    def test_mesh_mutation_never_returns_clear(self):
        old,fast=self.pair();old.mesh.Modified()
        for scorer in(old,fast):
            with self.assertRaises(RuntimeError):scorer.contact_corners(fixture.box_corners())
        self.assertFalse(fast.optimization_rows[0]['completed'])
    def test_positive_prepass_original_negative_disagreement_fails_closed(self):
        _,fast=self.pair([[[0,.5,0],[.01,.5,0],[0,.5,.01]]])
        with patch.object(GroundOBBReferenceContainer,'contact_corners',return_value={'contact':False}):
            with self.assertRaisesRegex(GeometryFailure,'positive tiled prepass disagrees'):fast.contact_corners(fixture.box_corners())
        self.assertFalse(fast.optimization_rows[0]['completed'])
    def test_positive_count_disagreement_fails_closed(self):
        old,fast=self.pair([[[0,.5,0],[.01,.5,0],[0,.5,.01]]]);corners=fixture.box_corners()
        bad=old.contact_corners(corners);bad['nonGroundContactCount']+=1
        with patch.object(GroundOBBReferenceContainer,'contact_corners',return_value=bad):
            with self.assertRaisesRegex(GeometryFailure,'contact count disagreement'):fast.contact_corners(corners)
        self.assertFalse(fast.optimization_rows[0]['completed'])
    def test_fallback_exception_never_becomes_negative(self):
        _,fast=self.pair([[[0,.5,0],[.01,.5,0],[0,.5,.01]]])
        with patch.object(GroundOBBReferenceContainer,'contact_corners',side_effect=GeometryFailure('authored fallback failure')):
            with self.assertRaisesRegex(GeometryFailure,'authored fallback failure'):fast.contact_corners(fixture.box_corners())
        self.assertFalse(fast.optimization_rows[0]['completed']);self.assertIsNone(fast.optimization_rows[0]['nativeBoundsCallsTotal'])
    def test_support_probe_output_unchanged(self):
        old,fast=self.pair();self.assertEqual(old.support_probes([0,0,0],.3),fast.support_probes([0,0,0],.3))
        self.assertEqual(fast.optimization_rows,[])


if __name__=='__main__':unittest.main(verbosity=2)
