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

    def test_only_three_scoped_workflows_disable_uploads_and_emit_receipts(self):
        root = HERE.parents[1]
        for name in ['native-apple', 'body-profile-current', 'mesh-candidate-ingress']:
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


if __name__ == '__main__':
    unittest.main()
