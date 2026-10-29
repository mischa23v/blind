#!/usr/bin/env python3
"""Explicit CURRENT companion; historical check_source/15-case evidence stays intact.
Source-text contracts only. This is not Swift parsing, compilation or execution.
"""
from pathlib import Path
import argparse
import ast
import difflib
import hashlib
import importlib.util
import json
import re
from prepare_candidate import HERE, ROOT, CHANGED, INGRESS, INGRESS_TEST, BENCH, BENCH_TEST, render

NEW_TESTS = [
    'testStrictSelectionPreservesInsideAndVerticalEndpointReceipts',
    'testStrictSelectionRejectsGoalAndStartProjectionWithTypedReceipts',
    'testDebugIngressStrictPolicySurvivesResetWithoutChangingLegacyDefault',
]

def load_base():
    manifest = json.loads((HERE / 'BASE_MANIFEST.json').read_text())
    result = {}
    for row in manifest['files']:
        data = (HERE / 'base' / row['path']).read_bytes()
        assert len(data) == row['bytes'] and hashlib.sha256(data).hexdigest() == row['sha256'], row['path']
        result[row['path']] = data.decode()
    return result

def load_candidate(root=None):
    selected = root or HERE / 'candidate'
    return {p: (selected / p).read_text() for p in CHANGED}

def validate(sources):
    base = load_base()
    checks = []
    def check(name, condition):
        assert condition, name
        checks.append(name)
    expected = render(base)
    for path in CHANGED:
        check('exact reviewed CURRENT delta: ' + path, sources[path] == expected[path])
        check('bounded source: ' + path, len(sources[path].encode()) <= 64000)
    ingress, tests83, bench, tests = [sources[p] for p in CHANGED]
    check('both83 API defaults remain legacy', ingress.count('endpointPolicy: MeshEndpointPolicy = .legacyNearestProjection,') == 2)
    check('both83 overloads forward selected policy', ingress.count('endpointPolicy: endpointPolicy') == 2)
    check('CPU diagnostic arguments survive unchanged',
          'syntheticTimingCompletion: ((UUID,[RoomMeshCandidateRuntime.DiagnosticStageReceipt])->Void)? = nil' in ingress and
          'captureSyntheticTestTiming: captureSyntheticTestTiming,\n            syntheticTimingCompletion: syntheticTimingCompletion)' in ingress)
    marker = '    private func locked<T>'
    check('83 lifecycle/query/decode bodies byte-unchanged', ingress[ingress.index(marker):] == base[INGRESS][base[INGRESS].index(marker):])
    check('original83 checks/result remain exact prefix', tests83.startswith(base[INGRESS_TEST]))
    appended = tests83[len(base[INGRESS_TEST]):]
    check('25 separate native caller checks authored', len(re.findall(r'^endpointCheck\(', appended, re.M)) == 25)
    check('original and current output markers remain distinct',
          tests83.count('print("RESULT: \\(checks) stage83') == 1 and appended.count('STRICT_ENDPOINT_INGRESS_RESULT:') == 1)
    check('strict normal initializer and reset refusal covered',
          'try endpointStrict.reset()' in appended and 'reset cannot silently restore legacy projection' in appended)
    check('typed native failure required in appended regression',
          'guard case .failure(.runtime(.endpointAssociationRejected(let receipt))) = result' in appended)
    check('bench explicitly selects strict at one existing owner construction',
          bench.count('endpointPolicy: .requireSuppliedXZOverPolygon') == 1 and bench.count('MeshCandidateIngress83(') == 1)
    check('bench remains classified and nonphysical',
          'supportPolicy: .classifiedFloorOnly,' in bench and 'public let authorizesPhysicalGuidance = false' in bench)
    original_names = re.findall(r'func (test\w+)\(', base[BENCH_TEST])
    names = re.findall(r'func (test\w+)\(', tests)
    check('exact15 originals plus3 named new cases', len(original_names) == 15 and names == original_names + NEW_TESTS)
    check('old nativeFailure assertion is not relaxed',
          'case .failure(.runtime(.nativeFailure)): break' in tests and 'case .failure: break' not in tests)
    check('four missing-position assertions are narrowly migrated', tests.count('assertMissingEndpointPolygons(try query(') == 4)
    check('missing polygons preserve both requests and deterministic absence',
          all(s in tests for s in ['XCTAssertEqual(receipt.start.requested, start',
              'XCTAssertEqual(receipt.goal.requested, goal', 'XCTAssertFalse(receipt.start.found',
              'XCTAssertFalse(receipt.goal.found', 'XCTAssertEqual(receipt.start.projected, [0,0,0]',
              'XCTAssertEqual(receipt.goal.projected, [0,0,0]']))
    check('new bench tests forbid all-rejected success',
          'let after = try queryEndpoints(owner, start: [-1,0,0], goal: [1,0,0]).get()' in tests)
    check('DEBUG83 forwarding and reset regression authored',
          'endpointPolicy: .requireSuppliedXZOverPolygon, captureSyntheticTestTiming: false' in tests and 'try strict.reset()' in tests)
    check('new endpoints use unchanged fixed body', 'MeshCandidateBody(radius: 0.225, height: 1.75)' in tests)
    check('no app/native-session/physical sink additions', all(token not in ingress + bench for token in
          ['ARSession()', 'session.run(', 'AVSpeechSynthesizer', 'SpatialRouteTicket', 'URLSession']))
    return checks

def historical_base_checks():
    path = ROOT / 'research/live-mesh-classified-bench-20261028/check_source.py'
    spec = importlib.util.spec_from_file_location('historical_classified_bench_source_contract', path)
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    base = load_base()
    original_sources = {p: base['research/live-mesh-classified-bench-20261028/' + p] for p in module.FILES}
    return module.validate(original_sources)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--source-root', type=Path, help='Review applied CURRENT files instead of isolated candidates')
    args = parser.parse_args()
    for path in [HERE / 'prepare_candidate.py', Path(__file__), HERE / 'test_current_contract.py']:
        ast.parse(path.read_text())
    sources = load_candidate(args.source_root)
    checks = validate(sources)
    original_checks = historical_base_checks()
    base = load_base()
    patch = ''.join(''.join(difflib.unified_diff(base[p].splitlines(True), sources[p].splitlines(True),
                                              fromfile='a/' + p, tofile='b/' + p)) for p in CHANGED)
    assert patch == (HERE / 'STRICT_CALLER_LAYER.patch').read_text()
    result = {'schema': 1, 'kind': 'CURRENT_source_contract_only', 'currentChecksPassed': len(checks),
              'checks': checks, 'historicalBaseSourceChecksPassed': len(original_checks),
              'original83NativeChecksRetained': 83, 'new83NativeChecksAuthored': 25,
              'benchNativeTestNames': re.findall(r'func (test\w+)\(', sources[BENCH_TEST]),
              'newBenchCasesAuthored': NEW_TESTS, 'swiftParsed': False, 'swiftCompiled': False,
              'swiftTestsExecuted': False, 'liveSourceEditedByThisPacket': False,
              'physicalAuthority': False, 'appActivation': False,
              'sourceHashes': {p: hashlib.sha256(v.encode()).hexdigest() for p, v in sources.items()}}
    (HERE / 'CURRENT_SOURCE_RESULT.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({k: result[k] for k in ['kind', 'currentChecksPassed', 'historicalBaseSourceChecksPassed',
                                           'new83NativeChecksAuthored', 'newBenchCasesAuthored', 'swiftTestsExecuted']}, indent=2))

if __name__ == '__main__':
    main()
