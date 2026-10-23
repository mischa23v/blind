"""Fresh reconstructed provenance/geometry checks; no real banknote images."""
import hashlib
from pathlib import Path
import tempfile
import unittest
from unittest import mock
import numpy as np
import prepare_reference as p
import reference_match as rm
@unittest.skipIf(rm.cv2 is None,'OpenCV unavailable; preparation tests not run')
class PreparationTests(unittest.TestCase):
    def test_rectify(self):
        im=np.arange(10000,dtype=np.uint8).reshape(100,100);out,h=p.rectify(im,[[10,10],[90,10],[90,90],[10,90]],80);self.assertEqual(out.shape,(80,80));self.assertEqual(h.shape,(3,3))
    def test_outside_rejected(self):
        with self.assertRaises(rm.InputError):p.rectify(np.zeros((100,100),np.uint8),[[-1,0],[90,0],[90,90],[0,90]])
    def test_crossed_rejected(self):
        with self.assertRaises(rm.InputError):p.rectify(np.zeros((100,100),np.uint8),[[0,0],[90,90],[90,0],[0,90]])
    def test_reversed_winding_rejected(self):
        with self.assertRaisesRegex(rm.InputError, 'positive-turn'):
            p.rectify(np.zeros((100,100),np.uint8),[[10,10],[10,90],[90,90],[90,10]])
    def test_mean_opposite_edges_matches_native_size_transform_and_pixels(self):
        gray=np.arange(120*200,dtype=np.uint8).reshape(120,200)
        quad=np.float32([[10,10],[170,10],[130,90],[30,90]])
        output, transform=p.rectify(gray,quad)
        # Native uses (160+100)/2 and (sqrt(80^2+40^2)+sqrt(80^2+20^2))/2.
        self.assertEqual(output.shape,(86,130))
        expected=rm.cv2.getPerspectiveTransform(quad,np.float32([[0,0],[129,0],[129,85],[0,85]]))
        np.testing.assert_array_equal(transform,expected)
        np.testing.assert_array_equal(output,rm.cv2.warpPerspective(gray,expected,(130,86),flags=rm.cv2.INTER_LINEAR))
    def test_default_native_max_side(self):
        output,_=p.rectify(np.zeros((1200,1600),np.uint8),[[100,100],[1500,100],[1500,1000],[100,1000]])
        self.assertEqual(output.shape,(514,800))
    def test_half_even_size_rounding_matches_native(self):
        for length,expected in [(32.5,32),(33.5,34)]:
            with self.subTest(length=length):
                output,_=p.rectify(np.zeros((64,64),np.uint8),[[5,5],[5+length,5],[5+length,45],[5,45]])
                self.assertEqual(output.shape,(40,expected))
    def test_edge_below_native_minimum_rejected(self):
        with self.assertRaisesRegex(rm.InputError, 'boundary'):
            p.rectify(np.zeros((100,100),np.uint8),[[10,10],[41.99,10],[41.99,90],[10,90]])
    def test_edge_at_native_minimum_accepted(self):
        output,_=p.rectify(np.zeros((100,100),np.uint8),[[10,10],[42,10],[42,90],[10,90]])
        self.assertEqual(output.shape,(80,32))
    def test_boundary_below_ten_percent_rejected(self):
        with self.assertRaisesRegex(rm.InputError, 'boundary'):
            p.rectify(np.zeros((100,200),np.uint8),[[10,10],[59.99,10],[59.99,50],[10,50]])
    def test_boundary_at_ten_percent_accepted(self):
        output,_=p.rectify(np.zeros((100,200),np.uint8),[[10,10],[60,10],[60,50],[10,50]])
        self.assertEqual(output.shape,(40,50))
    def test_opposite_edge_ratio_above_three_rejected_in_both_axes(self):
        quad=np.float32([[10,10],[42,10],[106.1,90],[10,90]])
        for corners in [quad,np.column_stack([120-quad[:,1],quad[:,0]])]:
            with self.subTest(corners=corners), self.assertRaisesRegex(rm.InputError, 'boundary'):
                p.rectify(np.zeros((130,130),np.uint8),corners)
    def test_opposite_edge_ratio_at_three_accepted(self):
        output,_=p.rectify(np.zeros((130,130),np.uint8),[[10,10],[42,10],[106,90],[10,90]])
        self.assertEqual(output.shape,(91,64))
    def test_invalid_native_image_contract_rejected(self):
        invalid=[np.zeros((100,100,3),np.uint8),np.zeros((100,100),np.uint16),
                 np.zeros((31,100),np.uint8),np.zeros((32,4097),np.uint8),np.zeros((3000,3000),np.uint8)]
        for gray in invalid:
            with self.subTest(shape=gray.shape,dtype=gray.dtype), self.assertRaisesRegex(rm.InputError, 'grayscale'):
                p.rectify(gray,[[10,10],[90,10],[90,90],[10,90]])
    def test_nonfinite_and_degenerate_transforms_rejected_before_warp(self):
        for transform in [np.zeros((3,3)),np.diag([1.,1.,1e-13]),np.full((3,3),np.nan),np.full((3,3),np.inf)]:
            with self.subTest(transform=transform), mock.patch.object(rm.cv2,'getPerspectiveTransform',return_value=transform), mock.patch.object(rm.cv2,'warpPerspective') as warp:
                with self.assertRaisesRegex(rm.InputError, 'transform'):
                    p.rectify(np.zeros((100,100),np.uint8),[[10,10],[90,10],[90,90],[10,90]])
                warp.assert_not_called()
    def test_nonfinite_corners_rejected(self):
        for value in [np.nan,np.inf,-np.inf]:
            with self.subTest(value=value), self.assertRaises(rm.InputError):
                p.rectify(np.zeros((100,100),np.uint8),[[value,10],[90,10],[90,90],[10,90]])
    def test_provenance_and_nooverwrite(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);src=root/'s.png';out=root/'p.png';rm.cv2.imwrite(str(src),np.zeros((100,100),np.uint8));before=src.read_bytes()
            r=p.prepare(src,out,[[10,10],[90,10],[90,90],[10,90]],'assistant','assistant_visual_review');self.assertEqual(r['source_sha256'],hashlib.sha256(before).hexdigest());self.assertEqual(src.read_bytes(),before);self.assertFalse(r['independent_test_sample']);self.assertTrue(Path(str(out)+'.provenance.json').exists())
            with self.assertRaises(rm.InputError):p.prepare(src,out,[[10,10],[90,10],[90,90],[10,90]],'assistant','assistant_visual_review')
    def test_unknown_review_rejected(self):
        with self.assertRaises(rm.InputError):p.prepare(Path('none'),Path('none.png'),[],'reviewer','unreviewed')
if __name__=='__main__':unittest.main()
