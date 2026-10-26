import unittest,numpy as np
import fusion_driver as f
from octomap_engine import OctoMap
class AssociationTests(unittest.TestCase):
 def test_native_key_pack_round_trip(self):
  k=np.array([[0,0,0],[65535,2,32768],[32769,32768,32768]],np.uint16);np.testing.assert_equal(f.native_unpack(f.packed(k)),k)
 def test_actual_boundary_deviation_is_not_lost(self):
  with OctoMap(.05) as tree:
   raw=f.packed(np.array([[0,0,0]],np.int64));centres=tree.keys([[.025,.025,.025]]);p=np.array([[.05-1e-10,.01,.01],[.025,.01,.01]])
   index,pf,keys,equal,error=f.associate_points(p,np.zeros(3),.05,raw,centres,tree)
   np.testing.assert_equal(index,[0,0]);np.testing.assert_equal(equal,[False,True]);self.assertNotEqual(keys[0,0],keys[1,0]);self.assertGreater(error,0)
   stats=tree.insert(0,pf,[.001,.001,.001]);self.assertEqual(stats['occupiedKeys'],2);np.testing.assert_equal(tree.query_keys(keys)['occupied'],[1,1])
 def test_unlisted_raw_voxel_refuses(self):
  with OctoMap()as tree:
   with self.assertRaisesRegex(ValueError,'raw membership'):
    f.associate_points(np.array([[.2,0,0]]),np.zeros(3),.05,f.packed(np.array([[0,0,0]])),tree.keys([[.025,.025,.025]]),tree)
 def test_empty_native_query_is_not_invented_coverage(self):
  with OctoMap()as tree:
   q=tree.query(np.empty((0,3)));self.assertEqual(len(q['known']),0)
if __name__=='__main__':unittest.main()
