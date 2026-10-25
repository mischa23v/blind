import Foundation
import XCTest
@testable import BlindCore

final class SpatialRouteOwnerTests: XCTestCase {
    typealias F = SpatialIntegrationFixture
    func testLoadedMapPoseBodyAndExistingPlannerProduceBoundTicket() throws {
        let (owner, support) = try F.prepared()
        XCTAssertEqual(owner.route.map(\.id), ["start", "middle", "end"])
        let ticket = try owner.next(support: support, now: 10)
        XCTAssertEqual(ticket.target.id, "middle")
        XCTAssertEqual(ticket.currentFloorPoint, Point3(1, 0, 3))
        XCTAssertEqual(ticket.artifactSHA256, owner.installation?.artifact.sha256)
        XCTAssertTrue(owner.permits(ticket, now: 10.2))
        XCTAssertFalse(owner.permits(ticket, now: 10.51))
    }
    func testNoNativePoseIssuerMeansNoTicket() throws {
        var owner = try F.owner(); let goal = UUID(); owner.setGoal(revision: goal)
        try owner.plan(from: "start", to: "end", goal: goal)
        let unaccepted = try F.capture(owner: owner)
        XCTAssertNil(owner.currentPose(now: 10))
        XCTAssertThrowsError(try owner.next(support: F.support(unaccepted), now: 10))
    }
    func testAppearanceAndCameraHeadingCannotUnlockLoadedMapRoute() throws {
        for source in [SpatialLocalizationCapture.Source.coarseLocation, .roomAppearance] {
            var owner = try F.owner()
            XCTAssertThrowsError(try owner.accept(F.capture(owner: owner, source: source), now: 10))
        }
        var owner = try F.owner()
        XCTAssertThrowsError(try owner.accept(F.capture(owner: owner, heading: .cameraOnly), now: 10))
    }
    func testCurrentLegIsCheckedNotOnlyAuthoredRouteEdges() throws {
        let map = F.map(blockedCell: (4, 4)) // Unknown region 0.5 m beside authored z=3 path.
        let (owner, support) = try F.prepared(map: map)
        XCTAssertFalse(owner.route.isEmpty) // Nominal body fits the authored graph.
        XCTAssertThrowsError(try owner.next(support: support, now: 10)) // Current uncertainty-expanded body reaches unknown ground.
    }
    func testLegacyGraphWithoutCollisionSurfaceCannotIssueTicket() throws {
        let (owner, support) = try F.prepared(map: F.map(surface: false))
        XCTAssertFalse(owner.route.isEmpty)
        XCTAssertThrowsError(try owner.next(support: support, now: 10))
    }
    func testCameraHeightCannotSubstituteForMeasuredFloor() throws {
        let (owner, support) = try F.prepared()
        let cameraHeight = SpatialFloorSupport(binding: support.binding, floorID: support.floorID,
            sessionID: support.sessionID, captureID: support.captureID, height: 1.3, capturedAt: support.capturedAt)
        XCTAssertThrowsError(try owner.next(support: cameraHeight, now: 10))
        XCTAssertNoThrow(try owner.next(support: support, now: 10))
    }
    func testWrongSessionCaptureOrFloorSupportRejects() throws {
        let (owner, support) = try F.prepared()
        for bad in [SpatialFloorSupport(binding: support.binding, floorID: "other", sessionID: support.sessionID,
                     captureID: support.captureID, height: 0, capturedAt: 10),
                    .init(binding: support.binding, floorID: support.floorID, sessionID: UUID(),
                     captureID: support.captureID, height: 0, capturedAt: 10),
                    .init(binding: support.binding, floorID: support.floorID, sessionID: support.sessionID,
                     captureID: UUID(), height: 0, capturedAt: 10),
                    .init(binding: support.binding, floorID: support.floorID, sessionID: support.sessionID,
                     captureID: support.captureID, height: 0, capturedAt: 9.9)] {
            XCTAssertThrowsError(try owner.next(support: bad, now: 10))
        }
    }
    func testGoalChangeWithdrawsOutputWithoutResettingPoseOrMap() throws {
        var (owner, support) = try F.prepared()
        let ticket = try owner.next(support: support, now: 10)
        let session = owner.sessionID, installation = owner.installation?.registry.installationID
        owner.setGoal(revision: UUID())
        XCTAssertFalse(owner.permits(ticket, now: 10.1))
        XCTAssertEqual(owner.sessionID, session)
        XCTAssertEqual(owner.installation?.registry.installationID, installation)
        XCTAssertNotNil(owner.currentPose(now: 10.1))
        XCTAssertTrue(owner.route.isEmpty)
    }
    func testBodyChangeWithdrawsOutputAndReplanningUsesNewEnvelope() throws {
        var (owner, support) = try F.prepared(map: F.map(clearance: 2))
        let ticket = try owner.next(support: support, now: 10)
        let goal = try XCTUnwrap(owner.goalRevision)
        try owner.setBody(.init(radius: 0.25, height: 2.2, margin: 0.1))
        XCTAssertFalse(owner.permits(ticket, now: 10.1))
        XCTAssertNotNil(owner.currentPose(now: 10.1))
        XCTAssertThrowsError(try owner.plan(from: "start", to: "end", goal: goal))
    }
    func testObstacleChangeWithdrawsOutputAndUsesExistingRestrictions() throws {
        var (owner, support) = try F.prepared()
        let ticket = try owner.next(support: support, now: 10)
        let goal = try XCTUnwrap(owner.goalRevision), binding = try XCTUnwrap(owner.installation).binding
        try owner.addRestrictions(binding: binding, blocked: [], zones: [
            .init(id: "closure", name: "Synthetic closure", level: "ground", minX: 2, maxX: 2.5, minZ: 2.5, maxZ: 3.5)], persist: { _ in })
        XCTAssertFalse(owner.permits(ticket, now: 10.1))
        XCTAssertThrowsError(try owner.plan(from: "start", to: "end", goal: goal))
        XCTAssertNotNil(owner.currentPose(now: 10.1))
    }
    func testBlockedGraphEdgeWithdrawsAndPreventsRoute() throws {
        var (owner, support) = try F.prepared()
        let ticket = try owner.next(support: support, now: 10)
        try owner.addRestrictions(binding: XCTUnwrap(owner.installation).binding, blocked: [MapConnection("middle", "end")], zones: [], persist: { _ in })
        XCTAssertFalse(owner.permits(ticket, now: 10.1))
        XCTAssertThrowsError(try owner.plan(from: "start", to: "end", goal: XCTUnwrap(owner.goalRevision)))
    }
    func testMapRevisionSessionAndNewCaptureEachWithdrawOldOutput() throws {
        var (owner, support) = try F.prepared()
        let ticket = try owner.next(support: support, now: 10)
        let newCapture = try F.capture(owner: owner, time: 10.1)
        try owner.accept(newCapture, now: 10.1)
        XCTAssertFalse(owner.permits(ticket, now: 10.1))
        let second = try owner.next(support: F.support(newCapture), now: 10.1)
        let newMap = try F.installation(map: F.map(revision: "r2"), prior: owner.installation)
        try owner.install(newMap, persist: { _ in })
        XCTAssertFalse(owner.permits(second, now: 10.1))
        XCTAssertNil(owner.currentPose(now: 10.1))
        XCTAssertThrowsError(try owner.accept(newCapture, now: 10.1))
    }
    func testTrackingLossRejectsInflightPoseAndRetainsDurableMap() throws {
        var (owner, support) = try F.prepared()
        let ticket = try owner.next(support: support, now: 10)
        let inFlight = try F.capture(owner: owner, time: 10.1), binding = owner.installation?.binding
        owner.loseTracking()
        XCTAssertFalse(owner.permits(ticket, now: 10.1))
        XCTAssertThrowsError(try owner.accept(inFlight, now: 10.1))
        XCTAssertEqual(owner.installation?.binding, binding)
    }
    func testWaypointAndFailedReplanWithdrawOldOutput() throws {
        var (owner, support) = try F.prepared()
        let ticket = try owner.next(support: support, now: 10)
        owner.confirmWaypoint()
        XCTAssertFalse(owner.permits(ticket, now: 10))
        XCTAssertThrowsError(try owner.next(support: support, now: 10)) // Manual arrival is not a changed pose.
        let moved = try F.capture(owner: owner, time: 10.1, x: 3)
        try owner.accept(moved, now: 10.1)
        let next = try owner.next(support: F.support(moved), now: 10.1)
        XCTAssertEqual(next.target.id, "end")
        XCTAssertThrowsError(try owner.plan(from: "unknown", to: "end", goal: XCTUnwrap(owner.goalRevision)))
        XCTAssertFalse(owner.permits(next, now: 10))
    }
    func testStaleGoalCannotReplaceNewerRoute() throws {
        var (owner, support) = try F.prepared()
        let ticket = try owner.next(support: support, now: 10)
        XCTAssertThrowsError(try owner.plan(from: "start", to: "end", goal: UUID()))
        XCTAssertTrue(owner.permits(ticket, now: 10))
    }
    func testDelayedEmptyRestrictionsCannotReopenClosedPath() throws {
        var (owner, _) = try F.prepared()
        let binding = try XCTUnwrap(owner.installation).binding, goal = try XCTUnwrap(owner.goalRevision)
        try owner.addRestrictions(binding: binding, blocked: [MapConnection("start", "middle")], zones: [], persist: { _ in })
        try owner.addRestrictions(binding: binding, blocked: [], zones: [], persist: { _ in })
        XCTAssertThrowsError(try owner.plan(from: "start", to: "end", goal: goal))
    }
    func testRestrictionIDCannotBeReusedToShrinkZone() throws {
        var (owner, _) = try F.prepared()
        let binding = try XCTUnwrap(owner.installation).binding
        let zone = KeepOutZone(id: "closure", name: "Closure", level: "ground", minX: 2, maxX: 2.5, minZ: 2.5, maxZ: 3.5)
        try owner.addRestrictions(binding: binding, blocked: [], zones: [zone], persist: { _ in })
        var moved = zone; moved.minZ = 0; moved.maxZ = 1
        XCTAssertThrowsError(try owner.addRestrictions(binding: binding, blocked: [], zones: [moved], persist: { _ in }))
        XCTAssertThrowsError(try owner.plan(from: "start", to: "end", goal: XCTUnwrap(owner.goalRevision)))
    }
    func testSameArtifactReinstallDoesNotEraseRestrictions() throws {
        var (owner, _) = try F.prepared()
        let installation = try XCTUnwrap(owner.installation), goal = try XCTUnwrap(owner.goalRevision)
        try owner.addRestrictions(binding: installation.binding, blocked: [MapConnection("start", "middle")], zones: [], persist: { _ in })
        XCTAssertThrowsError(try owner.install(installation, persist: { _ in }))
        try owner.install(XCTUnwrap(owner.installation), persist: { _ in })
        XCTAssertThrowsError(try owner.plan(from: "start", to: "end", goal: goal))
    }

    func testPoseBeyondSelectedLegCannotCrossBlockedEdgeToItsTarget() throws {
        var owner = try F.owner(); let goal = UUID(); owner.setGoal(revision: goal)
        let binding = try XCTUnwrap(owner.installation).binding
        try owner.addRestrictions(binding: binding, blocked: [MapConnection("middle", "end")], zones: [], persist: { _ in })
        try owner.plan(from: "start", to: "middle", goal: goal)
        let wrongStart = try F.capture(owner: owner, x: 6)
        try owner.accept(wrongStart, now: 10)
        XCTAssertThrowsError(try owner.next(support: F.support(wrongStart), now: 10)) { error in
            XCTAssertEqual(error as? SpatialRouteError, .offRoute)
        }
    }
    func testLargeLateralDepartureNeedsReplanInsteadOfInventedJoin() throws {
        let (owner, support) = try F.prepared(x: 2, z: 4)
        XCTAssertThrowsError(try owner.next(support: support, now: 10)) { error in
            XCTAssertEqual(error as? SpatialRouteError, .offRoute)
        }
    }

    func testHeadingUncertaintyCrossingBeaconBoundaryWithholdsDirection() throws {
        var (owner, _) = try F.prepared()
        let edgeHeading = -Double.pi / 2 + 22.4 * Double.pi / 180
        let nearBoundary = try F.capture(owner: owner, time: 10.1, bodyYaw: edgeHeading, headingUncertainty: 0.15)
        try owner.accept(nearBoundary, now: 10.1)
        XCTAssertThrowsError(try owner.next(support: F.support(nearBoundary), now: 10.1)) { error in
            XCTAssertEqual(error as? SpatialRouteError, .ambiguousDirection)
        }
    }
    func testTargetInsidePositionUncertaintyCannotProduceDirection() throws {
        var (owner, _) = try F.prepared()
        let close = try F.capture(owner: owner, time: 10.1, x: 2.95)
        try owner.accept(close, now: 10.1)
        XCTAssertThrowsError(try owner.next(support: F.support(close), now: 10.1)) { error in
            XCTAssertEqual(error as? SpatialRouteError, .ambiguousDirection)
        }
    }

    func testRestrictionSaveFailureWithdrawsOutputAndBlocksFurtherGuidance() throws {
        var (owner, support) = try F.prepared()
        let ticket = try owner.next(support: support, now: 10)
        enum WriteError: Error { case failed }
        XCTAssertThrowsError(try owner.addRestrictions(binding: XCTUnwrap(owner.installation).binding,
            blocked: [], zones: [], persist: { _ in throw WriteError.failed }))
        XCTAssertFalse(owner.restrictionsDurable)
        XCTAssertFalse(owner.permits(ticket, now: 10))
        try owner.plan(from: "start", to: "end", goal: XCTUnwrap(owner.goalRevision))
        XCTAssertThrowsError(try owner.next(support: support, now: 10))
        try owner.addRestrictions(binding: XCTUnwrap(owner.installation).binding, blocked: [], zones: [], persist: { _ in })
        XCTAssertTrue(owner.restrictionsDurable)
    }

}
