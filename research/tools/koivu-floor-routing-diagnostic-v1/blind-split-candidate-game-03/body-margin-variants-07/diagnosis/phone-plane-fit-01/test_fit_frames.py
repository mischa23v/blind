import unittest
import numpy as np
from fit_frames import fit
def grid(height):
 x,y=np.meshgrid(np.linspace(-1,1,21),np.linspace(-1,1,21));return np.c_[x.ravel(),y.ravel(),np.full(x.size,height)]
class Tests(unittest.TestCase):
 def test_broad_offset_plane(self):
  p=grid(.07);before=p.copy();r,q=fit(p)
  self.assertTrue(r['valid']);self.assertAlmostEqual(-q[3]/q[2],.07,places=10);np.testing.assert_array_equal(p,before)
 def test_one_cm_toy_is_retained_numeric_residual_not_cleared(self):
  floor=grid(.07);toy=grid(.08)[::50].copy();p=np.r_[floor,toy];before=p.copy();r,q=fit(p)
  self.assertTrue(r['valid']);self.assertGreater(float(np.median(toy@q[:3]+q[3])),.008);np.testing.assert_array_equal(p,before)
  self.assertNotIn('walk',r);self.assertTrue(r['inliersAreNotClearance'])
 def test_vertical_wall_rejected(self):
  p=grid(.07)[:,[2,0,1]];r,q=fit(p);self.assertFalse(r['valid']);self.assertIn('notLevel',r['reason'])
 def test_sparse_and_line_coverage_rejected(self):
  r,q=fit(grid(.07)[:20]);self.assertFalse(r['valid'])
  p=grid(.07);p[:,1]*=.001;r,q=fit(p);self.assertFalse(r['valid']);self.assertIn('insufficient2DCoverage',r['reason'])
 def test_hole_not_filled(self):
  p=grid(.07);p=p[np.hypot(p[:,0],p[:,1])>.4];before=p.copy();r,q=fit(p)
  self.assertTrue(r['valid']);np.testing.assert_array_equal(p,before);self.assertNotIn('support',r)
 def test_degenerate_cloud_is_unavailable_not_nan(self):
  for p in [np.tile([0.,0.,.07],(150,1)),np.c_[np.linspace(-1,1,150),np.zeros(150),np.full(150,.07)]]:
   r,q=fit(p);self.assertFalse(r['valid']);self.assertIsNone(q)
if __name__=='__main__':unittest.main()
