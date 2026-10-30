"""Small authored controls, prepared but not executed at source handoff.

GEOS controls use the installed library only; all corridor owners here are
explicit authored stubs, never a real-room/native route test or acceptance.
"""
import copy
import hashlib
import math
import pathlib
import tempfile
import unittest
from unittest.mock import patch
import candidate as c


class CorridorStub:
    def __init__(self, answer=True):
        self.answer = answer
        self.calls = []
    def segment(self, a, b):
        self.calls.append((copy.deepcopy(a), copy.deepcopy(b)))
        return self.answer


class MaxSpanStub(CorridorStub):
    def segment(self, a, b):
        super().segment(a, b)
        return math.dist(a, b) <= .12


def row(graph=None):
    graph = graph or [[0., .01, 0.], [.05, .02, 0.], [.10, .03, .005], [.15, .04, -.005], [.20, .05, 0.], [.25, .06, 0.]]
    start, goal = [-.01, -.02, 0.], [.26, -.03, 0.]
    distance = sum(math.dist(a, b) for a, b in zip(graph, graph[1:]))
    return {'name': c.NAMES[0], 'sourcePoseIndices': [92, 120], 'requestedStartXYZ': start, 'requestedGoalXYZ': goal,
            'gridSelection': {'lengthCapMetres': 1.5 * distance + .5, 'distanceGrid': {'lengthMetres': distance},
                              'clearanceGrid': {'pointsXYZ': graph, 'requestedConnectorChainXYZ': [start] + graph + [goal]}}}


def scene():
    return {'frame': 'authored-xz-m', 'revision': 'fixture-v1', 'units': 'metres', 'captured_at': 100., 'max_age_seconds': 10.,
            'source_kind': 'authored_fixture', 'coverage': [[-5, -5], [5, -5], [5, 5], [-5, 5]],
            'projection': {layer: {'source': 'authored control only', 'coverage': 'complete', 'frame': 'authored-xz-m', 'revision': 'fixture-v1'} for layer in ('floor', 'body', 'head')},
            'obstacles': [{'id': 'authored-table', 'layer': 'body', 'source_kind': 'authored_fixture', 'polygon': [[0, 0], [1, 0], [1, 1], [0, 1]]}]}


class Controls(unittest.TestCase):
    def test_reused_loader_executes_exact_hashed_bytes_without_reread(self):
        source = b'checked_value = 17\n'
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / 'probe.py'
            path.write_text("raise RuntimeError('unchecked path bytes executed')\n")
            with patch.object(pathlib.Path, 'read_bytes', return_value=source) as read:
                module = c.source_module('_authored_exact_bytes_probe', path, hashlib.sha256(source).hexdigest())
            read.assert_called_once(); self.assertEqual(module.checked_value, 17)

    def test_reused_loader_rejects_wrong_hash_before_execution(self):
        with patch.object(pathlib.Path, 'read_bytes', return_value=b"raise RuntimeError('must not execute')\n"):
            with self.assertRaisesRegex(ValueError, 'source pin mismatch'):
                c.source_module('_authored_wrong_hash', pathlib.Path('unused.py'), '0' * 64)

    def test_fixed_tolerance(self):
        self.assertEqual(c.TOLERANCE_METRES, .025)

    def test_actual_geos_shallow_staircase_preserves_exact_xyz_edges_and_connectors(self):
        source = row(); before = copy.deepcopy(source)
        pair = c.paired_objective(source, native=CorridorStub(), corridor_scope='authored-control-stub')
        out = pair['geos025CenteredCandidate']; original = source['gridSelection']['clearanceGrid']['requestedConnectorChainXYZ']
        self.assertEqual(out['status'], 'provisionalIndependentCoverageUnknown')
        self.assertLess(len(out['chainXYZ']), len(original))
        self.assertLess(out['metrics']['eventCounts']['turn'], pair['unchangedCentered']['metrics']['eventCounts']['turn'])
        self.assertEqual(out['chainXYZ'][:3], original[:3]); self.assertEqual(out['chainXYZ'][-3:], original[-3:])
        self.assertTrue(all(p in original for p in out['chainXYZ']))
        self.assertEqual(source, before); self.assertFalse(out['accepted'])
        self.assertFalse(out['checks']['eligibleForLaterFullBodyDiagnostic'])

    def test_actual_geos_locked_edge_overlap_rejected_after_reattachment(self):
        graph = [[-.01, 0., 0.], [.01, 0., 0.], [.01, 0., .005], [-.02, 0., .005], [-.02, 0., 0.], [-.03, 0., 0.]]
        source = row(graph)
        source['requestedStartXYZ'] = [-.011, 0., 0.]; source['requestedGoalXYZ'] = [-.031, 0., 0.]
        source['gridSelection']['clearanceGrid']['requestedConnectorChainXYZ'] = [source['requestedStartXYZ']] + graph + [source['requestedGoalXYZ']]
        self.assertTrue(c.geos_full_chain_simple(source['gridSelection']['clearanceGrid']['requestedConnectorChainXYZ']))
        out = c.paired_objective(source, native=CorridorStub(), corridor_scope='authored-control-stub')['geos025CenteredCandidate']
        self.assertEqual(out['status'], 'rejectedFullXZTopology')
        self.assertFalse(out['fullReconstructedXZSimple']); self.assertIsNotNone(out['chainXYZ'])
        self.assertFalse(out['checks']['eligibleForLaterFullBodyDiagnostic']); self.assertFalse(out['accepted'])

    def test_every_full_segment_checked_in_both_directions(self):
        native = CorridorStub(); source = row()
        with patch.object(c, 'geos_simplify_xz', return_value=[[.05, 0.], [.20, 0.]]):
            pair = c.paired_objective(source, native=native, corridor_scope='authored-control-stub')
        original = pair['unchangedCentered']['chainXYZ']; simplified = pair['geos025CenteredCandidate']['chainXYZ']
        expected = [(start, goal) for chain in (original, simplified) for a, b in zip(chain, chain[1:]) for start, goal in ((a, b), (b, a))]
        self.assertEqual(native.calls, expected)

    def test_authored_corridor_rejects_new_span_despite_original_spans_passing(self):
        with patch.object(c, 'geos_simplify_xz', return_value=[[.05, 0.], [.20, 0.]]):
            pair = c.paired_objective(row(), native=MaxSpanStub(), corridor_scope='authored-control-stub')
        self.assertTrue(pair['unchangedCentered']['checks']['allNativeSegmentsPassBothDirections'])
        out = pair['geos025CenteredCandidate']
        self.assertEqual(out['status'], 'provisionalNativeCorridorRejectedOrUnknown')
        self.assertFalse(out['checks']['eligibleForLaterFullBodyDiagnostic']); self.assertFalse(out['accepted'])

    def test_unknown_corridor_never_eligible(self):
        with patch.object(c, 'geos_simplify_xz', return_value=[[.05, 0.], [.20, 0.]]):
            out = c.paired_objective(row())['geos025CenteredCandidate']
        self.assertFalse(out['checks']['eligibleForLaterFullBodyDiagnostic'])

    def test_missing_coverage_blocks_acceptance_not_later_diagnostic(self):
        # Authored decision-logic control under an assumed verified-native flag;
        # the stub is not evidence that a real corridor check has run.
        checks = c.check_segments([[0., 0., 0.], [.1, 0., 0.]], CorridorStub(), None, None, None, None, 'admitted-unchanged-native')
        self.assertTrue(checks['eligibleForLaterFullBodyDiagnostic'])
        self.assertEqual(checks['independent2D']['status'], 'unknown')
        self.assertFalse(checks['accepted']); self.assertFalse(checks['physicalAuthority'])

    def test_ambiguous_xz_height_is_rejected_without_calling_simplifier(self):
        source = row(); source['gridSelection']['clearanceGrid']['pointsXYZ'][2] = [.05, .025, 0.]
        graph = source['gridSelection']['clearanceGrid']['pointsXYZ']
        source['gridSelection']['clearanceGrid']['requestedConnectorChainXYZ'] = [source['requestedStartXYZ']] + graph + [source['requestedGoalXYZ']]
        with patch.object(c, 'geos_simplify_xz') as simplify:
            out = c.paired_objective(source)['geos025CenteredCandidate']
        simplify.assert_not_called(); self.assertEqual(out['status'], 'rejectedSimplification'); self.assertIsNone(out['chainXYZ'])

    def test_non_subsequence_and_reordered_or_moved_vertices_rejected(self):
        for result in ([[.051, 0.], [.20, 0.]], [[.20, 0.], [.05, 0.]], [[.05, 0.], [.15, -.005], [.10, .005], [.20, 0.]]):
            with self.subTest(result=result), patch.object(c, 'geos_simplify_xz', return_value=result):
                out = c.paired_objective(row())['geos025CenteredCandidate']
                self.assertEqual(out['status'], 'rejectedSimplification'); self.assertIsNone(out['chainXYZ'])

    def test_geos_error_retained_without_fallback_or_retry(self):
        with patch.object(c, 'geos_simplify_xz', side_effect=ValueError('authored failure')) as simplify:
            pair = c.paired_objective(row())
        self.assertEqual(simplify.call_count, 1); self.assertIsNotNone(pair['unchangedCentered']['chainXYZ'])
        self.assertIsNone(pair['geos025CenteredCandidate']['chainXYZ'])

    def test_complete_2d_segment_obstacle_crossing_rejected(self):
        checks = c.check_segments([[-2, 0, .5], [2, 0, .5]], CorridorStub(), scene(), 'authored-xz-m', 'fixture-v1', 105., 'authored-control-stub')
        self.assertEqual(checks['independent2D']['status'], 'rejected'); self.assertFalse(checks['accepted'])

    def test_body_and_margin_contacts_use_unchanged_profile(self):
        for z in (-.1, -.32):
            checks = c.check_segments([[-2, 0, z], [2, 0, z]], CorridorStub(), scene(), 'authored-xz-m', 'fixture-v1', 105., 'authored-control-stub')
            self.assertEqual(checks['independent2D']['status'], 'rejected')
            self.assertEqual(checks['independent2D']['profile']['margin'], .15)

    def test_missing_projection_and_coverage_boundary_remain_unknown(self):
        incomplete = scene(); del incomplete['projection']['head']
        for chain, source in (([[-2, 0, -1], [2, 0, -1]], incomplete), ([[-4.8, 0, -3], [-4.8, 0, 3]], scene())):
            checks = c.check_segments(chain, CorridorStub(), source, 'authored-xz-m', 'fixture-v1', 105., 'authored-control-stub')
            self.assertEqual(checks['independent2D']['status'], 'unknown'); self.assertFalse(checks['accepted'])

    def test_authored_2d_clear_still_requires_full_3d(self):
        checks = c.check_segments([[-2, 0, -1], [2, 0, -1]], CorridorStub(), scene(), 'authored-xz-m', 'fixture-v1', 105., 'authored-control-stub')
        self.assertEqual(checks['independent2D']['status'], 'clear_in_authored_fixture_only')
        self.assertEqual(checks['full3DValidation'], 'requiredNotExecuted'); self.assertFalse(checks['accepted'])

    def test_all_seven_retained_even_if_every_simplification_fails(self):
        proposals = {'paths': [dict(row(), name=name) for name in c.NAMES]}
        with patch.object(c, 'geos_simplify_xz', side_effect=ValueError('authored failure')):
            result = c.paired_all_seven(proposals)
        self.assertEqual([p['name'] for p in result['paths']], c.NAMES)
        self.assertTrue(all(p['unchangedCentered']['chainXYZ'] for p in result['paths']))
        self.assertTrue(all(p['geos025CenteredCandidate']['status'] == 'rejectedSimplification' for p in result['paths']))
        self.assertFalse(result['accepted'])


if __name__ == '__main__':
    unittest.main(verbosity=2)
