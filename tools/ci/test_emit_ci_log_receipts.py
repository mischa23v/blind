"""Small synthetic receipt tests; no Apple commands, network or CI dispatch."""
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

HERE = Path(__file__).parent
SPEC = importlib.util.spec_from_file_location('receipts', HERE / 'emit-ci-log-receipts.py')
M = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(M)


class ReceiptTests(unittest.TestCase):
    def receipt(self, value):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'receipt.json'
            path.write_text(json.dumps(value))
            return M.read_receipt(Path(folder), 'receipt.json')

    def test_failure_counts_and_skips_are_not_changed(self):
        source = {'status': 'failed', 'counts': {'Passed': 3, 'Failed': 2, 'Skipped': 1},
                  'exit_code': 65, 'complete': False}
        self.assertEqual(self.receipt(source)['metadata'], source)

    def test_case_statuses_survive_without_raw_geometry_or_errors(self):
        source = {'cases': [{'identifier': 'Tests/testOwned()', 'result': 'Failed',
                             'private_capture': 'excluded'}],
                  'error': 'excluded', 'routeDiagnosticEvidence': {'geometry': 'excluded'}}
        result = self.receipt(source)['metadata']
        self.assertEqual(result['cases'], [{'identifier': 'Tests/testOwned()', 'result': 'Failed'}])
        self.assertNotIn('excluded', json.dumps(result))

    def test_missing_is_unavailable_not_zero_tests_or_passed(self):
        with tempfile.TemporaryDirectory() as folder:
            result = M.read_receipt(Path(folder), 'absent.json')
        self.assertEqual(result['availability'], 'unavailable')
        self.assertNotIn('metadata', result)

    def test_invalid_json_is_unavailable(self):
        with tempfile.TemporaryDirectory() as folder:
            (Path(folder) / 'a.json').write_text('{')
            self.assertEqual(M.read_receipt(Path(folder), 'a.json')['availability'], 'unavailable')

    def test_non_object_is_unavailable(self):
        self.assertEqual(self.receipt([])['availability'], 'unavailable')

    def test_oversized_input_is_unavailable(self):
        with tempfile.TemporaryDirectory() as folder:
            (Path(folder) / 'a.json').write_bytes(b' ' * (M.INPUT_LIMIT + 1))
            self.assertEqual(M.read_receipt(Path(folder), 'a.json')['availability'], 'unavailable')

    def test_symlink_is_not_followed(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'real.json').write_text('{}')
            (root / 'link.json').symlink_to(root / 'real.json')
            self.assertEqual(M.read_receipt(root, 'link.json')['availability'], 'unavailable')

    def test_parent_symlink_is_not_followed(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'real').mkdir()
            (root / 'real/a.json').write_text('{}')
            (root / 'link').symlink_to(root / 'real', target_is_directory=True)
            self.assertEqual(M.read_receipt(root, 'link/a.json')['availability'], 'unavailable')

    def test_fifo_is_not_read(self):
        with tempfile.TemporaryDirectory() as folder:
            os.mkfifo(Path(folder) / 'pipe')
            self.assertEqual(M.read_receipt(Path(folder), 'pipe')['availability'], 'unavailable')

    def test_cases_over_output_budget_are_explicit_and_counts_retained(self):
        source = {'counts': {'Failed': 2048},
                  'cases': [{'identifier': 'A' * 500, 'result': 'Failed'}] * 1600}
        result = self.receipt(source)
        self.assertEqual(result['metadata']['case_projection'], 'omitted_over_budget')
        self.assertEqual(result['metadata']['case_records_in_input'], 1600)
        self.assertEqual(result['metadata']['counts']['Failed'], 2048)
        self.assertLess(len(M.encode(result).encode()), M.OUTPUT_LIMIT)

    def test_injected_markup_and_commands_are_not_emitted_as_values(self):
        result = self.receipt({'status': '```\n::warning::payload',
                               'error': 'private'})['metadata']
        self.assertEqual(result, {})

    def test_incomplete_body_coverage_events_retained(self):
        result = self.receipt({'verified': False, 'events': {'testA': ['started', 'failed'],
                                                          'testB': []}})['metadata']
        self.assertFalse(result['verified'])
        self.assertEqual(result['events']['testB'], [])

    def test_failed_job_and_skipped_steps_in_log_and_summary(self):
        with tempfile.TemporaryDirectory() as folder:
            summary = Path(folder) / 'summary'
            env = {'RUNNER_TEMP': folder, 'GITHUB_STEP_SUMMARY': str(summary),
                   'GITHUB_SHA': 'a' * 40, 'GITHUB_RUN_ID': '123', 'GITHUB_RUN_ATTEMPT': '1',
                   'CI_JOB_STATUS': 'failure', 'BLIND_UPLOAD_ARTIFACTS': 'false',
                   'CI_STEP_OUTCOMES': json.dumps({'fixtures': {'outcome': 'failure',
                                                              'conclusion': 'failure',
                                                              'outputs': {'secret': 'never print'}},
                                                  'later': {'outcome': 'skipped'}})}
            output = io.StringIO()
            with patch.dict(os.environ, env, clear=True), patch('sys.argv', ['emit', 'ingress']), contextlib.redirect_stdout(output):
                M.main()
            lines = output.getvalue().splitlines()
            job = json.loads(lines[0].split('=', 1)[1])
            self.assertEqual(job['job_status_before_receipt'], 'failure')
            self.assertEqual(job['steps']['later']['outcome'], 'skipped')
            self.assertFalse(job['artifact_uploads_enabled'])
            self.assertNotIn('never print', output.getvalue())
            self.assertIn(output.getvalue().strip(), summary.read_text())
            self.assertEqual(json.loads(lines[1].split('=', 1)[1])['availability'], 'unavailable')

    def test_five_scoped_workflows_disable_uploads_and_emit_receipts(self):
        root = HERE.parents[1]
        for name in ['native-apple', 'body-profile-current', 'mesh-candidate-ingress', 'native-room-mesh-package', 'native-edt-navigation-probe']:
            text = (root / '.github/workflows' / (name + '.yml')).read_text()
            self.assertIn("BLIND_UPLOAD_ARTIFACTS: 'false'", text)
            lines = text.splitlines()
            for index, line in enumerate(lines):
                if 'uses: actions/upload-artifact@' in line:
                    self.assertIn("env.BLIND_UPLOAD_ARTIFACTS == 'true'", lines[index - 1])
            self.assertIn('if: always()\n        timeout-minutes: 1\n', text)
            self.assertIn('run: python3 -B tools/ci/emit-ci-log-receipts.py ', text)
            self.assertNotIn('actions/cache@', text)
            self.assertNotIn('continue-on-error', text)

    def test_room_mesh_summary_retains_counts_and_compile_only_limits(self):
        source = {'sourceCommit': 'a' * 40, 'swiftPMBuildSystem': 'native',
                  'defaultSwiftBuildBackendPassed': False, 'macOSSwiftPMPackageBuilt': True,
                  'publicImportedClientExecuted': True, 'legacyChecks': 55, 'runtimeChecks': 32,
                  'failureCommitChecks': 5, 'discardChecks': 19,
                  'iOSSimulatorPackageAndClientLinked': True, 'iOSSimulatorExecuted': False,
                  'appProjectBuilt': False, 'ARKitExecuted': False, 'physicalAuthority': False,
                  'publicExclusionUpdatesImplemented': False}
        self.assertEqual(self.receipt(source)['metadata'], source)

    def test_room_mesh_receipt_never_reads_route_geometry(self):
        self.assertEqual(M.RECEIPTS['room-mesh'], ['blind-room-mesh-75/SUMMARY.json',
                         'blind-room-mesh-75/RESULT.json', 'blind-room-mesh-75/RUNTIME_RESULT.json'])
        self.assertNotIn('ROUTE_DIAGNOSTIC', str(M.RECEIPTS['room-mesh']))
        result = self.receipt({'passed': False, 'geometry': [1,2,3], 'error': 'private',
                               'receipts': [{'command': 'secret'}]})['metadata']
        self.assertEqual(result, {'passed': False})


    def test_edt_refusal_preserves_failure_without_error_or_geometry(self):
        source = {'status': 'failed-or-inconclusive-diagnostic', 'sourceCommit': 'a' * 40,
                  'appActivation': False, 'physicalAuthority': False,
                  'error': 'private failure details', 'sourcePins': {'private': 'never'},
                  'commands': [{'command': 'never'}], 'rows': [{'geometry': [1, 2, 3]}]}
        result = self.receipt(source)['metadata']
        self.assertEqual(result, {k: source[k] for k in ('status', 'sourceCommit', 'appActivation', 'physicalAuthority')})
        self.assertNotIn('candidateExecuted', result)
        self.assertNotIn('all50OriginalControlsReproduced', result)

    def test_edt_candidate_failure_and_original_control_counts_are_retained(self):
        source = {'status': 'candidate-goals-not-met', 'all50OriginalControlsReproduced': True,
                  'candidateExecuted': True, 'candidateRequests': 25, 'candidateGoalsMet': False,
                  'physicalAuthority': False, 'appActivation': False, 'resultSHA256': 'b' * 64,
                  'nativeHookChecks': {'schema': 1, 'checks': 51, 'passed': 51, 'physicalAuthority': False}}
        self.assertEqual(self.receipt(source)['metadata'], source)

    def test_edt_hook_projection_omits_arbitrary_payload(self):
        result = self.receipt({'nativeHookChecks': {'checks': 51, 'passed': 50,
                                                   'error': 'private', 'geometry': [1, 2, 3]}})['metadata']
        self.assertEqual(result, {'nativeHookChecks': {'checks': 51, 'passed': 50}})

    def test_edt_receipts_are_fixed_json_not_raw_logs(self):
        self.assertEqual(M.RECEIPTS['edt-navigation-probe'], ['blind-edt-navigation-probe/receipt.json',
                         'blind-edt-navigation-probe/RESULT.json'])

    def test_edt_early_failure_logs_unavailable_result_and_original_step_failure(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'blind-edt-navigation-probe').mkdir()
            (root / 'blind-edt-navigation-probe/receipt.json').write_text(json.dumps({
                'status': 'failed-or-inconclusive-diagnostic', 'error': 'private pin mismatch',
                'physicalAuthority': False, 'appActivation': False}))
            summary = root / 'summary'
            env = {'RUNNER_TEMP': folder, 'GITHUB_STEP_SUMMARY': str(summary),
                   'CI_JOB_STATUS': 'failure', 'BLIND_UPLOAD_ARTIFACTS': 'false',
                   'CI_STEP_OUTCOMES': json.dumps({'fixtures': {'outcome': 'failure', 'conclusion': 'failure'}})}
            output = io.StringIO()
            with patch.dict(os.environ, env, clear=True), patch('sys.argv', ['emit', 'edt-navigation-probe']), contextlib.redirect_stdout(output):
                M.main()
            values = [json.loads(line.split('=', 1)[1]) for line in output.getvalue().splitlines()]
            self.assertEqual(len(values), 3)
            self.assertEqual(values[0]['steps']['fixtures']['outcome'], 'failure')
            self.assertFalse(values[0]['artifact_uploads_enabled'])
            self.assertEqual(values[1]['metadata']['status'], 'failed-or-inconclusive-diagnostic')
            self.assertEqual(values[2]['availability'], 'unavailable')
            self.assertNotIn('private', output.getvalue())
            self.assertIn(output.getvalue().strip(), summary.read_text())

    def test_edt_current_versus_historical_oracle_provenance_is_preserved(self):
        bridge = {'schema': 1, 'historicalRunnerSHA256': 'a' * 64,
                  'historicalPinManifestSHA256': 'b' * 64, 'historicalOracleSHA256': 'c' * 64,
                  'currentOracleSHA256': 'd' * 64, 'reversedOracleSHA256': 'c' * 64,
                  'oracleKernelByteIdentical': True, 'generatedRunnerSHA256': 'e' * 64,
                  'runnerReverseByteIdentical': True, 'compileFlagAdded': 'BLIND_COLLISION_ORACLE_TESTS',
                  'physicalAuthority': False, 'algorithmChanged': False, 'originalControlsRequired': 50,
                  'nativeHookChecksRequired': 51, 'candidateRequestsUnchanged': 25,
                  'historicalSourceFilesModified': False}
        self.assertEqual(self.receipt({'oracleBridgeProvenance': bridge})['metadata'],
                         {'oracleBridgeProvenance': bridge})

    def test_edt_adapter_provenance_cannot_emit_error_or_geometry(self):
        source = {'oracleBridgeProvenance': {'oracleKernelByteIdentical': False,
                  'algorithmChanged': True, 'error': 'private', 'geometry': [1, 2, 3],
                  'sourcePins': {'private': 'value'}, 'compileFlagAdded': '```\n::warning::private'}}
        self.assertEqual(self.receipt(source)['metadata'], {'oracleBridgeProvenance': {
                         'oracleKernelByteIdentical': False, 'algorithmChanged': True}})

if __name__ == '__main__':
    unittest.main()
