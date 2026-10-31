"""Six authored source-only scheduling/reporting contracts; not a native physics test."""
import copy,json,math,pathlib,unittest
from schedule_source import make_schedule
from route_progress import increment_progress
H=pathlib.Path(__file__).resolve().parent

class RouteSourceContractTests(unittest.TestCase):
    def setUp(self):
        self.freeze=json.loads((H/'ROUTE_FREEZE.json').read_text())
        self.path=json.loads((H/'SCHEDULE_0_8.json').read_text())['paths'][0]
    def test_exact_chain_and_both_connectors_not_replaced(self):
        chain=self.freeze['requestedConnectorChainXYZ']
        self.assertEqual(len(chain),144);self.assertEqual(chain[1:-1],self.freeze['sourceNativePoints'])
        self.assertEqual(self.path['chain'],chain);self.assertEqual(len(chain)-1,143)
    def test_generation_is_deterministic_and_input_immutable(self):
        chain=self.freeze['requestedConnectorChainXYZ'];before=copy.deepcopy(chain)
        self.assertEqual(make_schedule(chain),self.path);self.assertEqual(chain,before)
    def test_all143_segments_and_source_y_are_preserved(self):
        chain=self.path['chain'];events=self.path['events']
        for i,(a,b) in enumerate(zip(chain,chain[1:])):
            rows=[e for e in events if e['edge']==i and e['kind'] in ('translate','stationary')]
            self.assertTrue(rows);self.assertEqual(rows[0]['a'],a);self.assertEqual(rows[-1]['b'],b)
            for first,second in zip(rows,rows[1:]):self.assertEqual(first['b'],second['a'])
        self.assertEqual(events[0]['kind'],'initial');self.assertEqual(events[-1]['kind'],'terminal')
    def test_declared_increment_caps_and_exact_event_identity(self):
        events=self.path['events'];self.assertEqual(len(events),1644)
        self.assertEqual(sum(e['kind']=='translate' for e in events),377)
        self.assertEqual(sum(e['kind']=='turn' for e in events),1265)
        for e in events:
            self.assertLessEqual(math.dist(e['a'],e['b']),.025000001)
            self.assertLessEqual(abs(e['dyaw']),math.pi/180.+1e-12)
            if e['kind']=='turn':self.assertEqual(e['a'],e['b'])
            else:self.assertEqual(e['dyaw'],0.)
        for a,b in zip(events,events[1:]):
            self.assertEqual(a['b'],b['a'])
            self.assertLessEqual(abs((a['yaw']+a['dyaw']-b['yaw']+math.pi)%(2*math.pi)-math.pi),1e-12)

    def test_turn_height_is_separate_from_accepted_translation_progress(self):
        start=[0.,0.,0.];mid=[0.,.02,0.];end=[0.,.01,0.]
        turn=increment_progress('turn',start,mid,end,accepted=True)
        self.assertEqual(turn['translationIncrements'],0)
        self.assertEqual(turn['translation3DMetres'],0.);self.assertEqual(turn['translationXZMetres'],0.)
        self.assertAlmostEqual(turn['turnVerticalAdjustmentMetres'],.03)
        move=increment_progress('translate',start,[.01,0.,0.],[.02,0.,0.],accepted=True)
        self.assertEqual(move['translationIncrements'],1)
        self.assertAlmostEqual(move['translation3DMetres'],.02);self.assertAlmostEqual(move['translationXZMetres'],.02)
        self.assertEqual(move['turnVerticalAdjustmentMetres'],0.)
    def test_rejected_intervals_never_count_progress_or_vertical_adjustment(self):
        for kind in ('turn','translate'):
            result=increment_progress(kind,[0.,0.,0.],[.01,.02,0.],[.02,.01,0.],accepted=False)
            self.assertEqual(result,{'translationIncrements':0,'translation3DMetres':0.,
                                     'translationXZMetres':0.,'turnVerticalAdjustmentMetres':0.})

if __name__=='__main__':unittest.main(verbosity=2)
