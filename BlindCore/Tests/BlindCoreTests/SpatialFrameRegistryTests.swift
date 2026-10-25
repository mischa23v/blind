import Foundation
import XCTest
@testable import BlindCore

/// Synthetic policy/geometry fixtures, not sensor localization or device navigation.
final class SpatialFrameRegistryTests: XCTestCase {
    let building = SpatialMapBinding(mapID: "building-map", frameID: "building-frame", revision: "1")
    let ground = SpatialMapBinding(mapID: "ground-room", frameID: "ground-frame", revision: "1")
    let upper = SpatialMapBinding(mapID: "upper-room", frameID: "upper-frame", revision: "1")
    var nodes: [SpatialPlaceNode] {
        [.init(id: "world", kind: .world), .init(id: "place", kind: .place, parentID: "world"),
         .init(id: "building", kind: .building, parentID: "place"),
         .init(id: "floor-0", kind: .floor, parentID: "building"),
         .init(id: "room-0", kind: .room, parentID: "floor-0"),
         .init(id: "floor-1", kind: .floor, parentID: "building"),
         .init(id: "room-1", kind: .room, parentID: "floor-1")]
    }
    var maps: [SpatialMapRevision] {
        [.init(binding: building, nodeID: "building", metersPerUnit: 1,
               floorLevels: ["ground": "floor-0", "first": "floor-1"]),
         .init(binding: ground, nodeID: "room-0", metersPerUnit: 1, floorLevels: ["ground": "floor-0"]),
         .init(binding: upper, nodeID: "room-1", metersPerUnit: 1, floorLevels: ["first": "floor-1"])]
    }
    var links: [SpatialFrameLink] {
        [.init(child: ground, parent: building,
               childToParent: .init(translation: Point3(10, 0, 0), yaw: .pi / 2), source: "synthetic fixture"),
         .init(child: upper, parent: building,
               childToParent: .init(translation: Point3(0, 3, 0), yaw: 0), source: "synthetic fixture")]
    }
    var transition: SpatialTransition {
        .init(id: "lift", kind: .elevator, from: ground, to: upper, fromFloorID: "floor-0", toFloorID: "floor-1")
    }
    func snapshot(nodes: [SpatialPlaceNode]? = nil, maps: [SpatialMapRevision]? = nil,
                  active: [SpatialMapBinding]? = nil, links: [SpatialFrameLink]? = nil,
                  transitions: [SpatialTransition]? = nil) -> SpatialRegistrySnapshot {
        .init(nodes: nodes ?? self.nodes, maps: maps ?? self.maps,
              activeBindings: active ?? [building, ground, upper], links: links ?? self.links,
              transitions: transitions ?? [transition])
    }
    func registry() throws -> SpatialFrameRegistry { try .init(snapshot: snapshot()) }
    func gate() -> SpatialLocalizationLease {
        .init(limits: .init(maximumPositionUncertainty: 0.25, maximumHeadingUncertainty: 0.2))
    }
    func capture(_ gate: SpatialLocalizationLease, binding: SpatialMapBinding? = nil,
                 floorID: String = "floor-0", roomID: String? = "room-0", time: Double = 10,
                 source: SpatialLocalizationCapture.Source = .alignedMapPose,
                 heading: SpatialLocalizationCapture.HeadingSource = .bodyAligned,
                 tracking: Bool = true, uncertainty: Double = 0.1, yaw: Double = 0,
                 session: UUID? = nil, id: UUID = UUID()) -> SpatialLocalizationCapture {
        .init(id: id, sessionID: session ?? gate.sessionID, binding: binding ?? ground, floorID: floorID,
              roomID: roomID, position: Point3(1, 0, 0), bodyYaw: yaw, source: source,
              headingSource: heading, trackingNormal: tracking, positionUncertainty: uncertainty,
              headingUncertainty: 0.1, capturedAt: time)
    }
    func assertPoint(_ actual: Point3, _ expected: Point3, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual.x, expected.x, accuracy: 1e-9, file: file, line: line)
        XCTAssertEqual(actual.y, expected.y, accuracy: 1e-9, file: file, line: line)
        XCTAssertEqual(actual.z, expected.z, accuracy: 1e-9, file: file, line: line)
    }
    func testRoundTripRetainsHierarchyMapsAndTransitions() throws {
        let source = try registry()
        let restored = try SpatialFrameRegistry(data: source.encodedSnapshot())
        XCTAssertEqual(restored.snapshot, source.snapshot)
        XCTAssertEqual(try restored.validateTransition(id: "lift"), transition)
    }
    func testRotatedRoomToBuildingAndSiblingFloor() throws {
        let source = try registry()
        assertPoint(try source.transform(from: ground, to: building).applying(to: Point3(1, 0, 0)), Point3(10, 0, -1))
        let transform = try source.transform(from: ground, to: upper)
        assertPoint(try transform.applying(to: Point3(1, 0, 0)), Point3(10, -3, -1))
        XCTAssertEqual(try transform.applying(toYaw: 0), .pi / 2, accuracy: 1e-9)
    }
    func testInverseAndCompositionPreservePositionAndHeading() throws {
        let transform = SpatialRigidTransform(translation: Point3(2, 3, 4), yaw: 0.7)
        let identity = try transform.inverted().composed(after: transform)
        assertPoint(try identity.applying(to: Point3(7, 8, 9)), Point3(7, 8, 9))
        XCTAssertEqual(try identity.applying(toYaw: 0.4), 0.4, accuracy: 1e-9)
    }
    func testMissingTransformNeverFallsBackToIdentity() throws {
        let source = try SpatialFrameRegistry(snapshot: snapshot(links: []))
        XCTAssertThrowsError(try source.transform(from: ground, to: upper))
        XCTAssertThrowsError(try source.validateTransition(id: "lift"))
        XCTAssertEqual(try source.transform(from: ground, to: ground), .identity)
    }
    func testMapLabelsOrSameFrameStringDoNotEstablishConnection() throws {
        let alias = SpatialMapBinding(mapID: "other-map", frameID: ground.frameID, revision: ground.revision)
        let record = SpatialMapRevision(binding: alias, nodeID: "room-0", metersPerUnit: 1, floorLevels: ["ground": "floor-0"])
        let source = try SpatialFrameRegistry(snapshot: snapshot(maps: maps + [record], active: [building, ground, upper, alias]))
        XCTAssertThrowsError(try source.transform(from: ground, to: alias))
    }
    func testMissingOrNonMetricScaleRejected() {
        for scale in [nil, 0, 0.01, 2, .infinity, .nan] as [Double?] {
            var altered = maps
            altered[1] = .init(binding: ground, nodeID: "room-0", metersPerUnit: scale, floorLevels: ["ground": "floor-0"])
            XCTAssertThrowsError(try SpatialFrameRegistry(snapshot: snapshot(maps: altered)))
        }
    }
    func testInvalidParentAndDuplicateNodeRejected() {
        var altered = nodes
        altered[4] = .init(id: "room-0", kind: .room, parentID: "building")
        XCTAssertThrowsError(try SpatialFrameRegistry(snapshot: snapshot(nodes: altered)))
        XCTAssertThrowsError(try SpatialFrameRegistry(snapshot: snapshot(nodes: nodes + [nodes[0]])))
    }
    func testFrameCyclesDuplicateParentAndNonfiniteTransformRejected() {
        let cycle = SpatialFrameLink(child: building, parent: ground, childToParent: .identity, source: "fixture")
        XCTAssertThrowsError(try SpatialFrameRegistry(snapshot: snapshot(links: links + [cycle])))
        XCTAssertThrowsError(try SpatialFrameRegistry(snapshot: snapshot(links: links + [links[0]])))
        let invalid = SpatialFrameLink(child: ground, parent: building,
                                       childToParent: .init(translation: Point3(0, 0, 0), yaw: .nan), source: "fixture")
        XCTAssertThrowsError(try SpatialFrameRegistry(snapshot: snapshot(links: [invalid])))
    }
    func testUnknownAndWrongFloorRejected() throws {
        let source = try registry()
        XCTAssertThrowsError(try source.validateFloor("unknown", in: ground))
        XCTAssertThrowsError(try source.validateFloor("floor-1", in: ground))
        XCTAssertThrowsError(try source.validateLocation(floorID: "floor-0", roomID: "room-1", in: ground))
        XCTAssertThrowsError(try source.validateLocation(floorID: "floor-0", roomID: nil, in: ground))
    }
    func testDoorwayCannotPretendToChangeFloor() {
        let doorway = SpatialTransition(id: "door", kind: .doorway, from: ground, to: upper,
                                         fromFloorID: "floor-0", toFloorID: "floor-1")
        XCTAssertThrowsError(try SpatialFrameRegistry(snapshot: snapshot(transitions: [doorway])))
    }
    func testNewRevisionRetainsHistoryAndRejectsOldBinding() throws {
        var source = try registry()
        let newer = SpatialMapBinding(mapID: ground.mapID, frameID: "ground-frame-2", revision: "2")
        let record = SpatialMapRevision(binding: newer, nodeID: "room-0", metersPerUnit: 1, floorLevels: ["ground": "floor-0"])
        try source.update(snapshot: snapshot(maps: maps + [record], active: [building, newer, upper]))
        XCTAssertEqual(source.snapshot.maps.count, 4)
        XCTAssertThrowsError(try source.map(for: ground))
        XCTAssertNoThrow(try source.map(for: newer))
        XCTAssertThrowsError(try source.transform(from: newer, to: building))
        XCTAssertThrowsError(try source.validateTransition(id: "lift"))
    }
    func testUpdateCannotRewriteOrDiscardMapHistoryOrTransform() throws {
        var source = try registry()
        XCTAssertThrowsError(try source.update(snapshot: snapshot(maps: Array(maps.dropLast()), active: [building, ground], links: [], transitions: [])))
        XCTAssertThrowsError(try source.update(snapshot: snapshot(links: [])))
        XCTAssertEqual(source.snapshot, snapshot())
    }
    func testIndoorMapAdapterUsesExplicitFloorAndPackageRevision() throws {
        let source = try registry()
        var map = IndoorMap(name: "fixture", nodes: [.init(id: "door", name: "door", level: "ground", position: Point3(0, 0, 0))], edges: [])
        XCTAssertThrowsError(try source.validateIndoorMap(map, for: ground))
        map.packageID = ground.mapID; map.packageRevision = ground.revision
        XCTAssertNoThrow(try source.validateIndoorMap(map, for: ground))
        map.nodes[0].level = "unknown"
        XCTAssertThrowsError(try source.validateIndoorMap(map, for: ground))
        map.nodes[0].level = "ground"; map.packageID = ground.mapID; map.packageRevision = "old"
        XCTAssertThrowsError(try source.validateIndoorMap(map, for: ground))
    }
    func testSavedWorldFrameCannotBeAttachedToUnrelatedFrame() {
        let saved = SavedWorldFrame(placeID: UUID().uuidString, revision: UUID().uuidString,
                                    worldMapSHA256: String(repeating: "a", count: 64), roomCaptureSHA256: String(repeating: "b", count: 64),
                                    originAnchorID: UUID().uuidString, capturedAt: Date(timeIntervalSince1970: 1))
        var altered = maps
        altered[1] = .init(binding: ground, nodeID: "room-0", metersPerUnit: 1,
                            floorLevels: ["ground": "floor-0"], savedWorldFrame: saved)
        XCTAssertThrowsError(try SpatialFrameRegistry(snapshot: snapshot(maps: altered)))
    }
    func testGPSAndRoomAppearanceNeverEstablishPose() throws {
        let source = try registry()
        for evidence in [SpatialLocalizationCapture.Source.coarseLocation, .roomAppearance] {
            var live = gate()
            XCTAssertThrowsError(try live.accept(capture(live, source: evidence), registry: source, now: 10))
            XCTAssertNil(live.current(registry: source, now: 10))
        }
    }
    func testFreshAlignedCaptureSupportsOnlyItsExactOutputBinding() throws {
        let source = try registry(); var live = gate()
        try live.accept(capture(live), registry: source, now: 10)
        for purpose in [SpatialOutputLease.Purpose.route, .collision] {
            let output = try live.output(purpose: purpose, binding: ground, floorID: "floor-0", registry: source, now: 10.1)
            XCTAssertTrue(live.permits(output, purpose: purpose, registry: source, now: 10.2))
            XCTAssertFalse(live.permits(output, purpose: purpose == .route ? .collision : .route, registry: source, now: 10.2))
            XCTAssertThrowsError(try live.output(purpose: purpose, binding: ground, floorID: "floor-1", registry: source, now: 10.2))
            XCTAssertFalse(live.permits(output, purpose: purpose, registry: source, now: 10.6))
            XCTAssertThrowsError(try live.output(purpose: purpose, binding: upper, floorID: "floor-1", registry: source, now: 10.2))
        }
    }
    func testCameraHeadingTrackingLossAndUncertaintyReject() throws {
        let source = try registry(); var live = gate()
        for bad in [capture(live, heading: .cameraOnly), capture(live, tracking: false),
                    capture(live, uncertainty: 1), capture(live, uncertainty: .nan), capture(live, yaw: .infinity)] {
            XCTAssertThrowsError(try live.accept(bad, registry: source, now: 10))
            XCTAssertNil(live.current(registry: source, now: 10))
        }
    }
    func testExpiredFutureAndWrongSessionCapturesReject() throws {
        let source = try registry(); var live = gate()
        for bad in [capture(live, time: 9), capture(live, time: 11), capture(live, time: .nan),
                    capture(live, session: UUID())] {
            XCTAssertThrowsError(try live.accept(bad, registry: source, now: 10))
        }
    }
    func testReplayAndRejectedNewObservationInvalidateCurrentPose() throws {
        let source = try registry(); var live = gate(); let first = capture(live)
        try live.accept(first, registry: source, now: 10)
        XCTAssertThrowsError(try live.accept(first, registry: source, now: 10.1))
        XCTAssertNil(live.current(registry: source, now: 10.1))
        try live.accept(capture(live, time: 10.2), registry: source, now: 10.2)
        XCTAssertThrowsError(try live.accept(capture(live, time: 10.3, source: .roomAppearance), registry: source, now: 10.3))
        XCTAssertNil(live.current(registry: source, now: 10.3))
    }
    func testNewCaptureInvalidatesQueuedOldResult() throws {
        let source = try registry(); var live = gate()
        try live.accept(capture(live), registry: source, now: 10)
        let old = try live.output(purpose: .route, binding: ground, floorID: "floor-0", registry: source, now: 10)
        try live.accept(capture(live, time: 10.1), registry: source, now: 10.1)
        XCTAssertFalse(live.permits(old, purpose: .route, registry: source, now: 10.1))
    }
    func testRevisionChangeInvalidatesPoseAndQueuedCollision() throws {
        var source = try registry(); var live = gate()
        try live.accept(capture(live), registry: source, now: 10)
        let output = try live.output(purpose: .collision, binding: ground, floorID: "floor-0", registry: source, now: 10)
        let newer = SpatialMapBinding(mapID: ground.mapID, frameID: ground.frameID, revision: "2")
        let record = SpatialMapRevision(binding: newer, nodeID: "room-0", metersPerUnit: 1, floorLevels: ["ground": "floor-0"])
        try source.update(snapshot: snapshot(maps: maps + [record], active: [building, newer, upper]))
        XCTAssertNil(live.current(registry: source, now: 10.1))
        XCTAssertFalse(live.permits(output, purpose: .collision, registry: source, now: 10.1))
    }
    func testRestartPreservesMapHistoryButNotPoseOrOldSessionAuthority() throws {
        let source = try registry(); var live = gate(); let old = capture(live)
        try live.accept(old, registry: source, now: 10)
        let restored = try SpatialFrameRegistry(data: source.encodedSnapshot())
        live.restart()
        XCTAssertEqual(restored.snapshot, source.snapshot)
        XCTAssertNil(live.current(registry: restored, now: 10))
        XCTAssertThrowsError(try live.accept(old, registry: restored, now: 10))
        XCTAssertNil(gate().current(registry: restored, now: 10))
    }
    func testExplicitTrackingLossRetiresOutputs() throws {
        let source = try registry(); var live = gate()
        try live.accept(capture(live), registry: source, now: 10)
        let output = try live.output(purpose: .route, binding: ground, floorID: "floor-0", registry: source, now: 10)
        live.loseTracking()
        XCTAssertFalse(live.permits(output, purpose: .route, registry: source, now: 10))
    }
    func testTrackingLossRejectsNewerInflightCaptureFromOldOwnership() throws {
        let source = try registry(); var live = gate()
        try live.accept(capture(live), registry: source, now: 10)
        let inFlight = capture(live, time: 10.1)
        live.loseTracking()
        XCTAssertThrowsError(try live.accept(inFlight, registry: source, now: 10.1))
        XCTAssertNil(live.current(registry: source, now: 10.1))
        try live.accept(capture(live, time: 10.2), registry: source, now: 10.2)
        XCTAssertNotNil(live.current(registry: source, now: 10.2))
    }
    func testCaptureIDReuseAfterReplayCacheRolloverCannotReviveOldLease() throws {
        let source = try registry(); var live = gate(); let originalID = UUID()
        try live.accept(capture(live, id: originalID), registry: source, now: 10)
        let output = try live.output(purpose: .route, binding: ground, floorID: "floor-0", registry: source, now: 10)
        for index in 1...2048 {
            let time = 10 + Double(index) * 0.01
            try live.accept(capture(live, time: time), registry: source, now: time)
        }
        try live.accept(capture(live, time: 31, id: originalID), registry: source, now: 31)
        XCTAssertNotNil(live.current(registry: source, now: 31))
        XCTAssertFalse(live.permits(output, purpose: .route, registry: source, now: 31))
    }
    func testSnapshotReplacementCannotReviveCaptureEvenWhenBindingMatches() throws {
        var source = try registry(); var live = gate()
        try live.accept(capture(live), registry: source, now: 10)
        let output = try live.output(purpose: .route, binding: ground, floorID: "floor-0", registry: source, now: 10)
        try source.update(snapshot: snapshot())
        XCTAssertNil(live.current(registry: source, now: 10.1))
        XCTAssertFalse(live.permits(output, purpose: .route, registry: source, now: 10.1))
    }
    func testIndependentAcceptanceInCopiedGateCannotShareOutputLease() throws {
        let source = try registry(); var first = gate(); var second = first
        let sharedCapture = capture(first)
        try first.accept(sharedCapture, registry: source, now: 10)
        try second.accept(sharedCapture, registry: source, now: 10)
        let output = try first.output(purpose: .route, binding: ground, floorID: "floor-0", registry: source, now: 10)
        XCTAssertTrue(first.permits(output, purpose: .route, registry: source, now: 10))
        XCTAssertFalse(second.permits(output, purpose: .route, registry: source, now: 10))
    }
    func testInvalidPolicyCannotAdmitCapture() throws {
        let source = try registry()
        var live = SpatialLocalizationLease(limits: .init(maximumPositionUncertainty: 0.25,
                                                          maximumHeadingUncertainty: 0.2, maximumCaptureAge: 99))
        XCTAssertThrowsError(try live.accept(capture(live), registry: source, now: 10))
    }
}
