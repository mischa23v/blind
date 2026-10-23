import XCTest
@testable import BlindCore

/// Request-routing acceptance, not banknote/model/camera accuracy validation.
final class ConversationDomainPolicyTests: XCTestCase {
    func testPhysicalMoneyQuestionsRequireDedicatedToolEvenForBareAnswers() {
        for question in [
            "Read this banknote", "Identify money", "Can you please read my money?", "Read Saudi money",
            "Is this note fifty?", "Is this bill 50 or 100?", "What is the value of my banknote?",
            "Is the banknote genuine?", "What denomination is this?", "How much is this?",
            "Is this fifty or a hundred?", "Is this 50 or 100?", "Is it twenty riyals?",
            "Are these notes worth 500 riyals?", "What color is this banknote?",
            "هل هذه الورقة خمسين أو مئة؟", "هل ورقتي مئة ريال؟", "هل هذه خمسين أو مئة؟",
            "هذه الورقة خمسين ولا مئة؟", "اقرأ النقود", "اقرأ العُملة", "هل هذه الورقة أصلية؟"
        ] {
            XCTAssertEqual(ConversationDomainPolicy.requiredInspection(for: question), .banknote, question)
            XCTAssertFalse(ConversationDomainPolicy.allowsModelResponse(to: question), question)
        }
    }

    func testOrdinaryMoneyAndPriceDiscussionIsNotGloballyBanned() {
        for question in [
            "What does denomination mean?", "What is money?", "Explain currency", "What is the denomination of a currency?", "Explain the history of Saudi banknotes", "What denominations are used in Saudi Arabia?",
            "How much money should I budget for lunch?", "What should I do with my money?", "Is my money safe in a bank?", "Read me a story about money", "Is 50 riyals a fair price for this shirt?",
            "This shirt cost 50 riyals", "My budget is 100 riyals", "What is the price of milk?",
            "I had a fifty riyal note yesterday", "Do you remember how much money I spent?",
            "Is this fifty minutes?", "Are these fifty shirts?", "Read my meeting notes", "Do not read this banknote",
            "Don't identify my money", "ما معنى فئة العملة؟", "اشرح تاريخ العملة", "سعر القميص خمسون ريال", "لا تقرأ النقود"
        ] {
            XCTAssertNil(ConversationDomainPolicy.requiredInspection(for: question), question)
            XCTAssertTrue(ConversationDomainPolicy.allowsModelResponse(to: question), question)
        }
    }

    func testRecognitionDoesNotDependOnModelResponseWordingOrToolAvailability() {
        let request = "Is my shirt cream or white?"
        XCTAssertEqual(ConversationDomainPolicy.requiredInspection(for: request), .clothingColor)
        // No response/content parameter exists: all answers to this request
        // belong to the code-owned inspection route, including a bare "White."
        XCTAssertFalse(ConversationDomainPolicy.allowsModelResponse(to: request))
        XCTAssertFalse(ConversationDomainPolicy.allowsModelResponse(to: "Is this note fifty?"))
        XCTAssertTrue(ConversationDomainPolicy.allowsModelResponse(to: "I like white shirts and my budget is 50 riyals"))
    }
}
