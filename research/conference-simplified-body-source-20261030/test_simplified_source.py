"""Stdlib-only actual-chain and new-recorder fixtures; no geometry execution."""
import copy,importlib.util,json,math,pathlib,unittest
H=pathlib.Path(__file__).resolve().parent;R=H.parents[1];W=R.parent
def module(p,name):
    spec=importlib.util.spec_from_file_location(name,p);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
selection=module(H/'selection.py','simplified_selection');record=module(H/'query_recorder.py','query_recorder')
loader=module(R/'research/conference-body-postrun-source-20261030/run_aggregate_isolated.py','loader')
old=R/'research/conference-body-source-20261029';pins=json.loads((old/'SOURCE_PINS.json').read_text());prefix='research/conference-body-source-20261029/'
c=loader.load_frozen_contracts(old,pins['inputs'][prefix+'contracts.py'],pins['inputs'][prefix+'schedule_source.py'])
FROZEN=json.loads((H/'ROUTES.json').read_text());BASE=json.loads((H/'BASELINE.json').read_text())
def result(body=0,margin=0):
    return {k:{'nonGroundContactCount':n,'groundContactCount':0,'candidateTriangles':n,
               'contact':bool(n),'firstReferenceCellID':0 if n else None}for k,n in zip(('actualBody','horizontalMargin'),(body,margin))}
class SimplifiedSourceTests(unittest.TestCase):
    def test_all_seven_actual_candidates_freeze_exactly(self):
        pairs=json.loads((W/'conference-geos-simplification-attempt-001/comparison/PAIRS.json').read_text())
        baseline=json.loads((old/'ROUTES.json').read_text())
        self.assertEqual(selection.select_simplified(pairs,baseline,c.make_schedule),FROZEN)
        self.assertEqual(FROZEN['totalEvents'],7470)
    def test_frozen_endpoints_xyz_connectors_and_increment_caps(self):
        baseline=json.loads((old/'ROUTES.json').read_text())
        for row,original in zip(FROZEN['paths'],baseline['paths']):
            self.assertEqual(row['chain'][:3],original['chain'][:3]);self.assertEqual(row['chain'][-3:],original['chain'][-3:])
            schedule=c.check_schedule(row)
            for e in schedule['events']:
                self.assertLessEqual(math.dist(e['a'],e['b']),.025+1e-12)
                self.assertLessEqual(abs(e['dyaw']),math.pi/180+1e-12)
    def test_changed_connector_refused(self):
        pairs=json.loads((W/'conference-geos-simplification-attempt-001/comparison/PAIRS.json').read_text())
        pairs['paths'][0]['geos025CenteredCandidate']['chainXYZ'][0][1]+=.000001
        with self.assertRaises(ValueError):selection.select_simplified(pairs,json.loads((old/'ROUTES.json').read_text()),c.make_schedule)
    def test_new_query_counts_may_differ_from_old_event(self):
        r=record.BoundedQueryHitRecorder(FROZEN);name,n=r.sequence[0];r.begin_event(name,n,0)
        # Original first event had 0 body / 6 margin hits. New returned counts
        # are authoritative for this distinct synthetic trajectory/query case.
        r.record_hit(1,0,'boundaryIntersection')
        for cid in (0,1):r.record_hit(2,cid,'containedTriangleVertex')
        row=json.loads(r.finish_event(result(1,2)));self.assertEqual(row['actualBodyTriangleIDs'],[0])
        self.assertFalse(r.summary()['oldPerEventCountEqualityRequired'])
    def test_missing_or_duplicate_ids_refused(self):
        r=record.BoundedQueryHitRecorder(FROZEN);name,n=r.sequence[0];r.begin_event(name,n,0)
        with self.assertRaisesRegex(RuntimeError,'count/complete-ID'):r.finish_event(result(1,0))
        r.record_hit(1,0,'boundaryIntersection');r.record_hit(1,0,'boundaryIntersection')
        with self.assertRaisesRegex(RuntimeError,'count/complete-ID'):r.finish_event(result(2,0))
    def test_backwards_query_and_first_id_mismatch_refused(self):
        r=record.BoundedQueryHitRecorder(FROZEN);name,n=r.sequence[0];r.begin_event(name,n,0)
        r.record_hit(2,0,'boundaryIntersection')
        with self.assertRaisesRegex(RuntimeError,'backwards'):r.record_hit(1,0,'boundaryIntersection')
        r=record.BoundedQueryHitRecorder(FROZEN);r.begin_event(name,n,0);r.record_hit(1,4,'boundaryIntersection')
        with self.assertRaisesRegex(RuntimeError,'first-hit identity'):r.finish_event(result(1,0))
    def test_fixed_id_and_logical_caps_refuse_before_acceptance(self):
        r=record.BoundedQueryHitRecorder(FROZEN);name,n=r.sequence[0];r.begin_event(name,n,0);r.total=record.MAX_TOTAL_IDS
        with self.assertRaisesRegex(RuntimeError,'global logged-ID cap'):r.record_hit(1,0,'boundaryIntersection')
        self.assertEqual(r.active['ids'],[[],[]]);r.logical=record.MAX_LOGICAL_BYTES
        with self.assertRaisesRegex(RuntimeError,'logical byte cap'):r.finish_event(result())
        self.assertEqual(r.completed,0)
    def test_complete_new_schedule_returned_count_accounting(self):
        r=record.BoundedQueryHitRecorder(FROZEN)
        for name,n in r.sequence:r.begin_event(name,n,r.completed*2);r.finish_event(result())
        s=r.summary(require_complete=True);self.assertTrue(s['returnedQueryCountsMatched'])
        self.assertEqual(s['completedEvents'],7470);self.assertFalse(s['physicalAuthority'])
    def test_baseline_comparison_does_not_use_event_percentage_or_safety_rank(self):
        r=record.BoundedQueryHitRecorder(FROZEN)
        for name,n in r.sequence:r.begin_event(name,n,r.completed*2);r.finish_event(result())
        comp=selection.compare_baseline(BASE,r.summary(require_complete=True))
        self.assertFalse(comp['safetyImprovementEstablished']);self.assertFalse(comp['contactEventPercentagesCalculated'])
        for old,row in zip(BASE['paths'],comp['paths']):
            for kind in ('actualBody','horizontalMargin'):
                self.assertEqual(row['arms'][kind]['removedFaceIDs'],old['arms'][kind]['uniqueIDs'])
                self.assertEqual(row['arms'][kind]['addedFaceIDs'],[])
if __name__=='__main__':unittest.main(verbosity=2)
