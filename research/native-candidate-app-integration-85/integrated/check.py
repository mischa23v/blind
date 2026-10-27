#!/usr/bin/env python3
"""Portable source/CI invariants only; no Apple execution or runtime safety claim."""
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

H = Path(__file__).resolve().parent
R = H.parents[2]
checks = []
def check(name, value):
    assert value, name
    checks.append(name)
manifest = json.loads((H / 'SOURCE_PINS.json').read_text())
for name, digest in manifest['integrated'].items():
    check('integrated pin ' + name, hashlib.sha256((R / name).read_bytes()).hexdigest() == digest)
# Reverse in a disposable THREE-FILE copy only; shared source is never mutated.
with tempfile.TemporaryDirectory(prefix='stage85-integrated-') as temp:
    root = Path(temp)
    for name in manifest['appFiles']:
        target = root / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(R / name, target)
    subprocess.run(['git', 'apply', '-R', str(H.parent / 'app-integration.patch')], cwd=root,
                   check=True, timeout=15, capture_output=True)
    for name, digest in manifest['originalApp'].items():
        check('exact original recovered ' + name, hashlib.sha256((root / name).read_bytes()).hexdigest() == digest)
    check('bridge absent in original', not (root / 'ios/BlindAssist/MeshCandidateDiagnostics.swift').exists())
bridge = (R / 'ios/BlindAssist/MeshCandidateDiagnostics.swift').read_text()
nav = (R / 'ios/BlindAssist/NavigationModel.swift').read_text()
project = (R / 'ios/BlindAssist.xcodeproj/project.pbxproj').read_text()
check('bridge exact reviewed proposal', bridge == (H.parent / 'proposal/MeshCandidateDiagnostics.swift').read_text())
check('bridge compile fence', bridge.startswith('#if DEBUG && BLIND_MESH_CANDIDATE_DIAGNOSTICS\n') and bridge.endswith('#endif\n'))
check('default off and not persisted', 'private(set) var enabled = false' in bridge and 'UserDefaults' not in bridge)
check('no copy or geometry ingest', not any(x in bridge for x in ['.ingest(', '.copy(', '.geometry', 'ARMeshAnchor', 'MTLBuffer']))
check('terminal discard', 'terminal = true; enabled = false' in bridge and 'guard !terminal' in bridge)
check('no geometry output or guidance', not any(x in bridge for x in ['route(', 'speak(', 'guidance', 'ARSession()']))
check('existing main callback ownership', 'session.delegateQueue = .main' in nav)
check('flag not in default project settings', 'BLIND_MESH_CANDIDATE_DIAGNOSTICS' not in project)
production = '\n'.join(p.read_text() for p in (R / 'ios/BlindAssist').glob('*.swift'))
check('only declaration of runtime enable control', len(re.findall(r'\bsetMeshCandidateDiagnosticsEnabled\s*\(', production)) == 1)
helper = (R / 'tools/ci/native-apple.sh').read_text()
mode = helper.split('  diagnostics-build)\n', 1)[1].split('    ;;', 1)[0]
check('flag mode build only', "'SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) DEBUG BLIND_MESH_CANDIDATE_DIAGNOSTICS' build" in mode and 'run_logged diagnostics-build xcodebuild "${base[@]}"' in mode)
check('default build unchanged', 'run_logged build xcodebuild "${base[@]}" -destination \'generic/platform=iOS Simulator\' build' in helper)
check('no custom limits added', 'ulimit' not in mode and 'SDKROOT' not in mode)
workflow = (R / '.github/workflows/native-apple.yml').read_text()
job = workflow.split('  mesh-diagnostics-compile:\n', 1)[1]
check('compile isolated job', 'runs-on: xcode-27' in job and 'timeout-minutes: 25' in job)
check('no diagnostic runtime steps', 'native-apple.sh diagnostics-build' in job and not re.search(r'native-apple.sh (unit|ui)\b', job))
retired = (R / '.github/workflows/native-candidate-app-integration.yml').read_text()
check('custom experiment retired', '  push:' not in retired and 'if: ${{ false }}' in retired)
print(json.dumps(dict(sourceChecksPassed=len(checks), checks=checks, appPatchApplied=True,
    appleBuild='pending', runtimeOptIn=False, geometryCopyEnabled=False,
    physicalAuthority=False, experimental128MiBCapCompliance='not claimed'), indent=2))
