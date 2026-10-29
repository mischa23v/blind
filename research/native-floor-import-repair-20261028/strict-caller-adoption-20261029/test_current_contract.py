"""Mutate current source contracts only; no Swift/runtime claims."""
import unittest
from check_current import load_candidate, validate, INGRESS, INGRESS_TEST, BENCH, BENCH_TEST

class CurrentContractTests(unittest.TestCase):
    def setUp(self):
        self.sources = load_candidate()
        validate(self.sources)

    def reject(self, path, old, new):
        self.assertIn(old, self.sources[path])
        changed = dict(self.sources)
        changed[path] = changed[path].replace(old, new, 1)
        with self.assertRaises(AssertionError):
            validate(changed)

    def test_baseline_current_source(self):
        self.assertGreaterEqual(len(validate(self.sources)), 25)

    def test_refuse_default_activation(self):
        self.reject(INGRESS, 'endpointPolicy: MeshEndpointPolicy = .legacyNearestProjection',
                    'endpointPolicy: MeshEndpointPolicy = .requireSuppliedXZOverPolygon')

    def test_refuse_normal_forwarding_loss(self):
        self.reject(INGRESS, 'supportPolicy: supportPolicy, endpointPolicy: endpointPolicy)', 'supportPolicy: supportPolicy)')

    def test_refuse_debug_forwarding_loss(self):
        self.reject(INGRESS, 'supportPolicy: supportPolicy, endpointPolicy: endpointPolicy,', 'supportPolicy: supportPolicy,')

    def test_refuse_cpu_callback_loss(self):
        self.reject(INGRESS, 'syntheticTimingCompletion: syntheticTimingCompletion)', 'syntheticTimingCompletion: nil)')

    def test_refuse_bench_legacy_fallback(self):
        self.reject(BENCH, 'endpointPolicy: .requireSuppliedXZOverPolygon', 'endpointPolicy: .legacyNearestProjection')

    def test_refuse_legacy_comparator_relabel(self):
        self.reject(INGRESS_TEST, 'print("RESULT:', 'print("RENAMED_RESULT:')

    def test_refuse_any_failure_negative(self):
        self.reject(BENCH_TEST, 'case .failure(.runtime(.nativeFailure)): break', 'case .failure: break')

    def test_refuse_missing_endpoint_receipt_weakened(self):
        self.reject(BENCH_TEST, 'XCTAssertFalse(receipt.goal.found,', 'XCTAssertTrue(receipt.goal.found,')

    def test_refuse_all_rejected_vacuity(self):
        self.reject(BENCH_TEST, 'let after = try queryEndpoints(owner, start: [-1,0,0], goal: [1,0,0]).get()',
                    'let after = original')

if __name__ == '__main__':
    unittest.main()
