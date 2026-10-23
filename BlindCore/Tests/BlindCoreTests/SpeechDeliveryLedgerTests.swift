import XCTest
@testable import BlindCore

final class SpeechDeliveryLedgerTests: XCTestCase {
    func testRequestedStreamingUsesCancellableSynthesisWithVoiceOverOn() {
        for voiceOver in [false, true] {
            XCTAssertEqual(SpeechDeliveryLedger.transport(for: .requested(UUID()), priority: .information,
                                                         voiceOverRunning: voiceOver), .synthesized)
        }
    }

    func testAmbientAndSafetyKeepVoiceOverAnnouncements() {
        XCTAssertEqual(SpeechDeliveryLedger.transport(for: .narration(UUID()), priority: .information,
                                                     voiceOverRunning: true), .accessibility)
        for priority in [SpeechPriority.status, .information, .mobility, .danger] {
            XCTAssertEqual(SpeechDeliveryLedger.transport(for: .untracked, priority: priority,
                                                         voiceOverRunning: true), .accessibility)
            XCTAssertEqual(SpeechDeliveryLedger.transport(for: .untracked, priority: priority,
                                                         voiceOverRunning: false), .synthesized)
        }
        for priority in [SpeechPriority.mobility, .danger] {
            XCTAssertEqual(SpeechDeliveryLedger.transport(for: .requested(UUID()), priority: priority,
                                                         voiceOverRunning: true), .accessibility)
        }
    }

    func testRequestedPhrasesMustFinishBeforeAnotherCanStart() throws {
        var ledger = SpeechDeliveryLedger()
        let firstID = UUID(), secondID = UUID()
        let first = try XCTUnwrap(ledger.begin(text: "A red chair.", priority: .information,
                                               destination: .requested(firstID), transport: .synthesized))
        XCTAssertNil(ledger.begin(text: "A blue table.", priority: .information,
                                  destination: .requested(secondID), transport: .synthesized))
        XCTAssertEqual(ledger.active?.token, first.token)
        XCTAssertEqual(ledger.finish(token: first.token, outcome: .completed, now: 10)?.outcome, .completed)
        let second = try XCTUnwrap(ledger.begin(text: "A blue table.", priority: .information,
                                                destination: .requested(secondID), transport: .synthesized))
        XCTAssertEqual(second.destination, .requested(secondID))
        XCTAssertNotEqual(first.token, second.token)
    }

    func testTerminalEventIsExactlyOnce() throws {
        for outcome in [NarrationDelivery.completed, .interrupted, .unknown] {
            var ledger = SpeechDeliveryLedger()
            let attempt = try XCTUnwrap(ledger.begin(text: "A green lamp.", priority: .information, transport: .synthesized))
            XCTAssertEqual(ledger.finish(token: attempt.token, outcome: outcome, now: 1)?.outcome, outcome)
            XCTAssertNil(ledger.active)
            XCTAssertNil(ledger.finish(token: attempt.token, outcome: .completed, now: 2))
            XCTAssertNil(ledger.finish(token: attempt.token, outcome: .interrupted, now: 2))
        }
    }

    func testCancelledCallbackCannotCompleteReplacementWithSameRequestID() throws {
        var ledger = SpeechDeliveryLedger()
        let id = UUID()
        let old = try XCTUnwrap(ledger.begin(text: "Old details.", priority: .information,
                                             destination: .requested(id), transport: .synthesized))
        XCTAssertEqual(ledger.finish(token: old.token, outcome: .interrupted, now: 1)?.outcome, .interrupted)
        let replacement = try XCTUnwrap(ledger.begin(text: "New details.", priority: .information,
                                                     destination: .requested(id), transport: .synthesized))
        XCTAssertNil(ledger.finish(token: old.token, outcome: .completed, now: 2))
        XCTAssertEqual(ledger.active?.token, replacement.token)
        XCTAssertEqual(ledger.finish(token: replacement.token, outcome: .completed, now: 3)?.outcome, .completed)
    }

    func testPriorityPreemptionRequiresExplicitInterruption() throws {
        var ledger = SpeechDeliveryLedger()
        let description = try XCTUnwrap(ledger.begin(text: "A chair.", priority: .information, transport: .synthesized))
        XCTAssertTrue(SpeechPriority.mobility.canInterrupt(ledger.active?.priority))
        XCTAssertNil(ledger.begin(text: "Turn at the mapped door.", priority: .mobility, transport: .synthesized))
        XCTAssertEqual(ledger.finish(token: description.token, outcome: .interrupted, now: 1)?.outcome, .interrupted)
        let mobility = try XCTUnwrap(ledger.begin(text: "Turn at the mapped door.", priority: .mobility, transport: .synthesized))
        XCTAssertFalse(SpeechPriority.information.canInterrupt(ledger.active?.priority))
        XCTAssertTrue(SpeechPriority.danger.canInterrupt(ledger.active?.priority))
        _ = ledger.finish(token: mobility.token, outcome: .interrupted, now: 2)
        XCTAssertNotNil(ledger.begin(text: "Stop.", priority: .danger, transport: .synthesized))
    }

    func testAmbientAndRequestedDestinationsStaySeparate() throws {
        var ledger = SpeechDeliveryLedger()
        let id = UUID()
        let ambient = try XCTUnwrap(ledger.begin(text: "The room has a window.", priority: .information,
                                                 destination: .narration(id), transport: .synthesized))
        XCTAssertEqual(ledger.finish(token: ambient.token, outcome: .completed, now: 1)?.attempt.destination, .narration(id))
        let requested = try XCTUnwrap(ledger.begin(text: "A red frame.", priority: .information,
                                                   destination: .requested(id), transport: .synthesized))
        XCTAssertEqual(ledger.finish(token: requested.token, outcome: .unknown, now: 2)?.attempt.destination, .requested(id))
    }

    func testRepeatedVoiceOverTextCannotProveCompletion() throws {
        var ledger = SpeechDeliveryLedger()
        let first = try XCTUnwrap(ledger.begin(text: "A red chair.", priority: .information, transport: .accessibility))
        XCTAssertFalse(first.completionIsAmbiguous)
        XCTAssertEqual(ledger.finish(token: first.token, outcome: .completed, now: 1)?.outcome, .completed)
        let repeated = try XCTUnwrap(ledger.begin(text: "A red chair.", priority: .information, transport: .accessibility))
        XCTAssertTrue(repeated.completionIsAmbiguous)
        XCTAssertEqual(ledger.finish(token: repeated.token, outcome: .completed, now: 2)?.outcome, .unknown)
        let interrupted = try XCTUnwrap(ledger.begin(text: "A red chair.", priority: .information, transport: .accessibility))
        XCTAssertEqual(ledger.finish(token: interrupted.token, outcome: .interrupted, now: 3)?.outcome, .interrupted)
    }

    func testVoiceOverTextHistoryIsBoundedAndFailsClosedWhenFull() throws {
        var ledger = SpeechDeliveryLedger()
        for index in 0..<512 {
            let attempt = try XCTUnwrap(ledger.begin(text: "Detail \(index).", priority: .information, transport: .accessibility))
            XCTAssertFalse(attempt.completionIsAmbiguous)
            _ = ledger.finish(token: attempt.token, outcome: .completed, now: Double(index))
        }
        let overflow = try XCTUnwrap(ledger.begin(text: "Another detail.", priority: .information, transport: .accessibility))
        XCTAssertTrue(overflow.completionIsAmbiguous)
        XCTAssertEqual(ledger.finish(token: overflow.token, outcome: .completed, now: 513)?.outcome, .unknown)
    }

    func testSynthesisDoesNotInheritVoiceOverTextAmbiguity() throws {
        var ledger = SpeechDeliveryLedger()
        let first = try XCTUnwrap(ledger.begin(text: "A red chair.", priority: .information, transport: .accessibility))
        _ = ledger.finish(token: first.token, outcome: .unknown, now: 1)
        let synthesized = try XCTUnwrap(ledger.begin(text: "A red chair.", priority: .information, transport: .synthesized))
        XCTAssertFalse(synthesized.completionIsAmbiguous)
        XCTAssertEqual(ledger.finish(token: synthesized.token, outcome: .completed, now: 2)?.outcome, .completed)
    }

    func testRejectedTextDoesNotReplaceActiveEcho() throws {
        var ledger = SpeechDeliveryLedger()
        _ = try XCTUnwrap(ledger.begin(text: "I'm listening to your question.", priority: .status, transport: .synthesized))
        XCTAssertNil(ledger.begin(text: "A red wooden chair.", priority: .information, transport: .synthesized))
        XCTAssertTrue(ledger.isLikelyOwnSpeech("I'm", now: 1))
        XCTAssertTrue(ledger.isLikelyOwnSpeech("Listening to your question", now: 1))
        XCTAssertFalse(ledger.isLikelyOwnSpeech("A red wooden chair", now: 1))
        XCTAssertFalse(ledger.isLikelyOwnSpeech("Stop", now: 1))
        XCTAssertFalse(ledger.isLikelyOwnSpeech("question", now: 1))
    }

    func testPrefixMatchDoesNotSuppressDivergentHumanRequest() throws {
        var ledger = SpeechDeliveryLedger()
        _ = try XCTUnwrap(ledger.begin(text: "There is a blue chair.", priority: .information, transport: .synthesized))
        XCTAssertTrue(ledger.isLikelyOwnSpeech("There", now: 1))
        XCTAssertTrue(ledger.isLikelyOwnSpeech("There is", now: 1))
        XCTAssertTrue(ledger.isLikelyOwnSpeech("a blue chair", now: 1))
        XCTAssertFalse(ledger.isLikelyOwnSpeech("There is a green table", now: 1))
        XCTAssertFalse(ledger.isLikelyOwnSpeech("a blue chai", now: 1))
        XCTAssertFalse(ledger.isLikelyOwnSpeech("", now: 1))
    }

    func testEchoTailExpiresAndStaleCallbacksCannotRenewIt() throws {
        var ledger = SpeechDeliveryLedger()
        let old = try XCTUnwrap(ledger.begin(text: "A red chair.", priority: .information, transport: .synthesized))
        _ = ledger.finish(token: old.token, outcome: .interrupted, now: 10)
        XCTAssertTrue(ledger.isLikelyOwnSpeech("A red chair", now: 10.5))
        XCTAssertFalse(ledger.isLikelyOwnSpeech("A red chair", now: 11))
        XCTAssertNil(ledger.finish(token: old.token, outcome: .completed, now: 20))
        XCTAssertFalse(ledger.isLikelyOwnSpeech("A red chair", now: 20))
        XCTAssertFalse(ledger.isLikelyOwnSpeech("A red chair", now: 9))
        XCTAssertFalse(ledger.isLikelyOwnSpeech("A red chair", now: .nan))
    }

    func testOnlyMostRecentOutputRetainsResidualEcho() throws {
        var ledger = SpeechDeliveryLedger()
        let first = try XCTUnwrap(ledger.begin(text: "A red chair.", priority: .information, transport: .synthesized))
        _ = ledger.finish(token: first.token, outcome: .completed, now: 10)
        let second = try XCTUnwrap(ledger.begin(text: "A blue table.", priority: .information, transport: .synthesized))
        _ = ledger.finish(token: second.token, outcome: .completed, now: 10.1)
        XCTAssertFalse(ledger.isLikelyOwnSpeech("A red chair", now: 10.2))
        XCTAssertTrue(ledger.isLikelyOwnSpeech("A blue table", now: 10.2))
    }

    func testResidualEchoCanSpanAdjacentChunksButNotDivergentHumanWords() throws {
        var ledger = SpeechDeliveryLedger()
        let first = try XCTUnwrap(ledger.begin(text: "A red chair.", priority: .information, transport: .synthesized))
        _ = ledger.finish(token: first.token, outcome: .completed, now: 10)
        _ = try XCTUnwrap(ledger.begin(text: "A blue table.", priority: .information, transport: .synthesized))
        XCTAssertTrue(ledger.isLikelyOwnSpeech("A red chair A blue", now: 10.2))
        XCTAssertFalse(ledger.isLikelyOwnSpeech("A red chair Stop talking", now: 10.2))
        XCTAssertFalse(ledger.isLikelyOwnSpeech("A red chair A blue", now: 11))
    }

    func testArabicPrefixesAndPunctuation() throws {
        var ledger = SpeechDeliveryLedger()
        _ = try XCTUnwrap(ledger.begin(text: "أنا أستمع إلى سؤالك.", priority: .status, transport: .synthesized))
        XCTAssertTrue(ledger.isLikelyOwnSpeech("أنا", now: 1))
        XCTAssertTrue(ledger.isLikelyOwnSpeech("أنا أستمع", now: 1))
        XCTAssertTrue(ledger.isLikelyOwnSpeech("أستمع إلى سؤالك", now: 1))
        XCTAssertFalse(ledger.isLikelyOwnSpeech("توقف", now: 1))
    }

    func testEmptyAttemptsAreNeverAccepted() {
        var ledger = SpeechDeliveryLedger()
        XCTAssertNil(ledger.begin(text: "", priority: .information, transport: .synthesized))
        XCTAssertNil(ledger.begin(text: " \n\t", priority: .information, transport: .accessibility))
        XCTAssertNil(ledger.active)
    }
}
