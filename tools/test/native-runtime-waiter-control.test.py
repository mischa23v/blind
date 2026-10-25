#!/usr/bin/env python3
"""Synthetic control-infrastructure contracts; no Apple or production behavior claim."""
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / 'ci/native-runtime-waiter-control.py'
spec = importlib.util.spec_from_file_location('control', SCRIPT)
control = importlib.util.module_from_spec(spec)
spec.loader.exec_module(control)


class ControlTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.out = Path(self.temp.name)
        self.names = {f'testCase{i}' for i in range(17)}

    def records(self, mode='publication-v1'):
        return [f'NATIVE_RUNTIME_WAITER_MODE mode={mode} test=-[ConnectedJourneyRuntimeTests {n}]' for n in sorted(self.names)]

    def test_runner_guard_rejects_missing_self_hosted_and_unknown(self):
        for value in (None, 'self-hosted', '', 'unknown'):
            env = {} if value is None else {'RUNNER_ENVIRONMENT': value}
            with patch.dict(os.environ, env, clear=True):
                with self.assertRaises(RuntimeError):
                    control.require_hosted_runner()
        with patch.dict(os.environ, {'RUNNER_ENVIRONMENT': 'github-hosted'}, clear=True):
            control.require_hosted_runner()
        self.assertIn('def main(source):\n    require_hosted_runner()', SCRIPT.read_text())

    def test_candidate_requires_identical_methods_and_assertions(self):
        tail = '    private func installed() {}\n' + ''.join(f'    func testCase{i}() {{ XCTAssertTrue(true) }}\n' for i in range(17))
        self.assertEqual(control.verify_test_copy('old waiter\n' + tail, 'new waiter\n' + tail), self.names)
        with self.assertRaises(RuntimeError):
            control.verify_test_copy(tail, tail.replace('XCTAssertTrue(true)', 'XCTAssertTrue(false)', 1))
        with self.assertRaises(RuntimeError):
            control.verify_test_copy(tail, tail.replace('testCase0', 'testDifferent'))

    def test_mode_proof_requires_exact_mode_names_and_count(self):
        log = self.out / 'log'
        with contextlib.redirect_stdout(io.StringIO()):
            for records, expected in ((self.records(), True), (self.records('original-v1'), False),
                                      (self.records()[:-1], False), (self.records() + self.records()[:1], False),
                                      ([self.records()[0]] * 17, False)):
                log.write_text('\n'.join(records))
                self.assertEqual(control.mode_proof(log, 'publication-v1', self.names), expected)

    def test_first_functional_failure_does_not_skip_second(self):
        calls = []
        def arm(mode, owned, *args):
            calls.append((mode, owned))
            return {'mode': mode, 'attempted': True, 'valid': mode == 'original-v1'}
        with patch.object(control, 'create_device', return_value='SECOND') as create, \
             patch.object(control, 'device_state', return_value='Shutdown'), \
             patch.object(control, 'run_arm', side_effect=arm), \
             patch.object(control, 'cleanup', return_value=True) as cleanup, \
             patch.object(control, 'emit'):
            result = control.fixed_pair('FIRST', self.out, self.out, self.out, self.names, 'fingerprint')
        self.assertEqual(result, 1)
        self.assertEqual(calls, [('publication-v1', 'FIRST'), ('original-v1', 'SECOND')])
        self.assertEqual(create.call_count, 1)
        self.assertEqual([c.args[0] for c in cleanup.call_args_list], ['FIRST', 'SECOND'])

    def test_first_infrastructure_failure_never_becomes_test_result(self):
        events = []
        def arm(mode, *args):
            if mode == 'publication-v1':
                raise RuntimeError('synthetic pre-test failure')
            return {'mode': mode, 'attempted': True, 'valid': True}
        with patch.object(control, 'create_device', return_value='SECOND'), \
             patch.object(control, 'device_state', return_value='Shutdown'), \
             patch.object(control, 'run_arm', side_effect=arm), \
             patch.object(control, 'cleanup', return_value=True), \
             patch.object(control, 'emit', side_effect=lambda **v: events.append(v)):
            self.assertEqual(control.fixed_pair('FIRST', self.out, self.out, self.out, self.names, 'f'), 1)
        results = events[-1]['results']
        self.assertFalse(results[0]['attempted'])
        self.assertTrue(results[1]['attempted'])

    def test_cleanup_delete_is_attempted_even_after_shutdown_error(self):
        calls = []
        def run(command, *args, **kwargs):
            calls.append(command)
            if command[2] == 'shutdown':
                raise OSError('synthetic')
            return 0
        with patch.object(control, 'run', side_effect=run), patch.object(control, 'emit'):
            self.assertTrue(control.cleanup('OWNED', self.out, 'publication-v1'))
        self.assertEqual(calls, [['xcrun', 'simctl', 'shutdown', 'OWNED'], ['xcrun', 'simctl', 'delete', 'OWNED']])
        self.assertNotIn('all', str(calls))

    def test_both_success_is_only_success_and_cleanup_failure_stays_red(self):
        for cleanup_ok, expected in ((True, 0), (False, 1)):
            with patch.object(control, 'create_device', return_value='SECOND'), \
                 patch.object(control, 'device_state', return_value='Shutdown'), \
                 patch.object(control, 'run_arm', side_effect=lambda mode, *a: {'mode': mode, 'attempted': True, 'valid': True}), \
                 patch.object(control, 'cleanup', return_value=cleanup_ok), patch.object(control, 'emit'):
                self.assertEqual(control.fixed_pair('FIRST', self.out, self.out, self.out, self.names, 'f'), expected)

    def test_control_excerpt_capped_and_does_not_copy_arbitrary_output(self):
        log = self.out / 'log'
        log.write_text('not metadata secret-value\n' +
                       ''.join('NATIVE_RUNTIME_CONTROL test=synthetic ' + 'x' * 2100 + '\n' for _ in range(405)))
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            control.control_excerpt(log, 'publication-v1')
        text = output.getvalue()
        self.assertEqual(len(text.splitlines()), 401)
        self.assertNotIn('secret-value', text)
        self.assertIn('"omitted": 5', text)
        self.assertIn('"clipped_lines": 400', text)

    def test_command_same_selector_and_no_retry(self):
        command = control.test_command(self.out, 'OWNED', self.out / 'result')
        self.assertEqual(command[-1], 'test-without-building')
        self.assertIn('-only-testing:BlindAssistTests/ConnectedJourneyRuntimeTests', command)
        self.assertIn('platform=iOS Simulator,id=OWNED', command)
        self.assertNotIn('-retry-tests-on-failure', command)
        build = command[:-3] + ['build-for-testing']
        self.assertNotIn('-resultBundlePath', build)
        self.assertNotIn('test-without-building', build)

    def test_fingerprint_changes_when_built_code_changes(self):
        products = self.out / 'Build/Products/Debug-iphonesimulator'
        app = products / 'BlindAssist.app'; bundle = products / 'BlindAssistTests.xctest'
        app.mkdir(parents=True); bundle.mkdir()
        (app / 'BlindAssist').write_bytes(b'host')
        (bundle / 'BlindAssistTests').write_bytes(b'tests')
        first = control.app_fingerprint(self.out)
        self.assertEqual(control.app_fingerprint(self.out), first)
        (bundle / 'BlindAssistTests').write_bytes(b'changed')
        self.assertNotEqual(control.app_fingerprint(self.out), first)

    def test_runtime_evidence_error_preserves_actual_attempt(self):
        with patch.object(control, 'device_state', return_value='Shutdown'), \
             patch.object(control, 'app_fingerprint', return_value='f'), \
             patch.object(control, 'run', return_value=0), \
             patch.object(control, 'mode_proof', side_effect=OSError('synthetic missing log')), \
             patch.object(control, 'emit'):
            result = control.run_arm('publication-v1', 'OWNED', self.out, self.out, self.out, self.names, 'f')
        self.assertTrue(result['attempted'])
        self.assertFalse(result['valid'])
        self.assertEqual(result['test_exit'], 0)

    def test_infrastructure_build_and_test_caps_unchanged(self):
        source = SCRIPT.read_text()
        self.assertIn("run(command, 1200, out / 'build.log'", source)
        self.assertIn('run(test_command(derived, owned, result), 900, log', source)
        self.assertIn("['xcrun', 'simctl', 'bootstatus', owned, '-b'], 180", source)
        self.assertIn("TEST_BLOB = 'e362684225254aa8c5c7c69e01ea92fcd4f980bc'", source)
        self.assertIn("SOURCE = 'de0da00424b5dd3cae9e98e67894eddcffc74447'", source)
        self.assertIn("baseline.split(marker, 1)[1] != candidate.split(marker, 1)[1]", source)
        self.assertIn("only_reviewed_test_substitution=unchanged", source)


if __name__ == '__main__':
    unittest.main()
