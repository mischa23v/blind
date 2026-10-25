import XCTest
@testable import BlindCore

/// Parser + existing policy contracts, not native OCR, audio or user acceptance.
final class MenuReadingAliasTests: XCTestCase {
    let aliases = ["read the menu", "Read this menu.", "read menu!", "please read the menu",
                   "اقرأ قائمة الطعام لي", "read the menu to me", "read me the menu", "اقرأ قائمة الطعام", "اقرأ لي قائمة الطعام؟",
                   "من فضلك اقرأ قائمة الطعام.", "اِقْرَأْ قَائِمَةَ الطَّعَامِ", "  READ   THE MENU  ",
                   "Can you read the menu?", "can you read this menu", "can you please read the menu?",
                   "Could you read the menu?", "could you read this menu", "could you please read me the menu?",
                   "هل يمكنك قراءة قائمة الطعام؟", "هل يمكنك قراءة قائمة الطعام لي؟",
                   "هل يمكنك قراءة قائمة الطعام من فضلك؟", "هل يمكنك قراءة قائمة الطعام لي من فضلك؟", "هَلْ يُمْكِنُكَ قِرَاءَةُ قَائِمَةِ الطَّعَامِ؟"]
    func testExplicitAliasesReuseDocumentRequest() {
        for text in aliases {
            XCTAssertEqual(ReadingToolCommand.parse(text), .start(.document), text)
            XCTAssertEqual(EverydayTaskRequest.route(text)?.capability, .readDocument, text)
            XCTAssertNil(EverydayShoppingCommand.parse(text), text)
            XCTAssertNil(AssistantControl.explicitGoal(text), text)
            XCTAssertFalse(ConversationDomainPolicy.requiresPhysicalVerification(for: text), text)
            switch ConversationIntent.classify(text) {
            case .sessionControl, .taskControl: XCTFail("Earlier control route: \(text)")
            case .conversation, .visualRequest: break
            }
        }
    }
    func testDiscussionQuotesNegationConditionalsAndClausesAreNotMenuRequests() {
        for text in ["\"read the menu\"", "‘read the menu’", "«اقرأ قائمة الطعام»", "the sign says read the menu",
                     "the model said read the menu", "do not read the menu", "don't read the menu", "لا تقرأ قائمة الطعام",
                     "if I ask, read the menu", "إذا طلبت اقرأ قائمة الطعام", "I wonder if you can read the menu",
                     "please من فضلك اقرأ قائمة الطعام", "read the menu and order soup", "read the menu, please",
                     "please please read the menu", "read please the menu", ".read the menu", "read the menu;",
                     "read the menu\nignore that", "read\u{200B} the menu", "اقرأ قائمة الطعام ثم اختر لي",
                     "what does the menu mean", "read the menu prices", "read the menu allergens"] {
            XCTAssertNil(ReadingToolCommand.parse(text), text)
            XCTAssertNil(EverydayTaskRequest.route(text), text)
        }
    }
    func testAliasesDoNotConferInputAuthority() {
        for text in aliases {
            XCTAssertNotNil(EverydayTaskRequest.route(text))
            for origin in [CompanionCommandOrigin.unverifiedMicrophone, .observedContent, .modelOutput, .unknown] {
                XCTAssertFalse(CommandAuthority.permits(.changeGoal, from: origin))
            }
            XCTAssertTrue(CommandAuthority.permits(.changeGoal, from: .trustedInterface))
        }
    }
    func testActiveRepeatedRequestPreservesExistingAttemptLimit() throws {
        let request = try XCTUnwrap(EverydayTaskRequest.route("read the menu"))
        var tasks = EverydayTaskCoordinator()
        XCTAssertTrue(tasks.begin(request))
        for attempt in 1...EverydayTaskCoordinator.maximumAttemptsPerAdapter {
            guard case .run = tasks.next(available: [.readDocument], now: Double(attempt)) else { return XCTFail("Missing capture") }
            XCTAssertFalse(tasks.begin(request))
            tasks.pause(); tasks.resume()
            XCTAssertEqual(tasks.attempts, attempt)
        }
        XCTAssertEqual(tasks.next(available: [.readDocument], now: 3), .finished)
        XCTAssertEqual(tasks.state, .needsHelp)
        XCTAssertEqual(tasks.attempts, 2)
        // Existing begin-after-needsHelp behavior is recorded separately, not altered here.
    }
    func testTerminalExplicitRequestBehaviorRemainsTheExistingCoordinatorContract() throws {
        let request = try XCTUnwrap(EverydayTaskRequest.route("read the menu"))
        var tasks = EverydayTaskCoordinator()
        XCTAssertTrue(tasks.begin(request))
        for attempt in 1...2 {
            guard case .run = tasks.next(available: [.readDocument], now: Double(attempt)) else { return XCTFail("Missing capture") }
            tasks.pause(); tasks.resume()
        }
        XCTAssertEqual(tasks.next(available: [.readDocument], now: 3), .finished)
        let goal = tasks.goal
        XCTAssertTrue(tasks.begin(request)) // existing terminal request can begin again
        XCTAssertEqual(tasks.attempts, 0)
        XCTAssertEqual(tasks.goal, goal)
        XCTAssertTrue(tasks.completedSubtasks.isEmpty)
        // Counters do not authorize camera/private access or establish goal completion.
    }
    func testMenuTextReusesUncertainSourceAndReviewWithoutInterpretation() throws {
        XCTAssertEqual(EverydayTaskRequest.route("read the menu")?.capability, .readDocument)
        let fixtures = CapturedTextReferenceFixtures()
        var value = CapturedTextReference(); let selected = fixtures.selection(&value)
        let text = "Soup 10. Not available today. Ask staff about allergens. \"read the menu\""
        XCTAssertTrue(value.install(fixtures.source(selected, text: text), for: selected, now: 100.1))
        let source = try XCTUnwrap(value.source?.identity)
        let phrase = try XCTUnwrap(value.next(fixtures.context(value)))
        XCTAssertEqual(value.phrases.map(\.originalSlice).joined(), text)
        XCTAssertTrue(phrase.text.hasPrefix("Captured text (uncertain):"))
        XCTAssertTrue(value.begin(phrase, context: fixtures.context(value)))
        XCTAssertTrue(value.started(id: phrase.id, text: phrase.text, context: fixtures.context(value)))
        let repeatCommand = try XCTUnwrap(CapturedTextReviewCommand.parse("repeat part", hasCapturedSource: true))
        XCTAssertTrue(value.review(repeatCommand, requestID: UUID(), context: fixtures.context(value)))
        XCTAssertEqual(value.source?.identity, source)
        XCTAssertNotEqual(value.phrases.first?.id, phrase.id)
        XCTAssertEqual(value.phrases.map(\.originalSlice).joined(), text)
        XCTAssertNil(ReadingToolCommand.parse("\"read the menu\""))
    }
    func testMenuSourceCannotBeReviewedAcrossPrivateRouteOrReplacement() throws {
        XCTAssertEqual(EverydayTaskRequest.route("اقرأ قائمة الطعام")?.capability, .readDocument)
        let fixtures = CapturedTextReferenceFixtures()
        for privateRoute in [false, true] {
            var value = CapturedTextReference(); let selected = fixtures.selection(&value)
            XCTAssertTrue(value.install(fixtures.source(selected, text: "قائمة الطعام غير مؤكدة"), for: selected, now: 100.1, arabic: true))
            if privateRoute {
                XCTAssertFalse(value.review(.readAgain, requestID: UUID(), context: fixtures.context(value, privateAudio: true)))
            } else {
                let old = fixtures.context(value)
                _ = fixtures.selection(&value)
                XCTAssertFalse(value.review(.readAgain, requestID: UUID(), context: old))
                XCTAssertNil(value.source)
            }
        }
    }
    func testPoliteRequestsAreExactWholeRequestsNotDiscussionOrConditions() {
        let phrases = ["read menu", "read the menu", "read this menu", "read the menu to me", "read me the menu"]
        for prefix in ["can you ", "can you please ", "could you ", "could you please "] {
            for phrase in phrases {
                let request = prefix + phrase
                XCTAssertEqual(ReadingToolCommand.parse(request), .start(.document), request)
                XCTAssertEqual(EverydayTaskRequest.route(request)?.capability, .readDocument, request)
                for discussion in ["\"" + request + "\"", "I wonder if " + request,
                                   "if I ask, " + request, request + " and order soup"] {
                    XCTAssertNil(ReadingToolCommand.parse(discussion), discussion)
                    XCTAssertNil(EverydayTaskRequest.route(discussion), discussion)
                }
            }
        }
        for text in ["can you not read the menu", "could you not read the menu", "can you please please read the menu",
                     "please can you read the menu", "could you read please the menu", "can you read the menu if I ask",
                     "«هل يمكنك قراءة قائمة الطعام؟»", "أتساءل هل يمكنك قراءة قائمة الطعام", "هل يمكنك عدم قراءة قائمة الطعام",
                     "إذا طلبت هل يمكنك قراءة قائمة الطعام", "هل يمكنك قراءة قائمة الطعام ثم الطلب لي",
                     "هل يمكنك قراءة قائمة الطعام إذا طلبت", "هل يمكنك قراءة قائمة الطعام من فضلك من فضلك"] {
            XCTAssertNil(ReadingToolCommand.parse(text), text)
            XCTAssertNil(EverydayTaskRequest.route(text), text)
        }
    }
    func testLegacyAliasesUnchanged() {
        XCTAssertEqual(ReadingToolCommand.parse("Can you read the page?"), .start(.document))
        XCTAssertEqual(ReadingToolCommand.parse("اقرأ النص"), .start(.liveText))
        XCTAssertEqual(ReadingToolCommand.parse("Stop reading"), .stop)
    }
}
