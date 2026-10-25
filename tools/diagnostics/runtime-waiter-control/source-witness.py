from pathlib import Path
import re
import unittest
ROOT = Path(__file__).resolve().parent
BASE = (ROOT/'Baseline.swift').read_text()
CANDIDATE = (ROOT/'ConnectedJourneyRuntimeTests.swift').read_text()
class SourceWitness(unittest.TestCase):
    def test_latch_witness_uses_actual_candidate_helper(self):
        helper = (ROOT/'PublicationDeadlineLatch.swift').read_text().replace('import Foundation\n', '', 1)
        self.assertIn(helper, CANDIDATE)
    def test_all_seventeen_bodies_and_assertions_identical(self):
        # Entire tail, including every test method and fixture helper, is byte-identical.
        marker = '    private func installed('
        self.assertEqual(BASE[BASE.index(marker):], CANDIDATE[CANDIDATE.index(marker):])
        self.assertEqual(len(re.findall(r'    func test\w+\(', BASE)), 17)
    def test_original_waiter_body_identical(self):
        start = '        if condition() { return }'
        end = '    private func installed('
        original = BASE[BASE.index(start):BASE.index(end)]
        candidate = CANDIDATE[CANDIDATE.index(start):CANDIDATE.index('    // Isolated control only.')]
        self.assertEqual(original, candidate)
    def test_candidate_absolute_gate_and_single_wake(self):
        candidate = CANDIDATE[CANDIDATE.index('    private func untilPublication('):CANDIDATE.index('    private func installed(')]
        self.assertIn('startedInstant.advanced(by: .seconds(3))', candidate)
        self.assertEqual(candidate.count('Task {'), 1)
        self.assertEqual(candidate.count('withCheckedContinuation'), 1)
        self.assertNotIn('fulfillment(', candidate)
        self.assertNotIn('priority:', candidate)
        self.assertIn('defer { runtime.onChange = previous; latch.cancel() }', candidate)
        self.assertLess(candidate.index('let observed = condition()'), candidate.index('let instant = clock.now'))
        self.assertIn('guard result == .timely else', candidate)
        self.assertIn('if result == .cancelled { throw CancellationError() }', candidate)
    def test_mode_is_explicit_and_observer_calls_previous_first(self):
        self.assertIn('NATIVE_RUNTIME_WAITER_MODE mode=', CANDIDATE)
        self.assertIn('guard waiterControlMode == "original-v1" else', CANDIDATE)
        candidate = CANDIDATE[CANDIDATE.index('    private func untilPublication('):]
        self.assertLess(candidate.index('previous?()'), candidate.index('let observed = condition()'))
if __name__ == '__main__': unittest.main()
