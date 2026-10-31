"""Authored native controls; NOT executed. Configure through run_controls.py."""
import math
import unittest
import numpy as np
from ray_binding import open_reviewed_tree

REVIEWED_LIBRARY=None
REVIEWED_SHA256=None
ORIGIN=(.025,.025,.025)


class ReadOnlyRayControls(unittest.TestCase):
    def setUp(self):
        if REVIEWED_LIBRARY is None or REVIEWED_SHA256 is None:
            raise RuntimeError('separate reviewed candidate binary required; controls not admitted')
        self.tree,self.rays=open_reviewed_tree(REVIEWED_LIBRARY,REVIEWED_SHA256)
        self.addCleanup(self.tree.close)

    def line(self,endpoint=(1.025,.025,.025)):
        self.tree.insert(0,[endpoint],ORIGIN)

    def ray(self,direction=(1,0,0),limit=2.,origin=ORIGIN):
        return self.rays.cast(origin,[direction],[limit])[0]

    def snapshot(self):
        return self.rays.state(),self.tree.defaults(),{k:v.copy() for k,v in self.tree.leaves().items()}

    def assert_snapshot(self,before):
        state,defaults,leaves=before
        self.assertEqual(self.rays.state(),state);self.assertEqual(self.tree.defaults(),defaults)
        after=self.tree.leaves()
        for name in leaves:np.testing.assert_array_equal(leaves[name],after[name])

    def test_unknown_origin_is_not_a_free_prefix(self):
        row=self.ray()
        self.assertEqual(row['status'],'origin-unknown')
        self.assertEqual(row['terminalKnown'],0)
        self.assertIsNone(row['entryProjectedRange'])

    def test_axis_aligned_hit_reports_center_and_voxel_entry_distinctly(self):
        self.line();row=self.ray()
        self.assertEqual(row['status'],'hit-known-prefix')
        self.assertAlmostEqual(row['centerProjectedRange'],1.,places=5)
        self.assertAlmostEqual(row['entryProjectedRange'],.975,places=5)
        self.assertAlmostEqual(row['center'][0],1.025,places=5)
        self.assertAlmostEqual(row['entry'][0],1.,places=5)
        self.assertEqual((row['terminalKnown'],row['terminalOccupied'],row['hitScans'],row['freeScans']),(1,1,1,0))

    def test_unknown_gap_stops_before_distant_known_hit(self):
        self.tree.insert(0,[[.025,.525,.025]],ORIGIN)
        self.tree.insert(1,[[1.025,.025,.025]],[1.025,.525,.025])
        self.assertTrue(self.tree.query([[1.025,.025,.025]])['occupied'][0])
        row=self.ray()
        self.assertEqual(row['status'],'unknown-before-hit')
        self.assertEqual(row['terminalKnown'],0)
        self.assertIsNone(row['entryProjectedRange'])

    def test_occupied_origin_is_not_a_zero_error_depth_hit(self):
        self.line();row=self.ray(origin=(1.025,.025,.025))
        self.assertEqual(row['status'],'origin-occupied')
        self.assertEqual(row['terminalOccupied'],1)
        self.assertIsNone(row['entryProjectedRange'])

    def test_range_exhaustion_after_known_free_prefix(self):
        self.line((2.025,.025,.025));row=self.ray(limit=.4)
        self.assertEqual(row['status'],'range-exhausted')
        self.assertGreater(row['centerProjectedRange'],.4)
        self.assertIsNone(row['entryProjectedRange'])

    def test_upstream_max_range_is_center_based_not_entry_based(self):
        self.line()
        self.assertEqual(self.ray(limit=.99)['status'],'range-exhausted')
        row=self.ray(limit=1.01)
        self.assertEqual(row['status'],'hit-known-prefix')
        self.assertLess(row['entryProjectedRange'],.99)

    def test_nonfinite_zero_and_unnormalizable_directions_are_invalid(self):
        self.line()
        for d in [(0,0,0),(math.nan,0,0),(math.inf,0,0),(1e-45,0,0),(1e30,0,0)]:
            with self.subTest(direction=d):
                row=self.ray(direction=d)
                self.assertEqual(row['status'],'invalid-input')
                self.assertIsNone(row['entryProjectedRange'])

    def test_nonpositive_nonfinite_or_oversize_ranges_are_invalid_not_clamped(self):
        self.line()
        for limit in (0,-1,math.nan,math.inf,8.001):
            with self.subTest(limit=limit):
                self.assertEqual(self.ray(limit=limit)['status'],'invalid-input')

    def test_invalid_origin_and_native_bounds_are_distinct(self):
        self.assertEqual(self.ray(origin=(math.nan,0,0))['status'],'invalid-input')
        self.assertEqual(self.ray(origin=(2000,0,0))['status'],'bounds-rejected')

    def test_positive_and_negative_huge_finite_origins_refused_before_native_key_cast(self):
        self.line();before=self.snapshot()
        for magnitude in (1e30,float(np.finfo(np.float32).max)):
            for sign in (-1,1):
                for axis in range(3):
                    origin=list(ORIGIN);origin[axis]=sign*magnitude
                    with self.subTest(magnitude=magnitude,sign=sign,axis=axis):
                        row=self.ray(origin=origin)
                        self.assertEqual(row['status'],'bounds-rejected')
                        self.assertIsNone(row['entryProjectedRange'])
        self.assert_snapshot(before)

    def test_positive_and_negative_envelopes_refused_in_double_domain_without_clamping(self):
        self.line();before=self.snapshot()
        for sign in (-1,1):
            for axis in range(3):
                origin=list(ORIGIN);origin[axis]=sign*1638.0
                with self.subTest(sign=sign,axis=axis):
                    row=self.ray(origin=origin,limit=.5)
                    self.assertEqual(row['status'],'bounds-rejected')
                    self.assertEqual(row['maxRange'],.5)
                    self.assertIsNone(row['entryProjectedRange'])
        self.assert_snapshot(before)

    def test_oblique_ray_uses_upstream_entry_not_off_ray_voxel_center(self):
        origin=(.01,.02,.03);self.tree.insert(0,[[1.01,.42,.23]],origin)
        row=self.ray(direction=(1,.4,.2),origin=origin)
        self.assertEqual(row['status'],'hit-known-prefix')
        for actual,expected in zip(row['entry'],(1.,.416,.228)):
            self.assertAlmostEqual(actual,expected,places=5)
        self.assertAlmostEqual(row['entryProjectedRange'],.99*math.sqrt(1.2),places=5)
        self.assertNotAlmostEqual((row['center'][0]-.01),(row['center'][1]-.02)/.4,places=5)

    def test_status_counts_partition_a_mixed_batch(self):
        self.line()
        rows=self.rays.cast(ORIGIN,[(1,0,0),(-1,0,0),(1,0,0),(0,0,0)],[2,2,.2,2])
        self.assertEqual([r['status'] for r in rows],
            ['hit-known-prefix','unknown-before-hit','range-exhausted','invalid-input'])
        self.assertEqual(len(rows),4)

    def test_queries_and_invalid_rows_leave_every_map_payload_byte_unchanged(self):
        self.line();before=self.snapshot()
        self.rays.cast(ORIGIN,[(1,0,0),(-1,0,0),(0,0,0)],[2,2,2])
        self.ray(limit=math.nan);self.ray(origin=(2000,0,0))
        self.assert_snapshot(before)

    def test_batch_cap_precedes_array_conversion(self):
        class TooMany:
            def __len__(self):return 257
            def __array__(self,*a,**k):raise AssertionError('must not allocate')
        with self.assertRaises(ValueError):self.rays.cast(ORIGIN,TooMany(),[])

    def test_shape_rejections_do_not_mutate_or_retire_handle(self):
        self.line();before=self.snapshot()
        for origin,directions,ranges in [([0,0],[(1,0,0)],[2]),(ORIGIN,[(1,0)],[2]),
                                         (ORIGIN,[(1,0,0)],[]),(ORIGIN,[(1,0,0)],[[2]])]:
            with self.subTest(directions=directions,ranges=ranges):
                with self.assertRaises(ValueError):self.rays.cast(origin,directions,ranges)
        self.assert_snapshot(before)

    def test_empty_typed_batch_is_read_only(self):
        self.line();before=self.snapshot()
        self.assertEqual(self.rays.cast(ORIGIN,np.empty((0,3),np.float32),[]),[])
        self.assert_snapshot(before)

    def test_closed_owner_refuses_query_and_state(self):
        self.tree.close()
        with self.assertRaisesRegex(RuntimeError,'closed'):self.ray()
        with self.assertRaisesRegex(RuntimeError,'closed'):self.rays.state()

    def test_invalid_ray_does_not_retire_owner_or_add_scan(self):
        self.line();before=self.rays.state();self.ray(direction=(0,0,0))
        self.assertEqual(self.rays.state(),before)
        self.tree.insert(1,[[1.025,.025,.025]],ORIGIN)
        self.assertEqual(self.rays.state()['scans'],2)

    def test_terminal_key_and_float32_boundary_agree_with_existing_query(self):
        origin=(-1.001,.02,.03);endpoint=(-.051,.02,.03)
        self.tree.insert(0,[endpoint],origin);row=self.ray(origin=origin)
        self.assertEqual(row['status'],'hit-known-prefix')
        q=self.tree.query_keys(self.tree.keys([row['center']]))
        for field in ('known','occupied','hitScans','freeScans'):
            native_field={'known':'terminalKnown','occupied':'terminalOccupied'}.get(field,field)
            self.assertEqual(int(q[field][0]),row[native_field])
        self.assertEqual(float(q['probability'][0]),row['probability'])

    def test_maximum_batch_preserves_owner_state(self):
        self.line();before=self.snapshot()
        rows=self.rays.cast(ORIGIN,[(1,0,0)]*256,[2]*256)
        self.assertEqual(len(rows),256)
        self.assertTrue(all(r['status']=='hit-known-prefix' for r in rows))
        self.assert_snapshot(before)

    def test_state_audit_matches_existing_export_evidence(self):
        self.line();state=self.rays.state();leaves=self.tree.leaves()
        self.assertEqual(state['scans'],1)
        self.assertEqual(state['leaves'],len(leaves['xyzSizeProbability']))
        self.assertEqual(state['hitVotes'],int(leaves['hitScans'].sum()))
        self.assertEqual(state['freeVotes'],int(leaves['freeScans'].sum()))
        self.assertEqual(state['evidenceKeys'],state['leaves'])
