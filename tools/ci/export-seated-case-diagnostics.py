#!/usr/bin/env python3
"""Failure-preserving seated case metadata; never changes strict acceptance.

Reuse installed xcresult tests/summary queries and the reviewed exact fixture
allowlist. Raw assertion text, attachments, captured geometry and model text
are never exported. Unknown schemas remain explicitly unknown.
"""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SPEC = importlib.util.spec_from_file_location('seated_strict_collector', HERE / 'collect-seated-projection.py')
strict = importlib.util.module_from_spec(SPEC); SPEC.loader.exec_module(strict)
native = strict.native
EXPECTED = tuple(strict.EXPECTED)
CASE_LIMIT = 128
FAILURE_LIMIT = 128
LOG_LIMIT = 64 * 1024 * 1024
LINE_LIMIT = 4096
OUTPUT_LIMIT = 128 * 1024
EXCEPTIONS = (OSError, ValueError, TypeError, KeyError, RecursionError, subprocess.SubprocessError)
FIXTURES = ('ios/BlindAssistTests/SeatedMeshProjectionTests.swift',
            'ios/BlindAssistTests/SeatedCollisionBridgeTests.swift')
ASSERTIONS = {
    'XCTAssertTrue': 'assert_true', 'XCTAssertFalse': 'assert_false',
    'XCTAssertEqual': 'assert_equal', 'XCTAssertNotEqual': 'assert_not_equal',
    'XCTAssertNil': 'assert_nil', 'XCTAssertNotNil': 'assert_not_nil',
    'XCTAssertGreaterThan': 'assert_greater', 'XCTAssertGreaterThanOrEqual': 'assert_greater_equal',
    'XCTAssertLessThan': 'assert_less', 'XCTAssertLessThanOrEqual': 'assert_less_equal',
    'XCTAssertThrowsError': 'assert_throws', 'XCTAssertNoThrow': 'assert_no_throw',
    'XCTUnwrap': 'unwrap', 'XCTFail': 'explicit_failure', 'XCTAssert': 'assert_generic',
}


def require(ok):
    if not ok: raise ValueError('unsupported or excessive metadata')


def bounded(path, limit):
    require(path.is_file() and not path.is_symlink())
    with path.open('rb') as stream: data = stream.read(limit + 1)
    require(len(data) <= limit)
    return data


def identity(value):
    if type(value) is not str or len(value) > 512: return None
    candidate = value.removesuffix('()').removeprefix('BlindAssistTests/')
    if candidate in EXPECTED: return candidate
    match = re.fullmatch(r'-\[(?:BlindAssistTests\.)?(SeatedMeshProjectionTests|SeatedCollisionBridgeTests) (test\w+)\]', value)
    candidate = '/'.join(match.groups()) if match else None
    return candidate if candidate in EXPECTED else None


def category(value):
    # Classification only, not cause attribution; never echo or hash messages.
    if type(value) is not str: return 'unavailable'
    if len(value) > LINE_LIMIT: return 'oversize_message'
    match = re.match(r'^(XCT[A-Za-z]+)(?:\s|:|$)', value)
    if match and match.group(1) in ASSERTIONS: return ASSERTIONS[match.group(1)]
    if value.startswith('Asynchronous wait failed:'): return 'async_wait_failure'
    if value.startswith('Failed due to unwaited expectation'): return 'unwaited_expectation'
    if value.startswith('failed: caught error') or value.startswith('threw error'): return 'thrown_error'
    if value.startswith('failed -') or value == 'failed': return 'explicit_failure'
    return 'other_failure'


def project_cases(cases):
    result = {'cases': [], 'caseCountObserved': len(cases), 'unexpectedCaseCount': 0,
              'caseRowsOmitted': 0, 'duplicateExpectedCaseRows': 0}
    seen = set()
    for row in cases:
        name = identity(row['identifier'])
        if name is None:
            result['unexpectedCaseCount'] += 1; continue
        if name in seen: result['duplicateExpectedCaseRows'] += 1
        seen.add(name)
        if len(result['cases']) < CASE_LIMIT:
            result['cases'].append({'identifier': name, 'result': row['result']})
        else: result['caseRowsOmitted'] += 1
    result['missingExpectedIdentities'] = [name for name in EXPECTED if name not in seen]
    result['exactCaseSetObserved'] = len(cases) == len(EXPECTED) and seen == set(EXPECTED)
    return result


def summary_failures(summary):
    result = {'records': [], 'unrecognizedRecords': 0, 'recordsOmitted': 0,
              'schemaAvailable': False, 'origin': 'xcresult-summary',
              'countMeaning': 'failure_records_not_failed_test_cases'}
    if type(summary) is not dict or type(summary.get('testFailures')) is not list: return result
    failures = summary['testFailures']; result['schemaAvailable'] = True
    for row in failures[:FAILURE_LIMIT]:
        if type(row) is not dict:
            result['unrecognizedRecords'] += 1; continue
        a, b = identity(row.get('testIdentifier')), identity(row.get('testName'))
        # Conflicting known identifiers never bind an assertion to a guessed case.
        if (a and b and a != b) or not (a or b):
            result['unrecognizedRecords'] += 1; continue
        result['records'].append({'identifier': a or b,
                                  'category': category(row.get('failureText', row.get('message')))})
    result['recordsOmitted'] = max(0, len(failures) - FAILURE_LIMIT)
    return result


def log_failures(path):
    result = {'records': [], 'recordsOmitted': 0, 'oversizeLinesSkipped': 0,
              'origin': 'fixed-fixture-log', 'countMeaning': 'matching_log_records_not_unique_assertions'}
    require(path.is_file() and not path.is_symlink())
    pattern = re.compile(r'^(?:[^\r\n]{0,2048}/)?(SeatedMeshProjectionTests|SeatedCollisionBridgeTests)\.swift:'
                         r'([0-9]{1,7})(?::[0-9]{1,7})?: error: '
                         r'(-\[(?:BlindAssistTests\.)?(?:SeatedMeshProjectionTests|SeatedCollisionBridgeTests) test\w+\]) : (.*)$')
    total = 0; skipping = False
    with path.open('rb') as stream:
        while True:
            line = stream.readline(LINE_LIMIT + 1)
            if not line: break
            total += len(line); require(total <= LOG_LIMIT)
            if len(line) > LINE_LIMIT:
                if not skipping: result['oversizeLinesSkipped'] += 1
                skipping = not line.endswith(b'\n'); continue
            if skipping:
                skipping = not line.endswith(b'\n'); continue
            try: text = line.decode('utf-8').rstrip('\r\n')
            except UnicodeError: continue
            match = pattern.fullmatch(text)
            if not match: continue
            filename, line_number, raw_name, message = match.groups(); name = identity(raw_name)
            if not name or name.split('/')[0] != filename: continue
            if len(result['records']) >= FAILURE_LIMIT:
                result['recordsOmitted'] += 1; continue
            result['records'].append({'identifier': name, 'line': int(line_number), 'category': category(message)})
    return result


def fixture_source():
    data = [bounded(ROOT / p, 2 * 1024 * 1024) for p in FIXTURES]
    strict.verify_fixture_source(data[0].decode(), strict.PROJECTION_EXPECTED, 'SeatedMeshProjectionTests')
    strict.verify_fixture_source(data[1].decode(), strict.COLLISION_EXPECTED, 'SeatedCollisionBridgeTests')
    return {p: hashlib.sha256(b).hexdigest() for p, b in zip(FIXTURES, data)}


def collect(out):
    result = {'schema': 1, 'status': 'unavailable', 'sourceVerified': False,
              'scope': '18 fixed synthetic hosted cases; diagnostic metadata only',
              'acceptance': 'not_inferred_strict_collector_unchanged', 'physicalAuthority': False,
              'assertionOriginsCombined': False, 'commandExit': None, 'errors': []}
    expected = os.environ.get('GITHUB_SHA')
    if type(expected) is str and re.fullmatch('[0-9a-f]{40}', expected): result['expectedCommit'] = expected
    try:
        command = json.loads(bounded(out / 'diagnostics-unit-exit.json', 4096))
        require(type(command) is dict)
        if type(command.get('exit_code')) is int: result['commandExit'] = command['exit_code']
        else: result['errors'].append('command-exit-unavailable')
    except EXCEPTIONS: result['errors'].append('command-receipt-unavailable')
    try:
        before = native.provenance(ROOT, expected); hashes = fixture_source()
        bundle = out / 'diagnostics-unit.xcresult'
        cases = summary = None; pending = {}
        for kind in ['tests', 'summary']:
            try:
                raw = native.query(['xcrun', 'xcresulttool', 'get', 'test-results', kind,
                                    '--path', str(bundle), '--compact'], seconds=20)
                payload = json.loads(raw)
                pending.setdefault('querySHA256', {})[kind] = hashlib.sha256(raw).hexdigest()
                if kind == 'tests':
                    cases = native.cases_from(payload); pending.update(project_cases(cases))
                else:
                    summary = payload; pending['summaryFailureCategories'] = summary_failures(summary)
            except EXCEPTIONS: result['errors'].append(kind + '-metadata-unavailable')
        if cases is not None and summary is not None:
            try:
                pending['counts'] = native.reconcile(cases, summary); pending['aggregateCountsMatch'] = True
            except EXCEPTIONS:
                pending['aggregateCountsMatch'] = False; result['errors'].append('aggregate-counts-mismatch')
        try: pending['logFailureCategories'] = log_failures(out / 'diagnostics-unit.log')
        except EXCEPTIONS: result['errors'].append('fixed-fixture-log-unavailable')
        after = native.provenance(ROOT, expected)
        require(before == after and hashes == fixture_source())
        # No case/assertion metadata is released on dirty/changed source identity.
        result.update(pending, status='diagnostic-only', sourceVerified=True,
                      sourceCommit=before['actual_head'], fixtureSHA256=hashes)
    except EXCEPTIONS: result['errors'].append('source-identity-unverified')
    encoded = json.dumps(result, sort_keys=True, separators=(',', ':'))
    require(len(encoded.encode()) <= OUTPUT_LIMIT)
    line = 'SEATED_CASE_DIAGNOSTICS=' + encoded
    print(line)
    out.mkdir(parents=True, exist_ok=True)
    (out / 'seated-case-diagnostics.json').write_text(encoded + '\n')
    if os.environ.get('GITHUB_STEP_SUMMARY'):
        with open(os.environ['GITHUB_STEP_SUMMARY'], 'a') as stream:
            stream.write('\n### Seated case diagnostics, not acceptance\n```text\n' + line + '\n```\n')
    return 0  # Observation cannot erase the original native/strict collector failures.


if __name__ == '__main__':
    raise SystemExit(collect(Path(sys.argv[1])))
