import XCTest
@testable import BlindCore

final class CurrentNavigationHazardsTests: XCTestCase {
    private let owner = UUID()
    private func feed(_ value: inout CurrentNavigationHazards, time: Double = 1,
                      hazard: Hazard = .observing, tracked: Bool = true) -> CurrentNavigationHazards.State {
        value.consume(sessionID: owner, capturedAt: time, receivedAt: time,
            trackingNormal: tracked, detection: Detection(hazard, coverage: 0.8), estimatedFloorHeight: 0)
    }
    func testDefaultInactiveAndWrongOwnerNeverGrant() {
        var v = CurrentNavigationHazards()
        XCTAssertFalse(feed(&v).permitsFurtherIndependentChecks)
        v.begin(sessionID: owner)
        XCTAssertFalse(v.state(sessionID: UUID(), now: 1).permitsFurtherIndependentChecks)
    }
    func testObservingRetainsUnknownSupportAndExactCapture() {
        var v = CurrentNavigationHazards(); v.begin(sessionID: owner)
        guard case .observing(let r) = feed(&v) else { return XCTFail("missing observed result") }
        XCTAssertEqual(r.sessionID, owner); XCTAssertEqual(r.capturedAt, 1)
        XCTAssertFalse(r.fullFootprintSupportKnown); XCTAssertFalse(r.authorizesPhysicalGuidance)
        XCTAssertTrue(v.isCurrent(r, sessionID: owner, now: 1.5))
        XCTAssertFalse(v.isCurrent(r, sessionID: owner, now: 1.5001))
        XCTAssertFalse(v.isCurrent(r, sessionID: owner, now: 0.9))
    }
    func testObstacleDropOverheadAndUnknownAlwaysVeto() {
        for hazard in [Hazard.obstacle, .drop, .overhead, .uncertain, .calibrating, .needsCalibration, .stopped] {
            var v = CurrentNavigationHazards(); v.begin(sessionID: owner)
            XCTAssertFalse(feed(&v, hazard: hazard).permitsFurtherIndependentChecks)
        }
    }
    func testDuplicateAndDelayedFramesDoNotRefreshOrReplace() {
        var v = CurrentNavigationHazards(); v.begin(sessionID: owner)
        guard case .observing(let r) = feed(&v, time: 2) else { return XCTFail("missing result") }
        XCTAssertEqual(feed(&v, time: 1, hazard: .obstacle), .unknown(.outOfOrder))
        XCTAssertEqual(feed(&v, time: 2), .unknown(.outOfOrder))
        XCTAssertTrue(v.isCurrent(r, sessionID: owner, now: 2.2))
        XCTAssertFalse(v.isCurrent(r, sessionID: owner, now: 2.6))
    }
    func testMovedObjectNewHazardRetiresPriorReceiptAndLaterObservedIsNotClearance() {
        var v = CurrentNavigationHazards(); v.begin(sessionID: owner)
        guard case .observing(let old) = feed(&v) else { return XCTFail("missing result") }
        XCTAssertFalse(feed(&v, time: 1.1, hazard: .obstacle).permitsFurtherIndependentChecks)
        XCTAssertFalse(v.isCurrent(old, sessionID: owner, now: 1.1))
        guard case .observing(let new) = feed(&v, time: 1.2) else { return XCTFail("missing replacement") }
        XCTAssertFalse(new.authorizesPhysicalGuidance)
        XCTAssertFalse(v.isCurrent(old, sessionID: owner, now: 1.2))
    }
    func testLossAndStopRetireEvenWithoutNewSamples() {
        var v = CurrentNavigationHazards(); v.begin(sessionID: owner); _ = feed(&v)
        XCTAssertEqual(feed(&v, time: 1.1, tracked: false), .unknown(.trackingLost))
        XCTAssertFalse(v.state(sessionID: owner, now: 1.2).permitsFurtherIndependentChecks)
        _ = feed(&v, time: 1.3); v.invalidate()
        XCTAssertFalse(v.state(sessionID: owner, now: 1.3).permitsFurtherIndependentChecks)
        v.stop(); XCTAssertFalse(feed(&v, time: 1.4).permitsFurtherIndependentChecks)
    }
    func testInvalidFutureAndMissingFrameAgeDoNotReviveOldReceipt() {
        var v = CurrentNavigationHazards(); v.begin(sessionID: owner); _ = feed(&v)
        XCTAssertEqual(v.consume(sessionID: owner, capturedAt: 10, receivedAt: 1.1,
            trackingNormal: true, detection: Detection(.observing), estimatedFloorHeight: 0), .unknown(.stale))
        XCTAssertFalse(v.state(sessionID: owner, now: 1.1).permitsFurtherIndependentChecks)
        XCTAssertTrue(feed(&v, time: 1.2).permitsFurtherIndependentChecks)
        XCTAssertFalse(v.state(sessionID: owner, now: .nan).permitsFurtherIndependentChecks)
    }
    func testSessionReplacementCannotReuseOldFrames() {
        var v = CurrentNavigationHazards(); v.begin(sessionID: owner); _ = feed(&v)
        v.begin(sessionID: UUID())
        XCTAssertEqual(feed(&v, time: 2), .unknown(.wrongSession))
    }
}
