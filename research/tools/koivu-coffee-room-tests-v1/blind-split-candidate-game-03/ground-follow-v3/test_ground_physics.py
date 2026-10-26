import unittest
import numpy as np
from run_ground_pilot import connected_support,proposed_ground_motion
class Ground:
    def __init__(self,plane=lambda x,z:0.):self.plane=plane
    def is_ground(self,cell_id):return cell_id==1
    def plane_height(self,x,z):return self.plane(x,z)
class Surface:
    def __init__(self,height=lambda x,z:0.,cell=1,missing=False):self.height=height;self.cell=cell;self.missing=missing
    def support_probes(self,point,yaw):
        return {'probes':[{'hit':not self.missing,'modelXZ':point[[0,2]].tolist(),'modelHeightY':self.height(point[0],point[2]) if not self.missing else None,'referenceCellID':self.cell if not self.missing else None}for _ in range(9)]}
class Tests(unittest.TestCase):
    def motion(self,surface,plane=lambda x,z:0.):
        return proposed_ground_motion(surface,Ground(plane),np.array([0.,0.,0.]),np.array([.02,0.,0.]),0.,0.)
    def test_one_plane_sets_height_without_horizontal_correction(self):
        seg,checks,info=self.motion(Surface(lambda x,z:x*.05+.0002),lambda x,z:x*.05)
        self.assertIsNotNone(seg);self.assertAlmostEqual(seg[1][1],.001)
        np.testing.assert_array_equal(seg[1][[0,2]],[.02,0.]);self.assertLess(info['attempted3DDistanceMetres'],.025)
    def test_raw_ground_noise_does_not_move_planar_body_up_down(self):
        seg,checks,info=self.motion(Surface(lambda x,z:.0002))
        self.assertEqual(seg[0][1],0.);self.assertEqual(seg[1][1],0.);self.assertEqual(info['attempted3DDistanceMetres'],.02)
    def test_detached_flat_top_cannot_set_height(self):
        seg,checks,_=self.motion(Surface(lambda x,z:.01,cell=2));self.assertIsNone(seg)
        self.assertFalse(checks[0]['groundComponentConfirmedForAllProbes'])
    def test_missing_support_is_not_filled_by_infinite_plane(self):
        seg,checks,_=self.motion(Surface(missing=True));self.assertIsNone(seg);self.assertEqual(checks[0]['missingCount'],9)
    def test_drop_not_hidden_by_plane(self):
        seg,checks,_=self.motion(Surface(lambda x,z:-.05));self.assertIsNone(seg)
    def test_planar_motion_cannot_exceed_3d_cap(self):
        seg,checks,info=self.motion(Surface(lambda x,z:x*.8),lambda x,z:x*.8)
        self.assertIsNone(seg);self.assertIn('cap',info['reason'])
    def test_initial_broad_plane_cannot_float_above_raw_support(self):
        row=Surface().support_probes(np.array([0.,0.,0.]),0.)
        self.assertFalse(connected_support(row,Ground(),.03)['acceptedFiniteSupportModel'])
    def test_midpoint_hole_prevents_endpoint_repair(self):
        class MidMissing(Surface):
            def support_probes(self,p,yaw):self.missing=p[0]<.015;return super().support_probes(p,yaw)
        seg,checks,_=self.motion(MidMissing());self.assertIsNone(seg);self.assertEqual(len(checks),1)
if __name__=='__main__':unittest.main(verbosity=2)
