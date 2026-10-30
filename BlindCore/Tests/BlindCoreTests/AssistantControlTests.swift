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
    func testPoliteNarrationAliasesAreBoundedCompleteRequests() {
        for text in ["Please stay quiet while I listen to the story.",
                     "Please be quiet while I listen!", "Please pause descriptions.",
                     "Please hold descriptions", "please stay quiet"] {
            XCTAssertEqual(AssistantControl.parse(text), .quiet)
        }
        for text in ["Please resume descriptions.", "Please continue talking!",
                     "Resume descriptions please"] {
            XCTAssertEqual(AssistantControl.parse(text), .resume)
        }
    }
    func testPoliteAliasRejectsQuotationNegationQuestionsAndOtherPeople() {
        for text in ["Don't stay quiet", "Please don't stay quiet while I listen",
                     "What does quiet mean?", "Please stay quiet?",
                     "She said please stay quiet", "He should stay quiet",
                     "\"Please stay quiet\"", "“Please stay quiet”",
                     "Please resume descriptions?", "Please stay quiet and disable alerts",
                     "Please stay quiet while I listen to the story. Then stop the camera.",
                     String(repeating: " ", count: 257) + "please stay quiet"] {
            XCTAssertNil(AssistantControl.parse(text), text)
        }
    }
    func testResumeNeedsActualHeldNarrationNotAnEndedOrMutedSessionTransition() {
        for text in ["continue", "Wait. Now continue what we were doing.",
                     "Please resume descriptions."] {
            XCTAssertTrue(AssistantControl.resumesHeldNarration(text, isHeld: true))
            XCTAssertFalse(AssistantControl.resumesHeldNarration(text, isHeld: false))
        }
        for text in ["Don't continue", "What comes next?", "She says continue",
                     "\"continue\"", "Wait. Now continue what we were doing?"] {
            XCTAssertFalse(AssistantControl.resumesHeldNarration(text, isHeld: true))
        }
        var session = AssistantSession(); session.start(); session.mute()
        let muted = session
        XCTAssertTrue(AssistantControl.resumesHeldNarration("continue", isHeld: true))
        XCTAssertEqual(session, muted) // parser confers no session permission
        session.end(); let ended = session
        _ = AssistantControl.resumesHeldNarration("continue", isHeld: true)
        XCTAssertEqual(session, ended)
    }

}
