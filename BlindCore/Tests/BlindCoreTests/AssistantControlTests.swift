import XCTest
@testable import BlindCore

final class AssistantControlTests: XCTestCase {
    func testEnglishAndArabicCommandsShareControls() {
        XCTAssertEqual(AssistantControl.parse(" More information! "), .moreInformation)
        XCTAssertEqual(AssistantControl.parse("معلومات أكثر"), .moreInformation)
        XCTAssertEqual(AssistantControl.parse("أوقف الوصف"), .quiet)
        XCTAssertEqual(AssistantControl.parse("كرر الوصف"), .repeatDescription)
        XCTAssertEqual(AssistantControl.parse("resume descriptions"), .resume)
    }
    func testQuestionsContainingControlWordsDoNotTriggerControls() {
        XCTAssertNil(AssistantControl.parse("Is there a quiet place to sit?"))
        XCTAssertNil(AssistantControl.parse("The sign says stop descriptions. What does it mean?"))
        XCTAssertNil(AssistantControl.parse(""))
    }
    func testOfferAnswersAreWholeUtterancesOnly() {
        XCTAssertEqual(AssistantControl.offerAnswer("Yes."), .yes)
        XCTAssertEqual(AssistantControl.offerAnswer(" not now "), .no)
        XCTAssertEqual(AssistantControl.offerAnswer("نعم"), .yes)
        XCTAssertEqual(AssistantControl.offerAnswer("لا"), .no)
        XCTAssertNil(AssistantControl.offerAnswer("Yes, but where is the door?"))
        XCTAssertNil(AssistantControl.offerAnswer("No idea what this sign says"))
    }
    func testExplicitGoalsAreBoundedAndQuestionsDoNotChangeTheGoal() {
        XCTAssertEqual(AssistantControl.explicitGoal("Take me to the bathroom."), "the bathroom")
        XCTAssertEqual(AssistantControl.explicitGoal("أريد الذهاب إلى غرفة النوم"), "غرفة النوم")
        XCTAssertNil(AssistantControl.explicitGoal("Where should I go to buy a book?"))
        XCTAssertNil(AssistantControl.explicitGoal("Go to "))
        XCTAssertNil(AssistantControl.explicitGoal("Go to " + String(repeating: "a", count: 301)))
    }
}
