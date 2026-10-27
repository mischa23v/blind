#!/usr/bin/env python3
"""Portable policy/source/receipt fixtures only; no Apple command or process signals."""
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import tempfile

from evidence import (HERE, TOOLS, PINS, SIZES, LOCK, LOCK_PARSER, RECEIPT, POLICY,
                      pin_records, pinned_module, source_evidence, publish_staged_images,
                      simulator_state, endpoint_receipt, final_summary, write_json,
                      bounded_log, collect_images, image_inventory, record_predecessor_stop)

checks = []
def check(name, condition):
    if not condition:
        raise AssertionError(name)
    checks.append(name)

def rejected(function):
    try:
        function()
    except (OSError, ValueError, KeyError, TypeError):
        return True
    return False

source = Path(sys.argv[1]).resolve() if len(sys.argv) == 2 else TOOLS
for name, record in pin_records(source, PINS['sourceFiles']).items():
    check('unchanged app/test/exporter ' + name, record['matched'])
for name, record in pin_records(TOOLS, PINS['toolFiles']).items():
    check('pinned reused tool ' + name, record['matched'])
for path in HERE.glob('*.py'):
    compile(path.read_text(), str(path), 'exec')
check('Python syntax', True)
subprocess.run(['bash', '-n', str(HERE / 'native.sh')], check=True)
check('shell syntax', True)
helper = (TOOLS / 'tools/ci/native-apple.sh').read_text()
native = (HERE / 'native.sh').read_text()
workflow = (HERE / 'workflow-proposal.yml').read_text()
base = lambda text: shlex.split(re.search(r'base=\((.*?)\)\n', text, re.S)[1])
check('exact established base command', base(helper) == base(native))
old = re.search(r'run_logged "\$mode" (xcodebuild.*? test)\n', helper, re.S)[1]
new = re.search(r'TEST_RUNNER_BLIND_LAYOUT_DIAGNOSTIC=1 (xcodebuild.*? test) >', native, re.S)[1]
tokens = lambda text: shlex.split(text.replace('\\\n', ' '))
check('exact established UI invocation except result name', tokens(old) == tokens(new.replace('$out/$size.xcresult', '$out/$mode.xcresult')))
check('exact two selectors', native.count('selector=BlindAssistUITests/LaunchTests/testPracticeLayoutAt') == 2)
check('serial Large then AX5', 'for size in large accessibility-extra-extra-extra-large; do' in native)
check('explicit category setup readback and fail gate', 'content_size "$size"' in native and 'observed="$(xcrun simctl ui "$device" content_size)"' in native and 'evidence.py" category' in native)
check('first failure records successor not-run then stops', re.search(
    r'if \(\( status != 0 \|\| receipt_status != 0 \)\); then\s+if \[\[ "\$size" = large \]\]; then\s+python3 .*not-run-after-predecessor.*\n\s+fi\s+exit 1\s+fi', native) is not None)
check('export does not depend on selected simulator ID', 'simulator-id' not in native.split('  export)\n', 1)[1]
      and 'simulator-id' not in native.split('case "$mode" in', 1)[0])
check('no bespoke process control or simulator deletion', not any(value in native for value in ('killpg', 'killall', 'pkill', 'simctl delete', 'simctl create', 'ulimit', 'SDKROOT', 'retry-tests')))
check('no lifecycle runner imported', 'runner.py' not in (HERE / 'evidence.py').read_text())
check('no new signal or process-group implementation', not any(value in (HERE / 'evidence.py').read_text() for value in ('killpg', 'start_new_session', 'import signal', 'Popen(')))
check('fresh hosted job guard', 'test "$RUNNER_ENVIRONMENT" = github-hosted' in workflow)
check('public review branch guard', "github.event.repository.private == false" in workflow and "github.ref == 'refs/heads/codex/recovery-hazard-order-20261027'" in workflow)
check('immutable source checkout', 'ref: ' + PINS['source'] in workflow and 'path: pinned-practice-source' in workflow)
check('established job and phase budgets', 'timeout-minutes: 65' in workflow and workflow.count('timeout-minutes: 20') == 2 and workflow.count('timeout-minutes: 3') == 6)
check('unchanged helper reused directly', 'bash "$GITHUB_WORKSPACE/tools/ci/native-apple.sh" preflight' in workflow and 'bash "$GITHUB_WORKSPACE/tools/ci/native-apple.sh" build' in workflow)
check('bounded upload tree only', '/artifacts/**/*.png' in workflow and '/artifacts/*.json' in workflow and 'retention-days: 3' in workflow and '.log\n' not in workflow)
check('policy distinction explicit', POLICY['experimental600SecondBuild300SecondSelectorCompliance'] == 'not_claimed' and POLICY['processGroupCleanup'] == 'not_independently_verified')
active = TOOLS / '.github/workflows/practice-endpoint-native.yml'
if active.exists():
    check('active workflow equals reviewed proposal', active.read_bytes() == (HERE / 'workflow-proposal.yml').read_bytes())

parser = pinned_module(TOOLS, LOCK_PARSER, PINS['toolFiles'][LOCK_PARSER])
receipt_parser = pinned_module(TOOLS, RECEIPT, PINS['toolFiles'][RECEIPT])
with tempfile.TemporaryDirectory(prefix='endpoint-native-fixtures-') as temporary:
    root = Path(temporary)
    # A tiny synthetic Git tree reproduces the prior collapsed-directory defect.
    repo = root / 'source'; repo.mkdir()
    tracked = 'ios/BlindAssist.xcodeproj/project.pbxproj'
    (repo / tracked).parent.mkdir(parents=True)
    (repo / tracked).write_text('synthetic tracked source\n')
    subprocess.run(['git', 'init', '-q', str(repo)], check=True)
    subprocess.run(['git', '-C', str(repo), 'add', tracked], check=True)
    subprocess.run(['git', '-C', str(repo), '-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '-qm', 'synthetic source fixture'], check=True)
    head = subprocess.check_output(['git', '-C', str(repo), 'rev-parse', 'HEAD'], text=True).strip()
    pins = {tracked: hashlib.sha256((repo / tracked).read_bytes()).hexdigest()}
    inspect = lambda initial=False, expected=head: source_evidence(repo, expected, initial, pins, parser)
    check('clean exact source accepted', inspect(True)['sourceIntegrityPassed'])
    check('wrong HEAD rejected', not inspect(expected='0' * 40)['sourceIntegrityPassed'])
    (repo / tracked).write_text('changed\n')
    check('tracked mutation rejected', not inspect()['sourceIntegrityPassed'])
    (repo / tracked).write_text('synthetic tracked source\n')
    lock = repo / LOCK; lock.parent.mkdir(parents=True)
    expected_lock = {'version': 3, 'originHash': 'a' * 64, 'pins': [
        {'identity': 'grdb.swift', 'kind': 'remoteSourceControl', 'location': 'https://github.com/groue/GRDB.swift.git',
         'state': {'revision': parser.REVISION, 'version': '7.11.1'}}]}
    lock.write_text(json.dumps(expected_lock))
    collapsed = subprocess.check_output(['git', '-C', str(repo), 'status', '--porcelain'], text=True).strip()
    check('native directory collapse reproduced', collapsed == '?? ios/BlindAssist.xcodeproj/project.xcworkspace/')
    record = inspect()
    check('expanded exact lock path accepted', record['sourceIntegrityPassed'] and record['sourceStatus'] == ['?? ' + LOCK])
    check('generated metadata not called initially clean', not inspect(True)['sourceIntegrityPassed'])
    (repo / 'unexpected').write_text('synthetic\n')
    record = inspect()
    check('unexpected untracked file rejected', not record['sourceIntegrityPassed'])
    check('lock validity independent of bad source status', record['generatedLock']['independentlyValid'])
    (repo / 'unexpected').unlink()
    for name, value in [('wrong revision', dict(expected_lock, pins=[dict(expected_lock['pins'][0], state={'revision': '0' * 40, 'version': '7.11.1'})])),
                        ('schema two', dict(expected_lock, version=2)),
                        ('different URL', dict(expected_lock, pins=[dict(expected_lock['pins'][0], location='https://github.com/groue/GRDB.swift')]))]:
        lock.write_text(json.dumps(value))
        check(name + ' rejected without relaxing original metadata policy', not inspect()['sourceIntegrityPassed'])
    lock.write_text('{"version":3,"version":3,"pins":[]}')
    check('duplicate lock key rejected', not inspect()['sourceIntegrityPassed'])
    lock.write_text(json.dumps(expected_lock) + ' ' * 16384)
    check('16 KiB metadata cap retained', not inspect()['sourceIntegrityPassed'])
    lock.unlink(); lock.symlink_to(repo / tracked)
    check('symlink lock rejected', not inspect()['sourceIntegrityPassed'])
    lock.unlink()

    uid = '12345678-1234-1234-1234-123456789abc'
    runtime = 'com.apple.CoreSimulator.SimRuntime.iOS-27-0'
    device = {'udid': uid, 'name': 'iPhone 18 Pro Max', 'state': 'Shutdown', 'isAvailable': True}
    listing = lambda entry: {'devices': {runtime: [entry]}}
    check('exact preinstalled shutdown simulator admitted', simulator_state(listing(device), uid) == 'Shutdown')
    check('already booted simulator needs no boot retry', simulator_state(listing(dict(device, state='Booted')), uid) == 'Booted')
    for name, value in [('unavailable', dict(device, isAvailable=False)), ('wrong device', dict(device, name='other')), ('transitional state', dict(device, state='Booting'))]:
        check(name + ' simulator rejected', rejected(lambda: simulator_state(listing(value), uid)))
    check('duplicate selected simulator rejected', rejected(lambda: simulator_state({'devices': {runtime: [device, device]}}, uid)))

    log = root / 'endpoint.log'
    for size in SIZES:
        selector = receipt_parser.SELECTORS[size]; category = receipt_parser.CATEGORIES[size]
        good = [f"Test Case '-[BlindAssistUITests.LaunchTests {selector}]' started.",
                f'PRACTICE_LAYOUT category={category} expected={category}']
        good += [f'PRACTICE_LAYOUT afterReveal role={role}' for role in ('button', 'header', 'footer')]
        good += [f'PRACTICE_LAYOUT footerEnd size={size} endVisible=true', f"Test Case '-[BlindAssistUITests.LaunchTests {selector}]' passed (1.0 seconds)."]
        log.write_text('\n'.join(good) + '\n')
        check('strict receipt pass ' + size, endpoint_receipt(log, size)['status'] == 'passed')
        for name, bad in [('no start', good[1:]), ('skipped', [s.replace(' passed (', ' skipped (') for s in good]),
                          ('failed', [s.replace(' passed (', ' failed (') for s in good]),
                          ('wrong category', [s.replace('expected=' + category, 'expected=wrong') for s in good]),
                          ('footer not visible', [s.replace('endVisible=true', 'endVisible=false') for s in good]),
                          ('duplicate endpoint', good + [good[-2]])]:
            log.write_text('\n'.join(bad) + '\n')
            check(name + ' receipt rejected ' + size, rejected(lambda: endpoint_receipt(log, size)))

    images = root / 'images'; images.mkdir()
    artifacts = images / 'artifacts'; artifacts.mkdir()
    def stage(label, size, each=8):
        directory = images / label; directory.mkdir()
        for role in ('button', 'header', 'footer', 'footer-end'):
            with (directory / (size + '-' + role + '.png')).open('wb') as stream:
                stream.write(b'\x89PNG\r\n\x1a\n'); stream.truncate(each)
        return directory
    oversized = stage('oversized', SIZES[0], 7 * 1024 * 1024)
    check('28 MiB endpoint rejected before publication', rejected(lambda: publish_staged_images(oversized, artifacts, SIZES[0], {})))
    check('failed oversize leaves upload empty', not list(artifacts.iterdir()))
    first = stage('first', SIZES[0], 3 * 1024 * 1024)
    record = {}; publish_staged_images(first, artifacts, SIZES[0], record)
    check('four role files atomically published', record['staging']['published'] and not first.exists())
    second = stage('second', SIZES[1], 4 * 1024 * 1024)
    check('aggregate 28 MiB rejected', rejected(lambda: publish_staged_images(second, artifacts, SIZES[1], {})))
    check('first accepted evidence preserved', len(list(artifacts.glob('*/*.png'))) == 4)
    third = stage('third', SIZES[1]); next(third.iterdir()).write_bytes(b'not-a-png')
    check('bad signature rejected before publication', rejected(lambda: publish_staged_images(third, artifacts, SIZES[1], {})))
    fourth = stage('fourth', SIZES[1]); next(fourth.iterdir()).unlink()
    check('missing exact role rejected', rejected(lambda: publish_staged_images(fourth, artifacts, SIZES[1], {})))
    fifth = stage('fifth', SIZES[1]); (fifth / (SIZES[1] + '-button.png')).unlink(); (fifth / (SIZES[1] + '-button.png')).symlink_to(log)
    check('symlink image rejected', rejected(lambda: publish_staged_images(fifth, artifacts, SIZES[1], {})))
    missing_export = root / 'missing-export'; missing_export.mkdir()
    check('native export failure remains explicit', not collect_images(source, missing_export, SIZES[0], 1))
    check('failed export publishes no image', not list((missing_export / 'artifacts').glob('*/*.png')))
    # Execute the real shell export branch with no simulator ID and no result bundle.
    # No xcrun/xcodebuild command can be reached in this fixture.
    fake_workspace = root / 'export-without-id'; fake_workspace.mkdir()
    (fake_workspace / 'pinned-practice-source').mkdir()
    fake_here = fake_workspace / 'research/practice-endpoint-native-20261027'; fake_here.mkdir(parents=True)
    for name in ('evidence.py', 'PINS.json'):
        shutil.copyfile(HERE / name, fake_here / name)
    fake_temp = root / 'export-without-id-temp'; fake_temp.mkdir()
    completed = subprocess.run(['bash', str(HERE / 'native.sh'), 'export', SIZES[0]],
        env=dict(os.environ, GITHUB_WORKSPACE=str(fake_workspace), RUNNER_TEMP=str(fake_temp), PYTHONDONTWRITEBYTECODE='1'),
        capture_output=True, text=True)
    failure_receipt = fake_temp / 'blind-practice-endpoint-native/artifacts' / ('images-' + SIZES[0] + '.json')
    check('missing simulator ID still yields explicit export failure receipt', completed.returncode == 1
          and failure_receipt.is_file() and json.loads(failure_receipt.read_text())['exportExitCode'] == 1)
    # Exercise the actual serial shell failure branch with explicitly fake commands.
    # These stubs only write fixed synthetic text; they do not invoke any Apple tool.
    fake_receipt = fake_workspace / RECEIPT; fake_receipt.parent.mkdir(parents=True)
    shutil.copyfile(TOOLS / RECEIPT, fake_receipt)
    stub_bin = root / 'synthetic-command-stubs'; stub_bin.mkdir()
    (stub_bin / 'xcrun').write_text('#!/usr/bin/env bash\nset -eu\nif [[ $# = 5 ]]; then printf "%s" "$5" > "$STUB_CATEGORY"; else cat "$STUB_CATEGORY"; fi\n')
    (stub_bin / 'xcodebuild').write_text('#!/usr/bin/env bash\nprintf "%s\\n" "$*" >> "$STUB_CALLS"\nprintf "synthetic command failure\\n"\nexit 65\n')
    for path in stub_bin.iterdir():
        path.chmod(0o755)
    ui_temp = root / 'synthetic-ui-temp'; (ui_temp / 'blind-native-ci').mkdir(parents=True)
    (ui_temp / 'blind-native-ci/simulator-id').write_text(uid)
    stub_calls = root / 'stub-calls'; stub_category = root / 'stub-category'
    stopped_shell = subprocess.run(['bash', str(HERE / 'native.sh'), 'ui'],
        env=dict(os.environ, GITHUB_WORKSPACE=str(fake_workspace), RUNNER_TEMP=str(ui_temp),
                 PYTHONDONTWRITEBYTECODE='1', PATH=str(stub_bin) + os.pathsep + os.environ['PATH'],
                 STUB_CATEGORY=str(stub_category), STUB_CALLS=str(stub_calls)),
        capture_output=True, text=True)
    ui_artifacts = ui_temp / 'blind-practice-endpoint-native/artifacts'
    check('real serial shell records explicit stop after synthetic first failure', stopped_shell.returncode == 1
          and json.loads((ui_artifacts / 'sequence-stop.json').read_text())['state'] == 'not_run_due_to_predecessor')
    check('serial failure branch invokes only Large once', len(stub_calls.read_text().splitlines()) == 1
          and 'testPracticeLayoutAtDefaultSize' in stub_calls.read_text()
          and not (ui_artifacts / ('execution-' + SIZES[1] + '.json')).exists())

    records = root / 'summary'; records.mkdir()
    stages = {key: 'success' for key in ('source', 'preflight', 'build', 'setup', 'ui', 'export_large', 'export_ax5')}
    check('missing evidence never passes', final_summary(records, stages)['result'] != 'passed')
    (records / 'source-before.json').write_text('[]')
    check('malformed evidence object rejected', final_summary(records, stages)['result'] != 'passed')
    for phase in ('before', 'after'):
        write_json(records, 'source-' + phase + '.json', {'sourceIntegrityPassed': True, 'toolingPassed': True})
    for size in SIZES:
        (records / size).mkdir()
        image_rows = []
        for role in ('button', 'header', 'footer', 'footer-end'):
            name = size + '-' + role + '.png'; raw = b'\x89PNG\r\n\x1a\n'
            (records / size / name).write_bytes(raw)
            image_rows.append({'name': name, 'sha256': hashlib.sha256(raw).hexdigest()})
        for prefix, value in [('execution', {'nativeExitCode': 0, 'state': 'completed'}), ('category', {'matched': True}),
                              ('receipt', {'status': 'passed'}), ('images', {'complete': True, 'images': image_rows})]:
            write_json(records, prefix + '-' + size + '.json', value)
    check('all exact evidence supports endpoint-only summary', final_summary(records, stages)['result'] == 'passed')
    partial = root / 'partial-summary'; shutil.copytree(records, partial)
    shutil.rmtree(partial / SIZES[1])
    for prefix in ('execution', 'category', 'receipt', 'images'):
        (partial / (prefix + '-' + SIZES[1] + '.json')).unlink()
    partial_result = final_summary(partial, dict(stages, ui='failure', export_ax5='failure'))
    check('valid Large remains passed when AX5 images and execution missing', partial_result['cases'][0]['passed']
          and partial_result['cases'][0]['imageStatus'] == 'verified')
    check('partial endpoints cannot satisfy global eight-image gate', partial_result['result'] != 'passed'
          and not partial_result['finalImageInventory']['complete'])
    check('missing successor evidence alone stays unknown not not-run', partial_result['cases'][1]['nativeStatus'] == 'unknown_missing_or_invalid'
          and partial_result['cases'][1]['status'] == 'incomplete' and not partial_result['sequenceStopVerified'])
    check('successful predecessor cannot create not-run witness', rejected(lambda: record_predecessor_stop(partial)))
    write_json(partial, 'execution-' + SIZES[0] + '.json', {'nativeExitCode': 65, 'state': 'completed'})
    write_json(partial, 'receipt-' + SIZES[0] + '.json', {'status': 'failed'})
    record_predecessor_stop(partial)
    stopped = final_summary(partial, dict(stages, ui='failure', export_ax5='failure'))
    check('failed predecessor retains independent image verification', stopped['cases'][0]['nativeStatus'] == 'failed'
          and stopped['cases'][0]['receiptStatus'] == 'failed' and stopped['cases'][0]['imageStatus'] == 'verified')
    check('explicit serial failure witness proves successor not-run', stopped['sequenceStopVerified']
          and stopped['cases'][1]['nativeStatus'] == 'not_run_due_to_predecessor'
          and stopped['cases'][1]['status'] == 'not_run_due_to_predecessor' and stopped['result'] != 'passed')
    write_json(partial, 'execution-' + SIZES[1] + '.json', {'nativeExitCode': None, 'state': 'started'})
    interrupted = final_summary(partial, dict(stages, ui='failure'))
    check('started successor contradicts stale not-run witness', not interrupted['sequenceStopVerified']
          and interrupted['cases'][1]['nativeStatus'] == 'started_without_terminal_receipt'
          and interrupted['cases'][1]['status'] == 'incomplete')
    check('cannot record not-run after successor began', rejected(lambda: record_predecessor_stop(partial)))
    (partial / ('execution-' + SIZES[1] + '.json')).unlink()
    write_json(partial, 'execution-' + SIZES[0] + '.json', {'nativeExitCode': 0, 'state': 'completed'})
    record_predecessor_stop(partial)
    stopped = final_summary(partial, dict(stages, ui='failure'))
    check('native-pass receipt-failure also proves deliberate successor not-run', stopped['sequenceStopVerified']
          and stopped['cases'][0]['nativeStatus'] == 'passed' and stopped['cases'][0]['receiptStatus'] == 'failed'
          and stopped['cases'][1]['status'] == 'not_run_due_to_predecessor')
    write_json(partial, 'receipt-' + SIZES[0] + '.json', {'status': 'passed'})
    contradicted = final_summary(partial, stages)
    check('changed predecessor invalidates not-run witness', not contradicted['sequenceStopVerified']
          and contradicted['cases'][1]['status'] == 'incomplete')
    failed_case = root / 'failed-case-summary'; shutil.copytree(records, failed_case)
    write_json(failed_case, 'receipt-' + SIZES[1] + '.json', {'status': 'failed'})
    failed_result = final_summary(failed_case, dict(stages, ui='failure'))
    check('AX5 receipt failure does not overwrite Large result', failed_result['cases'][0]['passed']
          and failed_result['cases'][1]['nativeStatus'] == 'passed' and failed_result['cases'][1]['status'] == 'failed'
          and failed_result['cases'][1]['imageStatus'] == 'verified' and failed_result['result'] != 'passed')
    (failed_case / ('images-' + SIZES[0] + '.json')).unlink()
    incomplete_images = final_summary(failed_case, stages)
    check('PNG presence without publication receipt is incomplete not verified', incomplete_images['cases'][0]['nativeStatus'] == 'passed'
          and incomplete_images['cases'][0]['imageStatus'] == 'incomplete_or_invalid'
          and incomplete_images['cases'][0]['status'] == 'incomplete')
    over_total = root / 'global-image-cap'; over_total.mkdir()
    for size in SIZES:
        (over_total / size).mkdir()
        for role in ('button', 'header', 'footer', 'footer-end'):
            with (over_total / size / (size + '-' + role + '.png')).open('wb') as stream:
                stream.write(b'\x89PNG\r\n\x1a\n'); stream.truncate(3584 * 1024)
    check('global exact-eight image set still fails above 24 MiB', not image_inventory(over_total)['complete'])
    changed_image = records / SIZES[0] / (SIZES[0] + '-footer-end.png')
    changed_image.write_bytes(b'\x89PNG\r\n\x1a\nchanged')
    check('post-publication image mutation rejected', final_summary(records, stages)['result'] != 'passed')
    changed_image.write_bytes(b'\x89PNG\r\n\x1a\n')
    (records / 'extra.png').write_bytes(b'\x89PNG\r\n\x1a\n')
    check('unexpected upload PNG rejected', not image_inventory(records)['complete'])
    (records / 'extra.png').unlink()
    write_json(records, 'execution-' + SIZES[0] + '.json', {'nativeExitCode': False, 'state': 'completed'})
    check('boolean exit status cannot masquerade as zero', final_summary(records, stages)['result'] != 'passed')
    write_json(records, 'execution-' + SIZES[0] + '.json', {'nativeExitCode': 0, 'state': 'completed'})
    check('timed out stage cannot be hidden by receipts', final_summary(records, dict(stages, ui='failure'))['result'] != 'passed')
    write_json(records, 'source-after.json', {'sourceIntegrityPassed': False, 'toolingPassed': True})
    check('source failure cannot be hidden by native passes', final_summary(records, stages)['result'] != 'passed')
    check('individual JSON cap', rejected(lambda: write_json(records, 'too-large.json', {'value': 'x' * (128 * 1024)})))
    log.write_text('ordinary private text must not be selected\n' + ('error: /Users/example token=synthetic https://invalid.example\n' * 70))
    bounded = bounded_log(log, root, root)
    check('bounded diagnostic lines only', len(bounded['lines']) == 60 and bounded['omittedMatchedLines'] == 10 and all('ordinary private' not in s for s in bounded['lines']))
    check('diagnostic secrets and paths sanitized', all('synthetic' not in s and '/Users/example' not in s and 'https://' not in s for s in bounded['lines']))

print(json.dumps({'scope': 'portable source/policy/receipt fixtures only; no Apple commands',
                  'passed': len(checks), 'checks': checks, 'nativeExecution': 'not_run',
                  'resourcePolicy': POLICY}, indent=2))
