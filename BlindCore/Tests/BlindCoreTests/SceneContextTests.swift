import XCTest
@testable import BlindCore

final class SceneContextTests: XCTestCase {
    func observations() -> [SceneObservation] {
        [.init(id: "low", kind: .object, text: "stairs", confidence: 0.3, capturedAt: 10),
         .init(id: "people", kind: .people, text: "2", confidence: 0.9, capturedAt: 10),
         .init(id: "old", kind: .text, text: "old sign", confidence: 0.99, capturedAt: 1),
         .init(id: "text", kind: .text, text: "Reception", confidence: 0.95, capturedAt: 10)]
    }
    func context(hazard: Hazard = .observing, stationary: Bool = true, detail: DetailLevel = .balanced, requested: Bool = false) -> SceneContext {
        SceneContext(observations: observations(), at: 11, arabic: false, detail: detail,
                     stationary: stationary, hazard: hazard, requested: requested)
    }
    func testPriorityFreshnessConfidenceAndBudget() {
        XCTAssertEqual(context().observations.map(\.id), ["text", "people"])
        XCTAssertEqual(context(detail: .minimal, requested: true).observations.map(\.id), ["text"])
        XCTAssertEqual(context(detail: .minimal).observations.map(\.id), ["text"])
        XCTAssertFalse(context(stationary: false).observations.isEmpty)
        XCTAssertFalse(context(stationary: false, requested: true).observations.isEmpty)
    }
    func testUrgentOrUnavailableMonitoringNeverReachesLanguageLayer() {
        for hazard in [Hazard.drop, .overhead, .obstacle, .uncertain, .needsCalibration, .stopped] {
            XCTAssertTrue(context(hazard: hazard, requested: true).observations.isEmpty)
        }
    }
    func testDetailedMovingContextRetainsSameInformationBudget() {
        let evidence = (0..<5).map { SceneObservation(id: "item-\($0)", kind: .text, text: "Landmark \($0)", confidence: 0.9, capturedAt: 10) }
        let moving = SceneContext(observations: evidence, at: 11, arabic: false, detail: .detailed, stationary: false, hazard: .observing, requested: false)
        XCTAssertEqual(moving.observations.count, 5)
    }
    func testModelCannotIntroduceObservationOrOverrideOrder() {
        let context = context()
        XCTAssertEqual(context.rendering(ids: ["invented"]), context.fallback)
        XCTAssertEqual(context.rendering(ids: ["people", "text", "people"]), context.fallback)
        XCTAssertFalse(context.fallback.contains("stairs"))
        XCTAssertTrue(context.fallback.contains("Text reads"))
    }
    func testLateOrMovedSceneAnswerIsDiscarded() {
        func allowed(now: Double = 11, point: Point3 = Point3(0, 1, 0), tracking: Bool = true) -> Bool {
            SceneDelivery.allowed(capturedAt: 10, now: now, origin: Point3(0, 1, 0), current: point,
                                  currentFrameAt: now, hazard: .observing, tracking: tracking,
                                  originForward: Point3(0, 0, -1), currentForward: Point3(0, 0, -1))
        }
        XCTAssertTrue(allowed())
        XCTAssertFalse(allowed(now: 23))
        XCTAssertFalse(allowed(point: Point3(1, 1, 0)))
        XCTAssertFalse(allowed(tracking: false))
    }
    func testTurnedCameraDiscardsAnswer() {
        for direction in [Point3(1, 0, 0), Point3(0, 0, 1), Point3(0, 0, 0)] {
            XCTAssertFalse(SceneDelivery.allowed(capturedAt: 10, now: 11, origin: Point3(0, 1, 0), current: Point3(0, 1, 0),
                currentFrameAt: 11, hazard: .observing, tracking: true, originForward: Point3(0, 0, -1), currentForward: direction))
        }
    }
}
