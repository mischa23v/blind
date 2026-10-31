"""Bounded stdlib-only fail-closed reproducer controls; no Apple execution."""
import contextlib
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

SPEC = importlib.util.spec_from_file_location('report_parser', Path(__file__).with_name('parse_logs.py'))
m = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(m)


class ReproducerTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.output = self.root / 'result.json'
        self.pins = []
        for original in m.EXPECTED_INPUTS:
            raw = b'BLIND_CI_JOB={"run_id":1}\n'
            path = self.root / original['path']
            path.parent.mkdir(exist_ok=True)
            path.write_bytes(raw)
            self.pins.append(dict(original, bytes=len(raw), sha256=hashlib.sha256(raw).hexdigest()))
        patch = mock.patch.object(m, 'EXPECTED_INPUTS', self.pins)
        patch.start()
        self.addCleanup(patch.stop)

    def invoke(self, output=None):
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            return m.main(['--input-root', str(self.root), '--output', str(output or self.output)])

    def rejects_preserving_output(self):
        self.output.write_bytes(b'published receipt must survive\n')
        with self.assertRaises(SystemExit) as caught:
            self.invoke()
        self.assertEqual(caught.exception.code, 1)
        self.assertEqual(self.output.read_bytes(), b'published receipt must survive\n')
        self.assertEqual(list(self.root.glob('.result.json.*')), [])

    def test_exact_three_valid_inputs(self):
        self.assertEqual(self.invoke(), 0)
        self.assertEqual(len(json.loads(self.output.read_text())['jobs']), 3)

    def test_each_missing_input_fails_before_output(self):
        for item in self.pins:
            with self.subTest(path=item['path']):
                path = self.root / item['path']
                raw = path.read_bytes()
                path.unlink()
                self.rejects_preserving_output()
                path.write_bytes(raw)

    def test_each_hash_mismatch_fails_before_output(self):
        for item in self.pins:
            with self.subTest(path=item['path']):
                path = self.root / item['path']
                raw = path.read_bytes()
                path.write_bytes(raw[:-1] + b'!')
                self.rejects_preserving_output()
                path.write_bytes(raw)

    def test_missing_all_creates_no_output(self):
        for item in self.pins:
            (self.root / item['path']).unlink()
        with self.assertRaises(SystemExit):
            self.invoke()
        self.assertFalse(self.output.exists())

    def test_unrelated_log_is_not_read(self):
        (self.root / 'apple-candidate-561532e/unrelated-job.log').write_bytes(b'not an input')
        self.assertEqual(self.invoke(), 0)
        self.assertEqual(len(json.loads(self.output.read_text())['jobs']), 3)

    def test_changed_size_rejected(self):
        (self.root / self.pins[0]['path']).write_bytes(b'changed size')
        self.rejects_preserving_output()

    def test_log_symlink_rejected(self):
        target = self.root / self.pins[0]['path']
        target.unlink()
        target.symlink_to(self.root / self.pins[1]['path'])
        self.rejects_preserving_output()

    def test_input_size_cap_checked_before_read(self):
        with mock.patch.object(m, 'MAX_LOG_BYTES', 1):
            self.rejects_preserving_output()

    def test_output_size_cap_preserves_previous(self):
        with mock.patch.object(m, 'MAX_OUTPUT_BYTES', 1):
            self.rejects_preserving_output()

    def test_malformed_pinned_log_preserves_previous(self):
        raw = b'BLIND_CI_JOB={bad}\n'
        path = self.root / self.pins[0]['path']
        path.write_bytes(raw)
        self.pins[0].update(bytes=len(raw), sha256=hashlib.sha256(raw).hexdigest())
        self.rejects_preserving_output()

    def test_output_cannot_alias_input(self):
        path = self.root / self.pins[0]['path']
        before = path.read_bytes()
        with self.assertRaises(SystemExit):
            self.invoke(output=path)
        self.assertEqual(path.read_bytes(), before)

    def test_output_symlink_rejected(self):
        target = self.root / 'sentinel'
        target.write_bytes(b'preserve')
        self.output.symlink_to(target)
        with self.assertRaises(SystemExit):
            self.invoke()
        self.assertEqual(target.read_bytes(), b'preserve')

    def test_cli_requires_both_explicit_arguments(self):
        for args in ([], ['--input-root', str(self.root)], ['--output', str(self.output)]):
            with self.subTest(args=args), contextlib.redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit) as caught:
                    m.main(args)
                self.assertEqual(caught.exception.code, 2)
        self.assertFalse(self.output.exists())


if __name__ == '__main__':
    unittest.main()
