import XCTest
@testable import BlindCore

final class NativeObservationTests: XCTestCase {
    let session = UUID(uuidString: "C86D1803-74BC-4E23-A54E-84443C3E70D2")!
    let intrinsics = NativeCameraIntrinsics(width: 4, height: 4, fx: 4, fy: 4, cx: 2, cy: 2)
    func sample(time: Double = 1, received: Double? = 1.1, tracking: NativeObservationRecord.Tracking = .normal,
                producer: NativeObservationRecord.Producer = .arkit, convention: NativeCameraConvention = .arKitRightUpBack,
                map: SpatialMapBinding? = nil, depth: NativeDepthObservation? = nil, surfaces: [NativeSurfaceObservation] = [],
                pose: NativeCameraTransform = .identity, frame: String = "session-world") -> NativeObservationRecord {
        NativeObservationRecord(sessionID: session, coordinateFrameID: frame, producer: producer,
            sourceID: "synthetic-fixture", mapTarget: map, capturedAt: time, receivedAt: received,
            observedAt: producer == .arkit ? Date(timeIntervalSince1970: 1000) : nil,
            tracking: tracking, cameraConvention: convention, cameraToSessionWorld: pose, intrinsics: intrinsics,
            depth: depth, surfaces: surfaces, originalSurfaceCount: surfaces.count)
    }
    func depth(confidence: UInt8? = 2) -> NativeDepthObservation {
        NativeDepthObservation(source: .arkitSceneDepth, width: 4, height: 4, samplingStride: 1,
            sampledPixelCount: 1, invalidPixelCount: 0, confidenceAvailable: confidence != nil,
            pixels: [NativeDepthPixel(column: 2, row: 2, metres: 3, confidence: confidence)])
    }
    func testUnknownEvidenceDoesNotDiscardObservedGeometry() throws {
        let record = sample(depth: depth())
        try record.validate()
        XCTAssertEqual(try record.depth!.worldPoints(intrinsics: intrinsics, cameraToWorld: .identity, convention: .arKitRightUpBack), [Point3(0,0,-3)])
        XCTAssertEqual(record.unavailableEvidence.count, 6)
        XCTAssertTrue(record.isHistoryOnly)
        XCTAssertNil(record.mapTarget)
    }
    func testOpticalConventionsCannotSilentlyMix() throws {
        let record = sample(depth: depth())
        XCTAssertEqual(try record.depth!.worldPoints(intrinsics: intrinsics, cameraToWorld: .identity, convention: .pinholeRightDownForward), [Point3(0,0,3)])
        XCTAssertThrowsError(try sample(convention: .pinholeRightDownForward).validate())
        XCTAssertThrowsError(try sample(received: nil, tracking: .notRecorded, producer: .arkitScenesRecorded).validate())
    }
    func testFullRotationAndInversePreserveTiltAndTranslation() throws {
        let p = NativeCameraTransform(columns: [1,0,0,0, 0,0,1,0, 0,-1,0,0, 2,3,4,1])
        XCTAssertTrue(p.valid)
        let source = Point3(1,2,-3)
        XCTAssertEqual(try p.applying(to: source), Point3(3,6,6))
        XCTAssertEqual(try p.inverted().applying(to: p.applying(to: source)), source)
    }
    func testScaleShearReflectionAndNonfinitePoseRejected() {
        var matrix = NativeCameraTransform.identity.columns
        matrix[0] = 2; XCTAssertFalse(NativeCameraTransform(columns: matrix).valid)
        matrix[0] = -1; XCTAssertFalse(NativeCameraTransform(columns: matrix).valid)
        matrix[0] = 1; matrix[4] = 0.1; XCTAssertFalse(NativeCameraTransform(columns: matrix).valid)
        matrix[4] = 0; matrix[12] = .nan; XCTAssertFalse(NativeCameraTransform(columns: matrix).valid)
        XCTAssertFalse(NativeCameraTransform(columns: [1]).valid)
    }
    func testIntrinsicsScaleUsesImageAndDepthResolution() throws {
        let scaled = try intrinsics.scaled(width: 2, height: 2)
        XCTAssertEqual(scaled.fx, 2); XCTAssertEqual(scaled.cx, 1)
        XCTAssertThrowsError(try intrinsics.scaled(width: 0, height: 2))
    }
    func testLowAndMissingConfidenceRemainHistoryNotUncertainty() throws {
        for confidence: UInt8? in [nil, 0, 1, 2] {
            let record = sample(depth: depth(confidence: confidence)); try record.validate()
            XCTAssertEqual(record.depth?.pixels.first?.confidence, confidence)
            XCTAssertTrue(record.unavailableEvidence.contains("poseCovariance"))
        }
        XCTAssertThrowsError(try sample(depth: depth(confidence: 3)).validate())
    }
    func testMissingDepthAndTrackingLossStillRetainAttributedPoseHistory() throws {
        for tracking: NativeObservationRecord.Tracking in [.limited, .unavailable] {
            let record = sample(tracking: tracking)
            try record.validate(); XCTAssertNil(record.depth); XCTAssertTrue(record.isHistoryOnly)
        }
    }
    func testStaleFutureOrMissingNativeReceiptRejected() {
        XCTAssertThrowsError(try sample(received: 0.9).validate())
        XCTAssertThrowsError(try sample(received: 2.1).validate())
        XCTAssertThrowsError(try sample(received: nil).validate())
        XCTAssertThrowsError(try sample(time: -.infinity).validate())
    }
    func testRecordedClockNeverBecomesDeviceUptime() throws {
        let record = sample(received: nil, tracking: .notRecorded, producer: .arkitScenesRecorded, convention: .pinholeRightDownForward)
        try record.validate(); XCTAssertNil(record.receivedAt); XCTAssertNil(record.observedAt)
        XCTAssertThrowsError(try sample(received: 1.1, tracking: .notRecorded, producer: .arkitScenesRecorded, convention: .pinholeRightDownForward).validate())
    }
    func testMapTargetDoesNotReframeCoordinatesOrProvideFloor() throws {
        let target = SpatialMapBinding(mapID: "saved-map", frameID: "saved-map-world", revision: "r1")
        let record = sample(map: target, depth: depth()); try record.validate()
        XCTAssertEqual(record.coordinateFrameID, "session-world")
        XCTAssertEqual(record.mapTarget, target)
        XCTAssertTrue(record.unavailableEvidence.contains("mapAlignment"))
        XCTAssertTrue(record.unavailableEvidence.contains("floorIdentity"))
        XCTAssertThrowsError(try sample(map: target, frame: target.frameID).validate())
    }
    func testPlaneFloorClassificationIsNotFloorIdentityOrSupportPermit() throws {
        let plane = NativeSurfaceObservation(sourceID: "plane-1", kind: .arkitPlane,
            localToSessionWorld: .identity, vertices: [Point3(0,0,0), Point3(1,0,0), Point3(0,0,1)],
            classification: "floor", horizontal: true, originalVertexCount: 3)
        let record = sample(surfaces: [plane]); try record.validate()
        XCTAssertEqual(record.surfaces[0].classification, "floor")
        XCTAssertTrue(record.unavailableEvidence.contains("floorIdentity"))
        XCTAssertTrue(record.unavailableEvidence.contains("completeCorridorCoverage"))
    }
    func testBadMeshIndicesAndUndeclaredTruncationRejected() {
        let mesh = NativeSurfaceObservation(sourceID: "mesh-1", kind: .arkitMesh, localToSessionWorld: .identity,
            vertices: [Point3(0,0,0)], triangleIndices: [0,1,0], originalVertexCount: 1, originalTriangleCount: 1)
        XCTAssertThrowsError(try mesh.validate())
        let truncated = NativeSurfaceObservation(sourceID: "plane", kind: .arkitPlane, localToSessionWorld: .identity,
            vertices: [], originalVertexCount: 10)
        XCTAssertThrowsError(try truncated.validate())
    }
    func testBadDepthPixelsAndDuplicatePixelsRejected() {
        let pixel = NativeDepthPixel(column: 0, row: 0, metres: 2, confidence: 2)
        let data = NativeDepthObservation(source: .arkitSceneDepth, width: 4, height: 4, samplingStride: 1,
            sampledPixelCount: 2, invalidPixelCount: 0, confidenceAvailable: true, pixels: [pixel,pixel])
        XCTAssertThrowsError(try data.validate())
        let negative = NativeDepthObservation(source: .arkitSceneDepth, width: 4, height: 4, samplingStride: 1,
            sampledPixelCount: 1, invalidPixelCount: 0, confidenceAvailable: false,
            pixels: [NativeDepthPixel(column: 0, row: 0, metres: -1, confidence: nil)])
        XCTAssertThrowsError(try negative.validate())
    }
    func testHistorySurvivesRestartWithoutRestoringAuthority() throws {
        var history = NativeObservationHistory(); let record = sample(depth: depth())
        try history.append(record); let bytes = try history.encoded()
        let restored = try NativeObservationHistory(data: bytes)
        XCTAssertEqual(restored.records, [record]); XCTAssertTrue(restored.records[0].isHistoryOnly)
        XCTAssertTrue(restored.records[0].unavailableEvidence.contains("bodyToCameraCalibration"))
    }
    func testCachedRecordSizeAndBytesDoNotChangeOnLaterAppend() throws {
        var history = NativeObservationHistory()
        let first = try history.append(sample())
        let second = try history.append(sample(time: 2, received: 2.1))
        XCTAssertEqual(history.encodedRecords.first?.payload, first.payload)
        XCTAssertEqual(history.payloadByteCount, first.encodedBytes + second.encodedBytes)
        XCTAssertEqual(try NativeObservationEncodedRecord(payload: first.payload), first)
    }
    func testDuplicateAndOutOfOrderCallbacksCannotRewriteHistory() throws {
        var history = NativeObservationHistory(); let record = sample()
        try history.append(record)
        XCTAssertThrowsError(try history.append(record))
        XCTAssertThrowsError(try history.append(sample(time: 0.5, received: 0.6)))
        XCTAssertEqual(history.records.count, 1)
    }
    func testHistoryBoundEvictionIsExplicitNotCompleteInventory() throws {
        var history = NativeObservationHistory()
        for n in 1...70 { try history.append(sample(time: Double(n), received: Double(n)+0.1)) }
        XCTAssertEqual(history.records.count, 64); XCTAssertEqual(history.evictedRecordCount, 6)
        XCTAssertEqual(history.records.first?.capturedAt, 7)
    }
    func testMalformedArchiveAndSchemaRejected() throws {
        XCTAssertThrowsError(try NativeObservationHistory(data: Data()))
        var history = NativeObservationHistory(); try history.append(sample())
        var object = try JSONSerialization.jsonObject(with: history.encoded()) as! [String: Any]
        object["schemaVersion"] = 99
        XCTAssertThrowsError(try NativeObservationHistory(data: JSONSerialization.data(withJSONObject: object)))
    }
    func testMalformedEvictionCounterRejectedWithoutOverflowTrap() throws {
        var object: [String: Any] = ["schemaVersion": 1, "records": [], "evictedRecordCount": Int.max]
        XCTAssertThrowsError(try NativeObservationHistory(data: JSONSerialization.data(withJSONObject: object)))
        var full = NativeObservationHistory()
        for n in 1...64 { try full.append(sample(time: Double(n), received: Double(n)+0.1)) }
        object = try JSONSerialization.jsonObject(with: full.encoded()) as! [String: Any]
        object["evictedRecordCount"] = NativeObservationHistory.maximumEvictionCount
        var capped = try NativeObservationHistory(data: JSONSerialization.data(withJSONObject: object))
        let prior = capped
        XCTAssertThrowsError(try capped.append(sample(time: 65, received: 65.1)))
        XCTAssertEqual(capped, prior)
    }

    func testDepthAccountingRejectsHugeInvalidCountWithoutOverflow() {
        let observation = NativeDepthObservation(source: .arkitSceneDepth, width: 1, height: 1,
            samplingStride: 1, sampledPixelCount: 1, invalidPixelCount: Int.max,
            confidenceAvailable: false,
            pixels: [NativeDepthPixel(column: 0, row: 0, metres: 1, confidence: nil)])
        XCTAssertThrowsError(try observation.validate()) { error in
            XCTAssertEqual(error as? NativeObservationError, .invalidDepth)
        }
    }
    func testDepthAccountingRejectsImpossibleInvalidRasterCoverage() {
        let observation = NativeDepthObservation(source: .arkitSceneDepth, width: 1, height: 1,
            samplingStride: 1, sampledPixelCount: 2, invalidPixelCount: 2,
            confidenceAvailable: false, pixels: [])
        XCTAssertThrowsError(try observation.validate())
    }
    func testDepthAccountingUsesCeilingStrideCapacityAndAllowsSparseSubsets() throws {
        // 5 by 3 at stride 2 contains six lattice sites, not floor(5/2)*floor(3/2).
        for count in [0, 1, 6] {
            let observation = NativeDepthObservation(source: .arkitSceneDepth, width: 5, height: 3,
                samplingStride: 2, sampledPixelCount: count, invalidPixelCount: count,
                confidenceAvailable: false, pixels: [])
            XCTAssertNoThrow(try observation.validate())
        }
        let impossible = NativeDepthObservation(source: .arkitSceneDepth, width: 5, height: 3,
            samplingStride: 2, sampledPixelCount: 7, invalidPixelCount: 7,
            confidenceAvailable: false, pixels: [])
        XCTAssertThrowsError(try impossible.validate())
    }
    func testDepthAccountingRejectsNegativeAndOverBudgetCounts() {
        for (sampled, invalid) in [(-1, 0), (0, -1), (0, 1), (4097, 4097), (Int.max, Int.max)] {
            let observation = NativeDepthObservation(source: .arkitSceneDepth, width: 128, height: 128,
                samplingStride: 1, sampledPixelCount: sampled, invalidPixelCount: invalid,
                confidenceAvailable: false, pixels: [])
            XCTAssertThrowsError(try observation.validate())
        }
    }

}
