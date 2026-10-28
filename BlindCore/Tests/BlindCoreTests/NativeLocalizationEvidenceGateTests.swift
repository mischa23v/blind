import Foundation
import XCTest
@testable import BlindCore

/// Contract fixtures only: these values are NOT measured localization accuracy.
/// The validator below exists only in the test target and grants bench preparation,
/// never physical guidance, real sensor calibration or independent validation.
final class NativeLocalizationEvidenceGateTests: XCTestCase {
    private let digest = String(repeating: "a", count: 64)
    private let identity: [Double] = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]
    private struct FixtureValidator: NativeLocalizationEvidenceValidator {
        let result: NativeEvidenceValidation
        func validate(_ measurement: NativeLocalizationMeasurements) -> NativeEvidenceValidation { result }
    }
    private func fixture() -> (NativeLocalizationOwner, SpatialMapRevision) {
        let frame = SavedWorldFrame(placeID: UUID().uuidString, revision: UUID().uuidString,
            worldMapSHA256: digest, roomCaptureSHA256: digest, originAnchorID: UUID().uuidString,
            capturedAt: Date(timeIntervalSince1970: 1))
        let binding = SpatialMapBinding(mapID: "fixture-map", frameID: frame.frameID, revision: frame.revision)
        let owner = NativeLocalizationOwner(arSession: UUID(), registeredSession: UUID(),
            artifact: .init(binding: binding, sha256: digest), descriptor: frame,
            calibrationRevision: "fixture-calibration", mountRevision: UUID())
        return (owner, .init(binding: binding, nodeID: "fixture-room", metersPerUnit: 1,
            floorLevels: ["ground": "fixture-floor"], savedWorldFrame: frame))
    }
    private func candidate(_ owner: NativeLocalizationOwner, time: Double = 10,
                           id: UUID = UUID(), matrix: [Double]? = nil) -> NativeLocalizationCandidate {
        .init(id: id, owner: owner, capturedAt: time, cameraToWorld: matrix ?? identity, trackingNormal: true)
    }
    private func record(time: Double = 10, expiry: Double = 11,
                        revision: String = "fixture-calibration", hash: String? = nil) -> NativeEvidenceRecord {
        .init(sourceID: "fixture-only", revision: revision, sha256: hash ?? digest,
              protocolID: "synthetic-contract", datasetID: "not-device-data", observedAt: time, expiresAt: expiry)
    }
    private func measurement(_ c: NativeLocalizationCandidate, missing: String? = nil,
        calibration: NativeEvidenceRecord? = nil, support: NativeEvidenceRecord? = nil,
        error: NativeEvidenceRecord? = nil, floor: String = "fixture-floor",
        positionError: Double = 0.1) -> NativeLocalizationMeasurements {
        .init(candidate: c,
            calibration: missing == "calibration" ? nil : (calibration ?? record()),
            support: missing == "support" ? nil : (support ?? record(time: c.capturedAt)),
            errorModel: missing == "error" ? nil : (error ?? record(time: c.capturedAt)),
            operatingDomainID: "synthetic-only", floorID: floor, bodyPosition: Point3(1, 0, 2),
            bodyYaw: 0.2, supportHeight: 0, supportHeightError: 0.02,
            coveredFootprintSHA256: digest, totalPositionError: positionError, totalHeadingError: 0.1)
    }
    private func begin(_ gate: inout NativeLocalizationEvidenceGate, _ c: NativeLocalizationCandidate,
                       _ map: SpatialMapRevision) throws {
        try gate.begin(c, installed: map, recovered: c.owner.descriptor, now: c.capturedAt)
        XCTAssertEqual(gate.reason, .missingCalibration)
        XCTAssertEqual(gate.owner, c.owner)
    }
    private func expect(_ expected: NativeLocalizationNotReady, _ action: () throws -> Void,
                        file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try action(), file: file, line: line) {
            XCTAssertEqual($0 as? NativeLocalizationNotReady, expected, file: file, line: line)
        }
    }
    private func prepare(_ gate: inout NativeLocalizationEvidenceGate, _ m: NativeLocalizationMeasurements,
                         owner: NativeLocalizationOwner? = nil,
                         verdict: NativeEvidenceValidation = .independentlyValidated,
                         now: Double = 10) throws -> NativeLocalizationBenchPair {
        try gate.prepareForBench(m, currentOwner: owner ?? m.candidate.owner,
            validator: FixtureValidator(result: verdict), now: now)
    }

    func testSuccessfulFixtureIsBoundSingleUseBenchPairNotPhysicalRelease() throws {
        let (owner, map) = fixture(), c = candidate(owner)
        var gate = NativeLocalizationEvidenceGate()
        try begin(&gate, c, map)
        let m = measurement(c, support: record(expiry: 10.2))
        let pair = try prepare(&gate, m)
        XCTAssertEqual(pair.owner, owner)
        XCTAssertEqual(pair.capture.id, c.id)
        XCTAssertEqual(pair.capture.sessionID, owner.registeredSession)
        XCTAssertEqual(pair.capture.binding, map.binding)
        XCTAssertEqual(pair.capture.capturedAt, c.capturedAt)
        XCTAssertEqual(pair.support.captureID, pair.capture.id)
        XCTAssertEqual(pair.support.sessionID, pair.capture.sessionID)
        XCTAssertEqual(pair.support.binding, pair.capture.binding)
        XCTAssertEqual(pair.support.floorID, pair.capture.floorID)
        XCTAssertEqual(pair.support.capturedAt, pair.capture.capturedAt)
        XCTAssertEqual(pair.expiresAt, 10.2)
        XCTAssertEqual(gate.reason, .physicalReleaseNotApproved)
        expect(.supersededCandidate) { _ = try prepare(&gate, m) }
    }
    func testMissingRecordsFailAtTheirOwnGateAndConsumeCompletion() throws {
        for (missing, reason) in [("calibration", NativeLocalizationNotReady.missingCalibration),
                                 ("support", .missingSupport), ("error", .missingErrorModel)] {
            let (owner, map) = fixture(), c = candidate(owner)
            var gate = NativeLocalizationEvidenceGate()
            try begin(&gate, c, map)
            expect(reason) { _ = try prepare(&gate, measurement(c, missing: missing)) }
            XCTAssertEqual(gate.reason, reason)
            expect(.supersededCandidate) { _ = try prepare(&gate, measurement(c)) }
        }
    }
    func testExpiredAndMalformedRecordsCannotReachValidatorSuccess() throws {
        for bad in [record(expiry: 9.9), record(time: 10.1), record(hash: String(repeating: "A", count: 64))] {
            let (owner, map) = fixture(), c = candidate(owner)
            var gate = NativeLocalizationEvidenceGate()
            try begin(&gate, c, map)
            expect(.evidenceExpired) { _ = try prepare(&gate, measurement(c, calibration: bad)) }
            XCTAssertEqual(gate.reason, .evidenceExpired)
        }
    }
    func testWrongCalibrationCaptureTimeFloorAndErrorBudgetReject() throws {
        let (owner, map) = fixture(), c = candidate(owner)
        let invalid = [measurement(c, calibration: record(revision: "other")),
            measurement(c, support: record(time: 9.9)), measurement(c, error: record(time: 9.9)),
            measurement(c, floor: "not-installed"), measurement(c, positionError: 0.01),
            measurement(c, positionError: .nan)]
        for m in invalid {
            var gate = NativeLocalizationEvidenceGate()
            try begin(&gate, c, map)
            expect(.invalidEvidence) { _ = try prepare(&gate, m) }
            XCTAssertEqual(gate.reason, .invalidEvidence)
        }
    }
    func testValidatorRejectionsRemainDistinctFromStructuralRejections() throws {
        for (verdict, reason) in [(NativeEvidenceValidation.unvalidated, NativeLocalizationNotReady.unvalidatedEvidence),
                                  (.outsideDomain, .outOfDomain)] {
            let (owner, map) = fixture(), c = candidate(owner)
            var gate = NativeLocalizationEvidenceGate()
            try begin(&gate, c, map)
            expect(reason) { _ = try prepare(&gate, measurement(c), verdict: verdict) }
            XCTAssertEqual(gate.reason, reason)
        }
    }
    func testSameIDAlteredMatrixCannotSubstituteAndDoesNotConsumeRealCandidate() throws {
        let (owner, map) = fixture(), c = candidate(owner)
        var gate = NativeLocalizationEvidenceGate(), altered = identity
        altered[12] = 1
        try begin(&gate, c, map)
        let forged = candidate(owner, id: c.id, matrix: altered)
        expect(.supersededCandidate) { _ = try prepare(&gate, measurement(forged)) }
        XCTAssertEqual(gate.reason, .missingCalibration)
        XCTAssertNoThrow(try prepare(&gate, measurement(c)))
    }
    func testObsoleteCompletionDoesNotConsumeNewerPendingFrame() throws {
        let (owner, map) = fixture(), a = candidate(owner), b = candidate(owner, time: 10.1)
        var gate = NativeLocalizationEvidenceGate()
        try begin(&gate, a, map)
        try begin(&gate, b, map)
        expect(.supersededCandidate) { _ = try prepare(&gate, measurement(a), now: 10.1) }
        XCTAssertEqual(gate.reason, .missingCalibration)
        let pair = try prepare(&gate, measurement(b), now: 10.1)
        XCTAssertEqual(pair.capture.id, b.id)
    }
    func testMountChangeRejectsPendingCompletion() throws {
        let (owner, map) = fixture(), c = candidate(owner)
        let changed = NativeLocalizationOwner(arSession: owner.arSession, registeredSession: owner.registeredSession,
            artifact: owner.artifact, descriptor: owner.descriptor, calibrationRevision: owner.calibrationRevision,
            mountRevision: UUID(), selection: owner.selection)
        var gate = NativeLocalizationEvidenceGate()
        try begin(&gate, c, map)
        expect(.ownerChanged) { _ = try prepare(&gate, measurement(c), owner: changed) }
        XCTAssertEqual(gate.reason, .ownerChanged)
        expect(.supersededCandidate) { _ = try prepare(&gate, measurement(c)) }
    }
    func testWithdrawalPreservesReplayHighWater() throws {
        let (owner, map) = fixture(), c = candidate(owner)
        var gate = NativeLocalizationEvidenceGate()
        try begin(&gate, c, map)
        gate.withholdCandidate(.mountSlip)
        expect(.replayedCandidate) { try gate.begin(c, installed: map, recovered: owner.descriptor, now: 10) }
        XCTAssertEqual(gate.reason, .replayedCandidate)
        try begin(&gate, candidate(owner, time: 10.1), map)
    }
    func testCompletionTimeCannotRefreshOldCapture() throws {
        let (owner, map) = fixture(), c = candidate(owner)
        var gate = NativeLocalizationEvidenceGate()
        try begin(&gate, c, map)
        expect(.staleCandidate) { _ = try prepare(&gate, measurement(c), now: 11) }
        XCTAssertEqual(gate.reason, .staleCandidate)
    }
}
