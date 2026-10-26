import math,unittest
import numpy as np
from run_ground_pilot import connected_support,proposed_ground_motion

class Ground:
    def is_ground(self,cell_id):return cell_id==1
class Surface:
    def __init__(self,height=lambda x,z:0.,cell=1,missing=False):self.height=height;self.cell=cell;self.missing=missing
    def support_probes(self,point,yaw):
        return {'probes':[{'hit':not self.missing,'modelHeightY':self.height(point[0],point[2]) if not self.missing else None,'referenceCellID':self.cell if not self.missing else None}for _ in range(9)]}
class Tests(unittest.TestCase):
    def motion(self,surface,start=None,end=None):
        return proposed_ground_motion(surface,Ground(),np.array([0.,0.,0.]if start is None else start),np.array([.02,0.,0.]if end is None else end),0.,0.)
    def test_smooth_two_mm_rise_follows_not_contacts(self):
        seg,checks,info=self.motion(Surface(lambda x,z:x*.05))
        self.assertIsNotNone(seg);self.assertAlmostEqual(seg[1][1],.001)
        np.testing.assert_array_equal(seg[1][[0,2]],[.02,0.]);self.assertLess(info['attempted3DDistanceMetres'],.025)
    def test_smooth_ripple_keeps_midpoint_excursion(self):
        seg,checks,info=self.motion(Surface(lambda x,z:.0002*math.sin(math.pi*x/.02)))
        self.assertAlmostEqual(seg[0][1],.0002);self.assertAlmostEqual(seg[1][1],0.)
        self.assertGreater(info['attempted3DDistanceMetres'],.02)
    def test_detached_flat_top_cannot_set_height(self):
        seg,checks,_=self.motion(Surface(lambda x,z:.01,cell=2));self.assertIsNone(seg)
        self.assertFalse(checks[0]['groundComponentConfirmedForAllProbes'])
    def test_missing_support_remains_unknown(self):
        seg,checks,_=self.motion(Surface(missing=True));self.assertIsNone(seg);self.assertEqual(checks[0]['missingCount'],9)
    def test_drop_not_hidden_as_ground_following(self):
        seg,checks,_=self.motion(Surface(lambda x,z:-.05));self.assertIsNone(seg)
    def test_ground_following_cannot_exceed_3d_actor_cap(self):
        seg,checks,info=self.motion(Surface(lambda x,z:x*.8));self.assertIsNone(seg);self.assertIn('cap',info['reason'])
    def test_first_half_support_failure_prevents_end_repair(self):
        class MidMissing(Surface):
            def support_probes(self,p,yaw):self.missing=p[0]<.015;return super().support_probes(p,yaw)
        seg,checks,_=self.motion(MidMissing());self.assertIsNone(seg);self.assertEqual(len(checks),1)
if __name__=='__main__':unittest.main(verbosity=2)
