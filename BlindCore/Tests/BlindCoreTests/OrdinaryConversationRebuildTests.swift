import XCTest
@testable import BlindCore

/// Authored deterministic guard probes, not recovered model transcripts or model-accuracy tests.
/// Supplied history, line 835, preserves only the exact fragment “wavelengths bend”.
/// Its complete rainbow answers, joke, acknowledgments, and story examples are unavailable.
final class OrdinaryConversationRebuildTests: XCTestCase {
    func testAuthoredRainbowWavelengthVariantsRemainConversation() {
        for answer in ["Different wavelengths bend by different amounts.",
                       "Rainbows form because different wavelengths bend by different amounts in water droplets.",
                       "Light rays bend when they pass through water."] {
            XCTAssertFalse(SpatialClaimGuard.containsSpatialClaim(answer), answer)
            XCTAssertTrue(CompanionEvidenceGuard.allows(answer, reports: []), answer)
        }
    }
    func testAuthoredHeatAndArithmeticBaselines() {
        for answer in ["The sun gives us light and heat.", "Sunlight provides light and heat.",
                       "Six times seven is forty-two.", "Six times seven equals 42.", "6 × 7 = 42.",
                       "ستة ضرب سبعة يساوي اثنين وأربعين."] {
            XCTAssertFalse(SpatialClaimGuard.containsSpatialClaim(answer), answer)
            XCTAssertTrue(CompanionEvidenceGuard.allows(answer, reports: []), answer)
        }
    }
    func testAuthoredMetalinguisticRequests() {
        for question in ["What does ‘turn left’ mean?", "What does \"can I reach that shelf\" mean?",
                         "In the story, why does the character ask ‘Can I go home?’?",
                         "What is the meaning of the phrase ‘in front of’?",
                         "Explain the phrase ‘within reach’."] {
            XCTAssertTrue(ConversationDomainPolicy.allowsModelResponse(to: question), question)
        }
    }
    func testAuthoredNonspatialQuotedStoryExplanations() {
        for answer in ["‘The sun gives us light and heat’ describes energy from the Sun.",
                       "‘Six times seven is forty-two’ is a multiplication fact.",
                       "In the story, ‘That is a kind choice’ praises the character's kindness.",
                       "The phrase ‘light and heat’ names two forms of energy."] {
            XCTAssertTrue(CompanionEvidenceGuard.allows(answer, reports: []), answer)
        }
    }
    func testAuthoredHarmlessJokeAndBackpackAcknowledgments() {
        for answer in ["Why did the math book feel sad? It had too many problems!",
                       "I'm glad you found your backpack!", "Great, you found your backpack.",
                       "Thanks for telling me."] {
            XCTAssertTrue(CompanionEvidenceGuard.allows(answer, reports: ["I found my backpack."]), answer)
        }
    }
    func testPhysicalAndHyphenObfuscatedOutputRemainsBlocked() {
        for answer in ["Bend down to pick up the cup.", "The cup is within-reach.",
                       "Your backpack is in-front-of you.", "Move-forward.", "Light the candle.",
                       "Heat the milk.", "The cup is on the table.", "I can see your backpack.",
                       "The phrase ‘walk forward’ is an instruction.", "‘Walk forward.’",
                       "Different wavelengths bend by different amounts. Reach for the cup."] {
            XCTAssertFalse(CompanionEvidenceGuard.allows(answer, reports: []), answer)
        }
    }
    func testMixedAbstractAndPhysicalRequestsRemainBlocked() {
        for question in ["What does ‘turn left’ mean? Can I reach that shelf?",
                         "In the story, why does the character ask ‘Can I go home?’? Now guide me to the door.",
                         "Explain the phrase ‘within reach’, then tell me if this cup is within-reach.",
                         "Can I pick up the book titled ‘Turn Left’?", "Is this cup in-front-of me?",
                         "What does the camera see right now? Can I move forward?"] {
            XCTAssertFalse(ConversationDomainPolicy.allowsModelResponse(to: question), question)
        }
    }
    func testAuthoredAbstractAcknowledgmentVariantsDoNotClaimIdentity() {
        for answer in ["That's a good question!", "This is a thoughtful idea.", "That is a kind choice.",
                       "That's a relief.", "That is a great story."] {
            for reports in [[], ["I found my backpack."], ["My cup was on the table."]] {
                XCTAssertTrue(CompanionEvidenceGuard.allows(answer, reports: reports), "\(answer), reports: \(reports)")
            }
        }
        for answer in ["That is a good choice of chair.", "This is a safe path.", "That is your backpack.",
                       "That's a relief. Your backpack is here.", "That is a kind choice, and I see your cup.",
                       "In the story, ‘Your cup is here’ describes your situation."] {
            XCTAssertFalse(CompanionEvidenceGuard.allows(answer, reports: []), answer)
        }
    }
    func testScientificBendIsNarrowAndNeverMasksAnotherCommand() {
        for answer in ["Wavelengths bend at different angles through a prism.",
                       "Visible wavelengths bend by different amounts.",
                       "Rays of light bend when they pass through glass."] {
            XCTAssertFalse(SpatialClaimGuard.containsSpatialClaim(answer), answer)
            XCTAssertTrue(CompanionEvidenceGuard.allows(answer, reports: []), answer)
        }
        for answer in ["Different wavelengths bend your knees.", "Different wavelengths bend down to the cup.",
                       "Different wavelengths bend by different amounts, so reach for the cup.",
                       "Bend down because different wavelengths bend by different amounts.",
                       "Different wavelengths bend by different amounts. Your cup is in-front-of you.",
                       "Light rays bend when they pass through water. I can see the lamp.",
                       "The camera shows wavelengths bend by different amounts.",
                       "The camera reports wavelengths bend by different amounts.",
                       "The sensor confirms wavelengths bend by different amounts.",
                       "The camera says ‘That is a kind choice’.",
                       "‘Different wavelengths bend by different amounts. Walk forward.’"] {
            XCTAssertFalse(CompanionEvidenceGuard.allows(answer, reports: []), answer)
        }
    }
    func testSpokenEquivalentHyphensDoNotHideGeometryOrHandling() {
        for dash in ["-", "‐", "‑", "‒", "–", "—", "−"] {
            for template in ["A lamp in-front-of you.", "The object is within-your-hands.",
                             "Light-the-candle.", "Heat-the-milk.", "The-path-is-clear."] {
                let answer = template.replacingOccurrences(of: "-", with: dash)
                XCTAssertTrue(SpatialClaimGuard.containsSpatialClaim(answer), answer)
                XCTAssertFalse(CompanionEvidenceGuard.allows(answer, reports: []), answer)
            }
        }
    }
    func testOnlyCompleteQuotedLanguageFramesCanChangeRequestRouting() {
        for question in ["What does the phrase ‘can I walk home’ mean?", "Explain the sentence «can I reach that shelf».",
                         "What is the meaning of the phrase “can I touch it”?", "In the story, why does the character say ‘Can I go home?’?"] {
            XCTAssertTrue(ConversationDomainPolicy.allowsModelResponse(to: question), question)
        }
        for question in ["‘Can I reach that shelf?’", "What does ‘turn left’ mean; can I reach that shelf?",
                         "Explain the phrase ‘within reach’. Can I touch it?", "What does ‘Can I reach that shelf’ mean, and should I go there?",
                         "In the story, can I reach that shelf?", "What does ‘Can I reach that shelf” mean?",
                         "What does ‘Can I reach that shelf’ mean? Guide me to the door."] {
            XCTAssertFalse(ConversationDomainPolicy.allowsModelResponse(to: question), question)
        }
    }
    func testActualStreamingGuardKeepsAbstractAnswerAndRejectsLaterPhysicalChunk() {
        let sentence = "Different wavelengths bend by different amounts."
        var stream = CompanionSentenceStream()
        XCTAssertEqual(stream.append(sentence, reports: []), [sentence])
        XCTAssertEqual(stream.append(sentence + " Reach for the cup.", final: true, reports: []), [])
        XCTAssertTrue(stream.rejected)
        XCTAssertEqual(stream.delivered, sentence)
        var arithmetic = CompanionSentenceStream()
        XCTAssertEqual(arithmetic.append("Six times seven is forty-two.", final: true, reports: ["I found my backpack."]),
                       ["Six times seven is forty-two."])
        XCTAssertFalse(arithmetic.rejected)
    }

}
