import unittest
import numpy as np
from local_support import load,HERE
from trial_attempts import rectangle_cells,check_pose,swept_map_ok

class TrialTests(unittest.TestCase):
    def setUp(self):
        self.cfg=load(HERE/'PROTOCOL.json');shape=(80,80)
        self.data={k:np.zeros(shape,bool)for k in ('lowObstacle','lowOrSupportUnresolved','stepEdge','occupiedBodyOrHead','unknownBodyOrHead')}
        self.data.update(walk=np.ones(shape,bool),support=np.ones(shape,bool),lo=np.array([0,0,-4]))
    def test_body_margin_not_shrunk(self):
        c=rectangle_cells(np.array([2.,2.]),0,.30,.375,np.zeros(2),.05,(80,80));self.assertGreaterEqual(np.ptp(c[:,1]),14)
    def test_head_unknown_withholds_footprint(self):
        self.data['unknownBodyOrHead'][40,40]=True;self.data['walk'][40,40]=False
        ok,r=check_pose(self.data,np.array([2.025,2.025]),0,self.cfg);self.assertFalse(ok);self.assertEqual(r['unknownBodyOrHead'],1)
    def test_sweep_catches_intermediate_obstacle(self):
        self.data['walk'][40,40]=False
        self.assertTrue(check_pose(self.data,np.array([1.,2.025]),0,self.cfg)[0])
        self.assertTrue(check_pose(self.data,np.array([3.,2.025]),0,self.cfg)[0])
        self.assertFalse(swept_map_ok(self.data,np.array([1.,2.025]),np.array([3.,2.025]),0,0,self.cfg))
    def test_missing_support_withheld(self):
        self.data['support'][40,40]=False;self.data['walk'][40,40]=False
        self.assertFalse(check_pose(self.data,np.array([2.025,2.025]),0,self.cfg)[0])
    def test_outside_map_not_clear(self):self.assertFalse(check_pose(self.data,np.array([0.,0.]),0,self.cfg)[0])

if __name__=='__main__':unittest.main()
