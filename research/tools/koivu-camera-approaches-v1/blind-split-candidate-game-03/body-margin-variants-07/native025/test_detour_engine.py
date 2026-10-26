"""Bounded native adapter checks; these are not journey or human safety tests."""
import unittest
import numpy as np
from detour_engine import Engine,Config

def floor(x0=0,x1=12,z0=0,z1=8,y=0):
    return ([[x0,y,z0],[x1,y,z0],[x1,y,z1],[x0,y,z1]],[[0,3,2],[0,2,1]])
def box(x0,x1,y0,y1,z0,z1):
    v=[[x0,y0,z0],[x1,y0,z0],[x1,y0,z1],[x0,y0,z1],[x0,y1,z0],[x1,y1,z0],[x1,y1,z1],[x0,y1,z1]]
    t=[[0,1,2],[0,2,3],[4,7,6],[4,6,5],[0,4,5],[0,5,1],[1,5,6],[1,6,2],[2,6,7],[2,7,3],[3,7,4],[3,4,0]]
    return v,t
def join(*meshes):
    v=[];t=[]
    for vv,tt in meshes:
        n=len(v);v.extend(vv);t.extend([[i+n for i in tri] for tri in tt])
    return v,t

class NativeEngineTests(unittest.TestCase):
    def test_flat_route_complete_and_inputs_not_projected_in_place(self):
        a=np.array([2.,0.,4.],np.float32);b=np.array([10.,0.,4.],np.float32);before=a.copy()
        with Engine(*floor()) as e:
            r=e.route(a,b)
            self.assertTrue(r.complete,r)
            self.assertGreaterEqual(len(r.points),2)
            self.assertTrue(np.array_equal(a,before))
            self.assertLess(np.linalg.norm(np.array(r.projected_start)[[0,2]]-a[[0,2]]),.01)
    def test_box_detour_is_real_upstream_route(self):
        with Engine(*join(floor(),box(5,7,0,2,3,5))) as e:
            r=e.route([2,0,4],[10,0,4]);self.assertTrue(r.complete,r)
            self.assertGreaterEqual(len(r.points),4)
            # Independent conservative 2D point samples ensure no box-body contact.
            for a,b in zip(r.points,r.points[1:]):
                for t in np.linspace(0,1,301):
                    p=np.array(a)*(1-t)+np.array(b)*t
                    d=np.hypot(max(5-p[0],0,p[0]-7),max(3-p[2],0,p[2]-5))
                    self.assertGreaterEqual(d,.5204-1e-4)
    def test_disconnected_floor_unknown_is_not_bridged(self):
        with Engine(*join(floor(0,4,0,8),floor(6,12,0,8)),mode='progressively-observed-map') as e:
            r=e.route([2,0,4],[10,0,4]);self.assertFalse(r.complete,r)
    def test_wall_yields_partial_not_success(self):
        with Engine(*join(floor(),box(5.9,6.1,0,2.6,0,8))) as e:
            r=e.route([2,0,4],[10,0,4]);self.assertFalse(r.complete,r)
    def test_head_clearance_not_just_floor_membership(self):
        with Engine(*join(floor(),box(5,7,1.2,1.4,0,8))) as e:
            r=e.route([2,0,4],[10,0,4]);self.assertFalse(r.complete,r)
    def test_body_width_closes_tight_door(self):
        scene=join(floor(),box(5.9,6.1,0,2.6,0,3.4),box(5.9,6.1,0,2.6,4.6,8))
        with Engine(*scene,Config(radius=.2)) as e:self.assertTrue(e.route([2,0,4],[10,0,4]).complete)
        with Engine(*scene,Config(radius=.8)) as e:self.assertFalse(e.route([2,0,4],[10,0,4]).complete)
    def test_out_of_bounds_start_is_not_teleported(self):
        with Engine(*floor()) as e:
            r=e.route([-20,0,4],[10,0,4]);self.assertFalse(r.complete);self.assertEqual(r.points,());self.assertIsNotNone(r.error)
    def test_truncated_path_is_not_success(self):
        with Engine(*join(floor(),box(5,7,0,2,3,5))) as e:
            r=e.route([2,0,4],[10,0,4],max_points=2);self.assertFalse(r.complete)
    def test_invalid_inputs_rejected(self):
        v,t=floor();v[0][0]=float('nan')
        with self.assertRaises(ValueError):Engine(v,t)
        v,t=floor();t[0][0]=900
        with self.assertRaises(ValueError):Engine(v,t)
        with self.assertRaises(ValueError):Engine(*floor(),Config(radius=-1))
    def test_velocity_is_candidate_and_finite(self):
        with Engine(*floor()) as e:
            v,n=e.candidate_velocity([2,0,4],[0,0,0],[.5,0,0],circles=[[3,0,4,.3,-.2,0,0]])
            self.assertGreater(n,0);self.assertTrue(np.isfinite(v).all());self.assertLessEqual(np.linalg.norm(v),.50001)
    def test_floor_winding_is_not_silently_repaired(self):
        v,t=floor();t=[list(reversed(x)) for x in t]
        with self.assertRaises(ValueError):Engine(v,t)
    def test_closed_handle(self):
        e=Engine(*floor());e.close();e.close()
        with self.assertRaises(RuntimeError):e.route([2,0,4],[10,0,4])

if __name__=='__main__':unittest.main(verbosity=2)
