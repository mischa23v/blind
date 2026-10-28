#!/usr/bin/env python3
"""Candidate source and real anchor provenance checks only. Not Swift execution."""
import hashlib,json,re,shutil
from pathlib import Path
HERE=Path(__file__).resolve().parent; ROOT=HERE.parent.parent
sha=lambda x:hashlib.sha256(x).hexdigest()
t=(HERE/'ConnectedNavigationBenchIntegrationTests.swift').read_text()
f=(HERE/'KoivuSourceAnchorBenchFixture.swift').read_text()
r=json.loads((HERE/'RECORDED_INPUT_RECEIPT.json').read_text()); raw=(ROOT/r['source']).read_bytes();src=json.loads(raw)
anchors={}
for p in src['pairs']:
 for side in ('start','goal'):
  k=str(p[side+'AnchorIndex']); value=p[side+'OriginalXYZ']
  assert k not in anchors or anchors[k]==value
  anchors[k]=value
checks={
 'recorded_source_sha_matches':sha(raw)==r['sha256'] and r['sha256'] in f,
 'five_exact_source_anchors_twenty_pairs':anchors==r['anchors'] and len(anchors)==5 and len(src['pairs'])==20,
 'fixture_coordinates_match_source':all('.init('+', '.join(repr(x) for x in anchors[k])+')' in f for k in anchors),
 'no_recorded_floor_or_edges_invented':'edges: [], surfaces: nil' in f and 'savedWorldFrame:' not in f,
 'authored_namespace_disclosed':'authored dataset namespace' in f,
 'actual_native_import_and_owner':all(x in t for x in ['IndoorNavigator(storage:', 'loadRegisteredInstallation(', 'onJourneyMapPublished =', 'try runtime.install(installation)', 'ConnectedJourneyRuntime(io:']),
 'actual_issuer_candidate_and_pair':all(x in t for x in ['NativeLocalizationRouter(journey:', 'router.offer(', 'router.prepareForBench(', 'pair.capture.id, candidate.id', 'pair.support.captureID, candidate.id']),
 'actual_planner_and_output_controller':all(x in t for x in ['runtime.next(now:', 'SpatialRouteOutputController()', 'sink.deliver(', 'runtime.permits(candidate,']),
 'actual_hazard_missing_observation':all(x in t for x in ['HazardDetector()', 'detector.process(', 'trackingNormal: false', 'sink.revalidate()']),
 'physical_release_still_withheld':'XCTAssertEqual(router.reason, .physicalReleaseNotApproved)' in t,
 'missing_support_negative_present':'testMissingSupportNeverReachesRuntimeAcceptance' in t and 'omitSupport: true' in t,
 'recorded_import_negative_not_fake_success':'testRecordedKoivuMetadataLoadsThroughOwnersWithoutInventingRegistrationOrFloor' in t and '.importedFrameNeedsMeasuredRegistration' in t,
 'hosted_sources_match_reviewed_candidates':all((ROOT/'ios/BlindAssistTests'/name).read_bytes()==(HERE/name).read_bytes() for name in ['ConnectedNavigationBenchIntegrationTests.swift','KoivuSourceAnchorBenchFixture.swift']),
 'production_issuer_does_not_accept':not re.search(r'(?m)^\s*(?:try\??\s+)?(?:\w+\.)?acceptRegisteredCapture\(', (ROOT/'ios/BlindAssist/NativeLocalizationIssuer.swift').read_text()),
}
assert all(checks.values()),checks
sources=['ios/BlindAssist/IndoorNavigator.swift','ios/BlindAssist/ConnectedJourneyRuntime.swift','ios/BlindAssist/NativeLocalizationRouter.swift','ios/BlindAssist/NativeLocalizationIssuer.swift','ios/BlindAssist/SpatialRouteOutputController.swift','BlindCore/Sources/BlindCore/NativeLocalizationEvidence.swift','BlindCore/Sources/BlindCore/HazardDetector.swift','ios/BlindAssistTests/SpatialIntegrationFixture.swift']
(HERE/'SOURCE_PINS.json').write_text(json.dumps({p:sha((ROOT/p).read_bytes()) for p in sources},indent=2)+'\n')
result={'sourceChecksPassed':len(checks),'checks':checks,'swiftAvailable':shutil.which('swift') is not None,'swiftTestsExecuted':False,'nativeBuildExecuted':False,'recordedMovementExecuted':False,'physicalAuthority':False,'scope':'Source/provenance only. Reviewed sources copied to hosted-test directory; PBX owner coordinates membership and native CI remains pending. Not N00 completion.'}
(HERE/'SOURCE_CHECK_RESULT.json').write_text(json.dumps(result,indent=2)+'\n'); print(json.dumps(result))
