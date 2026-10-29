"""Prepared controls, NOT EXECUTED in this checkpoint. No native loads."""
import unittest
import numpy as np
import retention as subject

class ProjectionControls(unittest.TestCase):
    def setUp(self):
        self.k = dict(fl_x=2., fl_y=4., cx=100., cy=200.)
        self.depth = np.zeros((994,738), dtype=np.uint16)
    def test_original_intrinsics_no_axis_flip(self):
        self.depth[202,102] = 2000
        points, rows, cols = subject.project(self.depth, self.k)
        np.testing.assert_array_equal(points, [[2.,1.,2.]])
        np.testing.assert_array_equal(rows, [202])
        np.testing.assert_array_equal(cols, [102])
    def test_missing_zero_and_far_are_not_endpoints(self):
        self.depth[0,:5] = [0,1,3999,4000,65535]
        points, _, cols = subject.project(self.depth,self.k)
        self.assertEqual(len(points),2)
        np.testing.assert_array_equal(cols,[1,2])
    def test_full_raster_unselected_pixels_survive(self):
        self.depth[993,737] = 1000
        self.assertEqual(len(subject.project(self.depth,self.k)[0]),1)
    def test_original_shape_and_dtype_required(self):
        for raster in (self.depth.T,self.depth.astype(np.float32)):
            with self.assertRaises(ValueError): subject.project(raster,self.k)
    def test_intrinsic_invalid_rejected(self):
        for bad in (0.,-1.,float('nan')):
            with self.assertRaises(ValueError):
                subject.project(self.depth,dict(self.k,fl_x=bad))
    def test_semantic_evaluator_not_mapper_argument(self):
        import inspect
        self.assertEqual(tuple(inspect.signature(subject.project).parameters),('depth','k'))
    def test_patch_bounds_half_open(self):
        mask=subject.patch_mask(np.array([2,3,4]),np.array([1,2,3]),[1,2,3,4])
        np.testing.assert_array_equal(mask,[True,True,False])
    def test_empty_floor_evaluator_rejected(self):
        self.depth[0,0]=1000
        p,r,c=subject.project(self.depth,self.k)
        with self.assertRaises(ValueError):
            subject.diagnostic(p,r,c,{'tableInsetXYXY':[0,0,2,2],'nearbyFloorInsetXYXY':[10,10,12,12]})

if __name__ == '__main__': unittest.main()
