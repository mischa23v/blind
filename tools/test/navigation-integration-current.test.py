#!/usr/bin/env python3
"""CURRENT source contracts only; does not execute Swift or confer runtime authority.
Run from any cwd: python3 tools/test/navigation-integration-current.test.py
All behavior checks read current repository bytes. Embedded method identities and
prefix hashes preserve original authored fixtures only, not historical behavior.
"""
from pathlib import Path
import hashlib,json,re,os
ROOT=Path(os.environ.get('BLIND_SOURCE_ROOT',Path(__file__).resolve().parents[2]))
RESULTS=[]
def read(path):return (ROOT/path).read_text()
def digest(value):return hashlib.sha256(value.encode()).hexdigest()
def check(name,value):
    assert value,name
    RESULTS.append(name)

def same_owner():
    b='research/live-mesh-classified-bench-20261028/'
    s=read(b+'Sources/LiveMeshBenchSession.swift');r=read(b+'Sources/MeshBenchSavedWorldRecovery.swift')
    c=read('ios/BlindAssist/SeatedMeshDiagnosticController.swift');n=read('ios/BlindAssist/NavigationModel.swift');v=read('ios/BlindAssist/SeatedMeshDiagnosticView.swift')
    t=read('ios/BlindAssistTests/SeatedMeshProjectionTests.swift')
    check('paired byte digests checked before archive decode',s.index('frame.matches(')<s.index('NSKeyedUnarchiver.unarchivedObject'))
    check('seed constructor inaccessible to callers','private init(frame:SavedWorldFrame,map:ARWorldMap)' in s)
    check('bounded original bytes and anchors',all(x in s for x in ['maximumWorldBytes=32*1024*1024','maximumRoomBytes=8*1024*1024','map.anchors.count<=128','frame.anchors.count<=128']))
    check('same delegate queue required before preparation','lifecycle == .prepared,session.delegate === producer,session.delegateQueue === producerQueue' in s)
    check('map installed before run and existing reset retained',s.index('configuration.initialWorldMap=seed?.map')<s.index('session.run(configuration, options: [.resetTracking, .removeExistingAnchors])'))
    check('actual frame uses exact ingress generation and timestamp','savedWorldRecovery.observe(session:ingress.generation' in s and 'capturedAt:frame.timestamp,now:now' in s)
    check('original origin identity and finite matrix','anchor.identifier.uuidString==frame.originAnchorID,anchor.name==frame.originAnchorName' in s and 'v.isFinite,abs(v-' in s)
    check('stop retires seed and recovery','savedWorldSeed=nil;producer.savedWorldRecovery.retire()' in s)
    check('existing recovery gate reused and guarded','SavedWorldFrameRecovery()' in r and 'lock.lock()' in r and 'current.recoveryID == association.recoveryID' in r)
    check('loader checks private source owner twice',c.count('source.memory.writeOwner==source.memoryOwner')==2)
    check('loader uses bounded reader twice',c.count('SpatialMapFileStorage.readBounded')==2)
    check('activation after post-load source and selection recheck',c.index('request.isCurrent(),destinationProvider()==request.destination',c.index('private func performSavedWorldRestore'))<c.index('bench?.prepareSavedWorld(seed)',c.index('private func performSavedWorldRestore')))
    check('full stop waits for actual loader disposal','!collisionPending, !restorationPending' in c and 'work.source=nil;self.restorationPending=false' in c)
    check('real protected source fetched before handoff',n.index('places.diagnosticGeometrySource(for:frame)')<n.index('seatedDiagnosticHold = true // Before cleanup'))
    check('actor-isolated store calls use existing main bridge','MainActor.assumeIsolated({ places.diagnosticGeometrySource(for:frame) })' in n and 'MainActor.assumeIsolated({ self.places.ownsDiagnosticGeometrySource(source) })' in n)
    check('opt in defaults off','restoreSelectedWorld: Bool = false' in n and '@State private var restoreSelectedWorld = false' in v)
    check('actual production adapter in existing consumer fixture','private let recovery=MeshBenchSavedWorldRecovery()' in t and 'recovery.isCurrent(association,now:now)' in t)
    check('held loader races and no archive success forgery',all(x in t for x in ['for reason in ["deletion","goal","cancel"]','exerciseHeldSavedWorldLoaderRetirement()','backend.activationCount,0','ownerDone.assertForOverFulfill=true','return .failure(LiveMeshBenchSession.Failure.unavailable) // No forged successful AR archive.']))
    pattern=r'func (test\w+)\('
    old=['testIdentityKeepsRawARKitAxesAndMetres', 'testColumnMajorRotationTranslationAppliedExactlyOnce', 'testEachAnchorUsesItsOwnTransformWithoutFrameSubstitution', 'testMalformedNonfiniteAndPerspectiveInputRejectWholeProjection', 'testWholeProjectionRejectsVertexBudgetAndFloatOverflow', 'testDoubleLocalValuesCanCancelBeforeBoundedFloatProjection', 'testRouteMustMatchExactCurrentSourceSessionGenerationAndRevision', 'testConfirmationIsExactSingleUseAndRetiresOnStopOrViewReplacement', 'testStopKeepsOwnerUntilNativeAndHeldRendererBothDrain', 'testMainDeliveryCannotReleaseOwnerBeforeWorkerClosureReturns', 'testDeclaredFootUsesActualStrictQueryAndHistoricalDisplayWithoutFrameRebinding', 'testHeldControllerResultCannotPublishAfterExplicitReplacementOrSourceChange', 'testActualSourceAndStrictQueryCompleteWhileOptionalRenderIsHeld', 'testActualAuditRetirementAndDisposalAfterRealOracleProgress', 'testMappedDestinationFeedsActualStrictQueryAndCollisionReceipt', 'testMappedDestinationRefusesMissingWrongStaleAndCrossFloorAssociation', 'testMappedDestinationRetiresHeldResultsOnRestartMapGoalAndSourceChanges'];new=re.findall(pattern,t)
    check('all seventeen seated method identities unchanged',old==new and len(new)==17)
    old=['testStableOmittedAnchorReacquiredFromLaterFrameOnlyOnce', 'testAbsentAnchorRemainsPendingUntilTimeoutNeverRemoved', 'testAdmissionBackpressureRetriesAtMostThreeAndFairlyRotates', 'testMaximumRequestIssuesExactly192AttemptsThenStops', 'testWholeRequestOverflowDuplicatesAndPresentFrameOverflowRefused', 'testRepeatedRequestCancellationAndWrongAdmissionDoNotOverlap', 'testSchedulerClockFailuresAreTerminalWithinRequest', 'testStartupGraceIsNotCurrentButCanBecomeHealthy', 'testStartupExpiryAndFrameExpiryCannotRevive', 'testTrackingLossAndStopAreTerminalAndDoNotChangeReason', 'testLeaseRejectsDuplicateFutureNonfiniteAndBackwardsCapture', 'testIndependentWatchdogRetiresWhileProducerDoesNoWork', 'testActivationBoundaryAcceptsNewRunFrameBeforeDelayedProducerBegins', 'testLeaseBackwardsAndNonfiniteClockAreTerminal', 'testOrdinaryFrameDoesNotRebindFrozenRequestButExplicitRecaptureDoes', 'testSessionChangeExpiryAndInvalidAdmissionRetireSnapshot', 'testChangedGeometryBeforeQueryIsRefusedWithoutNativeReplan'];new=re.findall(pattern,read(b+'Tests/MeshBenchHelperTests.swift'))
    check('six recovery methods append without replacing original seventeen',new[:len(old)]==old and len(new)-len(old)==6)
    check('existing local BlindCore dependency no remote dependency','.package(path: "../../BlindCore")' in read(b+'Package.swift') and '.package(url:' not in read(b+'Package.swift'))
    check('no authority flag granted','independentlyValidated: true' not in s+c+n+r)

same_owner()

def route_reassociation():
    c=read('BlindCore/Sources/BlindCore/ConnectedJourneyCoordinator.swift');r=read('ios/BlindAssist/ConnectedJourneyRuntime.swift');t=read('ios/BlindAssistTests/ConnectedJourneyRuntimeTests.swift')
    check('existing planner retirement only','public mutating func requireRouteReassociation() {retirePlan()}' in c)
    check('portal request bound to exact armed endpoints goal and time',all(x in c for x in ['id==armedPortal.id,from==armedPortal.from,to==armedPortal.to','snapshot.goal?.revision==armedPortal.goal','now-armedPortal.armedAt<=120']))
    check('only offroute and blocked leg select reassociation','reason == .offRoute || reason == .blockedLeg' in r)
    check('old output and itinerary retired without guessed start','retireOutput();self.coordinator?.requireRouteReassociation();lastEndpoint=nil' in r)
    check('existing fresh unique endpoint path retained','if let endpoint = currentEndpoint(capture: capture, support: support)' in r and 'try coordinator?.plan(from: endpoint, now: now)' in r)
    check('transition starts owner only not fabricated capture','_ = try coordinator?.beginLocalization(in:target.binding)' in r and 'lastEndpoint=nil;retireOutput()' in r)
    check('all three actual armed-source paths request destination',r.count('try preparePortalDestinationLocalization(now:now)')==3)
    check('no duplicate portal local-leg preparation','completePortal already prepares the next local leg exactly once.' in r)
    check('N03 veto preserved exact','public func retireCurrentObstacleEvidence() { retireOutput() }' in r)
    check('reason clears with retirement','private func retire() {\n        routeReassociationReason=nil' in r)
    pattern=r'func (test\w+)\('
    old=['testDormantNativeRuntimePersistsDestinationButCannotInventCalibrationOrPose', 'testCancelIsSynchronousAndLatestOnlyWhileWriterIsBlocked', 'testPauseRestartAndResumeRetainRealGoalButNeedFreshEvidence', 'testFailedSaveNewCommandAndEraseCannotReviveSupersededGoal', 'testSyntheticFullNativeRuntimeOutAndBackRequiresDeliveredOneUseChoice', 'testMapIOWithdrawalInvalidGoalAndDeletionFenceStaleOutput', 'testUnverifiedCommandsCannotEvenRetireActiveNativeRoute', 'testDeleteWhileRestoreIsPendingCannotReinstallQueuedOldMap', 'testReplacementOrHoldDuringDelayedRestoreOwnsLatestIntent', 'testMaximumHistorySynchronousResidualIsBoundedAndMeasuredNotDeviceLatency', 'testInvalidCalibrationReplacementCannotReuseOldBodyOrRoute', 'testDeleteRestartCannotReimportSameRevisionAndForgetRestrictions', 'testOuterEnvelopeCannotBypassNestedHistoryByteLimit', 'testIntegratedAutomaticRecoveryAfterRejectedEvidence', 'testIntegratedRejectedEvidenceCannotInferMidLegStart', 'testRejectedEvidenceWaitsAtMidLegThenAutomaticallyReplansFromFreshAuthoredNode', 'testAutomaticRecoveryKeepsCurrentConservativeRestrictions'];new=re.findall(pattern,t)
    continuation=['testOffRouteRetiresPlanThenFreshUniqueEndpointReplansWithoutChangingGoal', 'testAutomaticPortalContextWaitsForFreshDestinationEvidence', 'testAutomaticPortalContextRejectsOldSessionAndRestartRetainsIntentOnly', 'testWithdrawnPortalDepartureReplansOnlyFromFreshDestinationEndpoint', 'testExpiredPortalDepartureReplansOnFreshUpperFloorWithoutRecordingCrossing', 'testFreshDifferentDestinationNodeDoesNotInventMissingPortalEndpoint', 'testPortalRecoveryRefusesAmbiguousOrMidLegPoseUntilUniqueEndpointExists', 'testPortalRecoveryRejectsOldSessionAndRestartRequiresNewLocalization', 'testInterruptedReversePortalPreservesReturnGoalAndOriginalStart', 'testGoalChangeDuringPortalInterruptionCannotReviveOldDestination']
    check('all original seventeen plus exact ten continuation methods retained',new==old+continuation and len(new)==27)
    check('new fixtures use actual owner consumer',all(x in t for x in ['runtime.next(now:1.2)','runtime.routeReassociationReason,.offRoute','event.portalDepartureCaptureID,departure.id','XCTAssertNil(restored.expectedSessionID)']))
    check('old test source prefix unchanged',digest(t[:t.index('    func testOffRouteRetiresPlanThenFreshUniqueEndpointReplansWithoutChangingGoal')])=='f2d58b47c9e63568dfc32070de53fffa5dc678f0218970c7253a67e60e116792')

route_reassociation()

def active_hazards():
    names=['BlindCore/Sources/BlindCore/CurrentNavigationHazards.swift','BlindCore/Tests/BlindCoreTests/CurrentNavigationHazardsTests.swift','ios/BlindAssist/NavigationModel.swift','ios/BlindAssist/ConnectedJourneyRuntime.swift']
    s=read(names[0]);t=read(names[1]);app=read(names[2]);runtime=read(names[3])
    checks={
     'same_owner': 'guard self.sessionID == sessionID' in s,
     'chronology': 'guard capturedAt > highWater' in s,
     'no_future_poison': s.index('highWater = capturedAt') > s.index('guard FrameTimestampPolicy.isFresh'),
     'fresh_delivery': 'FrameTimestampPolicy.isFresh(capturedAt: latest.capturedAt, receivedAt: now)' in s,
     'unknown_support': 'fullFootprintSupportKnown: Bool { false }' in s,
     'no_physical_grant': 'authorizesPhysicalGuidance: Bool { false }' in s,
     'existing_detection_used': 'detection: phoneDetection, estimatedFloorHeight: detector.floorHeight' in app,
     'no_extra_sensor_copy': 'NativeARObservationAdapter.capture' not in app,
     'same_camera_session': 'currentNavigationHazards.begin(sessionID: worldSessionID)' in app,
     'loss_retires': 'currentNavigationHazards.invalidate()\n        withNativeLocalization' in app,
     'watchdog_rechecks': 'private func revalidateNativeLocalization(now: Double) {\n        _ = revalidateCurrentNavigationHazards(now: now)' in app,
     'before_route_request': app.index('guard revalidateCurrentNavigationHazards(now: now) else { return }',app.index('private func connectedJourneyBeacon')) < app.index('try $0.next(now: now)',app.index('private func connectedJourneyBeacon')),
     'both_delivery_callbacks': app.count('guard self.revalidateCurrentNavigationHazards(now: ProcessInfo.processInfo.systemUptime) else')==2,
     'intent_retained': 'public func retireCurrentObstacleEvidence() { retireOutput() }' in runtime,
     'eight_behavior_fixtures': t.count('    func test')==8,
    }
    for name,value in checks.items():check('active hazard '+name,value)

active_hazards()

def optional_grid():
    names=['BlindCore/Sources/BlindCore/NativeLocalGrid.swift','BlindCore/Tests/BlindCoreTests/NativeLocalGridTests.swift','ios/BlindAssist/NativeMapping.swift']
    s=read(names[0]);t=read(names[1]);app=read(names[2])
    checks={
     'exact_capture_identity': '$0.nodeID == node && $0.captureSequence == sequence && $0.capturedAt == capturedAt' in s,
     'delivery_age_and_future': 'now >= capturedAt, now - capturedAt <= 0.5' in s,
     'no_truncated_current': 'guard status != .truncated' in s and 'guard !tile.truncated' in s,
     'revision_and_geometry_fence': 'current.revision == evidence.revision && current.tile == evidence.tile' in s,
     'explicit_unknown_support': 'fullFootprintSupportKnown: Bool { false }' in s,
     'no_empty_clearance': 'absenceEstablishesFreeSpace: Bool { false }' in s,
     'no_invented_registration': 'registeredMetricFrameAvailable: Bool { false }' in s and 'originalARCaptureIdentityAvailable: Bool { false }' in s,
     'conditional_dependency_refusal': 'guard available else { return .unavailable(.dependencyAbsent) }' in app,
     'delivery_recheck_wired': 'localGridSnapshot?.isCurrent(evidence, now: now)' in app,
     'notification_retires_unknown': 'navigationEvidenceChanged?(.unavailable(available ? .inactive : .dependencyAbsent))' in app,
     'notification_supplies_view': 'navigationEvidenceChanged?(value.navigationEvidence(now: ProcessInfo.processInfo.systemUptime))' in app,
     'five_swift_cases': t.count('func testNavigationEvidence')==5,
     'existing_tests_retained': all(line in t for line in ['    func testConsumesOriginalThreeDimensionalGridWithoutCreatingHeightOrAuthority() throws {', '    func testWrongGenerationAndSupersededEventsCannotMutateNewOwner() {', '    func testCurrentGraphPosesCorrectRetainedTilesWithoutChangingOriginalCaptureAge() {', '    func testNewFrameResetsEventAndCaptureCountersButDelayedOldFrameCannotReturn() {', '    func testZeroGenerationCannotBecomeOwnerAndMapChangeResetsCaptureBinding() {', '    func testFrameRevisionAndMapChangeRetireEarlierCoordinates() {', '    func testMissingPoseIsEvictedEvenWhenPoseGraphWasTruncated() {', '    func testTruncationAndUnknownLayersStayExplicitNotConvertedToSupport() {', '    func testMalformedMatricesCountsAndOversizedInputsAreRejected() {', '    func testFreshPoseExpiresWithoutNewCallbackAndHistoryHasSeparateDeadline() {', '    func testDelayedGridIsUsefulHistoryButNotCurrentPoseAndFutureStampCannotPoisonRecovery() {', '    func testCaptureAssociationCannotBeReassignedOrReplayedAsNewerCameraPose() {', '    func testUnavailableAndUnassociatedEventsRetireLivePoseAndCannotCreateTiles() {', '    func testRepeatedCaptureKeepsOriginalARBindingWhileGraphPoseMayCorrect() {', '    func testTileAndPointCapsEvictDeterministicallyWithoutPartialInventedLayers() {']),
     'original_consumer_preserved': digest(s.split('public struct NativeLocalGridConsumer: Sendable {',1)[1].split('\n/// Current capture-only view',1)[0].rstrip()+'\n')=='21295e364e040d3638344f2d543d95f2a4f89f9706c886e074980afdce1fa690',
    }
    for name,value in checks.items():check('optional grid '+name,value)

optional_grid()

def delayed_start():
    s=read('ios/BlindAssist/NavigationModel.swift');block=s.split('private func spatialRouteOutputAllowed(',1)[1].split('    /// A selected connected owner',1)[0]
    checks={
     'actual_beacon_permission': 'self?.spatialRouteOutput.validateForStart(id) == true' in s,
     'actual_speech_permission': 'self?.spatialRouteOutput.validateSpeechStart(id, text: text) == true' in s,
     'same_session_typed_freshness': 'currentNavigationHazards.state(sessionID: hazardSession, now: now).permitsFurtherIndependentChecks' in block,
     'no_recursive_retirement': 'revalidateCurrentNavigationHazards' not in block and '.retire(' not in block,
     'goal_and_existing_owner_preserved': '$0.goal?.revision == ticket.goalRevision && $0.permits(ticket, now: now)' in block,
     'sensor_and_body_guards_preserved': 'detection.hazard == .observing' in block and 'fixedBodyMount' in block,
    }
    for name,value in checks.items():check('delayed start '+name,value)

delayed_start()

assert len(RESULTS)==70
print(json.dumps({'currentSourceControlsPassed':len(RESULTS),'checks':RESULTS,'sourceRoot':str(ROOT),'nativeExecuted':False},indent=2))
