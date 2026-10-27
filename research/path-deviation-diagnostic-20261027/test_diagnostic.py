import copy
import json
import math
import os
import unittest
from diagnostic import DetourMetrics

class DiagnosticTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.backend = DetourMetrics(os.environ['DIAGNOSTIC_LIBRARY'])

    def setUp(self):
        self.route = {k: k + '-fixture' for k in ('map_id','revision','frame_id','floor_id','session_id','clock_id')}
        self.route.update(units='m', points=[[0,0,0],[10,0,0]])
        self.pose = {k:v for k,v in self.route.items() if k != 'points'}
        self.pose.update(source='synthetic analytic fixture, not sensor', captured_at=10., position=[5,0,-.25], camera_forward=[1,0,0])
        self.policy = dict(now=10.25, maximum_age=.5, association_radius=.5)
        self.segment = 0

    def assess(self): return self.backend.evaluate(self.route,self.pose,self.segment,**self.policy)
    def metric(self,name):
        r=self.assess(); self.assertEqual(r['status'],'computed_supplied_pose'); return r['metrics'][name]
    def status(self,expected):
        r=self.assess(); self.assertEqual(r['status'],expected); self.assertFalse(r['authorizes_physical_guidance']); self.assertIsNone(r['body_heading']); self.assertIsNone(r['metrics'])

    def test_left(self): self.assertAlmostEqual(self.metric('signed_cross_track_m'),.25)
    def test_right(self): self.pose['position'][2]=.25; self.assertAlmostEqual(self.metric('signed_cross_track_m'),-.25)
    def test_center(self): self.pose['position'][2]=0; self.assertEqual(self.metric('signed_cross_track_m'),0)
    def test_reverse_flips_sign(self): self.route['points'].reverse(); self.assertAlmostEqual(self.metric('signed_cross_track_m'),-.25)
    def test_progress(self): self.assertAlmostEqual(self.metric('along_path_m'),5)
    def test_left_heading(self): self.pose['camera_forward']=[0,0,-1]; self.assertAlmostEqual(self.metric('camera_heading_error_rad'),math.pi/2)
    def test_right_heading(self): self.pose['camera_forward']=[0,0,1]; self.assertAlmostEqual(self.metric('camera_heading_error_rad'),-math.pi/2)
    def test_opposite_wrap(self): self.pose['camera_forward']=[-1,0,0]; self.assertAlmostEqual(self.metric('camera_heading_error_rad'),-math.pi)
    def test_wrap_near_positive_pi(self): self.pose['camera_forward']=[-1,0,-.001]; self.assertGreater(self.metric('camera_heading_error_rad'),3.14)
    def test_wrap_near_negative_pi(self): self.pose['camera_forward']=[-1,0,.001]; self.assertLess(self.metric('camera_heading_error_rad'),-3.14)
    def test_north_left_is_west(self): self.route['points']=[[0,0,0],[0,0,-10]]; self.pose['position']=[-.25,0,-5]; self.pose['camera_forward']=[0,0,-1]; self.assertAlmostEqual(self.metric('signed_cross_track_m'),.25); self.assertAlmostEqual(self.metric('camera_heading_error_rad'),0)
    def test_south_left_is_east(self): self.route['points']=[[0,0,0],[0,0,10]]; self.pose['position']=[.25,0,5]; self.pose['camera_forward']=[0,0,1]; self.assertAlmostEqual(self.metric('signed_cross_track_m'),.25)
    def test_turn_cumulative(self): self.route['points'].append([10,0,-10]); self.segment=1; self.pose['position']=[9.75,0,-5]; self.assertAlmostEqual(self.metric('along_path_m'),15)
    def test_turn_vertex_ambiguous(self): self.route['points'].append([10,0,-10]); self.pose['position']=[10,0,0]; self.status('ambiguous_segment')
    def test_repeated_reverse_segment(self): self.route['points'].append([0,0,0]); self.status('ambiguous_segment')
    def test_crossing(self): self.route['points']=[[-5,0,0],[5,0,0],[0,0,-5],[0,0,5]]; self.pose['position']=[0,0,0]; self.status('ambiguous_segment'); self.assertIn(2,self.assess()['conflicting_segments'])
    def test_parallel_nearby_ambiguous(self): self.route['points']=[[0,0,0],[10,0,0],[10,0,-.4],[0,0,-.4]]; self.status('ambiguous_segment')
    def test_parallel_far_does_not_jump(self): self.route['points']=[[0,0,0],[10,0,0],[10,0,-2],[0,0,-2]]; self.assertAlmostEqual(self.metric('along_path_m'),5)
    def test_before_not_clamped(self): self.pose['position'][0]=-1; self.status('beyond_segment')
    def test_after_not_clamped(self): self.pose['position'][0]=11; self.status('beyond_segment')
    def test_outside_radius(self): self.pose['position'][2]=-2; self.status('outside_association_radius')
    def test_exact_radius_boundary(self): self.pose['position'][2]=-.5; self.assertAlmostEqual(self.metric('signed_cross_track_m'),.5)
    def test_zero_radius_center(self): self.pose['position'][2]=0; self.policy['association_radius']=0; self.assertEqual(self.metric('signed_cross_track_m'),0)
    def test_stale(self): self.policy['now']=10.501; self.status('stale_pose')
    def test_exact_age_boundary(self): self.policy['now']=10.5; self.assertEqual(self.metric('along_path_m'),5)
    def test_future(self): self.policy['now']=9; self.status('future_pose')
    def test_negative_time(self): self.pose['captured_at']=-1; self.status('invalid_policy_or_time')
    def test_nonfinite_time(self): self.policy['now']=math.inf; self.status('invalid_policy_or_time')
    def test_bool_age(self): self.policy['maximum_age']=True; self.status('invalid_policy_or_time')
    def test_negative_radius(self): self.policy['association_radius']=-1; self.status('invalid_policy_or_time')
    def test_huge_integer(self): self.pose['position'][0]=10**1000; self.status('invalid_pose_geometry')
    def test_nonfinite_pose(self): self.pose['position'][0]=math.nan; self.status('invalid_pose_geometry')
    def test_nonfinite_camera(self): self.pose['camera_forward'][0]=math.inf; self.status('invalid_pose_geometry')
    def test_zero_camera_heading_unavailable(self): self.pose['camera_forward']=[0,0,0]; self.assertIsNone(self.metric('camera_heading_error_rad'))
    def test_vertical_camera_heading_unavailable(self): self.pose['camera_forward']=[0,1,0]; self.assertIsNone(self.metric('camera_heading_error_rad'))
    def test_nearly_vertical_camera(self): self.pose['camera_forward']=[.0001,1,0]; self.assertIsNone(self.metric('camera_heading_error_rad'))
    def test_degenerate_segment(self): self.route['points'][1]=[0,0,0]; self.status('degenerate_segment')
    def test_too_short_segment(self): self.route['points'][1]=[.0005,0,0]; self.status('degenerate_segment')
    def test_vertical_segment(self): self.route['points'][1]=[0,1,0]; self.status('nonplanar_route')
    def test_sloped_segment(self): self.route['points'][1]=[10,1,0]; self.status('nonplanar_route')
    def test_large_coordinate_bound(self): self.pose['position'][0]=1001; self.status('invalid_pose_geometry')
    def test_float_quantization_recorded(self): self.route['points']=[[990,0,990],[1000,0,990]]; self.pose['position']=[995,0,989.75]; self.assertAlmostEqual(self.metric('signed_cross_track_m'),.25)
    def test_nonrepresentable_large_coordinate(self):
        self.route['points']=[[990,0,990],[1000,0,990]]; self.pose['position']=[995,0,989.74999]
        actual=self.metric('signed_cross_track_m'); self.assertNotEqual(actual,990-self.pose['position'][2]); self.assertAlmostEqual(actual,.25)
        self.assertEqual(self.assess()['geometry_representation'],'upstream_float32')
    def test_boolean_segment_invalid(self): self.segment=True; self.status('invalid_selected_segment')
    def test_segment_not_in_range(self): self.segment=1; self.status('invalid_selected_segment')
    def test_provenance_required(self): del self.pose['source']; self.status('missing_pose_provenance')
    def test_units(self): self.pose['units']='cm'; self.status('units_mismatch')
    def test_nonrepresentable_radius_boundary_explicit(self): self.pose['position'][2]=-.1; self.policy['association_radius']=.1; self.status('outside_association_radius')
    def test_tiny_camera_direction_normalized(self): self.pose['camera_forward']=[1e-300,0,0]; self.assertEqual(self.metric('camera_heading_error_rad'),0)
    def test_supplied_submillimetre_rejected_before_quantization(self): self.route['points']=[[990.000026,0,0],[990.001025,0,0]]; self.status('degenerate_segment')
    def test_other_segment_retained_when_outside_selected(self):
        self.route['points']=[[0,0,0],[10,0,0],[10,0,-2],[0,0,-2]]; self.pose['position']=[5,0,-2]
        self.status('outside_association_radius'); self.assertEqual(self.assess()['conflicting_segments'],[2])
    def test_other_segment_retained_when_beyond_selected(self):
        self.route['points']=[[0,0,0],[10,0,0],[15,0,0]]; self.pose['position']=[12,0,0]
        self.status('beyond_segment'); self.assertEqual(self.assess()['conflicting_segments'],[1])
    def test_nonmutation_and_no_authority(self):
        before=copy.deepcopy((self.route,self.pose,self.policy)); r=self.assess(); self.assertEqual(before,(self.route,self.pose,self.policy)); self.assertFalse(r['authorizes_physical_guidance']); self.assertIsNone(r['body_heading']); json.dumps(r,allow_nan=False)
    def test_empty_route(self): self.route['points']=[]; self.status('invalid_route_geometry')
    def test_oversized_route(self): self.route['points']=[[i,0,0] for i in range(257)]; self.status('invalid_route_geometry')
    def test_unknown_body_input_ignored(self): self.pose['body_heading']={'claimed':True}; self.assertIsNone(self.assess()['body_heading'])

for key in ('map_id','revision','frame_id','floor_id','session_id','clock_id'):
    def mismatch(self, k=key): self.pose[k]='different'; self.status('identity_mismatch')
    setattr(DiagnosticTests,'test_mismatch_'+key,mismatch)

if __name__=='__main__': unittest.main(verbosity=2)
