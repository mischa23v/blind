#!/usr/bin/env python3
"""Read-only candidate diagnostic. No source edits, generation, signing or UI tests."""
import collections
import datetime
import hashlib
import json
import os
import pathlib
import re
import selectors
import signal
import subprocess
import sys
import time

PINS = {
    'baseline': '106cc2ad9565513af578d9325110213216e8cc39',
    'review': '8d878c86ab0b3a96d5fd44b31b418fbdc9bc5ed6',
}
PHASES = ['preflight', 'build', 'single-1', 'single-2', 'single-3', 'class']
SINGLE_TEST = 'testTrackingLossStillInvalidatesRetainedMapFrame'
CLASS_TESTS = {SINGLE_TEST, 'testTaskCancellationRetiresRouteButPreservesPreviewFrame',
    'testCancellationAfterWithheldLegacyCueClearsMessageInBothLanguages',
    'testConfirmedFinalWaypointHasNoActiveRoute', 'testTaskCancellationCannotCreateUnknownAlignment',
    'testExplicitReplanDoesNotReuseOldRouteAlignment'}
FILES = [
    'ios/BlindAssist.xcodeproj/project.pbxproj',
    'ios/BlindAssist.xcodeproj/xcshareddata/xcschemes/BlindAssist.xcscheme',
    'BlindCore/Package.swift', 'BlindMemory/Package.swift',
    'ios/BlindAssistTests/CommunityTests.swift',
    'ios/BlindAssist/IndoorNavigator.swift',
    'ios/BlindAssist/RegisteredIndoorNavigation.swift',
    'ios/BlindAssist/SpatialMapIO.swift',
    'ios/BlindAssist/NavigationModel.swift',
]


def main():
    source, expected, label = pathlib.Path(sys.argv[1]).resolve(), sys.argv[2], sys.argv[3]
    if PINS.get(label) != expected:
        raise SystemExit('Unexpected comparison pin')
    out = pathlib.Path(os.environ['RUNNER_TEMP']) / 'focused-indoor-io'
    evidence = out / 'evidence'
    evidence.mkdir(parents=True, exist_ok=True)
    summary = {
        'label': label, 'expected_sha': expected,
        'limitation': 'No reproduction is not a fix. These repetitions do not establish latency or physical navigation safety.',
        'phases': {p: {'status': 'not_run', 'reason': 'not reached'} for p in PHASES},
    }

    def save():
        (evidence / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
        lines = ['# Focused indoor IO diagnostic: ' + label, '', summary['limitation'], '',
                 '| Phase | Outcome | Exit |', '|---|---|---|']
        for p, v in summary['phases'].items():
            lines.append(f"| {p} | {v['status']} | {v.get('exit_code', '')} |")
        (evidence / 'summary.md').write_text('\n'.join(lines) + '\n')

    def small(args):
        return subprocess.check_output(args, cwd=source, stderr=subprocess.STDOUT, timeout=30).decode(errors='replace').strip()

    def run(name, args, limit):
        # Streaming capture is bounded in memory and on disk; no full build log is retained.
        start = time.monotonic()
        record = {'status': 'running', 'wall_limit_seconds': limit,
                  'started_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'command': args}
        summary['phases'][name] = record
        save()
        tail, issues = collections.deque(maxlen=100), []
        issue_count = 0
        test_outcomes = {}
        pattern = re.compile(r'error:|fatal|failed|Asynchronous wait|XCTUnwrap|Test Case|Test Suite|Executed |\*\* (BUILD|TEST)', re.I)
        process = subprocess.Popen(args, cwd=source, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, start_new_session=True)
        sel = selectors.DefaultSelector()
        sel.register(process.stdout, selectors.EVENT_READ)
        buffer = b''
        timed_out = False

        def keep(raw):
            nonlocal issue_count
            line = raw.decode(errors='replace')[:1000]
            tail.append(line)
            match = re.search(r"Test Case '-\[BlindAssistTests\.IndoorGoalContinuityTests (test[^ ]+)\]' (passed|failed)", line)
            if match:
                key, outcome = match.groups()
                # A later pass cannot erase a previous failure from the same invocation.
                if test_outcomes.get(key) != 'failed':
                    test_outcomes[key] = outcome
            if pattern.search(line):
                issue_count += 1
                if len(issues) < 160:
                    issues.append(line)

        while sel.get_map():
            if time.monotonic() - start >= limit:
                timed_out = True
                # Kill the entire xcodebuild process group; no unbounded cleanup wait.
                try:
                    os.killpg(process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                break
            for key, _ in sel.select(timeout=0.5):
                chunk = os.read(key.fileobj.fileno(), 16384)
                if not chunk:
                    sel.unregister(key.fileobj)
                    continue
                buffer += chunk
                while b'\n' in buffer:
                    line, buffer = buffer.split(b'\n', 1)
                    keep(line)
                # Bound malformed / unterminated log lines as well.
                if len(buffer) > 16384:
                    keep(buffer[:1000] + b' [unterminated line truncated]')
                    buffer = b''
        if buffer:
            keep(buffer)
        sel.close()
        process.stdout.close()
        try:
            code = process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            code = process.wait(timeout=5)
            timed_out = True
        record.update(status='timed_out' if timed_out else ('passed' if code == 0 else 'failed'),
                      exit_code=code, elapsed_seconds=round(time.monotonic() - start, 3),
                      diagnostic_lines_total=issue_count, diagnostic_lines_retained=len(issues))
        if name.startswith('single-') or name == 'class':
            expected_tests = CLASS_TESTS if name == 'class' else {SINGLE_TEST}
            expected_count = len(expected_tests)
            record['test_outcomes'] = test_outcomes
            record['expected_test_count'] = expected_count
            record['expected_tests'] = sorted(expected_tests)
            if set(test_outcomes) != expected_tests or any(v != 'passed' for v in test_outcomes.values()):
                record['coverage_complete_and_passed'] = False
                if record['status'] == 'passed':
                    record['status'] = 'failed'
                    record['reason'] = 'Expected original test executions were not all observed passing'
            else:
                record['coverage_complete_and_passed'] = True
        (evidence / (name + '.txt')).write_text(
            json.dumps(record, indent=2) + '\nDIAGNOSTICS (first 160, each <=1000 chars)\n' +
            '\n'.join(issues) + '\nTAIL (last 100, each <=1000 chars)\n' + '\n'.join(tail) + '\n')
        print(name + ': ' + record['status'] + ', exit=' + str(code), flush=True)
        save()
        return record['status'] == 'passed'

    save()
    try:
        summary['phases']['preflight'] = {'status': 'running'}
        save()
        assert small(['uname', '-s']) == 'Darwin', 'Apple runner required'
        assert small(['git', 'rev-parse', 'HEAD']) == expected, 'Source pin mismatch'
        assert not small(['git', 'status', '--porcelain']), 'Candidate checkout must be clean'
        xcode = small(['xcodebuild', '-version'])
        assert xcode.splitlines()[0] == 'Xcode 27.0', 'Unexpected Xcode'
        sdk = small(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-version'])
        assert sdk == '27.0', 'Unexpected simulator SDK'
        project = (source / FILES[0]).read_text()
        assert not re.search(r'BLIND_[A-Z_]+|opencv2|\.mlmodelc|\.mlpackage', project), 'Optional project backend rejected'
        devices = json.loads(small(['xcrun', 'simctl', 'list', 'devices', 'available', '--json']))['devices']
        phone = next((d for d in devices.get('com.apple.CoreSimulator.SimRuntime.iOS-27-0', [])
                      if d.get('isAvailable') and d['name'] == 'iPhone 18 Pro Max'), None)
        assert phone, 'Installed iPhone 18 Pro Max / iOS 27.0 required; no download attempted'
        provenance = {
            'source_sha': expected, 'harness_sha': os.environ.get('GITHUB_SHA'),
            'helper_sha256': hashlib.sha256(pathlib.Path(__file__).read_bytes()).hexdigest(),
            'macos': small(['sw_vers', '-productVersion']), 'macos_build': small(['sw_vers', '-buildVersion']),
            'xcode': xcode, 'swift': small(['xcrun', 'swift', '--version']), 'simulator_sdk': sdk,
            'simulator': {'name': phone['name'], 'runtime': 'iOS 27.0', 'udid': phone['udid']},
            'source_sha256': {p: hashlib.sha256((source / p).read_bytes()).hexdigest() for p in FILES},
        }
        (evidence / 'provenance.json').write_text(json.dumps(provenance, indent=2) + '\n')
        summary['phases']['preflight'] = {'status': 'passed'}
        save()
        base = ['xcodebuild', '-project', 'ios/BlindAssist.xcodeproj', '-scheme', 'BlindAssist',
                '-configuration', 'Debug', '-jobs', '2', '-derivedDataPath', str(out / 'DerivedData'),
                'CODE_SIGNING_ALLOWED=NO']
        if run('build', base + ['-destination', 'generic/platform=iOS Simulator', 'build'], 1080):
            for phase in PHASES[2:]:
                selector = 'BlindAssistTests/IndoorGoalContinuityTests'
                if phase != 'class':
                    selector += '/testTrackingLossStillInvalidatesRetainedMapFrame'
                # Original test, unchanged timeout/assertions. Separate invocation each time.
                args = base + ['-destination', 'platform=iOS Simulator,id=' + phone['udid'],
                    '-destination-timeout', '120', '-parallel-testing-enabled', 'NO',
                    '-maximum-concurrent-test-simulator-destinations', '1', '-only-testing:' + selector,
                    '-resultBundlePath', str(out / (phase + '.xcresult')), 'test']
                run(phase, args, 360)
        else:
            for phase in PHASES[2:]:
                summary['phases'][phase]['reason'] = 'default unsigned build did not pass'
        summary['source_clean_after'] = not bool(small(['git', 'status', '--porcelain']))
        if not summary['source_clean_after']:
            summary['integrity_error'] = 'Candidate checkout changed during diagnostic'
    except Exception as exc:
        summary['error'] = str(exc)[:2000]
        for phase in PHASES:
            if summary['phases'][phase]['status'] == 'running':
                summary['phases'][phase] = {'status': 'failed', 'reason': str(exc)[:2000]}
        print('Diagnostic stopped: ' + str(exc)[:2000], flush=True)
    finally:
        save()
        if os.environ.get('GITHUB_STEP_SUMMARY'):
            with open(os.environ['GITHUB_STEP_SUMMARY'], 'a') as stream:
                stream.write((evidence / 'summary.md').read_text())
    return 0 if all(v['status'] == 'passed' for v in summary['phases'].values()) and not summary.get('integrity_error') and not summary.get('error') else 1


if __name__ == '__main__':
    sys.exit(main())
