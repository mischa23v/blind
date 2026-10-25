import XCTest
import AVFoundation
import NaturalLanguage
import CryptoKit
import BlindCore

/// Component integration only. Authored acquisition and a test-owned AVSpeech
/// bridge are NOT NavigationModel, Feedback, Vision, camera or safety authority.
@MainActor
private final class ComponentPlayback: NSObject, AVSpeechSynthesizerDelegate {
    var reader = CapturedTextReference()
    var attention = CompanionAttention()
    let settings = CompanionSettings(wordsPerMinute: 30)
    let speech = AVSpeechSynthesizer()
    var active: (AVSpeechUtterance, CapturedTextReference.Phrase)?
    var wake: Task<Void, Never>?
    var selection: CapturedTextReference.Selection!
    var identity: CompanionReferenceIdentity!
    var receipt: CapturedTextReference.PlaybackReceipt?
    var events: [[String: String]] = []
    var failure: String?
    var terminal = false
    var completedSlices: [String] = []
    var fixture = ""
    var installedPhrases: [[String: String]] = []
    var started = 0.0
    var finishTime = 0.0
    var wakeCount = 0
    var done: (() -> Void)?
    var voice: AVSpeechSynthesisVoice!
    var now: Double { ProcessInfo.processInfo.systemUptime }
    var context: CapturedTextReference.Context {
        .init(selection: selection, source: identity, cameraEpoch: selection.cameraEpoch,
              generation: selection.generation, requestID: selection.requestID, now: now)
    }
    func event(_ name: String, _ phrase: CapturedTextReference.Phrase? = nil) {
        events.append(["event": name, "monotonic": String(now),
                       "phraseID": phrase?.id.uuidString ?? "", "text": phrase?.text ?? ""])
    }
    func start() throws {
        speech.delegate = self
        voice = try XCTUnwrap(AVSpeechSynthesisVoice(language: "en-US"), "No available system voice; no download fallback")
        // Exactly 100 authored words; this is fixture input, never claimed OCR.
        fixture = Array(repeating: "The quiet garden has green trees and bright flowers today", count: 10).joined(separator: " ")
        XCTAssertEqual(fixture.split(separator: " ").count, 100)
        started = now
        selection = try XCTUnwrap(reader.select(cameraEpoch: UUID(), generation: 1,
            requestID: UUID(), issuedAt: started, capturedAt: started, orientation: 6, now: now))
        identity = .init(sourceID: selection.id, revision: UUID(),
                         sha256: SHA256.hash(data: Data(fixture.utf8)).map { String(format: "%02x", $0) }.joined(), media: .capturedText)
        let evidence = CompanionEvidence(id: "authored-page", kind: .historicalMemory,
                                         text: fixture, source: identity.evidenceSource)
        let source = CompanionReferenceSource(identity: identity,
            toolResult: .init(status: .success, source: identity.evidenceSource, evidence: [evidence]),
            blocks: [.init(evidence: evidence, bodyUTF16Range: NSRange(location: 0, length: fixture.utf16.count), locator: "authored-fixture")])
        guard reader.install(source, for: selection, now: now) else {
            throw NSError(domain: "ComponentProbe", code: 1, userInfo: [NSLocalizedDescriptionKey: "Fixture missed unchanged acquisition deadline"])
        }
        installedPhrases = reader.phrases.map { ["id": $0.id.uuidString, "text": $0.text, "originalSlice": $0.originalSlice] }
        event("authored-source-installed")
        pump()
    }
    func fail(_ message: String) {
        guard !terminal else { return }
        failure = message; terminal = true; event("failed")
        wake?.cancel(); wake = nil
        receipt = reader.clear()
        active = nil
        speech.stopSpeaking(at: .immediate)
        done?()
    }
    func pump() {
        guard !terminal, active == nil, wake == nil else { return }
        guard !reader.playbackCompleted else { fail("Completion cannot occur without final callback"); return }
        guard let phrase = reader.next(context) else { fail("Owned unread phrase unavailable"); return }
        let tokenizer = NLTokenizer(unit: .word); tokenizer.string = phrase.text
        let words = tokenizer.tokens(for: phrase.text.startIndex..<phrase.text.endIndex).count
        guard let deadline = attention.nextInformationBudgetTime(words: words, settings: settings, now: now) else {
            fail("No ordinary budget deadline"); return
        }
        if deadline > now {
            let selectedID = selection.id
            wakeCount += 1; event("budget-parked", phrase)
            events[events.count - 1]["ledgerDeadline"] = String(deadline)
            let delay = deadline - now
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
              reader.begin(phrase, context: context) else { fail("Unchanged Core admission rejected"); return }
        let utterance = AVSpeechUtterance(string: phrase.text); utterance.voice = voice
        active = (utterance, phrase); event("core-admitted", phrase)
        speech.speak(utterance)
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        guard let active, utterance === active.0, utterance.speechString == active.1.text else {
            fail("Foreign native start"); return
        }
        event("AVSpeech.didStart", active.1)
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        guard !terminal, let current = active, utterance === current.0,
              utterance.speechString == current.1.text else { fail("Foreign native finish"); return }
        event("AVSpeech.didFinish", current.1)
        guard reader.finish(id: current.1.id, text: utterance.speechString, outcome: .completed, context: context) else {
            fail("Exact native finish rejected by owner"); return
        }
        completedSlices.append(current.1.originalSlice); active = nil
        if reader.playbackCompleted {
            finishTime = now; receipt = reader.clear(); terminal = true
            event("component-playback-completed"); done?()
        } else { pump() }
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        guard !terminal, let current = active, utterance === current.0 else { return }
        event("AVSpeech.didCancel", current.1)
        _ = reader.finish(id: current.1.id, text: utterance.speechString, outcome: .interrupted, context: context)
        fail("Native speech cancelled")
    }
    func shutdown() {
        wake?.cancel(); wake = nil
        if !terminal { failure = "Component test deadline expired"; receipt = reader.clear(); event("timeout") }
        terminal = true; active = nil; speech.stopSpeaking(at: .immediate)
        speech.delegate = nil
    }
}

@MainActor
final class CapturedTextNativeComponentTests: XCTestCase {
    func testAuthoredSourceSurvivesRealBudgetWindowsUntilExactNativeCompletion() async throws {
        let playback = ComponentPlayback()
        let completed = expectation(description: "Actual native final phrase callback, not elapsed time")
        playback.done = { completed.fulfill() }
        try AVAudioSession.sharedInstance().setCategory(.playback)
        try AVAudioSession.sharedInstance().setActive(true)
        defer {
            playback.shutdown()
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            let report: [String: Any] = [
                "scope": "Core plus test-owned AVSpeech bridge; authored acquisition; NOT app controller or Feedback",
                "fixture": playback.fixture, "sourceID": playback.identity?.sourceID.uuidString ?? "",
                "revision": playback.identity?.revision.uuidString ?? "",
                "fixtureUTF8SHA256": playback.identity?.sha256 ?? "",
                "installedPhrases": playback.installedPhrases,
                "acquisition": "explicitly authored fixture, no image/camera/OCR",
                "voiceID": playback.voice?.identifier ?? "", "voiceLanguage": playback.voice?.language ?? "",
                "voiceName": playback.voice?.name ?? "",
                "voiceQuality": playback.voice.map { String(describing: $0.quality) } ?? "",
                "voiceEvidenceLimit": "System listed voice plus callbacks; not installed-asset or acoustic proof",
                "runtime": ProcessInfo.processInfo.operatingSystemVersionString,
                "duration": playback.finishTime > 0 ? playback.finishTime - playback.started : 0,
                "budgetWordsPerMinute": 30, "wakeCount": playback.wakeCount,
                "failure": playback.failure ?? "", "events": playback.events,
                "outcome": playback.receipt?.outcome.rawValue ?? "none",
                "completedPhrases": playback.receipt?.completedPhraseCount ?? 0,
                "totalPhrases": playback.receipt?.totalPhraseCount ?? 0
            ]
            if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) {
                let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
                attachment.name = "authored-component-playback"; attachment.lifetime = .keepAlways; add(attachment)
            }
        }
        try playback.start()
        await fulfillment(of: [completed], timeout: 480, enforceOrder: true)
        XCTAssertNil(playback.failure)
        XCTAssertEqual(playback.receipt?.outcome, .completed)
        XCTAssertGreaterThan(playback.finishTime - playback.started, 60)
        XCTAssertGreaterThan(playback.wakeCount, 0)
        XCTAssertEqual(playback.receipt?.completedPhraseCount, playback.receipt?.totalPhraseCount)
        XCTAssertEqual(playback.completedSlices.joined(), playback.fixture)
        XCTAssertFalse(playback.events.contains { $0["event"] == "AVSpeech.didCancel" })
        XCTAssertEqual(playback.events.filter { $0["event"] == "AVSpeech.didFinish" }.count, playback.completedSlices.count)
    }
}
