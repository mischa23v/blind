"""Authored mocks only, no provided map or native library."""
import unittest
from types import SimpleNamespace
import numpy as np
import select_goal_region as g


class Fixtures(unittest.TestCase):
 def test_horizontal_and_full_xyz_bound(self):
  ok,h,d=g.region_membership([[.35,0,0],[.35,.001,0],[0,.351,0],[.349,0,0]], [0,0,0])
  np.testing.assert_equal(ok,[True,False,False,True])

 def test_do_not_compound_steering_tolerance(self):
  goal=[0,0,0];steering=[.34,0,0];actor=[.68,0,0]
  self.assertTrue(g.region_membership([steering],goal)[0][0])
  self.assertFalse(g.region_membership([actor],goal)[0][0])
  self.assertLess(np.linalg.norm(np.asarray(actor)-steering),.35)

 def test_nonfinite_region_input_refused(self):
  with self.assertRaises(ValueError):g.region_membership([[np.nan,0,0]],[0,0,0])

 def test_rank_clearance_then_distance_then_indices(self):
  mask=np.ones((3,3),bool)
  model=SimpleNamespace(mask=mask,origin=(0.,0.),flags={'walk':mask})
  ad=SimpleNamespace(map_objective=lambda p,a,b:(np.asarray(p),{}))
  clearance=SimpleNamespace(clearance_field=lambda m:np.ones(m.shape),
    clearance_at=lambda xy,o,f:np.where(xy[:,0]>.1,2.,1.))
  ranked,report=g.rank_candidates(model,None,None,np.array([.075,0,-.075]),ad,clearance)
  self.assertEqual(ranked[0]['sourceIJ'],[2,1])
  self.assertEqual(ranked[1]['sourceIJ'],[2,0])
  self.assertEqual(ranked[2]['sourceIJ'],[2,2])
  self.assertEqual(report['eligibleFull3DRegionCentres'],9)

 def test_full_xyz_mapping_not_flattened_for_distance(self):
  mask=np.ones((1,1),bool);model=SimpleNamespace(mask=mask,origin=(0.,0.),flags={'walk':mask})
  def mapping(p,a,b):
   q=np.asarray(p).copy();q[:,1]=.351;return q,{}
  ad=SimpleNamespace(map_objective=mapping)
  clearance=SimpleNamespace(clearance_field=lambda m:np.ones(m.shape),clearance_at=lambda xy,o,f:np.ones(len(xy)))
  ranked,report=g.rank_candidates(model,None,None,np.array([.025,0,-.025]),ad,clearance)
  self.assertEqual(ranked,[]);self.assertEqual(report['horizontalRegionRejectedByFull3DBound'],1)


if __name__=='__main__':unittest.main(verbosity=2)
