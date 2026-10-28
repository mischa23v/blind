import XCTest
@testable import BlindCore

final class SavedWorldFrameTests: XCTestCase {
    private let session = UUID()
    private var descriptor: SavedWorldFrame {
        SavedWorldFrame(placeID: "D0B535E0-F6D8-4CDD-AFF7-E9F65B05E758",
            revision: "96527D07-EB39-44EF-A75B-121456B22914",
            worldMapSHA256: String(repeating: "a", count: 64), roomCaptureSHA256: String(repeating: "b", count: 64),
            originAnchorID: "3EC26236-C99B-43A2-94F1-0A6F7738C527", capturedAt: Date(timeIntervalSince1970: 100))
    }
    private func observe(_ recovery: inout SavedWorldFrameRecovery, at time: Double,
                         tracking: SavedWorldFrameRecovery.Tracking = .normal,
                         anchor: Bool = true, mapped: Bool = true) -> SavedWorldFrame? {
        recovery.observe(sessionID: session, tracking: tracking, mappingAvailable: mapped,
                         originAnchorMatches: anchor, frameTime: time, now: time + 0.01)
    }
    private func recover(_ recovery: inout SavedWorldFrameRecovery) {
        recovery.begin(frame: descriptor, sessionID: session, now: 10)
        _ = observe(&recovery, at: 10, tracking: .relocalizing)
        _ = observe(&recovery, at: 10.1)
        _ = observe(&recovery, at: 10.2)
        _ = observe(&recovery, at: 10.3)
    }
    func testDescriptorRoundTripAndArtifactBinding() throws {
        XCTAssertTrue(descriptor.valid)
        let decoded = try JSONDecoder().decode(SavedWorldFrame.self, from: JSONEncoder().encode(descriptor))
        XCTAssertEqual(decoded, descriptor)
        XCTAssertTrue(decoded.frameID.contains(decoded.revision))
        XCTAssertTrue(decoded.matches(worldMapSHA256: String(repeating: "a", count: 64), roomCaptureSHA256: String(repeating: "b", count: 64)))
        XCTAssertFalse(decoded.matches(worldMapSHA256: String(repeating: "c", count: 64), roomCaptureSHA256: String(repeating: "b", count: 64)))
        XCTAssertFalse(decoded.matches(worldMapSHA256: String(repeating: "a", count: 64), roomCaptureSHA256: String(repeating: "c", count: 64)))
    }
    func testInvalidMetadataCannotBeginRecovery() {
        let bad = SavedWorldFrame(placeID: "bedroom", revision: descriptor.revision,
            worldMapSHA256: String(repeating: "A", count: 64), roomCaptureSHA256: descriptor.roomCaptureSHA256,
            originAnchorID: descriptor.originAnchorID, capturedAt: descriptor.capturedAt)
        XCTAssertFalse(bad.valid)
        var recovery = SavedWorldFrameRecovery()
        recovery.begin(frame: bad, sessionID: session, now: 10)
        XCTAssertNil(observe(&recovery, at: 10, tracking: .relocalizing))
        XCTAssertNil(observe(&recovery, at: 10.1))
    }
    func testOrdinaryNormalTrackingNeverEstablishesSavedFrame() {
        var recovery = SavedWorldFrameRecovery()
        recovery.begin(frame: descriptor, sessionID: session, now: 10)
        for i in 0..<40 { XCTAssertNil(observe(&recovery, at: 10 + Double(i) * 0.1)) }
        XCTAssertNil(recovery.current(sessionID: session, now: 14))
    }
    func testRelocalizationRequiresRestoredOriginAndFreshDistinctFrames() {
        var recovery = SavedWorldFrameRecovery()
        recovery.begin(frame: descriptor, sessionID: session, now: 10)
        XCTAssertNil(observe(&recovery, at: 10, tracking: .relocalizing))
        XCTAssertNil(observe(&recovery, at: 10.1, anchor: false))
        XCTAssertNil(observe(&recovery, at: 10.2, mapped: false))
        XCTAssertNil(observe(&recovery, at: 10.3))
        XCTAssertNil(observe(&recovery, at: 10.3)) // duplicate cannot complete a stability window
        XCTAssertNil(observe(&recovery, at: 10.4))
        XCTAssertEqual(observe(&recovery, at: 10.5), descriptor)
        XCTAssertEqual(recovery.current(sessionID: session, now: 10.6), descriptor)
        XCTAssertNil(recovery.current(sessionID: UUID(), now: 10.6))
        XCTAssertNil(recovery.current(sessionID: session, now: 11.1))
    }
    func testTrackingLossAndMissingAnchorWithdrawBindingUntilNewRelocalization() {
        for failure in [SavedWorldFrameRecovery.Tracking.unavailable, .normal] {
            var recovery = SavedWorldFrameRecovery(); recover(&recovery)
            XCTAssertNotNil(recovery.current(sessionID: session, now: 10.4))
            XCTAssertNil(observe(&recovery, at: 10.4, tracking: failure, anchor: false))
            for i in 5...9 { XCTAssertNil(observe(&recovery, at: 10 + Double(i) * 0.1)) }
            XCTAssertNil(recovery.current(sessionID: session, now: 10.95))
            _ = observe(&recovery, at: 11, tracking: .relocalizing)
            _ = observe(&recovery, at: 11.1); _ = observe(&recovery, at: 11.2)
            XCTAssertEqual(observe(&recovery, at: 11.3), descriptor)
        }
    }
    func testSessionChangeResetAndFrameGapCannotReuseBinding() {
        var recovery = SavedWorldFrameRecovery(); recover(&recovery)
        XCTAssertNil(observe(&recovery, at: 11)) // missed frames discard the old alignment evidence
        XCTAssertNil(recovery.current(sessionID: session, now: 11.01))
        recover(&recovery)
        XCTAssertNil(recovery.observe(sessionID: UUID(), tracking: .normal, mappingAvailable: true,
            originAnchorMatches: true, frameTime: 10.4, now: 10.41))
        XCTAssertNil(recovery.current(sessionID: session, now: 10.42))
        recover(&recovery); recovery.reset()
        XCTAssertNil(recovery.current(sessionID: session, now: 10.42))
    }
    func testStaleFutureAndTimedOutFramesCannotEstablishBinding() {
        for (frameTime, now) in [(10.0, 11.0), (12.0, 11.0), (41.0, 41.01), (.nan, 10.1)] {
            var recovery = SavedWorldFrameRecovery()
            recovery.begin(frame: descriptor, sessionID: session, now: 10)
            XCTAssertNil(recovery.observe(sessionID: session, tracking: .relocalizing, mappingAvailable: true,
                originAnchorMatches: true, frameTime: frameTime, now: now))
            XCTAssertNil(recovery.current(sessionID: session, now: now))
        }
    }
    func testPreBeginRelocalizingFrameCannotAuthorizeLaterNormalFrames() {
        var recovery = SavedWorldFrameRecovery()
        recovery.begin(frame: descriptor, sessionID: session, now: 10)
        // A queued callback can arrive after begin and still be younger than the age limit.
        XCTAssertNil(recovery.observe(sessionID: session, tracking: .relocalizing, mappingAvailable: true,
            originAnchorMatches: true, frameTime: 9.9, now: 10.01))
        for i in 1...5 { XCTAssertNil(observe(&recovery, at: 10 + Double(i) * 0.1)) }
        XCTAssertNil(recovery.current(sessionID: session, now: 10.51))
    }
    func testDelayedDeliveryDoesNotExtendCaptureTimeLease() {
        var recovery = SavedWorldFrameRecovery()
        recovery.begin(frame: descriptor, sessionID: session, now: 9.7)
        XCTAssertNil(observe(&recovery, at: 9.7, tracking: .relocalizing))
        XCTAssertNil(observe(&recovery, at: 9.8))
        XCTAssertNil(observe(&recovery, at: 9.9))
        // The third normal frame is still fresh when delivered, but only for 0.01 s more.
        XCTAssertEqual(recovery.observe(sessionID: session, tracking: .normal, mappingAvailable: true,
            originAnchorMatches: true, frameTime: 10, now: 10.49), descriptor)
        XCTAssertEqual(recovery.current(sessionID: session, now: 10.49), descriptor)
        XCTAssertEqual(recovery.current(sessionID: session, now: 10.5), descriptor)
        XCTAssertNil(recovery.current(sessionID: session, now: 10.5001))
        XCTAssertNil(recovery.current(sessionID: session, now: 10.98))
    }
    func testPreBeginCallbacksWithdrawPartialAndCompletedRecoverySequences() {
        for tracking in [SavedWorldFrameRecovery.Tracking.relocalizing, .normal, .unavailable] {
            for acceptedNormals in 0...SavedWorldFrameRecovery.minimumNormalFrames {
                var recovery = SavedWorldFrameRecovery()
                recovery.begin(frame: descriptor, sessionID: session, now: 10)
                _ = observe(&recovery, at: 10, tracking: .relocalizing)
                for index in 0..<acceptedNormals { _ = observe(&recovery, at: 10.1 + Double(index) * 0.1) }
                // Reject before the ordinary out-of-order check, even if evidence was already accepted.
                XCTAssertNil(recovery.observe(sessionID: session, tracking: tracking, mappingAvailable: true,
                    originAnchorMatches: true, frameTime: 9.99, now: 10.4))
                XCTAssertNil(recovery.current(sessionID: session, now: 10.4))
                for index in 0..<3 { XCTAssertNil(observe(&recovery, at: 10.41 + Double(index) * 0.01)) }
                // Invalidated attempts can recover only after a new begin and fresh evidence.
                recover(&recovery)
                XCTAssertEqual(recovery.current(sessionID: session, now: 10.4), descriptor)
            }
        }
    }
    func testCameraAssociationRequiresExactLatestAcceptedCaptureAndRealClock() throws {
        var recovery = SavedWorldFrameRecovery(); recover(&recovery)
        let value = try XCTUnwrap(recovery.cameraAssociation(sessionID: session, capturedAt: 10.3, now: 10.4))
        XCTAssertEqual(value.frame, descriptor)
        XCTAssertEqual(value.sessionID, session)
        XCTAssertEqual(value.sourceFrameID, "arkit-session:\(session.uuidString)")
        XCTAssertEqual(value.capturedAt, 10.3)
        XCTAssertEqual(value.reference, .camera)
        XCTAssertEqual(value.uncertainty, .unmeasured)
        XCTAssertFalse(value.permitsPhysicalGuidance)
        for time in [10.2, 10.31, .nan, .infinity] {
            XCTAssertNil(recovery.cameraAssociation(sessionID: session, capturedAt: time, now: 10.4))
        }
        XCTAssertNil(recovery.cameraAssociation(sessionID: UUID(), capturedAt: 10.3, now: 10.4))
        XCTAssertNil(recovery.cameraAssociation(sessionID: session, capturedAt: 10.3, now: 10.29))
        XCTAssertNil(recovery.cameraAssociation(sessionID: session, capturedAt: 10.3, now: 10.801))
        XCTAssertEqual(observe(&recovery, at: 10.4), descriptor)
        XCTAssertNil(recovery.cameraAssociation(sessionID: session, capturedAt: 10.3, now: 10.41))
        XCTAssertNotNil(recovery.cameraAssociation(sessionID: session, capturedAt: 10.4, now: 10.41))
    }
    func testCameraAssociationDoesNotRenewAfterDelayedCallback() {
        var recovery = SavedWorldFrameRecovery()
        recovery.begin(frame: descriptor, sessionID: session, now: 9.7)
        _ = observe(&recovery, at: 9.7, tracking: .relocalizing)
        _ = observe(&recovery, at: 9.8); _ = observe(&recovery, at: 9.9)
        XCTAssertEqual(recovery.observe(sessionID: session, tracking: .normal, mappingAvailable: true,
            originAnchorMatches: true, frameTime: 10, now: 10.49), descriptor)
        XCTAssertNotNil(recovery.cameraAssociation(sessionID: session, capturedAt: 10, now: 10.5))
        XCTAssertNil(recovery.cameraAssociation(sessionID: session, capturedAt: 10, now: 10.5001))
    }
    func testThrottledFinalRelocalizingCallbackCanSeedThreeNormalFrames() {
        var recovery = SavedWorldFrameRecovery()
        recovery.begin(frame: descriptor, sessionID: session, now: 10)
        // This callback never reaches the full frame/anchor-processing path.
        recovery.observeTrackingInterruption(sessionID: session, tracking: .relocalizing,
            frameTime: 10.01, now: 10.02)
        XCTAssertNil(recovery.cameraAssociation(sessionID: session, capturedAt: 10.01, now: 10.02))
        XCTAssertNil(observe(&recovery, at: 10.1)); XCTAssertNil(observe(&recovery, at: 10.2))
        XCTAssertEqual(observe(&recovery, at: 10.3), descriptor)
        XCTAssertNotNil(recovery.cameraAssociation(sessionID: session, capturedAt: 10.3, now: 10.31))
    }
    func testThrottledTrackingLossWithdrawsAssociationUntilFreshRelocalization() throws {
        var recovery = SavedWorldFrameRecovery(); recover(&recovery)
        let prior = try XCTUnwrap(recovery.cameraAssociation(sessionID: session, capturedAt: 10.3, now: 10.31))
        recovery.observeTrackingInterruption(sessionID: session, tracking: .unavailable,
            frameTime: 10.32, now: 10.33)
        XCTAssertNil(recovery.cameraAssociation(sessionID: session, capturedAt: 10.3, now: 10.33))
        for time in [10.4, 10.5, 10.6] { XCTAssertNil(observe(&recovery, at: time)) }
        recovery.observeTrackingInterruption(sessionID: session, tracking: .relocalizing,
            frameTime: 10.61, now: 10.62)
        XCTAssertNil(observe(&recovery, at: 10.7)); XCTAssertNil(observe(&recovery, at: 10.8))
        XCTAssertEqual(observe(&recovery, at: 10.9), descriptor)
        let next = try XCTUnwrap(recovery.cameraAssociation(sessionID: session, capturedAt: 10.9, now: 10.91))
        XCTAssertNotEqual(next.recoveryID, prior.recoveryID)
    }
    func testObsoleteInterruptionCannotWithdrawNewerNativeAssociation() throws {
        var recovery = SavedWorldFrameRecovery(); recover(&recovery)
        let prior = try XCTUnwrap(recovery.cameraAssociation(sessionID: session, capturedAt: 10.3, now: 10.31))
        for (owner, time) in [(UUID(), 10.4), (session, 9.99), (session, 10.2), (session, 10.3)] {
            recovery.observeTrackingInterruption(sessionID: owner, tracking: .unavailable,
                frameTime: time, now: 10.4)
            XCTAssertEqual(recovery.cameraAssociation(sessionID: session, capturedAt: 10.3, now: 10.4), prior)
        }
        // Normal tracking on the interruption-only seam cannot establish/renew it.
        recovery.observeTrackingInterruption(sessionID: session, tracking: .normal,
            frameTime: 10.4, now: 10.41)
        XCTAssertNil(recovery.cameraAssociation(sessionID: session, capturedAt: 10.4, now: 10.41))
        XCTAssertEqual(recovery.cameraAssociation(sessionID: session, capturedAt: 10.3, now: 10.41), prior)
    }
    func testAssociationResetAndNewBeginNeverReuseRecoveryEpoch() throws {
        var recovery = SavedWorldFrameRecovery(); recover(&recovery)
        let prior = try XCTUnwrap(recovery.cameraAssociation(sessionID: session, capturedAt: 10.3, now: 10.31))
        recovery.reset()
        XCTAssertNil(recovery.cameraAssociation(sessionID: session, capturedAt: 10.3, now: 10.32))
        recover(&recovery)
        let next = try XCTUnwrap(recovery.cameraAssociation(sessionID: session, capturedAt: 10.3, now: 10.32))
        XCTAssertNotEqual(next.recoveryID, prior.recoveryID)
        recovery.begin(frame: descriptor, sessionID: UUID(), now: 10.4)
        XCTAssertNil(recovery.cameraAssociation(sessionID: session, capturedAt: 10.3, now: 10.41))
    }
    func testUnverifiedNormalTrackingAndBadAnchorNeverMintAssociation() {
        var recovery = SavedWorldFrameRecovery()
        recovery.begin(frame: descriptor, sessionID: session, now: 10)
        for time in [10.1, 10.2, 10.3] { _ = observe(&recovery, at: time) }
        XCTAssertNil(recovery.cameraAssociation(sessionID: session, capturedAt: 10.3, now: 10.31))
        recovery.observeTrackingInterruption(sessionID: session, tracking: .relocalizing,
            frameTime: 10.4, now: 10.41)
        for time in [10.5, 10.6, 10.7] { _ = observe(&recovery, at: time, anchor: false) }
        XCTAssertNil(recovery.cameraAssociation(sessionID: session, capturedAt: 10.7, now: 10.71))
    }
    func testStaleOrFutureInterruptionFailsClosedWithoutMintingAssociation() {
        for (time, now) in [(10.4, 11.0), (10.5, 10.4), (10.4, Double.nan)] {
            var recovery = SavedWorldFrameRecovery(); recover(&recovery)
            recovery.observeTrackingInterruption(sessionID: session, tracking: .relocalizing,
                frameTime: time, now: now)
            XCTAssertNil(recovery.cameraAssociation(sessionID: session, capturedAt: 10.3, now: 10.4))
            for normal in [10.6, 10.7, 10.8] { XCTAssertNil(observe(&recovery, at: normal)) }
        }
    }
    func testFurnitureRecordIsDatedCategoryMeasurementNotPersonalIdentity() throws {
        let item = try XCTUnwrap(SavedFurnitureObservation(id: "scan-object-1", category: "chair",
            position: Point3(1, 0, -2), frame: descriptor))
        XCTAssertEqual(item.category, "chair"); XCTAssertEqual(item.observedAt, descriptor.capturedAt)
        XCTAssertEqual(item.frame.frameID, descriptor.frameID); XCTAssertEqual(item.source, "RoomPlan scan")
        XCTAssertNil(SavedFurnitureObservation(id: "x", category: "chair", position: Point3(.nan, 0, 0), frame: descriptor))
    }
}
