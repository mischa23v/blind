import copy
import json
import unittest
from validator import validate, RADIUS, GUARD, BODY_RADIUS

SCENE = {
 'frame':'authored-xz-m','revision':'fixture-v1','units':'metres','captured_at':100.,'max_age_seconds':10.,
 'source_kind':'authored_fixture','coverage':[[-5,-5],[5,-5],[5,5],[-5,5]],
 'projection':{layer:{'source':'authored test geometry, not real room geometry','frame':'authored-xz-m',
  'revision':'fixture-v1','coverage':'complete','height_interval_metres':interval}
  for layer,interval in [('floor',[0,0]),('body',[0,1.6]),('head',[1.6,1.75])]},
 'obstacles':[{'id':'authored-table','layer':'body','source_kind':'authored_fixture','polygon':[[0,0],[1,0],[1,1],[0,1]]}]
}
def route(points): return {'points':points,'frame':'authored-xz-m','revision':'fixture-v1'}
def run(points,scene=None): return validate(route(points),scene or copy.deepcopy(SCENE),105.)

class Tests(unittest.TestCase):
 def test_crossing_pinpoints_segment(self):
  r=run([[-2,.5],[-1,.5],[2,.5]])
  self.assertEqual(r['status'],'rejected'); self.assertFalse(r['segments'][0]['contacts']); self.assertEqual(r['segments'][1]['contacts'][0]['obstacle_id'],'authored-table')
 def test_centerline_clear_body_collides(self): self.assertEqual(run([[-2,-.1],[2,-.1]])['status'],'rejected')
 def test_body_clear_margin_collides(self): self.assertEqual(run([[-2,-BODY_RADIUS-.05],[2,-BODY_RADIUS-.05]])['status'],'rejected')
 def test_exact_margin_contact(self): self.assertEqual(run([[-2,-RADIUS],[2,-RADIUS]])['status'],'rejected')
 def test_guard_conservative(self): self.assertEqual(run([[-2,-RADIUS-GUARD/2],[2,-RADIUS-GUARD/2]])['status'],'rejected')
 def test_beyond_guard(self): self.assertEqual(run([[-2,-RADIUS-2*GUARD],[2,-RADIUS-2*GUARD]])['status'],'clear_in_authored_fixture_only')
 def test_obstacle_boundary(self): self.assertEqual(run([[-2,0],[2,0]])['status'],'rejected')
 def test_corner_grazing(self):
  a=RADIUS/(2**.5)
  self.assertEqual(run([[-a,-a],[-a,-a]])['status'],'rejected')
 def test_authored_detour(self):
  r=run([[-2,.5],[-2,-1],[2,-1],[2,.5]])
  self.assertEqual(r['status'],'clear_in_authored_fixture_only'); self.assertFalse(r['live_guidance_allowed'])
 def test_endpoint_inside(self): self.assertEqual(run([[-2,.5],[.5,.5]])['status'],'rejected')
 def test_coverage_edge_body(self): self.assertEqual(run([[-4.8,-3],[-4.8,3]])['status'],'unknown')
 def test_outside_coverage(self): self.assertEqual(run([[-6,-3],[-6,3]])['status'],'unknown')
 def test_stale(self):
  s=copy.deepcopy(SCENE); s['captured_at']=80
  self.assertEqual(run([[-2,-1],[2,-1]],s)['status'],'unknown')
 def test_future(self):
  s=copy.deepcopy(SCENE); s['captured_at']=110
  self.assertEqual(run([[-2,-1],[2,-1]],s)['status'],'unknown')
 def test_frame_revision(self):
  for key in ['frame','revision']:
   r=route([[-2,-1],[2,-1]]); r[key]='wrong'; self.assertEqual(validate(r,SCENE,105)['status'],'unknown')
 def test_missing_layer(self):
  for layer in ['floor','body','head']:
   s=copy.deepcopy(SCENE); del s['projection'][layer]
   self.assertEqual(run([[-2,-1],[2,-1]],s)['status'],'unknown')
 def test_projection_mismatch(self):
  s=copy.deepcopy(SCENE); s['projection']['head']['revision']='wrong'
  self.assertEqual(run([[-2,-1],[2,-1]],s)['status'],'unknown')
 def test_manual_diagnostic_never_clear(self):
  s=copy.deepcopy(SCENE); s['source_kind']='MANUAL_DIAGNOSTIC_NOT_MEASURED'; s['obstacles'][0]['source_kind']='MANUAL_DIAGNOSTIC_NOT_MEASURED'
  self.assertEqual(run([[-2,-1],[2,-1]],s)['status'],'unknown')
  self.assertEqual(run([[-2,.5],[2,.5]],s)['status'],'rejected')
 def test_head_obstacle(self):
  s=copy.deepcopy(SCENE); s['obstacles'][0]['layer']='head'
  self.assertEqual(run([[-2,.5],[2,.5]],s)['status'],'rejected')
 def test_invalid_polygon(self):
  s=copy.deepcopy(SCENE); s['obstacles'][0]['polygon']=[[0,0],[1,1],[0,1],[1,0]]
  self.assertEqual(run([[-2,-1],[2,-1]],s)['status'],'unknown')
 def test_bad_points(self):
  for p in [[],[[0,0]],[[float('nan'),0],[1,1]],[[0,0,0],[1,1]],[[True,0],[1,1]]]:
   self.assertEqual(run(p)['status'],'unknown')
 def test_height_profile(self): self.assertEqual(run([[-2,-1],[2,-1]])['profile']['height'],1.6)

if __name__=='__main__': unittest.main(verbosity=2)
