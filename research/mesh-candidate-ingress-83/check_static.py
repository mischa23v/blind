#!/usr/bin/env python3
"""Source contracts only; never Swift/runtime execution evidence."""
import ast
import hashlib
import json
from pathlib import Path
import re
import yaml
HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent

def main():
    checks = []
    def check(name, value):
        assert value, name
        checks.append(name)
    for path in [Path(__file__), HERE / 'apple/ci.py']:
        ast.parse(path.read_text()); checks.append('Python syntax: ' + path.name)
    for name, digest in json.loads((HERE / 'SOURCE_PINS.json').read_text()).items():
        check('source hash: ' + name, hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == digest)
    config = yaml.load((HERE / 'apple/workflow-proposal.yml').read_text(), Loader=yaml.BaseLoader)
    check('read-only permissions', config['permissions'] == {'contents': 'read'})
    job = next(iter(config['jobs'].values()))
    check('public branch guard', "github.event.repository.private == false" in job['if'] and "codex/recovery-hazard-order-20261027" in job['if'])
    check('bounded Apple runner', job['runs-on'] == 'xcode-27' and int(job['timeout-minutes']) <= 25)
    check('pinned actions', all(re.fullmatch(r'actions/[a-z-]+@[a-f0-9]{40}', step['uses']) for step in job['steps'] if 'uses' in step))
    source = (HERE / 'Sources/MeshCandidateIngress.swift').read_text()
    check('existing runtime only', 'RoomMeshCandidateRuntime' in source and 'runtime.offer(event)' in source)
    check('one explicit gap invalidation site', source.count('runtime.invalidate()') == 1)
    check('copy after ingress admission', source.index('guard let context else') < source.index('let owned = OwnedCopy(capture(context))'))
    check('epoch and exact revision fences', source.count('epoch == context.sessionID') >= 2 and source.count('revisions[anchorID] == context.revision') >= 2)
    check('strict receipt order', 'time > receipt' in source)
    check('exact removal', 'anchorID: anchorID.uuidString' in source and 'removed: true' in source)
    check('single bounded native mailbox reused', 'private let runtime:' in source and 'try runtime.reset(' in source)
    check('no pointer/ARKit in owner', all(word not in source for word in ['UnsafeRawPointer', 'import ARKit', 'MTLBuffer']))
    check('no pretransform', 'vertices: mesh.localVertices.map(Double.init)' in source and 'columnMajorTransform: mesh.anchorTransform.map(Double.init)' in source)
    check('terminal discard release handshake', 'runtime.stopAndDiscard' in source and 'runtimeDiscarded, copies == 0' in source and 'owned.value = nil' in source)
    check('terminal reset prohibited', 'guard !discarding, advance()' in source)
    tests = (HERE / 'tests/main.swift').read_text()
    for marker in ['outer token retired before copy', 'ordinary update does not introduce sticky gap',
        'local transform applied exactly once', 'failed copy retains unknown', 'fresh epoch prevents ABA',
        'remove overflow remains unknown', 'late older completion cannot restore coverage',
        'old copy retains aggregate slot after reset', 'accepted supersession adds no sticky gap',
        'removal supersession adds no ingress gap', 'stop fences candidate']:
        check('fixture authored: ' + marker, marker in tests)
    print(json.dumps(dict(staticChecksPassed=len(checks), checks=checks,
        swiftExecutedLocally=False, appleExecution='pending', appActivation=False,
        ownedDiscardAPIAuthored=True, systemMemoryPurgeClaimed=False, physicalAuthority=False), indent=2))

if __name__ == '__main__':
    main()
