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

ROOT = Path(__file__).resolve().parents[2]
CASES = [('original-all', 'BlindAssistUITests/LaunchTests/testAccessibilityAuditOfCameraAndAsk', 4),
         ('camera-dynamic-type', 'BlindAssistUITests/CameraAuditScopeTests/testCameraDynamicTypeOnly', 2)]


def before_camera_geometry(path):
    records = {'readiness': [], 'environment': [], 'practice': [], 'practice-header': [], 'practice-footer': []}
    if path.exists():
        with path.open(errors='replace') as stream:
            for line in stream:
                if 'ACCESSIBILITY_AUDIT_READINESS phase=camera ' in line:
                    records['readiness'].append('titleReady=true controlReady=true' in line)
                if 'ACCESSIBILITY_AUDIT_EVIDENCE phase=camera point=before ' in line:
                    match = re.search(r'category=(\S+) window=(.+)', line)
                    if match: records['environment'].append({'category': match[1][:200], 'window': match[2].strip()[:1000]})
                if 'ACCESSIBILITY_AUDIT_FRAME phase=camera point=before ' in line:
                    match = re.search(r'role=(practice|practice-header|practice-footer) exists=true frame=(.*?) hittable=', line)
                    if match: records[match[1]].append(match[2][:1000])
    valid = all(len(values) == 1 for values in records.values())
    values = {key: items[0] if len(items) == 1 else None for key, items in records.items()}
    valid = valid and values['readiness'] is True and values['environment']['category'] == 'UICTContentSizeCategoryL'
    return {'completeLargeBeforeGeometry': valid, 'values': values}


def compare_before_geometry(logs):
    cases = {name: before_camera_geometry(logs / (name + '.log')) for name, _, _ in CASES}
    if not all(case['completeLargeBeforeGeometry'] for case in cases.values()):
        return {'status': 'inconclusive', 'reason': 'missing_or_nonlarge_before_geometry', 'cases': cases}
    if cases[CASES[0][0]]['values'] != cases[CASES[1][0]]['values']:
        return {'status': 'inconclusive', 'reason': 'before_geometry_mismatch', 'cases': cases}
    return {'status': 'matched', 'reason': 'both ready at Large with identical logged window/button/header/footer frames',
            'interpretation': 'Comparability check only, not proof of an audit-scope effect', 'cases': cases}


def main():
    out = Path(os.environ['RUNNER_TEMP']) / 'blind-camera-audit-scope-control'
    out.mkdir(exist_ok=False)
    artifacts = out / 'artifacts'; artifacts.mkdir()
    logs = out / 'local-logs'; logs.mkdir()
    deadline = time.monotonic() + 2400
    device = None
    failed = False
    summary = {'schema': 1, 'source': os.environ.get('GITHUB_SHA', 'local')[:256],
               'requestedRuntime': 'com.apple.CoreSimulator.SimRuntime.iOS-27-0',
               'requestedDevice': 'iPhone 18 Pro Max', 'runnerBudgetSeconds': 2400,
               'build': 'not_run', 'cleanup': 'not_run',
               'cases': [{'name': name, 'selector': selector, 'maxScreenshots': count,
                          'status': 'not_run', 'evidence': 'not_run'} for name, selector, count in CASES]}

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
        if test: env['TEST_RUNNER_BLIND_AUDIT_SCOPE_CONTROL'] = '1'
        with (logs / (label + '.log')).open('w') as stream:
            process = subprocess.Popen(args, cwd=ROOT, env=env, stdout=stream,
                                       stderr=subprocess.STDOUT, start_new_session=True)
            try:
                return process.wait(timeout=available)
            except BaseException as error:
                if process.poll() is None: os.killpg(process.pid, signal.SIGTERM)
                try: process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL); process.wait(timeout=5)
                if isinstance(error, subprocess.TimeoutExpired): raise TimeoutError('Timed out: ' + label) from error
                raise

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
                    if any(marker in line for marker in ('ACCESSIBILITY_AUDIT', 'Test Case ', 'error:', 'TEST FAILED', 'TEST SUCCEEDED')):
                        matched += 1; truncated += int(len(line.rstrip()) > 12288)
                        lines.append(line.rstrip()[:12288]); lines = lines[-80:]
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
        created = checked(['xcrun', 'simctl', 'create', 'Blind-Audit-Scope-' + os.environ.get('GITHUB_RUN_ID', 'local'),
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
                checked(['xcrun', 'simctl', 'ui', device, 'content_size', 'large'], name + '-set-size', 30)
                observed = checked(['xcrun', 'simctl', 'ui', device, 'content_size'], name + '-get-size', 30).strip()
                case['observedSimulatorCategory'] = observed[:2000]
                if observed != 'large': raise RuntimeError('Simulator failed explicit Large verification')
                code = run(base + ['-only-testing:' + case['selector'], '-resultBundlePath', str(out / (name + '.xcresult')),
                                   'test-without-building'], name, 300, test=True)
                case['nativeExitCode'] = code; case['status'] = 'passed' if code == 0 else 'native_failed'; failed |= code != 0
            except Exception as error:
                case['status'] = 'infrastructure_failed'; case['error'] = str(error)[:1000]; failed = True
            finally:
                case['logSummary'] = bounded_log(name)
                try:
                    export_root = out / ('export-' + name)
                    export_code = run([sys.executable, str(ROOT / 'tools/ci/export-full-audit-evidence.py'),
                                       str(out / (name + '.xcresult')), str(export_root)], name + '-export', 120)
                    case['exportExitCode'] = export_code
                    source = export_root / 'artifacts'
                    paths = list(source.glob('*.png'))
                    if len(paths) > case['maxScreenshots']: raise RuntimeError('Unexpected phase screenshot count')
                    if name == 'camera-dynamic-type' and any('full-audit-ask-' in p.name for p in paths):
                        raise RuntimeError('Unexpected ask evidence in camera-only case')
                    existing = list(artifacts.glob('*/*.png'))
                    if len(paths) + len(existing) > 6 or sum(p.stat().st_size for p in paths + existing) > 16 * 1024 * 1024:
                        raise RuntimeError('Combined screenshot artifact exceeds 6 PNG / 16 MiB')
                    destination = artifacts / name; destination.mkdir()
                    for path in paths: shutil.copyfile(path, destination / path.name)
                    evidence = source / 'evidence.json'
                    if evidence.stat().st_size > 16 * 1024: raise RuntimeError('Phase evidence JSON exceeds 16 KiB')
                    shutil.copyfile(evidence, destination / 'evidence.json')
                    case['screenshots'] = [p.name for p in sorted(paths)]
                    case['evidence'] = 'complete' if export_code == 0 else 'failed'
                    failed |= export_code != 0
                except Exception as error:
                    case['evidence'] = 'failed'; case['evidenceError'] = str(error)[:1000]; failed = True
                save()
    except Exception as error:
        summary['infrastructureError'] = str(error)[:1000]; failed = True
        if summary['build'] == 'not_run': summary['build'] = 'infrastructure_failed'
        for case in summary['cases']:
            if case['status'] == 'not_run': case['status'] = 'infrastructure_not_run'
    finally:
        summary['buildSummary'] = bounded_log('build')
        summary['beforeCameraComparison'] = compare_before_geometry(logs)
        if summary['beforeCameraComparison']['status'] != 'matched': failed = True
        if device:
            try: summary['shutdownExitCode'] = run(['xcrun', 'simctl', 'shutdown', device], 'shutdown', 30, cleanup=True)
            except Exception as error: summary['shutdownError'] = str(error)[:1000]
            try:
                code = run(['xcrun', 'simctl', 'delete', device], 'delete', 45, cleanup=True)
                summary['cleanup'] = 'passed' if code == 0 else 'failed'; failed |= code != 0
            except Exception as error:
                summary['cleanup'] = 'failed'; summary['cleanupError'] = str(error)[:1000]; failed = True
        else: summary['cleanup'] = 'no_owned_simulator'
        summary['screenshotCount'] = len(list(artifacts.glob('*/*.png')))
        summary['result'] = 'failed' if failed else 'passed'; save()
        print('ACCESSIBILITY_AUDIT_SCOPE=' + json.dumps({k: summary[k] for k in ('build', 'cleanup', 'screenshotCount', 'result')}))
    return int(failed)


if __name__ == '__main__': sys.exit(main())
