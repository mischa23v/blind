#!/usr/bin/env python3
"""Bounded source/patch checks only; does not parse/compile/execute Swift."""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

H = Path(__file__).resolve().parent
R = H.parents[1]
checks = []
def check(name, value):
    assert value, name
    checks.append(name)
def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
s = (H / 'candidate/MeshCandidateIngress.swift').read_text()
t = (H / 'Tests/ClassificationIngressTests.swift').read_text()
p = (H / 'Package.swift').read_text()
base = json.loads((H / 'SOURCE_PINS.json.before').read_text())
next_pins = json.loads((H / 'candidate/SOURCE_PINS.json').read_text())
source_path = 'research/mesh-candidate-ingress-83/Sources/MeshCandidateIngress.swift'
check('exact baseline pin', digest(H / 'MeshCandidateIngress.swift.before') == base[source_path])
check('exact candidate pin', digest(H / 'candidate/MeshCandidateIngress.swift') == next_pins[source_path])
check('only source pin changes', {k:v for k,v in base.items() if k != source_path} == {k:v for k,v in next_pins.items() if k != source_path})
check('legacy default unchanged', 'supportPolicy: MeshSupportPolicy = .legacySlope' in s)
check('immutable policy', 'private let supportPolicy: MeshSupportPolicy' in s and s.count('self.supportPolicy =') == 1)
check('same existing runtime receives policy', 'runtime = try RoomMeshCandidateRuntime(sessionID: initialEpoch.uuidString, generation: 1,\n                                               supportPolicy: supportPolicy)' in s)
check('opt-in branch only', s.count('if supportPolicy == .classifiedFloorOnly') == 1)
check('face count bound', 'mesh.classifications.count == mesh.triangleIndices.count / 3' in s)
check('only floor2, all other roles obstacles', 'mesh.classifications.map { $0 == 2 ? .floor : .obstacle }' in s)
check('unknown diagnostics and none retain gap', '!mesh.classificationDiagnostics.isEmpty ||\n                           mesh.classifications.contains(where: { $0 == nil || $0 == 0 }) { gap() }' in s)
check('all geometry and transform passed unchanged', 'vertices: mesh.localVertices.map(Double.init), triangles: mesh.triangleIndices.map(Int32.init),' in s and 'columnMajorTransform: mesh.anchorTransform.map(Double.init), complete: true,' in s)
check('roles reach real runtime event', 'triangleSupport: triangleSupport)' in s and '_ = runtime.offer(event)' in s)
check('authority fields unchanged', 'public var physicalAuthority: Bool { false }' in s and 'public var coverageKnown: Bool { false }' in s)
check('no new camera or physical outputs', not any(x in s for x in ['ARSession(', 'speak(', 'UIAccessibility', 'AVSpeech']))
check('nine authored fixtures', t.count('    func test') == 9)
check('SDK test conditional', '#if os(iOS) && canImport(ARKit)\n    func testPortableLabelContract' in t)
check('actual dependencies not mock runtimes', 'import MeshCandidateIngress83' in t and '@testable import MeshSnapshot82' in t and 'import BlindRoomMesh' in t)
check('negative helper excludes stale/unavailable', 'case .failure(.runtime(.nativeFailure)): break' in t and 'default: XCTFail(' in t)
check('all label bytes covered', 'for raw in UInt8.min...UInt8.max' in t)
check('replacement recovery and sticky gap fixture', 'testMissingReplacementRemovesPriorFloorAndValidRevisionRecoversButGapStays' in t and 'recovered.route.unknownCoverage.contains("ingress-or-lifecycle-gap")' in t)
check('obstacle retention fixture', 'labels: [4,4], y: 0.5' in t and 'owner.remove(anchorID: table, receiptUptime: 3)' in t)
check('dependency harness imports existing products', all(x in p for x in ['package: "mesh-candidate-ingress-83"', 'package: "arkit-mesh-adapter-82"', 'package: "BlindRoomMesh"']))
check('original live audit frozen', digest(R / 'research/live-navigation-wiring-20261028/README.md') == '5f50fbd81db06a79d5e7d57cfb5c98ce3df4bca41140d868934f4b4dfcaa0a1a')
check('original bench manifest frozen', digest(R / 'research/live-mesh-bench-proposal-20261028/MANIFEST.json') == '4b29e3f5c70ba743c2bbb21c99aa36ddfbb7b14a917129e93d3a608520cf53a7')
with tempfile.TemporaryDirectory(prefix='classification-patch-') as tmp:
    root = Path(tmp)
    for path, before in [(source_path,'MeshCandidateIngress.swift.before'), ('research/mesh-candidate-ingress-83/SOURCE_PINS.json','SOURCE_PINS.json.before')]:
        dest = root / path
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes((H / before).read_bytes())
    patch = str(H / 'classification-preservation.patch')
    subprocess.run(['git','apply','--check',patch], cwd=root, check=True, capture_output=True)
    subprocess.run(['git','apply',patch], cwd=root, check=True, capture_output=True)
    check('forward patch exact source', (root/source_path).read_bytes() == (H/'candidate/MeshCandidateIngress.swift').read_bytes())
    check('forward patch exact pins', (root/'research/mesh-candidate-ingress-83/SOURCE_PINS.json').read_bytes() == (H/'candidate/SOURCE_PINS.json').read_bytes())
    subprocess.run(['git','apply','-R',patch], cwd=root, check=True, capture_output=True)
    check('reverse patch exact source', (root/source_path).read_bytes() == (H/'MeshCandidateIngress.swift.before').read_bytes())
    check('reverse patch exact pins', (root/'research/mesh-candidate-ingress-83/SOURCE_PINS.json').read_bytes() == (H/'SOURCE_PINS.json.before').read_bytes())
result = dict(kind='source_and_patch_contracts_only', passed=len(checks), checks=checks,
              authoredSwiftHostTests=8, authoredConditionalSDKTests=1,
              swiftCompiled=False, swiftTestsExecuted=False, cameraActivated=False, physicalAuthority=False)
(H / 'STATIC_RESULT.json').write_text(json.dumps(result, indent=2)+'\n')
print(json.dumps(result, indent=2))
