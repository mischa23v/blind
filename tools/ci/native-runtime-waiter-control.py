#!/usr/bin/env python3
"""Fixed candidate-first/original-second fixture control; no retries or latency waiver."""
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import time
import uuid

SOURCE = 'de0da00424b5dd3cae9e98e67894eddcffc74447'
TEST_PATH = 'ios/BlindAssistTests/ConnectedJourneyRuntimeTests.swift'
TEST_BLOB = 'e362684225254aa8c5c7c69e01ea92fcd4f980bc'
EXTRACTOR_BLOB = '311a436564deef0b2add4e0a5f601e5ca51ebeca'
CANDIDATE = 'tools/diagnostics/runtime-waiter-control/ConnectedJourneyRuntimeTests.swift'
RUNTIME = 'com.apple.CoreSimulator.SimRuntime.iOS-27-0'
DEVICE_TYPE = 'com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro-Max'
MODES = ('publication-v1', 'original-v1')
ENV_KEY = 'TEST_RUNNER_BLIND_RUNTIME_WAITER_CONTROL'
PREFIX = 'NATIVE_RUNTIME_WAITER_CONTROL'


def emit(**values):
    print(PREFIX + ' ' + json.dumps(values, sort_keys=True), flush=True)


def capture(command, cwd=None, env=None):
    return subprocess.check_output(command, text=True, timeout=30, cwd=cwd, env=env)


def run(command, timeout, log, cwd=None, env=None):
    started = time.monotonic()
    status = 124
    with log.open('w') as output:
        process = subprocess.Popen(command, stdout=output, stderr=subprocess.STDOUT,
                                   start_new_session=True, cwd=cwd, env=env)
        try:
            status = process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait()
    emit(phase=log.stem, exit=status, elapsed_seconds=time.monotonic() - started)
    return status


def failure_excerpt(log):
    if not log.is_file():
        emit(phase='failure-excerpt', available=False)
        return
    pattern = re.compile(r'error:|fatal|destination|ineligible|unavailable|timed out|BUILD FAILED', re.I)
    matches = 0
    clipped = 0
    with log.open(errors='replace') as stream:
        for raw in stream:
            if not pattern.search(raw):
                continue
            matches += 1
            if matches <= 60:
                text = re.sub(r'/(?:Users|home|workspace|tmp|private|var)/[^\s,;\]}]+',
                              '[local path redacted]', raw.rstrip())
                clipped += len(text) > 1200
                emit(phase='failure-excerpt', redacted=True, text=text[:1200])
    emit(phase='failure-excerpt-counts', matching=matches,
         omitted=max(0, matches - 60), clipped_lines=clipped)


def test_names(source):
    names = re.findall(r'^    func (test\w+)\(', source, re.M)
    if len(names) != 17 or len(set(names)) != 17:
        raise RuntimeError('Expected unchanged seventeen test methods')
    return set(names)


def verify_test_copy(baseline, candidate):
    expected = test_names(baseline)
    if test_names(candidate) != expected:
        raise RuntimeError('Candidate test method identity mismatch')
    marker = '    private func installed('
    if baseline.count(marker) != 1 or candidate.count(marker) != 1 or baseline.split(marker, 1)[1] != candidate.split(marker, 1)[1]:
        raise RuntimeError('Test bodies and original assertions must be byte-identical')
    return expected


def mode_proof(log, mode, expected):
    records = []
    with log.open(errors='replace') as stream:
        for line in stream:
            if 'NATIVE_RUNTIME_WAITER_MODE ' in line:
                records.append(line[line.index('NATIVE_RUNTIME_WAITER_MODE '):].rstrip())
    valid = len(records) == 17
    observed = []
    for record in records:
        match = re.fullmatch(r'NATIVE_RUNTIME_WAITER_MODE mode=(publication-v1|original-v1) test=-\[ConnectedJourneyRuntimeTests (test\w+)\]', record)
        if match is None or match[1] != mode:
            valid = False
        else:
            observed.append(match[2])
    valid = valid and len(set(observed)) == 17 and set(observed) == expected
    for record in records[:17]:
        # Allowlist syntax before printing: do not expose arbitrary environment/output.
        if re.fullmatch(r'NATIVE_RUNTIME_WAITER_MODE mode=(publication-v1|original-v1) test=-\[ConnectedJourneyRuntimeTests test\w+\]', record):
            print(record, flush=True)
    emit(phase='mode-proof', mode=mode, count=len(records), omitted=max(0, len(records)-17), valid=valid)
    return valid


def control_excerpt(log, mode):
    # Buffered test metadata only; do not add stdout to the timed callback path.
    matched = 0
    clipped = 0
    with log.open(errors='replace') as stream:
        for raw in stream:
            if not raw.startswith(('NATIVE_RUNTIME_CONTROL ', 'NATIVE_RUNTIME_TRACE ')):
                continue
            matched += 1
            if matched <= 400:
                text = raw.rstrip()
                clipped += len(text) > 2048
                print(text[:2048], flush=True)
    emit(phase='control-excerpt', mode=mode, matching=matched,
         retained=min(400, matched), omitted=max(0, matched - 400), clipped_lines=clipped)


def app_fingerprint(derived):
    products = derived / 'Build' / 'Products'
    host = products / 'Debug-iphonesimulator' / 'BlindAssist.app'
    bundles = sorted(p for p in products.rglob('BlindAssistTests.xctest') if p.is_dir())
    if not host.is_dir() or len(bundles) != 1:
        raise RuntimeError('Expected compiled host and one hosted test bundle')
    # Hash both host and hosted test bundle, including all resources/dylibs. The
    # scheme may also build a UI runner, but this control never executes it.
    files = sorted(set(p for root in (host, bundles[0]) for p in root.rglob('*') if p.is_file()))
    if not files:
        raise RuntimeError('Built host/test files missing')
    digest = hashlib.sha256()
    for path in files:
        digest.update(str(path.relative_to(products)).encode() + b'\0')
        with path.open('rb') as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b''):
                digest.update(chunk)
    return digest.hexdigest()


def device_state(owned):
    devices = json.loads(capture(['xcrun', 'simctl', 'list', 'devices', '--json']))
    return next(d['state'] for d in devices['devices'][RUNTIME]
                if d['udid'].lower() == owned.lower())


def create_device():
    created = capture(['xcrun', 'simctl', 'create', 'Blind waiter fixture control', DEVICE_TYPE, RUNTIME]).strip()
    uuid.UUID(created)  # Validate but preserve Apple's spelling.
    return created


def cleanup(owned, out, mode):
    statuses = []
    for action in ('shutdown', 'delete'):
        try:
            statuses.append(run(['xcrun', 'simctl', action, owned], 30,
                                out / (mode + '-' + action + '.log')))
        except (OSError, subprocess.SubprocessError):
            statuses.append(125)
    emit(phase='cleanup', mode=mode, device=owned, shutdown_exit=statuses[0], delete_exit=statuses[1])
    return statuses[1] == 0


def test_command(derived, owned, result):
    return ['xcodebuild', '-project', 'ios/BlindAssist.xcodeproj', '-scheme', 'BlindAssist',
            '-configuration', 'Debug', '-jobs', '2', '-derivedDataPath', str(derived),
            'CODE_SIGNING_ALLOWED=NO', '-destination', 'platform=iOS Simulator,id=' + owned,
            '-destination-timeout', '120', '-parallel-testing-enabled', 'NO',
            '-maximum-concurrent-test-simulator-destinations', '1',
            '-only-testing:BlindAssistTests/ConnectedJourneyRuntimeTests',
            '-resultBundlePath', str(result), 'test-without-building']


def run_arm(mode, owned, source, out, derived, expected, fingerprint):
    state = device_state(owned)
    emit(phase='before-boot', mode=mode, device=owned, state=state)
    if state != 'Shutdown':
        raise RuntimeError('Fresh owned simulator must remain Shutdown before measured boot')
    boot_log = out / (mode + '-boot.log')
    if run(['xcrun', 'simctl', 'bootstatus', owned, '-b'], 180, boot_log):
        failure_excerpt(boot_log)
        return dict(mode=mode, attempted=False, reason='boot-infrastructure-failed', valid=False)
    if app_fingerprint(derived) != fingerprint:
        raise RuntimeError('Built app changed before arm')
    env = os.environ.copy()
    env[ENV_KEY] = mode
    log = out / (mode + '-runtime.log')
    result = out / (mode + '.xcresult')
    status = run(test_command(derived, owned, result), 900, log, cwd=source, env=env)
    try:
        proof = mode_proof(log, mode, expected)
        control_excerpt(log, mode)
        extraction = subprocess.run(['python3', str(source / 'tools/ci/extract-native-unit-failures.py'), str(log)],
                                    timeout=30, check=False).returncode
        summary_path = out / (mode + '-summary.json')
        summary_status = run(['xcrun', 'xcresulttool', 'get', 'test-results', 'summary', '--path', str(result)],
                             30, summary_path)
        selected = None
        valid_summary = False
        if summary_status == 0:
            try:
                summary = json.loads(summary_path.read_text())
                keys = ('result', 'totalTestCount', 'passedTests', 'failedTests', 'skippedTests')
                selected = {key: summary[key] for key in keys}
                counts = [selected[key] for key in keys[1:]]
                valid_summary = (all(type(n) is int for n in counts) and counts == [17, 17, 0, 0]
                                 and selected['result'] == 'Passed')
            except (ValueError, KeyError, TypeError):
                pass
        unchanged = app_fingerprint(derived) == fingerprint
        valid = status == 0 and proof and extraction == 0 and valid_summary and unchanged
        emit(phase='arm-result', mode=mode, attempted=True, test_exit=status, summary=selected,
             mode_valid=proof, same_built_app=unchanged, valid=valid)
        return dict(mode=mode, attempted=True, valid=valid, test_exit=status, summary=selected)
    except (RuntimeError, subprocess.SubprocessError, ValueError, KeyError, StopIteration, OSError) as error:
        emit(phase='arm-evidence-error', mode=mode, attempted=True, test_exit=status,
             reason=type(error).__name__, valid=False)
        return dict(mode=mode, attempted=True, valid=False, test_exit=status, reason=type(error).__name__)


def fixed_pair(first_owned, source, out, derived, expected, fingerprint):
    results = []
    cleanup_ok = True
    for index, mode in enumerate(MODES):
        owned = first_owned if index == 0 else None
        try:
            if owned is None:
                owned = create_device()
            emit(phase='owned-device', mode=mode, device=owned, pre_state=device_state(owned))
            results.append(run_arm(mode, owned, source, out, derived, expected, fingerprint))
        except (RuntimeError, subprocess.SubprocessError, ValueError, KeyError, StopIteration, OSError) as error:
            emit(phase='arm-infrastructure-error', mode=mode, reason=type(error).__name__)
            results.append(dict(mode=mode, attempted=False, valid=False, reason=type(error).__name__))
        finally:
            if owned is not None:
                cleanup_ok = cleanup(owned, out, mode) and cleanup_ok
        # Never break after a functional failure; exactly two fixed arms, no retries.
    valid = cleanup_ok and len(results) == 2 and all(r['valid'] for r in results)
    emit(phase='pair-result', results=results, cleanup_valid=cleanup_ok, valid=valid,
         interpretation='Candidate first, original second; boot-ready cold apps; host/load/order confounded; not production repair')
    return 0 if valid else 1


def require_hosted_runner():
    if os.environ.get("RUNNER_ENVIRONMENT") != "github-hosted":
        raise RuntimeError("GitHub-hosted runner required; no self-hosted execution")


def main(source):
    require_hosted_runner()
    source = source.resolve()
    producer = Path(__file__).resolve().parents[2]
    if capture(['uname', '-s']).strip() != 'Darwin' or not Path(os.environ['DEVELOPER_DIR']).is_dir():
        raise RuntimeError('Selected Apple runner/toolchain required')
    if capture(['git', 'rev-parse', 'HEAD'], cwd=source).strip() != SOURCE:
        raise RuntimeError('Pinned baseline mismatch')
    if capture(['git', 'status', '--porcelain', '--untracked-files=no'], cwd=source).strip():
        raise RuntimeError('Baseline is not pristine')
    for path, blob in ((TEST_PATH, TEST_BLOB), ('tools/ci/extract-native-unit-failures.py', EXTRACTOR_BLOB)):
        if capture(['git', 'hash-object', path], cwd=source).strip() != blob:
            raise RuntimeError('Reviewed baseline preimage mismatch')
    baseline = (source / TEST_PATH).read_text()
    candidate = (producer / CANDIDATE).read_text()
    expected = verify_test_copy(baseline, candidate)
    # Runner-installed Apple man page is the authoritative environment contract.
    man_env = dict(os.environ, MANPAGER='cat', PAGER='cat', MANWIDTH='160')
    manual = capture(['man', 'xcodebuild'], env=man_env)
    manual = re.sub('.\x08', '', manual)
    if 'TEST_RUNNER_' not in manual:
        raise RuntimeError('Installed xcodebuild TEST_RUNNER environment contract unavailable')
    emit(phase='environment-contract', supported=True, source='installed Apple xcodebuild manual')
    out = Path(os.environ['RUNNER_TEMP']) / 'blind-runtime-waiter-control'
    out.mkdir(parents=True, exist_ok=True)
    emit(source=SOURCE, test_preimage=TEST_BLOB, fixed_modes=list(MODES),
         candidate_sha256=hashlib.sha256(candidate.encode()).hexdigest())
    for command, name in ((['xcodebuild', '-version'], 'xcode-version'),
                          (['xcrun', 'swift', '--version'], 'swift-version'),
                          (['xcrun', 'simctl', 'help', 'bootstatus'], 'bootstatus-help')):
        if run(command, 30, out / (name + '.log')):
            raise RuntimeError('Installed command verification failed')
        if name in ('xcode-version', 'swift-version'):
            lines = (out / (name + '.log')).read_text(errors='replace').splitlines()
            for line in lines[:10]:
                safe = re.sub(r'/(?:Users|home|workspace|tmp|private|var)/[^\s]+', '[local path redacted]', line)
                emit(phase=name, text=safe[:500])
            emit(phase=name + '-counts', omitted=max(0, len(lines)-10),
                 clipped_lines=sum(len(line) > 500 for line in lines[:10]))
    types = json.loads(capture(['xcrun', 'simctl', 'list', 'devicetypes', '--json']))
    runtimes = json.loads(capture(['xcrun', 'simctl', 'list', 'runtimes', '--json']))
    if not any(d.get('identifier') == DEVICE_TYPE for d in types['devicetypes']):
        raise RuntimeError('Required installed device type missing')
    if not any(r.get('identifier') == RUNTIME and r.get('isAvailable') for r in runtimes['runtimes']):
        raise RuntimeError('Required installed runtime missing; no download')
    (source / TEST_PATH).write_text(candidate)
    changed = capture(['git', 'diff', '--name-only'], cwd=source).splitlines()
    if changed != [TEST_PATH]:
        raise RuntimeError('Only reviewed test-file substitution is permitted')
    first_owned = create_device()
    handed_to_pair = False
    try:
        if device_state(first_owned) != 'Shutdown':
            raise RuntimeError('Fresh owned simulator not Shutdown')
        derived = out / 'DerivedData'
        command = test_command(derived, first_owned, out / 'unused.xcresult')
        command = command[:-3] + ['build-for-testing']
        if run(command, 1200, out / 'build.log', cwd=source):
            failure_excerpt(out / 'build.log')
            emit(phase='pair-result', attempted=0, not_run=2, valid=False, reason='build-failed')
            return 1
        fingerprint = app_fingerprint(derived)
        emit(phase='build-fingerprint', sha256=fingerprint)
        handed_to_pair = True
        return fixed_pair(first_owned, source, out, derived, expected, fingerprint)
    finally:
        if not handed_to_pair:
            cleanup(first_owned, out, 'build')
        unchanged = (capture(['git', 'rev-parse', 'HEAD'], cwd=source).strip() == SOURCE and
                     capture(['git', 'diff', '--name-only'], cwd=source).splitlines() == [TEST_PATH] and
                     (source / TEST_PATH).read_text() == candidate)
        emit(phase='source-preservation', only_reviewed_test_substitution=unchanged)
        if not unchanged:
            raise RuntimeError('Source changed outside reviewed test substitution')


if __name__ == '__main__':
    try:
        if len(sys.argv) != 2:
            raise RuntimeError('Expected isolated pinned source directory')
        raise SystemExit(main(Path(sys.argv[1])))
    except (RuntimeError, subprocess.SubprocessError, ValueError, KeyError, StopIteration, OSError) as error:
        emit(phase='control-infrastructure-error', valid=False, reason=type(error).__name__)
        raise SystemExit(1)
