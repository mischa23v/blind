"""Fresh reconstructed provenance/geometry checks; no real banknote images."""
import hashlib
from pathlib import Path
import tempfile
import unittest
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
    def test_provenance_and_nooverwrite(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);src=root/'s.png';out=root/'p.png';rm.cv2.imwrite(str(src),np.zeros((100,100),np.uint8));before=src.read_bytes()
            r=p.prepare(src,out,[[10,10],[90,10],[90,90],[10,90]],'assistant','assistant_visual_review');self.assertEqual(r['source_sha256'],hashlib.sha256(before).hexdigest());self.assertEqual(src.read_bytes(),before);self.assertFalse(r['independent_test_sample']);self.assertTrue(Path(str(out)+'.provenance.json').exists())
            with self.assertRaises(rm.InputError):p.prepare(src,out,[[10,10],[90,10],[90,90],[10,90]],'assistant','assistant_visual_review')
    def test_unknown_review_rejected(self):
        with self.assertRaises(rm.InputError):p.prepare(Path('none'),Path('none.png'),[],'reviewer','unreviewed')
if __name__=='__main__':unittest.main()
