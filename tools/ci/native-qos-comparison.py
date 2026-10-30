#!/usr/bin/env python3
"""Isolated hosted-Simulator diagnostic proposal. No default scheduling change.

Only explicit reviewed publication enables its dedicated workflow. Imported by
portable parser/command controls without invoking Xcode or any native process.
"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import signal
import stat
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
CASE = 'NativeQoSComparisonTests/testIsolatedUtilityUserInitiatedABBA'
SELECTION = 'BlindAssistTests/' + CASE
FLAG = 'BLIND_QOS_COMPARISON'
LOG_LIMIT = 64 * 1024 * 1024
LINE_LIMIT = 4096
RECORD_LIMIT = 64
BUILD_SECONDS = 900
LAUNCH_SECONDS = 120
CASE_SECONDS = 360
TEST_SECONDS = LAUNCH_SECONDS + CASE_SECONDS
NUMBER = r'(?:-1|[0-9]{1,15})'
POSITIVE = r'[0-9]{1,15}'
PAIR = lambda name: (rf'{name}=\[wall_ms=(?P<{name}_wall>{NUMBER}),'
                     rf'cpu_us=(?P<{name}_cpu>{NUMBER}),pair_valid=(?P<{name}_valid>true|false)\]')
STAGE = r'(?:requestEnqueued|workerStarted|nativeBuildBegin|nativeBuildEnd|routeBegin|routeEnd|nativeFailure|completionQueued|completionDelivered|discardRequested|discardWorkerStarted|discardReleased|discardCompletionDelivered|workerFinished|requestRetired|sourceSnapshotEnqueued|sourceSnapshotWorkerStarted|sourceSnapshotWorkerFinished|sourceSnapshotDeliveryStarted|sourceSnapshotDeliveryFinished)'
PATTERNS = {
    'deadline': re.compile(r'NATIVE_QOS_DEADLINE arm=(?P<arm>[0-3]) phase=(?P<phase>source|query|normal_drain) budget_s=10(?:\.0)? met=(?P<met>true|false) physical_authority=false'),
    'late': re.compile(r'NATIVE_QOS_LATE_DRAIN arm=(?P<arm>[0-3]) observation_s=45 acknowledged=(?P<ack>true|false) original_failure_preserved=true'),
    'source': re.compile(rf'NATIVE_QOS_SOURCE arm=(?P<arm>[0-3]) callback_ms=(?P<callback>{NUMBER}) process_offset_ms={POSITIVE}'),
    'arm': re.compile(rf'NATIVE_QOS_ARM arm=(?P<arm>[0-3]) requested=(?P<requested>utility|userInitiated) effective_raw=(?P<effective>unavailable|[0-9]{{1,10}}) elapsed_ms={POSITIVE} normal_drain=(?P<normal>true|false) late_ack=(?P<late>true|false) '
                      + ' '.join(PAIR(name) for name in ['worker', 'build', 'route'])
                      + rf' stages=(?:{STAGE}:[0-9]{{1,15}}(?:;{STAGE}:[0-9]{{1,15}}){{0,63}})? physical_authority=false'),
}


def require(ok, message):
    if not ok:
        raise ValueError(message)


def module(name, file):
    spec = importlib.util.spec_from_file_location(name, HERE / file)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def read_bounded(path, limit):
    require(path.is_file() and not path.is_symlink(), 'regular-file-required')
    with path.open('rb') as stream:
        require(stat.S_ISREG(os.fstat(stream.fileno()).st_mode), 'regular-file-required')
        data = stream.read(limit + 1)
    require(len(data) <= limit, 'file-budget')
    return data


def exact_case(identifier):
    return identifier in {CASE, CASE + '()', 'BlindAssistTests/' + CASE,
                          'BlindAssistTests/' + CASE + '()'}


def clean_commands(commands, expected):
    if set(commands) != {'build', 'test'}:
        return False
    return all(c.get('mode') == mode and type(c.get('command_exit')) is int
               and type(c.get('wrapper_exit')) is int
               and c['command_exit'] == c['wrapper_exit'] == 0
               and c.get('watchdog') is None and c.get('source_verified') is True
               and c.get('source_commit') == expected['source_commit']
               and c.get('source_hashes') == expected['source_hashes']
               for mode, c in commands.items())


def parse_records(raw):
    require(len(raw) <= LOG_LIMIT, 'log-budget')
    records, parsed = [], []
    rejected = dropped = 0
    for line in raw.splitlines():
        if not line.startswith(b'NATIVE_QOS_'):
            continue
        if len(line) > LINE_LIMIT:
            rejected += 1
            continue
        try:
            text = line.decode('ascii')
        except UnicodeDecodeError:
            rejected += 1
            continue
        match = next(((kind, pattern.fullmatch(text)) for kind, pattern in PATTERNS.items()
                      if pattern.fullmatch(text)), None)
        if match is None:
            rejected += 1
            continue
        kind, value = match
        row = value.groupdict()
        valid = True
        if kind == 'arm':
            for prefix in ['worker', 'build', 'route']:
                wall, cpu = int(row[prefix + '_wall']), int(row[prefix + '_cpu'])
                paired = row[prefix + '_valid'] == 'true'
                valid &= (wall >= 0 and cpu >= 0) if paired else cpu == -1
            valid &= not (row['normal'] == row['late'] == 'true')
            valid &= row['effective'] == 'unavailable' or int(row['effective']) <= 4294967295
        if not valid:
            rejected += 1
        elif len(records) < RECORD_LIMIT:
            records.append(text)
            parsed.append((kind, row))
        else:
            dropped += 1
    arm_rows = [row for kind, row in parsed if kind == 'arm']
    expected = [('0', 'utility'), ('1', 'userInitiated'), ('2', 'userInitiated'), ('3', 'utility')]
    arms_complete = [(r['arm'], r['requested']) for r in arm_rows] == expected
    deadlines = [(r['arm'], r['phase'], r['met']) for kind, r in parsed if kind == 'deadline']
    normal_deadlines_met = sorted(deadlines) == sorted((str(a), phase, 'true') for a in range(4) for phase in ['source', 'query', 'normal_drain'])
    sources = [r for kind, r in parsed if kind == 'source']
    sources_complete = [r['arm'] for r in sources] == ['0', '1', '2', '3'] and all(int(r['callback']) >= 0 for r in sources)
    late = any(kind == 'late' for kind, _ in parsed)
    clean_protocol = (arms_complete and sources_complete and normal_deadlines_met and not late
                      and all(r['normal'] == 'true' and r['late'] == 'false' for r in arm_rows)
                      and rejected == dropped == 0)
    effective = [r['effective'] for r in arm_rows]
    separation = (arms_complete and 'unavailable' not in effective and
                  len({effective[0], effective[3]}) == len({effective[1], effective[2]}) == 1 and
                  effective[0] != effective[1])
    return {'records': records, 'rejected_prefix_records': rejected, 'dropped_records': dropped,
            'four_arms_recorded': arms_complete, 'all_normal_deadlines_met': normal_deadlines_met,
            'late_observation_present': late, 'clean_protocol_records': clean_protocol,
            'effective_qos_separation_observed': separation,
            'qos_causality_or_fix_established': False, 'physical_authority': False}


def command(mode, device, out):
    require(mode in {'build', 'test'}, 'command-mode')
    require(re.fullmatch(r'[0-9A-Fa-f]{8}(?:-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}', device) is not None, 'simulator-id')
    args = ['xcodebuild', '-project', 'ios/BlindAssist.xcodeproj', '-scheme', 'BlindAssist',
            '-configuration', 'Debug', '-jobs', '2', '-derivedDataPath', str(out / 'DerivedData'),
            '-destination', 'platform=iOS Simulator,id=' + device, '-destination-timeout', '120',
            '-parallel-testing-enabled', 'NO', '-maximum-concurrent-test-simulator-destinations', '1',
            '-only-testing:' + SELECTION, 'CODE_SIGNING_ALLOWED=NO',
            'SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) DEBUG ' + FLAG,
            '-resultBundlePath', str(out / (mode + '.xcresult')),
            'build-for-testing' if mode == 'build' else 'test-without-building']
    return args


def source_receipt():
    expected = os.environ.get('GITHUB_SHA', '')
    require(re.fullmatch('[0-9a-f]{40}', expected) is not None, 'workflow-sha')
    native = module('native_qos_status_reader', 'export-native-unit-statuses.py')
    provenance = native.provenance(ROOT, expected)
    paths = ['ios/BlindAssist.xcodeproj/project.pbxproj',
             'ios/BlindAssistTests/NativeQoSComparisonTests.swift',
             'research/room-mesh-package-75/BlindRoomMesh/Package.swift',
             'research/room-mesh-package-75/BlindRoomMesh/Sources/BlindRoomMesh/RoomMeshCandidate.swift']
    contents = [read_bounded(ROOT / p, 2 * 1024 * 1024) for p in paths]
    project, test, package, runtime = [x.decode() for x in contents]
    require(FLAG not in project and FLAG not in package, 'default-project-or-package-experiment-flag')
    require(test.startswith('#if DEBUG && BLIND_QOS_COMPARISON && canImport(Darwin)\n'), 'test-flag-guard')
    require(re.findall(r'^\s*func\s+(test\w+)\s*\(', test, re.M) == [CASE.split('/')[1]], 'exact-one-test-source')
    require(test.count('.configureSyntheticComparisonQoS(') == 1, 'explicit-test-opt-in')
    require('private var comparisonQoS: DispatchQoS?' in runtime and
            'guard let qos=locked({comparisonQoS}) else { Self.worker.async(execute:work); return }' in runtime,
            'inactive-default-runtime-hook')
    require(FLAG not in runtime, 'package-must-not-depend-on-test-flag-propagation')
    for folder in ['ios/BlindAssist', 'ios/BlindAssistTests']:
        for index, path in enumerate((ROOT / folder).glob('*.swift')):
            require(index < 2048, 'caller-scan-file-budget')
            if path.name != 'NativeQoSComparisonTests.swift':
                require('.configureSyntheticComparisonQoS(' not in read_bounded(path, 2 * 1024 * 1024).decode(), 'unexpected-override-caller')
    return {'source_commit': provenance['actual_head'], 'source_verified': True,
            'source_hashes': {p: hashlib.sha256(b).hexdigest() for p, b in zip(paths, contents)},
            'default_project_experiment_flag': False, 'package_experiment_flag_required': False,
            'package_hook': 'DEBUG-only-explicit-opt-in-inactive-by-default'}


def watchdog_reason(mode, elapsed, case_elapsed, size):
    if size > LOG_LIMIT: return 'log-budget'
    if mode == 'build' and elapsed > BUILD_SECONDS: return 'build-process-deadline'
    if mode == 'test' and elapsed > TEST_SECONDS: return 'test-process-deadline'
    if mode == 'test' and case_elapsed is None and elapsed > LAUNCH_SECONDS: return 'test-launch-deadline'
    if case_elapsed is not None and case_elapsed > CASE_SECONDS: return 'test-case-observation-deadline'
    return None


def terminate(process):
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        return
    try:
        process.wait(timeout=2)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGKILL)
        process.wait(timeout=5)


def run(mode, out):
    require(sys.platform == 'darwin', 'Apple-host-required')
    require(os.environ.get('GITHUB_REPOSITORY') == 'mischa23v/blind' and
            os.environ.get('GITHUB_REF') == 'refs/heads/codex/recovery-hazard-order-20261027', 'approved-repository-branch')
    before = source_receipt()
    device = read_bounded(Path(os.environ['RUNNER_TEMP']) / 'blind-native-ci/simulator-id', 64).decode('ascii').strip()
    args = command(mode, device, out)
    receipt = {'schema': 1, 'mode': mode, 'command_exit': None, 'wrapper_exit': None,
               'watchdog': None, 'test_started_observed': False, 'physical_authority': False, **before}
    path = out / (mode + '.log')
    started = time.monotonic()
    case_started = None
    position, tail = 0, b''
    marker = b"Test Case '-[BlindAssistTests.NativeQoSComparisonTests testIsolatedUtilityUserInitiatedABBA]' started."
    process = None
    try:
        with path.open('xb') as output:
            process = subprocess.Popen(args, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
            while process.poll() is None:
                now = time.monotonic()
                size = path.stat().st_size
                with path.open('rb') as source:
                    source.seek(position);chunk = source.read(min(65536, max(0, size-position)));position += len(chunk)
                if mode == 'test' and case_started is None and marker in tail + chunk:
                    case_started = now;receipt['test_started_observed'] = True
                tail = (tail + chunk)[-len(marker):]
                reason = watchdog_reason(mode, now-started,
                                         None if case_started is None else now-case_started, size)
                if reason:
                    receipt['watchdog'] = reason;terminate(process);break
                time.sleep(0.1)
            receipt['command_exit'] = process.wait(timeout=5)
        receipt['wrapper_exit'] = 124 if receipt['watchdog'] else receipt['command_exit']
        after = source_receipt()
        require(before == after, 'source-changed-during-diagnostic')
        receipt['source_verified'] = True
    except Exception as error:
        if process is not None and process.poll() is None:terminate(process)
        receipt.update(wrapper_exit=1, source_verified=False, error_type=type(error).__name__)
    finally:
        (out / (mode + '-command.json')).write_text(json.dumps(receipt, sort_keys=True) + '\n')
        print('NATIVE_QOS_COMMAND=' + json.dumps(receipt, sort_keys=True))
    return receipt['wrapper_exit'] if type(receipt['wrapper_exit']) is int and receipt['wrapper_exit'] >= 0 else 1


def collect(out):
    receipt = {'schema': 1, 'status': 'unavailable', 'physical_authority': False,
               'scope': 'isolated hosted simulator scheduling diagnostic; not normal acceptance',
               'qos_causality_or_fix_established': False, 'errors': []}
    native = module('native_qos_status_collector', 'export-native-unit-statuses.py')
    # Independent projections retain failed/incomplete records even if another
    # input is absent. Errors are fixed labels, never arbitrary source/model text.
    exceptions = (OSError, ValueError, TypeError, KeyError, RecursionError, subprocess.SubprocessError)
    verified = None
    try:
        verified = source_receipt();receipt.update(verified)
    except exceptions:
        receipt['errors'].append('source-provenance-unavailable')
    commands = {}
    for mode in ['build', 'test']:
        try:
            value = json.loads(read_bounded(out / (mode + '-command.json'), 16384))
            require(isinstance(value, dict), 'command-shape')
            # These are our own bounded scalar command receipts; never copy
            # arbitrary keys/values into public evidence if a file is replaced.
            require(set(value) <= {'schema', 'mode', 'command_exit', 'wrapper_exit', 'watchdog',
                    'test_started_observed', 'physical_authority', 'source_commit', 'source_verified',
                    'source_hashes', 'default_project_experiment_flag', 'package_experiment_flag_required',
                    'package_hook', 'error_type'}, 'command-keys')
            require(value.get('mode') == mode, 'command-mode')
            require(value.get('watchdog') in {None, 'log-budget', 'build-process-deadline',
                    'test-process-deadline', 'test-launch-deadline', 'test-case-observation-deadline'}, 'watchdog')
            commands[mode] = value
            receipt.setdefault('commands', {})[mode] = {
                'command_exit': value.get('command_exit') if type(value.get('command_exit')) is int else None,
                'wrapper_exit': value.get('wrapper_exit') if type(value.get('wrapper_exit')) is int else None,
                'watchdog': value.get('watchdog'), 'source_verified': value.get('source_verified') is True,
                'test_started_observed': value.get('test_started_observed') is True}
        except exceptions:
            receipt['errors'].append(mode + '-command-unavailable')
    try:
        receipt.update(parse_records(read_bounded(out / 'test.log', LOG_LIMIT)))
    except exceptions:
        receipt['errors'].append('timing-records-unavailable')
    cases, exact = [], False
    try:
        bundle = out / 'test.xcresult'
        cases = native.cases_from(json.loads(native.query(['xcrun', 'xcresulttool', 'get', 'test-results', 'tests', '--path', str(bundle), '--compact'])))
        selected = [c for c in cases if exact_case(c['identifier'])]
        receipt.update(cases=selected[:16], case_rows_omitted=max(0, len(selected)-16),
                       unexpected_case_count=len(cases)-len(selected))
        summary = json.loads(native.query(['xcrun', 'xcresulttool', 'get', 'test-results', 'summary', '--path', str(bundle), '--compact']))
        receipt['counts'] = native.reconcile(cases, summary)
        exact = len(cases) == len(selected) == 1
    except exceptions:
        receipt['errors'].append('xcresult-evidence-incomplete')
    receipt['exact_test_identity_verified'] = exact
    clean = (verified is not None and clean_commands(commands, verified) and exact
             and cases[0]['result'] == 'Passed' and receipt.get('clean_protocol_records') is True
             and not receipt['errors'])
    receipt['status'] = 'passed-isolated-diagnostic' if clean else 'failed-or-incomplete-diagnostic'
    encoded = json.dumps(receipt, sort_keys=True, separators=(',', ':'))
    require(len(encoded.encode()) <= 384 * 1024, 'receipt-output-budget')
    line = 'NATIVE_QOS_RECEIPT=' + encoded
    print(line)
    (out / 'result.json').write_text(encoded + '\n')
    if os.environ.get('GITHUB_STEP_SUMMARY'):
        with open(os.environ['GITHUB_STEP_SUMMARY'], 'a') as stream:
            stream.write('\n### Isolated QoS diagnostic, not app acceptance\n```text\n' + line + '\n```\n')
    return 0 if clean else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=['build', 'test', 'collect'])
    args = parser.parse_args()
    out = Path(os.environ['RUNNER_TEMP']) / 'blind-native-qos-comparison'
    out.mkdir(exist_ok=True)
    return collect(out) if args.mode == 'collect' else run(args.mode, out)


if __name__ == '__main__':
    raise SystemExit(main())
