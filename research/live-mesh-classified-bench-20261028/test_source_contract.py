"""Mutation tests of source contracts, NOT Swift/runtime/sensor tests."""
import unittest
from check_source import FILES, load_sources, validate

class SourceContractTests(unittest.TestCase):
    def setUp(self):
        validate(load_sources()) # A failing baseline must never make mutations pass.

    def test_current_source_contract(self):
        self.assertGreaterEqual(len(validate(load_sources())), 40)

    def refused(self, path, old, new):
        sources = load_sources()
        self.assertIn(old, sources[path])
        sources[path] = sources[path].replace(old, new, 1)
        with self.assertRaises(AssertionError):
            validate(sources)

    def test_reject_legacy_policy(self):
        self.refused(FILES[1], '.classifiedFloorOnly', '.legacySlope')

    def test_reject_gap_gate_removal(self):
        self.refused(FILES[1], 'guard Self.hasCompleteSource(candidate) else', 'guard true else')

    def test_reject_either_gate_instead_of_both(self):
        self.refused(FILES[1], 'sourceDeliveryComplete && candidate.route.unknownCoverage.isEmpty',
                     'sourceDeliveryComplete || candidate.route.unknownCoverage.isEmpty')

    def test_reject_unguarded_is_current(self):
        self.refused(FILES[1], 'Self.hasCompleteSource(candidate) && active(generation)', 'active(generation)')

    def test_reject_unclassified_device_fallback(self):
        self.refused(FILES[2], 'supportsSceneReconstruction(.meshWithClassification) else', 'supportsSceneReconstruction(.mesh) else')

    def test_reject_new_session(self):
        self.refused(FILES[2], 'let configuration = ARWorldTrackingConfiguration()', 'let other = ARSession(); let configuration = ARWorldTrackingConfiguration()')

    def test_reject_physical_authority(self):
        self.refused(FILES[1], 'authorizesPhysicalGuidance = false', 'authorizesPhysicalGuidance = true')

    def test_reject_copy_budget_expansion(self):
        self.refused(FILES[1], 'maxCopies: 1,', 'maxCopies: 2,')

    def test_reject_native_lifecycle_change(self):
        self.refused(FILES[2], 'session.pause()', 'session.pause(); session.delegate = nil')

    def test_reject_weak_native_negative_assertion(self):
        self.refused(FILES[3], 'case .failure(.runtime(.nativeFailure)): break', 'case .failure: break')

if __name__ == '__main__':
    unittest.main()
