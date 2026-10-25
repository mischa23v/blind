import XCTest
@testable import BlindCore

final class RecordedRoutePlaybackTests: XCTestCase {
    typealias F = SpatialIntegrationFixture
    private struct SyntheticBenchValidator: RecordedRouteAssociationValidator {
        let accept: Bool
        func validate(sample: RecordedRouteSample, association: RecordedRouteNodeAssociation) -> RecordedRouteAssociationValidation {
            accept ? .independentlyValidated : .unavailable
        }
    }
    private func setup() throws -> (RecordedRouteHistory, [RecordedRouteNodeAssociation], SpatialRouteOwner, UUID) {
        var map = F.map()
        map.nodes[1].position = Point3(1.4, 0, 3); map.nodes[2].position = Point3(1.8, 0, 3)
        map.edges = [.init(from: "start", to: "middle", distance: 0.4), .init(from: "middle", to: "end", distance: 0.4),
                     .init(from: "start", to: "end", distance: 0.8)]
        var owner = try F.owner(installation: F.installation(map: map)); let goal = UUID(); owner.setGoal(revision: goal)
        let session = UUID(); var history = RecordedRouteHistory(), associations: [RecordedRouteNodeAssociation] = []
        for (i, node) in map.nodes.enumerated() {
            var c = NativeCameraTransform.identity.columns; c[12] = node.position.x; c[13] = 1.3; c[14] = node.position.z
            let observation = NativeObservationRecord(sessionID: session, coordinateFrameID: "synthetic-source", producer: .arkit,
                sourceID: "synthetic-\(i)", capturedAt: Double(i)*0.2, receivedAt: Double(i)*0.2,
                observedAt: Date(timeIntervalSince1970: 100 + Double(i)), tracking: .normal,
                cameraConvention: .arKitRightUpBack, cameraToSessionWorld: .init(columns: c),
                intrinsics: .init(width: 2, height: 2, fx: 1, fy: 1, cx: 1, cy: 1), depth: nil)
            try history.observe(observation)
            associations.append(.init(observationID: observation.id, binding: owner.installation!.binding, nodeID: node.id,
                evidenceID: "synthetic-test-only", calibrationRevision: "synthetic", registrationRevision: "synthetic"))
        }
        return (history, associations, owner, goal)
    }
    func testMeasuredSeamKeepsRecordedOrderInsteadOfShortcutAndFreshOwnerGates() throws {
        var (history, associations, owner, goal) = try setup()
        try RecordedRoutePlayback.prepare(history: history, associations: associations, validator: SyntheticBenchValidator(accept: true), owner: &owner, goal: goal, origin: .trustedInterface)
        XCTAssertEqual(owner.route.map(\.id), ["end", "middle", "start"])
        let capture = try F.capture(owner: owner, x: 1.8, bodyYaw: .pi / 2)
        XCTAssertThrowsError(try owner.next(support: F.support(capture), now: 10))
        try owner.accept(capture, now: 10)
        let ticket = try owner.next(support: F.support(capture), now: 10)
        XCTAssertEqual(ticket.target.id, "middle")
        XCTAssertTrue(owner.permits(ticket, now: 10))
        XCTAssertFalse(owner.permits(ticket, now: 11))
        owner.setGoal(revision: UUID()); XCTAssertFalse(owner.permits(ticket, now: 10))
        history.interrupt()
        XCTAssertThrowsError(try RecordedRoutePlayback.prepare(history: history, associations: associations, validator: SyntheticBenchValidator(accept: true), owner: &owner, goal: goal, origin: .trustedInterface))
        XCTAssertTrue(owner.route.isEmpty)
    }
    func testMissingValidationClosedDoorAndRestoredHistoryCannotFallbackToShortcut() throws {
        var (history, associations, owner, goal) = try setup()
        XCTAssertThrowsError(try RecordedRoutePlayback.prepare(history: history, associations: associations, validator: SyntheticBenchValidator(accept: false), owner: &owner, goal: goal, origin: .trustedInterface))
        XCTAssertTrue(owner.route.isEmpty)
        try owner.addRestrictions(binding: owner.installation!.binding, blocked: [MapConnection("end", "middle")], zones: [], persist: { _ in })
        XCTAssertThrowsError(try RecordedRoutePlayback.prepare(history: history, associations: associations, validator: SyntheticBenchValidator(accept: true), owner: &owner, goal: goal, origin: .trustedInterface))
        XCTAssertTrue(owner.route.isEmpty) // Existing alternate end->start->middle is not silently substituted.
        history = try RecordedRouteHistory(data: history.encoded())
        XCTAssertThrowsError(try RecordedRoutePlayback.prepare(history: history, associations: associations, validator: SyntheticBenchValidator(accept: true), owner: &owner, goal: goal, origin: .trustedInterface))
    }
    func testStaleGoalCannotCancelAnotherOwnersRoute() throws {
        var (history, associations, owner, goal) = try setup()
        try owner.plan(from: "start", to: "end", goal: goal)
        let before = owner.route
        XCTAssertThrowsError(try RecordedRoutePlayback.prepare(history: history, associations: associations,
            validator: SyntheticBenchValidator(accept: true), owner: &owner, goal: UUID(), origin: .trustedInterface))
        XCTAssertEqual(owner.route, before)
        XCTAssertThrowsError(try owner.planRecordedNodes(["end", "middle", "start"], binding: owner.installation!.binding, goal: UUID()))
        XCTAssertEqual(owner.route, before)
    }
    func testExactCommandsDoNotInterpretQuotedOrConditionalConversationAsReturn() {
        XCTAssertTrue(RecordedRouteReturnCommand.matches("Retrace my route!"))
        XCTAssertFalse(RecordedRouteReturnCommand.matches("if I get lost retrace my route"))
        XCTAssertFalse(RecordedRouteReturnCommand.matches("don't retrace my route"))
        XCTAssertFalse(RecordedRouteReturnCommand.matches("\"retrace my route\""))
    }
}
