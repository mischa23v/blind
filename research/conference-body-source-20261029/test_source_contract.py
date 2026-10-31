"""Lightweight stdlib controls; no VTK/planner imports or mesh execution."""
import copy, hashlib, json, math, pathlib, unittest
from contracts import NAMES, encoded, select_routes, check_schedule
from schedule_source import make_schedule
H=pathlib.Path(__file__).resolve().parent

class SourceContractTests(unittest.TestCase):
    def frozen(self):return json.loads((H/'ROUTES.json').read_text())
    def test_all_seven_ordered_routes_retained(self):
        frozen=self.frozen()
        self.assertEqual([p['name'] for p in frozen['paths']],NAMES)
        self.assertEqual([p['eventCount'] for p in frozen['paths']],[1844,2052,1530,1555,2863,1923,1937])
        self.assertEqual(frozen['totalEvents'],13704)
    def test_exact_endpoints_and_schedule_hashes(self):
        for row in self.frozen()['paths']:
            s=check_schedule(row)
            self.assertEqual(s['chain'][0],row['requestedStartXYZ'])
            self.assertEqual(s['chain'][-1],row['requestedGoalXYZ'])
            self.assertEqual(s['events'][0]['a'],row['requestedStartXYZ'])
            self.assertEqual(s['events'][-1]['b'],row['requestedGoalXYZ'])
            self.assertEqual(hashlib.sha256(encoded(row['chain'])).hexdigest(),row['chainSHA256'])
    def test_every_authored_increment_bounded_without_smoothing(self):
        for row in self.frozen()['paths']:
            events=check_schedule(row)['events']
            for event in events:
                self.assertLessEqual(math.dist(event['a'],event['b']),.025+1e-12)
                self.assertLessEqual(abs(event['dyaw']),math.pi/180+1e-12)
                if event['kind']=='turn':self.assertEqual(event['a'],event['b'])
            self.assertEqual({e['edge'] for e in events if e['kind']=='translate'},
                             {i for i,(a,b) in enumerate(zip(row['chain'],row['chain'][1:])) if a!=b})
    def test_small_vertical_connector_and_180_tie_preserved(self):
        s=make_schedule([[0,0,0],[0,1e-8,0],[.1,1e-8,0],[0,1e-8,0]])
        self.assertEqual(s['events'][1]['b'],[0,1e-8,0])
        turns=[e for e in s['events'] if e['kind']=='turn']
        self.assertEqual(len(turns),180)
        self.assertTrue(all(e['dyaw']>0 for e in turns))
    def test_unavailable_never_falls_back_to_baseline_or_distance_grid(self):
        p={'paths':[]}
        for name in NAMES:
            p['paths'].append({'name':name,'requestedStartXYZ':[0,0,0],'requestedGoalXYZ':[1,0,0],
              'sourcePoseIndices':[0,1],'gridStatus':'disconnected',
              'baselineRequestedConnectorChainXYZ':[[0,0,0],[1,0,0]],
              'gridSelection':{'distanceGrid':{'requestedConnectorChainXYZ':[[0,0,0],[1,0,0]]}}})
        frozen=select_routes(p)
        self.assertEqual(len(frozen['paths']),7);self.assertEqual(frozen['totalEvents'],0)
        self.assertTrue(all(r['status']=='unavailable' and r['chain'] is None for r in frozen['paths']))
    def test_changed_schedule_refused(self):
        row=copy.deepcopy(self.frozen()['paths'][0]);row['chain'][2][0]+=.0001
        with self.assertRaises(ValueError):check_schedule(row)

if __name__=='__main__':unittest.main(verbosity=2)
