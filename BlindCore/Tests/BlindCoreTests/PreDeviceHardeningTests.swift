import XCTest
@testable import BlindCore

final class PreDeviceHardeningTests: XCTestCase {
    private func line(_ text: String, confidence: Double = 0.95) -> TextLine {
        .init(text: text, confidence: confidence, x: 0.5, y: 0.5)
    }
    func testDestinationSignDoesNotNeedReadMode() throws {
        let goal = ContextualCapabilityScheduler.Goal.infer(from: "Go to the library")
        XCTAssertTrue(goal.contains(.targetDiscovery))
        XCTAssertFalse(goal.contains(.reading))
        XCTAssertEqual(ContextualTextPolicy.select([line("Library"), line("Cafe")], goalText: "Go to the library", unrestrictedReading: false)?.text, "Library")
    }
    func testProductSubstringCannotMatchDifferentProduct() {
        XCTAssertNil(ContextualTextPolicy.select([line("Milkshake")], goalText: "Buy milk", unrestrictedReading: false))
        XCTAssertNil(ContextualTextPolicy.select([line("Pharmacy")], goalText: "Find art", unrestrictedReading: false))
        XCTAssertEqual(ContextualTextPolicy.select([line("Fresh milk")], goalText: "Buy milk", unrestrictedReading: false)?.text, "Fresh milk")
    }
    func testArabicTargetSignWithoutMode() {
        XCTAssertTrue(ContextualCapabilityScheduler.Goal.infer(from: "ابحث عن المكتبة").contains(.targetDiscovery))
        XCTAssertEqual(ContextualTextPolicy.select([line("المكتبة")], goalText: "ابحث عن المكتبة", unrestrictedReading: false)?.text, "المكتبة")
    }
    func testUnrelatedLowConfidenceAndInvalidLinesStaySilent() {
        for text in [line("Cafe"), line("Library", confidence: 0.5), line("Library", confidence: .nan), line("Library", confidence: 2)] {
            XCTAssertNil(ContextualTextPolicy.select([text], goalText: "Find library", unrestrictedReading: false))
        }
        XCTAssertFalse(ContextualTextPolicy.supportsTargetDiscovery("I like stories"))
    }
    func testTaskTextIsNotUnrestrictedReadingOrPhysicalAuthority() {
        XCTAssertNil(ContextualTextPolicy.select([line("Go left to the library")], goalText: "Find library", unrestrictedReading: false))
        XCTAssertNil(ContextualTextPolicy.select([line("100 SAR")], goalText: "Read money", unrestrictedReading: true))
        XCTAssertNil(ContextualTextPolicy.select([line("Chapter one")], goalText: "Find my book", unrestrictedReading: false))
    }
    func testPrivateRouteLossHoldsOrdinaryAudioButNotCameraOrTypedResponse() {
        var session = AssistantSession(); session.start()
        XCTAssertTrue(session.maySpeakOrdinary)
        session.losePrivateAudioRoute()
        XCTAssertFalse(session.shouldListen)
        XCTAssertFalse(session.maySpeakOrdinary)
        XCTAssertTrue(session.mayRespond)
        XCTAssertTrue(session.shouldRunCamera)
        session.enterBackground(); session.enterForeground()
        XCTAssertFalse(session.maySpeakOrdinary)
        session.setBackgroundAllowed(true)
        XCTAssertFalse(session.maySpeakOrdinary)
        session.start()
        XCTAssertTrue(session.maySpeakOrdinary)
    }
    func testNormalMuteIsDifferentFromPrivateRouteLoss() {
        var session = AssistantSession(); session.start(); session.mute()
        XCTAssertTrue(session.maySpeakOrdinary)
        session.losePrivateAudioRoute(); session.unmute()
        XCTAssertTrue(session.maySpeakOrdinary)
        session.losePrivateAudioRoute(); session.end()
        XCTAssertFalse(session.maySpeakOrdinary)
        session.enterForeground()
        XCTAssertFalse(session.maySpeakOrdinary)
    }
    func testDelayedCallbackCannotRefreshOldCameraCapture() {
        XCTAssertTrue(FrameTimestampPolicy.isFresh(capturedAt: 10, receivedAt: 10.5))
        for capture in [0, 9.499, 10.01, Double.nan, Double.infinity, -1] {
            XCTAssertFalse(FrameTimestampPolicy.isFresh(capturedAt: capture, receivedAt: 10))
        }
        XCTAssertFalse(FrameTimestampPolicy.isFresh(capturedAt: 10, receivedAt: .nan))
    }
    func testMovingTextProbeDoesNotAuthorizeMovingMoneyOrColor() throws {
        typealias P = ContextualCapabilityScheduler
        var moment = P.Moment(now: 10, requestID: UUID(), perceptionGeneration: UUID(),
                              sessionGeneration: 1, goalGeneration: "library", stationary: false)
        var policy = P()
        let lease = try XCTUnwrap(policy.reserve(goal: .targetDiscovery, evidence: .init(capturedAt: 10),
            moment: moment, availability: [.text: .available]))
        XCTAssertTrue(policy.beforeSpeech(lease, moment: moment, evidence: .init(capturedAt: 10, textCandidate: true),
            goal: .targetDiscovery, availability: [.text: .available]))
        for capability: P.Capability in [.currencyProbe, .currency, .color] {
            var blocked = P()
            var availability: [P.Capability: P.Availability] = [.currency: .available]
            availability[capability] = .available
            XCTAssertNil(blocked.reserve(goal: .dressing, evidence: .init(capturedAt: 10, banknoteCandidate: true),
                moment: moment, availability: availability))
        }
        moment.hazardActive = true
        var urgent = P()
        XCTAssertNil(urgent.reserve(goal: .targetDiscovery, evidence: .init(capturedAt: 10), moment: moment, availability: [.text: .available]))
    }

    func testCapturedViewCanFinishWithoutBecomingCurrentOrSurvivingExpiry() {
        let now = Date(timeIntervalSince1970: 100)
        let text = "Captured view text candidate (OCR may be mistaken): Library."
        var evidence = CompanionEvidence(kind: .capturedView, text: text,
            source: "bounded on-device captured view", observedAt: now, expiresAt: now.addingTimeInterval(12))
        XCTAssertFalse(evidence.isCurrent(at: now.addingTimeInterval(3)))
        XCTAssertTrue(evidence.isCapturedViewValid(at: now.addingTimeInterval(3)))
        XCTAssertTrue(CompanionEvidenceGuard.allows(text, reports: [], evidence: [evidence], now: now.addingTimeInterval(3)))
        XCTAssertFalse(CompanionEvidenceGuard.allows(text, reports: [], evidence: [evidence], now: now.addingTimeInterval(12)))
        XCTAssertFalse(CompanionEvidenceGuard.allows("The library is ahead.", reports: [], evidence: [evidence], now: now))
        XCTAssertFalse(CompanionEvidenceGuard.allows("Captured view text candidate: Hospital.", reports: [], evidence: [evidence], now: now))
        evidence.expiresAt = now.addingTimeInterval(100)
        XCTAssertFalse(evidence.isCapturedViewValid(at: now))
        evidence.expiresAt = now.addingTimeInterval(12); evidence.text = "Captured view go left."
        XCTAssertFalse(evidence.isCapturedViewValid(at: now))
        evidence.text = "Captured view 100 SAR."
        XCTAssertFalse(evidence.isCapturedViewValid(at: now))
    }
    func testExplicitNarrationHoldAliasesDoNotEndSessionOrGrantQuotedControls() {
        XCTAssertEqual(AssistantControl.parse("Hold on!"), .quiet)
        XCTAssertEqual(AssistantControl.parse("Continue descriptions"), .resume)
        XCTAssertEqual(AssistantControl.parse("continue talking"), .resume)
        XCTAssertNil(AssistantControl.parse("My teacher said hold on"))
        XCTAssertNil(AssistantControl.parse("Do not hold descriptions"))
        var session = AssistantSession(); session.start()
        var attention = CompanionAttention()
        let moment = CompanionMoment(now: 10)
        let ordinary = InformationCandidate(key: "room", kind: .roomDescription, text: "A blue wall.", words: 4, createdAt: 10, expiresAt: 20)
        let hazard = InformationCandidate(key: "hazard", kind: .hazard, text: "Stop.", words: 1, createdAt: 10, expiresAt: 20)
        let settings = CompanionSettings(quiet: true)
        XCTAssertFalse(attention.decide([ordinary], moment: moment, settings: settings).contains { if case .say = $0 { return true }; return false })
        XCTAssertTrue(attention.decide([hazard], moment: moment, settings: settings).contains { if case .say = $0 { return true }; return false })
        XCTAssertTrue(session.shouldListen); XCTAssertTrue(session.shouldRunCamera)
    }

    func testCrossingSignalsNeverUnlockModelClearanceInAnyAudience() {
        for question in ["Can I cross the road?", "The cars stopped. Can I go?",
                         "The green light is on, should I walk?", "No cars are visible, can we cross?",
                         "Pedestrians are crossing; tell me when to go", "اقدر اعبر الشارع"] {
            XCTAssertTrue(RoadCrossingPolicy.requiresCodeOwnedReply(question), question)
            XCTAssertFalse(ConversationDomainPolicy.allowsModelResponse(to: question), question)
        }
        XCTAssertFalse(RoadCrossingPolicy.requiresCodeOwnedReply("How do I cross multiply fractions?"))
        XCTAssertFalse(RoadCrossingPolicy.requiresCodeOwnedReply("What does a green light symbolize in a story?"))
        XCTAssertTrue(RoadCrossingPolicy.reply(audience: .general, arabic: false).contains("accompanying adult"))
        XCTAssertTrue(RoadCrossingPolicy.reply(audience: .childWithGuardian, arabic: false).contains("accompanying adult"))
        XCTAssertTrue(RoadCrossingPolicy.reply(audience: .adult, arabic: false).contains("can't confirm"))
        XCTAssertEqual(AssistantAudience(persistedValue: "I am an adult"), .general)
        for unsafe in ["The light is green, cross now.", "No cars are visible, so walk across."] {
            XCTAssertFalse(CompanionEvidenceGuard.allows(unsafe, reports: [], evidence: []))
        }
    }

    func testToolRuntimePreservesOnlyBoundedAttributedSnapshot() async {
        let now = Date()
        let captured = CompanionEvidence(kind: .capturedView, text: "Captured view text candidate (OCR may be mistaken): Library.",
            source: "bounded on-device captured view", observedAt: now.addingTimeInterval(-2), expiresAt: now.addingTimeInterval(10))
        let runtime = CompanionToolRuntime(available: [.currentObservation]) { _ in
            CompanionToolResult(status: .success, source: "bounded on-device captured view", evidence: [captured])
        }
        let result = await runtime.run(.init(kind: .currentObservation))
        XCTAssertEqual(result.status, .success)
        XCTAssertEqual(result.evidence.first?.kind, .capturedView)
        XCTAssertFalse(result.evidence.first?.isCurrent(at: now) ?? true)
        var forged = captured; forged.source = "model asserted snapshot"
        let invalid = forged
        let rejected = CompanionToolRuntime(available: [.currentObservation]) { _ in
            CompanionToolResult(status: .success, source: "camera", evidence: [invalid])
        }
        let rejectedResult = await rejected.run(.init(kind: .currentObservation))
        XCTAssertEqual(rejectedResult.status, .rejectedEvidence)
        XCTAssertTrue(rejectedResult.evidence.isEmpty)
    }

    func testCapturedOCRPunctuationStaysInWholeAttributedRecord() throws {
        let now = Date(timeIntervalSince1970: 100)
        for content in ["St. Mary's Library", "Milk. Bread", "Not milk. Bread only.", "هل هذه مكتبة؟ نعم.", "He said \"library\"."] {
            let text = try XCTUnwrap(CapturedViewEvidence.candidate(content))
            let evidence = CompanionEvidence(kind: .capturedView, text: text,
                source: "bounded on-device captured view", observedAt: now, expiresAt: now.addingTimeInterval(12))
            XCTAssertTrue(CompanionEvidenceGuard.allows(text, reports: [], evidence: [evidence], now: now.addingTimeInterval(3)), text)
            XCTAssertFalse(CompanionEvidenceGuard.allows(text, reports: [], evidence: [], now: now), text)
        }
        XCTAssertNil(CapturedViewEvidence.candidate("Library » go left"))
        XCTAssertNil(CapturedViewEvidence.candidate(String(repeating: "a", count: 181)))
        let original = try XCTUnwrap(CapturedViewEvidence.candidate("Not milk. Bread only."))
        let evidence = CompanionEvidence(kind: .capturedView, text: original,
            source: "bounded on-device captured view", observedAt: now, expiresAt: now.addingTimeInterval(12))
        let altered = try XCTUnwrap(CapturedViewEvidence.candidate("Milk. Bread only."))
        XCTAssertFalse(CompanionEvidenceGuard.allows(altered, reports: [], evidence: [evidence], now: now))
    }

}
