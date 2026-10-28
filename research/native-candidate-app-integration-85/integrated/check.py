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
# The authorized CI metadata extraction is a separate reversible helper layer.
# Recover the exact prior helper before assessing unchanged build-mode contracts.
with tempfile.TemporaryDirectory(prefix='stage85-ci-helper-') as temp:
    root = Path(temp)
    for name in manifest['beforeSceneTimingHelper']:
        target = root / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(R / name, target)
    subprocess.run(['git', 'apply', '-R', str(H / 'scene-timing-ci-helper.patch')], cwd=root,
                   check=True, timeout=15, capture_output=True)
    for name, digest in manifest['beforeSceneTimingHelper'].items():
        check('exact pre-scene-timing CI helper recovered ' + name, hashlib.sha256((root / name).read_bytes()).hexdigest() == digest)
# Reverse canonical project serialization, practice presentation, then both mesh layers in a disposable THREE-FILE copy only.
# Preserve the original stage85 patch and verify its published intermediate bytes.
with tempfile.TemporaryDirectory(prefix='stage85-integrated-') as temp:
    root = Path(temp)
    for name in manifest['appFiles']:
        target = root / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(R / name, target)
    subprocess.run(['git', 'apply', '-R', str(H / 'saved-room-geometry-membership.patch')], cwd=root,
                   check=True, timeout=15, capture_output=True)
    for name, digest in manifest['beforeSavedRoomGeometry'].items():
        check('exact pre-saved-room-geometry source recovered ' + name, hashlib.sha256((root / name).read_bytes()).hexdigest() == digest)
    subprocess.run(['git', 'apply', '-R', str(H / 'saved-frame-camera-association.patch')], cwd=root,
                   check=True, timeout=15, capture_output=True)
    for name, digest in manifest['beforeSavedFrameCameraAssociation'].items():
        check('exact pre-saved-frame-association source recovered ' + name, hashlib.sha256((root / name).read_bytes()).hexdigest() == digest)
    subprocess.run(['git', 'apply', '-R', str(H / 'navigation-test-recording.patch')], cwd=root,
                   check=True, timeout=15, capture_output=True)
    for name, digest in manifest['beforeNavigationTestRecording'].items():
        check('exact pre-navigation-test-recording source recovered ' + name, hashlib.sha256((root / name).read_bytes()).hexdigest() == digest)
    subprocess.run(['git', 'apply', '-R', str(H / 'connected-bench-preview-membership.patch')], cwd=root,
                   check=True, timeout=15, capture_output=True)
    for name, digest in manifest['beforeConnectedBenchPreviewMembership'].items():
        check('exact pre-connected-bench-preview project recovered ' + name, hashlib.sha256((root / name).read_bytes()).hexdigest() == digest)
    subprocess.run(['git', 'apply', '-R', str(H / 'project-canonicalization.patch')], cwd=root,
                   check=True, timeout=15, capture_output=True)
    for name, digest in manifest['beforeProjectCanonicalization'].items():
        check('exact pre-canonical project recovered ' + name, hashlib.sha256((root / name).read_bytes()).hexdigest() == digest)
    subprocess.run(['git', 'apply', '-R', str(H / 'practice-publication.patch')], cwd=root,
                   check=True, timeout=15, capture_output=True)
    for name, digest in manifest['beforePracticePublication'].items():
        check('exact pre-practice integration recovered ' + name, hashlib.sha256((root / name).read_bytes()).hexdigest() == digest)
    pre_practice_nav = (root / 'ios/BlindAssist/NavigationModel.swift').read_text()
    subprocess.run(['git', 'apply', '-R', str(H / 'critical-order.patch')], cwd=root,
                   check=True, timeout=15, capture_output=True)
    for name, digest in manifest['beforeCriticalOrder'].items():
        check('exact published stage85 recovered ' + name, hashlib.sha256((root / name).read_bytes()).hexdigest() == digest)
    subprocess.run(['git', 'apply', '-R', str(H.parent / 'app-integration.patch')], cwd=root,
                   check=True, timeout=15, capture_output=True)
    for name, digest in manifest['originalApp'].items():
        check('exact original recovered ' + name, hashlib.sha256((root / name).read_bytes()).hexdigest() == digest)
    check('bridge absent in original', not (root / 'ios/BlindAssist/MeshCandidateDiagnostics.swift').exists())
    original_nav = (root / 'ios/BlindAssist/NavigationModel.swift').read_text()
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
# These blocks contain no nested compiler directives. Removing only this exact
# feature fence from the recovered pre-practice layer must recover the entire
# historical default NavigationModel. The separate exact patch binds later changes.
without_mesh = re.sub(r'(?m)^[ \t]*#if DEBUG && BLIND_MESH_CANDIDATE_DIAGNOSTICS\n(?:(?!^[ \t]*#(?:if|endif)\b)[\s\S])*?^[ \t]*#endif\n', '', pre_practice_nav)
check('flag absent pre-practice navigation exactly preserves original', without_mesh == original_nav)
def body(signature):
    start = nav.index(signature)
    opening = nav.index('{', start + len(signature))
    depth = 0
    for index in range(opening, len(nav)):
        depth += (nav[index] == '{') - (nav[index] == '}')
        if depth == 0:
            return nav[opening + 1:index]
    raise AssertionError('Unclosed declaration: ' + signature)
normalize = lambda value: re.sub(r'\s+', ' ', value).strip()
hook = '#if DEBUG && BLIND_MESH_CANDIDATE_DIAGNOSTICS\nmeshCandidateDiagnostics.stop()\n#endif'
for label, signature, prefix in [
    ('camera stop', 'private func stopCameraMonitoring()', 'nativeObservations.stop()\nvoiceRoomScan.cancel()\nretireBodyWarning(publishChange: false)\nwithObservedScene { $0.stop() }'),
    ('session interruption', 'func sessionWasInterrupted(_ session: ARSession)', 'guard session === self.session else { return }\nplaces.invalidateWorldMapRecovery()\nretireBodyWarning(publishChange: false)\nnativeObservations.stop()\nwithObservedScene { $0.stop() }')]:
    check(label + ' critical retirement precedes optional diagnostics and pause',
          normalize(body(signature)).startswith(normalize(prefix + '\n' + hook + '\ncameraRecovery.pause()')))
failure = normalize(body('func session(_ session: ARSession, didFailWithError error: Error)'))
check('failure retires authority before optional diagnostics and recovery',
      failure.startswith(normalize('guard session === self.session else { return }\nplaces.invalidateWorldMapRecovery()\nretireBodyWarning(publishChange: false)\nnativeObservations.stop()\nwithObservedScene { $0.stop() }')) and
      failure.endswith(normalize('indoor.invalidatePosition()\npublish()\n' + hook + '\nrequestCameraRecovery(now: ProcessInfo.processInfo.systemUptime)')))
frame = body('func session(_ session: ARSession, didUpdate frame: ARFrame)')
check('frame exact ARSession guard precedes all work', normalize(frame).startswith('guard session === self.session else { return }'))
check('pre-throttle tracking association hook precedes existing evidence retirement',
      frame.index('places.observeWorldMapTrackingInterruption(') < frame.index('invalidateNativeLocalization(.trackingUnavailable)'))
retire_end = 'if readingTool != nil && !usesCapturedText { stopReadingTool(announce: false) }'
mesh_stop = 'if case .normal = frame.camera.trackingState {} else { meshCandidateDiagnostics.stop() }'
throttle = 'guard running, !simulation, !places.scanning, frame.timestamp - lastProcessed >= 1.0 / 15 else { return }'
check('tracking retirement precedes optional stop before frame throttle',
      frame.index('invalidateNativeLocalization(.trackingUnavailable)') < frame.index(retire_end) < frame.index(mesh_stop) < frame.index(throttle))
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
print(json.dumps(dict(sourceChecksPassed=len(checks), checks=checks, appPatchApplied=True, criticalOrderPatchApplied=True, practicePublicationPatchApplied=True, projectCanonicalizationPatchApplied=True, connectedBenchPreviewMembershipApplied=True, navigationTestRecordingApplied=True, savedFrameCameraAssociationApplied=True, sceneTimingCIHelperApplied=True, savedRoomGeometryMembershipApplied=True,
    appleBuild='pending', runtimeOptIn=False, geometryCopyEnabled=False,
    physicalAuthority=False, experimental128MiBCapCompliance='not claimed'), indent=2))
