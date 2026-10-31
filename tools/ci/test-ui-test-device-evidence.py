#!/usr/bin/env python3
import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location('device_evidence', Path(__file__).with_name('export-ui-test-device-evidence.py'))
m = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(m)
A = 'AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA'
B = 'BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB'
HELP = b'Command output structure (JSON Schema)\n{}\nUSAGE: xcresulttool get test-results test-details --test-id <test-id> --path <path>\n'


def details(test=m.TESTS[0], identity=A):
    return {'testIdentifier': test + '()', 'devices': [{'deviceId': identity, 'platform': 'iOS Simulator',
            'deviceName': 'PRIVATE_DEVICE_NAME', 'modelName': 'PRIVATE_MODEL'}],
            'testRuns': [{'deviceId': identity, 'result': 'Failed', 'private': '/private/person/file'}],
            'testDescription': 'PRIVATE_USER_CONTENT', 'testFailures': [{'message': 'PRIVATE_FAILURE'}]}


class IdentityTests(unittest.TestCase):
    def test_exact_identity_and_comparison_only(self):
        result = m.project_identity(details(), m.TESTS[0], A)
        self.assertEqual(result['deviceUUIDs'], [A])
        self.assertEqual(result['directTestRunDeviceUUIDs'], [A])
        self.assertEqual(result['preflightComparison'], 'same_reported_uuid')
        result = m.project_identity(details(identity=B), m.TESTS[0], A)
        self.assertEqual(result['preflightComparison'], 'different_reported_uuid')
        self.assertNotIn('executionUUID', result)

    def test_private_details_are_dropped(self):
        result = json.dumps(m.project_identity(details(), m.TESTS[0], A))
        for private in ('PRIVATE', '/private/', 'Failed'):
            self.assertNotIn(private, result)

    def test_wrong_test_or_arbitrary_identifier_rejected(self):
        for value in (None, '', 'OtherTests/testOther', m.TESTS[1], 'WrongTarget/' + m.TESTS[0]):
            d = details(); d['testIdentifier'] = value
            with self.subTest(value=value), self.assertRaises(ValueError):
                m.project_identity(d, m.TESTS[0], A)
        d = details(); d['testIdentifier'] = 'BlindAssistUITests/' + m.TESTS[0]
        self.assertEqual(m.project_identity(d, m.TESTS[0], A)['testID'], m.TESTS[0])

    def test_non_simulator_or_invalid_uuid_rejected(self):
        for device in ({}, {'deviceId': A, 'platform': 'iOS'}, {'deviceId': '/private/file', 'platform': 'iOS Simulator'}):
            d = details(); d['devices'] = [device]
            with self.subTest(device=device), self.assertRaises(ValueError):
                m.project_identity(d, m.TESTS[0], A)

    def test_empty_excessive_duplicate_devices_rejected(self):
        for devices in ([], [details()['devices'][0]] * 5, [details()['devices'][0]] * 2, {}):
            d = details(); d['devices'] = devices
            with self.subTest(devices=devices), self.assertRaises(ValueError):
                m.project_identity(d, m.TESTS[0], A)

    def test_multiple_devices_are_explicitly_ambiguous(self):
        d = details(); d['devices'].append({'deviceId': B, 'platform': 'iOS Simulator'})
        self.assertEqual(m.project_identity(d, m.TESTS[0], A)['preflightComparison'], 'ambiguous_multiple_devices')

    def test_unknown_run_shape_not_invented(self):
        for runs, shape in ((None, 'not_present'), ({'device': B}, 'other'), ([{'device': {'deviceId': B}}], 'list')):
            d = details(); d['testRuns'] = runs
            result = m.project_identity(d, m.TESTS[0], A)
            self.assertEqual(result['testRunsShape'], shape)
            self.assertNotIn(B, json.dumps(result))

    def test_invalid_excessive_runs_rejected(self):
        for runs in ([{}] * 9, ['private'], [{'deviceId': '../secret'}]):
            d = details(); d['testRuns'] = runs
            with self.subTest(runs=runs), self.assertRaises(ValueError):
                m.project_identity(d, m.TESTS[0], A)

    def collect(self, respond):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        selected = root / 'simulator-id'; selected.write_text(A)
        destination = root / 'out'
        commands = []
        def query(command):
            commands.append(command)
            return respond(command)
        result = m.collect(root/'ui.xcresult', selected, destination, query)
        return result, destination, commands

    def test_only_two_exact_tests_and_help_no_container_queries(self):
        def respond(command):
            if command[-1] == '--help': return HELP
            return json.dumps(details(command[command.index('--test-id')+1], B)).encode()
        result, destination, commands = self.collect(respond)
        self.assertTrue(result['complete'])
        self.assertEqual(len(commands), 3)
        self.assertEqual([c[c.index('--test-id')+1] for c in commands[1:]], list(m.TESTS))
        self.assertEqual(result['containerSelection'], 'not_attempted')
        self.assertNotIn('simctl', json.dumps(commands))
        self.assertNotIn('get_app_container', json.dumps(commands))
        self.assertEqual(set(p.name for p in destination.iterdir()), {'ui-test-device-evidence.json', 'xcresult-test-details-help.txt'})
        self.assertNotIn('PRIVATE', (destination/'ui-test-device-evidence.json').read_text())

    def test_query_failure_is_closed_without_raw_error(self):
        def respond(command):
            if command[-1] == '--help': return HELP
            raise ValueError('SECRET /private/path')
        result, destination, commands = self.collect(respond)
        self.assertFalse(result['complete'])
        self.assertNotIn('SECRET', json.dumps(result))
        self.assertEqual(len(commands), 3)
        self.assertTrue(all(r['queryStatus']=='unavailable' for r in result['tests']))

    def test_advertised_schema_is_bounded_and_retained(self):
        def respond(command):
            if command[-1] == '--help': return b'USAGE: test-details --test-id\n  --schema    Output schema\n'
            if '--schema' in command: return b'{"type":"object","properties":{"devices":{"type":"array"}}}'
            return json.dumps(details(command[command.index('--test-id')+1])).encode()
        result, destination, commands = self.collect(respond)
        self.assertTrue(result['complete'])
        self.assertEqual(len(commands), 4)
        self.assertTrue((destination/'xcresult-test-details-schema.json').is_file())

    def test_schema_output_cannot_expand_past_raw_cap(self):
        nested = {'type': 'string'}
        for _ in range(300): nested = {'x': nested}
        schema = {'type': 'object', 'properties': nested}
        raw = json.dumps(schema,separators=(',',':')).encode()
        self.assertLess(len(raw),m.CAP)
        self.assertGreater(len(json.dumps(schema,indent=2).encode()),m.CAP)
        def respond(command):
            if command[-1] == '--help': return b'USAGE: test-details --test-id\n  --schema    Output schema\n'
            if '--schema' in command: return raw
            return json.dumps(details(command[command.index('--test-id')+1])).encode()
        result, destination, _ = self.collect(respond)
        self.assertTrue(result['complete'])
        self.assertEqual((destination/'xcresult-test-details-schema.json').read_bytes(),raw)

    def test_schema_instance_must_not_be_retained(self):
        def respond(command):
            if command[-1] == '--help': return b'USAGE: test-details --test-id\n  --schema    Output schema\n'
            if '--schema' in command: return json.dumps(details()).encode()
            return json.dumps(details(command[command.index('--test-id')+1])).encode()
        result, destination, _ = self.collect(respond)
        self.assertFalse(result['complete'])
        self.assertFalse((destination/'xcresult-test-details-schema.json').exists())

    def test_schema_with_private_instance_fields_rejected(self):
        self.assertFalse(m.public_schema({'schemas': {}, 'testIdentifier': 'PRIVATE'}))
        self.assertFalse(m.public_schema({'schemas': 'PRIVATE'}))

    def test_oversized_details_are_not_projected_or_retained(self):
        def respond(command):
            if command[-1] == '--help': return HELP
            return b'x' * (m.CAP + 1)
        result, destination, _ = self.collect(respond)
        self.assertFalse(result['complete'])
        self.assertTrue(all(r['queryStatus']=='unavailable' for r in result['tests']))
        self.assertLess((destination/'ui-test-device-evidence.json').stat().st_size,16*1024)

    def test_unknown_help_and_oversize_output_fail_closed(self):
        for response in (b'unknown', b'x' * (m.CAP + 1)):
            result, _, _ = self.collect(lambda command: response)
            self.assertFalse(result['complete'])

    def test_new_queries_retain_existing_twenty_second_deadline(self):
        with patch.object(m.runtime, 'bounded_query', return_value=b'{}') as q:
            self.assertEqual(m.query(['xcrun','xcresulttool']), b'{}')
        q.assert_called_once_with(['xcrun','xcresulttool'], seconds=20, cap=128*1024)

    def test_selected_uuid_read_is_bounded(self):
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp)/'simulator-id'
            for text in ('../private', 'x'*65):
                p.write_text(text)
                with self.assertRaises(ValueError): m.selected_uuid(p)
            p.write_text(A.lower()+'\n')
            self.assertEqual(m.selected_uuid(p), A)

    def test_workflow_upload_is_exact_and_diagnostic_only(self):
        workflow = Path(__file__).resolve().parents[2]/'.github/workflows/native-apple.yml'
        text = workflow.read_text()
        start=text.index('      - name: Inspect exact synthetic UI test device identities')
        end=text.index('      - name: Extract bounded synthetic Practice runtime evidence',start)
        added=text[start:end]
        self.assertEqual(added.count("if: always() && steps.preflight.outcome == 'success'"),2)
        self.assertIn('timeout-minutes: 2',added)
        self.assertIn('/ui.xcresult',added)
        self.assertIn('/simulator-id',added)
        for name in ('ui-test-device-evidence.json','xcresult-test-details-help.txt','xcresult-test-details-schema.json'):
            self.assertIn('/'+name,added)
        for forbidden in ('continue-on-error','simctl','get_app_container','**','*.json'):
            self.assertNotIn(forbidden,added)
        self.assertIn('github.event.repository.private == false',text)
        self.assertIn('timeout-minutes: 20\n        run: bash tools/ci/native-apple.sh ui',text)


if __name__ == '__main__':
    unittest.main()
