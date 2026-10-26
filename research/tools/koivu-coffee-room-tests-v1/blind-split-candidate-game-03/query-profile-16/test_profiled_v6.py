"""Tiny exact-output instrumentation equivalence, no recorded mesh or episode."""
from pathlib import Path
import hashlib
import json
import math
import sys
import unittest
import numpy as np
HERE=Path(__file__).resolve().parent;ROOT=HERE.parent
sys.path.insert(0,str(ROOT/'ground-obb-v6'))
import test_oriented_ground_obb_container as authored
from oriented_ground_obb_container import GroundOBBReferenceContainer
from profiled_v6 import ProfiledGroundOBBReferenceContainer,PROFILE_PHASES
from instrument_v6 import ORIGINAL,EXPECTED,generate,verify_algorithm


class InstrumentationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls): authored.serial_vtk()
    def pair(self, extras=(), transform=None, cap=200000):
        _,original=authored.pair(authored.scene(extras,transform=transform),transform,cap)
        profiled=ProfiledGroundOBBReferenceContainer(original.surface,original.transform,
            ground=original.ground,maximum_candidate_cells=cap)
        self.assertEqual(profiled.profile_rows,[])
        return original,profiled
    def rows(self, profiled, count):
        self.assertEqual(len(profiled.profile_rows),count)
        for index,row in enumerate(profiled.profile_rows):
            self.assertEqual(row['index'],index)
            self.assertEqual(set(row['phaseSeconds']),set(PROFILE_PHASES))
            self.assertTrue(all(math.isfinite(x)and x>=0 for x in row['phaseSeconds'].values()))
            self.assertAlmostEqual(sum(row['phaseSeconds'].values()),row['contactTimedWallSeconds'],places=9)
            self.assertAlmostEqual(row['exclusivePhaseSumSeconds'],row['contactTimedWallSeconds'],places=9)
            self.assertFalse(row['nestedTimesAreAdditiveToPhases'])
            self.assertTrue(row['OBBFilterIncludesOwnerChecks'])
            self.assertTrue(row['resultHelperIncludesItsOwnerCheck'])
            for key in ('ownerCheck','resultHelper'):
                nested=row[key]
                self.assertEqual(nested['count'],sum(v['count']for v in nested['byPhase'].values()))
                self.assertAlmostEqual(nested['seconds'],sum(v['seconds']for v in nested['byPhase'].values()),places=9)
                self.assertLessEqual(nested['seconds'],row['contactTimedWallSeconds'])
    def compare(self, pair, start=(0.,0.,0.),end=(0.,0.,0.),yaw=0.,delta=0.):
        original,profiled=pair
        expected=original.swept_contacts(start,end,yaw,delta)
        actual=profiled.swept_contacts(start,end,yaw,delta)
        self.assertEqual(actual,expected)
        self.assertEqual(original.box_queries,profiled.box_queries)
        self.assertEqual(original.triangle_queries,profiled.triangle_queries)
        self.assertNotIn('phaseSeconds',json.dumps(actual))
        self.rows(profiled,2)
        self.assertTrue(all(r['completed']and r['exceptionType']is None for r in profiled.profile_rows))
        return actual,profiled
    def test_mechanical_generation_and_original_AST_identity(self):
        source=ORIGINAL.read_text()
        self.assertEqual(hashlib.sha256(source.encode()).hexdigest(),EXPECTED)
        generated=(HERE/'profiled_v6.py').read_text()
        self.assertEqual(generate(source),generated)
        self.assertTrue(all(verify_algorithm(source,generated).values()))
    def test_ground_only_all_result_fields_unchanged(self):
        actual,profiled=self.compare(self.pair())
        self.assertFalse(actual['actualBody']['contact'])
        self.assertGreater(actual['actualBody']['skippedGroundCandidateCount'],0)
        self.assertGreater(profiled.profile_rows[0]['ownerCheck']['count'],0)
    def test_contained_positive_and_first_receipt_nesting(self):
        actual,profiled=self.compare(self.pair([[[0,.5,0],[.01,.5,0],[0,.5,.01]]]))
        self.assertTrue(actual['actualBody']['contact'])
        row=profiled.profile_rows[0]
        self.assertEqual(row['resultHelper']['count'],1)
        self.assertEqual(row['resultHelper']['byPhase']['exactPredicateLoopAndSetup']['count'],1)
        self.assertGreater(row['ownerCheck']['byPhase']['zeroCopyOBBFilter']['count'],0)
    def test_thin_nearfoot_and_head_geometry_unchanged(self):
        for extra in ([[0,.01,-.01],[0,.02,-.01],[0,.02,.01]],
                      [[-.1,1.59,-.1],[.1,1.59,-.1],[0,1.59,.1]]):
            with self.subTest(extra=extra):
                actual,_=self.compare(self.pair([extra]));self.assertTrue(actual['actualBody']['contact'])
    def test_margin_only_output_unchanged(self):
        actual,_=self.compare(self.pair([[[.25,.5,-.01],[.25,.7,-.01],[.25,.5,.01]]]))
        self.assertFalse(actual['actualBody']['contact']);self.assertTrue(actual['horizontalMargin']['contact'])
    def test_multiple_contacts_keep_first_ID_and_counts(self):
        actual,_=self.compare(self.pair([[[0,.5,0],[.01,.5,0],[0,.5,.01]],[[.02,.8,0],[.03,.8,0],[.02,.8,.01]]]))
        self.assertEqual(actual['actualBody']['nonGroundContactCount'],2)
    def test_rotated_translated_sweep_and_similarity(self):
        self.compare(self.pair([[[.18,.5,.18],[.19,.6,.18],[.18,.5,.19]]],authored.similarity()),
            start=(-.01,0,0),end=(.01,.001,.005),yaw=.3,delta=math.radians(1))
    def test_closed_and_tolerance_admitted_faces(self):
        corners=authored.box_corners()
        for axis in range(3):
            for coordinate in (0.,1.,-.5e-6,1+.5e-6):
                with self.subTest(axis=axis,coordinate=coordinate):
                    original,profiled=self.pair([authored.model_triangle(corners,axis,coordinate)],authored.similarity())
                    expected=original.contact_corners(corners);actual=profiled.contact_corners(corners)
                    self.assertEqual(actual,expected);self.assertTrue(actual['contact']);self.rows(profiled,1)
    def test_all_rejected_zero_exact_loop_keeps_output(self):
        corners=authored.box_corners();original,profiled=self.pair([authored.model_triangle(corners,0,1.05)],authored.similarity())
        expected=original.contact_corners(corners);actual=profiled.contact_corners(corners)
        self.assertEqual(actual,expected);self.assertEqual(actual['exactNonGroundTriangleTests'],0)
        self.assertGreater(actual['rejectedNonGroundBoundsCandidates'],0);self.rows(profiled,1)
        self.assertEqual(profiled.profile_rows[0]['resultHelper']['byPhase']['resultAssemblyTail']['count'],1)
    def test_candidate_cap_exception_preserved_and_profiled(self):
        original,profiled=self.pair(cap=1);messages=[]
        for scorer in (original,profiled):
            with self.assertRaises(authored.GeometryFailure)as caught:scorer.contact_corners(authored.box_corners())
            messages.append(str(caught.exception))
        self.assertEqual(*messages);self.rows(profiled,1)
        self.assertFalse(profiled.profile_rows[0]['completed'])
        self.assertEqual(profiled.profile_rows[0]['exceptionType'],'GeometryFailure')
    def test_owner_error_preserved_and_profiled(self):
        original,profiled=self.pair();original.mesh.Modified()
        for scorer in (original,profiled):
            with self.assertRaises(RuntimeError):scorer.contact_corners(authored.box_corners())
        self.rows(profiled,1);self.assertFalse(profiled.profile_rows[0]['completed'])
    def test_noncontact_calls_do_not_mutate_old_profile_rows(self):
        original,profiled=self.pair();self.compare((original,profiled));saved=json.dumps(profiled.profile_rows,sort_keys=True)
        self.assertEqual(original.support_probes([0,0,0],.3),profiled.support_probes([0,0,0],.3))
        self.assertEqual(saved,json.dumps(profiled.profile_rows,sort_keys=True))


if __name__=='__main__':unittest.main(verbosity=2)
