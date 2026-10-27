#!/usr/bin/env python3
"""Pinned source and bounded evidence only; GitHub owns native command lifetimes."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

HERE = Path(__file__).resolve().parent
TOOLS = HERE.parents[1]
PINS = json.loads((HERE / 'PINS.json').read_text())
SIZES = ('large', 'accessibility-extra-extra-extra-large')
LOCK = 'ios/BlindAssist.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved'
LOCK_PARSER = 'research/indoor-io-buffered-diagnostic/resolution.py'
RECEIPT = 'research/practice-endpoint-control-20261027/endpoint_receipt.py'
EXPORTER = 'tools/ci/export-practice-layout-screenshots.py'
POLICY = {'jobMinutes': 65, 'buildStepMinutes': 20, 'combinedUIStepMinutes': 20,
          'exportStepMinutesEach': 3, 'nativeCommandLifetime': 'GitHub step/job timeout policy',
          'experimental600SecondBuild300SecondSelectorCompliance': 'not_claimed',
          'processGroupCleanup': 'not_independently_verified',
          'simulatorLifecycle': 'preinstalled simulator in fresh disposable hosted job; no deletion'}


def checked_bytes(root, name, maximum=2 * 1024 * 1024):
    path = root / name
    cursor = root
    for part in Path(name).parts:
        cursor /= part
        if cursor.is_symlink():
            raise ValueError('Symlink input rejected: ' + name)
    if not path.is_file() or path.stat().st_size > maximum:
        raise ValueError('Missing or oversized input: ' + name)
    raw = path.read_bytes()
    if len(raw) > maximum:
        raise ValueError('Input grew beyond bound: ' + name)
    return raw


def pin_records(root, pins):
    records = {}
    for name, expected in pins.items():
        actual = hashlib.sha256(checked_bytes(root, name)).hexdigest()
        records[name] = {'expected': expected, 'actual': actual, 'matched': actual == expected}
    return records


def pinned_module(root, name, digest):
    raw = checked_bytes(root, name)
    if hashlib.sha256(raw).hexdigest() != digest:
        raise ValueError('Pinned module changed: ' + name)
    # Execute the verified bytes, not a second unverified filesystem read.
    module = type(sys)('endpoint_' + Path(name).stem)
    module.__file__ = str(root / name)
    exec(compile(raw, str(root / name), 'exec'), module.__dict__)
    return module


def git(root, *args):
    # These small metadata queries have the enclosing GitHub 3-minute step limit.
    raw = subprocess.check_output(['git', '-C', str(root), *args], stderr=subprocess.DEVNULL)
    if len(raw) > 1024 * 1024:
        raise ValueError('Git metadata exceeds 1 MiB')
    return raw


def source_evidence(root, expected, initial=False, pins=None, lock_parser=None):
    pins = PINS['sourceFiles'] if pins is None else pins
    result = {'expectedCommit': expected, 'initial': initial, 'sourceIntegrityPassed': False}
    try:
        result['actualCommit'] = git(root, 'rev-parse', 'HEAD').decode().strip()
        result['inputHashes'] = pin_records(root, pins)
        rows = git(root, 'status', '--porcelain=v1', '-z', '--untracked-files=all').decode().split('\0')
        rows = [row for row in rows if row]
        result['sourceStatus'] = rows
        result['trackedSourceClean'] = subprocess.call(
            ['git', '-C', str(root), 'diff', '--quiet', 'HEAD', '--'],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) == 0
        allowed = not rows if initial else all(row == '?? ' + LOCK for row in rows)
        result['untrackedStatusAllowed'] = allowed
        parser = lock_parser or pinned_module(TOOLS, LOCK_PARSER, PINS['toolFiles'][LOCK_PARSER])
        metadata = parser.inspect(root)
        # Preserve the original exact generated-lock scope, separately from Git status.
        lock_valid = metadata['status'] == 'absent' or (not initial and
            metadata['status'] == 'validated_public_exact_pin' and metadata['bytes'] <= 16384
            and metadata['schema_version'] == 3
            and metadata['pins'][0]['location'] == 'https://github.com/groue/GRDB.swift.git')
        result['generatedLock'] = dict(metadata, independentlyValid=lock_valid)
        result['sourceIntegrityPassed'] = (result['actualCommit'] == expected
            and result['trackedSourceClean'] and allowed and lock_valid
            and all(record['matched'] for record in result['inputHashes'].values()))
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        result['errorType'] = type(error).__name__
    return result


def write_json(artifacts, name, value):
    artifacts.mkdir(parents=True, exist_ok=True)
    raw = (json.dumps(value, indent=2) + '\n').encode()
    if len(raw) > 128 * 1024:
        raise ValueError('Individual evidence JSON exceeds 128 KiB')
    others = [p for p in artifacts.glob('*.json') if p.name != name]
    if any(p.is_symlink() or not p.is_file() for p in others):
        raise ValueError('Non-regular existing evidence')
    if sum(p.stat().st_size for p in others) + len(raw) > 1024 * 1024:
        raise ValueError('Combined evidence JSON exceeds 1 MiB')
    # Stage outside the upload tree; no partial JSON is published.
    temporary = artifacts.parent / (name + '.tmp')
    temporary.write_bytes(raw)
    temporary.replace(artifacts / name)


def publish_staged_images(stage, artifacts, name, record):
    """Reuse the reviewed pure preflight/atomic-publication gate, not its runner."""
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
    stage.rename(destination)
    record['staging']['published'] = True
    return [p.name for p in sorted(paths)]


def simulator_state(data, device):
    if not re.fullmatch(r'[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}', device):
        raise ValueError('Invalid selected simulator ID')
    entries = data['devices']['com.apple.CoreSimulator.SimRuntime.iOS-27-0']
    found = [entry for entry in entries if entry.get('udid') == device]
    if (len(found) != 1 or found[0].get('name') != 'iPhone 18 Pro Max'
            or found[0].get('isAvailable') is not True
            or found[0].get('state') not in ('Booted', 'Shutdown')):
        raise ValueError('Selected installed simulator is unavailable or ambiguous')
    return found[0]['state']


def endpoint_receipt(log, size):
    parser = pinned_module(TOOLS, RECEIPT, PINS['toolFiles'][RECEIPT])
    return parser.verify_endpoint(log, size)


def collect_images(root, out, size, export_code):
    record = {'size': size, 'exportExitCode': export_code, 'complete': False}
    try:
        if export_code != 0:
            raise ValueError('Native attachment export did not complete successfully')
        exporter = pinned_module(root, EXPORTER, PINS['sourceFiles'][EXPORTER])
        stage = out / ('selected-private-' + size)
        stage.mkdir(exist_ok=False)
        exporter.export(out / ('export-private-' + size), stage, size)
        names = publish_staged_images(stage, out / 'artifacts', size, record)
        record['images'] = [{'name': name, 'sha256': hashlib.sha256(
            (out / 'artifacts' / size / name).read_bytes()).hexdigest()} for name in names]
        record['complete'] = True
    except (OSError, ValueError, KeyError, TypeError) as error:
        record['errorType'] = type(error).__name__
        if not isinstance(error, OSError):
            record['error'] = str(error)[:256]
    write_json(out / 'artifacts', 'images-' + size + '.json', record)
    return record['complete']


def load_record(artifacts, name):
    try:
        value = json.loads(checked_bytes(artifacts, name, 128 * 1024))
        if not isinstance(value, dict):
            raise ValueError('Evidence record must be an object')
        return value
    except (OSError, ValueError):
        return {'complete': False, 'status': 'missing_or_invalid'}


def bounded_log(path, source, out):
    """Only synthetic test/layout and build diagnostics, never whole raw logs."""
    result = {'available': False, 'lines': [], 'omittedMatchedLines': 0}
    if not path.is_file() or path.is_symlink():
        return result
    result.update(available=True, logBytes=path.stat().st_size)
    if result['logBytes'] > 16 * 1024 * 1024:
        return dict(result, refused='log exceeds 16 MiB; no complete scan claimed')
    count = 0
    with path.open(errors='replace') as stream:
        for line in stream:
            if any(marker in line for marker in ('PRACTICE_LAYOUT', 'Test Case ', 'error:', '** BUILD', '** TEST')):
                count += 1
                for value, replacement in ((str(source), '<source>'), (str(out), '<runner-temp>')):
                    line = line.replace(value, replacement)
                line = re.sub(r'https?://[^\s]+', '<url>', line)
                line = re.sub(r'/Users/[^/\s]+', '<home>', line)
                line = re.sub(r'(?i)\b(token|password|authorization|api[_-]?key)\s*[:=]\s*\S+', r'\1=<redacted>', line)
                line = ''.join(c for c in line.rstrip() if c == '\t' or ord(c) >= 32)
                result['lines'].append(line[:1000])
                result['lines'] = result['lines'][-60:]
    result['omittedMatchedLines'] = count - len(result['lines'])
    return result


def image_inventory(artifacts, size=None):
    sizes = SIZES if size is None else (size,)
    expected = {size + '/' + size + '-' + role + '.png'
                for size in sizes for role in ('button', 'header', 'footer', 'footer-end')}
    paths = list((artifacts if size is None else artifacts / size).rglob('*.png'))
    result = {'count': len(paths), 'complete': False}
    try:
        if {p.relative_to(artifacts).as_posix() for p in paths} != expected:
            raise ValueError('Exact expected image set missing or unexpected')
        total = sum(p.stat().st_size for p in paths)
        if total > 24 * 1024 * 1024:
            raise ValueError('Final image total exceeds 24 MiB')
        result['bytes'] = total
        result['sha256'] = {}
        for path in paths:
            name = path.relative_to(artifacts).as_posix()
            raw = checked_bytes(artifacts, name, 24 * 1024 * 1024)
            if raw[:8] != b'\x89PNG\r\n\x1a\n':
                raise ValueError('Final PNG signature mismatch')
            result['sha256'][name] = hashlib.sha256(raw).hexdigest()
        result['complete'] = True
    except (OSError, ValueError) as error:
        result['errorType'] = type(error).__name__
    return result


def predecessor_failure(artifacts):
    execution = load_record(artifacts, 'execution-' + SIZES[0] + '.json')
    receipt = load_record(artifacts, 'receipt-' + SIZES[0] + '.json')
    code = execution.get('nativeExitCode')
    if execution.get('state') != 'completed' or type(code) is not int:
        return None
    if code != 0:
        reason = 'predecessor_native_failed'
    elif receipt.get('status') == 'failed':
        reason = 'predecessor_receipt_failed'
    else:
        return None
    return {'state': 'not_run_due_to_predecessor', 'size': SIZES[1], 'predecessor': SIZES[0],
            'reason': reason, 'predecessorNativeExitCode': code,
            'predecessorReceiptStatus': receipt.get('status', 'unknown'),
            'witness': 'explicit_serial_ui_failure_branch'}


def next_case_has_execution_evidence(artifacts):
    return any((artifacts / (prefix + '-' + SIZES[1] + '.json')).exists()
               or (artifacts / (prefix + '-' + SIZES[1] + '.json')).is_symlink()
               for prefix in ('category', 'execution', 'receipt'))


def record_predecessor_stop(artifacts):
    """Called only by the shell's first-case failure branch, immediately before exit."""
    witness = predecessor_failure(artifacts)
    if (witness is None or next_case_has_execution_evidence(artifacts)
            or image_inventory(artifacts, SIZES[1])['count'] != 0):
        raise ValueError('Cannot attest an unstarted successor after this predecessor state')
    write_json(artifacts, 'sequence-stop.json', witness)


def final_summary(artifacts, stages):
    before = load_record(artifacts, 'source-before.json')
    after = load_record(artifacts, 'source-after.json')
    inventory = image_inventory(artifacts)
    sequence_stop = load_record(artifacts, 'sequence-stop.json')
    stop_verified = (sequence_stop == predecessor_failure(artifacts)
                     and not next_case_has_execution_evidence(artifacts)
                     and image_inventory(artifacts, SIZES[1])['count'] == 0)
    cases = []
    for size in SIZES:
        execution = load_record(artifacts, 'execution-' + size + '.json')
        category = load_record(artifacts, 'category-' + size + '.json')
        receipt = load_record(artifacts, 'receipt-' + size + '.json')
        images = load_record(artifacts, 'images-' + size + '.json')
        case_inventory = image_inventory(artifacts, size)
        expected_images = {size + '-' + role + '.png' for role in ('button', 'header', 'footer', 'footer-end')}
        image_rows = images.get('images', [])
        hashes_match = (isinstance(image_rows, list) and len(image_rows) == 4
            and all(isinstance(row, dict) and isinstance(row.get('name'), str) for row in image_rows)
            and {row.get('name') for row in image_rows} == expected_images
            and all(row.get('sha256') == case_inventory.get('sha256', {}).get(size + '/' + row['name'])
                    for row in image_rows))
        native_status = 'unknown_missing_or_invalid'
        if execution.get('state') == 'completed' and type(execution.get('nativeExitCode')) is int:
            native_status = 'passed' if execution['nativeExitCode'] == 0 else 'failed'
        elif execution.get('state') == 'started' and execution.get('nativeExitCode') is None:
            native_status = 'started_without_terminal_receipt'
        elif size == SIZES[1] and stop_verified:
            native_status = 'not_run_due_to_predecessor'
        receipt_status = receipt.get('status') if receipt.get('status') in ('passed', 'failed') else 'unknown_missing_or_invalid'
        category_status = 'matched' if category.get('matched') is True else (
            'mismatch' if category.get('matched') is False else 'unknown_missing_or_invalid')
        image_status = 'verified' if images.get('complete') is True and case_inventory['complete'] and hashes_match else 'incomplete_or_invalid'
        passed = native_status == 'passed' and category_status == 'matched' and receipt_status == 'passed' and image_status == 'verified'
        status = ('passed' if passed else 'not_run_due_to_predecessor' if native_status == 'not_run_due_to_predecessor'
                  else 'failed' if native_status == 'failed' or receipt_status == 'failed' or category_status == 'mismatch'
                  else 'incomplete')
        cases.append({'size': size, 'passed': passed, 'status': status, 'nativeStatus': native_status,
                      'receiptStatus': receipt_status, 'categoryStatus': category_status, 'imageStatus': image_status,
                      'execution': execution, 'category': category, 'receipt': receipt, 'images': images,
                      'imageInventory': case_inventory})
    passed = (all(s == 'success' for s in stages.values()) and len(stages) == 7
              and before.get('sourceIntegrityPassed') is True and before.get('toolingPassed') is True
              and after.get('sourceIntegrityPassed') is True and after.get('toolingPassed') is True
              and inventory['complete'] and all(case['passed'] for case in cases))
    return {'scope': 'full-app Large/AX5 endpoint reachability only; not an accessibility audit',
            'source': PINS['source'], 'policy': POLICY, 'stages': stages, 'cases': cases, 'finalImageInventory': inventory,
            'sequenceStop': sequence_stop, 'sequenceStopVerified': stop_verified,
            'sourceBeforePassed': before.get('sourceIntegrityPassed', False),
            'sourceAfterPassed': after.get('sourceIntegrityPassed', False),
            'result': 'passed' if passed else 'failed_or_incomplete'}


def main():
    mode, source = sys.argv[1], Path(sys.argv[2]).resolve()
    workspace = Path(os.environ['GITHUB_WORKSPACE']).resolve()
    if workspace != TOOLS or source != workspace / 'pinned-practice-source':
        raise ValueError('Require separate exact owned source checkout')
    out = Path(os.environ['RUNNER_TEMP']) / 'blind-practice-endpoint-native'
    artifacts = out / 'artifacts'
    if mode == 'before':
        out.mkdir(exist_ok=False)
    if mode in ('before', 'finish'):
        record = source_evidence(source, PINS['source'], initial=mode == 'before')
        try:
            records = pin_records(TOOLS, PINS['toolFiles'])
            record['toolHashes'] = records
            actual = git(TOOLS, 'rev-parse', 'HEAD').decode().strip()
            record['toolingCommit'] = actual
            record['toolingPassed'] = actual == os.environ['GITHUB_SHA'] and all(r['matched'] for r in records.values())
        except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
            record['toolingPassed'] = False
            record['toolingErrorType'] = type(error).__name__
        record['policy'] = POLICY
        record['diagnosticFiles'] = {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
            for p in HERE.iterdir() if p.is_file() and p.suffix in ('.py', '.sh', '.json', '.yml')}
        write_json(artifacts, 'source-' + ('before' if mode == 'before' else 'after') + '.json', record)
        if mode == 'before':
            return int(not (record['sourceIntegrityPassed'] and record['toolingPassed']))
        stages = {name: os.environ.get(name.upper() + '_OUTCOME', 'unknown')
                  for name in ('source', 'preflight', 'build', 'setup', 'ui', 'export_large', 'export_ax5')}
        native_out = Path(os.environ['RUNNER_TEMP']) / 'blind-native-ci'
        for label in ('build', *SIZES):
            write_json(artifacts, 'log-' + label + '.json', bounded_log(native_out / (label + '.log'), source, out))
        summary = final_summary(artifacts, stages)
        write_json(artifacts, 'summary.json', summary)
        print(json.dumps({'result': summary['result'], 'source': PINS['source'], 'policy': POLICY}))
        return int(summary['result'] != 'passed')
    size = sys.argv[3]
    if size not in SIZES:
        raise ValueError('Unexpected endpoint size')
    if mode == 'category':
        observed = sys.argv[4]
        value = {'requested': size, 'observed': observed[:256], 'matched': observed == size}
        write_json(artifacts, 'category-' + size + '.json', value)
        return int(not value['matched'])
    if mode == 'execution':
        code = None if sys.argv[4] == 'started' else int(sys.argv[4])
        write_json(artifacts, 'execution-' + size + '.json',
                   {'state': 'started' if code is None else 'completed', 'nativeExitCode': code})
        return 0
    if mode == 'not-run-after-predecessor':
        if size != SIZES[1]:
            raise ValueError('Only AX5 may be skipped by the preceding Large failure')
        record_predecessor_stop(artifacts)
        return 0
    if mode == 'receipt':
        try:
            value = endpoint_receipt(Path(os.environ['RUNNER_TEMP']) / 'blind-native-ci' / (size + '.log'), size)
        except (OSError, ValueError) as error:
            value = {'status': 'failed', 'errorType': type(error).__name__}
            if not isinstance(error, OSError):
                value['error'] = str(error)[:256]
        write_json(artifacts, 'receipt-' + size + '.json', value)
        return int(value['status'] != 'passed')
    if mode == 'collect':
        return int(not collect_images(source, out, size, int(sys.argv[4])))
    raise ValueError('Unknown evidence mode')


if __name__ == '__main__':
    sys.exit(main())
