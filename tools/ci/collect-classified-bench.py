#!/usr/bin/env python3
"""Verify exact macOS XCTest fixtures; Swift Testing's separate zero suite is not evidence."""
import argparse, json, re
from collections import Counter
from pathlib import Path

def require(value, message):
    if not value:
        raise ValueError(message)

EXPECTED_CASES = ['testActualDependencyRouteAndExactlyOneTransformRemainNonphysical', 'testForeignGenerationCannotInvokeBorrowedCapture', 'testReplacementRetiresBeforeCopyAndExactRemovalWithholdsIncompletePreview', 'testMalformedReplacementCannotExposeRetainedOldFloorPreview', 'testSingleCopyBackpressureDoesNotInvokeSecondCaptureAndRetainsGap', 'testStopDuringCaptureFencesLateCompletionAndDoesNotReleaseReservationEarly', 'testCallbackBudgetBoundsSumWorkWithFastDecoderAndRotatesOmissions', 'testBlockedSynchronousCapturePreventsDiscardAcknowledgement', 'testClassifiedConsumerNeverPromotesMissingUnknownOrNonFloorPlane', 'testNonFloorGeometryStillBlocksAndExactRemovalCannotDeclareClearance', 'testUnclassifiedReplacementAndLaterFloorCannotEraseGapInSameOwner', 'testNewTerminalOwnerCannotReusePriorGenerationOrGeometry', 'testQueuedFloorThenRefusedRemovalCannotExposeStaleFloorPreview', 'testRotatedTranslatedMetreGeometryUsesExactlyOneRigidTransform', 'testScaleAndReflectionReplacementCannotExposePriorFloor', 'testStrictSelectionPreservesInsideAndVerticalEndpointReceipts', 'testStrictSelectionRejectsGoalAndStartProjectionWithTypedReceipts', 'testDebugIngressStrictPolicySurvivesResetWithoutChangingLegacyDefault']

SNAPSHOT_CASES = ['testSnapshotPreservesLocalValuesTransformRolesAndUnknownPhysicalAuthority', 'testStableAnchorOrderReadOnlyRevisionAndExactOwnerIdentity', 'testNoOwnerReturnsUnavailableNotSyntheticEmptyRoom', 'testWholeSnapshotBudgetsAndInvalidLimitsNeverReturnPrefixes', 'testRemovalRetiresSnapshotKeepsTombstoneAndUnknownNotFreeSpace', 'testMalformedReplacementRetainsOnlyExplicitlyIncompleteDiagnosticHistory', 'testProjectedOverflowCannotPairNewLedgerWithOldRetainedTile', 'testQueuedDeliveryRetainsReservationAndDiscardUntilPayloadReleased', 'testInvalidateAndResetRetireExactSnapshot', 'testQueuedSnapshotCannotDeliverAfterNewerUpdate', 'testOnlyOneOutstandingSnapshotAndDiscardWaitsForAdmittedWorker', 'testLateFailureGapRetiresPreviouslyCompleteSnapshotWithoutRevisionChange', 'testActualIngressAndBenchForwardOwnedGeometryAndKeepMissingClassesUnknown', 'testIngressResetRetiresSnapshotAndCannotExposePreviousEpochGeometry', 'testIngressOutstandingDecodeRefusesSnapshotWithoutCopyingAgain', 'testForeignBenchGenerationCannotRequestSnapshot']

RECOVERY_CASES = ['test01LatestOwnedReplacementRecoversOnlyLogicalDelivery', 'test02ReplacementCannotClearAnotherAnchorsOmission', 'test03BusyCopyRequiresNewerObservationAndDoesNotInvokeRejectedCapture', 'test04PendingLatestRevisionQuarantinesOldTileAndLateCompletion', 'test05RefusedRemovalImmediatelyWithholdsAnotherRoutableFloor', 'test06MissingClassesReplaceOldFloorWithoutPromotingNonfloor', 'test07RejectedProjectedGeometryRecoversOnlyAfterValidNewerInstall', 'test08GoodReplacementCannotClearGlobalClockTrackingOrContextFailure', 'test09MetadataCapPreservesTombstonesAndCallerRecordLimit', 'test10QueuedQueryAndSnapshotCannotPublishBeforeNewerUpdate', 'test11LifecycleABAAndSameRevisionLateCommitCannotResolveFailures', 'test12AllRemovalsRemainUnknownEvenAfterSameUUIDReappears', 'test13MailboxRefusalNeedsExactNewerReplacementNotUnrelatedDrain', 'test14SnapshotBudgetsAndDeliveryDrainRemainBoundedAfterRecovery']

HELPER_CASES = ['testStableOmittedAnchorReacquiredFromLaterFrameOnlyOnce', 'testAbsentAnchorRemainsPendingUntilTimeoutNeverRemoved', 'testAdmissionBackpressureRetriesAtMostThreeAndFairlyRotates', 'testMaximumRequestIssuesExactly192AttemptsThenStops', 'testWholeRequestOverflowDuplicatesAndPresentFrameOverflowRefused', 'testRepeatedRequestCancellationAndWrongAdmissionDoNotOverlap', 'testSchedulerClockFailuresAreTerminalWithinRequest', 'testStartupGraceIsNotCurrentButCanBecomeHealthy', 'testStartupExpiryAndFrameExpiryCannotRevive', 'testTrackingLossAndStopAreTerminalAndDoNotChangeReason', 'testLeaseRejectsDuplicateFutureNonfiniteAndBackwardsCapture', 'testIndependentWatchdogRetiresWhileProducerDoesNoWork', 'testActivationBoundaryAcceptsNewRunFrameBeforeDelayedProducerBegins', 'testLeaseBackwardsAndNonfiniteClockAreTerminal']

def collect(source, log, command, before, after, snapshot_source, recovery_source, helper_source):
    expected=re.findall(r'^\s*func (test\w+)\(', source, re.M)
    require(expected==EXPECTED_CASES and len(set(expected))==18, 'expected exact reviewed 18-fixture XCTest source')
    snapshot_expected=re.findall(r'^\s*func (test\w+)\(', snapshot_source, re.M)
    require(snapshot_expected==SNAPSHOT_CASES and len(set(snapshot_expected))==16, 'expected exact reviewed16 snapshot XCTest source')
    recovery_expected=re.findall(r'^\s*func (test\w+)\(', recovery_source, re.M)
    require(recovery_expected==RECOVERY_CASES and len(set(recovery_expected))==14, 'expected exact reviewed14 recovery XCTest source')
    helper_expected=re.findall(r'^\s*func (test\w+)\(', helper_source, re.M)
    require(helper_expected==HELPER_CASES and len(set(helper_expected))==14, 'expected exact reviewed14 helper XCTest source')
    classes={'LiveMeshClassifiedBenchTests.LiveMeshBenchIngressTests':EXPECTED_CASES, 'LiveMeshClassifiedBenchTests.SourceGeometrySnapshotTests':SNAPSHOT_CASES, 'LiveMeshClassifiedBenchTests.AnchorDeliveryRecoveryTests':RECOVERY_CASES, 'LiveMeshClassifiedBenchTests.MeshBenchHelperTests':HELPER_CASES}
    case_lines=[line for line in log.splitlines() if line.startswith('Test Case ')]
    pattern=r"Test Case '-\[([^ ]+) (test\w+)\]' (started|passed|failed|skipped)(?:\.| \([^\n]*\)\.)"
    observed={}
    for line in case_lines:
        match=re.fullmatch(pattern,line)
        require(match is not None, 'unrecognized XCTest case record')
        cls,name,status=match.groups()
        require(cls in classes and name in classes[cls], 'unexpected XCTest class or case')
        observed.setdefault((cls,name),[]).append(status)
    require(observed=={(cls,name):['started','passed'] for cls,names in classes.items() for name in names}, 'missing, extra, duplicate, failed or skipped XCTest cases')
    suite_lines=[line for line in log.splitlines() if line.startswith('Test Suite ')]
    suites={}
    for line in suite_lines:
        match=re.fullmatch(r"Test Suite '([^']+)' (started|passed|failed) at .+\.",line)
        require(match is not None, 'unrecognized XCTest suite record')
        name,status=match.groups();suites.setdefault(name,[]).append(status)
    require(suites=={name:['started','passed'] for name in ['All tests','LiveMeshClassifiedBenchPackageTests.xctest','LiveMeshBenchIngressTests','SourceGeometrySnapshotTests','AnchorDeliveryRecoveryTests','MeshBenchHelperTests']}, 'missing, extra, contradictory or failed XCTest suite')
    totals=re.findall(r'Executed (\d+) tests?, with (\d+) failures? \((\d+) unexpected\)',log)
    require(Counter(totals)==Counter({('18','0','0'):1,('16','0','0'):1,('14','0','0'):2,('62','0','0'):2}), 'missing or contradictory XCTest totals')
    # Bind each total to its immediately preceding passed suite; swapped counts fail.
    expected_totals={'All tests':62,'LiveMeshClassifiedBenchPackageTests.xctest':62,'LiveMeshBenchIngressTests':18,'SourceGeometrySnapshotTests':16,'AnchorDeliveryRecoveryTests':14,'MeshBenchHelperTests':14}
    suite_totals={}; last_passed=None
    for line in log.splitlines():
        matched=re.fullmatch(r"Test Suite '([^']+)' passed at .+\.",line)
        if matched:last_passed=matched.group(1)
        total=re.fullmatch(r'\s*Executed (\d+) tests?, with (\d+) failures? \((\d+) unexpected\).*',line)
        if total:
            require(last_passed in expected_totals and last_passed not in suite_totals, 'unbound or duplicate suite total')
            require(tuple(map(int,total.groups()))==(expected_totals[last_passed],0,0), 'wrong suite-bound total')
            suite_totals[last_passed]=int(total.group(1));last_passed=None
    require(suite_totals==expected_totals, 'missing suite-bound totals')
    require(command.get('swift_test_exit_code')==0 and command.get('log_writer_exit_code')==0, 'command failed')
    require(before==after=='', 'source not clean before and after test')
    return {'status':'passed','scope':'62 macOS synthetic XCTest fixtures, not live sensing','executed':62,'passed':62,'failed':0,'ios_session_fixtures_excluded':5,'cases':[{'class':cls,'name':n,'status':'passed'} for cls,names in classes.items() for n in names],'swift_testing_zero_suite_not_counted':True,'source_clean_before_and_after':True}

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('source',type=Path);parser.add_argument('artifact_dir',type=Path);args=parser.parse_args();d=args.artifact_dir
    result=collect(args.source.read_text(),(d/'swift-test.log').read_text(),json.loads((d/'result.json').read_text()),(d/'source-before.txt').read_text(),(d/'source-after.txt').read_text(),(args.source.parent/'SourceGeometrySnapshotTests.swift').read_text(),(args.source.parent/'AnchorDeliveryRecoveryTests.swift').read_text(),(args.source.parent/'MeshBenchHelperTests.swift').read_text())
    (d/'xctest-results.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
