import Foundation
import XCTest
@testable import BlindCore

final class SpatialMapInstallationTests: XCTestCase {
    typealias F = SpatialIntegrationFixture
    func testUsesRealSHA256KnownVector() throws {
        XCTAssertEqual(try F.sha256(Data("abc".utf8)), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }
    func testRoundTripPreservesExactMapBytesRegistryAndDigest() throws {
        let installed = try F.installation()
        let restored = try SpatialMapInstallation(data: installed.encoded(), sha256: F.sha256)
        XCTAssertEqual(installed.envelope.mapBytes, restored.envelope.mapBytes)
        XCTAssertEqual(installed.registry.snapshot, restored.registry.snapshot)
        XCTAssertEqual(installed.artifact, restored.artifact)
        XCTAssertNotEqual(installed.registry.installationID, restored.registry.installationID)
    }
    func testChangedGeometryWithOriginalHashRejectsDespiteSameIDs() throws {
        let installed = try F.installation(); var map = installed.map
        map.nodes[0].position.x = 7
        let tampered = SpatialMapInstallationEnvelope(snapshot: installed.registry.snapshot, binding: installed.binding,
            mapBytes: try SpatialMapInstallation.canonicalMapBytes(map), artifactHistory: installed.envelope.artifactHistory)
        XCTAssertThrowsError(try SpatialMapInstallation(envelope: tampered, sha256: F.sha256))
    }
    func testBodyClearanceAndKeepOutGeometryAreInDigest() throws {
        let original = try F.installation(); var altered = original.map
        altered.surfaces?[0].cells[0].clearance = 0.2
        XCTAssertNotEqual(try F.sha256(SpatialMapInstallation.canonicalMapBytes(altered)), original.artifact.sha256)
        altered = original.map
        altered.keepOutZones = [.init(id: "zone", name: "Zone", level: "ground", minX: 1, maxX: 2, minZ: 1, maxZ: 2)]
        XCTAssertNotEqual(try F.sha256(SpatialMapInstallation.canonicalMapBytes(altered)), original.artifact.sha256)
    }
    func testUntypedLegacyMapCannotBeRegisteredByPassingBinding() throws {
        let installed = try F.installation(); var legacy = installed.map
        legacy.packageID = nil; legacy.packageRevision = nil
        let bytes = try SpatialMapInstallation.canonicalMapBytes(legacy)
        let envelope = SpatialMapInstallationEnvelope(snapshot: installed.registry.snapshot, binding: installed.binding,
            mapBytes: bytes, artifactHistory: [.init(binding: installed.binding, sha256: try F.sha256(bytes))])
        XCTAssertThrowsError(try SpatialMapInstallation(envelope: envelope, sha256: F.sha256))
    }
    func testSameRevisionCannotReplaceGeometryEvenWithNewMatchingDigest() throws {
        let previous = try F.installation(); var changed = previous.map
        changed.nodes[0].position.x += 0.1
        let candidate = try F.installation(map: changed, prior: previous)
        XCTAssertThrowsError(try candidate.validateReplacement(of: previous))
    }
    func testNewRevisionRetainsArtifactAndRegistryHistory() throws {
        let previous = try F.installation()
        let candidate = try F.installation(map: F.map(revision: "r2"), prior: previous)
        XCTAssertNoThrow(try candidate.validateReplacement(of: previous))
        XCTAssertEqual(candidate.envelope.artifactHistory.count, 2)
        XCTAssertEqual(candidate.registry.snapshot.maps.count, 2)
    }
    func testFailedAtomicWritePreservesOldMapPoseAndTicket() throws {
        var (owner, support) = try F.prepared()
        let ticket = try owner.next(support: support, now: 10)
        let previous = try XCTUnwrap(owner.installation)
        let candidate = try F.installation(map: F.map(revision: "r2"), prior: previous)
        enum DiskFailure: Error { case full }
        XCTAssertThrowsError(try owner.install(candidate, persist: { _ in throw DiskFailure.full }))
        XCTAssertEqual(owner.installation?.binding, previous.binding)
        XCTAssertEqual(owner.installation?.registry.installationID, previous.registry.installationID)
        XCTAssertTrue(owner.permits(ticket, now: 10.1))
    }
    func testAtomicFileRoundTripRestoresHistoryButNotPoseOrRoute() throws {
        var (owner, support) = try F.prepared()
        let oldTicket = try owner.next(support: support, now: 10)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("installation.json")
        let previous = try XCTUnwrap(owner.installation)
        let next = try F.installation(map: F.map(revision: "r2"), prior: previous)
        try owner.install(next, persist: { try $0.write(to: url, options: .atomic) })
        XCTAssertFalse(owner.permits(oldTicket, now: 10))
        var restored = try SpatialRouteOwner(body: F.body, limits: F.limits)
        try restored.restore(Data(contentsOf: url), sha256: F.sha256)
        XCTAssertEqual(restored.installation?.envelope.artifactHistory.count, 2)
        XCTAssertNil(restored.currentPose(now: 10)); XCTAssertTrue(restored.route.isEmpty)
        XCTAssertFalse(restored.permits(oldTicket, now: 10))
        XCTAssertThrowsError(try restored.restore(previous.encoded(), sha256: F.sha256))
    }
    func testDigestProviderFailureCannotInstallAnything() throws {
        let installation = try F.installation()
        XCTAssertThrowsError(try SpatialMapInstallation(envelope: installation.envelope, sha256: { _ in "not-a-sha" }))
    }
    private func referenceFixture() throws -> (SavedWorldFrame, Data, Data) {
        // Authored byte-binding fixture only, NOT an archived ARWorldMap/RoomPlan scan.
        let world = Data("authored-local-world-pair".utf8), room = Data("authored-room-pair".utf8)
        return (SavedWorldFrame(placeID: UUID().uuidString, revision: UUID().uuidString,
            worldMapSHA256: try F.sha256(world), roomCaptureSHA256: try F.sha256(room),
            originAnchorID: UUID().uuidString, capturedAt: Date(timeIntervalSince1970: 1)), world, room)
    }
    func testLocalSavedReferenceRetainsExactPairButNoNodesEdgesFloorOrMovement() throws {
        let (frame, world, room) = try referenceFixture()
        let reference = try SpatialMapInstallation.localSavedFrameReference(frame: frame,
            worldMapBytes: world, roomCaptureBytes: room, sha256: F.sha256)
        XCTAssertEqual(reference.map.purpose, .localizationReferenceOnly)
        XCTAssertFalse(reference.map.permitsRoutePlanning)
        XCTAssertTrue(reference.map.nodes.isEmpty); XCTAssertTrue(reference.map.edges.isEmpty)
        XCTAssertNil(reference.map.surfaces); XCTAssertNil(reference.map.keepOutZones)
        let record = try reference.registry.map(for: reference.binding)
        XCTAssertEqual(record.savedWorldFrame, frame); XCTAssertTrue(record.floorLevels.isEmpty)
        XCTAssertEqual(reference.registry.snapshot.nodes.map(\.kind), [.world, .place])
        XCTAssertTrue(reference.registry.snapshot.links.isEmpty)
        XCTAssertTrue(reference.registry.snapshot.transitions.isEmpty)
        let restored = try SpatialMapInstallation(data: reference.encoded(), sha256: F.sha256)
        XCTAssertEqual(restored.artifact, reference.artifact)
        XCTAssertEqual(restored.map.purpose, .localizationReferenceOnly)
        // Reject even same-node shortcut and direct route-owner adoption.
        XCTAssertThrowsError(try restored.map.route(from: "same", to: "same"))
        XCTAssertThrowsError(try restored.map.route(from: "a", to: "b"))
        var owner = try SpatialRouteOwner(body: F.body, limits: F.limits)
        XCTAssertThrowsError(try owner.restoreValidated(restored))
        XCTAssertThrowsError(try owner.install(restored, persist: { _ in XCTFail("must not persist navigation") }))
        XCTAssertNil(owner.installation)
        XCTAssertThrowsError(try ConnectedJourneyCatalog(registry: restored.registry, installations: [restored], portals: []))
    }
    func testReferenceConstructorRejectsWrongPrivatePairAndInvalidGraphPromotion() throws {
        let (frame, world, room) = try referenceFixture()
        XCTAssertThrowsError(try SpatialMapInstallation.localSavedFrameReference(frame: frame,
            worldMapBytes: room, roomCaptureBytes: room, sha256: F.sha256))
        XCTAssertThrowsError(try SpatialMapInstallation.localSavedFrameReference(frame: frame,
            worldMapBytes: world, roomCaptureBytes: world, sha256: F.sha256))
        let reference = try SpatialMapInstallation.localSavedFrameReference(frame: frame,
            worldMapBytes: world, roomCaptureBytes: room, sha256: F.sha256)
        var injected = reference.map
        injected.nodes = [.init(id: "table-centre", name: "Not a waypoint", level: "guessed", position: .init(0, 1, 0))]
        XCTAssertThrowsError(try injected.validate())
        injected = reference.map; injected.purpose = nil
        XCTAssertThrowsError(try injected.validate()) // Empty legacy graph stays invalid.
        var legacy = F.map()
        XCTAssertNil(legacy.purpose); XCTAssertTrue(legacy.permitsRoutePlanning)
        let oldBytes = try SpatialMapInstallation.canonicalMapBytes(legacy)
        XCTAssertFalse(String(decoding: oldBytes, as: UTF8.self).contains("purpose"))
        legacy = try JSONDecoder().decode(IndoorMap.self, from: oldBytes)
        XCTAssertNil(legacy.purpose); XCTAssertTrue(legacy.permitsRoutePlanning)
        XCTAssertNoThrow(try legacy.route(from: "start", to: "end", body: F.body))
    }

}
