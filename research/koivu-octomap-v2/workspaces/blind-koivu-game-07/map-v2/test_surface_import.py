"""Authored scalar/cell fixtures only; no recorded frame or game execution."""
import unittest
import numpy as np
from surface_import import classify,combine_coverage,query_flags,surface_classification


def query(n,*,known=1,occupied=0,hits=2,frees=2):
    return {'known':np.full(n,known,np.uint8),'occupied':np.full(n,occupied,np.uint8),
            'probability':np.full(n,.8 if occupied else .2),
            'logOdds':np.full(n,1. if occupied else -1.,np.float32),
            'hitScans':np.full(n,hits,np.uint32),'freeScans':np.full(n,frees,np.uint32)}


def fixture(extra_height=.2):
    ijk=np.array([[0,0,0],[1,0,0],[0,0,1],[1,0,1],[0,4,0]],np.int64)
    low=np.array([-.01,-.01,-.01,-.01,extra_height]);high=low+.01
    return [ijk,low,high,np.full(5,2,np.uint32),1,1,
            np.arange(5),np.arange(5),query(5),np.ones(5,bool)]


class ClassificationTests(unittest.TestCase):
    def test_native_free_reopens_only_model_raw_input_unchanged(self):
        args=fixture();before=[x.copy() if isinstance(x,np.ndarray) else x for x in args]
        result=classify(*args)
        self.assertTrue(result['support'][0]);self.assertFalse(result['blocked'][0])
        self.assertTrue(result['rawObstacle'][4]);self.assertTrue(result['rawKnownFreeWithEvidence'][4])
        for a,b in zip(args,before):
            if isinstance(a,np.ndarray):np.testing.assert_array_equal(a,b)
        self.assertFalse(result['physicalAuthority'])

    def test_native_occupied_blocks(self):
        args=fixture();args[8]['occupied'][4]=1
        self.assertTrue(classify(*args)['surfacePositiveOccupied'][0])
        self.assertTrue(classify(*args)['blocked'][0])

    def test_unknown_raw_hit_blocks(self):
        args=fixture();args[8]['known'][4]=0;args[8]['probability'][4]=np.nan;args[8]['logOdds'][4]=np.nan
        result=classify(*args)
        self.assertTrue(result['surfacePositiveUnresolved'][0]);self.assertTrue(result['blocked'][0])

    def test_free_scan_and_actual_hit_association_required(self):
        for field in ('freeScans','hitScans'):
            args=fixture();args[8][field][4]=0
            with self.subTest(field=field):self.assertTrue(classify(*args)['blocked'][0])

    def test_incomplete_or_missing_association_blocks(self):
        args=fixture();args[9][4]=False
        self.assertTrue(classify(*args)['blocked'][0])
        args=fixture();args[6]=args[6][:-1];args[7]=args[7][:-1]
        self.assertTrue(classify(*args)['blocked'][0])

    def test_all_actual_native_keys_required(self):
        args=fixture();args[6]=np.append(args[6],4);args[7]=np.arange(6);args[8]=query(6)
        self.assertFalse(classify(*args)['blocked'][0])
        args[8]['occupied'][5]=1
        self.assertTrue(classify(*args)['blocked'][0])
        args[8]['occupied'][5]=0;args[8]['freeScans'][5]=0
        self.assertTrue(classify(*args)['blocked'][0])

    def test_below_floor_contradiction_stays_blocked(self):
        args=fixture(-.12);result=classify(*args)
        self.assertTrue(result['rawKnownFreeWithEvidence'][4])
        self.assertTrue(result['rawBelowFloorContradiction'][4]);self.assertTrue(result['blocked'][0])

    def test_original_floor_support_and_ground_are_exact(self):
        args=fixture();result=classify(*args);original=surface_classification(*args[:6])
        np.testing.assert_array_equal(result['support'],original[0])
        np.testing.assert_array_equal(result['rawGround'],original[4])
        self.assertEqual(int(result['rawGroundNativeFreeWithEvidence'].sum()),4)
        self.assertTrue(result['surfaceGroundNativeFreeConflict'][0])
        self.assertTrue(result['support'][0])  # Prior retained, explicitly NOT support truth.

    def test_missing_quadrant_and_deep_returns_do_not_create_support(self):
        args=fixture(-.5);args[3][0]=1
        result=classify(*args)
        self.assertFalse(result['support'][0]);self.assertTrue(result['blocked'][0])
        self.assertFalse(result['rawBelowFloorContradiction'][4]) # Frozen band, disclosed limitation.

    def test_native_occupied_flag_owns_classification_not_python_threshold(self):
        args=fixture();args[8]['probability'][:]=.9
        self.assertFalse(classify(*args)['blocked'][0])
        args[8]['occupied'][4]=1;args[8]['probability'][4]=.1
        self.assertTrue(classify(*args)['blocked'][0])

    def test_bad_associations_rejected(self):
        for kind in ('duplicate','raw_out_of_bounds','query_out_of_bounds','negative'):
            args=fixture()
            if kind=='duplicate':args[6]=np.append(args[6],4);args[7]=np.append(args[7],4)
            elif kind=='raw_out_of_bounds':args[6][4]=5
            elif kind=='query_out_of_bounds':args[7][4]=5
            else:args[6][4]=-1
            with self.subTest(kind=kind),self.assertRaises(ValueError):classify(*args)

    def test_bad_original_arrays_rejected(self):
        for kind in ('nan','inverted','bad_view','negative_cell','float_complete','bad_width'):
            args=fixture()
            if kind=='nan':args[1][0]=np.nan
            elif kind=='inverted':args[1][0]=1.
            elif kind=='bad_view':args[3][0]=295
            elif kind=='negative_cell':args[0][0,0]=-1
            elif kind=='float_complete':args[9]=args[9].astype(float)
            else:args[4]=True
            with self.subTest(kind=kind),self.assertRaises(ValueError):classify(*args)


class CoverageTests(unittest.TestCase):
    def test_all_ninety_both_kinds_evidence_required(self):
        result=combine_coverage(np.ones((2,90),bool),query(180,hits=0))
        np.testing.assert_array_equal(result['cellClearanceEstimated'],[True,True])
        self.assertEqual(result['sampleAdmitted'].shape,(2,90));self.assertFalse(result['physicalAuthority'])

    def test_every_missing_kind_blocks_cell(self):
        for kind in ('projection','unknown','occupied','no_free_scan'):
            projected=np.ones((2,90),bool);q=query(180)
            if kind=='projection':projected[0,89]=False
            elif kind=='unknown':q['known'][89]=0;q['probability'][89]=np.nan;q['logOdds'][89]=np.nan
            elif kind=='occupied':q['occupied'][89]=1
            else:q['freeScans'][89]=0
            with self.subTest(kind=kind):np.testing.assert_array_equal(combine_coverage(projected,q)['cellClearanceEstimated'],[False,True])

    def test_empty_candidates_allowed(self):
        result=combine_coverage(np.zeros((0,90),bool),query(0))
        self.assertEqual(result['cellClearanceEstimated'].shape,(0,))

    def test_bad_coverage_shapes_rejected(self):
        for projected,q in [(np.ones((1,89),bool),query(89)),(np.ones((1,90)),query(90)),(np.ones((1,90),bool),query(89))]:
            with self.assertRaises(ValueError):combine_coverage(projected,q)

    def test_invalid_native_state_rejected(self):
        for kind in ('bad_flag','unknown_occupied','nonfinite_known','bad_probability','bad_count','extra_field','string_score'):
            q=query(1)
            if kind=='bad_flag':q['known'][0]=2
            elif kind=='unknown_occupied':q['known'][0]=0;q['occupied'][0]=1
            elif kind=='nonfinite_known':q['logOdds'][0]=np.nan
            elif kind=='bad_probability':q['probability'][0]=1.1
            elif kind=='bad_count':q['freeScans'][0]=295
            elif kind=='extra_field':q['inventedConfidence']=np.ones(1)
            else:q['probability']=np.array(['.2'])
            with self.subTest(kind=kind),self.assertRaises(ValueError):query_flags(q)


if __name__=='__main__':unittest.main(verbosity=2)
