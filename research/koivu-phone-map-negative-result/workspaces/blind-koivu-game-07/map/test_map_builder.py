import unittest,numpy as np
import map_builder as m
class MapTests(unittest.TestCase):
 def frame(self):return {'transform_matrix':np.eye(4).tolist(),'fl_x':10.,'fl_y':10.,'cx':5.,'cy':5.,'w':11,'h':11}
 def test_half_pixel(self):
  f=self.frame();d=np.zeros((11,11));d[5,6]=2;p,missing=m.points_from_depth(d,f);np.testing.assert_allclose(p,[[.3,-.1,-2]]);self.assertEqual(missing,120)
 def test_rigid_transform(self):
  f=self.frame();f['transform_matrix'][0][3]=3;d=np.zeros((11,11));d[4,4]=1;p,_=m.points_from_depth(d,f);np.testing.assert_allclose(p,[[2.95,.05,-1]])
 def test_every_pixel(self):
  f=self.frame();p,n=m.points_from_depth(np.ones((11,11)),f);self.assertEqual(len(p),121);self.assertEqual(n,0)
 def test_invalid_pose(self):
  f=self.frame();f['transform_matrix'][0][0]=2
  with self.assertRaises(ValueError):m.checked_camera(f)
 def test_voxel_low_head_retention(self):
  p=np.array([[.01,.01,.01],[.01,.04,.01],[.01,1.61,.01]]);k,v=m.grid(p,np.zeros(3),np.array([2,40,2]));self.assertTrue(v.all());self.assertEqual(len(k),3);self.assertNotEqual(k[0],k[2])
 def test_free_margin(self):
  f=self.frame();d=np.ones((11,11))*2; p=np.array([[0.,0.,-1.9],[0.,0.,-1.96],[0.,0.,-2.1]])
  np.testing.assert_equal(m.free_observed(p,d,f,np.eye(4)),[True,False,False])
 def test_missing_neighbour_not_filled(self):
  f=self.frame();d=np.ones((11,11))*2;d[4,4]=0;self.assertFalse(m.free_observed(np.array([[0.,0.,-1.]]),d,f,np.eye(4))[0])
 def test_no_edge_neighbourhood(self):
  f=self.frame();d=np.ones((11,11))*2;self.assertFalse(m.free_observed(np.array([[-.5,0.,-1.]]),d,f,np.eye(4))[0])
 def test_depth_bound(self):
  self.assertFalse(m.free_observed(np.array([[0.,0.,-1.]]),np.ones((11,11))*9,self.frame(),np.eye(4))[0])
 def test_level_fit_and_transform(self):
  x,y=np.meshgrid(np.arange(-1,1.01,.05),np.arange(-1,1.01,.05));p=np.column_stack((x.ravel(),y.ravel(),-1.5+.01*x.ravel()));t,r=m.fit_floor(p,np.zeros(3));a=p@t[:3,:3].T+t[:3,3];self.assertLess(abs(a[:,1]).max(),1e-10);self.assertAlmostEqual(np.linalg.det(t[:3,:3]),1)
 def test_collinear_fit_fails(self):
  p=np.column_stack((np.linspace(-2,2,300),np.linspace(-2,2,300),np.full(300,-1.5)))
  with self.assertRaises(ValueError):m.fit_floor(p,np.zeros(3))

class ClassificationTests(unittest.TestCase):
 def floor(self):return np.array([[x,0,z] for x in (0,1) for z in (0,1)]),np.zeros(4),np.zeros(4),np.full(4,2)
 def test_support_quadrants_and_distinct_frames(self):
  a,b,c,d=self.floor();self.assertTrue(m.surface_classification(a,b,c,d,1,1)[0][0]);d[0]=1;self.assertFalse(m.surface_classification(a,b,c,d,1,1)[0][0])
 def test_band_boundary_and_positive_wins(self):
  a,b,c,d=self.floor();b[:]=-.03;c[:]=.03
  r=m.surface_classification(a,b,c,d,1,1);self.assertTrue(r[0][0]);self.assertFalse(r[1][0]);c[0]=.0300001;r=m.surface_classification(a,b,c,d,1,1);self.assertTrue(r[1][0]);self.assertTrue(r[2][0])
 def test_below_floor_strict_overlap(self):
  a,b,c,d=self.floor();b[0]=-.04;c[0]=-.025;r=m.surface_classification(a,b,c,d,1,1);self.assertTrue(r[3][0]);b[0]=-.3;c[0]=-.25;self.assertFalse(m.surface_classification(a,b,c,d,1,1)[3][0])
 def test_top_touch_is_explicit(self):
  a,b,c,d=self.floor();b[0]=1.75;c[0]=1.8;self.assertFalse(m.surface_classification(a,b,c,d,1,1)[2][0]);b[0]=1.749999;self.assertTrue(m.surface_classification(a,b,c,d,1,1)[2][0])
 def test_duplicate_pixels_only_one_view(self):
  hits=np.zeros(2,np.uint32);views=np.zeros(2,np.uint16);lo=np.full(2,np.inf);hi=np.full(2,-np.inf)
  m.accumulate(np.array([0,0,0,1]),np.array([0.,.01,.02,1.6]),hits,views,lo,hi);np.testing.assert_equal(views,[1,1]);np.testing.assert_equal(hits,[3,1]);m.accumulate(np.array([0]),np.array([0.]),hits,views,lo,hi);np.testing.assert_equal(views,[2,1])
 def test_one_of_ninety_missing(self):
  coverage=np.ones((2,90),bool);coverage[0,89]=False;np.testing.assert_equal(coverage.all(1),[False,True])

if __name__=="__main__":unittest.main()
