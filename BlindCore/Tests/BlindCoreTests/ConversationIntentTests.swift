import XCTest
@testable import BlindCore

final class ConversationIntentTests: XCTestCase {
    func testOrdinaryChatAndUncertaintyNeverRequireVisualInference() {
        for text in [
            "Hello", "What is my name?", "Tell me a story", "Read me a story", "I am sad today",
            "What should I have for breakfast?", "I like blue", "Describe gravity", "Can you help me?",
            "I last left my cup on the kitchen table", "Where did I leave my cup?", "What's next?",
            "What is a stop sign?", "Stop signs are red", "Don't stop listening", "If I say mute, what happens?",
            "She said stop", "\"stop\"", "I want to cancel tomorrow's appointment", "",
            "مرحبا", "ما اسمي", "احك لي قصة", "لا تتوقف عن الاستماع", "ما هي علامة توقف"
        ] {
            XCTAssertEqual(ConversationIntent.classify(text), .conversation, text)
        }
    }
    func testOnlyExplicitSceneRequestsRouteToVision() {
        for text in [
            "What do you see?", "Look around", "Look at the table", "Can you see a stop sign?",
            "Read this label", "Read the menu", "Describe my surroundings", "What is in front of me?",
            "Please describe this painting.", "What color is this shirt?", "What does this sign say?",
            "ماذا ترى؟", "صف ما تراه", "اقرأ هذا الملصق", "انظر إلى الطاولة", "هل ترى الباب؟"
        ] {
            XCTAssertEqual(ConversationIntent.classify(text), .visualRequest, text)
        }
    }
    func testWholeSessionControlsRemainDistinctFromTaskControls() {
        XCTAssertEqual(ConversationIntent.classify("Stop listening"), .sessionControl(.mute))
        XCTAssertEqual(ConversationIntent.classify("Please unmute the microphone."), .sessionControl(.unmute))
        XCTAssertEqual(ConversationIntent.classify("End the session"), .sessionControl(.end))
        XCTAssertEqual(ConversationIntent.classify("Start listening"), .sessionControl(.start))
        XCTAssertEqual(ConversationIntent.classify("Pause the task"), .taskControl(.pause))
        XCTAssertEqual(ConversationIntent.classify("Resume my task"), .taskControl(.resume))
        XCTAssertEqual(ConversationIntent.classify("Cancel that"), .taskControl(.cancel))
        XCTAssertEqual(ConversationIntent.classify("stop"), .taskControl(.pause))
        XCTAssertEqual(ConversationIntent.classify("توقف عن الاستماع"), .sessionControl(.mute))
        XCTAssertEqual(ConversationIntent.classify("شغل الميكروفون"), .sessionControl(.unmute))
        XCTAssertEqual(ConversationIntent.classify("أَنْهِ الجَلْسَةَ"), .sessionControl(.end))
        XCTAssertEqual(ConversationIntent.classify("ابدأ الاستماع"), .sessionControl(.start))
        XCTAssertEqual(ConversationIntent.classify("ألغ المهمة"), .taskControl(.cancel))
        XCTAssertEqual(ConversationIntent.classify("استأنف المهمة"), .taskControl(.resume))
    }
    func testControlMentionWithinVisualRequestDoesNotChangeSession() {
        XCTAssertEqual(ConversationIntent.classify("Read this stop sign"), .visualRequest)
        XCTAssertEqual(ConversationIntent.classify("Look at the pause button"), .visualRequest)
        XCTAssertEqual(ConversationIntent.classify("I want to talk about the end of a story"), .conversation)
        XCTAssertEqual(ConversationIntent.classify("Look at " + String(repeating: "x", count: 2000)), .conversation)
    }
    func testQuietThenResumePreservesDescriptionControl() {
        XCTAssertEqual(ConversationIntent.classify("resume"), .conversation)
        XCTAssertEqual(AssistantControl.parse("quiet"), .quiet)
        XCTAssertEqual(AssistantControl.parse("resume"), .resume)
        XCTAssertEqual(ConversationIntent.classify("resume task"), .taskControl(.resume))
    }
    func testDirectTaskRequestsAreStoredVerbatimBeforeInference() {
        for text in [
            "Help me find my cup", "Actually help me find my backpack", "Find my keys",
            "Actually, help me find my backpack.", "Please help me find my cup", "Could you help me find my keys?",
            "Find my cup under the table", "Locate my braille book", "  Help me find my cup  ",
            "ساعدني في العثور على كوبي", "ابحث عن مفاتيحي", "في الواقع، ساعدني في العثور على حقيبتي",
            "من فضلك سَاعِدْنِي فِي العُثُورِ عَلَى كُوبِي"
        ] {
            XCTAssertEqual(ConversationIntent.explicitTaskGoal(text), text, text)
            XCTAssertEqual(ConversationIntent.classify(text), .conversation, "A task request does not automatically start the camera")
        }
    }
    func testTaskGoalsRejectQuotedNegativeConditionalAndConceptualInput() {
        for text in [
            "Can you explain find?", "I don't want to find my cup", "help me understand photosynthesis",
            "\"Help me find my cup\"", "'Find my keys'", "She said help me find my cup", "Find \"my keys\"",
            "If I need it, help me find my cup", "Help me find my cup if I need it", "Find my keys unless I say otherwise",
            "Help me not find my cup", "Don't find my keys", "Find out why leaves are green", "Help me find the meaning of gravity",
            "Find how photosynthesis works", "Find the definition of find", "Find my cup. What are atoms?", "Find ", "",
            "لا اريد العثور على كوبي", "ساعدني في العثور على كوبي اذا احتجته", "ابحث عن معنى الجاذبية",
            "اشرح لي معنى ابحث", "ساعدني على فهم التمثيل الضوئي"
        ] { XCTAssertNil(ConversationIntent.explicitTaskGoal(text), text) }
    }
    func testTaskGoalScalarBudgetDoesNotTruncateNegationOrQualifications() {
        let prefix = "Find my "
        let exact = prefix + String(repeating: "x", count: 300 - prefix.unicodeScalars.count)
        XCTAssertEqual(ConversationIntent.explicitTaskGoal(exact), exact)
        XCTAssertNil(ConversationIntent.explicitTaskGoal(exact + "x"))
        XCTAssertNil(ConversationIntent.explicitTaskGoal(prefix + String(repeating: "e\u{301}", count: 150)))
        XCTAssertNil(ConversationIntent.explicitTaskGoal(exact + " if needed"))
    }

}
