import unittest
import numpy as np
import western_depth_residuals as w

class Tests(unittest.TestCase):
 def test_source_sample_and_float32(self):
  d=np.zeros((8,8),np.uint16);d[3,3]=1000;d[7,7]=2000
  f={'cx':3.5,'cy':3.5,'fl_x':2.,'fl_y':2.,'transform_matrix':np.eye(4).tolist()}
  p,r,c,mm,j=w.project(d,f)
  self.assertEqual(p.dtype,np.float32);np.testing.assert_array_equal(r,[3,7]);np.testing.assert_array_equal(c,[3,7]);np.testing.assert_array_equal(mm,[1000,2000])
  np.testing.assert_array_equal(p,[[0,0,-1],[4,-4,-2]])
 def test_no_zero_depth_invention(self):
  f={'cx':0.,'cy':0.,'fl_x':1.,'fl_y':1.,'transform_matrix':np.eye(4).tolist()}
  self.assertEqual(len(w.project(np.zeros((8,8),np.uint16),f)[0]),0)
 def test_empty_summary(self):
  self.assertEqual(w.summary([]),{'n':0,'min':None,'p05_p50_p95':None,'max':None})
 def test_roi_association_and_rejection(self):
  T=np.eye(4);T[:3,3]=[-3.025,2.025,1.]
  frames=[{'transform_matrix':T.tolist()}];flags={'walk':np.ones((2,2),bool),'support':np.ones((2,2),bool),'low1':np.zeros((2,2),bool)}
  row={'frameIndex1Based':1,'sourceIJ':[0,0],'sourceXY':[-3.025,2.025],'walk':True,'support':True,'low1':False}
  w.verify_roi([row]*71,frames,np.eye(3),np.zeros(3),np.array([-61,40,0]),.05,flags)
  for key,value in [('sourceIJ',[1,0]),('sourceXY',[-3.,2.025]),('walk',False),('frameIndex1Based',2)]:
   bad=dict(row);bad[key]=value
   with self.assertRaises(ValueError):w.verify_roi([bad]*71,frames,np.eye(3),np.zeros(3),np.array([-61,40,0]),.05,flags)

if __name__=='__main__':unittest.main()
