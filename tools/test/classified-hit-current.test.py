#!/usr/bin/env python3
"""CURRENT source contracts only; no native execution or physical authority.
Reads actual caller-selected source root (or this repository). No historical
production-source fallback. Original method identities preserve existing tests.
"""
from pathlib import Path
import os,re,unittest,json
ROOT=Path(os.environ.get('BLIND_SOURCE_ROOT',Path(__file__).resolve().parents[2]))
PATHS={
 's':'BlindCore/Sources/BlindCore/NativeClassifiedHitEvidence.swift',
 'b':'ios/BlindAssist/NativeARObservationBridge.swift',
 'r':'ios/BlindAssist/ObservedSceneRuntime.swift',
 'n':'ios/BlindAssist/NavigationModel.swift',
 't':'ios/BlindAssistTests/ObservedSceneRuntimeTests.swift',
}
ORIGINAL_TEST_METHODS=['testRejectedFrameDisplaysEvidenceFailureNotTrailState', 'testNativeRuntimeFeedsActualAccumulatorAndRejectsAbandonedCompletion', 'testRuntimeRechecksClockAfterWorkerAndWatchdogExpiresPlan', 'testPreLossAndPreRestartFramesCannotSeedNewScene', 'testRejectedFutureTimestampDoesNotPoisonLaterCapture', 'testGoalAndBodyChangesFenceQueuedPlansWithoutRetiringScene', 'testQueuedObsoletePlanKeepsHistoryAndNextValidPlanStillRuns', 'testInvalidationAfterPlanningCompletesBeforeDeliveryRetainsBusySlot']
def check(source):
    s,b,r,n,t=(source[k] for k in ['s','b','r','n','t'])
    checks={
     'existing_record_validation': 'try record.validate()' in s,
     'actual_arkit_normal_only': 'record.producer == .arkit, record.tracking == .normal' in s,
     'finite_halfsecond_current': 'FrameTimestampPolicy.isFresh(capturedAt: record.capturedAt, receivedAt: now)' in s,
     'existing_transform_once': s.count('mesh.localToSessionWorld.applying(to: $0)')==1,
     'no_flattening': 'worldVertices: try mesh.vertices.map' in s,
     'all_indices_preserved': 'triangleIndices: mesh.triangleIndices' in s,
     'separate_three_roles': 'case floor, nonFloor, unknown' in s,
     'original_truncation_preserved': 'truncated: mesh.truncated' in s and 'originalTriangleCount: mesh.originalTriangleCount' in s,
     'no_support_authority': 'fullFootprintSupportKnown: Bool { false }' in s and 'authorizesPhysicalGuidance: Bool { false }' in s,
     'no_extra_capture': b.count('NativeARObservationAdapter.capture(frame, context: context)')==1,
     'rejected_extraction_delivered_unknown': 'catch { deliverHits(nil); throw error }' in b,
     'single_slot_coalescing': 'pending = (current.0, delivery); return nil' in s,
     'mailbox_epoch_guard': 'guard generation == delivery.generation else { return nil }' in s,
     'owner_rechecked_at_delivery': 'self.outcomeGeneration == value.generation' in b and 'self.sessionID == value.session' in b,
     'only_scalar_timestamp_in_mailbox': 'capturedAt: hitCapturedAt' in b,
     'actual_runtime_connection': 'bridge.onClassifiedHits' in n and '$0.offerClassifiedHits(evidence, session: session, capturedAt: capturedAt)' in n,
     'queued_plan_revision_fence': 'self.classifiedHits.revision == classifiedRevision' in r,
     'goal_and_stop_retirement': 'classifiedHits.retire(); self.intent = intent' in r and 'classifiedHits.stop(); session = nil' in r,
     'stale_hits_expire_independently': 'if classifiedHits.expire(now: now)' in r,
     'six_new_runtime_fixtures': t.count('func testClassified')==6,
     'exact_coordinate_frame': 'record.coordinateFrameID == "arkit-session:" + record.sessionID.uuidString' in s,
     'read_time_freshness': 'evidence.isFresh(session: session, now: clock())' in r,
     'actual_mailbox_fixture': 'testClassifiedMailboxCoalescesHeldDeliveryAndRejectsOldOwnerAfterLoss' in t and 'NativeClassifiedHitMailbox()' in b,
     'original_runtime_fixtures_retained': all(name in re.findall(r'func (test\w+)\(', t) for name in ORIGINAL_TEST_METHODS),
    }
    assert len(checks)==24
    assert all(checks.values()),[name for name,passed in checks.items() if not passed]
    return checks

class CurrentClassifiedHitContracts(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.source={key:(ROOT/path).read_text() for key,path in PATHS.items()}
    def test_actual_current_source_contracts(self):self.assertEqual(len(check(self.source)),24)
    def test_missing_frame_freshness_ownership_role_or_consumer_fences_are_rejected(self):
        mutations=[
          ('s','record.coordinateFrameID == "arkit-session:" + record.sessionID.uuidString','true'),
          ('s','case floor, nonFloor, unknown','case floor, nonFloor'),
          ('s','triangleIndices: mesh.triangleIndices','triangleIndices: []'),
          ('s','fullFootprintSupportKnown: Bool { false }','fullFootprintSupportKnown: Bool { true }'),
          ('s','guard generation == delivery.generation else { return nil }','guard true else { return nil }'),
          ('s','pending = (current.0, delivery); return nil','pending = (UUID(), delivery); return nil'),
          ('b','self.outcomeGeneration == value.generation','true'),
          ('r','self.classifiedHits.revision == classifiedRevision','true'),
          ('r','evidence.isFresh(session: session, now: clock())','true'),
          ('n','$0.offerClassifiedHits(evidence, session: session, capturedAt: capturedAt)','/* receipt not connected to consumer */'),
        ]
        for key,old,new in mutations:
            with self.subTest(mutation=old):
                self.assertIn(old,self.source[key])
                changed=dict(self.source);changed[key]=changed[key].replace(old,new)
                with self.assertRaises(AssertionError):check(changed)

if __name__=='__main__':unittest.main()
