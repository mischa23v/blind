import math,unittest
from unittest.mock import patch
import numpy as np
import candidate_map as cm

class Tests(unittest.TestCase):
 def test_proper_coordinate_transform(self):
  basis=cm.source_to_game(np.eye(3));self.assertAlmostEqual(np.linalg.det(basis),1.)
  p=np.array([[2.,3.,4.],[-1.,5.,0.]]);np.testing.assert_array_equal(cm.game_to_source(cm.source_to_game(p)),p)
 def test_transformed_cell_bounds_and_upward_winding(self):
  rr,de=cm.modules();v,t=rr.quads(np.ones((1,1),bool),(1.,2.),.05);v[:,2]*=-1;t=t[:,[0,2,1]]
  self.assertAlmostEqual(float(v[:,2].min()),-2.05,places=6);self.assertAlmostEqual(float(v[:,2].max()),-2,places=6)
  self.assertTrue((np.cross(v[t[:,1]]-v[t[:,0]],v[t[:,2]]-v[t[:,0]])[:,1]>0).all())
 def test_real_engine_proper_quads(self):
  rr,de=cm.modules();v,t=rr.quads(np.ones((100,100),bool),(-2.5,-2.5),.05);v[:,2]*=-1;t=t[:,[0,2,1]]
  with de.Engine(v,t,de.Config(radius=.375,height=1.75,cell_size=.05,max_climb=0.),mode='known-provided-map')as e:
   r=e.route((-1.,0.,0.),(1.,0.,0.));self.assertTrue(r.complete);self.assertGreaterEqual(len(r.points),2)
 def test_game_yaw_maps_to_source_negative_yaw(self):
  rr,_=cm.modules();m=cm.CandidateMap.__new__(cm.CandidateMap);m.rr=rr;m.origin=(-1.,-1.);m.mask=np.ones((40,40),bool)
  self.assertTrue(m.sampled_fit([0,0,0],math.pi/2));self.assertFalse(m.sampled_fit([2,0,0],0));self.assertFalse(m.sampled_fit([0,0,0],math.nan))
  np.testing.assert_array_equal(cm.source_route([[1.,0.,2.]]),[[1.,0.,-2.]])
 def test_route_skips_start_once_and_keeps_association(self):
  rr,de=cm.modules();m=cm.CandidateMap.__new__(cm.CandidateMap);m.rr=rr;m.origin=(-2.,-2.);m.mask=np.ones((80,80),bool);m.revision='test'
  class Fake:
   def route(self,a,b):return de.Route(((0.,.025,0.),(1.,.025,0.)),(0.,.025,0.),(1.,.025,0.),True,1,None)
  m.engine=Fake();r=m.route([0.,0.,0.],[1.,0.,0.]);self.assertTrue(r['complete']);self.assertEqual(r['points'],[[1.,.025,0.]])
 def test_unassociated_route_is_not_candidate(self):
  rr,de=cm.modules();m=cm.CandidateMap.__new__(cm.CandidateMap);m.rr=rr;m.origin=(-2.,-2.);m.mask=np.ones((80,80),bool);m.revision='test'
  class Fake:
   def route(self,a,b):return de.Route(((.5,0.,0.),(1.,0.,0.)),(.5,0.,0.),(1.,0.,0.),True,1,None)
  m.engine=Fake();self.assertFalse(m.route([0,0,0],[1,0,0])['complete'])
 def test_phone_field_allowlist_no_reference_access(self):
  accesses=[];shape=(241,250)
  split={k:np.ones(shape,bool)if k in('walk','support')else np.zeros(shape,bool)for k in cm.PHONE_KEYS}
  meta={'lo':np.array([-116,-121,-4]),'R':np.eye(3),'t':np.zeros(3),'res':np.asarray(.05)}
  class Box:
   def __init__(self,d):self.d=d;self.files=list(d)
   def __enter__(self):return self
   def __exit__(self,*a):pass
   def __getitem__(self,k):accesses.append(k);return self.d[k]
  class RR:
   @staticmethod
   def quads(*a):return np.array([[0.,0.,0.],[0.,0.,1.],[1.,0.,0.]],np.float32),np.array([[0,1,2]],np.int32)
  class E:
   def __init__(self,*a,**k):pass
   def close(self):pass
  class DE:
   Engine=E
   @staticmethod
   def Config(**k):return k
  def load(p,**k):return Box(split if str(p)=='split'else meta)
  with patch.object(cm,'modules',return_value=(RR,DE)),patch.object(cm,'sha',side_effect=lambda p:cm.SPLIT_SHA if str(p)=='split'else cm.META_SHA),patch.object(cm.np,'load',side_effect=load):
   with cm.CandidateMap.load('split','meta')as m:self.assertEqual(m.mask.shape,shape)
  self.assertEqual(set(accesses),set(cm.PHONE_KEYS)|{'lo','R','t','res'})
if __name__=='__main__':unittest.main()
