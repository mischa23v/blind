import math,unittest,numpy as np
from octomap_engine import OctoMap
class NativeOctomapTests(unittest.TestCase):
 def test_defaults_frozen(self):
  with OctoMap()as m:np.testing.assert_allclose(list(m.defaults().values()),[.05,.7,.4,.5,.1192,.971],atol=1e-7,rtol=0)
 def test_unknown_is_not_free(self):
  with OctoMap()as m:
   q=m.query([[1,0,0]]);self.assertEqual(q['known'][0],0);self.assertTrue(np.isnan(q['probability'][0]));self.assertEqual(q['freeScans'][0],0)
 def test_actual_hit_and_observed_ray(self):
  with OctoMap()as m:
   s=m.insert(0,[[1.01,.01,.01]],[.01,.01,.01]);self.assertEqual(s['occupiedKeys'],1);q=m.query([[1.01,.01,.01],[.51,.01,.01],[2,.01,.01]]);np.testing.assert_equal(q['known'],[1,1,0]);self.assertAlmostEqual(q['probability'][0],.7,places=6);self.assertAlmostEqual(q['probability'][1],.4,places=6)
 def test_same_voxel_duplicates_do_not_count_as_frames(self):
  with OctoMap()as m:
   s=m.insert(0,[[1.001,.101,.001],[1.049,.149,.049]]*10,[.001,.001,.001]);self.assertEqual(s['originalPoints'],20);self.assertEqual(s['representativeRays'],1);self.assertEqual(s['occupiedKeys'],1);q=m.query([[1.025,.125,.025]]);self.assertEqual(q['hitScans'][0],1)
 def test_representative_is_actual_first_not_centre(self):
  with OctoMap()as m:
   m.insert(0,[[1.001,.149,.001],[1.049,.101,.049]],[.001,.001,.001]);q=m.query([[.775,.125,.025]]);self.assertEqual(q['known'][0],1);self.assertAlmostEqual(q['probability'][0],.4,places=6)
 def test_occupied_wins_within_scan(self):
  with OctoMap()as m:
   m.insert(0,[[1.01,.01,.01],[2.01,.01,.01]],[.01,.01,.01]);q=m.query([[1.01,.01,.01]]);self.assertEqual(q['hitScans'][0],1);self.assertEqual(q['freeScans'][0],0);self.assertAlmostEqual(q['probability'][0],.7,places=6)
 def test_explicit_free_updates_not_absence(self):
  with OctoMap()as m:
   m.insert(0,[[1.01,.01,.01]],[.01,.01,.01])
   for i in range(1,4):m.insert(i,[[2.01,.01,.01]],[.01,.01,.01])
   q=m.query([[1.01,.01,.01]]);self.assertEqual(q['hitScans'][0],1);self.assertEqual(q['freeScans'][0],3);self.assertLess(q['probability'][0],.5);self.assertGreater(q['probability'][0],.1192)
 def test_invalid_scan_retires_handle(self):
  with OctoMap()as m:
   with self.assertRaises(RuntimeError):m.insert(0,[[float('nan'),0,0]],[0,0,0])
   with self.assertRaises(RuntimeError):m.query([[0,0,0]])
 def test_duplicate_frame_retires(self):
  with OctoMap()as m:
   m.insert(0,[[1,0,0]],[0,0,0])
   with self.assertRaises(RuntimeError):m.insert(0,[[1,0,0]],[0,0,0])
 def test_occupied_equivalence_negative_boundaries(self):
  with OctoMap()as m:
   rng=np.random.default_rng(14159);p=rng.uniform(-1,1,(1000,3));p=np.concatenate((p,p,p+1e-7),axis=0);s=m.insert(0,p,[0,0,0]);self.assertEqual(s['occupiedKeys'],s['representativeRays']);self.assertLessEqual(s['occupiedKeys'],3000);q=m.query(p);self.assertTrue(np.all(q['known']==1));self.assertTrue(np.all(q['probability']>=.5))
 def test_export_preserves_scores_not_max_likelihood(self):
  with OctoMap()as m:
   m.insert(0,[[1.01,.01,.01]],[.01,.01,.01]);a=m.leaves();self.assertTrue(np.any(np.abs(a['xyzSizeProbability'][:,4]-.4)<1e-6));self.assertTrue(np.any(np.abs(a['xyzSizeProbability'][:,4]-.7)<1e-6));self.assertTrue(np.allclose(a['xyzSizeProbability'][:,3],.05))


 def test_native_ray_capacity_refusal(self):
  with OctoMap() as m:
   with self.assertRaisesRegex(RuntimeError,'ray capacity'):m.insert(0,[[-1600,-1600,-1600]],[1600,1600,1600])
   with self.assertRaisesRegex(RuntimeError,'retired'):m.query([[0,0,0]])
 def test_native_keys_and_occupied_decision(self):
  with OctoMap() as m:
   points=np.array([[1.01,.01,.01],[.51,.01,.01],[2.01,.01,.01]])
   m.insert(0,points[:1],[.01,.01,.01]);a=m.query(points);b=m.query_keys(m.keys(points));np.testing.assert_equal(a['occupied'],[1,0,0]);np.testing.assert_equal(a['known'],[1,1,0])
   for key in a:np.testing.assert_equal(a[key],b[key])
 def test_count_cap_precedes_array_conversion(self):
  class TooMany:
   def __len__(self):return 5000001
   def __array__(self,*args,**kwargs):raise AssertionError('must not allocate')
  with OctoMap()as m:
   for op in [lambda:m.insert(0,TooMany(),[0,0,0]),lambda:m.query(TooMany()),lambda:m.keys(TooMany()),lambda:m.query_keys(TooMany())]:
    with self.assertRaises(ValueError):op()
 def test_key_type_cannot_wrap(self):
  with OctoMap() as m:
   with self.assertRaises(ValueError):m.query_keys(np.array([[-1,0,0]],dtype=np.int64))
 def test_python_serialized_handle_queries(self):
  from concurrent.futures import ThreadPoolExecutor
  with OctoMap() as m:
   m.insert(0,[[1.01,.01,.01]],[.01,.01,.01])
   with ThreadPoolExecutor(max_workers=2) as pool:
    rows=list(pool.map(lambda _:m.query([[1.01,.01,.01]])['occupied'][0],range(8)))
   self.assertEqual(rows,[1]*8)
if __name__=='__main__':unittest.main()
