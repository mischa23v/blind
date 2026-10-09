import XCTest
@testable import BlindCore

final class ElevationRegressionTests: XCTestCase {
    private func frame(_ time: Double, middleHeight: Double? = 0, confidence: UInt8 = 2) -> Observation {
        var points: [DepthSample] = []
        for x in stride(from: -0.6, through: 0.6, by: 0.04) {
            for ahead in stride(from: 0.1, through: 2.4, by: 0.04) {
                let middle = ahead > 0.9 && ahead < 1.3 && abs(x) < 0.18
                if middle && middleHeight == nil { continue }
                points.append(DepthSample(Point3(x, middle ? middleHeight! : 0, -ahead), confidence: middle ? confidence : 2))
            }
        }
        return Observation(timestamp: time, camera: Point3(0, 1.3, 0), forward: Point3(0, 0, -1), samples: points)
    }
    private func calibrated() -> HazardDetector {
        var detector = HazardDetector(); detector.beginCalibration()
        for i in 0..<15 { _ = detector.process(frame(Double(i) * 0.1)) }
        XCTAssertNotNil(detector.floorHeight)
        return detector
    }
    func testUnseenGapBetweenNearAndFarFloorStopsGuidance() {
        var detector = calibrated()
        XCTAssertEqual(detector.process(frame(2, middleHeight: nil)).hazard, .uncertain)
    }
    func testWeakDepthCannotFillMissingSupport() {
        var detector = calibrated()
        XCTAssertEqual(detector.process(frame(2, confidence: 1)).hazard, .uncertain)
    }
    func testSparseSamplesInEveryRowStillCannotEstablishSupport() {
        var detector = calibrated()
        let points = (0..<9).flatMap { row in
            [-0.1, 0.1].map { x in DepthSample(Point3(x, 0, -(0.4 + Double(row) * 0.2))) }
        }
        let sparse = Observation(timestamp: 2, camera: Point3(0, 1.3, 0), forward: Point3(0, 0, -1), samples: points)
        XCTAssertEqual(detector.process(sparse).hazard, .uncertain)
    }
    func testSmallUnclassifiedRiseAndDropStayUnknown() {
        for height in [-0.06, 0.06] {
            var detector = calibrated()
            XCTAssertEqual(detector.process(frame(2, middleHeight: height)).hazard, .uncertain)
        }
    }
    func testTwelveCentimetreDropAndRiseCannotHideInOtherFloorReturns() {
        for (height, expected) in [(-0.12, Hazard.drop), (0.12, Hazard.obstacle)] {
            var detector = calibrated()
            XCTAssertEqual(detector.process(frame(2, middleHeight: height)).hazard, expected)
            _ = detector.process(frame(2.1, middleHeight: height))
            XCTAssertEqual(detector.process(frame(2.2, middleHeight: height)).hazard, expected)
        }
    }
    func testWarningHoldsThroughBriefNormalFrameButDoesNotDelayNewDanger() {
        var detector = calibrated()
        XCTAssertEqual(detector.process(frame(2, middleHeight: -0.12)).hazard, .drop)
        XCTAssertEqual(detector.process(frame(2.1)).hazard, .drop)
        XCTAssertEqual(detector.process(frame(2.2, middleHeight: 0.12)).hazard, .obstacle)
        XCTAssertEqual(detector.process(frame(2.5)).hazard, .obstacle)
        XCTAssertEqual(detector.process(frame(2.8)).hazard, .obstacle)
        XCTAssertEqual(detector.process(frame(3)).hazard, .observing)
    }
}
