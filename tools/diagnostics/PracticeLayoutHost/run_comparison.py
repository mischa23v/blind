#!/usr/bin/env python3
"""One build, fifteen independent native invocations, no retries or audit filtering.

40 minute runner budget leaves five minutes inside the workflow's 45 minute cap
for bounded owned-simulator cleanup and screenshot/summary upload.
"""
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import time

from export_comparison import export

ROOT = Path(__file__).resolve().parents[3]
PROJECT = ROOT / 'tools/diagnostics/PracticeLayoutHost/PracticeLayoutHost.xcodeproj'
CASES = [(f'test{variant}_{kind}_{repeat}', f'comparison-{variant}-{label}-{repeat}', 'large')
         for variant in 'ABC' for kind, label in [('DynamicType', 'dynamicType'), ('HitRegion', 'hitRegion')]
         for repeat in (1, 2)]
CASES += [(f'test{variant}_Endpoint', f'comparison-{variant}-endpoint', 'accessibility-extra-extra-extra-large')
          for variant in 'ABC']


def main() -> int:
    out = Path(os.environ['RUNNER_TEMP']) / 'blind-practice-comparison'
    # Never upload stale images/outcomes from a previous attempt.
    out.mkdir(exist_ok=False)
    logs = out / 'local-logs'; logs.mkdir()
    artifacts = out / 'artifacts'; artifacts.mkdir()
    screenshots = artifacts / 'screenshots'; screenshots.mkdir()
    deadline = time.monotonic() + 40 * 60
    device = None
    summary = {'schema': 1, 'source': os.environ.get('GITHUB_SHA', 'local')[:256],
               'requestedSimulatorRuntime': 'com.apple.CoreSimulator.SimRuntime.iOS-27-0',
               'requestedSimulatorDevice': 'iPhone 18 Pro Max',
               'runnerBudgetSeconds': 2400, 'build': 'not_run', 'cleanup': 'not_run',
               'cases': [{'test': name, 'prefix': prefix, 'requestedCategory': size, 'status': 'not_run', 'evidence': 'not_run'}
                         for name, prefix, size in CASES]}
    failed = False

    def cancel(signum, _frame):
        nonlocal deadline
        deadline = 0
        raise RuntimeError('Runner interrupted by signal ' + str(signum))

    signal.signal(signal.SIGTERM, cancel)
    signal.signal(signal.SIGINT, cancel)

    def save():
        nonlocal failed
        serialized = json.dumps(summary, indent=2) + '\n'
        if len(serialized.encode('utf-8')) > 4 * 1024 * 1024:
            failed = True
            summary['artifactBudgetError'] = 'Outcome JSON exceeded 4 MiB; log summaries removed explicitly'
            summary['result'] = 'failed'
            for record in [summary] + summary['cases']:
                for key in ('buildSummary', 'logSummary'):
                    if key in record:
                        record[key] = {'lines': [], 'removedForArtifactBudget': True}
            serialized = json.dumps(summary, indent=2) + '\n'
        if len(serialized.encode('utf-8')) > 4 * 1024 * 1024:
            raise RuntimeError('Outcome metadata exceeds 4 MiB even without logs')
        (artifacts / 'outcomes.json').write_text(serialized)

    def command(args, label, timeout=None, cleanup=False):
        remaining = 60 if cleanup else deadline - time.monotonic()
        if remaining <= 0:
            raise TimeoutError('Runner deadline exhausted')
        limit = min(remaining, timeout or remaining)
        path = logs / (label + '.log')
        with path.open('w') as stream:
            process = subprocess.Popen(args, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT,
                                       start_new_session=True)
            try:
                code = process.wait(timeout=limit)
            except BaseException as error:
                if process.poll() is None:
                    os.killpg(process.pid, signal.SIGTERM)
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait(timeout=5)
                if isinstance(error, subprocess.TimeoutExpired):
                    raise TimeoutError('Command timed out: ' + label) from error
                raise
        return code, path

    def checked(args, label, timeout=None):
        code, path = command(args, label, timeout)
        if code != 0:
            raise RuntimeError(f'{label} exited {code}; see local native log')
        return path.read_text(errors='replace')

    def bounded_log(label):
        path = logs / (label + '.log')
        if not path.exists():
            return {'lines': [], 'omittedMatchedLines': 0, 'truncatedLines': 0}
        # Only synthetic test diagnostics/build error summaries; no environment dump,
        # entire result bundle, full logs, videos, application files or credentials.
        lines = []
        matched = 0
        truncated = 0
        with path.open(errors='replace') as stream:
            for line in stream:
                if any(marker in line for marker in ('COMPARISON', 'error:', 'Test Case ', 'TEST SUCCEEDED', 'TEST FAILED')):
                    matched += 1
                    truncated += int(len(line.rstrip()) > 12288)
                    lines.append(line.rstrip()[:12288])
                    lines = lines[-80:]
        result = {'lines': lines, 'omittedMatchedLines': matched - len(lines), 'truncatedLines': truncated}
        # Preserve full bounded audit descriptions preferentially. Include JSON
        # escaping/indentation in the byte budget, not just Python character count.
        while len(json.dumps(result, indent=2).encode('utf-8')) > 192 * 1024:
            index = next((i for i, line in enumerate(lines) if 'COMPARISON issue ' not in line), 0)
            lines.pop(index)
            result['omittedMatchedLines'] += 1
        return result

    save()
    try:
        summary['xcodeVersion'] = checked(['xcodebuild', '-version'], 'xcode-version', 30).strip()[:2000]
        summary['simulatorSDKVersion'] = checked(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-version'],
                                                 'sdk-version', 30).strip()[:2000]
        checked(['xcrun', 'simctl', 'help', 'ui'], 'simctl-ui-help', 30)
        types = json.loads(checked(['xcrun', 'simctl', 'list', 'devicetypes', '--json'], 'device-types', 30))
        matches = [t['identifier'] for t in types['devicetypes'] if t['name'] == 'iPhone 18 Pro Max']
        if len(matches) != 1:
            raise RuntimeError('Required iPhone 18 Pro Max simulator device type is not unique')
        created = checked(['xcrun', 'simctl', 'create',
                          'Blind-Comparison-' + os.environ.get('GITHUB_RUN_ID', 'local'), matches[0],
                          'com.apple.CoreSimulator.SimRuntime.iOS-27-0'], 'create', 60).strip()
        if not re.fullmatch(r'[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}', created):
            raise RuntimeError('Invalid owned simulator identifier')
        device = created
        checked(['xcrun', 'simctl', 'boot', device], 'boot', 60)
        checked(['xcrun', 'simctl', 'bootstatus', device, '-b'], 'bootstatus', 180)
        base = ['xcodebuild', '-project', str(PROJECT), '-scheme', 'PracticeLayoutHost',
                '-configuration', 'Debug', '-jobs', '2', '-derivedDataPath', str(out / 'DerivedData'),
                'CODE_SIGNING_ALLOWED=NO', '-destination', f'platform=iOS Simulator,id={device}',
                '-destination-timeout', '120', '-parallel-testing-enabled', 'NO',
                '-maximum-concurrent-test-simulator-destinations', '1']
        code, _ = command(base + ['build-for-testing'], 'build', 600)
        summary['build'] = 'passed' if code == 0 else 'failed'
        summary['buildExitCode'] = code
        summary['buildSummary'] = bounded_log('build')
        save()
        if code:
            raise RuntimeError('Build-for-testing failed; no test invocation possible')
        for case in summary['cases']:
            name, prefix, size = case['test'], case['prefix'], case['requestedCategory']
            if time.monotonic() >= deadline:
                case['status'] = 'deadline_not_run'; failed = True; save(); continue
            started = time.monotonic()
            try:
                checked(['xcrun', 'simctl', 'ui', device, 'content_size', size], name + '-set-category', 30)
                case['observedSimulatorCategory'] = checked(
                    ['xcrun', 'simctl', 'ui', device, 'content_size'], name + '-get-category', 30).strip()[:2000]
                result = out / (name + '.xcresult')
                code, _ = command(base + ['-test-timeouts-enabled', 'YES',
                    '-default-test-execution-time-allowance', '120', '-maximum-test-execution-time-allowance', '180',
                    '-only-testing:PracticeLayoutHostUITests/ComparisonTests/' + name,
                    '-resultBundlePath', str(result), 'test-without-building'], name, 240)
                case['nativeExitCode'] = code
                case['status'] = 'passed' if code == 0 else 'native_failed'
                failed |= code != 0
            except Exception as error:
                case['status'] = 'infrastructure_failed'
                case['error'] = str(error)[:1000]
                failed = True
            finally:
                case['elapsedSeconds'] = round(time.monotonic() - started, 2)
                case['logSummary'] = bounded_log(name)
                result = out / (name + '.xcresult')
                try:
                    if not result.is_dir():
                        raise RuntimeError('Missing xcresult')
                    exported = out / ('export-' + name)
                    checked(['xcrun', 'xcresulttool', 'export', 'attachments', '--path', str(result),
                             '--output-path', str(exported)], name + '-export', 60)
                    case['screenshots'] = export(exported, screenshots, prefix)
                    case['evidence'] = 'complete'
                except Exception as error:
                    case['evidence'] = 'failed'
                    case['evidenceError'] = str(error)[:1000]
                    failed = True
                save()
    except Exception as error:
        summary['infrastructureError'] = str(error)[:1000]
        summary['buildSummary'] = bounded_log('build')
        if summary['build'] == 'not_run':
            summary['build'] = 'infrastructure_failed'
        for case in summary['cases']:
            if case['status'] == 'not_run':
                case['status'] = 'infrastructure_not_run'
        failed = True
    finally:
        if device:
            try:
                code, _ = command(['xcrun', 'simctl', 'shutdown', device], 'shutdown', 30, cleanup=True)
                summary['shutdownExitCode'] = code
            except Exception as error:
                summary['shutdownError'] = str(error)[:1000]
            try:
                code, _ = command(['xcrun', 'simctl', 'delete', device], 'delete', 45, cleanup=True)
                summary['cleanup'] = 'passed' if code == 0 else 'failed'
                failed |= code != 0
            except Exception as error:
                summary['cleanup'] = 'failed'; summary['cleanupError'] = str(error)[:1000]; failed = True
        else:
            summary['cleanup'] = 'no_owned_simulator'
        summary['screenshotCount'] = len(list(screenshots.glob('*.png')))
        if summary['screenshotCount'] != 30:
            failed = True
        summary['result'] = 'failed' if failed else 'passed'
        save()
        print(json.dumps({k: summary[k] for k in ('build', 'cleanup', 'screenshotCount', 'result')}))
        for case in summary['cases']:
            print('COMPARISON_OUTCOME', case['test'], case['status'], case.get('evidence', 'missing'))
    return int(failed)


if __name__ == '__main__':
    sys.exit(main())
