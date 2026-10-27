#!/usr/bin/env python3
"""Source contracts only; does not execute Swift, ARKit or Metal."""
import ast
import hashlib
import json
from pathlib import Path
import re
import yaml
HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
checks = []
def check(label, value):
    assert value, label
    checks.append(label)
for p in [Path(__file__), HERE / 'apple/ci.py']:
    ast.parse(p.read_text()); checks.append('Python syntax: ' + p.name)
native = (HERE / 'Sources/ARKitMeshAdapter.swift').read_text()
snapshot = (HERE / 'Sources/MeshSnapshot.swift').read_text()
check('preflight before contents', native.index('MeshSnapshot82.preflight') < native.index('buffer.contents()'))
check('reject inaccessible buffers before contents', native.index('storageMode == .shared') < native.index('buffer.contents()'))
check('no asynchronous raw capture', all(x not in native for x in ['Task {', '.async', 'DispatchQueue', 'Unmanaged']))
check('no history sampling', all(x not in native for x in ['min(faces.count', 'remap', 'sampleMesh', 'maximumVertices']))
check('capture time explicitly unknown', 'captureUptime: Double? { nil }' in snapshot)
check('existing decoder invoked', 'MeshBufferDecoder.decode(' in snapshot)
check('whole revision gaps', 'case unknownGap(Gap)' in snapshot and 'return .unknownGap' in native)
check('no movement authority', 'physicalAuthority: Bool { false }' in snapshot)
config = yaml.load((HERE / 'apple/workflow-proposal.yml').read_text(), Loader=yaml.BaseLoader)
check('read-only workflow', config['permissions'] == {'contents': 'read'})
check('review branch only', config['on']['push']['branches'] == ['codex/recovery-hazard-order-20261027'])
job = config['jobs']['adapter']
check('repository public guarded', "github.event.repository.private == false" in job['if'])
check('bounded job', int(job['timeout-minutes']) == 18)
check('pinned actions', all(re.fullmatch(r'actions/[a-z-]+@[a-f0-9]{40}', s['uses']) for s in job['steps'] if 'uses' in s))
for name, digest in json.loads((HERE / 'SOURCE_PINS.json').read_text()).items():
    check('hash: ' + name, hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == digest)
print(json.dumps(dict(staticChecksPassed=len(checks), checks=checks,
    swiftExecutedLocally=False, appleExecution='pending', deviceExecution=False,
    runtimeActivation=False, copyLatencyMeasured=False), indent=2))
