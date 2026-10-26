"""Authored array/graph fixtures only; no supplied map, native library or query."""
import math
import unittest
from types import SimpleNamespace
import numpy as np
import flexible_loop as f


def cycles(specs):
    legs, transitions, closures = [], [], {}
    for number, (capacity, length, winding) in enumerate(specs):
        offset = len(legs)
        for k in range(8):
            legs.append({'id': offset+k, 'sector': k, 'from': number*100+k,
                         'to': number*100+(k+1)%8, 'fromFlat': number*100+k,
                         'toFlat': number*100+(k+1)%8, 'capacity': capacity,
                         'length': length, 'crossings': winding if k == 7 else 0})
            if k:
                transitions.append((offset+k-1, offset+k, capacity))
        closures[(offset+7, offset)] = capacity
    return legs, transitions, closures


class Fixtures(unittest.TestCase):
    def test_crossing_closed_square(self):
        square = [[-1,-1],[1,-1],[1,1],[-1,1],[-1,-1]]
        self.assertEqual(f.open_crossings(square, [0,0]), 1)
        self.assertEqual(f.open_crossings(square[::-1], [0,0]), -1)

    def test_anchor_touch(self):
        self.assertIsNone(f.open_crossings([[-1,0],[1,0]], [0,0]))

    def test_half_open_crossing_is_additive(self):
        self.assertEqual(f.open_crossings([[1,-1],[1,0]], [0,0]), 0)
        self.assertEqual(f.open_crossings([[1,0],[1,1]], [0,0]), 1)
        self.assertEqual(f.open_crossings([[1,-1],[1,0],[1,1]], [0,0]), 1)

    def test_explicit_blocked_exterior(self):
        field = f.clearance_field(np.ones((3,3), bool))
        self.assertAlmostEqual(field[0,0], .05-.05/math.sqrt(2))
        self.assertAlmostEqual(field[1,1], .10-.05/math.sqrt(2))

    def test_off_centre_lipschitz_and_outside(self):
        field = np.full((2,2), .2)
        value = f.clearance_at([[.025,.025],[.035,.025],[-.001,.025]], (0,0), field)
        np.testing.assert_allclose(value, [.2,.19,0], atol=1e-15)

    def test_path_metric(self):
        metric = f.path_metric([[.025,0,-.025],[.075,0,-.025]], (0,0), np.full((3,3), .2))
        self.assertAlmostEqual(metric['length'], .05)
        self.assertEqual(metric['firstHeading'], 0)

    def test_initial_length_counted(self):
        legs, edges, closures = cycles([(1,1,1)])
        legs[0]['length'] = 9
        result = f.rank_cycle(legs, edges, closures)
        self.assertEqual(result['selectedLengthMetres'], 16)
        self.assertEqual(result['scipyShortestLengthMetres'], 16)

    def test_maximin_precedes_shortest(self):
        result = f.rank_cycle(*cycles([(1,1,1),(2,3,1)]))
        self.assertEqual(result['legIDs'], list(range(8,16)))
        self.assertEqual(result['maximumBottleneckCentreClearanceMetres'], 2)

    def test_shortest_at_equal_bottleneck(self):
        result = f.rank_cycle(*cycles([(2,3,1),(2,1,1)]))
        self.assertEqual(result['legIDs'], list(range(8,16)))

    def test_winding_invalid_winner_does_not_hide_valid_loop(self):
        result = f.rank_cycle(*cycles([(3,1,0),(2,2,1)]))
        self.assertEqual(result['legIDs'], list(range(8,16)))

    def test_negative_winding(self):
        self.assertEqual(f.rank_cycle(*cycles([(1,1,-1)]))['winding'], -1)

    def test_winding_lift_bound(self):
        legs, edges, closures = cycles([(1,1,1)])
        legs[1]['crossings'], legs[7]['crossings'] = 9, -8
        self.assertFalse(f.rank_cycle(legs, edges, closures)['found'])

    def test_missing_closing_turn_rejects(self):
        legs, edges, _ = cycles([(1,1,1)])
        self.assertFalse(f.rank_cycle(legs, edges, {})['found'])

    def test_initial_leg_specific_closure(self):
        legs, edges, _ = cycles([(1,1,1),(1,1,1)])
        # Closures only to the other disconnected cycle: no valid source row.
        self.assertFalse(f.rank_cycle(legs, edges, {(7,8):1, (15,0):1})['found'])

    def test_cell_index_ties(self):
        legs, edges, closures = cycles([(1,1,1),(1,1,1)])
        for leg in legs[:8]:
            leg['fromFlat'] += 1000; leg['toFlat'] += 1000
        self.assertEqual(f.rank_cycle(legs, edges, closures)['legIDs'], list(range(8,16)))

    def test_junction_heading_is_acceptance(self):
        rr = SimpleNamespace(rect_ok=lambda mask, origin, x, y, theta: abs(theta) < .3)
        model = SimpleNamespace(rr=rr, mask=np.ones((3,3),bool), origin=(0,0))
        self.assertTrue(f.junction(model, 0, .1, [.075,.075], np.ones((3,3)))['passed'])
        self.assertFalse(f.junction(model, 0, 1., [.075,.075], np.ones((3,3)))['passed'])

    def test_exact_assembly_endpoint(self):
        legs = [{'path':[[0,0,0],[1,0,0]]}, {'path':[[1,0,0],[0,0,0]]}]
        np.testing.assert_array_equal(f.assemble_cycle(legs,[0,1]), [[0,0,0],[1,0,0],[0,0,0]])
        legs[1]['path'][0][0] += 1e-7
        with self.assertRaises(ValueError):
            f.assemble_cycle(legs,[0,1])


if __name__ == '__main__':
    unittest.main(verbosity=2)
