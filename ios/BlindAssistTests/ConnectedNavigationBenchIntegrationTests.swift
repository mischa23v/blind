import Foundation
import XCTest
@testable import BlindCore
@testable import BlindAssist

/// Candidate hosted tests, not shipped app code. Positive evidence is AUTHORED
/// simulation only. Koivu anchors are source metadata and NEVER floor clearance.
/// No production release gate is removed; no speaker, camera or LLM is invoked.
private actor ConnectedBenchIO: ConnectedJourneyRuntimeIO {
    private var bytes: Data?
    func read() -> Data? { bytes }
    func write(_ payload: JourneyRuntimeWrite) throws { bytes = try payload.envelope().encoded() }
}

@MainActor final class ConnectedNavigationBenchIntegrationTests: XCTestCase {
    private typealias F = SpatialIntegrationFixture
    private let digest = String(repeating: "a", count: 64)
    private let identity: [Double] = [1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1]
    private enum WaitFailure: Error { case timedOut }
    /// ONLY test target can accept this explicitly authored contract fixture.
    private struct AuthoredBenchValidator: NativeLocalizationEvidenceValidator {
        func validate(_ m: NativeLocalizationMeasurements) -> NativeEvidenceValidation {
            m.operatingDomainID == "AUTHORED_BENCH_NOT_SENSOR" ? .independentlyValidated : .unvalidated
        }
    }
    private func until(_ condition: () -> Bool) async throws {
        let deadline = ProcessInfo.processInfo.systemUptime + 5
        while !condition() {
            guard ProcessInfo.processInfo.systemUptime < deadline else { throw WaitFailure.timedOut }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
    }
    private func fixtureInstallation() throws -> SpatialMapInstallation {
        let saved = SavedWorldFrame(placeID: UUID().uuidString, revision: UUID().uuidString,
            worldMapSHA256: digest, roomCaptureSHA256: digest, originAnchorID: UUID().uuidString,
            capturedAt: Date(timeIntervalSince1970: 1))
        var map = F.map(revision: saved.revision)
        map.packageID = "authored-connected-bench"
        let binding = SpatialMapBinding(mapID: map.packageID!, frameID: saved.frameID, revision: saved.revision)
        let nodes = F.nodes + [SpatialPlaceNode(id: "room", kind: .room, parentID: "floor")]
        let record = SpatialMapRevision(binding: binding, nodeID: "floor", metersPerUnit: 1,
            floorLevels: ["ground": "floor"], savedWorldFrame: saved)
        let snapshot = SpatialRegistrySnapshot(nodes: nodes, maps: [record], activeBindings: [binding])
        let bytes = try SpatialMapInstallation.canonicalMapBytes(map)
        return try .init(envelope: .init(snapshot: snapshot, binding: binding, mapBytes: bytes,
            artifactHistory: [.init(binding: binding, sha256: try F.sha256(bytes))]), sha256: F.sha256)
    }
    /// Import executes actual asynchronous IndoorNavigator storage/publication,
    /// then actual ConnectedJourneyRuntime catalog/IO; no copied map owner.
    private func installed(_ installation: SpatialMapInstallation) async throws -> (IndoorNavigator, ConnectedJourneyRuntime, URL) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let runtime = ConnectedJourneyRuntime(io: ConnectedBenchIO(), sha256: F.sha256)
        runtime.restore(); try await until { !runtime.loading }
        let navigator = IndoorNavigator(storage: directory.appendingPathComponent("map.json"), sha256: F.sha256)
        try await until { !navigator.mapIOPending }
        var publicationError: Error?
        navigator.onJourneyMapOwnershipWithdrawn = { _ in runtime.mapOwnershipWithdrawn() }
        navigator.onJourneyMapPublished = { _, installation, _, _ in
            do {
                if let installation { try runtime.install(installation) }
                else { runtime.mapPreviewPublished() }
            } catch { publicationError = error }
        }
        var completion: Result<Void, Error>?
        navigator.loadRegisteredInstallation(try installation.encoded()) { completion = $0 }
        try await until { completion != nil }
        try XCTUnwrap(completion).get()
        if let publicationError { throw publicationError }
        try await until { runtime.pendingMapWorkCount == 0 && runtime.pendingWriteCount == 0 }
        XCTAssertEqual(navigator.registeredJourneyInstallation?.artifact, installation.artifact)
        XCTAssertTrue(runtime.durable)
        return (navigator, runtime, directory)
    }
    private func measurements(_ candidate: NativeLocalizationCandidate, x: Double, omitSupport: Bool = false) -> NativeLocalizationMeasurements {
        let t = candidate.capturedAt
        let record = NativeEvidenceRecord(sourceID: "AUTHORED_TEST_ONLY", revision: "fixture-calibration",
            sha256: digest, protocolID: "not-physical-calibration", datasetID: "authored-not-Koivu",
            observedAt: t, expiresAt: t + 0.4)
        return .init(candidate: candidate, calibration: record, support: omitSupport ? nil : record,
            errorModel: record, operatingDomainID: "AUTHORED_BENCH_NOT_SENSOR", floorID: "floor",
            bodyPosition: .init(x, 1.3, 3), bodyYaw: -.pi/2, supportHeight: 0,
            supportHeightError: 0.02, coveredFootprintSHA256: digest,
            totalPositionError: 0.1, totalHeadingError: 0.1)
    }
    private func supply(_ router: NativeLocalizationRouter, runtime: ConnectedJourneyRuntime,
                        installation: SpatialMapInstallation, arSession: UUID, mount: UUID,
                        x: Double, time: Double, omitSupport: Bool = false) throws {
        let record = try installation.registry.map(for: installation.binding)
        router.offer(arSession: arSession, calibrationRevision: "fixture-calibration", mountRevision: mount,
            capturedAt: time, cameraToWorld: identity, trackingNormal: true,
            recovered: record.savedWorldFrame, now: time)
        let candidate = try XCTUnwrap(router.candidate)
        XCTAssertEqual(router.reason, .missingCalibration)
        XCTAssertThrowsError(try runtime.next(now: time)) // offer alone never releases directions
        let pair = try router.prepareForBench(measurements(candidate, x: x, omitSupport: omitSupport),
            arSession: arSession, calibrationRevision: "fixture-calibration", mountRevision: mount,
            validator: AuthoredBenchValidator(), now: time)
        XCTAssertEqual(pair.capture.id, candidate.id)
        XCTAssertEqual(pair.support.captureID, candidate.id)
        XCTAssertEqual(router.reason, .physicalReleaseNotApproved)
        // Explicit test-only bridge. No corresponding production call is added.
        try runtime.accept(pair.capture, support: pair.support, now: time)
    }
    func testAuthoredWholeOwnerChainRetiresFakeOutputOnHazardAndTrackingLoss() async throws {
        let installation = try fixtureInstallation()
        let (navigator, runtime, directory) = try await installed(installation)
        defer { _ = navigator; try? FileManager.default.removeItem(at: directory) }
        try runtime.configure(body: F.body, limits: F.limits)
        try runtime.setDestination(binding: installation.binding, nodeID: "end", origin: .trustedInterface)
        try await until { runtime.pendingWriteCount == 0 }
        _ = try runtime.beginLocalization(in: installation.binding)
        let router = NativeLocalizationRouter(journey: runtime, previewContext: { nil }, withholdPreview: { _, _ in XCTFail("unexpected preview fallback") })
        router.select(.connectedJourney)
        let arSession = UUID(), mount = UUID()
        try supply(router, runtime: runtime, installation: installation, arSession: arSession, mount: mount, x: 1, time: 10)
        try await until { runtime.pendingWriteCount == 0 }
        try supply(router, runtime: runtime, installation: installation, arSession: arSession, mount: mount, x: 1, time: 10.1)
        let ticket = try runtime.next(now: 10.1)
        XCTAssertNotNil(ticket.route.directionalCue())
        let message = try XCTUnwrap(SpatialRouteSpeech(ticket: ticket.route, arabic: false))
        let sink = SpatialRouteOutputController()
        var hazard: Hazard = .observing
        var fakeSpeech = [UUID](), fakeBeacon = [UUID](), stopped = [UUID]()
        var fakeSpeechText = [String]()
        sink.permits = { candidate, _ in hazard == .observing && runtime.permits(candidate, now: 10.1) }
        sink.stopSpeech = { stopped.append($0) }; sink.stopBeacon = { _ in }
        runtime.onOutputRetired = { sink.retire() }
        XCTAssertTrue(sink.deliver(message: message, goalRevision: ticket.route.goalRevision.uuidString,
            speech: { id, text in fakeSpeech.append(id); fakeSpeechText.append(text); return true }, beacon: { fakeBeacon.append($0); return true }))
        XCTAssertEqual(fakeSpeech.count, 1); XCTAssertEqual(fakeBeacon.count, 1)
        XCTAssertEqual(fakeSpeechText, [message.text])
        XCTAssertEqual(fakeSpeech, fakeBeacon)
        var detector = HazardDetector()
        hazard = detector.process(.init(timestamp: 10.1, camera: .init(1,1.3,3),
            forward: .init(1,0,0), samples: [], trackingNormal: false)).hazard
        XCTAssertEqual(hazard, .uncertain)
        sink.revalidate()
        XCTAssertNil(sink.active); XCTAssertEqual(stopped.count, 1)
        hazard = .observing
        XCTAssertTrue(sink.deliver(message: message, goalRevision: ticket.route.goalRevision.uuidString,
            speech: { id, text in fakeSpeech.append(id); fakeSpeechText.append(text); return true }, beacon: { fakeBeacon.append($0); return true }))
        XCTAssertEqual(fakeSpeechText, [message.text, message.text])
        XCTAssertEqual(fakeSpeech, fakeBeacon)
        router.invalidate(.trackingUnavailable)
        XCTAssertNil(sink.active)
        XCTAssertFalse(runtime.permits(ticket.route, now: 10.1))
        XCTAssertThrowsError(try runtime.next(now: 10.1))
        XCTAssertEqual(runtime.goal?.target.endpoint.nodeID, "end") // intent survives, authority doesn't
    }
    func testMissingSupportNeverReachesRuntimeAcceptance() async throws {
        let installation = try fixtureInstallation()
        let (navigator, runtime, directory) = try await installed(installation)
        defer { _ = navigator; try? FileManager.default.removeItem(at: directory) }
        try runtime.configure(body: F.body, limits: F.limits)
        try runtime.setDestination(binding: installation.binding, nodeID: "end", origin: .trustedInterface)
        try await until { runtime.pendingWriteCount == 0 }
        _ = try runtime.beginLocalization(in: installation.binding)
        let router = NativeLocalizationRouter(journey: runtime, previewContext: { nil }, withholdPreview: { _, _ in XCTFail() })
        router.select(.connectedJourney)
        XCTAssertThrowsError(try supply(router, runtime: runtime, installation: installation, arSession: UUID(),
            mount: UUID(), x: 1, time: 10, omitSupport: true)) {
            XCTAssertEqual($0 as? NativeLocalizationNotReady, .missingSupport)
        }
        XCTAssertThrowsError(try runtime.next(now: 10))
    }
    func testRecordedKoivuMetadataLoadsThroughOwnersWithoutInventingRegistrationOrFloor() async throws {
        let installation = try KoivuSourceAnchorBenchFixture.installation()
        let (navigator, runtime, directory) = try await installed(installation)
        defer { _ = navigator; try? FileManager.default.removeItem(at: directory) }
        XCTAssertEqual(navigator.map?.nodes.map(\.position), KoivuSourceAnchorBenchFixture.points)
        XCTAssertNil(navigator.map?.surfaces)
        XCTAssertEqual(navigator.map?.edges.count, 0)
        try runtime.configure(body: F.body, limits: F.limits)
        try runtime.setDestination(binding: installation.binding, nodeID: "anchor-1", origin: .trustedInterface)
        try await until { runtime.pendingWriteCount == 0 }
        _ = try runtime.beginLocalization(in: installation.binding)
        let router = NativeLocalizationRouter(journey: runtime, previewContext: { nil }, withholdPreview: { _, _ in XCTFail() })
        router.select(.connectedJourney)
        router.offer(arSession: UUID(), calibrationRevision: "NOT_MEASURED", mountRevision: UUID(),
            capturedAt: 10, cameraToWorld: identity, trackingNormal: true, recovered: nil, now: 10)
        XCTAssertEqual(router.reason, .importedFrameNeedsMeasuredRegistration)
        XCTAssertNil(router.candidate)
        XCTAssertThrowsError(try runtime.next(now: 10))
        XCTAssertEqual(runtime.goal?.target.endpoint.nodeID, "anchor-1")
    }
}
