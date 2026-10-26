import unittest,math,importlib.util,sys
from pathlib import Path
import numpy as np
HERE=Path(__file__).resolve().parent
import goal_region_map as gm
import goal_region_controller as gc
class FakeMap:
 def __init__(self):self.queries=[];self.fit=True
 def flag_receipt(self,p,y):return {'sampledFit':self.fit,'lowUnresolvedCells':1}
 def route(self,p,g):
  self.queries.append((p.copy(),g.copy()));return {'complete':True,'points':[g.tolist()],'projectedStart':p.tolist(),'projectedGoal':g.tolist()}
class Tests(unittest.TestCase):
 def controller(self,goal,steer):
  c=gc.Controller();c.model=FakeMap();c.goal=np.array(goal,float);c.route_goal=np.array(steer,float);c.revision='fixture';return c
 def tick(self,c,pos):return c.consume({'command':'tick','tick':0,'now':100.,'deliveredPose':{'kind':'simulated-physics-body-pose','position':pos,'yaw':0.,'capturedAt':100.,'mapRevision':'fixture'}})
 def test_steering_proximity_not_arrival(self):
  c=self.controller([0,0,0],[.3,0,0]);r=self.tick(c,[.6,0,0]);self.assertFalse(r['goalReached']);np.testing.assert_array_equal(c.model.queries[0][1],[.3,0,0])
 def test_original_task_goal_stops(self):
  c=self.controller([0,0,0],[.3,0,0]);r=self.tick(c,[.33,0,0]);self.assertTrue(r['goalReached']);self.assertEqual(r['forwardMetres'],0);self.assertFalse(c.model.queries)
 def test_vertical_goal_error_not_erased(self):
  c=self.controller([0,0,0],[.3,0,0]);r=self.tick(c,[.33,.2,0]);self.assertFalse(r['goalReached'])
 def test_current_footprint_blocks_even_in_goal(self):
  c=self.controller([0,0,0],[.3,0,0]);c.model.fit=False;r=self.tick(c,[.1,0,0]);self.assertFalse(r['goalReached']);self.assertEqual(r['forwardMetres'],0)
 def test_frozen_candidate_and_full_frame_roundtrip(self):
  p=gm.load_plan();self.assertEqual(p['goal'],[-2.8487096487644004,0.,-3.1937490266953104]);self.assertLess(np.linalg.norm(np.array(p['goal'])-p['steeringGoalOriginalFrame']),.35)
  pair=gm.load_paired();old=pair.metadata('old');new=pair.metadata('new');point=np.array([1.2,.027,-2.3]);q,_=pair.map_objective(point,old,new);back,_=pair.map_objective(q,new,old);np.testing.assert_allclose(back,point,rtol=0,atol=1e-12)
 def test_heading_vector_rotation(self):
  pair=gm.load_paired();old=pair.metadata('old');new=pair.metadata('new')
  for yaw in [-3,-1,0,1,3]:
   q=gm.map_yaw(yaw,old,new,pair);back=gm.map_yaw(q,new,old,pair)
   self.assertLess(abs(math.atan2(math.sin(back-yaw),math.cos(back-yaw))),2e-7)
 def test_driver_exact_import_owner_and_scene_plane(self):
  spec=importlib.util.spec_from_file_location('north_driver_fixture',HERE/'run_north.py');m=importlib.util.module_from_spec(spec);sys.modules[spec.name]=m;spec.loader.exec_module(m)
  self.assertEqual(Path(m.motion.proposed_ground_motion.__code__.co_filename).resolve(),gm.GAME/'ground-follow-v3/run_ground_pilot.py')
  self.assertEqual(m.motion.GroundTiledReferenceContainer.__name__,'GroundTiledReferenceContainer')
  class Ground:pass
  g=Ground();g.receipt={'broadPlaneCoefficientsYEqualsAXPlusBZPlusC':[9,9,9],'broadPlaneFit':{'diagnostic':True}};g.plane_coefficients=np.ones(3)
  m.retain_scene_plane(g,{'planeCoefficientsYEqualsAXPlusBZPlusC':[.001,.002,0.]});np.testing.assert_array_equal(g.plane_coefficients,[.001,.002,0.]);self.assertEqual(g.receipt['expandedMembershipBroadPlaneDiagnostic'],[9,9,9]);self.assertFalse(g.plane_coefficients.flags.writeable)
if __name__=='__main__':unittest.main(verbosity=2)
