import Foundation
import XCTest
@testable import LiveMeshClassifiedBench

/// Pure ownership/freshness schedules. No ARSession is created or activated.
final class MeshBenchHelperTests: XCTestCase {
    private final class Clock {
        private let lock = NSLock()
        private var value: Double
        init(_ value: Double) { self.value = value }
        func read() -> Double { lock.lock(); defer { lock.unlock() }; return value }
        func set(_ value: Double) { lock.lock(); self.value = value; lock.unlock() }
    }
    func testStableOmittedAnchorReacquiredFromLaterFrameOnlyOnce() throws {
        let a = UUID(), b = UUID()
        var request = MeshBenchReacquisition()
        XCTAssertTrue(request.request(anchorIDs: [a,b], frameCapturedAt: 1, now: 1))
        XCTAssertNil(request.next(presentIDs: [a,b], frameCapturedAt: 1, now: 1))
        XCTAssertEqual(request.next(presentIDs: [a,b], frameCapturedAt: 1.01, now: 1.01), a)
        request.recordAdmission(anchorID: a, accepted: true, now: 1.01)
        XCTAssertNil(request.next(presentIDs: [a,b], frameCapturedAt: 1.01, now: 1.01))
        XCTAssertEqual(request.next(presentIDs: [a,b], frameCapturedAt: 1.02, now: 1.02), b)
        request.recordAdmission(anchorID: b, accepted: true, now: 1.02)
        let receipt = request.receipt(now: 1.02)
        XCTAssertEqual(receipt.state, .finished)
        XCTAssertEqual(receipt.totalAttempts, 2)
        XCTAssertEqual(receipt.admittedIDs, [a,b])
        XCTAssertTrue(receipt.pendingIDs.isEmpty)
        XCTAssertFalse(receipt.actualWorldCoverageKnown)
        XCTAssertFalse(receipt.authorizesPhysicalGuidance)
        XCTAssertNil(receipt.meshCapturedAt) // admission is not capture or installation proof
        XCTAssertNil(request.next(presentIDs: [a,b], frameCapturedAt: 1.03, now: 1.03))
    }
    func testAbsentAnchorRemainsPendingUntilTimeoutNeverRemoved() {
        let a = UUID(), b = UUID()
        var request = MeshBenchReacquisition()
        XCTAssertTrue(request.request(anchorIDs: [a,b], frameCapturedAt: 1, now: 1))
        XCTAssertEqual(request.next(presentIDs: [a], frameCapturedAt: 1.1, now: 1.1), a)
        request.recordAdmission(anchorID: a, accepted: true, now: 1.1)
        XCTAssertNil(request.next(presentIDs: [a], frameCapturedAt: 2, now: 2))
        var receipt = request.receipt(now: 2)
        XCTAssertEqual(receipt.pendingIDs, [b])
        XCTAssertEqual(receipt.anchors.last?.reason, .absentFromLatestFrame)
        XCTAssertEqual(receipt.anchors.last?.attempts, 0)
        receipt = request.receipt(now: 9)
        XCTAssertEqual(receipt.state, .timedOut)
        XCTAssertEqual(receipt.pendingIDs, [b])
        XCTAssertEqual(receipt.admittedIDs, [a])
        XCTAssertTrue(request.request(anchorIDs: [b], frameCapturedAt: 10, now: 10))
        XCTAssertEqual(request.next(presentIDs: [b], frameCapturedAt: 10.1, now: 10.1), b)
        let interrupted = request.receipt(now: 18)
        XCTAssertEqual(interrupted.state, .timedOut)
        XCTAssertEqual(interrupted.anchors.first?.reason, .admissionUnconfirmed)
        request.recordAdmission(anchorID: b, accepted: true, now: 18)
        XCTAssertTrue(request.receipt(now: 18).admittedIDs.isEmpty)
    }
    func testAdmissionBackpressureRetriesAtMostThreeAndFairlyRotates() {
        let a = UUID(), b = UUID()
        var request = MeshBenchReacquisition()
        XCTAssertTrue(request.request(anchorIDs: [a,b], frameCapturedAt: 1, now: 1))
        for (index, id) in [a,b,a,b,a,b].enumerated() {
            let now = 1 + Double(index + 1) * 0.01
            XCTAssertEqual(request.next(presentIDs: [a,b], frameCapturedAt: now, now: now), id)
            request.recordAdmission(anchorID: id, accepted: false, now: now)
        }
        let receipt = request.receipt(now: 1.07)
        XCTAssertEqual(receipt.state, .finished)
        XCTAssertEqual(receipt.totalAttempts, 6)
        XCTAssertEqual(receipt.pendingIDs, [a,b])
        XCTAssertTrue(receipt.anchors.allSatisfy { $0.attempts == 3 && $0.reason == .attemptsExhausted })
        XCTAssertNil(request.next(presentIDs: [a,b], frameCapturedAt: 1.08, now: 1.08))
    }
    func testMaximumRequestIssuesExactly192AttemptsThenStops() {
        let ids = (0..<64).map { _ in UUID() }
        var request = MeshBenchReacquisition()
        XCTAssertTrue(request.request(anchorIDs: ids, frameCapturedAt: 1, now: 1))
        for index in 0..<192 {
            let now = 1 + Double(index + 1) * 0.01
            let id = request.next(presentIDs: Set(ids), frameCapturedAt: now, now: now)
            XCTAssertEqual(id, ids[index % ids.count])
            if let id { request.recordAdmission(anchorID: id, accepted: false, now: now) }
        }
        let receipt = request.receipt(now: 3)
        XCTAssertEqual(receipt.state, .finished)
        XCTAssertEqual(receipt.totalAttempts, 192)
        XCTAssertEqual(receipt.anchors.count, 64)
        XCTAssertTrue(receipt.anchors.allSatisfy { $0.attempts == 3 })
    }
    func testWholeRequestOverflowDuplicatesAndPresentFrameOverflowRefused() {
        let id = UUID()
        var request = MeshBenchReacquisition()
        XCTAssertFalse(request.request(anchorIDs: (0..<65).map { _ in UUID() }, frameCapturedAt: 1, now: 1))
        XCTAssertEqual(request.receipt(now: 1).state, .rejected)
        XCTAssertEqual(request.receipt(now: 1).inputAnchorCount, 65)
        XCTAssertEqual(request.receipt(now: 1).rejectionReason, .tooManyAnchors)
        XCTAssertEqual(request.receipt(now: 1).rejectedCount, 65)
        XCTAssertTrue(request.receipt(now: 1).anchors.isEmpty)
        XCTAssertFalse(request.request(anchorIDs: [id,id], frameCapturedAt: 1, now: 1))
        XCTAssertEqual(request.receipt(now: 1).rejectionReason, .duplicateAnchorIdentity)
        XCTAssertTrue(request.receipt(now: 1).anchors.isEmpty)
        XCTAssertTrue(request.request(anchorIDs: [id], frameCapturedAt: 1, now: 1))
        XCTAssertNil(request.next(presentIDs: Set((0..<129).map { _ in UUID() }), frameCapturedAt: 1.1, now: 1.1))
        XCTAssertEqual(request.receipt(now: 1.1).state, .rejected)
        XCTAssertEqual(request.receipt(now: 1.1).rejectionReason, .tooManyFrameAnchors)
        XCTAssertEqual(request.receipt(now: 1.1).rejectedCount, 129)
        XCTAssertEqual(request.receipt(now: 1.1).pendingIDs, [id])
    }
    func testRepeatedRequestCancellationAndWrongAdmissionDoNotOverlap() {
        let a = UUID(), b = UUID()
        var request = MeshBenchReacquisition()
        XCTAssertTrue(request.request(anchorIDs: [a], frameCapturedAt: 1, now: 1))
        XCTAssertFalse(request.request(anchorIDs: [b], frameCapturedAt: 1.1, now: 1.1))
        XCTAssertEqual(request.receipt(now: 1.1).pendingIDs, [a])
        request.cancel()
        XCTAssertEqual(request.receipt(now: 1.2).state, .cancelled)
        XCTAssertNil(request.next(presentIDs: [a], frameCapturedAt: 1.2, now: 1.2))
        XCTAssertTrue(request.request(anchorIDs: [b], frameCapturedAt: 2, now: 2))
        XCTAssertEqual(request.next(presentIDs: [b], frameCapturedAt: 2.1, now: 2.1), b)
        request.recordAdmission(anchorID: a, accepted: true, now: 2.1)
        XCTAssertEqual(request.receipt(now: 2.1).state, .invalidSequence)
        XCTAssertEqual(request.receipt(now: 2.1).pendingIDs, [b])
    }
    func testSchedulerClockFailuresAreTerminalWithinRequest() {
        let id = UUID()
        for (capture, now) in [(Double.nan, 1.0), (1.0, Double.infinity), (2.0, 1.0),
                               (1.0, 1.6), (-1.0, 0.0), (Double.greatestFiniteMagnitude, Double.greatestFiniteMagnitude)] {
            var request = MeshBenchReacquisition()
            XCTAssertFalse(request.request(anchorIDs: [id], frameCapturedAt: capture, now: now))
            XCTAssertEqual(request.receipt(now: 2).state, .invalidClock)
        }
        var request = MeshBenchReacquisition()
        XCTAssertTrue(request.request(anchorIDs: [id], frameCapturedAt: 1, now: 1))
        XCTAssertNil(request.next(presentIDs: [id], frameCapturedAt: 0.9, now: 1.1))
        XCTAssertEqual(request.receipt(now: 1.1).state, .invalidClock)
        XCTAssertNil(request.next(presentIDs: [id], frameCapturedAt: 1.2, now: 1.2))
    }
    func testStartupGraceIsNotCurrentButCanBecomeHealthy() {
        let clock = Clock(1)
        // A separate deterministic clock exercises the actual lock-protected state.
        let tracked = MeshBenchFrameLease(clock: clock.read)
        XCTAssertFalse(tracked.isCurrent())
        XCTAssertFalse(tracked.isRetired())
        XCTAssertFalse(tracked.claimRetirementNotification())
        XCTAssertTrue(tracked.begin())
        XCTAssertFalse(tracked.begin())
        clock.set(2)
        XCTAssertTrue(tracked.observe(capturedAt: 2, normal: false))
        XCTAssertFalse(tracked.isCurrent())
        XCTAssertFalse(tracked.isRetired())
        XCTAssertEqual(tracked.receipt().phase, .awaitingNormalTracking)
        clock.set(3)
        XCTAssertTrue(tracked.observe(capturedAt: 3, normal: true))
        XCTAssertTrue(tracked.isCurrent())
        XCTAssertNil(tracked.receipt().meshCapturedAt)
        XCTAssertFalse(tracked.receipt().authorizesPhysicalGuidance)
        XCTAssertFalse(tracked.receipt().actualWorldCoverageKnown)
    }
    func testStartupExpiryAndFrameExpiryCannotRevive() {
        let clock = Clock(1)
        let startup = MeshBenchFrameLease(clock: clock.read)
        XCTAssertTrue(startup.begin())
        clock.set(11)
        XCTAssertFalse(startup.isRetired())
        clock.set(11.001)
        XCTAssertTrue(startup.isRetired())
        XCTAssertEqual(startup.receipt().retirementReason, .startupExpired)
        XCTAssertFalse(startup.observe(capturedAt: 11.001, normal: true))
        XCTAssertFalse(startup.begin())
        let healthy = MeshBenchFrameLease(clock: clock.read)
        XCTAssertTrue(healthy.begin())
        XCTAssertTrue(healthy.observe(capturedAt: 11.001, normal: true))
        clock.set(11.501)
        XCTAssertTrue(healthy.isCurrent())
        clock.set(11.502)
        XCTAssertTrue(healthy.isRetired())
        XCTAssertEqual(healthy.receipt().retirementReason, .frameExpired)
        XCTAssertFalse(healthy.observe(capturedAt: 11.502, normal: true))
    }
    func testTrackingLossAndStopAreTerminalAndDoNotChangeReason() {
        let clock = Clock(1), tracked = MeshBenchFrameLease(clock: { 1 })
        let lease = MeshBenchFrameLease(clock: clock.read)
        XCTAssertTrue(lease.begin())
        XCTAssertTrue(lease.observe(capturedAt: 1, normal: true))
        clock.set(1.1)
        XCTAssertFalse(lease.observe(capturedAt: 1.1, normal: false))
        XCTAssertTrue(lease.isRetired())
        XCTAssertEqual(lease.receipt().retirementReason, .trackingLost)
        XCTAssertTrue(lease.claimRetirementNotification())
        XCTAssertFalse(lease.claimRetirementNotification())
        lease.stop()
        XCTAssertEqual(lease.receipt().retirementReason, .trackingLost)
        XCTAssertFalse(lease.claimRetirementNotification())
        XCTAssertFalse(lease.observe(capturedAt: 1.1, normal: true))
        tracked.stop()
        XCTAssertTrue(tracked.isRetired())
        XCTAssertFalse(tracked.begin())
        XCTAssertEqual(tracked.receipt().retirementReason, .stopped)
        XCTAssertTrue(tracked.claimRetirementNotification())
        XCTAssertFalse(tracked.claimRetirementNotification())
    }
    func testLeaseRejectsDuplicateFutureNonfiniteAndBackwardsCapture() {
        for badCapture in [1.0, 0.9, 1.2, Double.nan, Double.infinity] {
            let clock = Clock(1)
            let tracked = MeshBenchFrameLease(clock: clock.read)
            XCTAssertTrue(tracked.begin())
            XCTAssertTrue(tracked.observe(capturedAt: 1, normal: true))
            clock.set(1.1)
            XCTAssertFalse(tracked.observe(capturedAt: badCapture, normal: true))
            XCTAssertEqual(tracked.receipt().retirementReason, .invalidCapture)
        }
    }
    func testIndependentWatchdogRetiresWhileProducerDoesNoWork() {
        let clock = Clock(1)
        let lease = MeshBenchFrameLease(clock: clock.read)
        XCTAssertTrue(lease.begin())
        XCTAssertTrue(lease.observe(capturedAt: 1, normal: true))
        let checked = expectation(description: "independent watchdog, no producer queue turn")
        clock.set(2)
        DispatchQueue(label: "bench.helper.watchdog-test").async {
            XCTAssertTrue(lease.isRetired())
            XCTAssertTrue(lease.claimRetirementNotification())
            XCTAssertFalse(lease.claimRetirementNotification())
            checked.fulfill()
        }
        wait(for: [checked], timeout: 2)
        XCTAssertFalse(lease.claimRetirementNotification())
        XCTAssertFalse(lease.isCurrent())
        XCTAssertEqual(lease.receipt().retirementReason, .frameExpired)
    }
    func testActivationBoundaryAcceptsNewRunFrameBeforeDelayedProducerBegins() {
        // The main owner establishes the lease before session.run. A later
        // producer turn must not move that lower bound past a new-run capture.
        let clock = Clock(1)
        let lease = MeshBenchFrameLease(clock: clock.read)
        XCTAssertTrue(lease.begin())
        clock.set(1.2)
        XCTAssertTrue(lease.observe(capturedAt: 1.1, normal: true))
        XCTAssertTrue(lease.isCurrent())
        XCTAssertEqual(lease.receipt().beganAt, 1)
        XCTAssertEqual(lease.receipt().frameCapturedAt, 1.1)
        XCTAssertEqual(lease.receipt().frameReceivedAt, 1.2)

        let olderClock = Clock(1)
        let older = MeshBenchFrameLease(clock: olderClock.read)
        XCTAssertTrue(older.begin())
        olderClock.set(1.2)
        XCTAssertFalse(older.observe(capturedAt: 0.99, normal: true))
        XCTAssertTrue(older.isRetired())
        XCTAssertEqual(older.receipt().retirementReason, .invalidCapture)
        XCTAssertFalse(older.observe(capturedAt: 1.1, normal: true))
    }
    func testLeaseBackwardsAndNonfiniteClockAreTerminal() {
        for now in [0.9, Double.nan, Double.infinity] {
            let clock = Clock(1)
            let lease = MeshBenchFrameLease(clock: clock.read)
            XCTAssertTrue(lease.begin())
            XCTAssertTrue(lease.observe(capturedAt: 1, normal: true))
            clock.set(now)
            XCTAssertTrue(lease.isRetired())
            XCTAssertEqual(lease.receipt().retirementReason, .invalidClock)
        }
        for now in [-Double.infinity, Double.greatestFiniteMagnitude] {
            let invalid = MeshBenchFrameLease(clock: { now })
            XCTAssertFalse(invalid.begin())
            XCTAssertTrue(invalid.isRetired())
            XCTAssertEqual(invalid.receipt().retirementReason, .invalidClock)
        }
    }
}
