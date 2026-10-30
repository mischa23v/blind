import importlib.util,pathlib,unittest,math
p=pathlib.Path(__file__).with_name('metrics.py');s=importlib.util.spec_from_file_location('heldout_metrics',p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
class MetricsTests(unittest.TestCase):
 def test_observation_hit_is_not_known_prefix(self):
  p=m.partition(['observed-hit-visibility-unverified'],1);self.assertEqual(p['hit-known-prefix'],0);self.assertEqual(p['observed-hit-visibility-unverified'],1)
 def test_primary_excludes_observation_status(self):
  with self.assertRaises(ValueError):m.primary_partition(['observed-hit-visibility-unverified'],1)
 def test_primary_schema_retained(self):
  p=m.primary_partition(['origin-unknown'],1);self.assertEqual(set(p),set(m.PRIMARY_STATUSES));self.assertEqual(p['origin-unknown'],1)
 def test_fixed_grid(self):self.assertEqual(m.GRID_COUNT,11625)
 def test_quantile_linear_and_signed_not_clipped(self):
  q=m.distributions([-2,0,1,9]);self.assertEqual(q['signed']['median'],.5);self.assertEqual(q['signed']['mean'],2);self.assertEqual(q['absolute']['median'],1.5)
 def test_empty_is_not_zero_error(self):self.assertIsNone(m.distributions([])['signed'])
 def test_nonfinite_rejected(self):
  for v in [math.nan,math.inf,-math.inf]:
   with self.assertRaises(ValueError):m.distributions([1,v])
 def test_unknown_not_hit(self):
  p=m.partition(['origin-unknown','unknown-before-hit'],2);self.assertEqual(p['hit-known-prefix'],0)
 def test_count_mismatch_rejected(self):
  with self.assertRaises(ValueError):m.partition(['hit-known-prefix'],2)
 def test_unknown_status_rejected(self):
  with self.assertRaises(ValueError):m.partition(['clear'],1)
 def test_exact_inverse_not_transpose(self):
  r=((1.000001,0,0),(0,1,0),(0,0,1.000001));inv=m.inverse3(r);self.assertAlmostEqual(m.axial((0,0,2.000002),(0,0,0),inv),2,places=14)
 def test_rotated_translated_axial_not_radial(self):
  r=((0,0,1),(0,1,0),(-1,0,0));inv=m.inverse3(r);self.assertAlmostEqual(m.axial((5,5,5),(2,3,4),inv),3);self.assertNotEqual(math.dist((5,5,5),(2,3,4)),3)
if __name__=='__main__':unittest.main(verbosity=2)
