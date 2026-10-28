#!/usr/bin/env python3
"""Independent synthetic viewer checks; no native route evidence or safety claim."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('viewer_test_helpers', HERE / 'test_render_results.py')
t = importlib.util.module_from_spec(spec)
spec.loader.exec_module(t)
r = t.r


class IndependentReview(unittest.TestCase):
    def load(self, evidence):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / 'synthetic.json'
            raw = json.dumps(evidence).encode()
            path.write_bytes(raw)
            return r.load_evidence(path, r.digest(raw))

    def test_unexpected_private_source_key_is_rejected(self):
        evidence = t.synthetic_evidence()
        evidence['routeDiagnosticEvidence']['sourceSHA256'] = dict(t.HASHES)
        evidence['routeDiagnosticEvidence']['sourceSHA256']['/private/family/photo.jpg'] = 'a' * 64
        with self.assertRaises(r.ViewError):
            self.load(evidence)

    def test_uncollected_status_is_sanitized(self):
        evidence = t.synthetic_evidence()
        record = evidence['routeDiagnosticEvidence']['reports'][0]
        record['status'] = '/private/family/photo.jpg'
        record.pop('report')
        _, _, metadata = self.load(evidence)
        self.assertNotIn('/private', json.dumps(metadata))
        self.assertEqual(metadata['reportInventory'][0]['collectionStatus'], 'not_collected')

    def test_independent_affine_witness(self):
        # x'= -2*y+7, y'=3*z-4, z'=5*x+11; full column-major matrix.
        matrix = [0,0,5,0, -2,0,0,0, 0,3,0,0, 7,-4,11,1]
        self.assertEqual(r.transform([2,3,4], matrix), [1,8,21])
        self.assertEqual(r.projected(r.transform([2,3,4], matrix)), [1,21])

    def test_active_failures_draw_no_route_lines(self):
        for label in ('journey', 'original-baseline'):
            for invalid in (False, True):
                with self.subTest(label=label, invalid=invalid), tempfile.TemporaryDirectory() as d:
                    report = t.synthetic_report(label)
                    row = report['outcomes'][0]
                    for key in ('projectedStart','projectedGoal','routePoints','nativeComplete','nativeStatus',
                                'startProjectionMetres','goalProjectionMetres','bodyContact','marginContact',
                                'floorContactIDs','obstacleSurfaceIDs','furnitureBoundIDs','segments',
                                'productionGuidanceReceipts','scoredChainContinuous',
                                'scoredChainIncludesRequestedGoal','sourceFloorSupportAlongScoredChain'):
                        row.pop(key, None)
                    row['outcome'] = ('invalid-standing-start-contact' if label == 'journey' else 'invalid-start-contact') if invalid else 'native-query-failure'
                    row['initialBodyContact'] = invalid
                    row['initialMarginContact'] = invalid
                    row['nativeError'] = 'nativeFailure'
                    if label == 'journey':
                        row['guidanceDelivered'] = False
                        row['replayPositionAfterStage'] = row['requestedStart']
                    else:
                        row['waypointSinkDelivered'] = False
                    t.v.validate_report(report, label, t.DOCS, t.UUIDS)
                    room, _, _, profile = r.schedule_map(t.DOCS, label)[r.identity(row, label)]
                    features = r.scene(t.DOCS[f'RoomPlanApple/{room}.capturedRoom.json'])
                    stem = Path(d) / 'SYNTHETIC-NOT-NATIVE'
                    receipt = r.draw_one(row, label, room, features, r.bounds(features, [row]), profile, stem, synthetic=True)
                    self.assertNotIn('reported-segment-', stem.with_suffix('.svg').read_text())
                    self.assertEqual(receipt['reportedOutcome'], row)
                    self.assertFalse(receipt['physicalAuthority'])


if __name__ == '__main__':
    unittest.main(verbosity=2)
