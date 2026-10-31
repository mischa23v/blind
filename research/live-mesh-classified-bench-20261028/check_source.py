#!/usr/bin/env python3
"""Bounded source-contract checks; not a Swift compiler or native behavior test."""
from pathlib import Path
import difflib
import hashlib
import json
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
OLD = HERE.parent / 'live-mesh-bench-proposal-20261028'
FILES = ['Package.swift', 'Sources/LiveMeshBenchIngress.swift', 'Sources/LiveMeshBenchSession.swift',
         'Tests/LiveMeshBenchIngressTests.swift', 'Tests/LiveMeshBenchSessionTests.swift']

def load_sources():
    return {p: (HERE / p).read_text() for p in FILES}

def validate(s):
    checks = []
    def check(name, condition):
        if not condition:
            raise AssertionError(name)
        checks.append(name)
    package, core, native, tests, native_tests = (s[p] for p in FILES)
    check('bounded source files', all(len(v.encode()) <= 64000 for v in s.values()))
    check('named standalone package and test target', package == (OLD / FILES[0]).read_text().replace('LiveMeshBenchProposal', 'LiveMeshClassifiedBench'))
    check('four existing local packages, no download dependency', package.count('.package(path:') == 4 and '.package(url:' not in package)
    check('actual83 classified policy fixed at construction', 'supportPolicy: .classifiedFloorOnly, decodeQueue: decodeQueue)' in core and 'legacySlope' not in core)
    check('one copy slot and128 identities', 'MeshCandidateIngress83(maxAnchors: 128, maxCopies: 1,' in core)
    check('no public forged snapshot seam', 'capture: (MeshSnapshot82.Context) -> MeshSnapshot82.Capture' in core and 'Owned(' not in core)
    check('native actual82 synchronous copy', 'return ARKitMeshAdapter82.capture(anchor, context: context, limits: limits)' in native)
    check('classified native capability required', 'ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) else { throw Failure.unavailable }' in native)
    check('no unclassified configuration fallback', 'configuration.sceneReconstruction = .meshWithClassification' in native and '? .meshWithClassification : .mesh' not in native)
    check('no second session or automatic app activation', 'ARSession()' not in native and native.count('session.run(configuration') == 1)
    check('debug iOS native producer only', native.startswith('#if DEBUG && os(iOS) && canImport(ARKit)'))
    check('authorities remain false', core.count('public let authorizesPhysicalGuidance = false') == 1 and native.count('public let authorizesPhysicalGuidance = false') == 1)
    check('monitoring warning remains explicit', 'Phone hazard monitoring is unavailable' in native and 'public let phoneMonitoringAvailable = false' in core+native)
    check('no physical or outbound sinks', all(v not in core+native for v in ['SpatialRouteTicket', 'SpatialLocalizationCapture', 'Feedback(', 'AVSpeechSynthesizer', 'URLSession']))
    check('generation admission fence', 'guard active(generation) else { return false }' in core)
    check('no wrapper reset', not re.search(r'func\s+reset\s*\(', core))
    check('incomplete source is refused before completion', 'guard Self.hasCompleteSource(candidate) else { completion(.failure(.unavailable)); return }' in core)
    check('display rechecks complete source', 'Self.hasCompleteSource(candidate) && active(generation) && ingress.isCurrent(candidate)' in core)
    check('complete delivery and zero gaps both required', 'candidate.route.sourceDeliveryComplete && candidate.route.unknownCoverage.isEmpty' in core)
    check('revision current still required after complete-source gate', 'guard self.ingress.isCurrent(candidate) else { completion(.failure(.stale)); return }' in core)
    check('callback aggregate bound and rotation', 'offer(selected, true)' in core and 'offer(index, false)' in core and 'next = (selected + 1) % count' in core)
    check('callback input cap', '(0...128).contains(count)' in core and 'anchors.count <= 128' in native)
    check('omissions explicit unknown', 'guard copyAllowed else { return .unknownGap' in native)
    check('whole-copy limits preserved', 'vertices: 32_000, faces: 32_000' in native and 'inputBytes: 1_500_000, decodedBytes: 1_500_000' in native)
    check('frame freshness before copy', native.index('guard frameIsCurrent() else') < native.index('return ARKitMeshAdapter82.capture'))
    check('replayed/preactivation frame guard retained', 'frame.timestamp > $0' in native and 'frame.timestamp >= beganAt' in native)
    check('exact UUID removal', 'ingress.remove(anchorID: anchor.identifier, generation: ingress.generation' in native)
    check('exact owner and queue restoration after drain', 'producer.ingress.stopAndDiscard' in native and 'let stillOwned = session.delegate === producer && session.delegateQueue === producerQueue' in native)
    check('no nil delegate ABA window', 'session.delegate = nil' not in native)
    check('background and interruption retire', 'UIApplication.willResignActiveNotification' in native and 'func sessionWasInterrupted' in native and 'Never restart an interrupted generation' in native)
    check('deinit cleanup retained', 'deinit {' in native and 'let callback = onStopped' in native)
    check('fifteen authored dependency fixtures', len(re.findall(r'func test', tests)) == 15)
    check('five native never-activated fixtures', len(re.findall(r'func test', native_tests)) == 5 and 'session.run(' not in native_tests)
    check('tests import actual stage', '@testable import LiveMeshClassifiedBench' in tests and '@testable import LiveMeshClassifiedBench' in native_tests)
    check('synthetic class bytes exercise82', 'classificationBytes: labels' in tests and 'labels: [UInt8]? = [2,2]' in tests)
    check('native negative assertions do not accept stale/unavailable', 'case .failure(.runtime(.nativeFailure)): break' in tests)
    check('retained old floor explicitly refused', 'testMalformedReplacementCannotExposeRetainedOldFloorPreview' in tests and 'assertIncompletePreviewRefused(try query(owner))' in tests)
    check('refused removal fixture present', 'testQueuedFloorThenRefusedRemovalCannotExposeStaleFloorPreview' in tests and 'XCTAssertFalse(owner.remove(anchorID: anchor, generation: owner.generation, receiptUptime: 1))' in tests)
    check('transform metric/reflection fixtures present', 'testRotatedTranslatedMetreGeometryUsesExactlyOneRigidTransform' in tests and 'testScaleAndReflectionReplacementCannotExposePriorFloor' in tests)
    check('foreign generation cannot revive geometry', 'testNewTerminalOwnerCannotReusePriorGenerationOrGeometry' in tests)
    # Full native lifecycle is identical except the two deliberate classification changes.
    expected_native = (OLD / FILES[2]).read_text().replace(
        'ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) else',
        'ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) else').replace(
        'configuration.sceneReconstruction = ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification)\n            ? .meshWithClassification : .mesh',
        'configuration.sceneReconstruction = .meshWithClassification')
    check('native lifecycle otherwise exactly frozen source', native == expected_native)
    check('five native tests unchanged except module import', native_tests == (OLD / FILES[4]).read_text().replace('LiveMeshBenchProposal', 'LiveMeshClassifiedBench'))
    return checks

def run():
    sources = load_sources()
    checks = validate(sources)
    pins = json.loads((HERE / 'INPUT_PINS.json').read_text())['files']
    for row in pins:
        data = (ROOT / row['path']).read_bytes()
        assert len(data) == row['bytes'], row['path']
        assert hashlib.sha256(data).hexdigest() == row['sha256'], row['path']
    checks.append('all frozen/app/dependency local input pins unchanged')
    remote = json.loads((HERE / 'REMOTE_SOURCE_RECEIPT.json').read_text())
    local = {p['path']: p for p in pins}
    compared = 0
    for row in remote['files'] + remote['dependency_and_frozen_sources']:
        if row['path'] in local:
            assert local[row['path']]['git_blob_sha'] == row['git_blob_sha'], row['path']
            compared += 1
    assert compared == 15, compared
    checks.append('15 materialized inputs match connector-verified exact-commit blobs')
    for relative in ['../mesh-candidate-ingress-83', '../arkit-mesh-adapter-82', '../native-mesh-decoder-81', '../room-mesh-package-75/BlindRoomMesh']:
        assert (HERE / relative / 'Package.swift').is_file(), relative
    checks.append('all four declared dependency package paths exist')
    patch = ''.join(''.join(difflib.unified_diff((OLD/p).read_text().splitlines(True),sources[p].splitlines(True),fromfile='a/'+p,tofile='b/'+p)) for p in FILES)
    assert patch == (HERE / 'classified-consumer.patch').read_text()
    checks.append('patch exactly describes staged five-file delta')
    result = {'kind': 'source_contract_only', 'checks_passed': len(checks), 'checks': checks,
              'pinned_unchanged_inputs': len(pins), 'remote_blob_matches': compared,
              'authored_dependency_fixtures': 15, 'authored_ios_ownership_fixtures': 5,
              'swift_compiled': False, 'swift_tests_executed': False, 'native_camera_activated': False,
              'app_linked': False, 'physical_guidance_authorized': False,
              'blocked': 'Native execution requires an approved Apple/Xcode environment; no Swift/Xcode exists here.'}
    (HERE / 'SOURCE_RESULT.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps({k: result[k] for k in ['kind','checks_passed','pinned_unchanged_inputs','remote_blob_matches','swift_tests_executed']}))

if __name__ == '__main__':
    run()
