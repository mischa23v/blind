#!/usr/bin/env python3
"""Bounded xcresult case + public/synthetic evidence; never changes test outcomes/retries.

Schema reference: Chromium's Xcode16LogParser consumes testNodes/children,
nodeType='Test Case', nodeIdentifier and result from Apple's xcresulttool.
https://raw.githubusercontent.com/chromium/chromium/main/ios/build/bots/scripts/xcode_log_parser.py
Apple overview: https://developer.apple.com/documentation/xcode/running-tests-and-interpreting-results
"""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import selectors
import signal
import subprocess
import sys
import time

TARGET = 'IndoorGoalContinuityTests/testTrackingLossStillInvalidatesRetainedMapFrame'
CAP = 4 * 1024 * 1024
STATUSES = {'Passed', 'Failed', 'Skipped', 'Expected Failure'}


def query(command, seconds=30):
    """Bound stdout and stderr together, kill only this owned query on timeout/cap."""
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                               start_new_session=True)
    buffers = {process.stdout: bytearray(), process.stderr: bytearray()}
    deadline = time.monotonic() + seconds
    try:
        with selectors.DefaultSelector() as selector:
            for stream in buffers:
                selector.register(stream, selectors.EVENT_READ)
            while selector.get_map():
                if time.monotonic() >= deadline:
                    raise ValueError('xcresult query timed out')
                for key, _ in selector.select(max(0.0, min(0.2, deadline - time.monotonic()))):
                    data = os.read(key.fd, 65536)
                    if data:
                        buffers[key.fileobj].extend(data)
                        if sum(map(len, buffers.values())) > CAP:
                            raise ValueError('xcresult query exceeded 4 MiB')
                    else:
                        selector.unregister(key.fileobj)
            code = process.wait(timeout=max(0.01, deadline - time.monotonic()))
            if code:
                raise ValueError('xcresult query exit code ' + str(code))
            return bytes(buffers[process.stdout])
    finally:
        # The session leader may already have exited while its descendants hold
        # our pipes. Retire the entire group we created, not just a live leader.
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        process.wait()
        for stream in buffers:
            stream.close()


def cases_from(payload):
    if not isinstance(payload, dict) or not isinstance(payload.get('testNodes'), list):
        raise ValueError('Unsupported xcresult tests schema')
    cases, count = [], 0
    stack = [(n, 0) for n in reversed(payload['testNodes'])]
    while stack:
        node, depth = stack.pop()
        count += 1
        if count > 10000 or depth > 32 or not isinstance(node, dict):
            raise ValueError('Invalid or excessive test tree')
        if node.get('nodeType') == 'Test Case':
            identifier, status = node.get('nodeIdentifier'), node.get('result')
            if not isinstance(identifier, str) or not identifier or len(identifier) > 512:
                raise ValueError('Invalid case identifier')
            if not isinstance(status, str) or status not in STATUSES:
                raise ValueError('Unknown case status')
            cases.append({'identifier': identifier, 'result': status})
            # Parameterized children are not additional test declarations.
            continue
        children = node.get('children', [])
        if not isinstance(children, list):
            raise ValueError('Invalid child list')
        stack.extend((n, depth + 1) for n in reversed(children))
    if not cases:
        raise ValueError('No test case statuses found')
    return cases


def reconcile(cases, summary):
    counts = {status: sum(c['result'] == status for c in cases) for status in STATUSES}
    expected = {'totalTestCount': len(cases), 'passedTests': counts['Passed'],
                'failedTests': counts['Failed'], 'skippedTests': counts['Skipped'],
                'expectedFailures': counts['Expected Failure']}
    if not isinstance(summary, dict):
        raise ValueError('Missing aggregate summary')
    for key, count in expected.items():
        value = summary.get(key)
        if type(value) is not int or value != count:
            raise ValueError('Case counts disagree with summary: ' + key)
    return counts


def target_records(cases):
    return [c for c in cases if c['identifier'].removesuffix('()') == TARGET
            or c['identifier'].removesuffix('()').endswith('/' + TARGET)]


def log_witness(path):
    """Exact target start/end only; no app/model text and no incomplete-log pass."""
    events, seen = [], 0
    pattern = re.compile(r"^Test Case '-\[(?:\w+\.)?IndoorGoalContinuityTests "
                         r"testTrackingLossStillInvalidatesRetainedMapFrame\]' (started|passed|failed|skipped)(?:[ .(])")
    with open(path, 'rb') as handle:
        while True:
            raw = handle.readline(1024 * 1024 + 1)
            if not raw:
                break
            seen += len(raw)
            if seen > 64 * 1024 * 1024 or len(raw) > 1024 * 1024:
                raise ValueError('Unit log exceeds bounded witness scan')
            match = pattern.search(raw.decode('utf-8', errors='replace'))
            if match:
                events.append(match.group(1))
                if len(events) > 16:
                    raise ValueError('Too many target executions')
    return events


def provenance(repo, expected):
    if not isinstance(expected, str) or re.fullmatch(r'[0-9a-f]{40}', expected) is None:
        raise ValueError('Missing or malformed workflow SHA')
    head = query(['git', '-C', str(repo), 'rev-parse', 'HEAD'], seconds=5).decode().strip()
    if head != expected:
        raise ValueError('Checkout HEAD differs from workflow SHA')
    # Includes staged/unstaged tracked source anywhere; no patch contents emitted.
    query(['git', '-C', str(repo), 'diff', '--quiet', 'HEAD', '--'], seconds=5)
    scopes = ['ios', 'BlindCore', 'BlindMemory', 'tools/ci', '.github/workflows']
    changes = query(['git', '-C', str(repo), 'status', '--porcelain=v1', '-z',
                     '--untracked-files=all', '--', *scopes], seconds=5).decode().split('\0')
    allowed = {'ios/BlindAssist.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved',
               'BlindMemory/Package.resolved'}
    if any(row and (not row.startswith('?? ') or row[3:] not in allowed) for row in changes):
        raise ValueError('Unexpected source or untracked file in tested scopes')
    # Reuse the already reviewed public-pin parser, after clean tracked-source check.
    spec = importlib.util.spec_from_file_location('native_lock_evidence',
        repo / 'research/indoor-io-buffered-diagnostic/resolution.py')
    module = importlib.util.module_from_spec(spec)
    old = sys.dont_write_bytecode
    try:
        sys.dont_write_bytecode = True
        spec.loader.exec_module(module)
    finally:
        sys.dont_write_bytecode = old
    metadata = []
    for name in sorted(allowed):
        module.PATH = name
        inspected = module.inspect(repo)
        if inspected['status'] not in {'absent', 'validated_public_exact_pin'}:
            raise ValueError('Unexpected generated dependency metadata')
        metadata.append(inspected)
    return {'actual_head': head, 'tracked_source_clean': True,
            'untracked_scopes': scopes, 'generated_metadata': metadata}


def route_evidence(repo, bundle, cases):
    """Fixed-schema public/synthetic attachments; cannot change case/target verdicts."""
    spec = importlib.util.spec_from_file_location('native_route_evidence',
        repo / 'tools/ci/native-route-diagnostic-evidence.py')
    module = importlib.util.module_from_spec(spec)
    old = sys.dont_write_bytecode
    try:
        sys.dont_write_bytecode = True
        spec.loader.exec_module(module)
        return module.collect(repo, bundle, cases, query)
    except (ValueError, OSError, KeyError, TypeError, RecursionError, subprocess.SubprocessError):
        # Never serialize arbitrary parser/OS text from an attachment.
        return {'schema': 1, 'status': 'collection_error', 'physicalAuthority': False}
    finally:
        sys.dont_write_bytecode = old


def encode_evidence(result):
    """The additive reports must not evict case statuses from the existing 1 MiB."""
    encoded = json.dumps(result, indent=2, allow_nan=False) + '\n'
    if len(encoded.encode()) <= 1024 * 1024:
        return encoded
    evidence = result.get('routeDiagnosticEvidence')
    if evidence is not None:
        for record in evidence.get('reports', []):
            if 'report' in record:
                del record['report']
                record['status'] = 'omitted_artifact_over_budget'
        evidence['status'] = 'artifact_over_budget'
        encoded = json.dumps(result, indent=2, allow_nan=False) + '\n'
        if len(encoded.encode()) > 1024 * 1024:
            result['routeDiagnosticEvidence'] = {'schema': 1, 'status': 'artifact_over_budget', 'physicalAuthority': False}
            # Compact representation retains every existing case if whitespace
            # rather than metadata was the limiting factor.
            encoded = json.dumps(result, separators=(',', ':'), allow_nan=False) + '\n'
    return encoded


def main():
    bundle, log, output = map(Path, sys.argv[1:4])
    result = {'schema': 1, 'target': TARGET, 'complete': False,
              'target_pass_verified': False, 'source_verified': False, 'expected_commit': os.environ.get('GITHUB_SHA'),
              'limits': {'query_bytes': CAP, 'query_seconds': 30, 'tree_nodes': 10000}}
    try:
        repo = Path(__file__).resolve().parents[2]
        verified_source = provenance(repo, os.environ.get('GITHUB_SHA'))
        result['provenance'] = verified_source
        result['source_commit'] = verified_source['actual_head']
        raw = query(['xcrun', 'xcresulttool', 'get', 'test-results', 'tests', '--path', str(bundle), '--compact'])
        cases = cases_from(json.loads(raw))
        summary_path = output.with_name('unit-summary.json')
        if summary_path.stat().st_size > 1024 * 1024:
            raise ValueError('Aggregate summary exceeds 1 MiB')
        counts = reconcile(cases, json.loads(summary_path.read_text()))
        witnesses = log_witness(log)
        targets = target_records(cases)
        result.update(cases=cases, case_count=len(cases), counts=counts, aggregate_counts_match=True, target_records=targets,
                      target_log_events=witnesses, complete=True,
                      query_sha256=hashlib.sha256(raw).hexdigest(),
                      target_pass_verified=len(targets) == 1 and targets[0]['result'] == 'Passed'
                      and witnesses == ['started', 'passed'])
        result['routeDiagnosticEvidence'] = route_evidence(repo, bundle, cases)
        if provenance(repo, os.environ.get('GITHUB_SHA')) != verified_source:
            raise ValueError('Source provenance changed during evidence collection')
        result['source_verified'] = True
        result['source_sha256'] = {name: hashlib.sha256((repo / name).read_bytes()).hexdigest()
            for name in ['ios/BlindAssistTests/CommunityTests.swift', 'ios/BlindAssist/SpatialMapIO.swift']}
    except (ValueError, OSError, RecursionError, subprocess.SubprocessError) as error:
        result['routeDiagnosticEvidence'] = {'schema': 1, 'status': 'source_or_cases_unverified', 'physicalAuthority': False}
        result.update(complete=False, target_pass_verified=False, source_verified=False,
                      error_type=type(error).__name__, error=str(error)[:256])
    encoded = encode_evidence(result)
    if len(encoded.encode()) > 1024 * 1024:
        result = {'schema': 1, 'complete': False, 'target_pass_verified': False, 'error': 'Evidence exceeds 1 MiB'}
        encoded = json.dumps(result) + '\n'
    output.write_text(encoded)
    print('NATIVE_UNIT_CASE_STATUSES=' + json.dumps(result, separators=(',', ':')))
    return 0 if result['complete'] else 1


if __name__ == '__main__':
    if len(sys.argv) == 4 and sys.argv[1] == '--summary':
        try:
            raw = query(['xcrun', 'xcresulttool', 'get', 'test-results', 'summary', '--path', sys.argv[2], '--compact'])
            value = json.loads(raw)
            if not isinstance(value, dict):
                raise ValueError('Unsupported aggregate summary schema')
            keys = ('result', 'totalTestCount', 'passedTests', 'failedTests', 'skippedTests',
                    'expectedFailures', 'startTime', 'finishTime')
            sanitized = {k: value[k] for k in keys if k in value and isinstance(value[k], (str, int, float))}
            Path(sys.argv[3]).write_text(json.dumps(sanitized) + '\n')
            print(Path(sys.argv[2]).stem + ' xcresult: ' + json.dumps(sanitized))
        except (ValueError, OSError, RecursionError, subprocess.SubprocessError) as error:
            Path(sys.argv[3]).write_text(json.dumps({'complete': False, 'error_type': type(error).__name__}) + '\n')
            print('Native summary unavailable: ' + type(error).__name__)
            raise SystemExit(1)
    else:
        raise SystemExit(main())

