import unittest,math
from types import SimpleNamespace
import numpy as np
import paired_adapter as p
class Tests(unittest.TestCase):
 def test_coordinate_roundtrip(self):
  q=np.array([[1.,2.,3.],[-2.,.4,5.]])
  np.testing.assert_array_equal(p.level_to_game(p.game_to_level(q)),q)
 def test_identity_keeps_height(self):
  f={'R':np.eye(3),'t':np.zeros(3)};q=np.array([1.,.7,-2.]);out,r=p.map_objective(q,f,f)
  np.testing.assert_array_equal(out,q);self.assertFalse(r['mappedHeightWasFlattened'])
 def test_new_vertical_translation_not_flattened(self):
  old={'R':np.eye(3),'t':np.zeros(3)};new={'R':np.eye(3),'t':np.array([.2,-.3,.04])}
  out,r=p.map_objective([1,0,-2],old,new);np.testing.assert_allclose(out,[1.2,.04,-1.7],rtol=0,atol=1e-15)
  self.assertLess(r['roundtripMaximumAbsErrorMetres'],1e-15)
 def test_rotation_same_phone_point(self):
  th=.31;R=np.array([[math.cos(th),-math.sin(th),0],[math.sin(th),math.cos(th),0],[0,0,1.]])
  old={'R':R,'t':np.array([.3,.7,-.2])};new={'R':R.T,'t':np.array([-.6,.2,.5])};q=np.array([2.,.8,-1.])
  out,r=p.map_objective(q,old,new);back,_=p.map_objective(out,new,old)
  np.testing.assert_allclose(back,q,atol=1e-14,rtol=0)
  np.testing.assert_allclose((p.game_to_level(out)-new['t'])@new['R'],r['unchangedPhoneXYZ'],atol=1e-14,rtol=0)
 def test_association_reports_vertical_without_changing_request(self):
  a=np.array([1.,.04,2.]);before=a.copy();r=p.association(a,[1.02,.025,2.])
  self.assertAlmostEqual(r['verticalDisplacementMetres'],-.015);self.assertTrue(r['existingHorizontalAssociationAtMost0p10m']);np.testing.assert_array_equal(a,before)
 def test_association_nan_explicit(self):
  r=p.safe(p.association([0,0,0],[float('nan')]*3));self.assertFalse(r['validProjectedXYZ']);self.assertEqual(r['projectedXYZ'],[None]*3)
 def test_exact_endpoint_check_can_reject_sweep_ok(self):
  rr=SimpleNamespace(sweep_ok=lambda *args:'ok',rect_ok=lambda mask,origin,x,y,theta:x<1.)
  m=SimpleNamespace(rr=rr,mask=None,origin=None)
  r=p.check_open(m,np.array([[0.,0.,0.],[1.,.04,0.]]));self.assertFalse(r['passed']);self.assertEqual(r['unchangedSourceSweep'],'ok')
 def test_malformed_objective_rejected(self):
  with self.assertRaises(ValueError):p.game_to_level([0.,float('inf'),1.])
if __name__=='__main__':unittest.main()
