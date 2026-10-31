"""Execute only the checker's metadata formatter; no native/model execution."""
import ast
import contextlib
import io
import json
import os
from pathlib import Path
import re
from types import SimpleNamespace
import unittest

ROOT = Path(os.environ.get('BLIND_SOURCE_ROOT', Path(__file__).resolve().parents[2]))
tree = ast.parse((ROOT / 'research/native-candidate-app-integration-85/integrated/check.py').read_text())
fn = next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == 'j01_portable_failure')
scope = {'json': json, 're': re}
exec(compile(ast.Module(body=[fn], type_ignores=[]), '<isolated formatter>', 'exec'), scope)


def run(code, stderr):
    output = io.StringIO()
    with contextlib.redirect_stdout(output):
        accepted = scope['j01_portable_failure']('fixed-reviewed-test.py', SimpleNamespace(returncode=code, stderr=stderr))
    return accepted, output.getvalue()


class Tests(unittest.TestCase):
    def test_success_stays_quiet(self):
        self.assertEqual(run(0, b'PRIVATE'), (True, ''))

    def test_alias_failure_metadata_preserved(self):
        accepted, output = run(1, b'ERROR: test_owned_temp (__main__.Fixture.test_owned_temp)\nValueError: symlink component refused\n')
        self.assertFalse(accepted)
        value = json.loads(output.split('=', 1)[1])
        self.assertEqual(value['returncode'], 1)
        self.assertEqual(value['records'], [{'kind': 'ERROR', 'test': 'test_owned_temp'}, {'errorType': 'ValueError', 'reason': 'symlink_component_refused'}])

    def test_arbitrary_messages_paths_and_arguments_not_emitted(self):
        _, output = run(1, b'File "/PRIVATE/secret.py", line 20\nValueError: PRIVATE_KEY=abc\nFAIL: test_safe (PRIVATE argument)\nPRIVATE arbitrary model reply\n')
        self.assertNotIn('PRIVATE', output)
        self.assertNotIn('secret.py', output)
        self.assertNotIn('abc', output)
        self.assertEqual(json.loads(output.split('=', 1)[1])['records'], [{'errorType': 'ValueError'}, {'kind': 'FAIL', 'test': 'test_safe'}])

    def test_output_and_input_observation_are_bounded(self):
        _, output = run(7, b'PRIVATE' * 10000 + b'\n' + (b'ValueError: symlink component refused\n' * 1000))
        value = json.loads(output.split('=', 1)[1])
        self.assertEqual(len(value['records']), 24)
        self.assertLessEqual(value['stderrTailBytesExamined'], 16384)
        self.assertLess(len(output.encode()), 8192)


if __name__ == '__main__':
    unittest.main()
