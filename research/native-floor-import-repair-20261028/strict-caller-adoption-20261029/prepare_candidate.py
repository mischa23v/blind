#!/usr/bin/env python3
"""Prepare isolated source copies. Never writes an active implementation/pin."""
from pathlib import Path
import difflib
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
INGRESS = 'research/mesh-candidate-ingress-83/Sources/MeshCandidateIngress.swift'
INGRESS_TEST = 'research/mesh-candidate-ingress-83/tests/main.swift'
BENCH = 'research/live-mesh-classified-bench-20261028/Sources/LiveMeshBenchIngress.swift'
BENCH_TEST = 'research/live-mesh-classified-bench-20261028/Tests/LiveMeshBenchIngressTests.swift'
CHANGED = [INGRESS, INGRESS_TEST, BENCH, BENCH_TEST]
FIXED = {
    INGRESS: '8b3eddcc383d08c71770d538c7ffe2429bd1b6e07e03e3ae99d9c9584c177ea9',
    INGRESS_TEST: 'b4d00b36d9dc58a7160817510f0e29d5f56dfd40358faec810db6b743ffd8123',
    BENCH: 'b84d624dc6f6f56862fd03f1d37ba668d1979b004bd1eb81707c40aa812bd989',
    BENCH_TEST: 'd3459c9658a53f289a6d762c942e66bdae7489d99c874b2ce1537273b026b0ed',
}
UNCHANGED_BENCH = ['research/live-mesh-classified-bench-20261028/' + p for p in
                   ['Package.swift', 'Sources/LiveMeshBenchSession.swift', 'Tests/LiveMeshBenchSessionTests.swift']]

def sha(data):
    return hashlib.sha256(data).hexdigest()

def one(text, old, new):
    assert text.count(old) == 1, old
    return text.replace(old, new, 1)

def render(base):
    result = dict(base)
    source = base[INGRESS]
    old = '                supportPolicy: MeshSupportPolicy = .legacySlope,\n'
    assert source.count(old) == 2
    source = source.replace(old, old + '                endpointPolicy: MeshEndpointPolicy = .legacyNearestProjection,\n')
    source = one(source, '                                               supportPolicy: supportPolicy)',
                 '                                               supportPolicy: supportPolicy, endpointPolicy: endpointPolicy)')
    source = one(source, '            supportPolicy: supportPolicy, captureSyntheticTestTiming: captureSyntheticTestTiming,',
                 '            supportPolicy: supportPolicy, endpointPolicy: endpointPolicy,\n'
                 '            captureSyntheticTestTiming: captureSyntheticTestTiming,')
    source = one(source, '    /// callers retain slope-based diagnostic behavior; policy is fixed across reset.\n',
                 '    /// callers retain slope-based diagnostic behavior; policy is fixed across reset.\n'
                 '    /// Explicit endpoint policy is forwarded unchanged to75 and also survives reset.\n'
                 '    /// The default preserves legacy replay; strict XZ admission is not clearance.\n')
    result[INGRESS] = source
    result[INGRESS_TEST] = base[INGRESS_TEST] + (HERE / 'fixtures83.swift.fragment').read_text()
    result[BENCH] = one(base[BENCH],
        '            supportPolicy: .classifiedFloorOnly, decodeQueue: decodeQueue)',
        '            supportPolicy: .classifiedFloorOnly,\n'
        '            endpointPolicy: .requireSuppliedXZOverPolygon, decodeQueue: decodeQueue)')
    result[BENCH] = one(result[BENCH],
        '        // this does not certify support or convert an omitted revision to free space.\n',
        '        // this does not certify support or convert an omitted revision to free space.\n'
        '        // New bench queries require supplied XZ membership, not silent horizontal\n'
        '        // projection. This still does not prove source/body/support clearance.\n')
    tests = base[BENCH_TEST]
    tests = one(tests, '    func testActualDependencyRouteAndExactlyOneTransformRemainNonphysical() throws {',
                 (HERE / 'bench-helpers.swift.fragment').read_text() +
                 '    func testActualDependencyRouteAndExactlyOneTransformRemainNonphysical() throws {')
    tests = one(tests, '        assertNoCandidate(try query(owner)) // Original position must not survive replacement.',
                 '        assertMissingEndpointPolygons(try query(owner), start: [-2,0,0], goal: [2,0,0]) // Original position must not survive replacement.')
    tests = one(tests, '        assertNoCandidate(try query(fresh))',
                 '        assertMissingEndpointPolygons(try query(fresh), start: [-2,0,0], goal: [2,0,0])')
    tests = one(tests, '        assertNoCandidate(try query(owner, x: 10, z: 4))\n        assertNoCandidate(try query(owner))',
                 '        assertMissingEndpointPolygons(try query(owner, x: 10, z: 4), start: [8,0,4], goal: [12,0,4])\n'
                 '        assertMissingEndpointPolygons(try query(owner), start: [-2,0,0], goal: [2,0,0])')
    assert tests.endswith('}\n')
    result[BENCH_TEST] = tests[:-2] + (HERE / 'bench-tests.swift.fragment').read_text() + '}\n'
    return {p: result[p] for p in CHANGED}

def main():
    base = {}
    rows = []
    for path in CHANGED + UNCHANGED_BENCH:
        data = (ROOT / path).read_bytes()
        if path in FIXED:
            assert sha(data) == FIXED[path], (path, 'changed base; do not rebase silently')
        destination = HERE / 'base' / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        if destination.exists():
            assert destination.read_bytes() == data, 'never overwrite a preserved source base'
        else:
            destination.write_bytes(data)
        base[path] = data.decode()
        rows.append({'path': path, 'bytes': len(data), 'sha256': sha(data)})
    manifest = {'schema': 1, 'scope': 'isolated layer on reviewed CPU candidate; not a remote commit claim',
                'publishedStrictBase': 'ceaaa1c1fc685b043934c4be1ade75653227e1bf',
                'pendingCPULayerIngressSHA256': FIXED[INGRESS], 'files': rows}
    (HERE / 'BASE_MANIFEST.json').write_text(json.dumps(manifest, indent=2) + '\n')
    result = render(base)
    for path, text in result.items():
        destination = HERE / 'candidate' / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(text)
    patch = ''.join(''.join(difflib.unified_diff(base[p].splitlines(True), result[p].splitlines(True),
                                              fromfile='a/' + p, tofile='b/' + p)) for p in CHANGED)
    (HERE / 'STRICT_CALLER_LAYER.patch').write_text(patch)
    print(json.dumps({'candidateFiles': len(result), 'liveFilesChanged': False,
                      'sourceHashes': {p: sha(t.encode()) for p, t in result.items()}}, indent=2))

if __name__ == '__main__':
    main()
