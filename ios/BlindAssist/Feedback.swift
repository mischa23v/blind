import AVFoundation
import UIKit
import BlindCore
import os
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

final class Feedback: NSObject, WCSessionDelegate, AVSpeechSynthesizerDelegate {
    private let speech = AVSpeechSynthesizer()
    private var delivery = SpeechDeliveryLedger()
    private var currentUtterance: AVSpeechUtterance?
    private var outputTimeout: Timer?
    private var urgentUntil = -Double.infinity
    private var urgentTimeout: Timer?
    var onNarrationFinished: ((UUID, String, NarrationDelivery) -> Void)?
    /// A phrase is complete only after its matching platform completion callback.
    /// Only accepted attempts emit a result; rejected delivery returns false.
    var onRequestedSpeechFinished: ((UUID, String, NarrationDelivery) -> Void)?
    var onIdle: (() -> Void)?
    var onControlAnnouncement: ((String) -> Void)?
    private let engine = AVAudioEngine()
    private let environment = AVAudioEnvironmentNode()
    private let player = AVAudioPlayerNode()
    private var tone: AVAudioPCMBuffer?
    private var spatialReady = false
    private var spatialGraphConfigured = false
    var arabic = false
    var detail: DetailLevel = .balanced

    override init() {
        super.init()
        speech.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(voiceOverChanged), name: UIAccessibility.voiceOverStatusDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(announcementFinished(_:)), name: UIAccessibility.announcementDidFinishNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(audioInterrupted(_:)), name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(mediaServicesReset), name: AVAudioSession.mediaServicesWereResetNotification, object: nil)
        if !ProcessInfo.processInfo.arguments.contains("--text-only") &&
            ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            configureSpatialAudio()
        }
    }

    func configureSpatialAudio() {
        do {
            let audio = AVAudioSession.sharedInstance()
            // VoiceInput owns the shared recording category/mode while listening.
            // A beacon must never change playAndRecord back to playback or disable AEC.
            if audio.category != .playAndRecord {
                try audio.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            }
            try audio.setActive(true)
            if !spatialGraphConfigured {
                let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
                engine.attach(player); engine.attach(environment)
                engine.connect(player, to: environment, format: format)
                engine.connect(environment, to: engine.mainMixerNode, format: nil)
                player.renderingAlgorithm = .HRTF
                let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 8_820)!
                buffer.frameLength = buffer.frameCapacity
                for i in 0..<Int(buffer.frameLength) {
                    let t = Double(i) / 44_100
                    buffer.floatChannelData![0][i] = Float(sin(2 * .pi * 660 * t) * sin(.pi * t / 0.2) * 0.18)
                }
                tone = buffer; spatialGraphConfigured = true
            }
            if !engine.isRunning { try engine.start() }
            spatialReady = true
        } catch { spatialReady = false }
    }

    private func alertSignals(_ detection: Detection) {
        let timing = AssistantPerformance.signposter.beginInterval("AlertDispatch", id: AssistantPerformance.signposter.makeSignpostID())
        defer { AssistantPerformance.signposter.endInterval("AlertDispatch", timing) }
        if detection.hazard.requiresImmediateAttention {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            if detection.hazard.isUrgent && detection.reason != .visualStairs { beacon(sector: detection.sector, distance: detection.distance ?? 1) }
            else { player.stop() } // Missing coverage has no known hazard bearing.
            if WCSession.default.isReachable {
                WCSession.default.sendMessage(["hazard": detection.hazard.rawValue], replyHandler: nil)
            }
        }
    }

    /// No raw text is accepted by the public sink; admission is minted by NavigationModel.
    /// The controller owns a bounded phrase queue and revalidates every phrase.
    /// This sink holds one attempt only, including the time before AVFoundation starts.
    @discardableResult func deliver(_ admitted: AdmittedSpeech, narrationID: UUID? = nil,
                                    speechID: UUID? = nil, alert: Detection? = nil) -> Bool {
        guard narrationID == nil || speechID == nil else { return false }
        let destination: SpeechDeliveryLedger.Destination
        if let narrationID {
            guard canSpeakAmbient else { return false }
            destination = .narration(narrationID)
        } else if let speechID {
            destination = .requested(speechID)
        } else {
            destination = .untracked
        }
        return speak(admitted, destination: destination, alert: alert)
    }

    /// AEC is primary. Exact active-output prefixes and a one-second residual tail
    /// also suppress echo. An identical human prefix can be suppressed briefly;
    /// this is not speaker identification. Rejected output never changes the text.
    func isLikelyOwnSpeech(_ text: String) -> Bool {
        delivery.isLikelyOwnSpeech(text, now: ProcessInfo.processInfo.systemUptime)
    }

    var speechPriority: SpeechPriority? {
        if ProcessInfo.processInfo.systemUptime < urgentUntil { return .danger }
        if let active = delivery.active { return active.priority }
        // A stop can still be settling at the platform. Do not overlap ordinary output.
        return speech.isSpeaking ? .information : nil
    }

    var canSpeakAmbient: Bool {
        delivery.active == nil && !speech.isSpeaking && ProcessInfo.processInfo.systemUptime >= urgentUntil
    }

    func requestCancellationAnnouncement() {
        if UIAccessibility.isVoiceOverRunning { onControlAnnouncement?(arabic ? "أُلغي." : "Canceled.") }
    }

    @discardableResult private func speak(_ admitted: AdmittedSpeech,
                                         destination: SpeechDeliveryLedger.Destination,
                                         alert: Detection?) -> Bool {
        guard !admitted.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        let priority: SpeechPriority = admitted.urgent ? .danger : admitted.priority
        guard priority.canInterrupt(speechPriority) else { return false }
        if admitted.urgent { reserveUrgentOutput() }
        if delivery.active != nil {
            finishActive(outcome: .interrupted, stopSynthesizer: true, notify: false)
        } else if speech.isSpeaking {
            speech.stopSpeaking(at: .immediate)
        }
        // UIKit announcement callbacks have no utterance identifier or direct stop
        // API. Requested streamed replies use cancellable AVSpeechSynthesizer even
        // with VoiceOver on. Apple's assistive-technology settings preserve its rate:
        // https://developer.apple.com/videos/play/wwdc2020/10022/
        let transport = SpeechDeliveryLedger.transport(for: destination, priority: priority,
                                                       voiceOverRunning: UIAccessibility.isVoiceOverRunning)
        guard let attempt = delivery.begin(text: admitted.text, priority: priority,
                                           destination: destination, transport: transport) else { return false }
        if let alert { alertSignals(alert) }
        armOutputTimeout(token: attempt.token)
        if transport == .accessibility {
            let value = NSAttributedString(string: attempt.text, attributes: [
                .accessibilitySpeechQueueAnnouncement: false,
                .accessibilitySpeechLanguage: arabic ? "ar-SA" : "en-US"
            ])
            UIAccessibility.post(notification: .announcement, argument: value)
        } else {
            let utterance = AVSpeechUtterance(string: attempt.text)
            utterance.voice = AVSpeechSynthesisVoice(language: arabic ? "ar-SA" : "en-US")
            utterance.rate = admitted.urgent ? 0.52 : 0.47
            utterance.prefersAssistiveTechnologySettings = true
            currentUtterance = utterance
            speech.speak(utterance)
        }
        return true
    }

    private func reserveUrgentOutput() {
        urgentUntil = ProcessInfo.processInfo.systemUptime + 5
        urgentTimeout?.invalidate()
        let deadline = urgentUntil
        let timer = Timer(timeInterval: 5, repeats: false) { [weak self] _ in
            guard let self, self.urgentUntil == deadline else { return }
            self.urgentTimeout = nil
            // This wakes deferred producers; elapsed time is not a delivery signal.
            self.notifyIdle()
        }
        urgentTimeout = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func armOutputTimeout(token: UUID) {
        outputTimeout?.invalidate()
        let timer = Timer(timeInterval: 120, repeats: false) { [weak self] _ in
            guard let self, self.delivery.active?.token == token else { return }
            // A lost callback must not strand the controller or claim text was heard.
            self.finishActive(outcome: .unknown, stopSynthesizer: true)
        }
        outputTimeout = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func interruptAmbient() {
        guard let active = delivery.active, case .narration = active.destination,
              active.priority != .mobility, active.priority != .danger else { return }
        let hadAnnouncement = active.transport == .accessibility
        finishActive(outcome: .interrupted, stopSynthesizer: true)
        if hadAnnouncement { requestCancellationAnnouncement() }
    }

    @objc private func voiceOverChanged() {
        let hadActive = delivery.active != nil
        finishActive(outcome: .unknown, stopSynthesizer: true)
        speech.stopSpeaking(at: .immediate)
        if !hadActive { notifyIdle() }
    }

    @objc private func audioInterrupted(_ notification: Notification) {
        guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              AVAudioSession.InterruptionType(rawValue: raw) == .began else { return }
        finishActive(outcome: .interrupted, stopSynthesizer: true)
        player.stop()
    }

    @objc private func mediaServicesReset() {
        finishActive(outcome: .unknown, stopSynthesizer: true)
        player.stop(); spatialReady = false
    }

    @objc private func announcementFinished(_ notification: Notification) {
        guard let active = delivery.active, active.transport == .accessibility,
              let text = notification.userInfo?[UIAccessibility.announcementStringValueUserInfoKey] as? String,
              text == active.text else { return }
        let successful = notification.userInfo?[UIAccessibility.announcementWasSuccessfulUserInfoKey] as? Bool == true
        finishActive(outcome: successful ? .completed : .interrupted)
    }

    private func notifyIdle() {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.canSpeakAmbient else { return }
            self.onIdle?()
        }
    }

    private func finishActive(outcome: NarrationDelivery, stopSynthesizer: Bool = false, notify: Bool = true) {
        guard let active = delivery.active,
              let completion = delivery.finish(token: active.token, outcome: outcome,
                                               now: ProcessInfo.processInfo.systemUptime) else { return }
        // Invalidate identity before stopping: didCancel can arrive after new output
        // starts. Clear all old state before invoking controller code, asynchronously.
        currentUtterance = nil
        outputTimeout?.invalidate(); outputTimeout = nil
        if stopSynthesizer { speech.stopSpeaking(at: .immediate) }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch completion.attempt.destination {
            case .narration(let id): self.onNarrationFinished?(id, completion.attempt.text, completion.outcome)
            case .requested(let id): self.onRequestedSpeechFinished?(id, completion.attempt.text, completion.outcome)
            case .untracked: break
            }
        }
        if notify { notifyIdle() }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        guard utterance === currentUtterance, delivery.active?.transport == .synthesized else { return }
        finishActive(outcome: .completed)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        guard utterance === currentUtterance, delivery.active?.transport == .synthesized else { return }
        finishActive(outcome: .interrupted)
    }

    @discardableResult func stopInformation(announceCancellation: Bool = true) -> Bool {
        guard ProcessInfo.processInfo.systemUptime >= urgentUntil,
              delivery.active?.priority != .mobility, delivery.active?.priority != .danger else { return false }
        let hadAnnouncement = delivery.active?.transport == .accessibility
        finishActive(outcome: .interrupted, stopSynthesizer: true)
        speech.stopSpeaking(at: .immediate)
        if announceCancellation && hadAnnouncement { requestCancellationAnnouncement() }
        return true
    }

    func stop(includingAlerts: Bool = false) {
        guard includingAlerts || (ProcessInfo.processInfo.systemUptime >= urgentUntil && delivery.active?.priority != .danger) else { return }
        if includingAlerts {
            urgentUntil = -.infinity; urgentTimeout?.invalidate(); urgentTimeout = nil
        }
        let hadAnnouncement = delivery.active?.transport == .accessibility
        finishActive(outcome: .interrupted, stopSynthesizer: true)
        speech.stopSpeaking(at: .immediate); player.stop()
        if hadAnnouncement { requestCancellationAnnouncement() }
    }

    deinit {
        outputTimeout?.invalidate(); urgentTimeout?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    func beacon(sector: Int, distance: Double) {
        guard spatialReady, let tone else { return }
        if !engine.isRunning { try? engine.start() }
        let angle = Double(sector) * .pi / 4
        player.position = AVAudio3DPoint(x: Float(sin(angle) * distance), y: 0, z: Float(-cos(angle) * distance))
        player.stop(); player.scheduleBuffer(tone); player.play()
    }
    func message(for hazard: Hazard) -> String {
        GuidanceText.hazard(hazard, arabic: arabic)
    }
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
}

