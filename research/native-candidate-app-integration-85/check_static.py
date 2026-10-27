#!/usr/bin/env python3
"""Source-only review checks; no Swift execution or app patch application."""
import ast
import hashlib
import json
from pathlib import Path
import re
import subprocess
import yaml
H = Path(__file__).resolve().parent
R = H.parent.parent
checks = []
def check(label, condition):
    assert condition, label
    checks.append(label)
for p in [Path(__file__), H/'apple/ci.py']:
    ast.parse(p.read_text()); checks.append('Python syntax: '+p.name)
patch = (H/'app-integration.patch').read_text()
bridge = (H/'proposal/MeshCandidateDiagnostics.swift').read_text()
check('entire bridge compile gated', bridge.startswith('#if DEBUG && BLIND_MESH_CANDIDATE_DIAGNOSTICS\n') and bridge.endswith('#endif\n'))
check('runtime default off', 'private(set) var enabled = false' in bridge)
check('owner allocated only at explicit begin', bridge.count('try MeshCandidateIngress83(') == 1 and 'guard enabled, !terminal else { return }' in bridge)
check('no live geometry route or output calls', not any(x in bridge for x in ['.ingest(', '.capture(', '.request(', 'ARMeshAnchor', 'MTLBuffer', 'speak(', 'URLSession', 'UserDefaults']))
check('same owner reset', 'if let owner { try owner.reset() }' in bridge)
check('explicit terminal discard', 'terminal = true; enabled = false' in bridge and 'owner.stopAndDiscard(completion: completion)' in bridge)
check('saturating counters', 'count == .max ? count : count + 1' in bridge)
check('remove exact identity', 'owner?.remove(anchorID: anchorID, receiptUptime: receiptUptime)' in bridge)
check('patch has only approved destinations', set(re.findall(r'^\+\+\+ b/(.+)$', patch, re.M)) == {'ios/BlindAssist/NavigationModel.swift','ios/BlindAssist/MeshCandidateDiagnostics.swift','ios/BlindAssist.xcodeproj/project.pbxproj'})
check('no new session or queue reassignment added', not any(x in line for line in patch.splitlines() if line.startswith('+') for x in ['ARSession()', 'delegateQueue =', 'session.delegate =', 'session.run(', 'session.pause(']))
for method in ['didAdd anchors:', 'didUpdate anchors:', 'didRemove anchors:']:
    check('anchor callback '+method, method in patch)
for hook in ['meshCandidateDiagnostics.beginEpoch()', 'meshCandidateDiagnostics.stop()', 'meshCandidateDiagnostics.scanStarted()', 'discardMeshCandidateDiagnostics', 'setMeshCandidateDiagnosticsEnabled']:
    check('hook '+hook, hook in patch)
# Reconstruct only NavigationModel in memory from checked unified hunks. This does
# not apply the proposal to the checkout or claim actual delegate execution.
baseline = (R/'ios/BlindAssist/NavigationModel.swift').read_text().splitlines(True)
section = patch.split('+++ b/ios/BlindAssist/NavigationModel.swift\n', 1)[1].split('--- ', 1)[0]
result = []; cursor = 0
for match in re.finditer(r'^@@ (-[^\n]+) @@[^\n]*\n(.*?)(?=^@@ |\Z)', section, re.M | re.S):
    header, body = match.groups()
    old_start = int(re.match(r'-(\d+)', header).group(1)) - 1
    result.extend(baseline[cursor:old_start]); cursor = old_start
    for line in body.splitlines(True):
        if line.startswith(' '):
            assert baseline[cursor] == line[1:]; result.append(line[1:]); cursor += 1
        elif line.startswith('-'):
            assert baseline[cursor] == line[1:]; cursor += 1
        elif line.startswith('+'):
            result.append(line[1:])
result.extend(baseline[cursor:])
proposed = ''.join(result)
launch = proposed.split('    private func launch(', 1)[1].split('    func stop()', 1)[0]
check('launch epoch before AR run', launch.index('meshCandidateDiagnostics.beginEpoch()') < launch.index('session.run('))
frame = proposed.split('    func session(_ session: ARSession, didUpdate frame: ARFrame) {', 1)[1]
check('tracking fence before frame throttle', frame.index('meshCandidateDiagnostics.stop()') < frame.index('frame.timestamp - lastProcessed'))
check('main delegate baseline retained', 'session.delegateQueue = .main' in (R/'ios/BlindAssist/NavigationModel.swift').read_text())
check('normal project has no opt-in symbol', 'BLIND_MESH_CANDIDATE_DIAGNOSTICS' not in (R/'ios/BlindAssist.xcodeproj/project.pbxproj').read_text())
for folder,module in [('native-mesh-decoder-81','MeshBufferDecoder81'),('arkit-mesh-adapter-82','MeshSnapshot82'),('mesh-candidate-ingress-83','MeshCandidateIngress83')]:
    manifest=(R/'research'/folder/'Package.swift').read_text()
    check('actual package '+module, f'name: "{module}"' in manifest and 'path: "Sources"' in manifest)
check('native package dependency', '.package(path: "../room-mesh-package-75/BlindRoomMesh")' in (R/'research/mesh-candidate-ingress-83/Package.swift').read_text())
for folder,file in [('arkit-mesh-adapter-82','ARKitMeshAdapter.swift'),('mesh-candidate-ingress-83','ARKitIngress.swift')]:
    check('host condition '+file, (R/'research'/folder/'Sources'/file).read_text().startswith('#if os(iOS) && canImport(ARKit)\n'))
ci = (H/'apple/ci.py').read_text()
check('exact shallow seed before resolve', ci.index("'app-exact-dependency-seed'") < ci.index("'app-exact-dependency-resolve'") and "'refs/tags/v7.11.1^{}']) == grdb_revision" in ci)
check('git rewrite process local', "env['GIT_CONFIG_COUNT']" in ci and "'url.' + seed.as_uri() + '.insteadOf'" in ci and "'--global'" not in ci)
check('exact app dependency resolution', '-onlyUsePackageVersionsFromResolvedFile' in ci and "assert pins == [expected_pin]" in ci and "grdb_revision = 'b83108d10f42680d78f23fe4d4d80fc88dab3212'" in ci)
check('resolve before disabled-resolution builds', ci.index("'app-exact-dependency-resolve'") < ci.index("'-disableAutomaticPackageResolution'"))
check('checkout revision independently verified', "str(checkout), 'rev-parse', 'HEAD']) == grdb_revision" in ci)
workflow=yaml.load((H/'apple/workflow-proposal.yml').read_text(),Loader=yaml.BaseLoader)
check('read-only workflow', workflow['permissions']=={'contents':'read'})
check('review branch', workflow['on']['push']['branches']==['codex/recovery-hazard-order-20261027'])
for job in workflow['jobs'].values():
    check('public repo guard', "github.event.repository.private == false" in job['if'])
    check('bounded job', int(job['timeout-minutes']) <= 40)
    check('pinned actions', all(re.fullmatch(r'actions/[a-z-]+@[a-f0-9]{40}',step['uses']) for step in job['steps'] if 'uses' in step))
for name,digest in json.loads((H/'SOURCE_PINS.json').read_text()).items():
    check('pin '+name,hashlib.sha256((R/name).read_bytes()).hexdigest()==digest)
subprocess.run(['git','apply','--check',str(H/'app-integration.patch')],cwd=R,check=True,timeout=15)
checks.append('patch applies without modifying app')
print(json.dumps(dict(staticChecksPassed=len(checks),checks=checks,swiftExecutedLocally=False,appleBuild='pending',appPatchApplied=False,deviceExecution=False),indent=2))
