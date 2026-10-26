"""Tiny label/coordinate contract fixtures; no recorded reference mesh."""
import unittest
import numpy as np
from label_contract import PHONE_KEYS,MASK_KEYS,validate_arrays,masks_from_phone,select_columns
from score_reference import transform

def fixture():
    a={'lo':np.array([0,0,-4]),'R':np.eye(3),'t':np.zeros(3),'state':np.full((4,4),'clear',dtype='U10'),'mean':np.zeros((4,4)),'n':np.full((4,4),40),'tail':np.zeros((4,4))}
    a.update({k:np.zeros((4,4),bool)for k in MASK_KEYS});a['walk'][:]=True;a['support'][:]=True
    d={'stage':'D1',**{k:int(a[k].sum())for k in MASK_KEYS}}
    m=masks_from_phone(a);w={'stage':'walk',**{k:int(m[k].sum())for k in ('d1Permissive','d1Strict','statClearOnly','statObjectBlocked')},'statStates_walk':{'clear':16,'object':0,'unresolved':0},'statStates_flagged':{'clear':0,'object':0,'unresolved':0}}
    return a,{'log':[d,w]}

class Contracts(unittest.TestCase):
    def test_valid_phone_only_selection_ignores_reference_fields(self):
        a,r=fixture();a['refWalk']=np.zeros((4,4),bool);first=validate_arrays(a,r);rows,receipt=select_columns(first)
        a['refWalk'][:]=True;second=validate_arrays(a,r)
        self.assertTrue(np.array_equal(rows,select_columns(second)[0]));self.assertNotIn('refWalk',first)
    def test_mismatched_receipt_rejected(self):
        a,r=fixture();r['log'][0]['walk']=15
        with self.assertRaises(ValueError):validate_arrays(a,r)
    def test_improper_level_rotation_rejected(self):
        a,r=fixture();a['R'][0,0]=-1
        with self.assertRaises(ValueError):validate_arrays(a,r)
    def test_unknown_statistical_label_rejected(self):
        a,r=fixture();a['state'][0,0]='safe'
        with self.assertRaises(ValueError):validate_arrays(a,r)
    def test_model_to_reference_matches_direct_level_mapping(self):
        a,_=fixture();theta=.37;a['R']=np.array([[np.cos(theta),-np.sin(theta),0],[np.sin(theta),np.cos(theta),0],[0,0,1.]])
        a['t']=np.array([.1,-.2,1.2]);A=np.eye(4);A[:3,:3]*=1.02079084;A[:3,3]=[2,-3,4]
        point=np.array([.7,.012,-.4]);level=np.array([point[0],-point[2],point[1]])
        expected=A[:3,:3]@(a['R'].T@(level-a['t']))+A[:3,3]
        actual=transform(a,A)@np.r_[point,1.]
        np.testing.assert_allclose(actual[:3],expected,atol=1e-14,rtol=0)
    def test_no_octomap_half_cell_height_shift_in_reference_boxes(self):
        a,_=fixture();a['t']=[0,0,1.2];m=transform(a,np.eye(4))
        np.testing.assert_allclose((m@[0,0,0,1])[:3],[0,0,-1.2],atol=1e-14,rtol=0)

if __name__=='__main__':unittest.main(verbosity=2)
