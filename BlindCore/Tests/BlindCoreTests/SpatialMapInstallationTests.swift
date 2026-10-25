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
}
