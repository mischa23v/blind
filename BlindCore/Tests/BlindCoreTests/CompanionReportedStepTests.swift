import XCTest
@testable import BlindCore
final class CompanionReportedStepTests: XCTestCase {
    func testGenericReportsStaySourceAttributedAndBoundToExactCurrentStep() {
        for report in ["I got the milk", "I've retrieved the milk", "I put the cereal on the table", "جبت الحليب", "انا اخذت الحليب", "I got الحليب"] {
            let value = CompanionReportedStep.proposed(step: "Check ingredients", currentStep: "Check ingredients", quote: report, latest: report, goalRevision: "goal-1")
            XCTAssertEqual(value?.report, report)
            XCTAssertEqual(value?.step, "Check ingredients")
            XCTAssertTrue(value?.source.contains("not sensor confirmed") == true)
        }
    }
    func testAmbiguityNegationUnrelatedBindingAndSourceChangesDoNotAdvance() {
        for report in ["done", "I am done", "خلصت", "I didn't get the milk", "I will get it", "I might have it", "I said I got the milk", "Mom got the milk", "I got it in the game", "انا لم احضر الحليب", "انا سوف احضر الحليب", "I got the milk?"] {
            XCTAssertNil(CompanionReportedStep.proposed(step: "Get milk", currentStep: "Get milk", quote: report, latest: report, goalRevision: "g"), report)
        }
        XCTAssertNil(CompanionReportedStep.proposed(step: "Get cereal", currentStep: "Get milk", quote: "I got cereal", latest: "I got cereal", goalRevision: "g"))
        XCTAssertNil(CompanionReportedStep.proposed(step: "Get milk", currentStep: "Get milk", quote: "I got milk", latest: "I did not get milk. I got milk in the game", goalRevision: "g"))
    }
}
