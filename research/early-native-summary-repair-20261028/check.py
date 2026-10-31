#!/usr/bin/env python3
"""Source/inverse proof only; behavioral regression is the collector test suite."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import textwrap

H = Path(__file__).resolve().parent
R = H.parents[1]
W = '.github/workflows/native-apple.yml'
P = 'research/native-candidate-app-integration-85/integrated/SOURCE_PINS.json'
BEFORE = 'faafd69a05f4d6e65a21e5317d105b74c61d0779d00a0099cab2fa0c740aba81'
PIN_BEFORE = '79e3acf8b144a05ccd9dc163a7219bb1b5abf8909393065061da2cd6310fd6f8'
HELPER = 'd798efeed160cb0a0513991ee7d291bffe88b30844ba112121662e0d79add32a'
checks = []
def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def check(name, value):
    assert value, name
    checks.append(name)

before = (H / 'native-apple.before.yml').read_text()
after = (R / W).read_text()
pins_before = (H / 'SOURCE_PINS.before.json').read_text()
pins_after = (R / P).read_text()
helper_path = H.parent / 'early-native-evidence-20261028/native-apple-sh.before.txt'
helper = helper_path.read_text()
check('published 6fe9d52 workflow baseline exact', digest(H / 'native-apple.before.yml') == BEFORE)
check('published 6fe9d52 manifest baseline exact', digest(H / 'SOURCE_PINS.before.json') == PIN_BEFORE)
check('published 6fe9d52 helper exact unchanged reference', digest(helper_path) == HELPER)
original_command = 'python3 tools/ci/export-native-unit-statuses.py "$out/unit.xcresult" "$out/unit.log" "$out/unit-case-statuses.json" || true'
original_run = '        run: ' + original_command.replace('$out', '$RUNNER_TEMP/blind-native-ci') + '\n'
# Reuse the original helper body, replacing only its loop variable with unit.
body = helper.split('    for suite in unit ui; do\n', 1)[1].split('    done\n', 1)[0]
summary = textwrap.dedent(body).replace('$suite', 'unit')
shell = 'out="$RUNNER_TEMP/blind-native-ci"\n' + summary + original_command + '\n'
replacement = '        run: |\n' + textwrap.indent(shell, '          ')
check('only existing early reporting run changed', before.count(original_run) == 1 and after == before.replace(original_run, replacement))
check('exact helper summary condition arguments fallback reused before collector', summary in shell and shell.index('--summary') < shell.index('"$out/unit.log"'))
check('original collector failure handling retained', original_command in helper and shell.endswith(original_command + '\n'))
check('same single artifact upload and identity', after.count('name: native-unit-case-statuses-') == 1)
check('manifest only changed workflow pin', pins_after == pins_before.replace(BEFORE, digest(R / W)))
check('integrated consumer matches candidate workflow', json.loads(pins_after)['integrated'][W] == digest(R / W))
check('reject original incomplete early command', before != before.replace(original_run, replacement))
subprocess.run(['bash', '-n', '-c', shell], check=True, timeout=10)
check('reporting shell syntax', True)
with tempfile.TemporaryDirectory(prefix='early-summary-inverse-') as temp:
    root = Path(temp)
    for name in (W, P):
        target = root / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(R / name, target)
    subprocess.run(['git', 'apply', str(H / 'summary-dependency.inverse.patch')], cwd=root, check=True, capture_output=True, timeout=10)
    check('inverse exact published workflow', (root / W).read_text() == before)
    check('inverse exact published manifest', (root / P).read_text() == pins_before)
    subprocess.run(['git', 'apply', str(H / 'summary-dependency.patch')], cwd=root, check=True, capture_output=True, timeout=10)
    check('forward exact repaired workflow', (root / W).read_text() == after)
    check('forward exact repaired manifest', (root / P).read_text() == pins_after)
print(json.dumps({'baseCommit':'6fe9d5270f23954fa59fc3509cccf23445cefa51',
    'sourceChecksPassed':len(checks),'checks':checks,
    'workflowSHA256':digest(R / W),'manifestSHA256':digest(R / P),
    'nativeOrSDKTestsRun':False,'githubRuntimeVerified':False,
    'behavioralRegression':'test-export-order.py (separate result; not counted here)'}, indent=2))
