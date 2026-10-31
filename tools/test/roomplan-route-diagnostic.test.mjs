import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
const read = path => readFileSync(new URL(`../../${path}`, import.meta.url), 'utf8');
const digest = data => createHash('sha256').update(data).digest('hex');
const base = 'research/room-mesh-package-75/BlindRoomMesh/Sources/';
const runtime = read(base+'BlindRoomMesh/RoomMeshCandidate.swift');
const bridge = read(base+'BlindRoomMesh/Bridge.swift');
const native = read(base+'CDetour/blind_detour_exclusion.cpp');
const adapter = read('ios/BlindAssist/SavedRoomRouteMeshAdapter.swift');
const oracle = read('ios/BlindAssistTests/SavedRoomRouteCollisionOracle.swift');
const bench = read('ios/BlindAssistTests/SavedRoomRouteDiagnosticAppleTests.swift');

test('baseline twelve schedules and separate width28 addendum remain preregistered exact bytes', () => {
  const protocol = read('research/roomplan-route-diagnostic-20261028/PROTOCOL.json');
  const addendum = read('research/roomplan-route-diagnostic-20261028/PROFILE_28CM_ADDENDUM.json');
  assert.equal(digest(protocol),'ee8f183ca4d7b6fd9aabecf2f7cd8d39bc472ce071873bceafe4c557f65f8123');
  assert.equal(digest(addendum),'c52792a1213a1b3969e97a6201d43bac2426a444f3f39e8b906a5feb0e0f701d');
  assert.equal(read('ios/BlindAssistTests/Fixtures/RoomRouteDiagnostic/PROTOCOL.json'),protocol);
  assert.equal(read('ios/BlindAssistTests/Fixtures/RoomRouteDiagnostic/PROFILE_28CM_ADDENDUM.json'),addendum);
  const p=JSON.parse(protocol),a=JSON.parse(addendum);
  assert.equal(p.pairs.length*p.profiles.length,12);
  assert.equal(p.pairs.length*a.profiles.length,6);
  assert.deepEqual(a.profiles[0],{id:'declared-width28-assumed-depth20-height120',width:0.28,depth:0.20,height:1.20,margin:0.15});
  assert.equal(p.physicalAuthority,false); assert.equal(p.sourceGeometryExpanded,false);
  assert.equal(p.supportPolicy,'classifiedFloorOnly');
  assert.equal(new Set(p.pairs.map(x=>x.id)).size,6);
});

test('classified runtime cannot silently mix missing labels with legacy slope mode', () => {
  assert.match(runtime,/enum MeshTriangleSupport: UInt8, Codable, Sendable/);
  assert.match(runtime,/supportPolicy: MeshSupportPolicy = \.legacySlope/);
  assert.match(runtime,/event\.triangleSupport\?\.count == event\.triangles\.count\/3/);
  assert.match(runtime,/guard shapeBounded,supportValid,pending<maxPending/);
  assert.match(runtime,/triangleSupport:owner\.geometrySupport\(\)/);
  assert.match(bridge,/guard supportPolicy == \.classifiedFloorOnly \? p\.triangleSupport\?\.count == p\.triangles\.count\/3 : p\.triangleSupport == nil/);
  assert.match(bridge,/for key in tiles\.keys\.sorted\(\)/);
  assert.match(bridge,/missing triangle support/);
  assert.match(bridge,/bn_build_classified/);
});

test('source-classified Recast uses obstacle-priority raster tags before existing filters', () => {
  const classify=native.indexOf('if (classifiedFloorOnly) {',native.indexOf('std::vector<unsigned char> areas'));
  const clear=native.indexOf('rcClearUnwalkableTriangles',classify);
  const obstacle=native.indexOf('if (triangleSupport[i]==0) areas[i]=2',clear);
  const raster=native.indexOf('rcRasterizeTriangles',obstacle);
  const remap=native.indexOf('span->area=span->area==1 ? RC_WALKABLE_AREA : RC_NULL_AREA',raster);
  const filter=native.indexOf('rcFilterLedgeSpans',remap);
  assert.ok(classify>=0 && clear>classify && obstacle>clear && raster>obstacle && remap>raster && filter>remap);
  assert.match(native,/if \(triangleSupport\[i\]==1\) areas\[i\]=1/);
  assert.match(native,/rcMarkWalkableTriangles/); // separate original legacy branch
  assert.match(native,/classifiedFloorOnly && !triangleSupport/);
  assert.match(read('ios/BlindAssistTests/ClassifiedRoomMeshTests.swift'),/FloorTouchingBedAndLowObjectNeverGainSupportUnderTriangleOrderPermutations/);
  assert.match(read('ios/BlindAssistTests/ClassifiedRoomMeshTests.swift'),/for height in \[0\.025, 0\.65\]/);
});

test('native adapter uses actual mesh export and identity-mapped floor-only triangles without model replacement', () => {
  assert.match(adapter,/JSONDecoder\(\)\.decode\(CapturedRoom\.self/);
  assert.match(adapter,/metadataURL: metadataURL, modelProvider: nil, exportOptions: \.mesh/);
  assert.match(adapter,/preserveTopology: false/);
  assert.match(adapter,/MDLTransform\.globalTransform/);
  assert.match(adapter,/metadata\[node\.name\] \?\? inheritedID/);
  assert.match(adapter,/let isFloor = feature\.kind == \.floor/);
  assert.match(adapter,/try verifySourceBounds/);
  assert.match(adapter,/defer \{ try\? manager\.removeItem/);
  assert.match(adapter,/guard !Thread\.isMainThread/);
  assert.doesNotMatch(adapter,/ARSession\(/);
});

test('independent test-only full-cylinder oracle has zero hidden inflation and mandatory controls', () => {
  assert.match(oracle,/SCNCylinder\(radius: CGFloat\(radius\), height: CGFloat\(height\)\)/);
  assert.match(oracle,/concavePolyhedron, \.collisionMargin: 0\.0/);
  assert.equal((oracle.match(/options: \[\.collisionMargin: 0\.0\]/g)||[]).length,2);
  assert.match(oracle,/convexSweepTest/);
  assert.match(oracle,/contactTest\(with: body/);
  assert.match(oracle,/updateCollisionPairs/);
  // Startup now records every fixed control instead of stopping at the first
  // error string. Preserve the mandatory candidate gate, not obsolete wording.
  for (const name of ['thinWallForward','thinWallReverse','wallInitialOverlap','wallTerminalOverlap',
    'containedSolid','overheadTallForward','overheadTallReverse','overheadShort','clear','floor']) {
    assert.ok(oracle.includes(name));
  }
  assert.match(oracle,/if checkBackend \{ try Self\.verifyBackend\(configuration: configuration, queryMode: queryMode\) \}/);
  assert.match(oracle,/static let candidate = BackendConfiguration\.defaultOffscreenRenderer/);
  assert.match(oracle,/configuration: \.candidate, queryMode: \.separated, checkBackend: true/);
  assert.match(oracle,/let original = backendQueries\(configuration: configuration, queryMode: queryMode\)/);
  assert.match(oracle,/let mixed = mixedSceneQueries\(layout: \.wallAndFloor, queryMode: queryMode\)/);
  assert.match(oracle,/Set\(\(original \+ mixed\)\.filter \{ !\$0\.passed \}\.map\(\\\.name\)\)/);
  assert.match(oracle,/guard failures\.isEmpty else \{\s*throw Failure\.backendUnavailable/);
  // Preserve all categories and all phases: query filtering is not permission
  // to drop floor geometry, move/shrink the body or skip a failed mixed control.
  assert.match(oracle,/private var floorMask: Int \{ queryMode == \.separated \? 4 : sourceMask \}/);
  assert.match(oracle,/private var allSourceMask: Int \{ sourceMask \| floorMask \}/);
  assert.match(oracle,/private var queryMasks: \[Int\] \{ queryMode == \.separated \? \[sourceMask, floorMask\] : \[sourceMask\] \}/);
  assert.match(oracle,/body\.categoryBitMask = kind == \.floorSurface \? floorMask : sourceMask/);
  assert.equal((oracle.match(/for mask in queryMasks \{/g)||[]).length,2);
  assert.match(oracle,/swept\.formUnion\(try contacts\(raw\)\)/);
  assert.match(oracle,/result\.formUnion\(try contacts\(scene\.physicsWorld\.contactTest/);
  assert.match(oracle,/let queries = backendQueries\(configuration: configuration, queryMode: \.combined\)/);
  assert.match(oracle,/backendReady: failures\.isEmpty, failedControls: failures, queries: queries/);
  assert.match(oracle,/result\.swept\.obstacleSurfaceIDs == \[controlWall\]/);
  assert.match(oracle,/result\.swept\.obstacleSurfaceIDs == \[controlOverhead\]/);
  assert.match(oracle,/case \.overheadShort, \.clear:\s*passed = all == empty/);
  assert.match(oracle,/result\.initial\.furnitureBoundIDs == \[controlSolid\]/);
  assert.match(oracle,/result\.terminal\.floorSurfaceIDs == \[controlFloor\]/);
  assert.match(oracle,/fullFootprintSupportVerified = false/);
});

test('bench preserves all outcomes and never feeds oracle feedback into route selection', () => {
  assert.match(bench,/let candidate = try await query\(owner/);
  assert.ok(bench.indexOf('let candidate = try await query(owner')<bench.indexOf('let initialBody = try oracle.sweep'));
  assert.match(bench,/var effectiveRadius: Float \{ Float\(radius \+ margin\) \}/);
  assert.match(bench,/var effectiveHeight: Float \{ Float\(height \+ margin\) \}/);
  assert.match(bench,/requested-start-to-projection/);
  assert.match(bench,/projection-to-requested-goal/);
  assert.match(bench,/not-run-after-aborted-stage/);
  assert.match(bench,/try attachment\(results,errors:errors,label:label\).*preserve outcomes BEFORE assertions/);
  assert.match(bench,/XCTAssertGreaterThan\(completedCandidates,0/);
  assert.match(bench,/XCTAssertEqual\(conflictingCompleteCandidates,0/);
  assert.match(bench,/owner\.invalidate\(\); sink\.retire\(\)/);
  assert.doesNotMatch(bench,/SpatialFloorSupport\(|SpatialRouteTicket\(|AVSpeechSynthesizer|UIImpactFeedbackGenerator|ARSession\(/);
});

test('separate supplied-posture journeys keep baseline eighteen intact and use existing code guidance only', () => {
  const text=read('research/roomplan-route-diagnostic-20261028/JOURNEY_ADDENDUM.json');
  assert.equal(digest(text),'8e060627d0f570820fd00a427e22f6672eb50048611dfc9682986cac5c30cc9a');
  assert.equal(read('ios/BlindAssistTests/Fixtures/RoomRouteDiagnostic/JOURNEY_ADDENDUM.json'),text);
  const p=JSON.parse(text),source=read('ios/BlindAssistTests/SavedRoomRouteJourneyAppleTests.swift');
  assert.equal(p.journeys.length,5); assert.equal(p.journeys.reduce((n,j)=>n+j.stages.length,0),16);
  assert.equal(p.denominator.baselineCandidateSchedulesUnchanged,18);
  assert.equal(p.cameraLocalizationTested,false); assert.equal(p.getUpKinematicsTested,false);
  assert.equal(p.physicalAuthority,false); assert.deepEqual(p.declaredHeadingFloorLocal,[1,0,0]);
  for (const call of ['SpatialFacts.relation(','SpatialFacts.phrase(','cadence.label(']) assert.ok(source.includes(call));
  assert.match(source,/sourceSHA256 == expected/); assert.match(source,/standing && sourceSHA256/);
  assert.match(source,/let heading=pose\.heading/);
  assert.match(source,/segments: \[CandidateSegment\]/);
  assert.match(source,/first\.from == pose\.position/);
  assert.match(source,/segment\.from == previous/);
  assert.match(source,/segments:segments,pose:pose/);
  assert.match(source,/for segment in segments \{/);
  for (const kind of ['requested-start-to-projection','projection-to-detour-start','detour-end-to-projection','projection-to-requested-goal']) assert.ok(source.includes(kind));
  assert.match(source,/receipt\["from"\] as\? \[Float\],array\(segments\[index\]\.from\)/);
  assert.match(source,/receipt\["to"\] as\? \[Float\],array\(segments\[index\]\.to\)/);
  assert.doesNotMatch(source,/index==1 \? \[pose\.position/);
  assert.match(source,/not-run-after-journey-stop/); assert.match(source,/not-run-after-aborted-stage/);
  assert.match(source,/No inferred open door or outside floor/);
  assert.doesNotMatch(source,/SpatialFloorSupport\(|SpatialRouteTicket\(|AVSpeechSynthesizer|UIImpactFeedbackGenerator|ARSession\(/);
});

test('export witness preserves original boundary and concavity without requiring collinear tessellation vertices', () => {
  const source=read('ios/BlindAssistTests/SavedRoomRouteMeshAppleFixtureTests.swift');
  assert.match(source,/originalBoundary,exportedBoundary.*exportedBoundary,originalBoundary/);
  assert.match(source,/feature\.polygonCorners\.count,source\.polygonCorners\?\.count/);
  assert.match(source,/Original floor boundary must be preserved/);
  assert.match(source,/area, sourceArea/);
  assert.match(source,/SIMD2<Double>\(0, 0\.5\)/);
  assert.doesNotMatch(source,/let nearest = exportedFloorVertices/);
});

// Post-freeze bookkeeping repair; endpoints, profiles and existing run evidence
// stay unchanged. This is a source contract, not native collision/support proof.
test('baseline collision scoring retains an exact continuous endpoint chain without claiming floor support', () => {
  for (const kind of ['requested-start-to-projection','projection-to-detour-start','detour-end-to-projection','projection-to-requested-goal']) assert.ok(bench.includes(kind));
  assert.match(bench,/guard segment\.from == endpoint/);
  assert.match(bench,/endpoint == \(complete \? goal : last\)/);
  assert.match(bench,/let segments = try scoredSegments/);
  assert.match(bench,/for segment in segments/);
  assert.match(bench,/scoredChainIncludesRequestedGoal"\] = route\.complete/);
  assert.match(bench,/sourceFloorSupportAlongScoredChain"\] = "unverified-full-footprint"/);
  assert.match(bench,/"floorContactIDs":margin\.all\.floorSurfaceIDs/);
  assert.match(bench,/"fullFootprintSupportVerified":false,"sourceFloorSupport":"unverified-full-footprint"/);
  assert.match(bench,/testScoredChainRetainsBothNativeEndpointDiscrepanciesAndNeverBridgesPartialGoal/);
  assert.doesNotMatch(bench,/SIMD3\(\(0\.\.<3\)\.map/);
  assert.doesNotMatch(read('ios/BlindAssistTests/SavedRoomRouteJourneyAppleTests.swift'),/SIMD3\(\(0\.\.<3\)\.map/);
});
