import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import sys
import unittest

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('receipt', HERE / 'export-practice-runtime-evidence.py')
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
NONCE = '11111111-2222-3333-4444-555555555555'


def valid():
    return {'schema': 1, 'scope': 'synthetic-practice-runtime', 'testID': m.TEST, 'runID': NONCE,
            'events': [{'phase': 'startEntered', 'elapsedMS': 0}, {'phase': 'cameraStopped', 'elapsedMS': 4}],
            'ticks': 1, 'totalTickMS': 2, 'maxTickMS': 2, 'maxTickGapMS': 0, 'lastTickMS': 100,
            'hazard': 'observing', 'hazardTransitions': 1, 'publications': {'model': 4},
            'snapshots': 2, 'truncated': False}


class EvidenceTests(unittest.TestCase):
    def test_retains_partial_trace_without_claiming_end_or_ui_success(self):
        self.assertEqual(m.validate(valid(), NONCE), valid())

    def test_closed_schema_and_owners(self):
        for key, value in [('unexpected', 'private'), ('scope', 'production'), ('testID', 'OtherTest'),
                           ('runID', '00000000-2222-3333-4444-555555555555'), ('schema', True)]:
            d = valid(); d[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError): m.validate(d, NONCE)

    def test_rejects_arbitrary_phase_and_publication_content(self):
        for key, value in [('events', [{'phase': 'private text', 'elapsedMS': 0}]),
                           ('publications', {'user text': 1}), ('hazard', 'private text')]:
            d = valid(); d[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError): m.validate(d, NONCE)

    def test_numeric_and_snapshot_bounds(self):
        for key, values in [('ticks', [-1, True, 1_000_001]), ('snapshots', [0, 33, True]),
                            ('maxTickMS', [float('nan'), float('inf'), -1, 3_600_001, 10**400]),
                            ('truncated', [1, 'false'])]:
            for value in values:
                d = valid(); d[key] = value
                with self.subTest(key=key, value=value), self.assertRaises(ValueError): m.validate(d, NONCE)

    def test_huge_json_event_integer_is_a_closed_validation_error(self):
        d = valid(); d['events'][0]['elapsedMS'] = 10**400
        restored = json.loads(json.dumps(d))
        with self.assertRaises(ValueError): m.validate(restored, NONCE)

    def test_rejects_duplicate_or_reversed_phases(self):
        for events in [[{'phase': 'startEntered', 'elapsedMS': 2}, {'phase': 'cameraStopped', 'elapsedMS': 1}],
                       [{'phase': 'startEntered', 'elapsedMS': 0}] * 2,
                       [{'phase': 'endReturned', 'elapsedMS': 0}], []]:
            d = valid(); d['events'] = events
            with self.subTest(events=events), self.assertRaises(ValueError): m.validate(d, NONCE)

    def test_requires_exact_single_log_marker(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / 'ui.log'
            line = f'PRACTICE_RUNTIME_RUN test={m.TEST} run={NONCE}\n'
            p.write_text('other log\n' + line)
            self.assertEqual(m.nonce_from_log(p), NONCE)
            for text in ['', line * 2, line.replace(m.TEST, 'Other'), line.replace(NONCE, '../escape')]:
                p.write_text(text)
                with self.subTest(text=text), self.assertRaises(ValueError): m.nonce_from_log(p)

    def test_query_output_and_time_are_bounded(self):
        self.assertEqual(m.bounded_query([sys.executable, '-c', 'print("ok")']), b'ok\n')
        for code in ['print("x" * 5000)', 'import sys; sys.stderr.write("x" * 5000)', 'raise SystemExit(3)']:
            with self.subTest(code=code), self.assertRaises(ValueError):
                m.bounded_query([sys.executable, '-c', code])
        with self.assertRaises(ValueError):
            m.bounded_query([sys.executable, '-c', 'import time; time.sleep(5)'], seconds=0.05)

    def test_rejects_unhashable_phase_or_hazard(self):
        for key, value in [('hazard', []), ('events', [{'phase': {}, 'elapsedMS': 0}])]:
            d = valid(); d[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError): m.validate(d, NONCE)

    def test_reads_only_exact_nonce_receipt(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); path = root / 'Library/Caches/BlindPracticeRuntime' / (NONCE + '.json')
            path.parent.mkdir(parents=True); path.write_text(json.dumps(valid()))
            (path.parent / 'other.json').write_text('private unrelated input must not be read')
            self.assertEqual(m.read_receipt(root, NONCE), valid())
            with self.assertRaises(ValueError): m.read_receipt(root, '../escape')

    def test_rejects_symlink_and_oversized_receipt(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); path = root / 'Library/Caches/BlindPracticeRuntime' / (NONCE + '.json')
            path.parent.mkdir(parents=True); target = root / 'other.json'; target.write_text(json.dumps(valid()))
            path.symlink_to(target)
            with self.assertRaises(ValueError): m.read_receipt(root, NONCE)
            path.unlink(); path.write_bytes(b'x' * (16 * 1024 + 1))
            with self.assertRaises(ValueError): m.read_receipt(root, NONCE)

    def test_rejects_symlink_parent(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); other = root / 'other'; other.mkdir()
            caches = root / 'Library/Caches'; caches.mkdir(parents=True)
            (caches / 'BlindPracticeRuntime').symlink_to(other, target_is_directory=True)
            (other / (NONCE + '.json')).write_text(json.dumps(valid()))
            with self.assertRaises(ValueError): m.read_receipt(root, NONCE)


if __name__ == '__main__': unittest.main()
