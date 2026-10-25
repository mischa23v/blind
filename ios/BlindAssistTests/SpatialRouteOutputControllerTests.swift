import Foundation
import XCTest
@testable import BlindCore
#if canImport(NativeSpatialAdapter)
@testable import NativeSpatialAdapter
#else
@testable import BlindAssist
#endif

/// Executes the exact Foundation controller used by NavigationModel. Sink closures
/// are recording fakes, not AVFoundation/VoiceOver playback or physical sensors.
final class SpatialRouteOutputControllerTests: XCTestCase {
    typealias F = SpatialIntegrationFixture
    final class Harness {
        var owner: SpatialRouteOwner
        var support: SpatialFloorSupport
        var now = 10.0
        var goal: String
        var hazard = false
        var speechID: UUID?
        var beacon = SpatialRouteBeaconOwnership()
        var stoppedSpeech: [UUID] = []
        var stoppedBeacon: [UUID] = []
        var speechStarts = 0
        var beaconStarts = 0
        let controller = SpatialRouteOutputController()
        init() throws {
            (owner, support) = try F.prepared()
            goal = try XCTUnwrap(owner.goalRevision).uuidString
            controller.permits = { [weak self] ticket, goal in
                guard let self else { return false }
                return !self.hazard && goal == self.goal && self.owner.permits(ticket, now: self.now)
            }
            controller.stopSpeech = { [weak self] id in
                guard let self else { return }
                self.stoppedSpeech.append(id)
                if self.speechID == id { self.speechID = nil }
            }
            controller.stopBeacon = { [weak self] id in
                guard let self else { return }
                if self.beacon.retire(id) { self.stoppedBeacon.append(id) }
            }
        }
        func ticket() throws -> SpatialRouteTicket { try owner.next(support: support, now: now) }
        @discardableResult func deliver(_ ticket: SpatialRouteTicket) -> Bool {
            controller.deliver(ticket: ticket, goalRevision: goal,
                speech: { id in self.speechID = id; self.speechStarts += 1; return true },
                beacon: { id in self.beacon.replace(routeID: id); self.beaconStarts += 1; return true })
        }
    }
    func testCurrentInstalledRouteReachesBothOwnedSinks() throws {
        let h = try Harness(), ticket = try h.ticket()
        XCTAssertTrue(h.deliver(ticket))
        XCTAssertEqual(h.speechID, h.controller.active?.id)
        XCTAssertEqual(h.beacon.routeID, h.controller.active?.id)
        XCTAssertTrue(h.controller.validateForStart(try XCTUnwrap(h.speechID)))
    }
    func testExpiredTicketReachesNeitherSink() throws {
        let h = try Harness(), ticket = try h.ticket()
        h.now = 11
        XCTAssertFalse(h.deliver(ticket))
        XCTAssertEqual(h.speechStarts, 0); XCTAssertEqual(h.beaconStarts, 0)
        XCTAssertNil(h.controller.active)
    }
    func testPermissionChangesBetweenSpeechAndBeacon() throws {
        let h = try Harness(), ticket = try h.ticket()
        XCTAssertFalse(h.controller.deliver(ticket: ticket, goalRevision: h.goal, speech: { id in
            h.speechID = id; h.hazard = true; return true
        }, beacon: { _ in XCTFail("A speech admission is not beacon permission"); return true }))
        XCTAssertNil(h.speechID); XCTAssertNil(h.controller.active)
    }
    func testWatchdogRetiresExpiredOutputWithoutNewSensorCallback() throws {
        let h = try Harness(); XCTAssertTrue(h.deliver(try h.ticket()))
        let id = try XCTUnwrap(h.controller.active?.id)
        h.now = 10.6; h.controller.revalidate(); h.controller.revalidate()
        XCTAssertEqual(h.stoppedSpeech, [id]); XCTAssertEqual(h.stoppedBeacon, [id])
        XCTAssertNil(h.speechID); XCTAssertNil(h.beacon.routeID)
    }
    func testDelayedPlaybackStartRechecksTicket() throws {
        let h = try Harness(); XCTAssertTrue(h.deliver(try h.ticket()))
        let id = try XCTUnwrap(h.controller.active?.id)
        h.owner.loseTracking()
        XCTAssertFalse(h.controller.validateForStart(id))
        XCTAssertNil(h.speechID); XCTAssertNil(h.controller.active)
    }
    func testOldCallbackCannotRetireNewRouteOrIndependentAlert() throws {
        let h = try Harness(), ticket = try h.ticket()
        XCTAssertTrue(h.deliver(ticket)); let old = try XCTUnwrap(h.controller.active?.id)
        XCTAssertTrue(h.deliver(ticket)); let current = try XCTUnwrap(h.controller.active?.id)
        h.controller.retire(id: old)
        XCTAssertEqual(h.controller.active?.id, current)
        XCTAssertEqual(h.beacon.routeID, current)
        let hazardSpeechID = UUID()
        h.speechID = hazardSpeechID; h.beacon.replace(routeID: nil); h.hazard = true
        h.controller.revalidate()
        XCTAssertEqual(h.speechID, hazardSpeechID)
        XCTAssertEqual(h.stoppedBeacon, [old]) // New independent beacon is not stopped.
    }
    func testGoalChangeRetiresOutputButNotMeasuredPoseOrMap() throws {
        let h = try Harness(); XCTAssertTrue(h.deliver(try h.ticket()))
        let session = h.owner.sessionID, artifact = h.owner.installation?.artifact
        h.goal = UUID().uuidString; h.controller.revalidate()
        XCTAssertNil(h.controller.active)
        XCTAssertEqual(h.owner.sessionID, session); XCTAssertEqual(h.owner.installation?.artifact, artifact)
        XCTAssertNotNil(h.owner.currentPose(now: 10))
    }
    func testBodyAndRestrictionChangesRetireHeldOutput() throws {
        let h = try Harness(); XCTAssertTrue(h.deliver(try h.ticket()))
        try h.owner.setBody(.init(radius: 0.3, height: 1.6, margin: 0.1))
        h.controller.revalidate(); XCTAssertNil(h.controller.active)
        let second = try Harness(); XCTAssertTrue(second.deliver(try second.ticket()))
        try second.owner.addRestrictions(binding: XCTUnwrap(second.owner.installation).binding,
            blocked: [MapConnection("middle", "end")], zones: [], persist: { _ in })
        second.controller.revalidate(); XCTAssertNil(second.controller.active)
    }
    func testFailedSpeechDoesNotStartBeaconOrHoldAttempt() throws {
        let h = try Harness(), ticket = try h.ticket()
        XCTAssertFalse(h.controller.deliver(ticket: ticket, goalRevision: h.goal,
            speech: { _ in false }, beacon: { _ in XCTFail("Speech was rejected"); return true }))
        XCTAssertNil(h.controller.active)
    }
    func testBeaconOwnershipRejectsStaleRetirementAfterReplacement() {
        var ownership = SpatialRouteBeaconOwnership()
        let old = UUID(), new = UUID()
        ownership.replace(routeID: old); ownership.replace(routeID: new)
        XCTAssertFalse(ownership.retire(old)); XCTAssertEqual(ownership.routeID, new)
        ownership.replace(routeID: nil) // Actual independent-alert path in Feedback.
        XCTAssertFalse(ownership.retire(new))
    }
}
