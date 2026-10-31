import importlib.util,pathlib,unittest
p=pathlib.Path(__file__).with_name('evaluate.py');s=importlib.util.spec_from_file_location('self_diag',p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
class SupportTests(unittest.TestCase):
 def test_all_eight_masks(self):
  r=m.support_summary(list(range(8)),1);self.assertEqual(r['total'],8);self.assertEqual(r['selfViewOccupied'],4);self.assertEqual(r['otherViewOnlyOccupied'],3);self.assertEqual(r['noSingleViewOccupied'],1)
 def test_partition(self):
  r=m.support_summary([0,1,2,2,5,7],0);self.assertEqual(r['selfViewOccupied']+r['otherViewOnlyOccupied']+r['noSingleViewOccupied'],r['total']);self.assertEqual(sum(r['occupiedBySingleViewMask'].values()),6)
 def test_empty(self):self.assertEqual(m.support_summary([],2)['total'],0)
 def test_invalid(self):
  with self.assertRaises(ValueError):m.support_summary([8],0)
if __name__=='__main__':unittest.main(verbosity=2)
