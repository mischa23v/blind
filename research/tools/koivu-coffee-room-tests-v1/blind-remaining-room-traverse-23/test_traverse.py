import unittest,numpy as np
import select_traverse as st
class T(unittest.TestCase):
 def test_closed_roi(self):
  self.assertTrue(st.roi_box_overlap(np.array([-3.,1.]),np.array([-2.,2.])))
  self.assertFalse(st.roi_box_overlap(np.array([-2.9,1.]),np.array([-2.,2.])))
  self.assertFalse(st.roi_box_overlap(np.array([-4.,.1]),np.array([-3.1,.99])))
 def test_continuous_sweep_roi(self):
  class M:pass
  m=M();m.rr=M();m.rr.RB=np.array([[-.15,-.225],[-.15,.225],[.15,-.225],[.15,.225]])
  class A:
   def map_objective(self,p,n,o):return np.asarray(p),{}
   def game_to_level(self,p):return np.asarray(p)[:,[0,2,1]]*np.array([1,-1,1])
  a=A();r=st.exclusion(np.array([[-3.4,0,0.],[-3.4,0,-4.]]),m,a,None,None)
  self.assertFalse(r['passed']) # endpoints outside, swept segment intersects.
  r=st.exclusion(np.array([[-2.4,0,0.],[-2.4,0,-4.]]),m,a,None,None);self.assertTrue(r['passed'])
 def test_targets_and_cap(self):self.assertEqual((st.START,st.TARGETS,st.CAP),(92,[120,200,220,20],32))
if __name__=='__main__':unittest.main(verbosity=2)
