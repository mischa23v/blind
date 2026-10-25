#!/usr/bin/env python3
"""One boot-ready/cold-application control; never a retry or latency waiver."""
import json
import os
from pathlib import Path
import subprocess
import signal
import re
import time
import uuid

RUNTIME = 'com.apple.CoreSimulator.SimRuntime.iOS-27-0'
DEVICE_TYPE = 'com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro-Max'
PREFIX = 'NATIVE_RUNTIME_READINESS'


def emit(**values):
    print(PREFIX + ' ' + json.dumps(values, sort_keys=True), flush=True)


def run(command, timeout, log):
    started = time.monotonic()
    status = 124
    with log.open('w') as output:
        process = subprocess.Popen(command, stdout=output, stderr=subprocess.STDOUT,
                                   start_new_session=True)
        try:
            status = process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            # Stop this owned command group before simulator cleanup; no orphaned build/test.
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait()
    emit(phase=log.stem, exit=status, elapsed_seconds=time.monotonic() - started)
    return status


def failure_excerpt(log):
    # Build/destination diagnostics only: bounded and explicitly path-redacted.
    emitted = 0
    patterns = re.compile(r'error:|fatal|destination|ineligible|unavailable|timed out|BUILD FAILED', re.I)
    with log.open(errors='replace') as source:
        for line in source:
            if not patterns.search(line):
                continue
            line = re.sub(r'/(?:Users|home|workspace|tmp|private|var)/[^\s,;\]}]+',
                          '[local path redacted]', line.rstrip())
            emit(phase='failure-excerpt', redacted=True, text=line[:1200])
            emitted += 1
            if emitted == 60:
                emit(phase='failure-excerpt', capped=True)
                break


def capture(command):
    return subprocess.check_output(command, text=True, timeout=30)


def main():
    if capture(['uname', '-s']).strip() != 'Darwin':
        raise RuntimeError('Apple runner required')
    if not Path(os.environ['DEVELOPER_DIR']).is_dir():
        raise RuntimeError('Selected Apple toolchain missing')
    out = Path(os.environ['RUNNER_TEMP']) / 'blind-runtime-readiness'
    out.mkdir(parents=True, exist_ok=True)
    emit(source=capture(['git', 'rev-parse', 'HEAD']).strip(), fixed_attempts=1,
         interpretation='boot-ready simulator, cold application; not cold-device proof; cross-host comparison confounded')
    # Installed Apple CLI help is the authoritative command contract on this runner.
    if run(['xcrun', 'simctl', 'help', 'bootstatus'], 30, out / 'bootstatus-help.log'):
        raise RuntimeError('Installed bootstatus help unavailable; no fallback')
    types = json.loads(capture(['xcrun', 'simctl', 'list', 'devicetypes', '--json']))
    runtimes = json.loads(capture(['xcrun', 'simctl', 'list', 'runtimes', '--json']))
    if not any(t.get('identifier') == DEVICE_TYPE for t in types['devicetypes']):
        raise RuntimeError('Required installed device type missing')
    if not any(r.get('identifier') == RUNTIME and r.get('isAvailable') for r in runtimes['runtimes']):
        raise RuntimeError('Required installed runtime missing; no download')
    owned = None
    outcome = 1
    try:
        created = capture(['xcrun', 'simctl', 'create',
                           'Blind runtime readiness control', DEVICE_TYPE, RUNTIME]).strip()
        uuid.UUID(created)  # Validate ownership token, but preserve Apple's exact spelling.
        owned = created
        devices = json.loads(capture(['xcrun', 'simctl', 'list', 'devices', '--json']))
        device = next(d for d in devices['devices'][RUNTIME] if d['udid'].lower() == owned.lower())
        emit(phase='owned-device', device=owned, pre_state=device['state'])
        if device['state'] != 'Shutdown':
            raise RuntimeError('Fresh owned simulator was not Shutdown; no cold-start claim')
        base = ['xcodebuild', '-project', 'ios/BlindAssist.xcodeproj', '-scheme', 'BlindAssist',
                '-configuration', 'Debug', '-jobs', '2', '-derivedDataPath', str(out / 'DerivedData'),
                'CODE_SIGNING_ALLOWED=NO', '-destination', 'platform=iOS Simulator,id=' + owned,
                '-destination-timeout', '120', '-parallel-testing-enabled', 'NO',
                '-maximum-concurrent-test-simulator-destinations', '1',
                '-only-testing:BlindAssistTests/ConnectedJourneyRuntimeTests']
        if run(base + ['build-for-testing'], 1200, out / 'build.log'):
            failure_excerpt(out / 'build.log')
            emit(completed=0, not_run=1, reason='build-failed')
            return 1
        # Readiness measurement is separate, with a fixed infrastructure deadline.
        # No sleep, test warmup, app launch, priority change, or assertion change.
        devices = json.loads(capture(['xcrun', 'simctl', 'list', 'devices', '--json']))
        before_boot = next(d for d in devices['devices'][RUNTIME] if d['udid'].lower() == owned.lower())
        emit(phase='before-boot', state=before_boot['state'])
        if before_boot['state'] != 'Shutdown':
            raise RuntimeError('Build booted simulator; cold-boot measurement invalid')
        boot_status = run(['xcrun', 'simctl', 'bootstatus', owned, '-b'], 180, out / 'boot.log')
        if boot_status:
            failure_excerpt(out / 'boot.log')
            emit(completed=0, not_run=1, reason='boot-infrastructure-failed', boot_exit=boot_status)
            return 1
        result = out / 'runtime.xcresult'
        test_status = run(base + ['-resultBundlePath', str(result), 'test-without-building'],
                          900, out / 'runtime.log')
        # Exactly one test invocation, even on failure or unavailable results.
        extraction = subprocess.run(['python3', 'tools/ci/extract-native-unit-failures.py',
                                     str(out / 'runtime.log')], timeout=30, check=False).returncode
        summary_status = run(['xcrun', 'xcresulttool', 'get', 'test-results', 'summary',
                              '--path', str(result)], 30, out / 'summary.json')
        valid = False
        if summary_status == 0:
            try:
                summary = json.loads((out / 'summary.json').read_text())
                keys = ['result', 'totalTestCount', 'passedTests', 'failedTests', 'skippedTests']
                selected = {key: summary[key] for key in keys}
                emit(phase='test-summary', **selected)
                counts = [selected[key] for key in keys[1:]]
                valid = (all(type(n) is int for n in counts) and counts == [17, 17, 0, 0]
                         and selected['result'] == 'Passed')
            except (ValueError, KeyError, TypeError):
                pass
        outcome = 0 if test_status == 0 and valid and extraction == 0 else 1
        emit(phase='test-finished', completed=1, test_exit=test_status, tests_valid=outcome == 0)
    finally:
        if owned is not None:
            # Never shutdown/delete another simulator, and never use "all".
            shutdown = run(['xcrun', 'simctl', 'shutdown', owned], 30, out / 'cleanup-shutdown.log')
            deletion = run(['xcrun', 'simctl', 'delete', owned], 30, out / 'cleanup-delete.log')
            emit(phase='cleanup', shutdown_exit=shutdown, delete_exit=deletion)
            if deletion:
                outcome = 1
    emit(completed=1, diagnostic_pass=outcome == 0,
         interpretation='No production repair or physical-device cold-launch claim')
    return outcome


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (RuntimeError, subprocess.SubprocessError, ValueError, KeyError, StopIteration, OSError) as error:
        # Metadata only; raw command paths/output remain in local runner logs.
        emit(completed=0, diagnostic_pass=False, reason=type(error).__name__)
        raise SystemExit(1)
