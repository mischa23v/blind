"""Stdlib synthetic accounting checks, not physical geometry validation."""
import importlib.util, pathlib, unittest
H=pathlib.Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('height_recount',H/'recount_heights.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class HeightBandTests(unittest.TestCase):
    def test_declared_closed_bands_and_retained_straddles(self):
        self.assertEqual(m.classify(-.025,.025),('nearFoot25mm',False,False))
        self.assertEqual(m.classify(.5,.8),('whollyAtLeast0_5m',False,False))
        self.assertEqual(m.classify(-.1,.8),('other',True,True))
        self.assertEqual(m.classify(.026,.49),('other',False,False))
    def test_mixed_hits_not_promoted_by_low_first_witness(self):
        a=m.new_arm();m.accumulate(a,[0,1],{'a':[0,0,0],'b':[0,0,0]},[[0,.01],[.8,.9]])
        s=m.finish_arm(a)
        for r in s['references'].values():
            self.assertEqual(r['events']['allHitsNearFoot'],0)
            self.assertEqual(r['events']['anyNotNearFoot'],1)
            self.assertEqual(r['occurrences']['nearFoot25mm'],1)
            self.assertEqual(r['occurrences']['whollyAtLeast0_5m'],1)
    def test_start_end_references_and_empty_events_separate(self):
        a=m.new_arm();event={'a':[0,0,0],'b':[0,.03,0]}
        m.accumulate(a,[0],event,[[0,.02]]);m.accumulate(a,[],event,[[0,.02]])
        s=m.finish_arm(a)
        self.assertEqual(s['references']['startFoot']['events']['allHitsNearFoot'],1)
        self.assertEqual(s['references']['endFoot']['events']['anyNotNearFoot'],1)
        self.assertEqual(s['references']['startFoot']['events']['noContact'],1)
        self.assertEqual(s['eventsAllHitsNearBothFootReferences'],0)
    def test_unique_ids_not_repeated_occurrences(self):
        a=m.new_arm();event={'a':[0,0,0],'b':[0,0,0]}
        for _ in range(3):m.accumulate(a,[0],event,[[0,.01]])
        s=m.finish_arm(a);self.assertEqual(s['uniqueIDs'],[0]);self.assertEqual(s['hitOccurrences'],3)
        self.assertEqual(s['uniqueFaceCount'],1)
if __name__=='__main__':unittest.main(verbosity=2)
