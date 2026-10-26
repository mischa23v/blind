import unittest
import numpy as np
from pilot_controller import Controller
from run_pilot import support_check,contact_status

class FakeMap:
    revision='fixture'
    def flag_receipt(self,p,y):return {'sampledFit':True,'lowUnresolvedCells':1,'physicalAuthority':False}
    def route(self,a,b):return {'complete':True,'points':[[3.,.02,0.]],'projectedStart':a.tolist(),'projectedGoal':b.tolist()}
    def close(self):pass

class Tests(unittest.TestCase):
    def controller(self):
        c=Controller();c.model=FakeMap();c.revision='fixture';c.goal=np.array([3.,0,0]);return c
    def packet(self,position=None):return {'command':'tick','tick':0,'now':100.,'deliveredPose':{'kind':'simulated-physics-body-pose','position':[0,.01,0]if position is None else position,'yaw':0.,'capturedAt':100.,'mapRevision':'fixture'}}
    def test_single_native_endpoint_is_not_skipped_twice(self):
        r=self.controller().consume(self.packet());self.assertEqual(r['forwardMetres'],.02);self.assertFalse(r['physicalAuthority'])
    def test_goal_requires_delivered_actual_pose(self):
        r=self.controller().consume(self.packet([2.7,.01,0]));self.assertTrue(r['goalReached']);self.assertEqual(r['forwardMetres'],0.)
    def test_reference_data_is_not_an_accepted_input(self):
        p=self.packet();p['referenceContact']=False
        with self.assertRaises(ValueError):self.controller().consume(p)
    def test_pose_kind_cannot_claim_live_sensor(self):
        p=self.packet();p['deliveredPose']['kind']='ARKit'
        with self.assertRaises(ValueError):self.controller().consume(p)
    def test_missing_floor_support_is_not_clear(self):
        r={'probes':[{'hit':True,'modelHeightY':0.}]*8+[{'hit':False,'modelHeightY':None}]};self.assertFalse(support_check(r)['acceptedFiniteSupportModel'])
    def test_initial_offset_is_not_zero_uncertainty(self):
        r={'probes':[{'hit':True,'modelHeightY':.01}]*9};a=support_check(r);self.assertTrue(a['acceptedFiniteSupportModel']);self.assertEqual(a['heightMaximum'],.01);self.assertFalse(a['continuousSupportProven'])
    def test_near_foot_contact_still_terminates_ambiguity(self):
        hit={'contact':True,'firstTriangleHeightRelativeToStartFootRange':[.002,.02]};self.assertEqual(contact_status({'actualBody':hit,'horizontalMargin':hit}),'firstContactTriangleNearFootAmbiguous')
if __name__=='__main__':unittest.main(verbosity=2)
