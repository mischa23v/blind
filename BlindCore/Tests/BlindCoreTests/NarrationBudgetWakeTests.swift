import XCTest
@testable import BlindCore

final class NarrationBudgetWakeTests: XCTestCase {
    func testDeadlineUsesActualChargesAndDoesNotReserveOrCharge() {
        var budget = NarrationBudget()
        XCTAssertTrue(budget.charge(words: 20, limit: 30, now: 100))
        XCTAssertEqual(budget.nextAvailableAt(words: 25, limit: 30, now: 101), 160)
        XCTAssertEqual(budget.nextAvailableAt(words: 25, limit: 30, now: 159), 160)
        XCTAssertEqual(budget.allowance(limit: 30, now: 159), 10)
        XCTAssertEqual(budget.nextAvailableAt(words: 25, limit: 30, now: 160), 160)
        XCTAssertEqual(budget.allowance(limit: 30, now: 160), 30)
    }
    func testLoweredLimitKeepsDebtUntilEnoughRealChargesExpire() {
        var budget = NarrationBudget()
        XCTAssertTrue(budget.charge(words: 10, limit: 100, now: 100))
        XCTAssertTrue(budget.charge(words: 60, limit: 100, now: 110))
        XCTAssertTrue(budget.charge(words: 30, limit: 100, now: 120))
        XCTAssertEqual(budget.nextAvailableAt(words: 25, limit: 30, now: 121), 180)
        XCTAssertEqual(budget.nextAvailableAt(words: 25, limit: 100, now: 122), 170)
        XCTAssertEqual(budget.nextAvailableAt(words: 25, limit: 180, now: 123), 123)
    }
    func testInvalidClockOrImpossiblePhraseCannotSchedule() {
        var budget = NarrationBudget()
        XCTAssertTrue(budget.charge(words: 20, limit: 30, now: 100))
        for now in [Double.nan, .infinity, 99] { XCTAssertNil(budget.nextAvailableAt(words: 20, limit: 30, now: now)) }
        XCTAssertNil(budget.nextAvailableAt(words: 31, limit: 30, now: 101))
        XCTAssertNil(budget.nextAvailableAt(words: 0, limit: 30, now: 101))
        XCTAssertEqual(budget.nextAvailableAt(words: 20, limit: 30, now: 102), 160)
    }
    func testCompanionSharedBudgetStillGatesAtWakeAndHazardsBypass() {
        var companion = CompanionAttention()
        let settings = CompanionSettings(wordsPerMinute: 30)
        func answer(_ now: Double) -> InformationCandidate {
            .init(key: "page", kind: .answer, text: "Authored quoted source", words: 25, createdAt: now, expiresAt: now + 2, requested: true)
        }
        guard case .say = companion.decide([answer(100)], moment: .init(now: 100), settings: settings).first else { return XCTFail("Initial requested quote fits") }
        XCTAssertEqual(companion.nextInformationBudgetTime(words: 25, settings: settings, now: 101), 160)
        guard case .wait(_, .budget) = companion.check(answer(159), moment: .init(now: 159), settings: settings) else { return XCTFail("No budget bypass before wake") }
        let hazard = InformationCandidate(key: "hazard", kind: .hazard, text: "Authored warning", words: 100, createdAt: 159, expiresAt: 161)
        guard case .say = companion.check(hazard, moment: .init(now: 159), settings: settings) else { return XCTFail("Hazard remains independent") }
        guard case .say = companion.decide([answer(160)], moment: .init(now: 160), settings: settings).first else { return XCTFail("Exact release admits after revalidation") }
        XCTAssertEqual(companion.nextInformationBudgetTime(words: 25, settings: settings, now: 161), 220)
    }
}
