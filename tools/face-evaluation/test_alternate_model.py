import unittest
from alternate_model import decide, summarize, distribution

class AlternateAccountingTests(unittest.TestCase):
 def test_empty_abstains(self): self.assertIsNone(decide([], .363, .1))
 def test_margin_abstains(self): self.assertIsNone(decide([(1,.8),(2,.75)],.363,.1))
 def test_reject_below_threshold(self): self.assertIsNone(decide([(1,.3),(2,.1)],.363,.1))
 def test_known_unknown_denominators(self):
  rows=[{'image':'a','identity':1,'known':True},{'image':'b','identity':21,'known':False}]
  out=summarize(rows,[1,1]);self.assertEqual(out['knownCorrect']['numerator'],1);self.assertEqual(out['unknownFalseIdentification']['denominator'],1);self.assertEqual(out['unknownIdentitiesWithAnyFalseIdentification']['numerator'],1)
 def test_empty_distribution(self):self.assertEqual(distribution([]),{'count':0})
 def test_distribution(self):self.assertEqual(distribution([0,1])['quantiles']['median'],.5)
if __name__=='__main__':unittest.main()
