import unittest
import numpy as np
from diagnose_clearance_conservatism import square_distances

class GeometryDiagnosticTests(unittest.TestCase):
    def test_axis_diagonal_inside_and_boundary(self):
        d=square_distances([[0,0],[.5,0],[1,0],[1,1]],[[0,0]],1)
        np.testing.assert_allclose(d,[0,0,.5,np.sqrt(.5)])
    def test_tree_bounds_match_exhaustive_uniform_square_distance(self):
        rng=np.random.default_rng(271828)
        boxes=rng.uniform(-2,2,(100,2));points=rng.uniform(-3,3,(30,2))
        delta=np.maximum(np.abs(points[:,None,:]-boxes[None,:,:])-.025,0)
        expected=np.hypot(delta[:,:,0],delta[:,:,1]).min(axis=1)
        np.testing.assert_allclose(square_distances(points,boxes,.05),expected,rtol=0,atol=1e-14)
    def test_nearest_centre_need_not_mean_nearest_box(self):
        boxes=[[.51,0],[.37,.37]];p=[[0,0]]
        d=square_distances(p,boxes,.1)
        self.assertLess(d[0],.46)
    def test_bad_input_rejected(self):
        with self.assertRaises(ValueError):square_distances([[0,0]],[],.05)
        with self.assertRaises(ValueError):square_distances([[float('nan'),0]],[[0,0]],.05)

if __name__=='__main__':unittest.main(verbosity=2)
