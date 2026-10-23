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

    func testLocalDistanceAndReachQuestionsRequireSpecificPhysicalVerification() {
        for question in [
            "How far is the cup?", "Tell me roughly how far that chair is", "What is the distance from me to the door?",
            "Is this within reach?", "Is my cup close enough?", "How many steps to the kitchen?",
            "How many steps from here to the door?", "Can I reach that shelf?", "Could I maybe pick up this cup?",
            "I think I can reach it", "Maybe I should touch the glass?", "Am I close enough to grab it?",
            "Tell me whether I should walk forward", "Should I try to reach that shelf?", "Can I pick it up?",
            "Can I pick this cup up?", "Is it okay if I cross?", "Is that too far for me?", "Which way is the bathroom?",
            "Is the cup on my right?", "Is that chair behind me?", "Am I at the right chair?",
            "Is it safe to cross?", "Which direction is that chair?", "Should I go this way?",
            "كم يبعد هذا الكوب؟", "كم تبعد الطاولة؟", "ما المسافة بيني وبين الباب؟", "هل هذا قريب؟",
            "هل أقدر أمسك هذا الكوب؟", "ربما أستطيع أن ألمس هذا؟", "هل يمكنني الوصول إلى الباب؟",
            "كم خطوة للباب؟", "هل هو في متناول يدي؟", "هل أقدر أشيله؟", "التقطه",
            "هل الكوب على اليمين؟", "هل أنا عند الكرسي؟"
        ] {
            XCTAssertTrue(ConversationDomainPolicy.requiresPhysicalVerification(for: question), question)
            XCTAssertFalse(ConversationDomainPolicy.allowsModelResponse(to: question), question)
            XCTAssertNil(ConversationDomainPolicy.requiredInspection(for: question), question)
        }
    }

    func testExplicitMovementRequestsStayBlockedWhenHedgedOrMixedWithHomework() {
        for question in [
            "Guide me to the door", "Please help me walk to the chair", "Maybe walk to the door",
            "Could you tell me where to walk?", "Can I walk forward?", "Should I turn left or right?",
            "Can I approach that person?", "Should we follow the dog?", "Can I climb these stairs?",
            "Pick up that bottle", "Perhaps touch the cup", "Help me reach for it", "Follow that person",
            "Show me the way to the exit", "I have homework, but tell me how to walk to that desk",
            "Explain this equation, then can I reach that shelf?", "Left or right?",
            "ساعدني أمشي إلى الباب", "هل أمشي قدام؟", "ربما اقترب من هذا الشخص", "هل أتبع الكلب؟",
            "هل أستطيع أن أصعد هذا الدرج؟", "المس هذا الكوب", "لو سمحت دلني على الباب",
            "ساعدني في الوصول إلى الكرسي", "اشرح الرياضيات ثم هل أقدر أمسك الكوب؟", "يمين ولا يسار؟"
        ] {
            XCTAssertTrue(ConversationDomainPolicy.requiresPhysicalVerification(for: question), question)
            XCTAssertFalse(ConversationDomainPolicy.allowsModelResponse(to: question), question)
        }
    }

    func testOrdinaryHomeworkMathStoriesAndFigurativeConversationRemainAvailable() {
        for question in [
            "Help me with my homework", "What is the distance between points A and B in this diagram?",
            "How many steps does this math problem need?", "How far does light travel in a second?",
            "How far is the moon from Earth?", "Explain distance and displacement", "What is a right angle?",
            "Can you walk me through this equation?", "How do I move the decimal point?", "Cross multiply these fractions",
            "How can I reach my goals?", "Can I follow your reasoning?", "Go on with the story",
            "Tell me a story about a child climbing a mountain", "Why do people walk upright?", "What does approach mean?",
            "I walked to school yesterday", "Don't guide me", "Do not pick up the cup", "What time is it?",
            "ساعدني في الواجب", "اشرح المسافة بين نقطتين", "كم المسافة بين النقطتين في الرسم؟",
            "ما معنى الاقتراب؟", "احك لي قصة عن تسلق جبل", "كيف أصل إلى هدفي؟", "لا تمش", "كم الساعة؟"
        ] {
            XCTAssertFalse(ConversationDomainPolicy.requiresPhysicalVerification(for: question), question)
            XCTAssertTrue(ConversationDomainPolicy.allowsModelResponse(to: question), question)
        }
    }

    func testBoundedLocalPresenceLocationPronounsAndCommonSpellingsRequireEvidence() {
        for question in ["Where is my cane?", "Where is my cup?", "Where are my shoes?", "Where is Mom?",
            "Where's my cup?", "Wheres my cane?", "Wher is my cup?", "Where are my shose?", "Where is it?", "Where are they now?",
            "Are there apples in the fridge?", "Is there any milk in the refrigerator?", "Do I have milk in the fridge?",
            "وين عصاي؟", "أين أمي؟", "وين كوبي؟", "أين حذائي؟", "وينها؟", "هل يوجد حليب في الثلاجة؟", "في تفاح في الثلاجة؟"] {
            XCTAssertTrue(ConversationDomainPolicy.requiresPhysicalVerification(for: question), question)
            XCTAssertFalse(ConversationDomainPolicy.allowsModelResponse(to: question), question)
        }
        for question in ["Why is milk kept in the fridge?", "Tell me a story about Mom", "What are canes made of?",
            "I left my cup in the kitchen yesterday", "Why do apples turn brown?", "Why are shoes useful?",
            "لماذا نحفظ الحليب في الثلاجة؟", "احك لي قصة عن التفاح"] {
            XCTAssertFalse(ConversationDomainPolicy.requiresPhysicalVerification(for: question), question)
            XCTAssertTrue(ConversationDomainPolicy.allowsModelResponse(to: question), question)
        }
    }

    func testLiveTemperatureNeedsAnActualSourceButTemperatureScienceRemainsChat() {
        for question in ["What's the temperature?", "What is the current temperature?", "What is the temp outside?",
            "What is the temprature here?", "What is my temperature?", "How cold is it outside?", "Is this water hot?",
            "What is the temperature of this milk?", "كم درجة الحرارة؟", "كم الحرارة اليوم؟", "وش درجة الحرارة؟",
            "كيف درجة حرارة الجو الان؟", "هل هذا حار؟", "كم حرارتي؟"] {
            XCTAssertTrue(ConversationDomainPolicy.requiresLiveTemperature(for: question), question)
            XCTAssertFalse(ConversationDomainPolicy.allowsModelResponse(to: question), question)
        }
        for question in ["What is temperature?", "Explain temperature for my homework", "What temperature does water boil at?",
            "Convert 30 degrees Celsius to Fahrenheit", "My homework asks how temperature affects gas pressure",
            "ما معنى درجة الحرارة؟", "اشرح الحرارة في واجب العلوم", "كم درجة حرارة غليان الماء؟"] {
            XCTAssertFalse(ConversationDomainPolicy.requiresLiveTemperature(for: question), question)
            XCTAssertTrue(ConversationDomainPolicy.allowsModelResponse(to: question), question)
        }
    }

    func testPlaceTemperatureRequestsAndFridgeWhereQuestionsUseEvidenceRoutes() {
        for question in ["What is the temperature in Khobar?", "What's the temprature in Khober?",
            "What is the tempreture in Al Khobar?", "Temp in Riyadh", "Temperature in London",
            "What is the current tempature in Khobar?", "كم درجة الحرارة في الخبر؟", "وش الحرارة بالخبر؟",
            "درجة الحرارة في الرياض", "كم درجة الحراره في الخبر اليوم؟"] {
            XCTAssertTrue(ConversationDomainPolicy.requiresLiveTemperature(for: question), question)
            XCTAssertFalse(ConversationDomainPolicy.allowsModelResponse(to: question), question)
        }
        for question in ["What is temperature in physics?", "What is the temperature in an ideal gas?",
            "What is the temperature in a vacuum?", "What is the average temperature in Khobar?",
            "Explain temperature in thermodynamics", "ما درجة الحرارة في الغاز المثالي؟", "ما الحرارة في الفيزياء؟"] {
            XCTAssertFalse(ConversationDomainPolicy.requiresLiveTemperature(for: question), question)
            XCTAssertTrue(ConversationDomainPolicy.allowsModelResponse(to: question), question)
        }
        for question in ["Where are apples?", "Where is milk?", "Where are the apples in the fridge?",
            "Where is milk in the fridge?", "Where's the milk in my refrigerator?", "Wher is milk in the fridge?",
            "أين التفاح؟", "وين الحليب في الثلاجة؟", "أين التفاح في الثلاجة؟"] {
            XCTAssertTrue(ConversationDomainPolicy.requiresPhysicalVerification(for: question), question)
            XCTAssertFalse(ConversationDomainPolicy.allowsModelResponse(to: question), question)
        }
        for question in ["Why do apples stay fresh in the fridge?", "Where does milk come from?",
            "Why is milk stored in the fridge?", "لماذا يوضع الحليب في الثلاجة؟"] {
            XCTAssertFalse(ConversationDomainPolicy.requiresPhysicalVerification(for: question), question)
            XCTAssertTrue(ConversationDomainPolicy.allowsModelResponse(to: question), question)
        }
    }

}
