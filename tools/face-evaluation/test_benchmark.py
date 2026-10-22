import unittest
from benchmark import decision, interval, metric

class BenchmarkAccountingTests(unittest.TestCase):
    def test_empty_interval(self): self.assertIsNone(interval(0,0))
    def test_zero_not_certain(self):
        low,high=interval(0,20);self.assertEqual(low,0);self.assertGreater(high,.16)
    def test_one_cluster(self):
        low,high=interval(1,20);self.assertLess(low,.05);self.assertGreater(high,.23)
    def test_empty_gallery(self): self.assertEqual(decision([]),(None,'empty_gallery'))
    def test_below_threshold(self): self.assertEqual(decision([(1,.362),(2,.1)]),(None,'below_threshold'))
    def test_margin(self): self.assertEqual(decision([(1,.8),(2,.75)]),(None,'runner_up'))
    def test_candidate(self): self.assertEqual(decision([(1,.8),(2,.2)]),(1,'experimental_candidate'))
    def test_denominator_preserved(self):
        self.assertEqual(metric(7,200)['fraction'],.035)
        self.assertIsNone(metric(0,0)['fraction'])
if __name__=='__main__':unittest.main()
