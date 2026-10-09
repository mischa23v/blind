import XCTest
@testable import BlindCore

final class PendingQuestionTests: XCTestCase {
    func testQuestionMustRetainGoalMapAlignmentAndFreshView() {
        let pending = PendingQuestion(question: "Who is there?", cloud: false, focus: "people", goalRevision: "goal",
            mapRevision: "map", alignmentRevision: "alignment", created: 10, camera: Point3(0, 1, 0), forward: Point3(0, 0, -1))
        func valid(goal: String = "goal", map: String = "map", alignment: String = "alignment", now: Double = 11,
                   camera: Point3 = Point3(0, 1, 0), forward: Point3 = Point3(0, 0, -1), hazard: Hazard = .observing) -> Bool {
            pending.isCurrent(goalRevision: goal, mapRevision: map, alignmentRevision: alignment, now: now,
                camera: camera, forward: forward, frameAt: now, tracking: true, hazard: hazard)
        }
        XCTAssertTrue(valid())
        XCTAssertFalse(valid(goal: "new goal")); XCTAssertFalse(valid(map: "new map")); XCTAssertFalse(valid(alignment: "recalibrated"))
        XCTAssertFalse(valid(now: 23)); XCTAssertFalse(valid(camera: Point3(2, 1, 0)))
        XCTAssertFalse(valid(forward: Point3(1, 0, 0))); XCTAssertFalse(valid(hazard: .drop))
    }
}
