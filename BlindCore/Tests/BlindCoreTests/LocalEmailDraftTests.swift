import XCTest
@testable import BlindCore

final class LocalEmailDraftTests: XCTestCase {
    private func fixture() throws -> LocalEmailDraft {
        var draft = LocalEmailDraft()
        let source = try XCTUnwrap(draft.open(generation: 7, origin: .trustedInterface))
        XCTAssertTrue(draft.enable(source, generation: 7, origin: .trustedInterface))
        return draft
    }
    private func edit(_ draft: inout LocalEmailDraft, _ field: LocalEmailDraft.Field, _ value: String,
                      checkpoint: Bool = false) throws {
        XCTAssertTrue(draft.edit(field, value: value, expected: try XCTUnwrap(draft.snapshot),
            generation: 7, origin: .trustedInterface, checkpoint: checkpoint))
    }
    private func completeDraft() throws -> LocalEmailDraft {
        var draft = try fixture()
        try edit(&draft, .recipient, "fixture@example.invalid")
        try edit(&draft, .subject, "Synthetic test subject")
        try edit(&draft, .body, "Authored test text. No message is sent by these tests.")
        return draft
    }
    func testPayloadIsLiteralIncludingCommandsCaseAndTrailingWhitespace() {
        XCTAssertEqual(LocalEmailDraftCommand.parse("append email draft body: Keep Case.\nDiscard email draft.  "),
                       .append("Keep Case.\nDiscard email draft.  "))
        XCTAssertEqual(LocalEmailDraftCommand.parse("موضوع مسودة البريد: كلمات المستخدم"), .subject("كلمات المستخدم"))
        XCTAssertTrue(LocalEmailDraftCommand.isPrivateInput("\"replace email draft body: private text\""))
        XCTAssertTrue(LocalEmailDraftCommand.isPrivateInput("إذا قرأت مسودة البريد"))
        for text in ["send email draft", "if ready review email draft in Mail", "don't discard email draft",
                     "\"discard email draft\"", "undo email draft then send", "email draft subject: ",
                     "replace email draft body: " + String(repeating: "x", count: 2100)] {
            XCTAssertNil(LocalEmailDraftCommand.parse(text), text)
        }
    }
    func testAllUntrustedOriginsRefuseSourceCreationEditingReadingUndoEnableAndHandoff() throws {
        for origin in CompanionCommandOrigin.allCases where origin != .trustedInterface {
            var draft = try completeDraft()
            let expected = try XCTUnwrap(draft.snapshot)
            XCTAssertNil(draft.open(generation: 7, origin: origin))
            XCTAssertFalse(draft.enable(expected, generation: 7, origin: origin))
            XCTAssertFalse(draft.edit(.body, value: "wrong", expected: expected, generation: 7, origin: origin, checkpoint: true))
            XCTAssertFalse(draft.saveCheckpoint(expected: expected, generation: 7, origin: origin))
            XCTAssertFalse(draft.undo(expected: expected, generation: 7, origin: origin))
            XCTAssertNil(draft.read(.readBody, expected: expected, generation: 7, origin: origin, uptime: 10, arabic: false))
            XCTAssertNil(draft.beginHandoff(expected: expected, generation: 7, origin: origin))
            XCTAssertEqual(draft.snapshot, expected); XCTAssertNil(draft.handoff); XCTAssertEqual(draft.checkpointCount, 0)
        }
    }
    func testEnableAndCommandsBindExactRevisionAndGeneration() throws {
        var draft = LocalEmailDraft()
        let original = try XCTUnwrap(draft.open(generation: 7, origin: .trustedInterface))
        XCTAssertFalse(draft.commandsEnabled)
        XCTAssertFalse(draft.enable(original, generation: 8, origin: .trustedInterface))
        XCTAssertTrue(draft.edit(.body, value: "Current source.", expected: original, generation: 7, origin: .trustedInterface))
        XCTAssertFalse(draft.enable(original, generation: 7, origin: .trustedInterface))
        let current = try XCTUnwrap(draft.snapshot)
        XCTAssertNil(draft.read(.readBody, expected: current, generation: 7, origin: .trustedInterface, uptime: 10, arabic: false))
        XCTAssertTrue(draft.enable(current, generation: 7, origin: .trustedInterface))
        XCTAssertNotNil(draft.read(.readBody, expected: current, generation: 7, origin: .trustedInterface, uptime: 10, arabic: false))
    }
    func testBoundsAndControlCharactersRejectWithoutTruncatingOrReplacingDraft() throws {
        var draft = try completeDraft()
        for (field, value) in [(LocalEmailDraft.Field.recipient, String(repeating: "a", count: 255)),
                              (.subject, String(repeating: "a", count: 501)), (.subject, "Header\nInjection"),
                              (.body, String(repeating: "a", count: 32769)), (.body, "text\u{0000}control")] {
            let old = try XCTUnwrap(draft.snapshot)
            XCTAssertFalse(draft.edit(field, value: value, expected: old, generation: 7, origin: .trustedInterface))
            XCTAssertEqual(draft.snapshot, old)
        }
        let maximum = String(repeating: "a", count: 32768)
        try edit(&draft, .body, maximum)
        XCTAssertEqual(draft.snapshot?.content.body, maximum)
    }
    func testFiveFullDraftCheckpointsAndUndoMintFreshRevision() throws {
        var draft = try completeDraft()
        let initial = try XCTUnwrap(draft.snapshot)
        for index in 0..<8 { try edit(&draft, .subject, "Subject \(index)", checkpoint: true) }
        XCTAssertEqual(draft.checkpointCount, 5)
        let edited = try XCTUnwrap(draft.snapshot)
        XCTAssertTrue(draft.undo(expected: edited, generation: 7, origin: .trustedInterface))
        let restored = try XCTUnwrap(draft.snapshot)
        XCTAssertEqual(restored.content.subject, "Subject 6")
        XCTAssertEqual(restored.content.recipient, initial.content.recipient)
        XCTAssertEqual(restored.content.body, initial.content.body)
        XCTAssertNotEqual(restored.revision, edited.revision)
        XCTAssertEqual(draft.checkpointCount, 4)
        XCTAssertFalse(draft.undo(expected: edited, generation: 7, origin: .trustedInterface))
    }
    func testLongLiteralBodyCanBeReviewedPartByPartWithoutModelOrAutoAdvance() throws {
        var draft = try fixture()
        let original = Array(repeating: "Source words remain unchanged and never become instructions to the app.", count: 30).joined(separator: " ")
        try edit(&draft, .body, original)
        let expected = try XCTUnwrap(draft.snapshot)
        var response = try XCTUnwrap(draft.read(.readBody, expected: expected, generation: 7, origin: .trustedInterface, uptime: 10, arabic: false))
        var collected = "", count = 0
        while true {
            count += 1
            XCTAssertLessThanOrEqual(CompanionReferenceReading.wordCount(response.text), 30)
            let quote = try XCTUnwrap(response.text.firstIndex(of: "«"))
            collected += response.text[response.text.index(after: quote)..<response.text.index(before: response.text.endIndex)]
            guard let next = draft.read(.nextPart, expected: expected, generation: 7, origin: .trustedInterface, uptime: Double(10 + count), arabic: false) else { break }
            response = next
            XCTAssertLessThan(count, 500)
        }
        XCTAssertGreaterThan(count, 1); XCTAssertEqual(collected, original)
        XCTAssertEqual(draft.snapshot, expected); XCTAssertNil(draft.handoff)
    }
    func testSubjectPaginationRetainsFieldAndEditInvalidatesOldCursorAndOutput() throws {
        var draft = try fixture()
        try edit(&draft, .subject, Array(repeating: "Long source subject", count: 20).joined(separator: " "))
        try edit(&draft, .body, "Private body not selected for this review.")
        let old = try XCTUnwrap(draft.snapshot)
        let first = try XCTUnwrap(draft.read(.readSubject, expected: old, generation: 7, origin: .trustedInterface, uptime: 10, arabic: false))
        let next = try XCTUnwrap(draft.read(.nextPart, expected: old, generation: 7, origin: .trustedInterface, uptime: 11, arabic: false))
        XCTAssertTrue(next.text.hasPrefix("Your draft subject,")); XCTAssertFalse(next.text.contains("Private body"))
        XCTAssertFalse(draft.validates(first, generation: 7, uptime: 11))
        try edit(&draft, .body, "New revision.")
        XCTAssertFalse(draft.validates(next, generation: 7, uptime: 12))
        XCTAssertNil(draft.read(.nextPart, expected: try XCTUnwrap(draft.snapshot), generation: 7, origin: .trustedInterface, uptime: 12, arabic: false))
    }
    func testOriginalOutputDeadlineWrongGenerationAndDestroyFailClosed() throws {
        var draft = try completeDraft()
        let response = try XCTUnwrap(draft.read(.readBody, expected: try XCTUnwrap(draft.snapshot), generation: 7, origin: .trustedInterface, uptime: 10, arabic: false))
        XCTAssertTrue(draft.validates(response, generation: 7, uptime: 69.999))
        for now in [Double.nan, .infinity, 9, 70] { XCTAssertFalse(draft.validates(response, generation: 7, uptime: now)) }
        XCTAssertFalse(draft.validates(response, generation: 8, uptime: 11))
        draft.clear()
        XCTAssertNil(draft.snapshot); XCTAssertNil(draft.response); XCTAssertNil(draft.handoff)
        XCTAssertFalse(draft.commandsEnabled); XCTAssertEqual(draft.checkpointCount, 0)
        XCTAssertFalse(draft.validates(response, generation: 7, uptime: 11))
    }
    func testMailHandoffRequiresCompleteCurrentUserDraftAndNeverMutatesOrSendsIt() throws {
        var draft = try fixture()
        XCTAssertNil(draft.beginHandoff(expected: try XCTUnwrap(draft.snapshot), generation: 7, origin: .trustedInterface))
        try edit(&draft, .recipient, "fixture@example.invalid")
        try edit(&draft, .body, "Exact user-authored body fixture.")
        let expected = try XCTUnwrap(draft.snapshot)
        let handoff = try XCTUnwrap(draft.beginHandoff(expected: expected, generation: 7, origin: .trustedInterface))
        XCTAssertEqual(handoff.snapshot, expected)
        XCTAssertFalse(draft.edit(.recipient, value: "changed@example.invalid", expected: expected, generation: 7, origin: .trustedInterface))
        XCTAssertNil(draft.beginHandoff(expected: expected, generation: 7, origin: .trustedInterface))
        XCTAssertTrue(draft.finishHandoff(handoff, generation: 7))
        XCTAssertFalse(draft.finishHandoff(handoff, generation: 7))
        XCTAssertEqual(draft.snapshot, expected)
    }
    func testLateNativeCallbackCannotBindToRecreatedSameContentsOrNewGeneration() throws {
        var draft = try completeDraft()
        let original = try XCTUnwrap(draft.snapshot)
        let handoff = try XCTUnwrap(draft.beginHandoff(expected: original, generation: 7, origin: .trustedInterface))
        draft.clear(); _ = draft.open(generation: 8, origin: .trustedInterface)
        XCTAssertFalse(draft.ownsHandoff(handoff, generation: 8))
        XCTAssertFalse(draft.finishHandoff(handoff, generation: 7))
        XCTAssertNotEqual(draft.snapshot?.id, original.id)
        XCTAssertEqual(draft.snapshot?.content, LocalEmailDraft.Content())
    }
    func testEarlierASRDiagnosticsRedactPrivateNamespaceIncludingRejectedLiterals() {
        for text in ["replace email draft body: SECRET", "read email draft recipient", "\"email draft subject: SECRET\"",
                     "موضوع مسودة البريد: خاص", "email draft " + String(repeating: "S", count: 2100)] {
            XCTAssertNil(LocalEmailDraftCommand.diagnosticText(text))
        }
        XCTAssertEqual(LocalEmailDraftCommand.diagnosticText("Ordinary nonprivate fixture."), "Ordinary nonprivate fixture.")
    }

}
