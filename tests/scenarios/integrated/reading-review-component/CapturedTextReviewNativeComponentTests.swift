import XCTest
import AVFoundation
import NaturalLanguage
import CryptoKit
import BlindCore

/// Authored-source component integration. This bridge is NOT NavigationModel,
/// Feedback, camera/Vision acquisition or proof of acoustic intelligibility.
@MainActor
private final class ReviewComponentPlayback: NSObject, AVSpeechSynthesizerDelegate {
    enum Phase: String { case initial, previous, repeated, next, done }
    struct Active {
        let utterance: AVSpeechUtterance
        let phrase: CapturedTextReference.Phrase
        let selection: CapturedTextReference.Selection
    }
    var reader = CapturedTextReference()
    var attention = CompanionAttention()
    let settings = CompanionSettings(wordsPerMinute: 30)
    let speech = AVSpeechSynthesizer()
    var active: Active?
    var wake: Task<Void, Never>?
    var identity: CompanionReferenceIdentity!
    var originalSelection: CapturedTextReference.Selection!
    var originalPhrases: [CapturedTextReference.Phrase] = []
    var originalReceipt: CapturedTextReference.PlaybackReceipt?
    var replacedAttemptReceipt: CapturedTextReference.PlaybackReceipt?
    var repeatReceipt: CapturedTextReference.PlaybackReceipt?
    var finalReceipt: CapturedTextReference.PlaybackReceipt?
    var attempts: [[String: Any]] = []
    var events: [[String: String]] = []
    var completed: [(String, UUID, String)] = []
    var failure: String?
    var terminal = false
    var awaitingOldCancellation = false
    var oldCancellationRejected = false
    var cleared = false
    var queuedRepeatRejected = false
    var fixture = ""
    var phase = Phase.initial
    var started = 0.0
    var finished = 0.0
    var wakeCount = 0
    var done: (() -> Void)?
    var voice: AVSpeechSynthesisVoice!
    var now: Double { ProcessInfo.processInfo.systemUptime }
    func context(_ selection: CapturedTextReference.Selection) -> CapturedTextReference.Context {
        .init(selection: selection, source: identity, cameraEpoch: selection.cameraEpoch,
              generation: selection.generation, requestID: selection.requestID, now: now)
    }
    func event(_ name: String, active: Active? = nil) {
        events.append(["event": name, "monotonic": String(now), "phase": phase.rawValue,
            "phraseID": active?.phrase.id.uuidString ?? "", "text": active?.phrase.text ?? "",
            "callbackSelectionID": active?.selection.id.uuidString ?? "",
            "callbackRequestID": active?.selection.requestID.uuidString ?? "",
            "callbackCameraEpoch": active?.selection.cameraEpoch.uuidString ?? "",
            "callbackGeneration": active.map { String($0.selection.generation) } ?? "",
            "sourceID": identity?.sourceID.uuidString ?? "", "revision": identity?.revision.uuidString ?? "",
            "currentSelectionID": reader.selection?.id.uuidString ?? "",
            "currentRequestID": reader.selection?.requestID.uuidString ?? ""])
    }
    func captureAttempt(_ command: String) {
        let selection = reader.selection!
        attempts.append(["command": command, "selectionID": selection.id.uuidString,
            "requestID": selection.requestID.uuidString, "cameraEpoch": selection.cameraEpoch.uuidString,
            "generation": selection.generation, "sourceID": reader.source!.identity.sourceID.uuidString,
            "revision": reader.source!.identity.revision.uuidString,
            "issuedAt": selection.issuedAt, "capturedAt": selection.capturedAt,
            "phrases": reader.phrases.map { ["id": $0.id.uuidString, "text": $0.text, "originalSlice": $0.originalSlice] }])
    }
    func start() throws {
        speech.delegate = self
        voice = try XCTUnwrap(AVSpeechSynthesisVoice(language: "en-US"), "No system voice; no asset fallback")
        fixture = Array(repeating: "The quiet garden has green trees and bright flowers today", count: 4).joined(separator: " ")
        XCTAssertEqual(fixture.split(separator: " ").count, 40)
        started = now
        originalSelection = try XCTUnwrap(reader.select(cameraEpoch: UUID(), generation: 1,
            requestID: UUID(), issuedAt: started, capturedAt: started, orientation: 6, now: now))
        identity = .init(sourceID: originalSelection.id, revision: UUID(),
            sha256: SHA256.hash(data: Data(fixture.utf8)).map { String(format: "%02x", $0) }.joined(), media: .capturedText)
        let evidence = CompanionEvidence(id: "authored-page", kind: .historicalMemory,
            text: fixture, source: identity.evidenceSource)
        let source = CompanionReferenceSource(identity: identity,
            toolResult: .init(status: .success, source: identity.evidenceSource, evidence: [evidence]),
            blocks: [.init(evidence: evidence, bodyUTF16Range: NSRange(location: 0, length: fixture.utf16.count), locator: "authored-fixture")])
        guard reader.install(source, for: originalSelection, now: now) else {
            throw NSError(domain: "ReviewComponent", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unchanged acquisition bound rejected fixture"])
        }
        originalPhrases = reader.phrases
        guard originalPhrases.count == 2 else { fail("Frozen fixture must have exactly two installed parts"); return }
        captureAttempt("initial"); event("authored-source-installed"); pump()
    }
    func fail(_ message: String) {
        guard !terminal else { return }
        failure = message; terminal = true; event("failed")
        wake?.cancel(); wake = nil; _ = reader.clear()
        active = nil; speech.stopSpeaking(at: .immediate); done?()
    }
    @discardableResult
    func review(_ command: CapturedTextReviewCommand, phase newPhase: Phase) -> Bool {
        guard let selected = reader.selection else { fail("Review lost source owner"); return false }
        let oldIDs = Set(reader.phrases.map(\.id)), request = UUID()
        let oldSource = reader.source!.identity
        guard reader.review(command, requestID: request, context: context(selected)),
              let next = reader.selection, next.id != selected.id, next.requestID == request,
              next.requestID != selected.requestID, next.issuedAt == originalSelection.issuedAt,
              next.capturedAt == originalSelection.capturedAt,
              reader.source!.identity == oldSource, oldSource == identity,
              Set(reader.phrases.map(\.id)).isDisjoint(with: oldIDs),
              reader.completed == 0, !reader.withdrawn else {
            fail("Review changed source or failed to renew playback ownership"); return false
        }
        phase = newPhase; captureAttempt(newPhase.rawValue); event("review-created"); return true
    }
    func pump() {
        guard !terminal, active == nil, wake == nil, !awaitingOldCancellation else { return }
        guard let selected = reader.selection, let phrase = reader.next(context(selected)) else {
            fail("No owned next phrase"); return
        }
        let tokenizer = NLTokenizer(unit: .word); tokenizer.string = phrase.text
        let words = tokenizer.tokens(for: phrase.text.startIndex..<phrase.text.endIndex).count
        guard let deadline = attention.nextInformationBudgetTime(words: words, settings: settings, now: now) else {
            fail("Ordinary budget cannot admit phrase"); return
        }
        if deadline > now {
            wakeCount += 1; event("budget-parked")
            events[events.count - 1]["ledgerDeadline"] = String(deadline)
            let delay = deadline - now, selectedID = selected.id
            wake = Task { @MainActor [weak self] in
                do { try await Task.sleep(for: .seconds(delay)) } catch { return }
                guard let self, !Task.isCancelled, !self.terminal,
                      self.reader.selection?.id == selectedID else { return }
                self.wake = nil; self.event("budget-woke"); self.pump()
            }
            return
        }
        let stamp = now
        let candidate = InformationCandidate(key: phrase.id.uuidString, kind: .answer,
            text: phrase.text, words: words, createdAt: stamp, expiresAt: stamp + 2, requested: true)
        guard case .say = attention.decide([candidate], moment: .init(now: stamp), settings: settings).first,
              reader.begin(phrase, context: context(selected)) else { fail("Core admission rejected"); return }
        if phase == .initial && reader.completed == 0 {
            queuedRepeatRejected = !reader.review(.repeatPart, requestID: UUID(), context: context(selected))
            guard queuedRepeatRejected, reader.pending == phrase, reader.lastSpokenPart == nil,
                  reader.selection == selected else { fail("Queued phrase was treated as heard"); return }
            event("queued-repeat-rejected")
        }
        let utterance = AVSpeechUtterance(string: phrase.text); utterance.voice = voice
        active = Active(utterance: utterance, phrase: phrase, selection: selected)
        event("core-admitted", active: active); speech.speak(utterance)
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        guard !terminal, let current = active, utterance === current.utterance,
              utterance.speechString == current.phrase.text else { fail("Foreign native start"); return }
        event("AVSpeech.didStart", active: current)
        guard reader.started(id: current.phrase.id, text: utterance.speechString, context: context(current.selection)) else {
            fail("Exact real onset rejected"); return
        }
        if phase == .previous {
            replacedAttemptReceipt = reader.playbackReceipt
            guard review(.repeatPart, phase: .repeated) else { return }
            awaitingOldCancellation = true
            event("old-cancellation-requested", active: current)
            let accepted = speech.stopSpeaking(at: .immediate)
            event("old-stop-request-returned", active: current)
            events[events.count - 1]["accepted"] = String(accepted)
            // Wait for actual didCancel. A racing didFinish fails; never synthesize cancellation.
        }
    }
    func rejectOldCallback(_ current: Active, outcome: NarrationDelivery) -> Bool {
        let selected = reader.selection, before = reader.playbackReceipt
        let beforePaused = reader.paused, beforeSpoken = reader.lastSpokenPart, beforePending = reader.pending
        let accepted = reader.finish(id: current.phrase.id, text: current.utterance.speechString,
            outcome: outcome, context: context(current.selection))
        let safe = !accepted && reader.selection == selected && reader.playbackReceipt == before &&
            !reader.withdrawn && reader.completed == 0 && reader.source?.identity == identity &&
            reader.paused == beforePaused && reader.lastSpokenPart == beforeSpoken && reader.pending == beforePending
        event(safe ? "old-callback-rejected" : "old-callback-corrupted-owner", active: current)
        return safe
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        guard !terminal, let current = active, utterance === current.utterance,
              utterance.speechString == current.phrase.text else { return }
        event("AVSpeech.didCancel", active: current)
        guard awaitingOldCancellation, phase == .repeated, rejectOldCallback(current, outcome: .interrupted) else {
            fail("Unexpected cancellation or stale owner mutation"); return
        }
        oldCancellationRejected = true; awaitingOldCancellation = false; active = nil; pump()
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        guard !terminal, let current = active, utterance === current.utterance,
              utterance.speechString == current.phrase.text else { fail("Foreign native finish"); return }
        event("AVSpeech.didFinish", active: current)
        if awaitingOldCancellation {
            _ = rejectOldCallback(current, outcome: .completed)
            fail("Requested cancellation raced with actual finish"); return
        }
        guard reader.finish(id: current.phrase.id, text: utterance.speechString, outcome: .completed,
                            context: context(current.selection)) else { fail("Native finish rejected"); return }
        completed.append((phase.rawValue, current.phrase.id, current.phrase.originalSlice)); active = nil
        guard reader.playbackCompleted else { pump(); return }
        switch phase {
        case .initial:
            originalReceipt = reader.playbackReceipt
            guard review(.previousPart, phase: .previous) else { return }; pump()
        case .repeated:
            repeatReceipt = reader.playbackReceipt
            guard review(.nextPart, phase: .next) else { return }; pump()
        case .next:
            let oldContext = context(reader.selection!)
            finalReceipt = reader.clear()
            cleared = reader.source == nil && reader.selection == nil && reader.lastSpokenPart == nil &&
                reader.phrases.isEmpty && !reader.review(.repeatPart, requestID: UUID(), context: oldContext)
            guard cleared else { fail("Clear retained review authority"); return }
            finished = now; phase = .done; terminal = true; event("review-sequence-completed-and-cleared"); done?()
        default: fail("Unexpected completed attempt")
        }
    }
    func shutdown() {
        wake?.cancel(); wake = nil
        if !terminal { failure = "Component test deadline expired"; event("timeout"); _ = reader.clear() }
        terminal = true; active = nil; speech.stopSpeaking(at: .immediate); speech.delegate = nil
    }
    func receipt(_ value: CapturedTextReference.PlaybackReceipt?) -> [String: Any] {
        guard let value else { return [:] }
        return ["sourceID": value.sourceID.uuidString, "revision": value.revision.uuidString,
                "requestID": value.requestID.uuidString, "completed": value.completedPhraseCount,
                "total": value.totalPhraseCount, "outcome": value.outcome.rawValue]
    }
}

@MainActor
final class CapturedTextReviewNativeComponentTests: XCTestCase {
    func testRetainedSourceRepeatNextAndRealOldCancellationStayOwned() async throws {
        let playback = ReviewComponentPlayback()
        let done = expectation(description: "Real completion, real cancellation and bounded source clear")
        playback.done = { done.fulfill() }
        try AVAudioSession.sharedInstance().setCategory(.playback)
        try AVAudioSession.sharedInstance().setActive(true)
        defer {
            playback.shutdown()
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            let report: [String: Any] = [
                "scope": "Unchanged Core plus test-owned AVSpeech bridge; NOT app controller, Feedback or camera",
                "fixture": playback.fixture, "fixtureUTF8SHA256": playback.identity?.sha256 ?? "",
                "acquisition": "explicitly authored, no image/camera/OCR",
                "voiceID": playback.voice?.identifier ?? "", "voiceLanguage": playback.voice?.language ?? "",
                "runtime": ProcessInfo.processInfo.operatingSystemVersionString,
                "duration": playback.finished > 0 ? playback.finished - playback.started : 0,
                "budgetWordsPerMinute": 30, "wakeCount": playback.wakeCount,
                "events": playback.events, "attempts": playback.attempts,
                "originalReceipt": playback.receipt(playback.originalReceipt),
                "replacedAttemptReceipt": playback.receipt(playback.replacedAttemptReceipt),
                "repeatReceipt": playback.receipt(playback.repeatReceipt),
                "finalReceipt": playback.receipt(playback.finalReceipt),
                "queuedRepeatRejected": playback.queuedRepeatRejected,
                "actualOldCancellationRejected": playback.oldCancellationRejected,
                "cleared": playback.cleared, "failure": playback.failure ?? ""
            ]
            if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) {
                let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
                attachment.name = "authored-retained-review-component"; attachment.lifetime = .keepAlways; add(attachment)
            }
        }
        try playback.start()
        await fulfillment(of: [done], timeout: 480, enforceOrder: true)
        XCTAssertNil(playback.failure)
        XCTAssertTrue(playback.queuedRepeatRejected); XCTAssertTrue(playback.oldCancellationRejected)
        XCTAssertTrue(playback.cleared)
        XCTAssertEqual(playback.originalReceipt?.outcome, .completed)
        XCTAssertEqual(playback.originalReceipt?.completedPhraseCount, 2)
        XCTAssertEqual(playback.originalReceipt?.totalPhraseCount, 2)
        XCTAssertEqual(playback.replacedAttemptReceipt?.outcome, .cancelled)
        XCTAssertEqual(playback.replacedAttemptReceipt?.completedPhraseCount, 0)
        XCTAssertEqual(playback.repeatReceipt?.outcome, .completed)
        XCTAssertEqual(playback.finalReceipt?.outcome, .completed)
        XCTAssertEqual(playback.completed.count, 4)
        XCTAssertEqual(playback.completed.prefix(2).map { $0.2 }.joined(), playback.fixture)
        XCTAssertEqual(playback.completed.last?.2, playback.originalPhrases.last?.originalSlice)
        XCTAssertEqual(playback.completed.dropFirst(2).first?.2, playback.originalPhrases.first?.originalSlice)
        XCTAssertEqual(playback.events.filter { $0["event"] == "AVSpeech.didCancel" }.count, 1)
        XCTAssertEqual(playback.events.filter { $0["event"] == "AVSpeech.didFinish" }.count, 4)
        XCTAssertEqual(playback.attempts.count, 4)
        XCTAssertEqual(Set(playback.attempts.compactMap { $0["requestID"] as? String }).count, 4)
        XCTAssertEqual(Set(playback.attempts.compactMap { $0["selectionID"] as? String }).count, 4)
        XCTAssertEqual(Set(playback.attempts.compactMap { $0["sourceID"] as? String }).count, 1)
        XCTAssertEqual(playback.events.filter { $0["event"] == "AVSpeech.didStart" }.count, 5)
        XCTAssertGreaterThan(playback.finished - playback.started, 60)
        XCTAssertGreaterThan(playback.wakeCount, 0)
    }
}
