import XCTest
@testable import BlindCore

final class WearableEvidenceTests: XCTestCase {
    private var packet: WearablePacket {
        WearablePacket(role: .belt, flags: 16, sequence: 1, distancesMM: [1200, .max, 2500, .max, 900, .max, .max, 0])
    }
    func testBeltReportsNearestValidRangesWithoutObjectIdentity() {
        let facts = WearableEvidence.observations(packet: packet, receivedAt: 1, now: 1.1, arabic: false)
        XCTAssertEqual(facts.map(\.id), ["wearable-1-4", "wearable-1-0", "wearable-1-2"])
        XCTAssertTrue(facts[0].text.contains("rear"))
        XCTAssertTrue(facts.allSatisfy { $0.kind == .range && $0.text.contains("Object unidentified") })
    }
    func testFaultUncalibratedAndStaleReportsAreExcluded() {
        for flags: UInt8 in [0, 1, 17] {
            var damaged = packet; damaged.flags = flags
            XCTAssertTrue(WearableEvidence.observations(packet: damaged, receivedAt: 1, now: 1, arabic: false).isEmpty)
        }
        for now in [0.9, 1.801, Double.nan] {
            XCTAssertTrue(WearableEvidence.observations(packet: packet, receivedAt: 1, now: now, arabic: false).isEmpty)
        }
    }
    func testWristDirectionIsNotBodyFrontAndArabicIsRendered() {
        var wrist = packet; wrist.role = .wrist
        let facts = WearableEvidence.observations(packet: wrist, receivedAt: 1, now: 1, arabic: true)
        XCTAssertEqual(facts.count, 1)
        XCTAssertTrue(facts[0].text.contains("باتجاه توجيهه"))
        XCTAssertFalse(facts[0].text.contains("الأمام"))
    }
    func testDescriptionBudgetsKeepCameraEvidenceAndRejectOldRanges() {
        let facts = WearableEvidence.observations(packet: packet, receivedAt: 1, now: 1, arabic: false)
        let sign = SceneObservation(id: "sign", kind: .text, text: "Exit", confidence: 1, capturedAt: 1)
        let selected = SceneContext(observations: facts + [sign], at: 1, arabic: false, detail: .balanced, stationary: true, hazard: .observing, requested: true)
        XCTAssertEqual(selected.observations.map(\.id), ["wearable-1-4", "wearable-1-0", "sign"])
        XCTAssertEqual(SceneContext(observations: facts + [sign], at: 2, arabic: false, detail: .detailed, stationary: true, hazard: .observing, requested: true).observations.map(\.id), ["sign"])
    }
    func testChangedOrDisconnectedSensorsInvalidatePendingAnswer() {
        let original = WearableEvidence.observations(packet: packet, receivedAt: 1, now: 1, arabic: false)
        let fresh = WearableEvidence.observations(packet: packet, receivedAt: 2, now: 2, arabic: false)
        XCTAssertTrue(WearableEvidence.stillMatches(original, current: fresh))
        XCTAssertFalse(WearableEvidence.stillMatches(original, current: []))
        var changed = packet; changed.distancesMM[4] = 1100
        XCTAssertFalse(WearableEvidence.stillMatches(original, current: WearableEvidence.observations(packet: changed, receivedAt: 2, now: 2, arabic: false)))
    }
}
