import unittest
import numpy as np
from local_support import frame_evidence,combine,load,HERE

class LocalSupportTests(unittest.TestCase):
    def setUp(self):self.cfg=load(HERE/'PROTOCOL.json');self.lo=np.array([0,0,-4]);self.shape=(6,6)
    def cell(self,heights,plane=(0,0,1,-.06),valid=True):
        p=np.c_[np.full(len(heights),.125),np.full(len(heights),.125),heights]
        return frame_evidence(p,np.ones(len(p)),plane,valid,self.lo,self.shape,self.cfg)
    def fused(self,e):
        return combine(np.array([e['supportHeight']]*3),e['positive']*np.uint16(3),e['ambiguous']*np.uint16(3),e['negative']*np.uint16(3),self.cfg)
    def test_observed_offset_floor_is_support_without_global_zero(self):
        d=self.fused(self.cell([.06,.06]));i=2*6+2
        self.assertTrue(d['support'][i]);self.assertFalse(d['lowObstacle'][i]);self.assertFalse(d['lowOrSupportUnresolved'][i]);self.assertAlmostEqual(d['floorHeight'][i],.06,places=6)
    def test_one_cm_toy_retained_with_floor_in_same_cell(self):
        d=self.fused(self.cell([.06,.07]));self.assertTrue(d['lowObstacle'][14])
    def test_three_mm_object_unresolved_not_clear(self):
        d=self.fused(self.cell([.06,.063]));self.assertTrue(d['lowOrSupportUnresolved'][14])
    def test_shallow_dip_retained(self):self.assertTrue(self.fused(self.cell([.06,.05]))['lowOrSupportUnresolved'][14])
    def test_no_plane_extrapolation_to_empty_cell(self):
        d=self.fused(self.cell([.06]));self.assertEqual(int(d['support'].sum()),1);self.assertTrue(d['lowOrSupportUnresolved'][0])
    def test_invalid_fit_cannot_establish_support(self):self.assertFalse(self.fused(self.cell([.06],valid=False))['support'].any())
    def test_cross_view_height_disagreement_is_unknown(self):
        e=self.cell([.06]);h=np.array([e['supportHeight']]*3);h[0,14]=.0
        d=combine(h,np.zeros(36),np.zeros(36),np.zeros(36),self.cfg);self.assertFalse(d['support'][14]);self.assertTrue(d['lowOrSupportUnresolved'][14])
    def test_two_views_insufficient(self):
        e=self.cell([.06]);d=combine(np.array([e['supportHeight']]*2),np.zeros(36),np.zeros(36),np.zeros(36),self.cfg);self.assertFalse(d['support'].any())

if __name__=='__main__':unittest.main()
