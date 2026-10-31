"""Authored controls only. Original 16+22 tests are unchanged and must rerun."""
import math,unittest
import numpy as np
from ray_binding import open_reviewed_tree
REVIEWED_LIBRARY=None;REVIEWED_SHA256=None
O=(.025,.025,.025)
HIT='observed-hit-visibility-unverified'
class ObservationControls(unittest.TestCase):
 def setUp(self):
  if REVIEWED_LIBRARY is None or REVIEWED_SHA256 is None:raise RuntimeError('candidate not admitted')
  self.tree,self.rays=open_reviewed_tree(REVIEWED_LIBRARY,REVIEWED_SHA256);self.addCleanup(self.tree.close)
 def line(self):self.tree.insert(0,[[1.025,.025,.025]],O)
 def observed(self,origin=O,direction=(1,0,0),limit=2):return self.rays.cast_observed(origin,[direction],[limit])[0]
 def snap(self):return self.rays.state(),self.tree.defaults(),{k:v.copy()for k,v in self.tree.leaves().items()}
 def unchanged(self,b):
  state,defaults,leaves=b;self.assertEqual(self.rays.state(),state);self.assertEqual(self.tree.defaults(),defaults)
  for k,v in self.tree.leaves().items():np.testing.assert_array_equal(v,leaves[k])
 def test_unknown_origin_observes_recorded_hit_without_visibility_claim(self):
  self.line();origin=(-.275,.025,.025);self.assertEqual(self.rays.cast(origin,[(1,0,0)],[2])[0]['status'],'origin-unknown');r=self.observed(origin=origin);self.assertEqual(r['status'],HIT);self.assertAlmostEqual(r['entry'][0],1.,places=5)
 def test_unknown_gap_is_preserved_in_primary_but_observed_surface_available(self):
  self.tree.insert(0,[[.025,.525,.025]],O);self.tree.insert(1,[[1.025,.025,.025]],[1.025,.525,.025]);self.assertEqual(self.rays.cast(O,[(1,0,0)],[2])[0]['status'],'unknown-before-hit');self.assertEqual(self.observed()['status'],HIT)
 def test_occupied_origin_refused_even_in_observation_mode(self):
  self.line();r=self.observed(origin=(1.025,.025,.025));self.assertEqual(r['status'],'origin-occupied');self.assertIsNone(r['entryProjectedRange'])
 def test_known_prefix_still_distinct_observation_status(self):
  self.line();self.assertEqual(self.rays.cast(O,[(1,0,0)],[2])[0]['status'],'hit-known-prefix');self.assertEqual(self.observed()['status'],HIT)
 def test_empty_unknown_map_range_exhaustion_is_not_clear(self):
  r=self.observed();self.assertEqual(r['status'],'range-exhausted');self.assertIsNone(r['entryProjectedRange']);self.assertEqual(self.rays.cast(O,[(1,0,0)],[2])[0]['status'],'origin-unknown')
 def test_center_based_range_censoring_unchanged(self):
  self.line();self.assertEqual(self.observed(limit=.99)['status'],'range-exhausted');r=self.observed(limit=1.01);self.assertEqual(r['status'],HIT);self.assertLess(r['entryProjectedRange'],.99)
 def test_oblique_entry_same_as_primary_when_known_prefix(self):
  origin=(.01,.02,.03);direction=(1,.4,.2);self.tree.insert(0,[[1.01,.42,.23]],origin);a=self.rays.cast(origin,[direction],[2])[0];b=self.observed(origin,direction);self.assertEqual(a['status'],'hit-known-prefix');self.assertEqual(b['status'],HIT)
  for key in ['entry','center','entryProjectedRange','centerProjectedRange']:self.assertEqual(a[key],b[key])
 def test_invalid_and_huge_inputs_remain_refused(self):
  for origin,direction,limit,status in [((1e30,0,0),(1,0,0),2,'bounds-rejected'),(O,(0,0,0),2,'invalid-input'),(O,(1,0,0),9,'invalid-input'),(O,(math.nan,0,0),2,'invalid-input')]:self.assertEqual(self.observed(origin,direction,limit)['status'],status)
 def test_both_modes_and_errors_leave_payload_identical(self):
  self.line();before=self.snap();self.observed(origin=(-.275,.025,.025));self.observed(limit=.5);self.observed(origin=(1e30,0,0));self.rays.cast(O,[(1,0,0)],[2]);self.unchanged(before)
 def test_maximum_batch_is_all_observed_status_without_mutation(self):
  self.line();before=self.snap();rows=self.rays.cast_observed((-.275,.025,.025),[(1,0,0)]*256,[2]*256);self.assertEqual(len(rows),256);self.assertTrue(all(r['status']==HIT for r in rows));self.unchanged(before)
