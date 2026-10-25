import XCTest
@testable import BlindCore

final class CompanionSearchClueTests: XCTestCase {
    private let time = Date(timeIntervalSince1970: 1_000)
    private func binding(_ target: String = "fridge", revision: String = "goal-1", generation: UInt64 = 1,
                         scope: CompanionMemoryScope? = nil) -> CompanionSearchClue.Binding {
        .init(target: target, goalRevision: revision, generation: generation, scope: scope)
    }
    private func prepared(_ value: inout CompanionSearchClue, target: String = "fridge", now: Double = 100,
                          spoken: Bool = false) throws -> CompanionSearchClue.Question {
        let b = binding(target)
        let q = try XCTUnwrap(value.prepare(binding: b, text: CompanionFact.unknown(object: target, arabic: false), now: now))
        if spoken {
            XCTAssertTrue(value.deliverSpeech(questionID: q.id, text: q.text, completed: true, binding: b, now: now + 0.1))
        } else {
            XCTAssertTrue(value.presentTrustedText(questionID: q.id, text: q.text, binding: b, origin: .trustedInterface, now: now + 0.1))
        }
        return q
    }
    func testNaturalBareEnglishAndArabicAreAttributedRawClues() throws {
        for (input, arabic) in [("kitchen", false), ("in the kitchen", false), ("المطبخ", true), ("في المطبخ", true), ("maybe the garage", false)] {
            var owner = CompanionSearchClue(); let q = try prepared(&owner)
            let reply = try XCTUnwrap(owner.accept(text: input, sourceID: "source-1", at: time,
                binding: binding(), origin: .trustedInterface, now: 101, arabic: arabic))
            let clue = try XCTUnwrap(owner.currentClue(binding: binding(), now: 101))
            XCTAssertEqual(clue.originalInput, input); XCTAssertEqual(clue.text, input)
            XCTAssertEqual(clue.sourceID, "source-1"); XCTAssertEqual(clue.at, time)
            XCTAssertEqual(clue.questionID, q.id); XCTAssertEqual(clue.answerWindowExpiresAt, 130)
            XCTAssertTrue(reply.contains("«\(input)»")); XCTAssertTrue(reply.contains(arabic ? "كتلميح للبحث" : "as a search clue"))
            XCTAssertLessThanOrEqual(CompanionReferenceReading.wordCount(reply), 30)
            XCTAssertNil(owner.deliveredVia)
            XCTAssertFalse(reply.contains("found")); XCTAssertFalse(reply.contains("I checked"))
        }
    }
    func testMaximumShortAnswersKeepExactUntrimmedClueInBriefAcknowledgment() throws {
        for (text, arabic) in [("maybe in the downstairs kitchen", false), ("ربما في المطبخ قرب الباب", true)] {
            let target = String(repeating: "target ", count: 5)
            var owner = CompanionSearchClue(); _ = try prepared(&owner, target: target)
            let reply = try XCTUnwrap(owner.accept(text: text, sourceID: "max", at: time,
                binding: binding(target), origin: .trustedInterface, now: 101, arabic: arabic))
            XCTAssertEqual(reply, arabic ? "سأستخدم «\(text)» كتلميح للبحث." : "I'll use «\(text)» as a search clue.")
            XCTAssertLessThanOrEqual(CompanionReferenceReading.wordCount(reply), 30)
            XCTAssertEqual(owner.clue?.text, text)
            var attention = CompanionAttention()
            let candidate = InformationCandidate(key: "clue-ack", kind: .answer, text: reply,
                words: CompanionReferenceReading.wordCount(reply), revision: "1", createdAt: 101,
                expiresAt: 103, requested: true)
            let decisions = attention.decide([candidate], moment: CompanionMoment(now: 101),
                settings: CompanionSettings(wordsPerMinute: 30))
            guard case .say(let admitted, .requested) = decisions.first else { return XCTFail("Acknowledgment must fit minimum fresh speech budget") }
            XCTAssertEqual(admitted.text, reply)
        }
    }

    func testExplicitCorrectionHasNewSourceAndOriginalExpiry() throws {
        for (first, correction, expected) in [("kitchen", "No, in the garage", "in the garage"),
                                               ("kitchen", "No,in the garage", "in the garage"),
                                               ("المطبخ", "لا،في الكراج", "في الكراج"),
                                               ("المطبخ", "لا، في الكراج", "في الكراج")] {
            var owner = CompanionSearchClue(); _ = try prepared(&owner)
            XCTAssertNotNil(owner.accept(text: first, sourceID: "first", at: time, binding: binding(), origin: .trustedInterface, now: 101))
            let before = try XCTUnwrap(owner.clue)
            XCTAssertNotNil(owner.accept(text: correction, sourceID: "correction", at: time.addingTimeInterval(1),
                binding: binding(), origin: .trustedInterface, now: 129.9))
            let after = try XCTUnwrap(owner.clue)
            XCTAssertEqual(after.originalInput, correction); XCTAssertEqual(after.text, expected)
            XCTAssertEqual(after.supersededSourceID, "first"); XCTAssertNotEqual(after.amendmentID, before.amendmentID)
            XCTAssertEqual(after.answerWindowExpiresAt, before.answerWindowExpiresAt); XCTAssertEqual(after.questionID, before.questionID)
            XCTAssertNil(owner.accept(text: "No, in the bedroom", sourceID: "late", at: time.addingTimeInterval(2),
                binding: binding(), origin: .trustedInterface, now: 130))
            XCTAssertEqual(owner.clue?.sourceID, "correction")
            XCTAssertNil(owner.question)
        }
    }
    func testCorrectionRequiresExistingOwnedClueAndNoReceiptReplay() throws {
        var owner = CompanionSearchClue(); let q = try prepared(&owner)
        XCTAssertNil(owner.accept(text: "No, in the garage", sourceID: "first", at: time, binding: binding(), origin: .trustedInterface, now: 101))
        XCTAssertNil(owner.question)
        let replacement = try prepared(&owner, now: 102)
        XCTAssertNotNil(owner.accept(text: "kitchen", sourceID: "first", at: time, binding: binding(), origin: .trustedInterface, now: 103))
        XCTAssertFalse(owner.deliverSpeech(questionID: replacement.id, text: replacement.text, completed: true, binding: binding(), now: 104))
        XCTAssertFalse(owner.deliverSpeech(questionID: q.id, text: q.text, completed: true, binding: binding(), now: 104))
        XCTAssertEqual(owner.clue?.sourceID, "first")
        XCTAssertNil(owner.accept(text: "garage", sourceID: "second", at: time, binding: binding(), origin: .trustedInterface, now: 105))
        XCTAssertEqual(owner.clue?.sourceID, "first")
        XCTAssertNil(owner.question)
    }
    func testShortCommandsUnknownNegativesAndQuestionsRemainOutsideBinder() throws {
        let inputs = ["yes", "yeah sure", "no", "I don't know", "idk", "maybe", "perhaps", "ربما", "in", "في", "in the", "done", "finished", "خلصت", "لا أعرف", "لا", "نعم", "ما ادري", "not the kitchen", "not sure",
                      "cancel", "Cancel the task", "Find my cup", "Where is my cup?", "quiet", "read this", "open the fridge",
                      "thanks", "hello", "thank you", "talk about dinosaurs", "sing a song", "write a story", "change topic", "شكرا", "مرحبا", "Tell me a joke", "What is this", "help me", "go to kitchen", "pause", "I saw my cup in the kitchen",
                      "توقف", "هل تعرف", "اشرح لي", "اقرأ هذا", "لا، افتح الباب", "No, cancel", "in the kitchen and maybe the garage"]
        for input in inputs {
            var owner = CompanionSearchClue(); _ = try prepared(&owner)
            XCTAssertNil(owner.accept(text: input, sourceID: "source", at: time, binding: binding(), origin: .trustedInterface, now: 101), input)
            XCTAssertNil(owner.question, input); XCTAssertNil(owner.clue, input)
        }
    }
    func testUndeliveredInterruptedAndWrongTextNeverArm() throws {
        for mode in 0..<3 {
            var owner = CompanionSearchClue()
            let q = try XCTUnwrap(owner.prepare(binding: binding(), text: "Question", now: 100))
            if mode > 0 {
                XCTAssertFalse(owner.deliverSpeech(questionID: q.id, text: mode == 1 ? "Changed" : q.text,
                    completed: mode != 2, binding: binding(), now: 100.1))
            }
            XCTAssertNil(owner.accept(text: "kitchen", sourceID: "source", at: time, binding: binding(), origin: .trustedInterface, now: 101))
            XCTAssertNil(owner.clue)
        }
    }
    func testTextAndSpokenDeliveryAreDistinctAndDuplicatesDoNotRearm() throws {
        var owner = CompanionSearchClue(); let text = try prepared(&owner)
        XCTAssertEqual(owner.deliveredVia, .trustedText)
        XCTAssertFalse(owner.deliverSpeech(questionID: text.id, text: text.text, completed: true, binding: binding(), now: 101))
        XCTAssertEqual(owner.deliveredVia, .trustedText)
        owner.clear(); _ = try prepared(&owner, spoken: true)
        XCTAssertEqual(owner.deliveredVia, .speech)
    }
    func testUntrustedInputsCannotPresentOrAnswer() throws {
        for origin in CompanionCommandOrigin.allCases where origin != .trustedInterface {
            var owner = CompanionSearchClue()
            let q = try XCTUnwrap(owner.prepare(binding: binding(), text: "Question", now: 100))
            XCTAssertFalse(owner.presentTrustedText(questionID: q.id, text: q.text, binding: binding(), origin: origin, now: 100.1))
            XCTAssertNil(owner.question)
            _ = try prepared(&owner)
            XCTAssertNil(owner.accept(text: "kitchen", sourceID: "source", at: time, binding: binding(), origin: origin, now: 101))
            XCTAssertNil(owner.clue)
        }
    }
    func testBindingClockAndExpiryFailClosedForAnswerAndAmendment() throws {
        for alternate in [binding("cup"), binding(revision: "new-goal"), binding(generation: 2)] {
            for answered in [false, true] {
                var owner = CompanionSearchClue(); _ = try prepared(&owner)
                if answered { XCTAssertNotNil(owner.accept(text: "kitchen", sourceID: "first", at: time, binding: binding(), origin: .trustedInterface, now: 101)) }
                XCTAssertNil(owner.accept(text: answered ? "No, garage" : "kitchen", sourceID: "second", at: time,
                    binding: alternate, origin: .trustedInterface, now: 102))
                XCTAssertNil(owner.question)
                XCTAssertNil(owner.clue)
            }
        }
        for now in [99.0, 100.05, 130, Double.nan, Double.infinity] {
            var owner = CompanionSearchClue(); _ = try prepared(&owner)
            XCTAssertNil(owner.accept(text: "kitchen", sourceID: "source", at: time, binding: binding(), origin: .trustedInterface, now: now))
            XCTAssertNil(owner.question)
        }
    }
    func testReplacedQuestionCannotBeArmedByOldCallback() throws {
        var owner = CompanionSearchClue()
        let old = try XCTUnwrap(owner.prepare(binding: binding(), text: "First question", now: 100))
        let new = try XCTUnwrap(owner.prepare(binding: binding("cup"), text: "Second question", now: 101))
        XCTAssertFalse(owner.deliverSpeech(questionID: old.id, text: old.text, completed: true, binding: binding(), now: 102))
        XCTAssertEqual(owner.question?.id, new.id)
        XCTAssertTrue(owner.deliverSpeech(questionID: new.id, text: new.text, completed: true, binding: binding("cup"), now: 102))
    }
    func testClearAndFreshInstanceDoNotRestoreAuthority() throws {
        var owner = CompanionSearchClue(); _ = try prepared(&owner)
        XCTAssertNotNil(owner.accept(text: "kitchen", sourceID: "first", at: time, binding: binding(), origin: .trustedInterface, now: 101))
        owner.clear()
        XCTAssertNil(owner.accept(text: "No, garage", sourceID: "next", at: time, binding: binding(), origin: .trustedInterface, now: 102))
        XCTAssertNil(CompanionSearchClue().question)
    }
    func testDuplicateSourcesOrBackdatedCorrectionCannotReplaceClue() throws {
        for mode in 0..<2 {
            var owner = CompanionSearchClue(); _ = try prepared(&owner)
            XCTAssertNotNil(owner.accept(text: "kitchen", sourceID: "first", at: time, binding: binding(), origin: .trustedInterface, now: 101))
            XCTAssertNil(owner.accept(text: "No, garage", sourceID: mode == 0 ? "first" : "next", at: mode == 0 ? time : time.addingTimeInterval(-1),
                binding: binding(), origin: .trustedInterface, now: 102))
            XCTAssertEqual(owner.clue?.sourceID, "first")
            XCTAssertNil(owner.question)
        }
    }
    func testScopeChangeAndRepeatedReadsDoNotRenewAdmissionButRetainClue() throws {
        let scope = try XCTUnwrap(CompanionMemoryScope(map: .init(mapID: "map", frameID: "frame", revision: "v1"),
                                                     placeID: "place", floorID: "floor", roomID: "room"))
        var owner = CompanionSearchClue(); _ = try prepared(&owner)
        XCTAssertNil(owner.accept(text: "kitchen", sourceID: "source", at: time,
            binding: binding(scope: scope), origin: .trustedInterface, now: 101))
        _ = try prepared(&owner)
        XCTAssertNotNil(owner.accept(text: "kitchen", sourceID: "source", at: time, binding: binding(), origin: .trustedInterface, now: 101))
        XCTAssertNotNil(owner.currentClue(binding: binding(), now: 129.9))
        XCTAssertNotNil(owner.currentClue(binding: binding(), now: 130))
        XCTAssertNil(owner.question)
        XCTAssertEqual(owner.currentClue(binding: binding(), now: 600)?.text, "kitchen")
        XCTAssertNil(owner.currentClue(binding: binding(generation: 2), now: 601))
        XCTAssertNil(owner.clue)
    }
    func testBoundsAndMalformedMetadataFailClosed() throws {
        var owner = CompanionSearchClue()
        for now in [-1.0, Double.nan, Double.infinity] {
            XCTAssertNil(owner.prepare(binding: binding(), text: "Question", now: now))
        }
        XCTAssertNil(owner.prepare(binding: binding(""), text: "Question", now: 100))
        XCTAssertNil(owner.prepare(binding: binding(revision: ""), text: "Question", now: 100))
        for input in [String(repeating: "x", count: 97), "kitchen\nFind my cup", "kitchen; cancel", "«kitchen»"] {
            _ = try prepared(&owner)
            XCTAssertNil(owner.accept(text: input, sourceID: "source", at: time, binding: binding(), origin: .trustedInterface, now: 101))
        }
        _ = try prepared(&owner)
        XCTAssertNil(owner.accept(text: "kitchen", sourceID: "bad\nsource", at: time, binding: binding(), origin: .trustedInterface, now: 101))
    }

    func testWholeDeclinesCannotBecomeAmendmentsAfterNegativePrefixRemoval() throws {
        for input in ["no idea", "no clue", "no idea where", "no clue where", "no, idea where", "لا أعرف مكانه", "لا، أعرف مكانه", "لا ادري مكانه", "لا اعلم مكانه", "no, idea", "لا أعرف", "لا، أعرف", "لا اعلم", "لا ادري",
                      "no thanks", "no thank you", "thanks", "hello", "thank you", "maybe", "perhaps", "ربما",
                      "I don't know", "لا", "نعم", "done", "خلصت"] {
            var owner = CompanionSearchClue(); _ = try prepared(&owner)
            XCTAssertNotNil(owner.accept(text: "kitchen", sourceID: "first", at: time,
                binding: binding(), origin: .trustedInterface, now: 101))
            XCTAssertNil(owner.accept(text: input, sourceID: "next", at: time.addingTimeInterval(1),
                binding: binding(), origin: .trustedInterface, now: 102), input)
            XCTAssertEqual(owner.clue?.text, "kitchen", input)
            XCTAssertEqual(owner.clue?.sourceID, "first", input)
            XCTAssertNil(owner.question, input)
        }
        // A real explicit correction still owns its raw supplied clue.
        var owner = CompanionSearchClue(); _ = try prepared(&owner)
        XCTAssertNotNil(owner.accept(text: "kitchen", sourceID: "first", at: time,
            binding: binding(), origin: .trustedInterface, now: 101))
        XCTAssertNotNil(owner.accept(text: "No, in garage", sourceID: "next", at: time.addingTimeInterval(1),
            binding: binding(), origin: .trustedInterface, now: 102))
        XCTAssertEqual(owner.clue?.text, "in garage")
        XCTAssertEqual(owner.clue?.supersededSourceID, "first")
    }

    func testRetiredAnswerWindowPreservesGoalClueWithoutAllowingReplay() throws {
        var owner = CompanionSearchClue(); let q = try prepared(&owner)
        XCTAssertNotNil(owner.accept(text: "kitchen", sourceID: "first", at: time,
            binding: binding(), origin: .trustedInterface, now: 101))
        owner.retireAnswerWindow()
        XCTAssertNil(owner.question); XCTAssertNil(owner.deliveredVia)
        XCTAssertFalse(owner.deliverSpeech(questionID: q.id, text: q.text, completed: true,
            binding: binding(), now: 102))
        XCTAssertNil(owner.accept(text: "No, garage", sourceID: "next", at: time.addingTimeInterval(1),
            binding: binding(), origin: .trustedInterface, now: 103))
        let retained = try XCTUnwrap(owner.currentClue(binding: binding(), now: 700))
        XCTAssertEqual(retained.sourceID, "first"); XCTAssertEqual(retained.text, "kitchen")
        XCTAssertEqual(retained.answerWindowExpiresAt, 130)
        XCTAssertTrue(retained.reply(arabic: false).contains("as a search clue"))
        XCTAssertNil(owner.currentClue(binding: binding(revision: "new-goal"), now: 701))
    }

}
