import Foundation
import XCTest
@testable import BlindCore

/// ALL maps, poses, measured uncertainty/support, transforms and links below are
/// synthetic authored fixtures. This executes real planner/collision/lease code;
/// it is not native localization, current clearance or physical-device evidence.
enum ConnectedFixture {
    static let body = SpatialIntegrationFixture.body, limits = SpatialIntegrationFixture.limits
    static let sha256 = SpatialIntegrationFixture.sha256
    static let a = SpatialMapBinding(mapID: "bedroom-map", frameID: "bedroom-frame", revision: "r1")
    static let b = SpatialMapBinding(mapID: "hall-map", frameID: "hall-frame", revision: "r1")
    static let c = SpatialMapBinding(mapID: "study-map", frameID: "study-frame", revision: "r1")
    static let date = Date(timeIntervalSince1970: 1_790_000_000)
    static func endpoint(_ binding: SpatialMapBinding, _ node: String, room: Bool = true) -> JourneyEndpoint {
        .init(binding: binding, floorID: binding == c ? "upper" : "ground", nodeID: node,
              roomID: room ? (binding == a ? "bedroom" : binding == b ? "hall" : "study") : nil)
    }
    static func catalog(missing: SpatialMapBinding? = nil, omitPortal: Bool = false,
                        omitTransform: Bool = false, replacement: Bool = false) throws -> ConnectedJourneyCatalog {
        let nodes: [SpatialPlaceNode] = [
            .init(id: "world", kind: .world), .init(id: "home", kind: .place, parentID: "world"),
            .init(id: "house", kind: .building, parentID: "home"),
            .init(id: "ground", kind: .floor, parentID: "house"), .init(id: "upper", kind: .floor, parentID: "house"),
            .init(id: "bedroom", kind: .room, parentID: "ground"), .init(id: "hall", kind: .room, parentID: "ground"),
            .init(id: "study", kind: .room, parentID: "upper")]
        let updated = SpatialMapBinding(mapID: a.mapID, frameID: "bedroom-frame-r2", revision: "r2")
        let bindings = [a,b,c] + (replacement ? [updated] : [])
        let records = bindings.map { binding in SpatialMapRevision(binding: binding,
            nodeID: binding == c ? "upper" : "ground", metersPerUnit: 1,
            floorLevels: ["level": binding == c ? "upper" : "ground"]) }
        let transitions: [SpatialTransition] = [
            .init(id: "bedroom-door", kind: .doorway, from: a, to: b, fromFloorID: "ground", toFloorID: "ground"),
            .init(id: "lift", kind: .elevator, from: b, to: c, fromFloorID: "ground", toFloorID: "upper")]
        let links: [SpatialFrameLink] = [
            .init(child: a, parent: b, childToParent: .init(translation: .init(-2,0,0), yaw: 0), source: "synthetic authored transform"),
            .init(child: c, parent: b, childToParent: .init(translation: .init(0,3,0), yaw: 0), source: "synthetic authored floor transform")]
        let active = bindings.filter { replacement ? $0 != a : true }
        let snapshot = SpatialRegistrySnapshot(nodes: nodes, maps: records, activeBindings: active,
            links: omitTransform ? [] : links, transitions: transitions)
        let registry = try SpatialFrameRegistry(snapshot: snapshot)
        var installations: [SpatialMapInstallation] = []
        for binding in active where binding != missing {
            let xs: [Double] = binding == c ? [5,6,7] : binding == b ? [1,3,5] : [1,2,3]
            let grid = NavigationSurface(level: "level", origin: .init(0,0,0), resolution: 0.5, width: 20, depth: 12,
                cells: Array(repeating: .init(floor: 0, clearance: 2.5, blocked: false), count: 240))
            var map = IndoorMap(name: "SYNTHETIC \(binding.mapID)", nodes: zip(["s","m","p"], xs).map {
                .init(id: $0.0, name: $0.0, level: "level", position: .init($0.1,0,3))
            }, edges: [.init(from: "s", to: "m", distance: xs[1]-xs[0]), .init(from: "m", to: "p", distance: xs[2]-xs[1])], surfaces: [grid])
            map.packageID = binding.mapID; map.packageRevision = binding.revision
            let bytes = try SpatialMapInstallation.canonicalMapBytes(map)
            installations.append(try SpatialMapInstallation(envelope: .init(snapshot: snapshot, binding: binding, mapBytes: bytes,
                artifactHistory: [.init(binding: binding, sha256: try sha256(bytes))]), sha256: sha256))
        }
        let portals: [JourneyPortal] = [
            .init(transitionID: "bedroom-door", from: endpoint(a,"p"), to: endpoint(b,"s"), source: "SYNTHETIC known door endpoints", surveyedDistance: 0.5, accessible: true, direction: .bidirectional),
            .init(transitionID: "lift", from: endpoint(b,"p"), to: endpoint(c,"s"), source: "SYNTHETIC known lift endpoints", surveyedDistance: 3.2, accessible: true, direction: .bidirectional)]
        return try .init(registry: registry, installations: installations,
                         portals: omitPortal || replacement || missing != nil || omitTransform ? [] : portals)
    }
    static func coordinator(_ catalog: ConnectedJourneyCatalog? = nil, snapshot: ConnectedJourneySnapshot = .init()) throws -> ConnectedJourneyCoordinator {
        try .init(catalog: catalog ?? self.catalog(), body: body, limits: limits, snapshot: snapshot)
    }
    static func capture(_ owner: ConnectedJourneyCoordinator, at endpoint: JourneyEndpoint, time: Double,
                        source: SpatialLocalizationCapture.Source = .alignedMapPose,
                        heading: SpatialLocalizationCapture.HeadingSource = .bodyAligned,
                        yaw: Double = -.pi/2) throws -> SpatialLocalizationCapture {
        let position = try owner.catalog.node(endpoint).position
        return .init(sessionID: try XCTUnwrap(owner.expectedSessionID), binding: endpoint.binding, floorID: endpoint.floorID,
            roomID: endpoint.roomID, position: .init(position.x,1.3,position.z), bodyYaw: yaw,
            source: source, headingSource: heading, trackingNormal: true,
            positionUncertainty: 0.05, headingUncertainty: 0.05, capturedAt: time)
    }
    static func observe(_ owner: inout ConnectedJourneyCoordinator, _ endpoint: JourneyEndpoint, time: Double, yaw: Double = -.pi/2) throws {
        let capture = try self.capture(owner, at: endpoint, time: time, yaw: yaw)
        try owner.accept(capture, support: SpatialIntegrationFixture.support(capture), now: time)
    }
    static func begin(_ owner: inout ConnectedJourneyCoordinator, _ endpoint: JourneyEndpoint, time: Double, yaw: Double = -.pi/2) throws {
        try owner.beginLocalization(in: endpoint.binding); try observe(&owner, endpoint, time: time, yaw: yaw)
    }
    static func prepared() throws -> ConnectedJourneyCoordinator {
        var value = try coordinator(); try begin(&value, endpoint(a,"s"), time: 1)
        try value.markStart(at: endpoint(a,"s"), origin: .trustedInterface, now: 1, recordedAt: date, persist: { _ in })
        return value
    }
    static func deliver(_ value: inout ConnectedJourneyCoordinator, _ question: JourneyReturnQuestion,
                        outcome: NarrationDelivery = .completed, now: Double = 10) throws -> JourneyClarificationReceipt {
        var ledger = SpeechDeliveryLedger()
        let attempt = try XCTUnwrap(ledger.begin(text: question.text, priority: .information,
            destination: .requested(question.id), transport: .synthesized))
        let completion = try XCTUnwrap(ledger.finish(token: attempt.token, outcome: outcome, now: now))
        return try value.recordClarificationDelivery(completion, now: now)
    }
    static func drive(_ value: inout ConnectedJourneyCoordinator, time: inout Double, trace: inout [String], reverse: Bool = false) throws {
        let originalGoal = try XCTUnwrap(value.snapshot.goal).revision
        while let leg = value.currentLeg {
            switch leg {
            case .local(_, let to):
                while true {
                    let ticket = try value.next(now: time)
                    let cue = try XCTUnwrap(ticket.route.directionalCue())
                    XCTAssertTrue(value.permits(ticket, now: time))
                    trace.append("map=\(ticket.route.spatial.binding.mapID) floor=\(ticket.route.spatial.floorID) target=\(ticket.route.target.id) sector=\(cue.sector) distance=\(String(format: "%.2f", cue.distance))")
                    time += 0.1
                    let endpoint = self.endpoint(to.binding, ticket.route.target.id)
                    try observe(&value, endpoint, time: time, yaw: reverse ? .pi/2 : -.pi/2)
                    XCTAssertFalse(value.permits(ticket, now: time))
                    try value.advanceWaypoint(now: time)
                    if ticket.route.target.id == to.nodeID { break }
                }
                try value.completeLocalLeg(now: time, recordedAt: date, persist: { _ in })
            case .portal(let id, let from, let to):
                trace.append("portal=\(id) from=\(from.floorID) to=\(to.floorID) output=withheld")
                XCTAssertThrowsError(try value.next(now: time))
                try value.armPortal(now: time, recordedAt: date)
                try value.beginLocalization(in: to.binding)
                XCTAssertNil(value.currentPose(now: time))
                XCTAssertEqual(value.snapshot.goal?.revision, originalGoal)
                time += 0.1
                try observe(&value, to, time: time, yaw: reverse ? .pi/2 : -.pi/2)
                try value.completePortal(now: time, recordedAt: date, persist: { _ in })
            }
            XCTAssertEqual(value.snapshot.goal?.revision, originalGoal)
        }
        trace.append("goal=\(value.snapshot.goal!.purpose.rawValue) status=\(value.snapshot.goal!.status.rawValue)")
    }
}

final class ConnectedJourneyTests: XCTestCase {
    typealias F = ConnectedFixture
    func testSyntheticFullOutboundAndReturnUsesActualPlannerCollisionAndNarrationLedger() throws {
        var value = try F.prepared(), time = 1.0, trace: [String] = []
        try value.setDestination(F.endpoint(F.c,"p"), origin: .trustedInterface, recordedAt: F.date, persist: { _ in })
        let goal = value.snapshot.goal?.revision
        try value.plan(from: F.endpoint(F.a,"s"), now: time)
        XCTAssertEqual(value.itinerary.count, 5)
        try F.drive(&value, time: &time, trace: &trace)
        XCTAssertEqual(value.snapshot.goal?.revision, goal)
        try value.saveReference(at: F.endpoint(F.c,"p"), origin: .trustedInterface, now: time, recordedAt: F.date, persist: { _ in })
        guard case .clarify(let question) = try value.requestReturn(origin: .trustedInterface, recordedAt: F.date, persist: { _ in }) else { return XCTFail() }
        trace.append(question.text)
        let receipt = try F.deliver(&value, question, now: time)
        try value.resolveReturn(.journeyStart, receipt: receipt, origin: .trustedInterface, now: time, recordedAt: F.date, persist: { _ in })
        time += 0.1; try F.observe(&value, F.endpoint(F.c,"p"), time: time, yaw: .pi/2)
        try value.plan(from: F.endpoint(F.c,"p"), now: time)
        try F.drive(&value, time: &time, trace: &trace, reverse: true)
        XCTAssertEqual(value.snapshot.goal?.target.context, .init(worldID: "world", placeID: "home", buildingID: "house", floorID: "ground", roomID: "bedroom"))
        XCTAssertEqual(value.snapshot.events.filter { $0.kind == .portalEndpointsAssociated }.count, 4)
        XCTAssertEqual(trace, [
            "map=bedroom-map floor=ground target=m sector=0 distance=1.00",
            "map=bedroom-map floor=ground target=p sector=0 distance=1.00",
            "portal=bedroom-door from=ground to=ground output=withheld",
            "map=hall-map floor=ground target=m sector=0 distance=2.00",
            "map=hall-map floor=ground target=p sector=0 distance=2.00",
            "portal=lift from=ground to=upper output=withheld",
            "map=study-map floor=upper target=m sector=0 distance=1.00",
            "map=study-map floor=upper target=p sector=0 distance=1.00",
            "goal=destination status=arrived",
            "Return to the saved reference or the journey start?",
            "map=study-map floor=upper target=m sector=0 distance=1.00",
            "map=study-map floor=upper target=s sector=0 distance=1.00",
            "portal=lift from=upper to=ground output=withheld",
            "map=hall-map floor=ground target=m sector=0 distance=2.00",
            "map=hall-map floor=ground target=s sector=0 distance=2.00",
            "portal=bedroom-door from=ground to=ground output=withheld",
            "map=bedroom-map floor=ground target=m sector=0 distance=1.00",
            "map=bedroom-map floor=ground target=s sector=0 distance=1.00",
            "goal=returnToStart status=arrived"])
        print("SYNTHETIC_FULL_JOURNEY_OUTPUT=" + String(decoding: try JSONEncoder().encode(trace), as: UTF8.self))
    }
    func testRestartRestoresIntentAndHistoryButNeverPoseRouteOrReceipt() throws {
        var original = try F.prepared()
        try original.setDestination(F.endpoint(F.c,"p"), origin: .trustedInterface, recordedAt: F.date, persist: { _ in })
        try original.plan(from: F.endpoint(F.a,"s"), now: 1)
        let old = try original.next(now: 1), bytes = try original.snapshot.encoded()
        var restored = try F.coordinator(snapshot: .init(data: bytes))
        XCTAssertEqual(restored.snapshot, original.snapshot)
        XCTAssertNil(restored.currentPose(now: 1)); XCTAssertNil(restored.expectedSessionID); XCTAssertNil(restored.currentQuestion)
        XCTAssertFalse(restored.permits(old, now: 1)); XCTAssertThrowsError(try restored.next(now: 1))
        try F.begin(&restored, F.endpoint(F.c,"s"), time: 1)
        try restored.plan(from: F.endpoint(F.c,"s"), now: 1)
        XCTAssertEqual(restored.currentLeg, .local(from: F.endpoint(F.c,"s"), to: F.endpoint(F.c,"p")))
        XCTAssertEqual(restored.snapshot.goal, original.snapshot.goal)
    }
    func testCameraRestartRetainsGoalAndRequiresFreshSessionEvidence() throws {
        var value = try F.prepared()
        try value.setDestination(F.endpoint(F.c,"p"), origin: .trustedInterface, recordedAt: F.date, persist: { _ in })
        try value.plan(from: F.endpoint(F.a,"s"), now: 1)
        let ticket = try value.next(now: 1), capture = try F.capture(value, at: F.endpoint(F.a,"s"), time: 1.1)
        let before = value.snapshot; value.loseTracking()
        XCTAssertEqual(before, value.snapshot); XCTAssertFalse(value.permits(ticket, now: 1))
        XCTAssertThrowsError(try value.accept(capture, support: SpatialIntegrationFixture.support(capture), now: 1.1))
        try F.begin(&value, F.endpoint(F.a,"s"), time: 2)
        try value.plan(from: F.endpoint(F.a,"s"), now: 2)
        XCTAssertNoThrow(try value.next(now: 2))
    }
    func testNoPortalNoTransformUnknownMapOrFloorCannotInventConnection() throws {
        for catalog in [try F.catalog(omitPortal: true), try F.catalog(omitTransform: true), try F.catalog(missing: F.b)] {
            var value = try F.coordinator(catalog); try F.begin(&value, F.endpoint(F.a,"s"), time: 1)
            try value.setDestination(F.endpoint(F.c,"p"), origin: .trustedInterface, recordedAt: F.date, persist: { _ in })
            XCTAssertThrowsError(try value.plan(from: F.endpoint(F.a,"s"), now: 1))
        }
        var value = try F.prepared()
        XCTAssertThrowsError(try value.setDestination(.init(binding: F.a, floorID: "unknown", nodeID: "s"), origin: .trustedInterface, recordedAt: F.date, persist: { _ in }))
        XCTAssertThrowsError(try value.beginLocalization(in: .init(mapID: "outside", frameID: "GPS", revision: "1")))
        XCTAssertNil(value.currentPose(now: 1))
    }
    func testIncompleteWrongRevisionWrongEndpointAndMetricInconsistentPortalReject() throws {
        let catalog = try F.catalog(), p = catalog.portals[0]
        for bad in [JourneyPortal(transitionID: p.transitionID, from: p.from, to: p.to, source: " ", surveyedDistance: 1, accessible: true, direction: .bidirectional),
                    .init(transitionID: p.transitionID, from: F.endpoint(F.a,"missing"), to: p.to, source: "synthetic", surveyedDistance: 1, accessible: true, direction: .bidirectional),
                    .init(transitionID: "lift", from: catalog.portals[1].from, to: catalog.portals[1].to, source: "synthetic", surveyedDistance: 0.1, accessible: true, direction: .bidirectional)] {
            XCTAssertThrowsError(try ConnectedJourneyCatalog(registry: catalog.registry, installations: Array(catalog.installations.values), portals: [bad]))
        }
    }
    func testAppearanceGPSUserLabelAndCameraHeadingCannotEstablishCurrentPose() throws {
        for source in [SpatialLocalizationCapture.Source.coarseLocation, .roomAppearance] {
            var value = try F.coordinator(); try value.beginLocalization(in: F.a)
            let capture = try F.capture(value, at: F.endpoint(F.a,"s"), time: 1, source: source)
            XCTAssertThrowsError(try value.accept(capture, support: SpatialIntegrationFixture.support(capture), now: 1))
            XCTAssertNil(value.currentPose(now: 1))
        }
        var value = try F.coordinator(); try value.beginLocalization(in: F.a)
        let capture = try F.capture(value, at: F.endpoint(F.a,"s"), time: 1, heading: .cameraOnly)
        XCTAssertThrowsError(try value.accept(capture, support: SpatialIntegrationFixture.support(capture), now: 1))
        XCTAssertThrowsError(try value.markStart(at: F.endpoint(F.a,"s"), origin: .trustedInterface, now: 1, recordedAt: F.date, persist: { _ in }))
    }
    func testUnverifiedSpeechCannotChangeGoalReturnCancelOrReference() throws {
        for origin in CompanionCommandOrigin.allCases where origin != .trustedInterface {
            var value = try F.prepared(); let before = value.snapshot
            XCTAssertThrowsError(try value.setDestination(F.endpoint(F.c,"p"), origin: origin, recordedAt: F.date, persist: { _ in }))
            XCTAssertThrowsError(try value.requestReturn(origin: origin, recordedAt: F.date, persist: { _ in }))
            XCTAssertThrowsError(try value.cancel(origin: origin, recordedAt: F.date, persist: { _ in }))
            XCTAssertThrowsError(try value.saveReference(at: F.endpoint(F.a,"s"), origin: origin, now: 1, recordedAt: F.date, persist: { _ in }))
            XCTAssertEqual(value.snapshot, before)
        }
        for text in ["take me back", "Take me back!", "ارجعني", "رجعني"] { XCTAssertTrue(JourneyReturnCommand.matches(text)) }
        XCTAssertFalse(JourneyReturnCommand.matches("the television said take me back"))
    }
    func testNewGoalRejectsOldRouteAndDoesNotResetPose() throws {
        var value = try F.prepared()
        try value.setDestination(F.endpoint(F.c,"p"), origin: .trustedInterface, recordedAt: F.date, persist: { _ in })
        try value.plan(from: F.endpoint(F.a,"s"), now: 1)
        let old = try value.next(now: 1), pose = value.currentPose(now: 1)
        try value.setDestination(F.endpoint(F.b,"s"), origin: .trustedInterface, recordedAt: F.date, persist: { _ in })
        XCTAssertFalse(value.permits(old, now: 1)); XCTAssertEqual(value.currentPose(now: 1), pose)
        XCTAssertTrue(value.itinerary.isEmpty)
    }
    func testBlockedReturnUsesCurrentRestrictionsNotTraversedHistory() throws {
        var value = try F.prepared(), time = 1.0, trace: [String] = []
        try value.setDestination(F.endpoint(F.c,"p"), origin: .trustedInterface, recordedAt: F.date, persist: { _ in })
        try value.plan(from: F.endpoint(F.a,"s"), now: time); try F.drive(&value, time: &time, trace: &trace)
        _ = try value.requestReturn(origin: .trustedInterface, recordedAt: F.date, persist: { _ in })
        time += 0.1; try F.observe(&value, F.endpoint(F.c,"p"), time: time, yaw: .pi/2)
        try value.plan(from: F.endpoint(F.c,"p"), now: time)
        let old = try value.next(now: time)
        try value.addRestrictions(blocked: [MapConnection("s","m")], zones: [], persistMap: { _ in })
        XCTAssertFalse(value.permits(old, now: time))
        XCTAssertThrowsError(try value.plan(from: F.endpoint(F.c,"p"), now: time))
        XCTAssertEqual(value.snapshot.goal?.purpose, .returnToStart)
    }
    func testDeletionAndReplacementKeepHistoryButWithholdStaleTarget() throws {
        var value = try F.prepared()
        _ = try value.requestReturn(origin: .trustedInterface, recordedAt: F.date, persist: { _ in })
        let history = value.snapshot
        try value.replaceCatalog(try F.catalog(missing: F.a))
        XCTAssertEqual(value.snapshot, history); XCTAssertNil(value.currentPose(now: 1))
        try F.begin(&value, F.endpoint(F.c,"p"), time: 2)
        XCTAssertThrowsError(try value.plan(from: F.endpoint(F.c,"p"), now: 2))
        try value.replaceCatalog(try F.catalog(replacement: true))
        try F.begin(&value, F.endpoint(F.c,"p"), time: 3)
        XCTAssertThrowsError(try value.plan(from: F.endpoint(F.c,"p"), now: 3))
        XCTAssertEqual(value.snapshot.start?.endpoint.binding.revision, "r1")
    }
}
