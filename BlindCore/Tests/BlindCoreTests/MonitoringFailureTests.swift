import XCTest
@testable import BlindCore

final class MonitoringFailureTests: XCTestCase {
    func testUnavailableMonitoringInterruptsSpeechWithoutClaimingADrop() {
        XCTAssertTrue(Hazard.uncertain.requiresImmediateAttention)
        XCTAssertTrue(Hazard.needsCalibration.requiresImmediateAttention)
        XCTAssertFalse(Hazard.uncertain.isUrgent)
        XCTAssertFalse(Hazard.observing.requiresImmediateAttention)
        XCTAssertFalse(Hazard.stopped.requiresImmediateAttention)
        XCTAssertTrue(GuidanceText.hazard(.uncertain, arabic: false).hasPrefix("Stop."))
        XCTAssertTrue(GuidanceText.hazard(.uncertain, arabic: true).hasPrefix("توقف"))
    }
    func testFaultAndDropRemainHigherPriorityThanOrdinaryObservations() {
        for flags: UInt8 in [1, 3, 17, 19] {
            let packet = WearablePacket(role: .belt, flags: flags, sequence: 1, distancesMM: Array(repeating: .max, count: 8))
            let combined = AlertPolicy.highest([Detection(.observing), packet.detection])
            XCTAssertTrue(combined.hazard.requiresImmediateAttention)
            XCTAssertEqual(combined.hazard, flags & 2 != 0 ? .drop : .uncertain)
            let context = SceneContext(observations: [SceneObservation(id: "sign", kind: .text, text: "Exit", confidence: 1, capturedAt: 1)],
                                       at: 1, arabic: true, detail: .detailed, stationary: true, hazard: combined.hazard, requested: true)
            XCTAssertTrue(context.observations.isEmpty)
        }
    }
}
