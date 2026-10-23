import XCTest
@testable import BlindCore

final class VoiceRoomScanConfirmationTests: XCTestCase {
    func testEnglishNamedScanNeedsSeparateConfirmation() {
        var gate = VoiceRoomScanConfirmation()
        XCTAssertEqual(gate.consume("Start scan room Living Room", source: .directUser, now: 10),
                       .requestConfirmation(name: "Living Room"))
        XCTAssertTrue(gate.hasPendingConfirmation)
        XCTAssertTrue(gate.promptDidFinish(now: 10))
        XCTAssertEqual(gate.consume("yes", source: .directUser, now: 11), .start(name: "Living Room"))
        XCTAssertFalse(gate.hasPendingConfirmation)
        XCTAssertEqual(gate.consume("yes", source: .directUser, now: 12), .none)
    }

    func testUnnamedScanAndExplicitStartReply() {
        for phrase in ["scan room", "scan the room", "start room scan", "start scanning the room", "scan this room"] {
            var gate = VoiceRoomScanConfirmation()
            XCTAssertEqual(gate.consume(phrase, source: .directUser, now: 0), .requestConfirmation(name: nil), phrase)
            XCTAssertTrue(gate.promptDidFinish(now: 0))
            XCTAssertEqual(gate.consume("start", source: .directUser, now: 1), .start(name: nil), phrase)
        }
    }

    func testArabicNamedAndUnnamedRequests() {
        var gate = VoiceRoomScanConfirmation()
        XCTAssertEqual(gate.consume("ابدأ مسح الغرفة غرفة النوم", source: .directUser, now: 0),
                       .requestConfirmation(name: "غرفة النوم"))
        XCTAssertTrue(gate.promptDidFinish(now: 0))
        XCTAssertEqual(gate.consume("نعم ابدأ المسح", source: .directUser, now: 1), .start(name: "غرفة النوم"))
        XCTAssertEqual(gate.consume("امسح الغرفة", source: .directUser, now: 2), .requestConfirmation(name: nil))
        XCTAssertTrue(gate.promptDidFinish(now: 2))
        XCTAssertEqual(gate.consume("نعم", source: .directUser, now: 3), .start(name: nil))
    }

    func testCaseWhitespaceAndSingleSpeechPunctuation() {
        var gate = VoiceRoomScanConfirmation()
        XCTAssertEqual(gate.consume("  SCAN   ROOM  Kitchen!  ", source: .directUser, now: 0),
                       .requestConfirmation(name: "Kitchen"))
        XCTAssertTrue(gate.promptDidFinish(now: 0))
        XCTAssertEqual(gate.consume("Yes.", source: .directUser, now: 1), .start(name: "Kitchen"))
    }

    func testOptionalNameIntroducerPreservesLabel() {
        for (phrase, name) in [("scan room named Office 2", "Office 2"),
                               ("start scanning room called Guest-room", "Guest-room"),
                               ("ابدأ مسح غرفة باسم غرفة الضيوف", "غرفة الضيوف")] {
            var gate = VoiceRoomScanConfirmation()
            XCTAssertEqual(gate.consume(phrase, source: .directUser, now: 0), .requestConfirmation(name: name))
            XCTAssertTrue(gate.promptDidFinish(now: 0))
            XCTAssertEqual(gate.consume("yes", source: .directUser, now: 1), .start(name: name))
        }
    }

    func testNoAffirmativeStartsWithoutPendingRequest() {
        var gate = VoiceRoomScanConfirmation()
        for text in ["yes", "start", "start scanning", "yes start the scan", "نعم", "ابدأ المسح"] {
            XCTAssertEqual(gate.consume(text, source: .directUser, now: 0), .none, text)
        }
    }

    func testModelAndObservedTextCannotRequestOrConfirmOrStop() {
        for source in [VoiceRoomScanConfirmation.Source.modelTool, .observedContent] {
            var gate = VoiceRoomScanConfirmation()
            XCTAssertEqual(gate.consume("scan room Kitchen", source: source, now: 0), .none)
            XCTAssertEqual(gate.consume("yes", source: .directUser, now: 1), .none)
            XCTAssertEqual(gate.consume("scan room Kitchen", source: .directUser, now: 2),
                           .requestConfirmation(name: "Kitchen"))
            XCTAssertTrue(gate.promptDidFinish(now: 2))
            XCTAssertEqual(gate.consume("yes", source: source, now: 3), .none)
            XCTAssertEqual(gate.consume("scan room Bedroom", source: source, now: 3), .none)
            XCTAssertEqual(gate.consume("stop scanning", source: source, now: 3), .none)
            XCTAssertEqual(gate.consume("cancel scanning", source: source, now: 3), .none)
            XCTAssertTrue(gate.hasPendingConfirmation)
            XCTAssertEqual(gate.consume("yes", source: .directUser, now: 4), .start(name: "Kitchen"))
        }
    }

    func testQuotedNegatedHypotheticalAndFamilyDiscussionDoNotRequest() {
        let rejected = [
            "\"scan room\"", "‘scan room Kitchen’", "scan room \"Kitchen\"", "`scan room`",
            "do not scan room", "don't scan room", "not scan room", "I said scan room",
            "Can you scan room?", "scan room?", "what if I say scan room", "if we scan room",
            "scan room if dad asks", "scan room after lunch", "scan room tomorrow", "scan room not now",
            "scan room with my family", "scan room because dad said so", "scan room then start",
            "scan room is what I told my brother", "scan room means record the room",
            "scan room Kitchen and start", "scan room Kitchen. yes", "scan room\nyes",
            "أنا أتكلم مع أخي عن مسح الغرفة", "قال ابدأ مسح الغرفة", "لا تبدأ مسح الغرفة",
            "ابدأ مسح الغرفة؟", "ابدأ مسح الغرفة إذا وافق أبي", "ابدأ مسح الغرفة مع أخي",
            "ابدأ مسح الغرفة لاحقا", "ابدأ مسح الغرفة لو قالت أمي", "«ابدأ مسح الغرفة»"
        ]
        for text in rejected {
            var gate = VoiceRoomScanConfirmation()
            XCTAssertEqual(gate.consume(text, source: .directUser, now: 0), .none, text)
            XCTAssertFalse(gate.hasPendingConfirmation, text)
            XCTAssertEqual(gate.consume("yes", source: .directUser, now: 1), .none, text)
        }
    }

    func testUnrelatedOrAmbiguousReplyConsumesPendingRequest() {
        for reply in ["tell me the time", "maybe", "okay", "yes if dad agrees", "I said yes", "\"yes\"", "نعم ربما", ""] {
            var gate = VoiceRoomScanConfirmation()
            _ = gate.consume("scan room Kitchen", source: .directUser, now: 0)
            XCTAssertTrue(gate.promptDidFinish(now: 0))
            XCTAssertEqual(gate.consume(reply, source: .directUser, now: 1), .none, reply)
            XCTAssertFalse(gate.hasPendingConfirmation, reply)
            XCTAssertEqual(gate.consume("yes", source: .directUser, now: 2), .none, reply)
        }
    }

    func testRepeatedAndReplacementRequestsAlwaysAskAgain() {
        var gate = VoiceRoomScanConfirmation()
        for (phrase, name) in [("scan room Kitchen", "Kitchen"), ("scan room Kitchen", "Kitchen"),
                               ("scan room Bedroom", "Bedroom")] {
            XCTAssertEqual(gate.consume(phrase, source: .directUser, now: 10), .requestConfirmation(name: name))
            XCTAssertTrue(gate.promptDidFinish(now: 10))
        }
        XCTAssertEqual(gate.consume("yes", source: .directUser, now: 11), .start(name: "Bedroom"))
    }

    func testExpirationBoundaryAndNoReplayAfterExpiry() {
        var gate = VoiceRoomScanConfirmation()
        _ = gate.consume("scan room Kitchen", source: .directUser, now: 10)
        XCTAssertTrue(gate.promptDidFinish(now: 10))
        XCTAssertEqual(gate.consume("yes", source: .directUser, now: 30), .start(name: "Kitchen"))
        _ = gate.consume("scan room Kitchen", source: .directUser, now: 40)
        XCTAssertTrue(gate.promptDidFinish(now: 40))
        XCTAssertEqual(gate.consume("yes", source: .directUser, now: 60.000001), .none)
        XCTAssertEqual(gate.consume("yes", source: .directUser, now: 59), .none)
    }

    func testClockRollbackAndInvalidTimesClearPendingRequest() {
        for time in [9.0, -1, Double.nan, Double.infinity, -Double.infinity] {
            var gate = VoiceRoomScanConfirmation()
            _ = gate.consume("scan room", source: .directUser, now: 10)
            XCTAssertTrue(gate.promptDidFinish(now: 10))
            XCTAssertEqual(gate.consume("yes", source: .directUser, now: time), .none)
            XCTAssertEqual(gate.consume("yes", source: .directUser, now: 11), .none)
        }
        for time in [-1.0, Double.nan, Double.infinity, -Double.infinity] {
            var gate = VoiceRoomScanConfirmation()
            XCTAssertEqual(gate.consume("scan room", source: .directUser, now: time), .none)
            XCTAssertFalse(gate.hasPendingConfirmation)
        }
    }

    func testNegativeAndCancelRepliesClearPendingRequest() {
        for reply in ["no", "no thanks", "cancel", "stop", "not now", "لا", "لا شكرا", "إلغاء", "توقف"] {
            var gate = VoiceRoomScanConfirmation()
            _ = gate.consume("scan room", source: .directUser, now: 0)
            XCTAssertTrue(gate.promptDidFinish(now: 0))
            XCTAssertEqual(gate.consume(reply, source: .directUser, now: 1), .cancel, reply)
            XCTAssertFalse(gate.hasPendingConfirmation, reply)
            XCTAssertEqual(gate.consume("yes", source: .directUser, now: 2), .none, reply)
        }
    }

    func testExplicitStopDoesNotNeedPendingRequestOrValidClock() {
        for text in ["stop scanning", "stop the scan", "stop room scan", "أوقف المسح", "أوقف مسح الغرفة"] {
            var gate = VoiceRoomScanConfirmation()
            XCTAssertEqual(gate.consume(text, source: .directUser, now: .nan), .stop, text)
        }
        var gate = VoiceRoomScanConfirmation()
        XCTAssertEqual(gate.consume("no", source: .directUser, now: 0), .none)
        XCTAssertEqual(gate.consume("stop", source: .directUser, now: 0), .none)
    }

    func testExplicitCancelDiscardsRatherThanFinishesAndSaves() {
        for text in ["cancel scanning", "cancel the scan", "cancel room scan", "ألغ المسح", "ألغ مسح الغرفة"] {
            var gate = VoiceRoomScanConfirmation()
            XCTAssertEqual(gate.consume(text, source: .directUser, now: .nan), .cancel, text)
            _ = gate.consume("scan room Kitchen", source: .directUser, now: 0)
            XCTAssertEqual(gate.consume(text, source: .directUser, now: 1), .cancel, text)
            XCTAssertFalse(gate.hasPendingConfirmation)
            XCTAssertEqual(gate.consume("yes", source: .directUser, now: 2), .none, text)
        }
        var gate = VoiceRoomScanConfirmation()
        XCTAssertEqual(gate.consume("cancel", source: .directUser, now: 0), .none)
    }

    func testLifecycleOrGoalCancellationRequiresNewTwoTurnRequest() {
        var gate = VoiceRoomScanConfirmation()
        _ = gate.consume("scan room Bedroom", source: .directUser, now: 0)
        gate.cancel()
        gate.cancel()
        XCTAssertFalse(gate.hasPendingConfirmation)
        XCTAssertEqual(gate.consume("yes", source: .directUser, now: 1), .none)
        XCTAssertEqual(gate.consume("scan room Kitchen", source: .directUser, now: 2),
                       .requestConfirmation(name: "Kitchen"))
        XCTAssertTrue(gate.promptDidFinish(now: 2))
        XCTAssertEqual(gate.consume("yes", source: .directUser, now: 3), .start(name: "Kitchen"))
    }

    func testNamesAndInputAreBoundedAndCannotContainInstructionSyntax() {
        for tail in [String(repeating: "a", count: 65), "one two three four five six seven",
                     "../Kitchen", "Kitchen; start", "Kitchen <start>", "Kitchen 😀", "123", "named"] {
            var gate = VoiceRoomScanConfirmation()
            XCTAssertEqual(gate.consume("scan room " + tail, source: .directUser, now: 0), .none, tail)
        }
        var gate = VoiceRoomScanConfirmation()
        XCTAssertEqual(gate.consume("scan room " + String(repeating: "a", count: 300), source: .directUser, now: 0), .none)
    }

    func testConfirmationBeforePromptCompletionCannotStart() {
        var gate = VoiceRoomScanConfirmation()
        _ = gate.consume("scan room Kitchen", source: .directUser, now: 0)
        XCTAssertEqual(gate.consume("yes", source: .directUser, now: 1), .none)
        XCTAssertFalse(gate.hasPendingConfirmation)
        XCTAssertFalse(gate.promptDidFinish(now: 2))
        XCTAssertEqual(gate.consume("yes", source: .directUser, now: 3), .none)
    }

    func testSlowPromptGetsFullResponseWindowAfterCompletion() {
        var gate = VoiceRoomScanConfirmation()
        _ = gate.consume("scan room Kitchen", source: .directUser, now: 10)
        XCTAssertTrue(gate.promptDidFinish(now: 210))
        XCTAssertEqual(gate.consume("start scanning", source: .directUser, now: 230), .start(name: "Kitchen"))
    }

    func testDuplicateCompletionCannotRenewResponseWindow() {
        var gate = VoiceRoomScanConfirmation()
        _ = gate.consume("scan room Kitchen", source: .directUser, now: 0)
        XCTAssertTrue(gate.promptDidFinish(now: 10))
        XCTAssertFalse(gate.promptDidFinish(now: 25))
        XCTAssertEqual(gate.consume("yes", source: .directUser, now: 30.000001), .none)
        XCTAssertFalse(gate.hasPendingConfirmation)
    }

    func testInvalidOrBackwardsPromptCompletionCancels() {
        for time in [9.0, -1, Double.nan, Double.infinity, -Double.infinity] {
            var gate = VoiceRoomScanConfirmation()
            _ = gate.consume("scan room Kitchen", source: .directUser, now: 10)
            XCTAssertFalse(gate.promptDidFinish(now: time))
            XCTAssertFalse(gate.hasPendingConfirmation)
            XCTAssertFalse(gate.promptDidFinish(now: 11))
            XCTAssertEqual(gate.consume("yes", source: .directUser, now: 12), .none)
        }
        var gate = VoiceRoomScanConfirmation()
        _ = gate.consume("scan room Kitchen", source: .directUser, now: 0)
        XCTAssertTrue(gate.promptDidFinish(now: 10))
        XCTAssertFalse(gate.promptDidFinish(now: 20))
        XCTAssertFalse(gate.promptDidFinish(now: 19))
        XCTAssertFalse(gate.hasPendingConfirmation)
        XCTAssertEqual(gate.consume("yes", source: .directUser, now: 21), .none)
    }

    func testPromptDeliveryHasBoundedLifetime() {
        var gate = VoiceRoomScanConfirmation()
        _ = gate.consume("scan room Kitchen", source: .directUser, now: 0)
        XCTAssertTrue(gate.promptDidFinish(now: 300))
        XCTAssertEqual(gate.consume("yes", source: .directUser, now: 320), .start(name: "Kitchen"))
        _ = gate.consume("scan room Kitchen", source: .directUser, now: 400)
        XCTAssertFalse(gate.promptDidFinish(now: 700.000001))
        XCTAssertFalse(gate.hasPendingConfirmation)
        XCTAssertEqual(gate.consume("yes", source: .directUser, now: 701), .none)
    }

    func testLateCallbackAfterCancellationCannotRestorePendingRequest() {
        var gate = VoiceRoomScanConfirmation()
        XCTAssertFalse(gate.promptDidFinish(now: 0))
        _ = gate.consume("scan room Kitchen", source: .directUser, now: 1)
        gate.cancel()
        XCTAssertFalse(gate.promptDidFinish(now: 2))
        XCTAssertFalse(gate.hasPendingConfirmation)
        XCTAssertEqual(gate.consume("yes", source: .directUser, now: 3), .none)
    }
}
