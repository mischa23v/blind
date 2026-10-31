import XCTest
@testable import BlindCore
final class LocalRecipeReferenceTests: XCTestCase {
    private func recipe(seconds: Int = 60) throws -> LocalRecipeReference {
        try .decode(Data("""
        {"schema":1,"title":"User recipe","attribution":"Family note, not verified","ingredients":[{"name":"Water","quantity":"1 cup, as written"}],"steps":[{"text":"Source step one","timerSeconds":\(seconds)},{"text":"Source step two"}]}
        """.utf8))
    }
    func testLiteralQuantityAndSourcePreserved() throws {
        let r = try recipe(); XCTAssertEqual(r.ingredients[0].quantity, "1 cup, as written")
        XCTAssertEqual(r.attribution, "Family note, not verified")
    }
    func testOversizedAndMalformedRejected() {
        XCTAssertThrowsError(try LocalRecipeReference.decode(Data(repeating: 32, count: LocalRecipeReference.maximumBytes + 1)))
        XCTAssertThrowsError(try LocalRecipeReference.decode(Data("{}".utf8)))
        XCTAssertThrowsError(try recipe(seconds: 0)); XCTAssertThrowsError(try recipe(seconds: 86401))
    }
    func testStepMovementDoesNotStartTimer() throws {
        var s = LocalRecipeSession(recipe: try recipe()); XCTAssertEqual(s.timerState, .idle)
        XCTAssertFalse(s.move(by: -1)); XCTAssertFalse(s.move(by: 2)); XCTAssertTrue(s.move(by: 1))
        XCTAssertFalse(s.startTimer(uptime: 0)); XCTAssertFalse(s.move(by: 1))
    }
    func testExactMonotonicExpiryAndNoDoubleStart() throws {
        var s = LocalRecipeSession(recipe: try recipe()); XCTAssertTrue(s.startTimer(uptime: 20))
        XCTAssertFalse(s.startTimer(uptime: 21)); s.tick(uptime: 79.1); XCTAssertEqual(s.remainingSeconds, 1)
        s.tick(uptime: 80); XCTAssertEqual(s.timerState, .elapsed); XCTAssertEqual(s.remainingSeconds, 0)
    }
    func testStepChangeCancelsAndDoesNotMarkFoodDone() throws {
        var s = LocalRecipeSession(recipe: try recipe()); _ = s.startTimer(uptime: 0)
        _ = s.move(by: 1); XCTAssertEqual(s.timerState, .cancelled); XCTAssertNil(s.remainingSeconds)
    }
    func testInvalidClockCancels() throws {
        var s = LocalRecipeSession(recipe: try recipe()); _ = s.startTimer(uptime: 5)
        s.tick(uptime: 4); XCTAssertEqual(s.timerState, .invalidClock); XCTAssertNil(s.remainingSeconds)
        XCTAssertFalse(s.startTimer(uptime: .infinity))
    }
    func testBackgroundCancellationDoesNotResume() throws {
        var s = LocalRecipeSession(recipe: try recipe()); _ = s.startTimer(uptime: 0); s.cancelTimer()
        s.tick(uptime: 100); XCTAssertEqual(s.timerState, .cancelled); XCTAssertNil(s.remainingSeconds)
    }
}
