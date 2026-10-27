"""Offline supplied-pose evaluator; no pose estimation or navigation authority."""
import ctypes
import math

IDENTITY = ('map_id', 'revision', 'frame_id', 'floor_id', 'session_id', 'clock_id')

def number(value):
    try:
        return type(value) in (float, int) and math.isfinite(value)
    except OverflowError:
        return False

def vector(value):
    return isinstance(value, (list, tuple)) and len(value) == 3 and all(number(x) and abs(x) <= 1000 for x in value)

class DetourMetrics:
    def __init__(self, library):
        self.library = ctypes.CDLL(str(library))
        self.call = self.library.diagnostic_segment
        self.call.argtypes = [ctypes.POINTER(ctypes.c_float)] * 4 + [ctypes.POINTER(ctypes.c_double)]
        self.call.restype = ctypes.c_int

    def segment(self, point, start, end, camera):
        magnitude = math.hypot(*camera)
        normalized = [x / magnitude for x in camera] if magnitude else camera
        arrays = [(ctypes.c_float * 3)(*v) for v in (point, start, end, normalized)]
        out = (ctypes.c_double * 6)()
        if self.call(*arrays, out) != 1:
            return None
        return tuple(out)

    def evaluate(self, route, pose, selected_segment, *, now, maximum_age, association_radius):
        """All evidence is supplied; status is diagnostic association, never clearance."""
        result = {'status': 'invalid_input', 'authorizes_physical_guidance': False,
                  'body_heading': None, 'geometry_representation': 'upstream_float32', 'metrics': None, 'conflicting_segments': []}
        if not isinstance(route, dict) or not isinstance(pose, dict):
            return result
        if not all(isinstance(route.get(k), str) and route[k] for k in IDENTITY):
            result['status'] = 'invalid_route_identity'; return result
        if any(pose.get(k) != route[k] for k in IDENTITY):
            result['status'] = 'identity_mismatch'; return result
        if route.get('units') != 'm' or pose.get('units') != 'm':
            result['status'] = 'units_mismatch'; return result
        if not isinstance(pose.get('source'), str) or not pose['source']:
            result['status'] = 'missing_pose_provenance'; return result
        captured = pose.get('captured_at')
        if not all(number(x) for x in (now, captured, maximum_age, association_radius)) or min(now, captured) < 0 or maximum_age <= 0 or association_radius < 0 or association_radius > 1000:
            result['status'] = 'invalid_policy_or_time'; return result
        if now < captured:
            result['status'] = 'future_pose'; return result
        if now - captured > maximum_age:
            result['status'] = 'stale_pose'; return result
        points = route.get('points')
        if not isinstance(points, (list, tuple)) or not 2 <= len(points) <= 256 or not all(vector(p) for p in points):
            result['status'] = 'invalid_route_geometry'; return result
        if any(abs(p[1] - points[0][1]) > 1e-6 for p in points):
            result['status'] = 'nonplanar_route'; return result
        if type(selected_segment) is not int or not 0 <= selected_segment < len(points) - 1:
            result['status'] = 'invalid_selected_segment'; return result
        if not vector(pose.get('position')) or not vector(pose.get('camera_forward')):
            result['status'] = 'invalid_pose_geometry'; return result
        if any(math.hypot(b[0]-a[0],b[2]-a[2]) < .001 for a,b in zip(points,points[1:])):
            result['status'] = 'degenerate_segment'; return result
        values = [self.segment(pose['position'], a, b, pose['camera_forward']) for a,b in zip(points, points[1:])]
        if any(v is None or not all(math.isfinite(x) for x in v[:5]) for v in values):
            result['status'] = 'degenerate_segment'; return result
        selected = values[selected_segment]
        result.update({'selected_segment': selected_segment, 'pose_source': pose['source'],
                       'capture_age_seconds': now - captured, 'association_radius_m': association_radius})
        conflicts = [i for i,v in enumerate(values) if i != selected_segment and math.sqrt(max(0,v[0])) <= association_radius]
        result['conflicting_segments'] = conflicts
        if not 0 <= selected[2] <= 1:
            result['status'] = 'beyond_segment'; return result
        if math.sqrt(max(0, selected[0])) > association_radius:
            result['status'] = 'outside_association_radius'; return result
        if conflicts:
            result['status'] = 'ambiguous_segment'; result['conflicting_segments'] = conflicts; return result
        result['status'] = 'computed_supplied_pose'
        result['metrics'] = {
            'signed_cross_track_m': selected[3],
            'along_path_m': sum(v[4] for v in values[:selected_segment]) + selected[2] * selected[4],
            'segment_fraction_unclamped': selected[2],
            'distance_to_selected_segment_m': math.sqrt(max(0, selected[0])),
            'camera_heading_error_rad': selected[5] if math.isfinite(selected[5]) else None,
        }
        return result
