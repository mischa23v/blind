"""Synthetic parser checks only: no compiler, Apple runner, or real test claim."""
from pathlib import Path
import tempfile
import unittest
from body_profile_evidence import Evidence, LOG_HALF, MAX_LINE, required_names

SOURCE = Path(__file__).resolve().parents[1] / 'evaluations/body-aware-warning/verification/Tests/BodyProfileStoreTests.swift'
NAMES = required_names(SOURCE.read_text())


def record(name, state, dotted=False):
    label = f'BodyProfileStoreTests.{name}' if dotted else f'-[NativeBodyProfileTests.BodyProfileStoreTests {name}]'
    duration = '' if state == 'started' else ' (0.001 seconds)'
    return f"Test Case '{label}' {state}{duration}.\n".encode()


def passing(dotted=False):
    return b''.join(record(n, state, dotted) for n in NAMES for state in ('started', 'passed'))


def parse(data):
    e = Evidence(NAMES)
    # Exercise chunks splitting test names and status tokens.
    for offset in range(0, len(data), 23):
        e.feed(data[offset:offset + 23])
    return e.finish()


class ParserTests(unittest.TestCase):
    def test_current_required_names(self):
        self.assertEqual(len(NAMES), 9)

    def test_darwin_all_exactly_once(self):
        self.assertTrue(parse(passing())['verified'])

    def test_dotted_xctest(self):
        self.assertTrue(parse(passing(True))['verified'])

    def test_swift_testing_footer_is_not_xctest_coverage(self):
        footer = b'Test run with 0 tests passed after 0.001 seconds.\n'
        self.assertFalse(parse(footer)['verified'])
        self.assertTrue(parse(passing() + footer)['verified'])

    def test_missing_case(self):
        self.assertFalse(parse(passing().replace(record(NAMES[0], 'passed'), b''))['verified'])

    def test_skipped_or_failed(self):
        for state in ('skipped', 'failed'):
            with self.subTest(state=state):
                self.assertFalse(parse(passing().replace(record(NAMES[0], 'passed'), record(NAMES[0], state)))['verified'])

    def test_duplicate_pass_or_whole_run(self):
        for extra in (record(NAMES[0], 'passed'), passing()):
            self.assertFalse(parse(passing() + extra)['verified'])

    def test_pass_without_start_and_wrong_order(self):
        self.assertFalse(parse(passing().replace(record(NAMES[0], 'started'), b''))['verified'])
        pair = record(NAMES[0], 'started') + record(NAMES[0], 'passed')
        self.assertFalse(parse(passing().replace(pair, record(NAMES[0], 'passed') + record(NAMES[0], 'started')))['verified'])

    def test_unknown_or_malformed_case(self):
        self.assertFalse(parse(passing() + record('testUnexpected', 'passed'))['verified'])
        self.assertFalse(parse(passing() + b"Test Case 'BodyProfileStoreTests.testBad' unknown.\n")['verified'])

    def test_overlong_line_fails_closed(self):
        self.assertFalse(parse(b'x' * (MAX_LINE + 1) + b'\n' + passing())['verified'])

    def test_capped_log_still_checks_middle_coverage(self):
        e = Evidence(NAMES)
        noise = b'build log line\n' * 45000
        e.feed(noise)
        e.feed(passing())
        e.feed(noise)
        coverage = e.finish()
        self.assertTrue(coverage['verified'])
        self.assertTrue(coverage['log_truncated'])
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'log'
            e.write_log(path)
            self.assertLess(path.stat().st_size, 2 * LOG_HALF + 100)
            self.assertIn(b'LOG TRUNCATED', path.read_bytes())

    def test_invalid_source(self):
        for source in ('', 'func testA() {} func testA() {}'):
            with self.assertRaises(ValueError):
                required_names(source)


if __name__ == '__main__':
    unittest.main()
