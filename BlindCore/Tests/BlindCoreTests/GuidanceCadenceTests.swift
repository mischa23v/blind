import XCTest
@testable import BlindCore

final class GuidanceCadenceTests: XCTestCase {
    private func rel(_ sector: Sector, _ distance: Double) -> SpatialRelation {
        SpatialRelation(angleDegrees: 0, distance: distance, sector: sector)
    }

    func testFullNameOnceThenOnlyMilestonesAndTurns() {
        var cadence = GuidanceCadence()
        XCTAssertEqual(cadence.label(target: "Door to Kitchen", short: "Door", relation: rel(.ahead, 4.2), now: 0), "Door to Kitchen")
        XCTAssertNil(cadence.label(target: "Door to Kitchen", short: "Door", relation: rel(.ahead, 3.9), now: 0.25), "no milestone passed")
        XCTAssertEqual(cadence.label(target: "Door to Kitchen", short: "Door", relation: rel(.ahead, 2.9), now: 1.6), "Door", "passed 3 metres")
        XCTAssertNil(cadence.label(target: "Door to Kitchen", short: "Door", relation: rel(.ahead, 1.9), now: 2.0), "milestone too soon after the last cue")
        XCTAssertEqual(cadence.label(target: "Door to Kitchen", short: "Door", relation: rel(.left, 1.8), now: 2.8), "Door", "direction changed")
        XCTAssertEqual(cadence.label(target: "Front door", short: "Front door", relation: rel(.ahead, 6), now: 3.0), "Front door", "new target")
    }

    func testNonFiniteInputStaysQuiet() {
        var cadence = GuidanceCadence()
        XCTAssertNil(cadence.label(target: "Door", short: "Door", relation: rel(.ahead, .nan), now: 0))
        XCTAssertNil(cadence.label(target: "Door", short: "Door", relation: rel(.ahead, 2), now: .infinity))
    }
}
