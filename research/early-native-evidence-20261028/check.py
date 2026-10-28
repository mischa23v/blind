#!/usr/bin/env python3
"""Bounded source/flow checks only; no Apple tools, uploads, or native tests."""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
WORKFLOW = '.github/workflows/native-apple.yml'
PINS = 'research/native-candidate-app-integration-85/integrated/SOURCE_PINS.json'
BASE_SHA256 = 'fa2fed05f2fcdce59f1cdcb92fb77442a3c7e5c3d0bf53ef78c0fe1c2df40672'
BASE_PINS_SHA256 = '6944b4ea0cc0df54ddf46eb3b27119fc4009b0337561df1a80387d039f307203'
HELPER_SHA256 = 'd798efeed160cb0a0513991ee7d291bffe88b30844ba112121662e0d79add32a'
EARLY_NAME = 'Extract bounded hosted-unit case statuses before UI tests'
UPLOAD_NAME = 'Preserve bounded hosted-unit case statuses'
UI_NAME = 'iOS UI and accessibility audit tests'
UNIT_NAME = 'Hosted iOS unit tests'
INVOCATION = ('python3 tools/ci/export-native-unit-statuses.py '
              '"$RUNNER_TEMP/blind-native-ci/unit.xcresult" '
              '"$RUNNER_TEMP/blind-native-ci/unit.log" '
              '"$RUNNER_TEMP/blind-native-ci/unit-case-statuses.json" || true')
EARLY = ('      - name: ' + EARLY_NAME + '\n'
         '        if: always()\n'
         '        timeout-minutes: 3\n'
         '        run: ' + INVOCATION + '\n')
checks = []


def check(name, condition):
    if not condition:
        raise AssertionError(name)
    checks.append(name)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def split_steps(text):
    header, rest = text.split('    steps:\n', 1)
    native, tail = rest.split('\n  mesh-diagnostics-compile:\n', 1)
    # Do not normalize any bytes: step bodies include conditions/timeouts/paths.
    chunks = re.split(r'(?=^      - )', native, flags=re.MULTILINE)
    return header + '    steps:\n', [s for s in chunks if s], '\n  mesh-diagnostics-compile:\n' + tail


before = (HERE / 'native-apple.before.yml').read_text()
before_pins = (HERE / 'SOURCE_PINS.before.json').read_text()
helper = (HERE / 'native-apple-sh.before.txt').read_text()
after = (ROOT / WORKFLOW).read_text()
after_pins = (ROOT / PINS).read_text()
check('frozen workflow exact baseline SHA256', sha(before.encode()) == BASE_SHA256)
check('frozen manifest exact baseline SHA256', sha(before_pins.encode()) == BASE_PINS_SHA256)
check('frozen unchanged helper exact baseline SHA256', sha(helper.encode()) == HELPER_SHA256)

old_header, old_steps, old_tail = split_steps(before)
new_header, new_steps, new_tail = split_steps(after)
old_upload = next(s for s in old_steps if s.startswith('      - name: ' + UPLOAD_NAME + '\n'))
# The job separator is retained by split_steps outside the final upload chunk.
upload = old_upload.rstrip('\n') + '\n'
expected = before.replace(old_upload, '', 1).replace('      - name: ' + UI_NAME + '\n',
    EARLY + upload + '      - name: ' + UI_NAME + '\n', 1)


def candidate_is_exact(candidate, candidate_pins):
    return (candidate == expected and candidate_pins ==
            before_pins.replace(BASE_SHA256, sha(candidate.encode())))


check('candidate is exact reporting insertion and same upload relocation', candidate_is_exact(after, after_pins))
check('triggers permissions guards runners and job timeout unchanged', new_header == old_header)
check('separate diagnostic job byte-identical', new_tail == old_tail)
check('one new bounded reporting step only', len(new_steps) == len(old_steps) + 1)
original_by_name = {s.splitlines()[0]: s.rstrip('\n') for s in old_steps}
new_by_name = {s.splitlines()[0]: s.rstrip('\n') for s in new_steps}
check('every pre-existing step byte-identical including all test predicates and timeouts',
      all(new_by_name.get(name) == body for name, body in original_by_name.items()))
check('exact early exporter if always and three-minute bound', EARLY in new_steps)
names = [s.splitlines()[0].removeprefix('      - name: ') for s in new_steps]
u = names.index(UNIT_NAME)
check('unit then export then original artifact then UI contiguous order',
      names[u:u + 4] == [UNIT_NAME, EARLY_NAME, UPLOAD_NAME, UI_NAME])
check('artifact upload count unchanged', after.count('uses: actions/upload-artifact@') == before.count('uses: actions/upload-artifact@'))
check('artifact identity and allowlisted path occurs once',
      after.count('name: native-unit-case-statuses-${{ github.run_id }}-${{ github.run_attempt }}') == 1
      and after.count('path: ${{ runner.temp }}/blind-native-ci/unit-case-statuses.json') == 1)
check('no duplicate original upload step', names.count(UPLOAD_NAME) == 1)
check('late summary remains after UI unchanged',
      names.index('Summarize native evidence and preserve source') > names.index(UI_NAME))
original_invocation = INVOCATION.replace('$RUNNER_TEMP/blind-native-ci', '$out')
check('existing three-argument collector and failure handling reused exactly', original_invocation in helper)
check('only workflow pin changed in manifest',
      after_pins.replace(sha(after.encode()), BASE_SHA256) == before_pins)
check('new workflow hash matches integrated consumer pin',
      json.loads(after_pins)['integrated'][WORKFLOW] == sha(after.encode()))

# Reject representative contract regressions rather than merely checking tokens.
mutations = {
    'changed existing test timeout': after.replace('timeout-minutes: 15', 'timeout-minutes: 16'),
    'changed artifact identity': after.replace('name: native-unit-case-statuses-', 'name: replacement-unit-case-statuses-'),
    'broader artifact upload': after.replace('/blind-native-ci/unit-case-statuses.json\n', '/blind-native-ci/*\n'),
    'changed collector argument': after.replace('"$RUNNER_TEMP/blind-native-ci/unit.log"', '"$RUNNER_TEMP/blind-native-ci/ui.log"'),
    'changed job permission': after.replace('contents: read', 'contents: write'),
    'changed UI outcome gate': after.replace("steps.build.outcome == 'success'", "steps.unit.outcome == 'success'"),
    'missing early exporter': after.replace(EARLY, ''),
    'unchanged original late reporting': before,
}
for name, mutation in mutations.items():
    check('reject ' + name, not candidate_is_exact(mutation, after_pins))
check('reject stale workflow pin', not candidate_is_exact(after, before_pins))

with tempfile.TemporaryDirectory(prefix='early-native-source-check-') as temp:
    root = Path(temp)
    for name in (WORKFLOW, PINS):
        path = root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / name, path)
    patch = str(HERE / 'reporting-order.patch')
    for arguments in (['--check', '-R'], ['-R']):
        subprocess.run(['git', 'apply', *arguments, patch], cwd=root,
                       check=True, capture_output=True, timeout=10)
    check('inverse patch restores exact original workflow', (root / WORKFLOW).read_text() == before)
    check('inverse patch restores exact original manifest', (root / PINS).read_text() == before_pins)
    subprocess.run(['git', 'apply', patch], cwd=root,
                   check=True, capture_output=True, timeout=10)
    check('forward patch reproduces exact candidate workflow', (root / WORKFLOW).read_text() == after)
    check('forward patch reproduces exact candidate manifest', (root / PINS).read_text() == after_pins)
    subprocess.run(['git', 'apply', str(HERE / 'reporting-order.inverse.patch')], cwd=root,
                   check=True, capture_output=True, timeout=10)
    check('standalone inverse patch restores original workflow', (root / WORKFLOW).read_text() == before)
    check('standalone inverse patch restores original manifest', (root / PINS).read_text() == before_pins)

    # Execute only the reporting shell line against an owned inert Python stub.
    # No real collector, SDK tool, build, test, upload, or external service runs.
    binary = root / 'bin'
    binary.mkdir()
    stub = binary / 'python3'
    stub.write_text('#!/usr/bin/env bash\nprintf "%s\\n" "$@" > "$ARG_LOG"\nexit "$STUB_EXIT"\n')
    stub.chmod(0o700)
    arg_log = root / 'argv'
    runner_temp = root / 'runner temp with spaces'
    environment = dict(os.environ, PATH=str(binary) + os.pathsep + os.environ['PATH'],
                       ARG_LOG=str(arg_log), RUNNER_TEMP=str(runner_temp))
    expected_argv = ['tools/ci/export-native-unit-statuses.py'] + [
        str(runner_temp / 'blind-native-ci' / filename)
        for filename in ('unit.xcresult', 'unit.log', 'unit-case-statuses.json')]
    subprocess.run(['bash', '-n', '-c', INVOCATION], check=True, timeout=10)
    check('reporting shell syntax valid', True)
    for code in (0, 1, 2, 137):
        result = subprocess.run(['bash', '-e', '-c', INVOCATION], env=dict(environment, STUB_EXIT=str(code)),
                                capture_output=True, timeout=10)
        check('stub collector exit ' + str(code) + ' does not rewrite test verdict or stop reporting shell',
              result.returncode == 0 and arg_log.read_text().splitlines() == expected_argv)

print(json.dumps({
    'baseCommit': 'dc32a9bad9a75566f27924fb9f7aa8fe50a46e95',
    'sourceAndStubFlowChecksPassed': len(checks),
    'checks': checks,
    'workflowBeforeSHA256': BASE_SHA256,
    'workflowAfterSHA256': sha(after.encode()),
    'manifestBeforeSHA256': BASE_PINS_SHA256,
    'manifestAfterSHA256': sha(after_pins.encode()),
    'patchSHA256': sha((HERE / 'reporting-order.patch').read_bytes()),
    'inversePatchSHA256': sha((HERE / 'reporting-order.inverse.patch').read_bytes()),
    'appleSDKOrNativeTestsRun': False,
    'githubActionsRuntimeVerified': False,
    'fullIntegratedCheckRun': False,
    'physicalAuthority': False,
}, indent=2))
