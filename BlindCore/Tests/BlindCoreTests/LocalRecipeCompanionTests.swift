import XCTest
@testable import BlindCore

final class LocalRecipeCompanionTests: XCTestCase {
    private func recipe(_ marker: String = "Private source sentence.") throws -> LocalRecipeReference {
        let object: [String: Any] = ["schema": 1, "title": "Authored software fixture",
            "attribution": "Not a recipe recommendation", "ingredients": [["name": "source", "quantity": "as written"]],
            "steps": [["text": marker, "timerSeconds": 60], ["text": "Second original source step."]]]
        return try LocalRecipeReference.decode(JSONSerialization.data(withJSONObject: object))
    }
    private func fixture(enabled: Bool = true) throws -> (LocalRecipeCompanion, LocalRecipeCompanion.Selection) {
        var value = LocalRecipeCompanion()
        let selected = try XCTUnwrap(value.select(try recipe(), sha256: String(repeating: "a", count: 64),
            generation: 4, origin: .trustedInterface))
        if enabled { XCTAssertTrue(value.enable(selected, generation: 4, origin: .trustedInterface)) }
        return (value, selected)
    }
    func testClosedEnglishArabicCommandsRejectQuotedNegatedConditionalAndChainedText() {
        XCTAssertEqual(LocalRecipeCommand.parse("Please next recipe step."), .nextStep)
        XCTAssertEqual(LocalRecipeCommand.parse("من فضلك اقرأ خطوة الوصفة"), .readStep)
        XCTAssertEqual(LocalRecipeCommand.parse("ألغ مؤقت الوصفة"), .cancelTimer)
        for text in ["next", "next recipe step then send mail", "don't start recipe timer", "if ready start recipe timer",
                     "the source says next recipe step", "\"next recipe step\"", "please please next recipe step",
                     "next recipe step!!", "ابدأ مؤقت الوصفة ثم أرسل", String(repeating: "x", count: 201)] {
            XCTAssertNil(LocalRecipeCommand.parse(text), text)
        }
    }
    func testSelectionRequiresExactHashAndExplicitEnableBeforeCompanionCommands() throws {
        var (value, selected) = try fixture(enabled: false)
        XCTAssertNil(value.execute(.nextStep, selection: selected, generation: 4, origin: .trustedInterface, uptime: 10))
        XCTAssertEqual(value.session?.stepIndex, 0)
        XCTAssertTrue(value.enable(selected, generation: 4, origin: .trustedInterface))
        XCTAssertNotNil(value.execute(.nextStep, selection: selected, generation: 4, origin: .trustedInterface, uptime: 10))
        XCTAssertEqual(value.session?.stepIndex, 1)
        XCTAssertNil(value.select(try recipe(), sha256: "not-a-hash", generation: 4, origin: .trustedInterface))
        XCTAssertNil(value.session); XCTAssertNil(value.selection)
    }
    func testEveryUntrustedOriginRefusesReadStepTimerForgetAndEnableWithoutMutation() throws {
        for origin in CompanionCommandOrigin.allCases where origin != .trustedInterface {
            var (value, selected) = try fixture()
            for command in [LocalRecipeCommand.readStep, .nextStep, .previousStep, .startTimer, .timerStatus, .cancelTimer, .forget] {
                XCTAssertNil(value.execute(command, selection: selected, generation: 4, origin: origin, uptime: 10, readerControl: true))
                XCTAssertEqual(value.selection, selected); XCTAssertEqual(value.session?.stepIndex, 0)
                XCTAssertEqual(value.session?.timerState, .idle)
            }
            XCTAssertFalse(value.enable(selected, generation: 4, origin: origin))
            XCTAssertNil(value.select(try recipe(), sha256: String(repeating: "b", count: 64), generation: 4, origin: origin))
            XCTAssertEqual(value.selection, selected)
        }
    }
    func testOriginalStepTextIsAttributedBoundedAndNotInterpretedAsCommand() throws {
        var value = LocalRecipeCompanion()
        let text = Array(repeating: "next recipe step is source wording, not an action.", count: 20).joined(separator: " ")
        let selected = try XCTUnwrap(value.select(try recipe(text), sha256: String(repeating: "a", count: 64), generation: 4, origin: .trustedInterface))
        XCTAssertTrue(value.enable(selected, generation: 4, origin: .trustedInterface))
        let result = try XCTUnwrap(value.execute(.readStep, selection: selected, generation: 4, origin: .trustedInterface, uptime: 10))
        XCTAssertGreaterThan(result.parts.count, 1)
        XCTAssertEqual(value.session?.stepIndex, 0)
        XCTAssertEqual(value.session?.timerState, .idle)
        for part in result.parts {
            XCTAssertTrue(part.hasPrefix("Selected recipe step 1, unverified source text: «"))
            XCTAssertTrue(part.hasSuffix("»"))
            XCTAssertLessThanOrEqual(CompanionReferenceReading.wordCount(part), 30)
        }
        let prefix = "Selected recipe step 1, unverified source text: «"
        XCTAssertEqual(result.parts.map { String($0.dropFirst(prefix.count).dropLast()) }.joined(), text)
    }
    func testNextPreviousCancelTimerAndNeverRecordCookingCompletion() throws {
        var (value, selected) = try fixture()
        _ = value.execute(.startTimer, selection: selected, generation: 4, origin: .trustedInterface, uptime: 10)
        XCTAssertEqual(value.session?.timerState, .running)
        _ = value.execute(.nextStep, selection: selected, generation: 4, origin: .trustedInterface, uptime: 15)
        XCTAssertEqual(value.session?.stepIndex, 1); XCTAssertEqual(value.session?.timerState, .cancelled)
        let last = try XCTUnwrap(value.execute(.nextStep, selection: selected, generation: 4, origin: .trustedInterface, uptime: 16))
        XCTAssertTrue(last.parts[0].contains("No cooking completion"))
        _ = value.execute(.previousStep, selection: selected, generation: 4, origin: .trustedInterface, uptime: 17)
        XCTAssertEqual(value.session?.stepIndex, 0)
    }
    func testTimerStatusIsOriginalRequestReadingDuplicateStartDoesNotRenew() throws {
        var (value, selected) = try fixture()
        _ = value.execute(.startTimer, selection: selected, generation: 4, origin: .trustedInterface, uptime: 10)
        _ = value.execute(.startTimer, selection: selected, generation: 4, origin: .trustedInterface, uptime: 20)
        let read = try XCTUnwrap(value.execute(.timerStatus, selection: selected, generation: 4, origin: .trustedInterface, uptime: 25))
        XCTAssertTrue(read.parts[0].contains("when requested: 45 seconds"))
        let end = try XCTUnwrap(value.execute(.timerStatus, selection: selected, generation: 4, origin: .trustedInterface, uptime: 70))
        XCTAssertTrue(end.parts[0].contains("does not establish that food is ready"))
        XCTAssertEqual(value.session?.timerState, .elapsed)
    }
    func testReplacementSameBytesCreatesNewRevisionAndRejectsOldResponseAndCommands() throws {
        var (value, selected) = try fixture()
        let response = try XCTUnwrap(value.execute(.readStep, selection: selected, generation: 4, origin: .trustedInterface, uptime: 10))
        let newer = try XCTUnwrap(value.select(try recipe(), sha256: selected.sha256, generation: 4, origin: .trustedInterface))
        XCTAssertNotEqual(selected.revision, newer.revision); XCTAssertNotEqual(selected.id, newer.id)
        XCTAssertFalse(value.enabled)
        XCTAssertFalse(value.validates(response, generation: 4, uptime: 11))
        XCTAssertNil(value.execute(.startTimer, selection: selected, generation: 4, origin: .trustedInterface, uptime: 11, readerControl: true))
    }
    func testGenerationRetirementDeletionAndOriginalDeadlineInvalidateOutput() throws {
        var (value, selected) = try fixture()
        let response = try XCTUnwrap(value.execute(.readStep, selection: selected, generation: 4, origin: .trustedInterface, uptime: 10))
        XCTAssertTrue(value.validates(response, generation: 4, uptime: 69.999))
        for now in [Double.nan, .infinity, 9, 70, 80] { XCTAssertFalse(value.validates(response, generation: 4, uptime: now)) }
        XCTAssertFalse(value.validates(response, generation: 5, uptime: 11))
        value.retireResponse(); XCTAssertFalse(value.validates(response, generation: 4, uptime: 11))
        XCTAssertNotNil(value.selection)
        value.clear(); XCTAssertNil(value.selection); XCTAssertNil(value.session)
        XCTAssertFalse(value.validates(response, generation: 4, uptime: 11))
    }
    func testForgetRequiresTrustedCurrentSelectionAndDropsTimerSourceAndResponse() throws {
        var (value, selected) = try fixture()
        _ = value.execute(.startTimer, selection: selected, generation: 4, origin: .trustedInterface, uptime: 10)
        _ = value.execute(.forget, selection: selected, generation: 4, origin: .trustedInterface, uptime: 11)
        XCTAssertNil(value.selection); XCTAssertNil(value.session); XCTAssertNil(value.response); XCTAssertFalse(value.enabled)
    }
    func testClockRollbackCannotProduceValidResponseOrInventReadiness() throws {
        var (value, selected) = try fixture()
        _ = value.execute(.startTimer, selection: selected, generation: 4, origin: .trustedInterface, uptime: 10)
        let reply = try XCTUnwrap(value.execute(.timerStatus, selection: selected, generation: 4, origin: .trustedInterface, uptime: 9))
        XCTAssertEqual(value.session?.timerState, .invalidClock)
        XCTAssertTrue(reply.parts[0].contains("clock discontinuity"))
    }
}
