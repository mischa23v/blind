import importlib.util
import pathlib
import unittest
import numpy as np
spec = importlib.util.spec_from_file_location('aggregation', pathlib.Path(__file__).with_name('aggregation_experiment.py'))
import sys
sys.path.insert(0, str(pathlib.Path(spec.origin).parent))
a = importlib.util.module_from_spec(spec); spec.loader.exec_module(a)

class Cosine:
    def match(self, x, y, mode):
        return float(np.dot(a.normalize(x).reshape(-1), a.normalize(y).reshape(-1)))

class Tests(unittest.TestCase):
    def test_equal_probes_and_no_leakage(self):
        expected = None
        for method in a.METHODS:
            enroll, probes = a.split(method)
            self.assertFalse(enroll.intersection(probes))
            self.assertEqual(len(probes), 340)
            self.assertEqual(sum(int(k.split('/')[0][1:]) <= 20 for k in probes), 140)
            if expected is not None: self.assertEqual(probes, expected)
            expected = probes
    def test_invalid_normalization(self):
        for value in ([0, 0], [np.nan, 1], [np.inf, 1]):
            with self.assertRaises(ValueError): a.normalize(value)
    def test_threshold_and_margin(self):
        self.assertEqual(a.decide([(1,.6),(2,.55)],.5,.1)[1], 'runner_up')
        self.assertEqual(a.decide([(1,.4)],.5,.1)[1], 'below_threshold')
        self.assertEqual(a.decide([], .5,.1)[1], 'empty_gallery')
        self.assertEqual(a.decide([(1,.6),(2,.2)],.5,.1)[0], 1)
    def test_failures_keep_denominators(self):
        row = a.evaluate(Cosine(), {}, {}, 'single', .363, .1)
        self.assertEqual(row['summary']['knownAbstain'],140)
        self.assertEqual(row['summary']['unknownAbstain'],200)
        self.assertEqual(row['summary']['probeTotal'],340)
    def test_runner_up_is_identity_not_template(self):
        features = {f's1/{j}.pgm': np.array([[1.,0.]],dtype=np.float32) for j in (1,2,3,4)}
        features['s2/1.pgm'] = np.array([[0.,1.]],dtype=np.float32)
        for method in ('max3','mean3'):
            row = a.evaluate(Cosine(), features, {}, method, .363,.1)
            self.assertEqual(row['results'][0]['candidate'],1)
    def test_quality_gate_does_not_drop_probe(self):
        features = {k: np.array([[1.,0.]],dtype=np.float32) for k in ('s1/1.pgm','s1/4.pgm')}
        obs = {'s1/1.pgm': {'geometryPass':True}, 's1/4.pgm': {'geometryPass':False}}
        row = a.evaluate(Cosine(),features,obs,'single',.363,.1,geometry=True)
        self.assertEqual(row['summary']['probeTotal'],340)
        self.assertEqual(row['results'][0]['reason'],'geometry_gate')
    def test_normalized_mean_is_unit(self):
        self.assertAlmostEqual(float(np.linalg.norm(a.normalize(np.mean([a.normalize([1,0]),a.normalize([0,1])],axis=0)))),1.,places=6)

if __name__ == '__main__': unittest.main(verbosity=2)
