import XCTest
@testable import BlindCore

/// Synthetic scheduling/association checks, not face-model or device accuracy evidence.
final class FamiliarEncounterPolicyTests: XCTestCase {
    func testRequiresTwoDifferentFreshObservationsAndLatchesOnce() {
        var state = FamiliarEncounterPolicy(); let mom = UUID()
        XCTAssertEqual(state.observe([mom], detectedFaces: 1, now: 1), [])
        XCTAssertEqual(state.observe([mom], detectedFaces: 1, now: 2), [mom])
        state.markAnnounced(mom)
        for time in [3.0, 31, 300, 3000] { XCTAssertEqual(state.observe([mom], detectedFaces: 1, now: time), []) }
    }
    func testRejectedSpeechCanBeReproposedOnlyOnFreshMatchingEvidence() {
        var state = FamiliarEncounterPolicy(); let dad = UUID()
        _ = state.observe([dad], detectedFaces: 1, now: 1)
        XCTAssertEqual(state.observe([dad], detectedFaces: 1, now: 2), [dad])
        XCTAssertEqual(state.observe([], detectedFaces: 1, now: 3), [])
        XCTAssertEqual(state.observe([dad], detectedFaces: 1, now: 4), [dad])
    }
    func testUnknownFacesAndPartialCrowdDoNotResetSpokenLatch() {
        var state = FamiliarEncounterPolicy(); let mom = UUID()
        _ = state.observe([mom], detectedFaces: 8, now: 1)
        _ = state.observe([mom], detectedFaces: 8, now: 10); state.markAnnounced(mom)
        for time in 11...40 { _ = state.observe([], detectedFaces: 8, now: Double(time)) }
        XCTAssertEqual(state.observe([mom], detectedFaces: 8, now: 41), [])
        XCTAssertEqual(state.observe([mom], detectedFaces: 8, now: 42), [])
    }
    func testBriefOcclusionDoesNotResetAndTenSecondsContinuouslyEmptyDoes() {
        var state = FamiliarEncounterPolicy(); let mom = UUID()
        _ = state.observe([mom], detectedFaces: 1, now: 0)
        _ = state.observe([mom], detectedFaces: 1, now: 1); state.markAnnounced(mom)
        for time in 2...9 { _ = state.observe([], detectedFaces: 0, now: Double(time)) }
        XCTAssertEqual(state.observe([mom], detectedFaces: 1, now: 10), [])
        for time in 11...21 { _ = state.observe([], detectedFaces: 0, now: Double(time)) }
        XCTAssertEqual(state.observe([mom], detectedFaces: 1, now: 22), [])
        XCTAssertEqual(state.observe([mom], detectedFaces: 1, now: 23), [mom])
    }
    func testCameraGapIsNotEvidenceOfAbsence() {
        var state = FamiliarEncounterPolicy(); let mom = UUID()
        _ = state.observe([mom], detectedFaces: 1, now: 0)
        _ = state.observe([mom], detectedFaces: 1, now: 1); state.markAnnounced(mom)
        _ = state.observe([], detectedFaces: 0, now: 2)
        _ = state.observe([], detectedFaces: 0, now: 300)
        XCTAssertEqual(state.observe([mom], detectedFaces: 1, now: 301), [])
    }
    func testPoseInvalidationRequiresFreshEvidenceButDoesNotRepeatNotice() {
        var state = FamiliarEncounterPolicy(); let mom = UUID(), friend = UUID()
        _ = state.observe([mom, friend], detectedFaces: 2, now: 1)
        _ = state.observe([mom, friend], detectedFaces: 2, now: 2); state.markAnnounced(mom)
        state.invalidateEvidence()
        XCTAssertEqual(state.observe([mom, friend], detectedFaces: 2, now: 3), [])
        XCTAssertEqual(state.observe([mom, friend], detectedFaces: 2, now: 4), [friend])
    }
    func testSameFrameDuplicateIdentityAndClockReversalFailClosed() {
        var state = FamiliarEncounterPolicy(); let mom = UUID()
        XCTAssertEqual(state.observe([mom, mom], detectedFaces: 2, now: 1), [])
        _ = state.observe([mom], detectedFaces: 1, now: 2)
        XCTAssertEqual(state.observe([mom], detectedFaces: 1, now: 2), [])
        XCTAssertEqual(state.observe([mom], detectedFaces: 1, now: 3), [])
        XCTAssertEqual(state.observe([mom], detectedFaces: 0, now: 4), [])
        XCTAssertEqual(state.observe([mom], detectedFaces: 1, now: .nan), [])
    }
    func testEncounterRevisionChangesAfterMeaningfulEmptyView() {
        var state = FamiliarEncounterPolicy(); let mom = UUID()
        _ = state.observe([mom], detectedFaces: 1, now: 1)
        let first = state.encounterID(for: mom)
        for time in 2...12 { _ = state.observe([], detectedFaces: 0, now: Double(time)) }
        _ = state.observe([mom], detectedFaces: 1, now: 13)
        XCTAssertNotEqual(state.encounterID(for: mom), first)
    }
    func testEveryFaceKeepsOwnCandidateAndDuplicateNamesAbstainTogether() {
        let mom = UUID(), friend = UUID()
        XCTAssertEqual(FamiliarFaceBatchPolicy.uniqueCandidates([mom, nil, friend]), [mom, nil, friend])
        XCTAssertEqual(FamiliarFaceBatchPolicy.uniqueCandidates([mom, friend, mom]), [nil, friend, nil])
        XCTAssertTrue(FamiliarFaceBatchPolicy.uniqueCandidates(Array(repeating: mom, count: 33)).allSatisfy { $0 == nil })
    }
    func testUprightFrameBoundsRejectMalformedAndClippedFaces() {
        XCTAssertTrue(FamiliarFaceBatchPolicy.validBounds(x: 0.1, y: 0.2, width: 0.2, height: 0.3))
        for (x, y, w, h) in [(-0.1, 0.0, 0.2, 0.2), (0.9, 0.0, 0.2, 0.2),
                             (0.0, 0.9, 0.2, 0.2), (0.0, 0.0, 0.0, 0.2),
                             (Double.nan, 0.0, 0.2, 0.2)] {
            XCTAssertFalse(FamiliarFaceBatchPolicy.validBounds(x: x, y: y, width: w, height: h))
        }
    }
}
