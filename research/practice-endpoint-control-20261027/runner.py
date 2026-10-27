#!/usr/bin/env python3
"""Two real-app audit scopes, one build and simulator, no retries or suppression."""
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import time
import uuid

ROOT = Path(os.environ["BLIND_ENDPOINT_SOURCE_ROOT"]).resolve()
CASES = [('large', 'BlindAssistUITests/LaunchTests/testPracticeLayoutAtDefaultSize', 4),
         ('accessibility-extra-extra-extra-large', 'BlindAssistUITests/LaunchTests/testPracticeLayoutAtLargestAccessibilitySize', 4)]


def sanitize_progress(line, replacements=()):
    for value, replacement in sorted(replacements, key=lambda item: -len(item[0])):
        if value: line = line.replace(value, replacement)
    line = re.sub(r'https?://[^\s]+', '<url>', line)
    line = re.sub(r'/Users/[^/\s]+', '<home>', line)
    line = re.sub(r'(?i)\b(token|password|authorization|api[_-]?key)\s*[:=]\s*\S+', r'\1=<redacted>', line)
    return ''.join(char for char in line if char == '\t' or ord(char) >= 32)


def build_progress_tail(path, replacements=()):
    lines, matched, truncated = [], 0, 0
    pattern = re.compile(r'^\s*(?:SwiftCompile|SwiftEmitModule|SwiftDriver|CompileSwift|CompileC|CompileAssetCatalog|Ld |Link |CodeSign|ProcessInfoPlistFile|Touch |Copy |CpResource|Resolve Package Graph|Resolved source packages|Fetching from|Checking out|Prepare packages|ComputeTargetDependencyGraph|Build description|note:|warning:|error:|\*\* BUILD)')
    if path.exists():
        with path.open(errors='replace') as stream:
            for line in stream:
                if pattern.search(line):
                    value = sanitize_progress(line.rstrip(), replacements)
                    matched += 1; truncated += int(len(value) > 800)
                    lines.append(value[:800]); lines = lines[-60:]
    result = {'lines': lines, 'omittedMatchedLines': matched - len(lines), 'truncatedLines': truncated,
              'logByteCount': path.stat().st_size if path.exists() else 0}
    while len(json.dumps(result, indent=2).encode()) > 64 * 1024:
        lines.pop(0); result['omittedMatchedLines'] += 1
    return result


def owned_group_exists(pgid):
    try:
        os.killpg(pgid, 0)
        return True
    except ProcessLookupError:
        return False


def stop_owned_group(process, record, grace=5):
    """Bound cleanup by the owned session's group, never only its leader.

    start_new_session=True makes pid the owned pgid. Even an exited leader
    can leave live descendants. A group that remains after SIGKILL is unknown
    (for example unreaped zombies), not a claimed cleanup success.
    """
    pgid = process.pid
    def send(sig, key):
        try:
            os.killpg(pgid, sig)
            record[key] = True
        except ProcessLookupError:
            pass
    if owned_group_exists(pgid):
        send(signal.SIGTERM, 'sentSIGTERM')
        until = time.monotonic() + grace
        while owned_group_exists(pgid) and time.monotonic() < until:
            process.poll()  # reap the leader, not a proxy for group liveness
            time.sleep(min(.05, max(0, until - time.monotonic())))
        if owned_group_exists(pgid):
            send(signal.SIGKILL, 'sentSIGKILL')
    try:
        process.wait(timeout=grace)
    except subprocess.TimeoutExpired:
        record['leaderReaped'] = False
    else:
        record['leaderReaped'] = True
    until = time.monotonic() + grace
    while owned_group_exists(pgid) and time.monotonic() < until:
        time.sleep(min(.05, max(0, until - time.monotonic())))
    record['ownedGroupCleanup'] = 'unknown_remaining_group' if owned_group_exists(pgid) else 'absent'
    return record['ownedGroupCleanup'] == 'absent'


def recover_owned_uuid(listing, owned_name):
    devices = listing.get('devices') if isinstance(listing, dict) else None
    if not isinstance(devices, dict) or any(not isinstance(group, list) for group in devices.values()):
        raise ValueError('Invalid simulator recovery schema')
    entries = [entry for group in devices.values() for entry in group]
    if any(not isinstance(entry, dict) for entry in entries):
        raise ValueError('Invalid simulator recovery entry')
    matches = [entry.get('udid') for entry in entries if entry.get('name') == owned_name]
    if not matches:
        return None
    if len(matches) != 1 or not isinstance(matches[0], str) or not re.fullmatch(r'[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}', matches[0]):
        raise ValueError('Owned simulator recovery ambiguous/invalid')
    return matches[0]


def publish_staged_images(stage, artifacts, name, record):
    """Preflight private staging before atomic publication into upload tree."""
    roles = ('button', 'header', 'footer', 'footer-end')
    expected = {name + '-' + role + '.png' for role in roles}
    paths = list(stage.iterdir())
    existing = list(artifacts.glob('*/*.png'))
    if any(p.is_symlink() or not p.is_file() for p in paths + existing):
        raise ValueError('Non-regular screenshot rejected')
    total = sum(p.stat().st_size for p in paths + existing)
    record['staging'] = {'selectedCount': len(paths), 'combinedCount': len(paths) + len(existing),
                         'combinedBytes': total, 'published': False}
    if {p.name for p in paths} != expected or len(paths) != 4 or len(paths) + len(existing) > 8 or total > 24 * 1024 * 1024:
        raise ValueError('Combined endpoint screenshots exceed 8 PNG / 24 MiB or missing role')
    for path in paths:
        with path.open('rb') as stream:
            if stream.read(8) != b'\x89PNG\r\n\x1a\n':
                raise ValueError('Invalid staged PNG signature')
    destination = artifacts / name
    if destination.exists():
        raise ValueError('Refusing stale published endpoint')
    stage.rename(destination)  # same owned runner-temp volume; no partial copy
    record['staging']['published'] = True
    return [p.name for p in sorted(paths)]


def main():
    out = Path(os.environ['RUNNER_TEMP']) / 'blind-practice-endpoint-control'
    out.mkdir(exist_ok=False)
    artifacts = out / 'artifacts'; artifacts.mkdir()
    logs = out / 'local-logs'; logs.mkdir()
    deadline = time.monotonic() + 2400
    device = None
    creation_attempted = False
    owned_name = "Blind-Practice-Endpoint-" + str(uuid.uuid4())
    failed = False
    summary = {'schema': 1, 'source': os.environ.get('GITHUB_SHA', 'local')[:256],
               'requestedRuntime': 'com.apple.CoreSimulator.SimRuntime.iOS-27-0',
               'requestedDevice': 'iPhone 18 Pro Max', 'runnerBudgetSeconds': 2400,
               'build': 'not_run', 'cleanup': 'not_run', 'commands': {},
               'cases': [{'name': name, 'selector': selector, 'maxScreenshots': count,
                          'status': 'not_run', 'evidence': 'not_run'} for name, selector, count in CASES]}

    def safe_error(error):
        if isinstance(error, OSError): return type(error).__name__
        return sanitize_progress(str(error), [(str(ROOT), '<workspace>'), (str(out), '<runner-temp>'), (str(Path.home()), '<home>')])[:1000]

    def save():
        payload = json.dumps(summary, indent=2) + '\n'
        if len(payload.encode()) > 3 * 1024 * 1024:
            raise RuntimeError('Outcome JSON exceeds 3 MiB (reserving room for phase metadata below 4 MiB total)')
        (artifacts / 'outcomes.json').write_text(payload)

    def cancel(signum, _frame):
        nonlocal deadline
        deadline = 0
        raise RuntimeError('Interrupted by signal ' + str(signum))

    signal.signal(signal.SIGTERM, cancel); signal.signal(signal.SIGINT, cancel)

    def run(args, label, limit, cleanup=False, test=False):
        available = limit if cleanup else min(limit, deadline - time.monotonic())
        if available <= 0: raise TimeoutError('Runner deadline exhausted')
        env = dict(os.environ)
        if test: env['TEST_RUNNER_BLIND_LAYOUT_DIAGNOSTIC'] = '1'
        started = time.monotonic()
        record = {'budgetSeconds': round(available, 2), 'timedOut': False, 'sentSIGTERM': False, 'sentSIGKILL': False}
        summary['commands'][label] = record
        with (logs / (label + '.log')).open('w') as stream:
            process = subprocess.Popen(args, cwd=ROOT, env=env, stdout=stream,
                                       stderr=subprocess.STDOUT, start_new_session=True)
            try:
                return process.wait(timeout=available)
            except BaseException as error:
                record['timedOut'] = isinstance(error, subprocess.TimeoutExpired)
                record['interrupted'] = not record['timedOut']
                if isinstance(error, subprocess.TimeoutExpired): raise TimeoutError('Timed out: ' + label) from error
                raise
            finally:
                clean = stop_owned_group(process, record)
                record['elapsedSeconds'] = round(time.monotonic() - started, 3)
                record['exitCode'] = process.returncode
                save()
                if not clean:
                    raise RuntimeError('Owned process group cleanup incomplete: ' + label)

    def checked(args, label, limit):
        code = run(args, label, limit)
        if code: raise RuntimeError(label + ' exited ' + str(code))
        return (logs / (label + '.log')).read_text(errors='replace')

    def bounded_log(label):
        path = logs / (label + '.log')
        lines, matched, truncated = [], 0, 0
        if path.exists():
            with path.open(errors='replace') as stream:
                for line in stream:
                    if any(marker in line for marker in ('PRACTICE_LAYOUT', 'Test Case ', 'error:', 'TEST FAILED', 'TEST SUCCEEDED')):
                        matched += 1; truncated += int(len(line.rstrip()) > 12288)
                        lines.append(sanitize_progress(line.rstrip(), [(str(ROOT), '<workspace>'), (str(out), '<runner-temp>')])[:12288]); lines = lines[-80:]
        result = {'lines': lines, 'omittedMatchedLines': matched - len(lines), 'truncatedLines': truncated}
        while len(json.dumps(result, indent=2).encode()) > 192 * 1024:
            index = next((i for i, line in enumerate(lines) if 'ACCESSIBILITY_AUDIT=' not in line), 0)
            lines.pop(index); result['omittedMatchedLines'] += 1
        return result

    save()
    try:
        summary['xcodeVersion'] = checked(['xcodebuild', '-version'], 'xcode-version', 30).strip()[:2000]
        summary['simulatorSDKVersion'] = checked(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-version'], 'sdk-version', 30).strip()[:2000]
        if summary['simulatorSDKVersion'] != '27.0':
            raise RuntimeError('Scope control requires simulator SDK exactly 27.0')
        types = json.loads(checked(['xcrun', 'simctl', 'list', 'devicetypes', '--json'], 'types', 30))
        matches = [x['identifier'] for x in types['devicetypes'] if x['name'] == 'iPhone 18 Pro Max']
        if len(matches) != 1: raise RuntimeError('Required device type is not unique')
        creation_attempted = True
        summary['ownedSimulatorName'] = owned_name
        created = checked(['xcrun', 'simctl', 'create', owned_name,
                           matches[0], summary['requestedRuntime']], 'create', 60).strip()
        if not re.fullmatch(r'[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}', created):
            raise RuntimeError('Invalid owned simulator UUID')
        device = created
        checked(['xcrun', 'simctl', 'boot', device], 'boot', 60)
        checked(['xcrun', 'simctl', 'bootstatus', device, '-b'], 'bootstatus', 180)
        base = ['xcodebuild', '-project', 'ios/BlindAssist.xcodeproj', '-scheme', 'BlindAssist',
                '-configuration', 'Debug', '-jobs', '2', '-derivedDataPath', str(out / 'DerivedData'),
                'CODE_SIGNING_ALLOWED=NO', '-destination', 'platform=iOS Simulator,id=' + device,
                '-destination-timeout', '120', '-parallel-testing-enabled', 'NO',
                '-maximum-concurrent-test-simulator-destinations', '1']
        code = run(base + ['build-for-testing'], 'build', 600)
        summary['buildExitCode'] = code; summary['build'] = 'passed' if code == 0 else 'failed'; save()
        if code: raise RuntimeError('Build-for-testing failed')
        for case in summary['cases']:
            name = case['name']
            if time.monotonic() >= deadline:
                case['status'] = 'deadline_not_run'; failed = True; save(); continue
            try:
                checked(['xcrun', 'simctl', 'ui', device, 'content_size', name], name + '-set-size', 30)
                observed = checked(['xcrun', 'simctl', 'ui', device, 'content_size'], name + '-get-size', 30).strip()
                case['observedSimulatorCategory'] = observed[:2000]
                if observed != name: raise RuntimeError('Simulator failed explicit requested category verification')
                code = run(base + ['-only-testing:' + case['selector'], '-resultBundlePath', str(out / (name + '.xcresult')),
                                   'test-without-building'], name, 300, test=True)
                case['nativeExitCode'] = code; case['status'] = 'passed' if code == 0 else 'native_failed'; failed |= code != 0
            except Exception as error:
                case['status'] = 'infrastructure_failed'; case['error'] = safe_error(error); failed = True
            finally:
                case['logSummary'] = bounded_log(name)
                try:
                    from endpoint_receipt import verify_endpoint
                    export_root = out / ('export-' + name)
                    export_code = run(['xcrun', 'xcresulttool', 'export', 'attachments', '--path',
                                       str(out / (name + '.xcresult')), '--output-path', str(export_root)], name + '-export', 120)
                    case['exportExitCode'] = export_code
                    if export_code != 0: raise RuntimeError('Attachment export failed')
                    stage = out / ('selected-private-' + name)
                    stage.mkdir()
                    case['staging'] = {'published': False, 'selectedCount': None, 'combinedBytes': None, 'status': 'private_selection_started'}
                    code = run([sys.executable, str(ROOT / 'tools/ci/export-practice-layout-screenshots.py'),
                                str(export_root), str(stage), name], name + '-select-images', 30)
                    case['selectionExitCode'] = code
                    if code != 0: raise RuntimeError('Exact four-role screenshot selection failed; private partial outputs not published')
                    case['screenshots'] = publish_staged_images(stage, artifacts, name, case)
                    case['evidence'] = 'complete'
                    case['endpointReceipt'] = verify_endpoint(logs / (name + '.log'), name)
                except Exception as error:
                    case['evidence'] = 'failed'; case['evidenceError'] = safe_error(error); failed = True
                save()
    except Exception as error:
        summary['infrastructureError'] = safe_error(error); failed = True
        if summary['build'] == 'not_run': summary['build'] = 'infrastructure_failed'
        for case in summary['cases']:
            if case['status'] == 'not_run': case['status'] = 'infrastructure_not_run'
    finally:
        summary['buildSummary'] = bounded_log('build')
        summary['buildProgressTail'] = build_progress_tail(logs / 'build.log',
            [(str(ROOT), '<workspace>'), (str(out), '<runner-temp>'), (str(Path.home()), '<home>')])
        if device is None and creation_attempted:
            # Creation may complete in CoreSimulator after the command fails.
            # Recover only this unpredictable exact owned name, never a sweep.
            summary['cleanup'] = 'creation_uncertain'
            try:
                code = run(['xcrun', 'simctl', 'list', 'devices', '--json'], 'recover-owned-device', 30, cleanup=True)
                path = logs / 'recover-owned-device.log'
                if code or path.stat().st_size > 2 * 1024 * 1024:
                    raise ValueError('Owned simulator recovery listing failed/bounded out')
                listing = json.loads(path.read_text())
                recovered = recover_owned_uuid(listing, owned_name)
                if recovered is not None:
                    device = recovered
                    summary['creationRecovery'] = 'exact_owned_name_found'
                else:
                    summary['creationRecovery'] = 'not_found_at_cleanup_check'
            except Exception as error:
                summary['creationRecoveryError'] = safe_error(error)
            if device is None:
                failed = True  # absence in one listing is not proof delayed creation cannot finish
        if device:
            try: summary['shutdownExitCode'] = run(['xcrun', 'simctl', 'shutdown', device], 'shutdown', 30, cleanup=True)
            except Exception as error: summary['shutdownError'] = safe_error(error)
            try:
                code = run(['xcrun', 'simctl', 'delete', device], 'delete', 45, cleanup=True)
                summary['cleanup'] = 'passed' if code == 0 else 'failed'; failed |= code != 0
            except Exception as error:
                summary['cleanup'] = 'failed'; summary['cleanupError'] = safe_error(error); failed = True
        elif not creation_attempted: summary['cleanup'] = 'creation_not_attempted'
        summary['screenshotCount'] = len(list(artifacts.glob('*/*.png')))
        summary['result'] = 'failed' if failed else 'passed'; save()
        print('PRACTICE_ENDPOINT_CONTROL=' + json.dumps({k: summary[k] for k in ('build', 'cleanup', 'screenshotCount', 'result')}))
    return int(failed)


if __name__ == '__main__': sys.exit(main())
