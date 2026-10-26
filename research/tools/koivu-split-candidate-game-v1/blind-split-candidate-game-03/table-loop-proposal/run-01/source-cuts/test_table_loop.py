"""Tiny synthetic topology/adapter fixtures. No recorded map or native queries.

Written source-only while the independent game worker owns the compute slot.
Running these fixtures requires the later coordinated authorization.
"""
import math
import json
from types import SimpleNamespace
import unittest

import numpy as np

import table_loop as loop


class TopologyTests(unittest.TestCase):
    def test_no_blocked_island(self):
        target, _, report = loop.choose_target(np.ones((5, 5), bool))
        self.assertIsNone(target)
        self.assertEqual(report["reason"], "noEnclosedPhoneObstacleTarget")

    def test_border_component_is_not_target(self):
        mask = np.ones((9, 9), bool)
        mask[0, :] = False
        mask[3:5, 3:5] = False
        target, _, _ = loop.choose_target(mask)
        np.testing.assert_array_equal(target["cells"], [[3, 3], [3, 4], [4, 3], [4, 4]])

    def test_diagonal_blocked_connection_to_border_is_exterior(self):
        mask = np.ones((7, 7), bool)
        mask[[0, 1, 2], [0, 1, 2]] = False
        target, _, _ = loop.choose_target(mask)
        self.assertIsNone(target)

    def test_walk_connectivity_is_four_not_eight(self):
        mask = np.zeros((5, 5), bool)
        mask[1, 1] = mask[2, 2] = True
        _, walk, report = loop.choose_target(mask)
        self.assertNotEqual(walk[1, 1], walk[2, 2])
        self.assertEqual(report["walkComponents"], 2)

    def test_largest_island_wins(self):
        mask = np.ones((10, 10), bool)
        mask[2, 2] = False
        mask[6:8, 6:8] = False
        target, _, _ = loop.choose_target(mask)
        self.assertEqual(len(target["cells"]), 4)

    def test_exact_centroid_tie_uses_lowest_flat_index(self):
        mask = np.ones((9, 9), bool)
        mask[2, 2] = mask[6, 6] = False
        target, _, _ = loop.choose_target(mask)
        np.testing.assert_array_equal(target["cells"], [[2, 2]])

    def test_no_walk_is_explicit(self):
        target, _, report = loop.choose_target(np.zeros((5, 5), bool))
        self.assertIsNone(target)
        self.assertEqual(report["reason"], "noWalkablePhoneCells")

    def test_outline_is_exposed_edges_not_hull(self):
        self.assertEqual(len(loop.outline_segments([[1, 1]])), 4)
        self.assertEqual(len(loop.outline_segments([[1, 1], [2, 1]])), 6)

    def test_side_targets_use_cell_edges_and_fixed_order(self):
        low, high, targets = loop.side_geometry(np.array([[2, 3]]), [1., -2.])
        np.testing.assert_allclose(low, [1.10, -1.85])
        np.testing.assert_allclose(high, [1.15, -1.80])
        self.assertGreater(targets[0, 1], high[1])
        self.assertGreater(targets[1, 0], high[0])
        self.assertLess(targets[2, 1], low[1])
        self.assertLess(targets[3, 0], low[0])


class WindingTests(unittest.TestCase):
    def setUp(self):
        self.square = np.array([[-1., -1.], [1., -1.], [1., 1.], [-1., 1.], [-1., -1.]])
        self.centres = np.array([[0., 0.], [.2, .3], [-.3, -.2]])

    def test_all_target_centres_encircled_once_in_both_directions(self):
        for path, expected in ((self.square, 1), (self.square[::-1], -1)):
            result = loop.winding_receipt(path, self.centres)
            self.assertTrue(result["passed"])
            self.assertEqual(result["commonSignedWinding"], expected)
            self.assertFalse(result["simpleNonSelfIntersectingPolygonProven"])

    def test_out_and_back_is_not_a_loop(self):
        path = np.array([[-1., 0.], [1., 0.], [-1., 0.], [-1., 0.]])
        self.assertFalse(loop.winding_receipt(path, [[0., .2]])["passed"])

    def test_twice_wound_path_is_not_single_lap_proposal(self):
        path = np.vstack((self.square, self.square[1:]))
        result = loop.winding_receipt(path, self.centres)
        self.assertFalse(result["passed"])
        self.assertEqual(result["windingHistogram"], {"2": 3})

    def test_one_target_cell_outside_rejects(self):
        self.assertFalse(loop.winding_receipt(self.square, [[0., 0.], [2., 0.]])["passed"])

    def test_target_on_segment_is_not_encircled(self):
        result = loop.winding_receipt(self.square, [[1., 0.]])
        self.assertFalse(result["passed"])
        self.assertEqual(result["centresOnRoute"], 1)

    def test_open_or_nonfinite_path_rejected(self):
        with self.assertRaises(ValueError):
            loop.winding_numbers(self.square[:-1], self.centres)
        bad = self.square.copy()
        bad[1, 0] = np.nan
        with self.assertRaises(ValueError):
            loop.winding_numbers(bad, self.centres)


class ConnectionTests(unittest.TestCase):
    def setUp(self):
        self.waypoints = [[0., 0., 0.], [1., 0., 0.], [1., 0., 1.], [0., 0., 1.]]
        self.legs = [{"complete": True, "points": [self.waypoints[(i+1) % 4]]} for i in range(4)]

    def test_start_skipped_only_by_existing_adapter(self):
        path, connectors = loop.planar_cycle(self.waypoints, self.legs)
        np.testing.assert_array_equal(path, self.waypoints+[self.waypoints[0]])
        self.assertEqual(len(connectors), 4)
        self.assertTrue(all(c["lengthMetres"] == 0 for c in connectors))

    def test_projected_end_gets_explicit_unsnapped_connector(self):
        self.legs[0]["points"] = [[.95, .025, 0.]]
        path, connectors = loop.planar_cycle(self.waypoints, self.legs)
        self.assertAlmostEqual(connectors[0]["lengthMetres"], .05)
        np.testing.assert_array_equal(path[1], [.95, 0., 0.])
        np.testing.assert_array_equal(path[2], self.waypoints[1])
        self.assertFalse(connectors[0]["nativeSearchForConnector"])

    def test_submicrometre_float32_goal_difference_does_not_invent_turn(self):
        original = [1.-2e-7, .025, 1e-7]
        self.legs[0]["points"] = [original.copy()]
        path, connectors = loop.planar_cycle(self.waypoints, self.legs)
        np.testing.assert_array_equal(path, self.waypoints+[self.waypoints[0]])
        self.assertEqual(self.legs[0]["points"], [original])
        self.assertTrue(connectors[0]["coalescedToExactRequestedWaypoint"])
        self.assertGreater(connectors[0]["lengthMetresBeforeNumericalCoalescing"], 0.)
        self.assertLess(connectors[0]["lengthMetresBeforeNumericalCoalescing"], 1e-6)
        self.assertEqual(loop.nominal_budget(path)["perLapTurnTicksIncludingClosure"], 360)

    def test_corner_more_than_coalescing_bound_is_retained(self):
        self.legs[0]["points"] = [[1.-2e-6, 0., 0.]]
        path, connectors = loop.planar_cycle(self.waypoints, self.legs)
        self.assertEqual(len(path), 6)
        self.assertFalse(connectors[0]["coalescedToExactRequestedWaypoint"])
        np.testing.assert_array_equal(path[1], [1.-2e-6, 0., 0.])

    def test_incomplete_or_overlong_connection_rejected(self):
        self.legs[0]["complete"] = False
        with self.assertRaises(ValueError):
            loop.planar_cycle(self.waypoints, self.legs)
        self.legs[0] = {"complete": True, "points": [[.8, 0., 0.]]}
        with self.assertRaises(ValueError):
            loop.planar_cycle(self.waypoints, self.legs)

    def test_closure_seam_passed_to_unchanged_checker(self):
        calls = []
        rr = SimpleNamespace(sweep_ok=lambda mask, origin, path: calls.append(path.copy()) or "ok",
                             rect_ok=lambda *args: True)
        model = SimpleNamespace(rr=rr, mask=np.ones((2, 2), bool), origin=(0., 0.))
        path, _ = loop.planar_cycle(self.waypoints, self.legs)
        report, poses = loop.sampled_closed_check(model, path)
        self.assertTrue(report["passed"])
        self.assertGreater(len(poses), 0)
        self.assertEqual(len(calls[0]), len(path)+1)
        np.testing.assert_array_equal(calls[0][-1], calls[0][1])
        self.assertFalse(report["continuousClearanceProven"])

    def test_exact_endpoint_not_multiple_of_spacing_is_checked(self):
        path = np.array([[0., 0., 0.], [.031, 0., 0.], [.031, 0., -.04], [0., 0., -.04], [0., 0., 0.]])
        def rect(mask, origin, x, y, theta):
            return not (abs(x-.031) < 1e-12 and abs(y) < 1e-12 and abs(theta) < 1e-12)
        model = SimpleNamespace(rr=SimpleNamespace(sweep_ok=lambda *args: "ok", rect_ok=rect),
                                mask=np.ones((2, 2), bool), origin=(0., 0.))
        report, _ = loop.sampled_closed_check(model, path)
        self.assertFalse(report["exactSegmentEndpointHeadingsFit"])
        self.assertFalse(report["passed"])

    def test_three_lap_budget_scales_length_and_closure_turns(self):
        path, _ = loop.planar_cycle(self.waypoints, self.legs)
        budget = loop.nominal_budget(path)
        self.assertEqual(budget["laps"], 3)
        self.assertEqual(budget["perLapTranslationTicksCeilTotalLength"], 200)
        self.assertEqual(budget["perLapTurnTicksIncludingClosure"], 360)
        self.assertEqual(budget["proposedMaximumEpisodeTicks"], 3*(200+360+300)+150)
        self.assertFalse(budget["actorResetOrTeleportAllowed"])

    def test_rejected_native_missing_coordinates_serialize_null_not_zero(self):
        value = {"complete": False, "projectedStart": [math.nan, math.inf, -math.inf],
                 "reason": "query_association", "count": np.int64(3)}
        parsed = json.loads(loop.proposal_json(value))
        self.assertEqual(parsed["projectedStart"], [None, None, None])
        self.assertFalse(parsed["complete"])
        self.assertEqual(parsed["reason"], "query_association")
        self.assertEqual(parsed["count"], 3)


if __name__ == "__main__":
    unittest.main()
