import Foundation
import XCTest
@testable import MeshSnapshot82
import MeshCandidateIngress83
import BlindRoomMesh
#if os(iOS) && canImport(ARKit)
import ARKit
#endif

/// Synthetic owned geometry through the real82→81→83→75 dependencies. No session,
/// captured room, calibrated body/support evidence, or movement output is involved.
final class ClassificationIngressTests: XCTestCase {
    private let identity: [Float] = [1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1]
    private let vertices: [Float] = [-3,0,-3,-3,0,3,3,0,3,3,0,-3]
    private let indices: [UInt8] = [0,0,1,0,2,0,0,0,2,0,3,0]
    private final class Box<T>: @unchecked Sendable {
        private let lock = NSLock()
        private var value: T?
        func put(_ value: T) { lock.lock(); self.value = value; lock.unlock() }
        func get() -> T? { lock.lock(); defer { lock.unlock() }; return value }
    }
    private func plane(_ c: MeshSnapshot82.Context, _ id: UUID, labels: [UInt8]?,
                       x: Float = 0, y: Float = 0, shortClassificationBytes: Bool = false) -> MeshSnapshot82.Capture {
        let bytes = vertices.flatMap { value in
            (0..<4).map { UInt8(truncatingIfNeeded: value.bitPattern >> ($0 * 8)) }
        }
        let descriptor: MeshSnapshot82.Descriptor? = labels.map {
            .init(count: $0.count, offset: 0, stride: 1, bufferLength: $0.count, format: .uint8)
        }
        do {
            let plan = try MeshSnapshot82.preflight(context: c,
                vertices: .init(count: 4, offset: 0, stride: 12, bufferLength: bytes.count, format: .float3),
                indices: .init(count: 6, offset: 0, stride: 2, bufferLength: indices.count, format: .uint16),
                classification: descriptor)
            var transform = identity; transform[12] = x; transform[13] = y
            return .owned(.init(context: c, anchorID: id, plan: plan, vertexBytes: bytes, indexBytes: indices,
                classificationBytes: shortClassificationBytes ? [] : labels, transform: transform))
        } catch {
            return .unknownGap(.init(context: c, anchorID: id,
                reason: (error as? MeshSnapshot82.Failure) ?? .invalidDescriptor))
        }
    }
#if DEBUG
    /// Runs only on the separate bounded diagnostic queue, never the timed
    /// result callback. No runtime/owner/geometry capture is needed by the sink.
    private static func cpuReceipt(id: UUID, rows: [RoomMeshCandidateRuntime.DiagnosticStageReceipt]) {
        func pair(_ begin: RoomMeshCandidateRuntime.DiagnosticStage,
                  _ end: RoomMeshCandidateRuntime.DiagnosticStage) -> (Int, Int64, Bool) {
            guard let a = rows.first(where: { $0.stage == begin }),
                  let b = rows.first(where: { $0.stage == end }),
                  b.elapsedMilliseconds >= a.elapsedMilliseconds else { return (-1, -1, false) }
            let wall = b.elapsedMilliseconds - a.elapsedMilliseconds
            guard let at = a.workerThreadID, let bt = b.workerThreadID, at == bt,
                  let ac = a.workerCPUTimeMicroseconds, let bc = b.workerCPUTimeMicroseconds,
                  bc >= ac else { return (wall, -1, false) }
            return (wall, bc - ac, true)
        }
        let began = rows.first(where: { $0.stage == .workerStarted })?.elapsedMilliseconds ?? -1
        let maxLockWait = rows.map(\.diagnosticLockWaitMicroseconds).max() ?? 0
        print("CLASSIFICATION_DIAGNOSTIC_LOCK lane=ingress83 records=\(rows.count) max_wait_us=\(maxLockWait)")
        let worker = pair(.workerStarted, .workerFinished)
        let build = pair(.nativeBuildBegin, .nativeBuildEnd)
        let route = pair(.routeBegin, .routeEnd)
        let retired = rows.contains { $0.stage == .requestRetired }
        let failed = rows.contains { $0.stage == .nativeFailure }
        // Missing/mismatched clocks are -1/false, not evidence of zero CPU.
        print("CLASSIFICATION_WORKER_CPU id=\(id.uuidString) worker_begin_ms=\(began) lane=ingress83 worker_wall_ms=\(worker.0) worker_cpu_us=\(worker.1) worker_pair_valid=\(worker.2) build_wall_ms=\(build.0) build_cpu_us=\(build.1) build_pair_valid=\(build.2) route_wall_ms=\(route.0) route_cpu_us=\(route.1) route_pair_valid=\(route.2) retired=\(retired) native_failed=\(failed) records=\(rows.count)")
    }
#endif
    private func makeOwner(supportPolicy: MeshSupportPolicy = .legacySlope,
                           decodeQueue: DispatchQueue) throws -> MeshCandidateIngress83 {
#if DEBUG
        try MeshCandidateIngress83(supportPolicy: supportPolicy,
            captureSyntheticTestTiming: true, syntheticTimingCompletion: { Self.cpuReceipt(id: $0, rows: $1) },
            decodeQueue: decodeQueue)
#else
        try MeshCandidateIngress83(supportPolicy: supportPolicy, decodeQueue: decodeQueue)
#endif
    }
    private enum TimingEvent: String { case submitted, callback, waitFinished, failureDiscardCompleted, discardCompleted }
    private static func timingReceipt(_ owner: MeshCandidateIngress83, event: TimingEvent,
                                      queryID: UUID, submittedAt: TimeInterval) {
#if DEBUG
        guard let runtimeID = owner.diagnosticReceiptID else { return }
        let stages = owner.diagnosticStageReceipts.map { "\($0.stage.rawValue):\($0.elapsedMilliseconds)" }.joined(separator: ";")
        let elapsed = max(0, Int((ProcessInfo.processInfo.systemUptime - submittedAt) * 1_000))
        // Random diagnostic IDs and closed stage names only; no geometry,
        // session/anchor identity or arbitrary error text. Stage clocks are owner-
        // relative; elapsed_ms is query-relative. Thread flag is not an actor proof.
        print("CLASSIFICATION_INGRESS_TIMING query=\(queryID.uuidString) runtime=\(runtimeID.uuidString) event=\(event.rawValue) elapsed_ms=\(elapsed) main_thread=\(Thread.isMainThread) stages=\(stages)")
#endif
    }
    private func query(_ owner: MeshCandidateIngress83, x: Float = 0) async throws
        -> Result<MeshCandidateIngress83.Candidate, MeshCandidateIngress83.Failure> {
        let done = expectation(description: "real dependency candidate callback")
        let box = Box<Result<MeshCandidateIngress83.Candidate, MeshCandidateIngress83.Failure>>()
        let queryID = UUID(), submittedAt = ProcessInfo.processInfo.systemUptime
        Self.timingReceipt(owner, event: .submitted, queryID: queryID, submittedAt: submittedAt)
        owner.request(start: [-2+x,0,0], goal: [2+x,0,0], body: try .init(radius: 0.225, height: 1.75)) {
            // Completion critical path: no stdout, receipt snapshot or formatting.
            box.put($0)
            done.fulfill()
        }
        await fulfillment(of: [done], timeout: 10)
        Self.timingReceipt(owner, event: .waitFinished, queryID: queryID, submittedAt: submittedAt)
        guard let value = box.get() else {
            owner.stopAndDiscard {} // Fence on timeout; no late result becomes a passing assertion.
            throw MeshCandidateIngress83.Failure.unavailable
        }
        return value
    }
    private func discard(_ owner: MeshCandidateIngress83) async {
        let done = expectation(description: "acknowledged owned/native discard")
        let queryID = UUID(), submittedAt = ProcessInfo.processInfo.systemUptime
        owner.stopAndDiscard { done.fulfill() }
        await fulfillment(of: [done], timeout: 10)
        Self.timingReceipt(owner, event: .waitFinished, queryID: queryID, submittedAt: submittedAt)
    }
    private func assertNoCandidate(_ result: Result<MeshCandidateIngress83.Candidate, MeshCandidateIngress83.Failure>,
                                   file: StaticString = #filePath, line: UInt = #line) {
        switch result {
        case .failure(.runtime(.nativeFailure)): break // Actual native no-route/build refusal.
        default: XCTFail("Expected native refusal, not a candidate or lifecycle/admission failure", file: file, line: line)
        }
    }
    private func assertNonphysical(_ candidate: MeshCandidateIngress83.Candidate,
                                   file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(candidate.physicalAuthority, file: file, line: line)
        XCTAssertFalse(candidate.coverageKnown, file: file, line: line)
        XCTAssertFalse(candidate.route.authorizesPhysicalGuidance, file: file, line: line)
        XCTAssertFalse(candidate.route.actualWorldCoverageKnown, file: file, line: line)
        XCTAssertFalse(candidate.route.rawDepthHazardImplemented, file: file, line: line)
        XCTAssertTrue(candidate.route.rawDepthHazardVeto, file: file, line: line)
    }
    func testActualDecoderPreservesKnownLabelsAndDoesNotGuessMissingOrUnsupported() throws {
        let c = MeshSnapshot82.Context(sessionID: UUID(), generation: 1, revision: 1, receiptUptime: 1)
        for raw in UInt8.min...UInt8.max {
            guard case .revision(_, _, let mesh) = MeshSnapshot82.decode(plane(c, UUID(), labels: [raw,raw])) else {
                return XCTFail("Valid owned geometry unexpectedly refused")
            }
            XCTAssertEqual(mesh.classifications, raw <= 7 ? [raw,raw] : [nil,nil])
            XCTAssertEqual(mesh.triangleIndices.count, 6)
            XCTAssertEqual(mesh.classificationDiagnostics.isEmpty, raw <= 7)
        }
        for capture in [plane(c, UUID(), labels: nil), plane(c, UUID(), labels: [2,2], shortClassificationBytes: true)] {
            guard case .revision(_, _, let mesh) = MeshSnapshot82.decode(capture) else { return XCTFail("Expected conservative geometry retention") }
            XCTAssertEqual(mesh.classifications, [nil,nil]); XCTAssertFalse(mesh.classificationDiagnostics.isEmpty)
        }
        if case .unknownGap = plane(c, UUID(), labels: [2]) {} else { XCTFail("Malformed face count must fail82 preflight") }
    }
    func testClassifiedFloorUsesRealRuntimeAndTransformOnceWithoutPhysicalAuthority() async throws {
        let queue = DispatchQueue(label: "classification.test.floor"), id = UUID()
        let owner = try makeOwner(supportPolicy: .classifiedFloorOnly, decodeQueue: queue)
        defer { owner.stopAndDiscard {} }
        XCTAssertTrue(owner.ingest(anchorID: id, receiptUptime: 1) { plane($0, id, labels: [2,2], x: 10) })
        queue.sync {}
        let candidate = try await query(owner, x: 10).get()
        XCTAssertTrue(candidate.route.complete); XCTAssertTrue(candidate.route.sourceDeliveryComplete)
        XCTAssertTrue(owner.isCurrent(candidate)); XCTAssertEqual(candidate.route.projectedStart[0], 8, accuracy: 0.5)
        assertNonphysical(candidate)
        await discard(owner)
    }
    func testDefaultLegacyPolicyKeepsExistingUnclassifiedDiagnosticBehavior() async throws {
        let queue = DispatchQueue(label: "classification.test.legacy"), id = UUID()
        let owner = try makeOwner(decodeQueue: queue) // Deliberately no opt-in.
        defer { owner.stopAndDiscard {} }
        XCTAssertTrue(owner.ingest(anchorID: id, receiptUptime: 1) { plane($0, id, labels: nil) })
        queue.sync {}
        let candidate = try await query(owner).get()
        XCTAssertTrue(candidate.route.complete); XCTAssertTrue(candidate.route.sourceDeliveryComplete)
        assertNonphysical(candidate)
        await discard(owner)
    }
    func testKnownNonFloorMissingNoneAndUnsupportedNeverPromoteUpwardPlanes() async throws {
        // Positive control is the separate floor test; identical geometry is used here.
        let labels: [UInt8?] = [nil,0,1,3,4,5,6,7,8,255]
        for label in labels {
            let queue = DispatchQueue(label: "classification.test.non-floor"), id = UUID()
            let owner = try makeOwner(supportPolicy: .classifiedFloorOnly, decodeQueue: queue)
            defer { owner.stopAndDiscard {} }
            XCTAssertTrue(owner.ingest(anchorID: id, receiptUptime: 1) { plane($0, id, labels: label.map { [$0,$0] }) })
            queue.sync {}
            assertNoCandidate(try await query(owner))
            await discard(owner)
        }
    }
    func testKnownTableGeometryRemainsObstacleAndRemovalCanRestoreFloorCandidate() async throws {
        let queue = DispatchQueue(label: "classification.test.obstacle-retention"), floor = UUID(), table = UUID()
        let owner = try makeOwner(supportPolicy: .classifiedFloorOnly, decodeQueue: queue)
        defer { owner.stopAndDiscard {} }
        XCTAssertTrue(owner.ingest(anchorID: floor, receiptUptime: 1) { plane($0, floor, labels: [2,2]) })
        queue.sync {}; let clearFixture = try await query(owner).get()
        XCTAssertTrue(clearFixture.route.complete) // Synthetic baseline only, not live clearance.
        // Same footprint, half a metre overhead: dropping non-floor faces would leave
        // the baseline candidate, whereas retaining/rasterizing them removes headroom.
        XCTAssertTrue(owner.ingest(anchorID: table, receiptUptime: 2) { plane($0, table, labels: [4,4], y: 0.5) })
        queue.sync {}; assertNoCandidate(try await query(owner))
        XCTAssertTrue(owner.remove(anchorID: table, receiptUptime: 3))
        let restored = try await query(owner).get()
        XCTAssertTrue(restored.route.complete); XCTAssertFalse(restored.route.sourceDeliveryComplete)
        XCTAssertTrue(restored.route.unknownCoverage.contains("removed:" + table.uuidString))
        assertNonphysical(restored)
        await discard(owner)
    }
    func testMissingReplacementRemovesPriorFloorAndValidRevisionRecoversButGapStays() async throws {
        let queue = DispatchQueue(label: "classification.test.recovery"), id = UUID()
        let owner = try makeOwner(supportPolicy: .classifiedFloorOnly, decodeQueue: queue)
        defer { owner.stopAndDiscard {} }
        XCTAssertTrue(owner.ingest(anchorID: id, receiptUptime: 1) { plane($0, id, labels: [2,2]) })
        queue.sync {}; let old = try await query(owner).get()
        XCTAssertTrue(owner.ingest(anchorID: id, receiptUptime: 2) {
            XCTAssertFalse(owner.isCurrent(old)); return plane($0, id, labels: nil)
        })
        queue.sync {}; assertNoCandidate(try await query(owner))
        XCTAssertTrue(owner.ingest(anchorID: id, receiptUptime: 3) { plane($0, id, labels: [2,2], x: 10) })
        queue.sync {}; let recovered = try await query(owner, x: 10).get()
        XCTAssertTrue(recovered.route.complete); XCTAssertFalse(recovered.route.sourceDeliveryComplete)
        XCTAssertTrue(recovered.route.unknownCoverage.contains("ingress-or-lifecycle-gap"))
        XCTAssertEqual(recovered.route.projectedStart[0], 8, accuracy: 0.5)
        assertNonphysical(recovered)
        assertNoCandidate(try await query(owner)) // No stale prior-position floor survived replacement.
        try owner.reset()
        XCTAssertTrue(owner.ingest(anchorID: id, receiptUptime: 1) { plane($0, id, labels: nil) })
        queue.sync {}; assertNoCandidate(try await query(owner)) // Reset retains classified policy.
        try owner.reset()
        XCTAssertTrue(owner.ingest(anchorID: id, receiptUptime: 1) { plane($0, id, labels: [2,2]) })
        queue.sync {}; let fresh = try await query(owner).get()
        XCTAssertTrue(fresh.route.sourceDeliveryComplete) // Only fresh epoch clears historical gap.
        await discard(owner)
    }
    func testUnknownCompanionFacesKeepExistingFloorRouteButNeverCompleteCoverage() async throws {
        let cases: [[UInt8]?] = [nil,[0,0],[255,255]]
        for labels in cases {
            let queue = DispatchQueue(label: "classification.test.unknown"), a = UUID(), b = UUID()
            let owner = try makeOwner(supportPolicy: .classifiedFloorOnly, decodeQueue: queue)
            defer { owner.stopAndDiscard {} }
            XCTAssertTrue(owner.ingest(anchorID: a, receiptUptime: 1) { plane($0, a, labels: [2,2]) })
            queue.sync {}
            XCTAssertTrue(owner.ingest(anchorID: b, receiptUptime: 2) { plane($0, b, labels: labels, x: 10) })
            queue.sync {}; let candidate = try await query(owner).get()
            XCTAssertTrue(candidate.route.complete); XCTAssertFalse(candidate.route.sourceDeliveryComplete)
            XCTAssertTrue(candidate.route.unknownCoverage.contains("ingress-or-lifecycle-gap"))
            assertNonphysical(candidate)
            await discard(owner)
        }
    }
    func testMalformedDecodedLabelsReplaceFloorWhileRejectedDescriptorKeepsExplicitGap() async throws {
        let queue = DispatchQueue(label: "classification.test.malformed"), id = UUID()
        let owner = try makeOwner(supportPolicy: .classifiedFloorOnly, decodeQueue: queue)
        defer { owner.stopAndDiscard {} }
        XCTAssertTrue(owner.ingest(anchorID: id, receiptUptime: 1) { plane($0, id, labels: [2,2]) })
        queue.sync {}
        // Test-only owned snapshot corruption, not a claim82 produces short copies.
        XCTAssertTrue(owner.ingest(anchorID: id, receiptUptime: 2) { plane($0, id, labels: [2,2], shortClassificationBytes: true) })
        queue.sync {}; assertNoCandidate(try await query(owner))
        try owner.reset()
        XCTAssertTrue(owner.ingest(anchorID: id, receiptUptime: 1) { plane($0, id, labels: [2,2]) })
        queue.sync {}
        XCTAssertTrue(owner.ingest(anchorID: id, receiptUptime: 2) { plane($0, id, labels: [2]) })
        queue.sync {}; let retained = try await query(owner).get()
        // A whole unknownGap carries NO replacement geometry; established83 semantics
        // retain old geometry for diagnostics only, explicitly not complete delivery.
        XCTAssertFalse(retained.route.sourceDeliveryComplete); assertNonphysical(retained)
        await discard(owner)
    }
    #if os(iOS) && canImport(ARKit)
    func testPortableLabelContractAgreesWithNativeARKitSDK() {
        XCTAssertEqual(ARMeshClassification.floor.rawValue, 2)
        XCTAssertEqual(ARMeshClassification.none.rawValue, 0)
        for value in [1,3,4,5,6,7] { XCTAssertNotEqual(ARMeshClassification(rawValue: value), .floor) }
    }
    #endif
}
