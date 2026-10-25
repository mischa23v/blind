import Foundation
import XCTest
@testable import BlindCore
#if canImport(NativeSpatialAdapter)
@testable import NativeSpatialAdapter
#else
@testable import BlindAssist
#endif

/// Runs the real native storage/ownership adapter on Foundation with injected real
/// SHA-256. Synthetic map/pose/support only; no Apple sensor/audio SDK execution.
final class RegisteredIndoorNavigationTests: XCTestCase {
    typealias F = SpatialIntegrationFixture
    var directory: URL!
    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }
    func adapter() -> RegisteredIndoorNavigation {
        .init(storage: directory.appendingPathComponent("registered.json"), sha256: F.sha256)
    }
    func ready() throws -> RegisteredIndoorNavigation {
        let adapter = adapter()
        try adapter.install(F.installation().encoded())
        try adapter.configure(body: F.body, limits: F.limits)
        try adapter.plan(from: "start", to: "end", goal: UUID())
        let capture = SpatialLocalizationCapture(sessionID: try XCTUnwrap(adapter.sessionID),
            binding: try XCTUnwrap(adapter.installation).binding, floorID: "floor", position: Point3(1, 1.3, 3), bodyYaw: -.pi / 2,
            source: .alignedMapPose, headingSource: .bodyAligned, trackingNormal: true,
            positionUncertainty: 0.1, headingUncertainty: 0.1, capturedAt: 10)
        try adapter.accept(capture, floorSupport: F.support(capture), now: 10)
        return adapter
    }
    func testActualAdapterPersistsEnvelopeAndRestoresNoAuthority() throws {
        let first = try ready(); let ticket = try first.next(now: 10)
        XCTAssertTrue(first.permits(ticket, now: 10))
        let restored = adapter(); try restored.restore()
        XCTAssertEqual(restored.installation?.artifact, first.installation?.artifact)
        XCTAssertNil(restored.currentPose(now: 10))
        XCTAssertFalse(restored.permits(ticket, now: 10))
        XCTAssertThrowsError(try restored.next(now: 10))
    }
    func testGoalCancellationRetiresOnlyHeldRouteOutputAndKeepsPose() throws {
        let adapter = try ready(); var retirements = 0
        adapter.onOutputRetired = { retirements += 1 }
        let ticket = try adapter.next(now: 10), session = adapter.sessionID
        adapter.cancelRoute()
        XCTAssertEqual(retirements, 1)
        XCTAssertFalse(adapter.permits(ticket, now: 10))
        XCTAssertEqual(adapter.sessionID, session)
        XCTAssertNotNil(adapter.currentPose(now: 10))
    }
    func testExpiryWithdrawsHeldOutputWithoutAnotherSensorCallback() throws {
        let adapter = try ready(); var retirements = 0
        adapter.onOutputRetired = { retirements += 1 }
        _ = try adapter.next(now: 10)
        adapter.revalidate(now: 10.6); adapter.revalidate(now: 11)
        XCTAssertEqual(retirements, 1)
    }
    func testMapReplacementAndSessionLossNotifyRouteOutputRetirement() throws {
        let adapter = try ready(); var retirements = 0
        adapter.onOutputRetired = { retirements += 1 }
        let old = try adapter.next(now: 10)
        try adapter.install(F.installation(map: F.map(revision: "r2"), prior: adapter.installation).encoded())
        XCTAssertEqual(retirements, 1); XCTAssertFalse(adapter.permits(old, now: 10))
        XCTAssertNil(adapter.currentPose(now: 10))
        let second = try ready(); var lost = 0
        second.onOutputRetired = { lost += 1 }; _ = try second.next(now: 10)
        second.loseTracking()
        XCTAssertEqual(lost, 1); XCTAssertNil(second.currentPose(now: 10))
    }
    func testLegacyImportCannotKeepRegisteredAuthority() throws {
        let adapter = try ready(); let old = try adapter.next(now: 10)
        adapter.clearForLegacyImport()
        XCTAssertNil(adapter.installation); XCTAssertFalse(adapter.permits(old, now: 10))
        XCTAssertThrowsError(try adapter.next(now: 10))
    }
    func testReconfigureOrRestoreCannotEraseRestrictionsInActiveOwner() throws {
        let adapter = try ready()
        try adapter.addRestrictions(binding: XCTUnwrap(adapter.installation).binding,
                                    blocked: [MapConnection("start", "middle")], zones: [])
        XCTAssertThrowsError(try adapter.configure(body: F.body, limits: F.limits))
        XCTAssertThrowsError(try adapter.restore())
        XCTAssertThrowsError(try adapter.plan(from: "start", to: "end", goal: UUID()))
    }
    func testReportedBlockedNextLegIsAppliedToRegisteredPlanner() throws {
        let adapter = try ready(); var retirements = 0
        adapter.onOutputRetired = { retirements += 1 }
        let ticket = try adapter.next(now: 10)
        XCTAssertThrowsError(try adapter.blockNextLegAndReplan()) // This authored fixture has no alternative.
        XCTAssertEqual(retirements, 1)
        XCTAssertTrue(adapter.route.isEmpty)
        XCTAssertFalse(adapter.permits(ticket, now: 10))
        XCTAssertThrowsError(try adapter.plan(from: "start", to: "end", goal: UUID()))
    }

    func testReportedClosureSurvivesRestoreAndReconfiguration() throws {
        let first = try ready()
        try first.addRestrictions(binding: XCTUnwrap(first.installation).binding,
                                  blocked: [MapConnection("middle", "end")], zones: [])
        let restored = adapter(); try restored.restore()
        try restored.configure(body: F.body, limits: F.limits)
        XCTAssertThrowsError(try restored.plan(from: "start", to: "end", goal: UUID()))
        XCTAssertNil(restored.currentPose(now: 10))
        XCTAssertEqual(restored.installation?.currentRestrictions.blocked, [SpatialBlockedEdge(MapConnection("middle", "end"))])
    }

    func testUnconfiguredImportedMapCanPersistAvoidanceWithoutInventingPosePolicy() throws {
        let first = adapter(); try first.install(F.installation().encoded())
        XCTAssertFalse(first.configured)
        try first.addRestrictions(binding: XCTUnwrap(first.installation).binding,
                                  blocked: [MapConnection("middle", "end")], zones: [])
        XCTAssertFalse(first.configured); XCTAssertNil(first.currentPose(now: 10))
        let restored = adapter(); try restored.restore()
        try restored.configure(body: F.body, limits: F.limits)
        XCTAssertThrowsError(try restored.plan(from: "start", to: "end", goal: UUID()))
    }
    func testUnconfiguredFailedRestrictionSaveCannotGainAuthorityByConfigure() throws {
        let parent = directory.appendingPathComponent("active"), backup = directory.appendingPathComponent("backup")
        let first = RegisteredIndoorNavigation(storage: parent.appendingPathComponent("map.json"), sha256: F.sha256)
        try first.install(F.installation().encoded())
        try FileManager.default.moveItem(at: parent, to: backup)
        try Data("Synthetic storage failure fixture".utf8).write(to: parent)
        let binding = try XCTUnwrap(first.installation).binding
        XCTAssertThrowsError(try first.addRestrictions(binding: binding, blocked: [MapConnection("middle", "end")], zones: []))
        XCTAssertThrowsError(try first.configure(body: F.body, limits: F.limits))
        XCTAssertFalse(first.configured)
        try FileManager.default.removeItem(at: parent)
        try FileManager.default.moveItem(at: backup, to: parent)
        try first.addRestrictions(binding: binding, blocked: [], zones: []) // Retry keeps positive restriction.
        try first.configure(body: F.body, limits: F.limits)
        XCTAssertThrowsError(try first.plan(from: "start", to: "end", goal: UUID()))
    }

    func testEnvelopeLargerThanLegacyMapLimitLoadsWithExactBytes() throws {
        let original = try F.installation()
        // Valid JSON trailing whitespace preserves exact bytes/digest. Synthetic
        // bounded fixture exercises base64 envelope overhead, not a real venue.
        let bytes = original.envelope.mapBytes + Data(repeating: 0x20, count: 1_550_000)
        XCTAssertLessThan(bytes.count, SpatialMapInstallation.maximumMapBytes)
        let envelope = SpatialMapInstallationEnvelope(snapshot: original.registry.snapshot,
            binding: original.binding, mapBytes: bytes,
            artifactHistory: [.init(binding: original.binding, sha256: try F.sha256(bytes))])
        let installation = try SpatialMapInstallation(envelope: envelope, sha256: F.sha256)
        let encoded = try installation.encoded()
        XCTAssertGreaterThan(encoded.count, SpatialMapInstallation.maximumMapBytes)
        XCTAssertLessThan(encoded.count, SpatialMapInstallation.maximumEnvelopeBytes)
        let first = adapter(); try first.install(encoded)
        let restored = adapter(); try restored.restore()
        XCTAssertEqual(restored.installation?.envelope.mapBytes, bytes)
        XCTAssertNil(restored.currentPose(now: 10))
    }

}

#if canImport(BlindAssist)
/// Hosted Apple-only tests of the actual JSON-import/IndoorNavigator caption path.
/// Synthetic uncertainty/support are fixture inputs, never a production issuer.
final class RegisteredIndoorNavigatorCaptionTests: XCTestCase {
    func ready(_ file: URL) throws -> IndoorNavigator {
        let nav = IndoorNavigator(storage: file), map = try SpatialIntegrationFixture.installation()
        try nav.loadImportedMap(map.encoded())
        try nav.configureRegisteredNavigation(body: SpatialIntegrationFixture.body, limits: SpatialIntegrationFixture.limits)
        try nav.plan(from: "start", to: "end", goalRevision: UUID())
        let now = ProcessInfo.processInfo.systemUptime
        let capture = SpatialLocalizationCapture(sessionID: try XCTUnwrap(nav.registeredSessionID),
            binding: map.binding, floorID: "floor", position: Point3(1, 1.3, 3), bodyYaw: -.pi / 2,
            source: .alignedMapPose, headingSource: .bodyAligned, trackingNormal: true,
            positionUncertainty: 0.1, headingUncertainty: 0.1, capturedAt: now)
        try nav.acceptRegisteredCapture(capture, support: SpatialIntegrationFixture.support(capture), now: now)
        XCTAssertNotNil(nav.next(camera: Point3(0, 0, 0), forward: Point3(0, 0, -1)))
        return nav
    }
    func testExpiredRouteCaptionIsWithdrawn() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let nav = try ready(directory.appendingPathComponent("map.json")), old = nav.message
        nav.revalidateSpatialOutput(now: ProcessInfo.processInfo.systemUptime + 1)
        XCTAssertNotEqual(nav.message, old)
        XCTAssertEqual(nav.message, "Previous route cue withdrawn. Request fresh guidance.")
    }
    func testExpiredRouteCannotOverwriteNewDestinationSuggestion() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let nav = try ready(directory.appendingPathComponent("map.json"))
        var retirements = 0; nav.onSpatialOutputRetired = { retirements += 1 }
        nav.suggestDestination(id: "end"); let suggestion = nav.message
        nav.revalidateSpatialOutput(now: ProcessInfo.processInfo.systemUptime + 1)
        XCTAssertEqual(nav.message, suggestion); XCTAssertEqual(retirements, 1)
    }
}
#endif
