import XCTest
@testable import BlindCore

final class RecordedRouteSamplerTests: XCTestCase {
    func testConstantStateSamplerContinuesPastOldRingAndPreservesPayloadProvenance() throws {
        var sampler = RecordedRouteSampler(); let session = UUID()
        var last: RecordedRouteSample?
        for i in 0..<50_000 {
            let time = Double(i)*0.21
            let record = NativeObservationRecord(sessionID: session, coordinateFrameID: "unregistered-frame", producer: .arkit,
                sourceID: "frame-\(i)", capturedAt: time, receivedAt: time, observedAt: Date(timeIntervalSince1970: 1000+time),
                tracking: .normal, cameraConvention: .arKitRightUpBack, cameraToSessionWorld: .identity,
                intrinsics: .init(width: 2, height: 2, fx: 1, fy: 1, cx: 1, cy: 1), depth: nil)
            last = try sampler.observe(record)
        }
        let sample = try XCTUnwrap(last)
        XCTAssertEqual(sample.sourceID, "frame-49999"); XCTAssertEqual(sampler.lastSample, sample)
        XCTAssertEqual(try RecordedRouteSample(payload: sample.encoded()), sample)
        XCTAssertNil(sample.mapTarget); XCTAssertEqual(sample.transportMode, .unknown)
        let gap = sample.markingBoundary(.durabilityLoss)
        XCTAssertEqual(gap.cameraToSourceFrame, sample.cameraToSourceFrame)
        XCTAssertEqual(gap.observationID, sample.observationID)
        XCTAssertEqual(gap.boundaryBefore, .durabilityLoss)
    }
    func testRestartCannotStitchReusedSessionFrame() throws {
        var sampler = RecordedRouteSampler(); let session = UUID()
        func frame(_ time: Double) -> NativeObservationRecord {
            .init(sessionID: session, coordinateFrameID: "frame", producer: .arkit, sourceID: "\(time)",
                capturedAt: time, receivedAt: time, observedAt: Date(), tracking: .normal,
                cameraConvention: .arKitRightUpBack, cameraToSessionWorld: .identity,
                intrinsics: .init(width: 2, height: 2, fx: 1, fy: 1, cx: 1, cy: 1), depth: nil)
        }
        _ = try sampler.observe(frame(0)); sampler.restart()
        XCTAssertEqual(try sampler.observe(frame(0.2)).boundaryBefore, .restarted)
        sampler.interrupt(.trackingLost)
        XCTAssertEqual(try sampler.observe(frame(0.4)).boundaryBefore, .trackingLost)
    }
}
