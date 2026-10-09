import XCTest
@testable import BlindCore

final class NarrationBudgetTests: XCTestCase {
    func testSlidingWindowAndDispatchRecheck() {
        var budget = NarrationBudget()
        XCTAssertEqual(budget.allowance(limit: 100, now: 0), 100)
        XCTAssertTrue(budget.charge(words: 70, limit: 100, now: 1))
        XCTAssertFalse(budget.charge(words: 31, limit: 100, now: 2))
        XCTAssertTrue(budget.charge(words: 30, limit: 100, now: 3))
        XCTAssertEqual(budget.allowance(limit: 100, now: 60.9), 0)
        XCTAssertEqual(budget.allowance(limit: 100, now: 61), 70)
        XCTAssertEqual(budget.allowance(limit: 100, now: 63), 100)
    }
    func testPreferenceReductionAndBadClockCannotIncreaseAllowance() {
        var budget = NarrationBudget(); XCTAssertTrue(budget.charge(words: 80, limit: 100, now: 10))
        XCTAssertEqual(budget.allowance(limit: 40, now: 11), 0)
        XCTAssertEqual(budget.allowance(limit: 100, now: 9), 0)
        XCTAssertEqual(budget.allowance(limit: 100, now: .nan), 0)
        XCTAssertEqual(budget.allowance(limit: 100, now: 12), 20)
    }
}
