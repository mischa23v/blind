import XCTest
@testable import BlindCore

final class RecoveryAndVisualTests: XCTestCase {
    func testRecoveryNeedsContinuousObservationAndNeverDelaysNewDanger() {
        var policy = MonitoringContinuity()
        XCTAssertEqual(policy.process(Detection(.uncertain, reason: .groundCoverage), at: 0).hazard, .uncertain)
        for time in [0.1, 0.3, 0.5] { XCTAssertEqual(policy.process(Detection(.observing), at: time).hazard, .uncertain) }
        XCTAssertEqual(policy.process(Detection(.drop), at: 0.51).hazard, .drop)
        XCTAssertEqual(policy.process(Detection(.obstacle), at: 0.52).hazard, .obstacle)
        _ = policy.process(Detection(.uncertain), at: 0.6)
        for time in [0.7, 0.9, 1.1, 1.3, 1.5] { XCTAssertEqual(policy.process(Detection(.observing), at: time).hazard, .uncertain) }
        XCTAssertEqual(policy.process(Detection(.observing), at: 1.8).hazard, .observing)
    }
    func testBriefGoodFramesCannotRestartSpeechAndGuidance() {
        var continuity = MonitoringContinuity(), speech = AlertPolicy()
        var announcements = 0
        for i in 0..<100 {
            let hazard: Hazard = i % 2 == 0 ? .uncertain : .observing
            let found = continuity.process(Detection(hazard), at: Double(i) * 0.1)
            XCTAssertEqual(found.hazard, .uncertain)
            if speech.shouldAnnounce(found, at: Double(i) * 0.1) { announcements += 1 }
        }
        XCTAssertEqual(announcements, 1)
        XCTAssertTrue(speech.shouldAnnounce(Detection(.drop), at: 10))
        XCTAssertTrue(speech.shouldAnnounce(Detection(.obstacle), at: 10.01))
    }
    func testInterruptedRecoveryAndDuplicateTimesDoNotClearUnknown() {
        var policy = MonitoringContinuity()
        _ = policy.process(Detection(.uncertain), at: 0)
        _ = policy.process(Detection(.observing), at: 0.1)
        for _ in 0..<20 { XCTAssertEqual(policy.process(Detection(.observing), at: 0.1).hazard, .uncertain) }
        XCTAssertEqual(policy.process(Detection(.observing), at: 4).hazard, .uncertain)
        XCTAssertEqual(policy.process(Detection(.observing), at: 3).hazard, .uncertain)
        XCTAssertEqual(policy.process(Detection(.observing), at: .nan).hazard, .uncertain)
        XCTAssertEqual(policy.process(Detection(.drop), at: .nan).hazard, .drop)
        XCTAssertEqual(policy.process(Detection(.stopped), at: 5).hazard, .stopped)
    }
    func testUnchangedUnknownReminderAndNewEpisode() {
        var policy = AlertPolicy()
        XCTAssertTrue(policy.shouldAnnounce(.uncertain, at: 0))
        XCTAssertFalse(policy.shouldAnnounce(.uncertain, at: 8))
        XCTAssertTrue(policy.shouldAnnounce(.uncertain, at: 15))
        XCTAssertFalse(policy.shouldAnnounce(.observing, at: 16))
        XCTAssertTrue(policy.shouldAnnounce(.uncertain, at: 16.1))
    }
    private func frame(_ time: Double, gap: Bool = false, camera: Point3 = Point3(0, 1.2, 0)) -> Observation {
        let points = stride(from: 0.32, through: 2.18, by: 0.04).flatMap { ahead in
            stride(from: -0.35, through: 0.35, by: 0.04).compactMap { side -> DepthSample? in
                if gap && ahead > 0.9 && ahead < 1.5 { return nil }
                return DepthSample(Point3(side, 0, -ahead))
            }
        }
        return Observation(timestamp: time, camera: camera, forward: Point3(0, 0, -1), samples: points)
    }
    private func calibrated() -> HazardDetector {
        var detector = HazardDetector(); detector.beginCalibration()
        for i in 0..<15 { _ = detector.process(frame(Double(i) * 0.1)) }
        return detector
    }
    func testRecentGroundOnlyChangesRecoveryHintNeverFillsAHole() {
        var detector = calibrated()
        XCTAssertEqual(detector.process(frame(1.5)).hazard, .observing)
        let gap = detector.process(frame(1.6, gap: true))
        XCTAssertEqual(gap.hazard, .uncertain)
        XCTAssertEqual(gap.reason, .groundNeedsRecheck)
        XCTAssertEqual(detector.process(frame(2, gap: true)).reason, .groundCoverage)
    }
    func testMovedCameraAndDepthLossInvalidateGroundMemory() {
        var detector = calibrated()
        _ = detector.process(frame(1.5))
        let moved = detector.process(frame(1.6, gap: true, camera: Point3(0.2, 1.2, 0)))
        XCTAssertEqual(moved.reason, .groundCoverage)
        _ = detector.process(frame(1.7))
        detector.invalidateRecentEvidence()
        XCTAssertNotNil(detector.floorHeight)
        XCTAssertEqual(detector.process(frame(1.8, gap: true)).reason, .groundCoverage)
    }
    func testRememberedLevelFloorNeverMasksFreshUpOrDownEvidence() {
        for (height, expected) in [(-0.12, Hazard.drop), (0.12, Hazard.obstacle)] {
            var detector = calibrated()
            _ = detector.process(frame(1.5))
            var step = frame(1.6)
            step.samples = step.samples.map { sample in
                var result = sample
                if result.position.z < -0.9 { result.position.y = height }
                return result
            }
            XCTAssertEqual(detector.process(step).hazard, expected)
        }
    }
    func testRecoveryPhrasesInBothLanguagesRemainStopInstructions() {
        for reason in [MonitoringReason.trackingUnavailable, .depthUnavailable, .cameraOrientation, .cameraHeight,
                       .frameUnavailable, .invalidGeometry, .groundCoverage, .groundNeedsRecheck, .localizing] {
            XCTAssertTrue(GuidanceText.detection(Detection(.uncertain, reason: reason), arabic: false).hasPrefix("Stop."))
            XCTAssertTrue(GuidanceText.detection(Detection(.uncertain, reason: reason), arabic: true).hasPrefix("توقف"))
        }
        let visual = Detection(.obstacle, reason: .visualStairs)
        XCTAssertTrue(GuidanceText.detection(visual, arabic: false).contains("Possible stairs"))
        XCTAssertTrue(GuidanceText.detection(visual, arabic: true).contains("درجات"))
    }
    private func warning(label: String = "stairs", confidence: Double = 0.9, now: Double = 10.1,
                         position: Point3 = Point3(0, 1.2, 0), direction: Point3 = Point3(0, 0, -1),
                         tracking: Bool = true, frameTime: Double = 10.1) -> Detection? {
        VisualHazard.warning(identifier: label, confidence: confidence, capturedAt: 10, now: now,
            origin: Point3(0, 1.2, 0), current: position, originForward: Point3(0, 0, -1),
            currentForward: direction, tracking: tracking, currentFrameAt: frameTime)
    }
    func testImageOnlyAddsPossibleStairWarningWithoutDistance() {
        let found = warning()
        XCTAssertEqual(found?.hazard, .obstacle)
        XCTAssertEqual(found?.reason, .visualStairs)
        XCTAssertNil(found?.distance)
        XCTAssertNil(warning(label: "clear floor"))
        XCTAssertNil(warning(label: "no stairs"))
        XCTAssertNil(warning(label: "text: stairs"))
        XCTAssertNil(warning(label: "steps"))
        XCTAssertNil(warning(confidence: 0.4))
        XCTAssertNil(warning(confidence: .nan))
    }
    func testOldMovedTurnedOrUntrackedImageCannotWarnAboutCurrentView() {
        XCTAssertNil(warning(now: 12, frameTime: 12))
        XCTAssertNil(warning(now: 9, frameTime: 9))
        XCTAssertNil(warning(now: 11, frameTime: 10))
        XCTAssertNil(warning(position: Point3(1, 1.2, 0)))
        XCTAssertNil(warning(direction: Point3(1, 0, 0)))
        XCTAssertNil(warning(tracking: false))
        XCTAssertNil(VisualHazard.warning(identifier: "stairs", confidence: 0.9, capturedAt: 10, now: 10.1,
            origin: Point3(0, 1.2, 0), current: Point3(0, 1.2, 0), originForward: Point3(0, 0, -1),
            currentForward: Point3(0, 0, -1), tracking: true, currentFrameAt: 10.1, originPitch: 0, currentPitch: 0.5))
    }
    func testImageCannotOverrideMeasuredDropOrObstacleAndNewSourceWarnsNow() {
        let visual = warning()!, measured = Detection(.obstacle, distance: 0.7)
        XCTAssertEqual(AlertPolicy.highest([visual, Detection(.drop)]).hazard, .drop)
        XCTAssertEqual(AlertPolicy.highest([visual, measured]), measured)
        XCTAssertEqual(AlertPolicy.highest([measured, visual]), measured)
        var policy = AlertPolicy()
        XCTAssertTrue(policy.shouldAnnounce(visual, at: 0))
        XCTAssertTrue(policy.shouldAnnounce(measured, at: 0.01))
    }
}
