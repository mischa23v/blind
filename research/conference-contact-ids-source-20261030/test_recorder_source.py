"""Stdlib-only source/recorder contracts; synthetic IDs are not scene results."""
import ast, hashlib, importlib.util, json, pathlib, unittest
H=pathlib.Path(__file__).resolve().parent;R=H.parents[1]
spec=importlib.util.spec_from_file_location('pinned_hit_recorder',H/'hit_recorder.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
EXPECTED=json.loads((H/'EXPECTED_COUNTS.json').read_text())

def result_for(counts):
    return {kind:{'groundContactCount':0,'nonGroundContactCount':n,'candidateTriangles':n,'contact':n>0,
                  'firstReferenceCellID':0 if n else None}
            for kind,n in zip(('actualBody','horizontalMargin'),counts)}

class RecorderSourceTests(unittest.TestCase):
    def test_all_hit_method_identical_except_additive_record_call(self):
        old=R/'research/coffee-room-journey-recovery-20261029/collision-protocol/upstream/blind-split-candidate-game-03/ground-follow-v2/oriented_ground_container.py'
        def method(path):
            tree=ast.parse(path.read_text())
            return next(n for n in ast.walk(tree) if isinstance(n,ast.FunctionDef) and n.name=='contact_corners')
        baseline=method(old);debug=method(H/'oriented_ground_container_debug.py')
        removed=[]
        class RemoveRecorder(ast.NodeTransformer):
            def visit_If(self,node):
                if isinstance(node.test,ast.Compare) and isinstance(node.test.left,ast.Attribute) and node.test.left.attr=='_contact_recorder':
                    removed.append(node);return None
                return self.generic_visit(node)
        debug=RemoveRecorder().visit(debug)
        self.assertEqual(len(removed),1)
        self.assertEqual(ast.dump(debug,include_attributes=False),ast.dump(baseline,include_attributes=False))
    def test_complete_synthetic_recorder_stream_exact_counts(self):
        synthetic=json.loads(json.dumps(EXPECTED))
        synthetic['totalCandidateTriangles']=108582
        synthetic['candidateCountStreamSHA256']=hashlib.sha256(b''.join(('%d,%d\n'%tuple(pair)).encode()for row in synthetic['paths']for pair in row['counts'])).hexdigest()
        recorder=m.FixedHitRecorder(synthetic)
        for name,n,counts in recorder.sequence:
            offset=recorder.completed*2;recorder.begin_event(name,n,offset)
            for slot,count in enumerate(counts):
                for cell in range(count):recorder.record_hit(offset+slot+1,cell,'boundaryIntersection')
            record=json.loads(recorder.finish_event(result_for(counts)))
            self.assertEqual([len(record[k])for k in ('actualBodyTriangleIDs','horizontalMarginTriangleIDs')],counts)
        summary=recorder.summary(require_complete=True)
        self.assertEqual(summary['loggedHitOccurrences'],108582)
        self.assertTrue(summary['allOldPerEventCountsMatched'])
    def test_global_cap_is_enforced_before_append(self):
        r=m.FixedHitRecorder(EXPECTED);name,n,counts=r.sequence[0];r.begin_event(name,n,0);r.total=m.MAX_TOTAL_IDS
        with self.assertRaisesRegex(RuntimeError,'global logged-ID cap'):r.record_hit(2,0,'boundaryIntersection')
        self.assertEqual(r.active['ids'],[[],[]])
    def test_extra_or_missing_hit_cannot_be_a_complete_record(self):
        r=m.FixedHitRecorder(EXPECTED);name,n,counts=r.sequence[0];r.begin_event(name,n,0)
        with self.assertRaisesRegex(RuntimeError,'not reproduced'):r.finish_event(result_for(counts))
        for cell in range(counts[1]):r.record_hit(2,cell,'boundaryIntersection')
        with self.assertRaisesRegex(RuntimeError,'exceeds exact old'):r.record_hit(2,123,'boundaryIntersection')
    def test_event_or_query_reordering_rejected(self):
        r=m.FixedHitRecorder(EXPECTED);name,n,_=r.sequence[0]
        with self.assertRaisesRegex(RuntimeError,'identity'):r.begin_event(name,n+1,0)
        r.begin_event(name,n,0)
        with self.assertRaisesRegex(RuntimeError,'invalid hit query'):r.record_hit(3,1,'boundaryIntersection')
    def test_output_cap_prevents_completed_record(self):
        r=m.FixedHitRecorder(EXPECTED);name,n,counts=r.sequence[0];r.begin_event(name,n,0)
        for cell in range(counts[1]):r.record_hit(2,cell,'boundaryIntersection')
        r.logical=m.MAX_LOGICAL_BYTES
        with self.assertRaisesRegex(RuntimeError,'logical output cap'):r.finish_event(result_for(counts))
        self.assertEqual(r.completed,0)

if __name__=='__main__':unittest.main(verbosity=2)
