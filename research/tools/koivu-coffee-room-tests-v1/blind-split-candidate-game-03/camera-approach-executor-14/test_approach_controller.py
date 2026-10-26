"""Authored contract fixtures only: no recorded map, reference or journey."""
from pathlib import Path
import copy
import hashlib
import json
import tempfile
import unittest
import numpy as np
from approach_controller import ApproachController, load_plan, variants


class FakeMap:
    revision = 'authored-phone-revision'
    def __init__(self):
        self.closed = False
        self.fit = True
        self.complete = True
    def close(self): self.closed = True
    def flag_receipt(self, position, yaw):
        return {'sampledFit': self.fit, 'lowUnresolvedCells': 2, 'mapRevision': self.revision}
    def route(self, position, goal):
        return {'complete': self.complete, 'points': [goal.tolist()],
                'projectedStart': position.tolist(), 'projectedGoal': goal.tolist()}


def authored_plan(profile='body45cmMargin0', fallback=False):
    radius = .125 if fallback else None
    return {'status': 'selectedPhoneOnlyApproach', 'referenceInputsUsed': False,
            'physicalAuthority': False, 'profile': profile,
            'geometry': variants.geometry(profile, radius),
            'proposalAttempt': 'proposal0125Fallback' if fallback else 'profileDefault',
            'start': [0., 0., 0.], 'goal': [2., 0., 0.], 'initialYawRadians': 0.,
            'mapRevision': FakeMap.revision, 'nativeLibrarySHA256': 'n'*64,
            'approachID': 'authored-A-to-B',
            'nativeInitialRoute': {'complete': True, 'points': [[0., 0., 0.], [2., 0., 0.]],
                                   'mapRevision': FakeMap.revision}}


class ApproachControllerTests(unittest.TestCase):
    def initialize_packet(self):
        return {'command': 'initialize', 'planPath': 'authored', 'planSHA256': 'p'*64,
                'nativeDirectory': 'authored', 'nativeSHA256': 'n'*64}
    def prepare(self, plan=None):
        plan = authored_plan() if plan is None else plan
        model = FakeMap(); calls = []
        def factory(*args): calls.append(args); return model
        c = ApproachController(factory=factory, loader=lambda *args: copy.deepcopy(plan))
        reply = c.consume(self.initialize_packet())
        self.assertFalse(reply['physicalAuthority'])
        c.consume({'command': 'beginRun', 'goal': plan['goal']})
        return c, model, calls
    def tick(self, controller, position, tick=0, age=0., revision=None, pose=True):
        now = 100+tick/15
        delivered = None if not pose else {'kind': 'simulated-physics-body-pose',
            'position': position, 'yaw': 0., 'capturedAt': now-age,
            'mapRevision': controller.revision if revision is None else revision}
        return controller.consume({'command': 'tick', 'tick': tick, 'now': now,
                                   'deliveredPose': delivered})
    def test_reuses_unchanged_tick_with_bounded_candidate(self):
        c, m, _ = self.prepare(); row = self.tick(c, [0., 0., 0.])
        self.assertGreater(row['forwardMetres'], 0.)
        self.assertLessEqual(row['forwardMetres'], .025)
        self.assertFalse(row['physicalAuthority'])
        self.assertTrue(row['permissiveUnknownAdmitted'])
        self.assertEqual(row['phoneFlagReceipt']['lowUnresolvedCells'], 2)
    def test_only_predeclared_goal_is_accepted(self):
        plan = authored_plan(); c = ApproachController(factory=lambda *a: FakeMap(), loader=lambda *a: plan)
        c.consume(self.initialize_packet())
        with self.assertRaises(ValueError): c.consume({'command': 'beginRun', 'goal': [3., 0., 0.]})
        self.assertIsNone(c.goal)
        c.consume({'command': 'beginRun', 'goal': plan['goal']})
        np.testing.assert_array_equal(c.goal, plan['goal'])
    def test_cannot_change_goal_or_begin_twice(self):
        c, _, _ = self.prepare()
        with self.assertRaises(ValueError): c.consume({'command': 'beginRun', 'goal': [2., 0., 0.]})
        with self.assertRaises(ValueError): c.consume({'command': 'advanceGoal', 'goal': [9., 0., 9.]})
    def test_delivered_pose_goal_stop_is_not_world_arrival(self):
        c, _, _ = self.prepare(); row = self.tick(c, [2., 0., 0.])
        self.assertTrue(row['goalReached'])
        self.assertEqual(row['forwardMetres'], 0.)
        self.assertEqual(row['yawRadians'], 0.)
        self.assertNotIn('arrival', row)
    def test_stale_pose_and_missing_pose_stop(self):
        c, _, _ = self.prepare(); row = self.tick(c, [0., 0., 0.], age=.6)
        self.assertEqual(row['reason'], 'staleOrInvalidSimulatedPose')
        self.assertEqual(row['forwardMetres'], 0.)
        row = self.tick(c, [0., 0., 0.], tick=1, pose=False)
        self.assertEqual(row['reason'], 'noDeliveredPose')
        self.assertEqual(row['forwardMetres'], 0.)
    def test_skipped_tick_and_wrong_pose_revision_rejected(self):
        c, _, _ = self.prepare()
        with self.assertRaises(ValueError): self.tick(c, [0., 0., 0.], tick=1)
        with self.assertRaises(ValueError): self.tick(c, [0., 0., 0.], revision='other-map')
    def test_sampled_footprint_withholds_even_at_goal(self):
        c, model, _ = self.prepare(); model.fit = False
        row = self.tick(c, [2., 0., 0.])
        self.assertFalse(row['goalReached'])
        self.assertEqual(row['reason'], 'currentSampledPhoneFootprintWithheld')
    def test_no_complete_route_stops(self):
        c, model, _ = self.prepare(); model.complete = False
        row = self.tick(c, [0., 0., 0.])
        self.assertEqual(row['reason'], 'noCompleteNativeCandidate')
        self.assertEqual(row['forwardMetres'], 0.)
    def test_invalid_plan_never_opens_map(self):
        opened = []
        def invalid(*a): raise ValueError('invalid frozen approach')
        c = ApproachController(factory=lambda *a: opened.append(True), loader=invalid)
        with self.assertRaises(ValueError): c.consume(self.initialize_packet())
        self.assertEqual(opened, [])
    def test_native_identity_mismatch_never_opens_map(self):
        opened = []; plan = authored_plan(); plan['nativeLibrarySHA256'] = 'x'*64
        c = ApproachController(factory=lambda *a: opened.append(True), loader=lambda *a: plan)
        with self.assertRaises(ValueError): c.consume(self.initialize_packet())
        self.assertEqual(opened, [])
    def test_profile_revision_mismatch_closes_model(self):
        model = FakeMap(); plan = authored_plan(); plan['mapRevision'] = 'different'
        c = ApproachController(factory=lambda *a: model, loader=lambda *a: plan)
        with self.assertRaises(ValueError): c.consume(self.initialize_packet())
        self.assertTrue(model.closed)
    def test_fallback_radius_only_bound_to_frozen_abstract_profile(self):
        c, _, calls = self.prepare(authored_plan('abstract28cmProfile', True))
        self.assertEqual(calls, [('abstract28cmProfile', 'authored', 'n'*64, .125)])
    def test_initialize_contract_rejects_extra_fields_and_repeat(self):
        c, _, _ = self.prepare()
        with self.assertRaises(ValueError): c.consume(self.initialize_packet())
        c = ApproachController()
        with self.assertRaises(ValueError): c.consume({**self.initialize_packet(), 'referenceMesh': 'forbidden'})


class FrozenPlanTests(unittest.TestCase):
    def load(self, plan, wrong_hash=False):
        with tempfile.TemporaryDirectory() as directory:
            p = Path(directory)/'authored.json'
            p.write_text(json.dumps(plan))
            digest = '0'*64 if wrong_hash else hashlib.sha256(p.read_bytes()).hexdigest()
            return load_plan(p, digest)
    def test_exact_frozen_authored_plan_loads(self):
        p = authored_plan(); self.assertEqual(self.load(p), p)
    def test_wrong_hash_rejected(self):
        with self.assertRaises(ValueError): self.load(authored_plan(), True)
    def test_truth_or_authority_or_unselected_plan_rejected(self):
        for field, value in [('referenceInputsUsed', True), ('physicalAuthority', True), ('status', 'noRoute')]:
            with self.subTest(field=field):
                p = authored_plan(); p[field] = value
                with self.assertRaises(ValueError): self.load(p)
    def test_geometry_mismatch_rejected(self):
        p = authored_plan(); p['geometry']['width'] = .28
        with self.assertRaises(ValueError): self.load(p)
    def test_incomplete_or_wrong_map_route_rejected(self):
        for field, value in [('complete', False), ('points', []), ('mapRevision', 'different')]:
            with self.subTest(field=field):
                p = authored_plan(); p['nativeInitialRoute'][field] = value
                with self.assertRaises(ValueError): self.load(p)
    def test_nonfinite_goal_and_yaw_rejected(self):
        for field, value in [('goal', [float('nan'), 0., 0.]), ('initialYawRadians', float('inf'))]:
            with self.subTest(field=field):
                p = authored_plan(); p[field] = value
                with self.assertRaises(ValueError): self.load(p)


if __name__ == '__main__': unittest.main(verbosity=2)
