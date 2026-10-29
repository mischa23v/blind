import XCTest
@testable import BlindAssist

/// Deterministic result-policy tests, not Foundation Models acceptance.
/// No model, asset download, network, or microphone is used.
final class ConversationRuntimeFailureTests: XCTestCase {
    func testRuntimeFailureNeverMasqueradesAsGeneratedContent() {
        for failure in [LocalImageAnswer.ConversationRuntimeFailure.generationFailed, .modelUnavailable] {
            for arabic in [false, true] {
                let answer = LocalImageAnswer.conversationFailure(failure, arabic: arabic)
                XCTAssertNil(answer.text)
                XCTAssertNil(answer.taskUpdate)
                XCTAssertEqual(answer.conversationRuntimeFailure, failure)
                XCTAssertEqual(answer.conversationOperationalFallback, answer.status)
                XCTAssertFalse(answer.status.isEmpty)
            }
        }
    }
    func testGenerationFallbackIsLocalizedAndDoesNotBlameTheQuestion() {
        XCTAssertEqual(LocalImageAnswer.conversationFailure(.generationFailed, arabic: false).conversationOperationalFallback,
                       "I couldn't finish an on-device reply just now.")
        XCTAssertEqual(LocalImageAnswer.conversationFailure(.generationFailed, arabic: true).conversationOperationalFallback,
                       "تعذر إكمال الرد على الجهاز الآن.")
    }
    func testEvidenceRefusalAndCancellationAreNotRuntimeFailure() {
        for answer in [
            LocalImageAnswer(text: "I can't verify that.", status: "Unsupported local claim withheld; current evidence is unknown."),
            LocalImageAnswer(text: nil, status: "Conversation interrupted."),
            LocalImageAnswer(text: nil, status: "That request exceeds the local context budget. Try a shorter question.")
        ] {
            XCTAssertNil(answer.conversationRuntimeFailure)
            XCTAssertNil(answer.conversationOperationalFallback)
        }
    }
    func testExistingTextIsNeverReplacedOrReplayedByOperationalFallback() {
        let answer = LocalImageAnswer(text: "Already delivered.", status: "failure", conversationRuntimeFailure: .generationFailed)
        XCTAssertNil(answer.conversationOperationalFallback)
        XCTAssertEqual(answer.text, "Already delivered.")
    }
}
