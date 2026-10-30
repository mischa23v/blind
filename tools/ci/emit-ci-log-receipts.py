#!/usr/bin/env python3
"""Metadata-only CI receipts in ordinary logs/summary; no network, artifacts or tests.

Missing/invalid evidence stays unavailable. This observer never converts an earlier
test failure, skip or unexecuted stage into a pass. Inputs are fixed public/synthetic
CI outputs, not device files. Raw logs, geometry, images and arbitrary errors are
not read or emitted. Native exporters retain their existing detailed log records.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import stat

INPUT_LIMIT = 1024 * 1024
OUTPUT_LIMIT = 128 * 1024
STEP_STATES = {'success', 'failure', 'cancelled', 'skipped'}
RECEIPTS = {
    'native': [
        'blind-native-ci/unit-summary.json',
        'blind-native-ci/unit-case-statuses.json',
        'blind-native-ci/ui-summary.json',
        'blind-native-ci/seed-radius-results.json',
        'blind-native-ci/seed-radius-unit-exit.json',
        'blind-native-ci/seed-radius-diagnostics.json',
    ],
    'mesh-diagnostics-compile': [
        'blind-native-ci/seated-projection-results.json',
        'blind-native-ci/diagnostics-unit-exit.json',
    ],
    'classified-mesh-bench': [
        'classified-mesh-bench/result.json',
        'classified-mesh-bench/xctest-results.json',
    ],
    'body-profile': [
        'body-profile-current-evidence/result.json',
        'body-profile-current-evidence/body-profile-coverage.json',
    ],
    'ingress': ['blind-mesh-candidate-ingress-83/RESULT.json'],
}
SCALARS = {
    'schema', 'status', 'result', 'complete', 'source_verified',
    'source_commit', 'expected_commit', 'commit', 'target_pass_verified',
    'aggregate_counts_match', 'case_count', 'totalTestCount', 'passedTests',
    'failedTests', 'skippedTests', 'expectedFailures', 'executed', 'passed',
    'failed', 'skipped', 'commandExit', 'exit_code', 'swift_test_exit_code',
    'log_writer_exit_code', 'ios_session_fixtures_excluded',
    'source_clean_before_and_after', 'swift_testing_zero_suite_not_counted',
    'compiled_inputs_verified', 'body_profile_coverage_verified', 'verified',
    'log_truncated', 'log_bytes_seen', 'hostRealPackageFixtures',
    'actualARKitSimulatorCompile', 'defaultSwiftBuildBackendPassed',
    'appActivation', 'simulatorExecution', 'deviceExecution',
    'copyLatencyMeasured', 'physicalAuthority', 'unexpectedCaseCount',
    'unparsedFailureRecordCount',
}
TOKEN = re.compile(r'[A-Za-z0-9_./ ()\[\]-]{1,512}\Z')


def scalar(value):
    return (value is None or type(value) in (bool, int)
            or isinstance(value, str) and TOKEN.fullmatch(value) is not None)


def metadata(value):
    if not isinstance(value, dict):
        raise ValueError('receipt must be an object')
    result = {k: v for k, v in value.items() if k in SCALARS and scalar(v)}
    if isinstance(value.get('counts'), dict):
        result['counts'] = {k: v for k, v in value['counts'].items()
                            if k in {'Passed', 'Failed', 'Skipped', 'Expected Failure'}
                            and type(v) is int and v >= 0}
    cases = value.get('cases')
    if isinstance(cases, list):
        result['case_records_in_input'] = len(cases)
        projected = []
        if len(cases) <= 2048:
            for case in cases:
                if not isinstance(case, dict):
                    raise ValueError('invalid case record')
                projected.append({k: v for k, v in case.items()
                                  if k in {'identifier', 'class', 'name', 'status', 'result'}
                                  and scalar(v)})
        if len(projected) == len(cases):
            result['cases'] = projected
        else:
            result['case_projection'] = 'omitted_over_budget'
    events = value.get('events')
    if isinstance(events, dict) and len(events) <= 256:
        result['events'] = {k: v for k, v in events.items()
                            if isinstance(k, str) and TOKEN.fullmatch(k)
                            and isinstance(v, list) and len(v) <= 3
                            and all(x in {'started', 'passed', 'failed', 'skipped'} for x in v)}
    return result


def read_receipt(root, relative):
    record = {'path': relative, 'availability': 'unavailable'}
    path = root / relative
    try:
        # Fixed paths only; refuse symlinks rather than following an unexpected source.
        if path.is_symlink() or path.parent.is_symlink() or not path.resolve().is_relative_to(root.resolve()):
            raise ValueError('unexpected receipt path')
        if not stat.S_ISREG(path.stat().st_mode):
            raise ValueError('receipt must be a regular file')
        with path.open('rb') as handle:
            raw = handle.read(INPUT_LIMIT + 1)
        if len(raw) > INPUT_LIMIT:
            raise ValueError('receipt input budget exceeded')
        value = metadata(json.loads(raw))
        record.update(availability='present', sha256=hashlib.sha256(raw).hexdigest(),
                      bytes=len(raw), metadata=value)
        if len(encode(record).encode()) > OUTPUT_LIMIT:
            value.pop('cases', None)
            value['case_projection'] = 'omitted_over_budget'
        if len(encode(record).encode()) > OUTPUT_LIMIT:
            raise ValueError('receipt output budget exceeded')
    except (OSError, ValueError, TypeError, RecursionError) as error:
        record = {'path': relative, 'availability': 'unavailable',
                  'error_type': type(error).__name__}
    return record


def encode(value):
    # Escape markup even inside the summary fence; one prefixed JSON line per record.
    return json.dumps(value, separators=(',', ':'), sort_keys=True, allow_nan=False).replace('`', '\\u0060')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('job', choices=RECEIPTS)
    args = parser.parse_args()
    raw_steps = os.environ.get('CI_STEP_OUTCOMES', '{}')
    if len(raw_steps.encode()) > INPUT_LIMIT:
        raise ValueError('step metadata budget exceeded')
    steps = json.loads(raw_steps)
    if not isinstance(steps, dict) or len(steps) > 128:
        raise ValueError('invalid step metadata')
    outcomes = {name: {k: v for k, v in data.items()
                       if k in {'outcome', 'conclusion'} and v in STEP_STATES}
                for name, data in steps.items()
                if TOKEN.fullmatch(name) and isinstance(data, dict)}
    status = os.environ.get('CI_JOB_STATUS')
    receipt = {'schema': 1, 'job': args.job,
               'job_status_before_receipt': status if status in STEP_STATES else 'unknown',
               'steps': outcomes, 'physical_authority': False,
               'artifact_uploads_enabled': os.environ.get('BLIND_UPLOAD_ARTIFACTS') == 'true'}
    for key, env, pattern in [('workflow_commit', 'GITHUB_SHA', r'[0-9a-f]{40}'),
                              ('run_id', 'GITHUB_RUN_ID', r'[0-9]+'),
                              ('run_attempt', 'GITHUB_RUN_ATTEMPT', r'[0-9]+')]:
        value = os.environ.get(env, '')
        receipt[key] = value if re.fullmatch(pattern, value) else None
    lines = ['BLIND_CI_JOB=' + encode(receipt)]
    root = Path(os.environ['RUNNER_TEMP'])
    for relative in RECEIPTS[args.job]:
        lines.append('BLIND_CI_RECEIPT=' + encode(read_receipt(root, relative)))
    for line in lines:
        print(line)
    # Under 1 MiB even for the six-record native job; summary is optional locally.
    if os.environ.get('GITHUB_STEP_SUMMARY'):
        with open(os.environ['GITHUB_STEP_SUMMARY'], 'a') as handle:
            handle.write('\n### Log-only CI receipts (not device acceptance)\n\n```text\n'
                         + '\n'.join(lines) + '\n```\n')


if __name__ == '__main__':
    main()
