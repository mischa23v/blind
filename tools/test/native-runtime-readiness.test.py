"""Synthetic command/summary witnesses; these are not Apple execution evidence."""
import importlib.util
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from contextlib import redirect_stdout
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('readiness', ROOT / 'tools/ci/native-runtime-readiness.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
OWNED = 'AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE'


class ReadinessTests(unittest.TestCase):
    def witness(self, mode='pass'):
        calls = []
        def capture(command):
            calls.append(command)
            if command[0] == 'uname': return 'Darwin'
            if command[0] == 'git': return 'synthetic-source'
            if 'devicetypes' in command:
                return json.dumps({'devicetypes': [{'identifier': m.DEVICE_TYPE}]})
            if 'runtimes' in command:
                return json.dumps({'runtimes': [{'identifier': m.RUNTIME, 'isAvailable': True}]})
            if 'create' in command: return OWNED
            if 'devices' in command:
                return json.dumps({'devices': {m.RUNTIME: [{'udid': OWNED, 'state': 'Shutdown'}]}})
            raise AssertionError(command)
        def run(command, timeout, log):
            calls.append(command)
            log.write_text('')
            if 'build-for-testing' in command and mode == 'build-fail': return 65
            if 'bootstatus' in command and 'help' not in command and mode == 'boot-fail': return 124
            if 'test-without-building' in command and mode == 'test-fail': return 65
            if 'summary' in command:
                if mode == 'missing-summary': return 1
                summary = {'result': 'Passed', 'totalTestCount': 17, 'passedTests': 17,
                           'failedTests': 0, 'skippedTests': 0}
                if mode == 'zero-tests': summary.update(totalTestCount=0, passedTests=0)
                if mode == 'skipped': summary.update(passedTests=16, skippedTests=1)
                if mode == 'malformed': log.write_text('not-json'); return 0
                log.write_text(json.dumps(summary))
            if 'delete' in command and mode == 'cleanup-fail': return 1
            return 0
        with tempfile.TemporaryDirectory() as temp, patch.dict(os.environ, RUNNER_TEMP=temp, DEVELOPER_DIR=temp), \
             patch.object(m, 'capture', side_effect=capture), patch.object(m, 'run', side_effect=run), \
             patch.object(m.subprocess, 'run') as extract, redirect_stdout(io.StringIO()) as output:
            extract.return_value.returncode = 0
            status = m.main()
        return status, calls, output.getvalue()

    def test_one_boot_ready_cold_app_attempt(self):
        status, calls, output = self.witness()
        self.assertEqual(status, 0)
        self.assertEqual(sum('test-without-building' in c for c in calls), 1)
        boot = next(i for i,c in enumerate(calls) if 'bootstatus' in c and '-b' in c)
        test = next(i for i,c in enumerate(calls) if 'test-without-building' in c)
        self.assertLess(boot, test)
        self.assertIn('"completed": 1', output)
        self.assertIn('"pre_state": "Shutdown"', output)
        for c in calls:
            if 'shutdown' in c or 'delete' in c: self.assertEqual(c[-1], OWNED)
        tests = calls[test]
        self.assertIn('-only-testing:BlindAssistTests/ConnectedJourneyRuntimeTests', tests)
        self.assertIn('-parallel-testing-enabled', tests)
        self.assertNotIn('launch', [x for c in calls for x in c])

    def test_each_failure_is_final_without_retry(self):
        for mode in ['test-fail', 'missing-summary', 'zero-tests', 'skipped', 'malformed', 'cleanup-fail']:
            with self.subTest(mode=mode):
                status, calls, _ = self.witness(mode)
                self.assertEqual(status, 1)
                self.assertEqual(sum('test-without-building' in c for c in calls), 1)
                self.assertEqual(sum('delete' in c for c in calls), 1)

    def test_infrastructure_failure_never_runs_test(self):
        for mode in ['build-fail', 'boot-fail']:
            with self.subTest(mode=mode):
                status, calls, output = self.witness(mode)
                self.assertEqual(status, 1)
                self.assertFalse(any('test-without-building' in c for c in calls))
                self.assertIn('"not_run": 1', output)
                self.assertEqual(sum('delete' in c for c in calls), 1)

    def test_failure_excerpt_bounded_and_redacted(self):
        with tempfile.TemporaryDirectory() as temp, redirect_stdout(io.StringIO()) as output:
            log = Path(temp)/'failure.log'
            log.write_text('private unrelated payload\n' + ('error: destination /Users/example/secret/path unavailable\n' * 90))
            m.failure_excerpt(log)
        text = output.getvalue()
        self.assertNotIn('/Users/', text)
        self.assertNotIn('private unrelated payload', text)
        self.assertEqual(text.count('"redacted": true'), 60)
        self.assertIn('"capped": true', text)

    def test_real_deadline_witness(self):
        import sys
        with tempfile.TemporaryDirectory() as temp, redirect_stdout(io.StringIO()) as output:
            result = m.run([sys.executable, '-c', 'import time; time.sleep(10)'], .02, Path(temp)/'deadline.log')
        self.assertEqual(result, 124)
        self.assertIn('elapsed_seconds', output.getvalue())

    def test_trigger_scope_and_no_warmup(self):
        text = (ROOT/'.github/workflows/native-runtime-readiness.yml').read_text()
        paths = text.split('    paths:')[1].split('  workflow_dispatch:')[0]
        self.assertEqual(paths.count('      - '), 2)
        self.assertNotIn('*', paths)
        self.assertIn('github.event.repository.private == false', text)
        self.assertIn('native-runtime-readiness-${{ github.ref }}', text)
        self.assertIn('cancel-in-progress: false', text)
        source = (ROOT/'tools/ci/native-runtime-readiness.py').read_text()
        self.assertNotIn('time.sleep(', source)
        self.assertNotIn('for attempt', source)
        self.assertIn("'bootstatus', owned, '-b'], 180", source)
        self.assertIn('counts == [17, 17, 0, 0]', source)

if __name__ == '__main__': unittest.main()
