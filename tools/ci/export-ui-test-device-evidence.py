#!/usr/bin/env python3
"""Identity-only xcresult evidence for two synthetic UI tests; never selects a container.

Apple documents test-details and installed help as the output-format authority:
https://developer.apple.com/documentation/xcode-release-notes/xcode-16_3-release-notes
Retain the installed schema before treating a reported device ID as a clone identity.
"""
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import sys

SPEC = importlib.util.spec_from_file_location('practice_runtime_export', Path(__file__).with_name('export-practice-runtime-evidence.py'))
runtime = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(runtime)
TESTS = ('LaunchTests/testPracticeIsAnnouncedAndCanStop', 'LaunchTests/testAccessibilityAuditOfCameraAndAsk')
UUID = re.compile(runtime.UUID)
CAP = 128 * 1024


def query(command):
    # Reuse the existing process-group cleanup and deadline implementation.
    # Only these new metadata queries use 128 KiB; container queries stay 4 KiB.
    return runtime.bounded_query(command, seconds=20, cap=CAP)


def selected_uuid(path):
    with path.open('rb') as stream:
        raw = stream.read(65)
    if len(raw) > 64:
        raise ValueError('selected_identity_oversize')
    value = raw.decode('ascii').strip().upper()
    if not UUID.fullmatch(value):
        raise ValueError('selected_identity_invalid')
    return value


def exact_identifier(value, test):
    return type(value) is str and value.removesuffix('()') in (test, 'BlindAssistUITests/' + test)


def project_identity(payload, test, selected):
    if type(payload) is not dict or not exact_identifier(payload.get('testIdentifier'), test):
        raise ValueError('exact_test_identity_missing')
    # Keep no arbitrary test names, labels, errors, paths, durations or attachments.
    result = {'testID': test, 'queryStatus': 'identity_fields_retained',
              'identityMeaning': 'reported_xcresult_fields_not_verified_execution_container'}
    devices = payload.get('devices')
    if type(devices) is not list or not 1 <= len(devices) <= 4:
        raise ValueError('device_records_missing_or_excessive')
    ids = []
    for device in devices:
        if type(device) is not dict or type(device.get('deviceId')) is not str:
            raise ValueError('device_identity_missing')
        value = device['deviceId'].upper()
        if not UUID.fullmatch(value) or device.get('platform') != 'iOS Simulator':
            raise ValueError('device_identity_not_simulator_uuid')
        ids.append(value)
    if len(ids) != len(set(ids)):
        raise ValueError('duplicate_device_identity')
    result['deviceUUIDs'] = ids
    result['preflightComparison'] = ('ambiguous_multiple_devices' if len(ids) != 1 else
                                     'same_reported_uuid' if ids[0] == selected else 'different_reported_uuid')
    # This is deliberately a shape observation, not a guessed execution-device selector.
    runs = payload.get('testRuns')
    result['testRunsShape'] = 'not_present' if runs is None else 'list' if type(runs) is list else 'other'
    if type(runs) is list:
        if len(runs) > 8: raise ValueError('test_runs_excessive')
        result['testRunCount'] = len(runs)
        run_ids = []
        missing = 0
        for run in runs:
            if type(run) is not dict: raise ValueError('test_run_record_invalid')
            value = run.get('deviceId')
            if value is None:
                missing += 1
            elif type(value) is str and UUID.fullmatch(value.upper()):
                run_ids.append(value.upper())
            else: raise ValueError('test_run_device_identity_invalid')
        result['directTestRunDeviceUUIDs'] = run_ids
        result['testRunsWithoutDirectDeviceID'] = missing
    return result


def public_schema(value):
    # A schema response must not accidentally preserve a test-details instance.
    keys = {'schemas', '$schema', '$id', '$ref', '$defs', 'definitions', 'type',
            'title', 'description', 'properties', 'required', 'additionalProperties'}
    return type(value) is dict and not set(value) - keys and (
        type(value.get('schemas')) is dict or type(value.get('$defs')) is dict or
        (value.get('type') == 'object' and type(value.get('properties')) is dict))


def collect(bundle, simulator_file, destination, run_query=query):
    destination.mkdir(parents=True, exist_ok=False)
    result = {'schema': 1, 'scope': 'synthetic-ui-test-device-identity',
              'sourceOfTruth': 'installed_public_xcresulttool_help_and_exact_test_details',
              'uiOutcome': 'not_inferred_from_diagnostic', 'containerSelection': 'not_attempted',
              'tests': [], 'errors': [], 'complete': False}
    try:
        selected = selected_uuid(simulator_file)
        result['preflightUUID'] = selected
    except (OSError, ValueError, UnicodeError):
        result['errors'].append('preflight_identity_unavailable')
        selected = None
    try:
        help_bytes = run_query(['xcrun', 'xcresulttool', 'get', 'test-results', 'test-details', '--help'])
        if len(help_bytes) > CAP: raise ValueError('help_oversize')
        help_text = help_bytes.decode('utf-8')
        if 'test-details' not in help_text or '--test-id' not in help_text:
            raise ValueError('unexpected_help')
        (destination / 'xcresult-test-details-help.txt').write_bytes(help_bytes)
        result['helpStatus'] = 'retained'
        # Older tools embed JSON Schema in help; newer ones advertise --schema.
        if 'Command output structure (JSON Schema)' in help_text:
            result['schemaStatus'] = 'embedded_in_installed_help'
        elif re.search(r'(?m)^\s*--schema(?:\s|$)', help_text):
            raw = run_query(['xcrun', 'xcresulttool', 'get', 'test-results', 'test-details',
                             '--schema', '--path', str(bundle), '--test-id', TESTS[0]])
            if len(raw) > CAP: raise ValueError('schema_oversize')
            schema = json.loads(raw)
            if not public_schema(schema): raise ValueError('schema_not_recognized')
            (destination / 'xcresult-test-details-schema.json').write_bytes(raw)
            result['schemaStatus'] = 'retained_public_schema'
        else:
            result['schemaStatus'] = 'not_advertised'
            result['errors'].append('installed_schema_unavailable')
    except (OSError, ValueError, RecursionError, subprocess.SubprocessError):
        result['errors'].append('installed_help_or_schema_unavailable')
    if selected is not None:
        for test in TESTS:
            try:
                raw = run_query(['xcrun', 'xcresulttool', 'get', 'test-results', 'test-details',
                                 '--path', str(bundle), '--test-id', test, '--compact'])
                if len(raw) > CAP: raise ValueError('test_details_oversize')
                result['tests'].append(project_identity(json.loads(raw), test, selected))
            except (OSError, ValueError, RecursionError, subprocess.SubprocessError):
                result['tests'].append({'testID': test, 'queryStatus': 'unavailable'})
                result['errors'].append('exact_test_identity_unavailable')
    result['complete'] = not result['errors'] and len(result['tests']) == len(TESTS)
    data = json.dumps(result, indent=2) + '\n'
    if len(data.encode()) > 16 * 1024: raise ValueError('identity_report_oversize')
    (destination / 'ui-test-device-evidence.json').write_text(data)
    return result


def main():
    bundle, selected, destination = map(Path, sys.argv[1:])
    result = collect(bundle, selected, destination)
    print('UI_TEST_DEVICE_EVIDENCE=' + json.dumps(result, separators=(',', ':')))
    return 0 if result['complete'] else 1


if __name__ == '__main__':
    sys.exit(main())
