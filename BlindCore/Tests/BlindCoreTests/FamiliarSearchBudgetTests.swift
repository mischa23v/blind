import XCTest
@testable import BlindCore

final class FamiliarSearchBudgetTests: XCTestCase {
    func testSixAttemptsMaximum() {
        var budget = FamiliarSearchBudget(startedAt: 10)
        for time in stride(from: 10.0, through: 20.0, by: 2) {
            XCTAssertTrue(budget.consumeAttempt(now: time))
        }
        XCTAssertTrue(budget.isExpired(now: 20))
        XCTAssertFalse(budget.consumeAttempt(now: 22))
    }

    func testSpacingRejectionsDoNotSpendAttempts() {
        var budget = FamiliarSearchBudget(startedAt: 0)
        XCTAssertTrue(budget.consumeAttempt(now: 0))
        XCTAssertFalse(budget.consumeAttempt(now: 0))
        XCTAssertFalse(budget.consumeAttempt(now: 1.999))
        for time in stride(from: 2.0, through: 10.0, by: 2) {
            XCTAssertTrue(budget.consumeAttempt(now: time))
        }
        XCTAssertFalse(budget.consumeAttempt(now: 12))
    }

    func testInclusiveTwentySecondBoundary() {
        var budget = FamiliarSearchBudget(startedAt: 100)
        XCTAssertFalse(budget.isExpired(now: 120))
        XCTAssertTrue(budget.consumeAttempt(now: 120))
        XCTAssertTrue(budget.isExpired(now: 120.000001))
        XCTAssertFalse(budget.consumeAttempt(now: 120.000001))
        XCTAssertFalse(budget.consumeAttempt(now: 120))
    }

    func testInvalidStartsAndTimesFailClosed() {
        for value in [-1.0, Double.nan, Double.infinity, -Double.infinity] {
            var invalidStart = FamiliarSearchBudget(startedAt: value)
            XCTAssertTrue(invalidStart.isExpired(now: 0))
            XCTAssertFalse(invalidStart.consumeAttempt(now: 0))
            var invalidTime = FamiliarSearchBudget(startedAt: 0)
            XCTAssertTrue(invalidTime.isExpired(now: value))
            XCTAssertFalse(invalidTime.consumeAttempt(now: value))
            XCTAssertFalse(invalidTime.consumeAttempt(now: 1))
        }
    }

    func testClockReversalBeforeStartOrPreviousCheckExpires() {
        var futureStart = FamiliarSearchBudget(startedAt: 10)
        XCTAssertTrue(futureStart.isExpired(now: 9))
        XCTAssertFalse(futureStart.consumeAttempt(now: 9))
        XCTAssertFalse(futureStart.consumeAttempt(now: 10))
        var budget = FamiliarSearchBudget(startedAt: 0)
        XCTAssertTrue(budget.consumeAttempt(now: 2))
        XCTAssertFalse(budget.consumeAttempt(now: 3)) // Too soon, still observes the clock.
        XCTAssertTrue(budget.isExpired(now: 2.5))
        XCTAssertFalse(budget.consumeAttempt(now: 2.5))
        XCTAssertFalse(budget.consumeAttempt(now: 4))
    }
}
