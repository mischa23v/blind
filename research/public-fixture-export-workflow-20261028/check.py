#!/usr/bin/env python3
"""Exact workflow/pin layering only; no native execution or binary export."""
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

H = Path(__file__).resolve().parent
R = H.parents[1]
W = '.github/workflows/native-apple.yml'
P = 'research/native-candidate-app-integration-85/integrated/SOURCE_PINS.json'
WORKFLOW_BEFORE = 'ba74cd55736aa76248b885cf3c2454ba7ce2d082b0f7f040cd87ad8389e37a8e'
PINS_BEFORE = '4790530fe65ee2280ae3946c223e1878a1beda7e1ba8f41ffe23a5c403182a2f'
EXTRACTION = '          python3 tools/ci/export-public-apple-same-export.py "$out/unit.xcresult" "$out/unit-case-statuses.json" "$out/public-apple-same-export" || true\n'
PRIOR = '          python3 tools/ci/export-native-unit-statuses.py "$out/unit.xcresult" "$out/unit.log" "$out/unit-case-statuses.json" || true\n'
FILES = ['APPLE_ROOM_ROUTE_Hallway2_SAME_EXPORT.usdz',
         'APPLE_ROOM_ROUTE_Hallway2_SAME_EXPORT_METADATA.bin',
         'APPLE_ROOM_ROUTE_Bedroom3_SAME_EXPORT.usdz',
         'APPLE_ROOM_ROUTE_Bedroom3_SAME_EXPORT_METADATA.bin',
         'APPLE_ROOM_ROUTE_MESH_METADATA_INVENTORY.json',
         'APPLE_ROOM_ROUTE_SAME_EXPORT_MANIFEST.json', 'receipt.json']
UPLOAD = ('      - name: Preserve bounded public Apple same-export comparison assets\n'
          '        if: always()\n'
          '        uses: actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02 # v4\n'
          '        with:\n'
          '          name: public-apple-same-export-${{ github.run_id }}-${{ github.run_attempt }}\n'
          '          path: |\n' + ''.join(
          '            ${{ runner.temp }}/blind-native-ci/public-apple-same-export/' + name + '\n' for name in FILES) +
          '          if-no-files-found: error\n'
          '          retention-days: 3\n')
checks = []
def sha(data): return hashlib.sha256(data).hexdigest()
def check(name, condition):
    assert condition, name
    checks.append(name)

before = (H / 'native-apple.before.yml').read_text()
after = (R / W).read_text()
pins_before = (H / 'SOURCE_PINS.before.json').read_text()
pins_after = (R / P).read_text()
check('exact parent-layer workflow baseline', sha(before.encode()) == WORKFLOW_BEFORE)
check('exact classification/timing parent-layer pins baseline', sha(pins_before.encode()) == PINS_BEFORE)
expected = before.replace(PRIOR, PRIOR + EXTRACTION, 1).replace(
    '      - name: iOS UI and accessibility audit tests\n', UPLOAD + '      - name: iOS UI and accessibility audit tests\n', 1)
check('only extraction command and one exact upload step added', after == expected)
check('one extractor invocation only', after.count(EXTRACTION) == 1)
check('case exporter immediately before binary collector', PRIOR + EXTRACTION in after)
check('unit summary precedes status artifact dependency', after.index('--summary') < after.index(PRIOR) < after.index(EXTRACTION))
check('all original bytes recovered by removing additions', after.replace(EXTRACTION, '', 1).replace(UPLOAD, '', 1) == before)
check('existing jobs runners triggers permissions and step budgets retained',
      re.findall(r'^.*(?:timeout-minutes:|runs-on:|permissions:|contents:|cancel-in-progress:).*$', after, re.M)
      == re.findall(r'^.*(?:timeout-minutes:|runs-on:|permissions:|contents:|cancel-in-progress:).*$', before, re.M))
check('single additional artifact action', after.count('uses: actions/upload-artifact@') == before.count('uses: actions/upload-artifact@') + 1)
paths = re.findall(r'^            \$\{\{ runner.temp \}\}/blind-native-ci/public-apple-same-export/(.*)$', UPLOAD, re.M)
check('exact seven-file upload allowlist no extra path', paths == FILES and len(paths) == len(set(paths)) == 7)
check('no wildcard or parent path admission', all(not any(x in name for x in ['*', '?', '[', '/', '\\', '..']) for name in paths))
check('binary artifact before UI with current statuses preserved',
      after.index('name: Preserve bounded hosted-unit case statuses') < after.index(UPLOAD)
      < after.index('name: iOS UI and accessibility audit tests'))
check('manifest only workflow entry changes', pins_after == pins_before.replace(WORKFLOW_BEFORE, sha(after.encode())))
check('integrated workflow pin exact', json.loads(pins_after)['integrated'][W] == sha(after.encode()))
for name, mutated in {
    'upload wildcard': after.replace(FILES[0], '*.usdz'),
    'broader output directory': after.replace('path: |\n' + '\n'.join(UPLOAD.split('          path: |\n',1)[1].splitlines()[:7]), 'path: ${{ runner.temp }}/blind-native-ci'),
    'earlier extractor without status dependency': after.replace(PRIOR + EXTRACTION, EXTRACTION + PRIOR),
    'changed unit deadline': after.replace('timeout-minutes: 15', 'timeout-minutes: 16'),
    'changed permissions': after.replace('contents: read', 'contents: write'),
}.items():
    check('reject ' + name, mutated != expected)
run = after.split('      - name: Extract bounded hosted-unit case statuses before UI tests\n', 1)[1].split('      - name: Preserve bounded hosted-unit case statuses\n',1)[0].split('        run: |\n',1)[1]
shell = '\n'.join(line[10:] for line in run.splitlines()) + '\n'
subprocess.run(['bash', '-n', '-c', shell], check=True, timeout=10)
check('full reporting shell syntax valid', True)
with tempfile.TemporaryDirectory(prefix='public-fixture-workflow-layer-') as tmp:
    root = Path(tmp)
    for name in (W, P):
        path = root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(R / name, path)
    subprocess.run(['git','apply',str(H / 'workflow.inverse.patch')], cwd=root, check=True, capture_output=True, timeout=10)
    check('inverse exact parent workflow restored', (root / W).read_text() == before)
    check('inverse exact parent pins restored', (root / P).read_text() == pins_before)
    subprocess.run(['git','apply',str(H / 'workflow.patch')], cwd=root, check=True, capture_output=True, timeout=10)
    check('forward exact child workflow restored', (root / W).read_text() == after)
    check('forward exact child pins restored', (root / P).read_text() == pins_after)
print(json.dumps({'sourceChecksPassed':len(checks),'checks':checks,
    'workflowBeforeSHA256':WORKFLOW_BEFORE,'workflowAfterSHA256':sha(after.encode()),
    'pinsBeforeSHA256':PINS_BEFORE,'pinsAfterSHA256':sha(pins_after.encode()),
    'forwardPatchSHA256':sha((H/'workflow.patch').read_bytes()),
    'inversePatchSHA256':sha((H/'workflow.inverse.patch').read_bytes()),
    'nativeTestsRun':False,'binaryExtractorExecuted':False,'githubUploadPerformed':False}, indent=2))
