import AVFoundation
import UIKit
import BlindCore
import os
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

final class Feedback: NSObject, WCSessionDelegate, AVSpeechSynthesizerDelegate {
    private let speech = AVSpeechSynthesizer()
    private var speakingAmbient = false
    private var accessibilityAnnouncement: String?
    private var urgentUntil = -Double.infinity
    private var announcementStartedAt = -Double.infinity
    private var announcementTimeout: Timer?
    private var narrationText: String?
    private var narrationID: UUID?
    private var seenAnnouncements = Set<String>()
    private var announcementAmbiguous = false
    private var currentUtterance: AVSpeechUtterance?
    private var activePriority: SpeechPriority?
    var onNarrationFinished: ((UUID, String, NarrationDelivery) -> Void)?
    var onIdle: (() -> Void)?
    private let engine = AVAudioEngine()
    private let environment = AVAudioEnvironmentNode()
    private let player = AVAudioPlayerNode()
    private var tone: AVAudioPCMBuffer?
    private var spatialReady = false
    var arabic = false
    var detail: DetailLevel = .balanced
    override init() {
        super.init()
        speech.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(voiceOverChanged), name: UIAccessibility.voiceOverStatusDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(announcementFinished(_:)), name: UIAccessibility.announcementDidFinishNotification, object: nil)
        if WCSession.isSupported() { WCSession.default.delegate = self; WCSession.default.activate() }
        configureSpatialAudio()
    }
    func configureSpatialAudio() {
        do {
            let audio = AVAudioSession.sharedInstance()
            try audio.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audio.setActive(true)
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
            tone = buffer; try engine.start(); spatialReady = true
        } catch { spatialReady = false }
    }
    private func alertSignals(_ detection: Detection) {
        let timing = AssistantPerformance.signposter.beginInterval("AlertDispatch", id: AssistantPerformance.signposter.makeSignpostID())
        defer { AssistantPerformance.signposter.endInterval("AlertDispatch", timing) }
        if detection.hazard.requiresImmediateAttention {
            speech.stopSpeaking(at: .immediate)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            if detection.hazard.isUrgent && detection.reason != .visualStairs { beacon(sector: detection.sector, distance: detection.distance ?? 1) }
            else { player.stop() } // Missing coverage has no known hazard bearing.
            if WCSession.default.isReachable {
                WCSession.default.sendMessage(["hazard": detection.hazard.rawValue], replyHandler: nil)
            }
        }
    }
    /// No raw text is accepted by the public sink; admission is minted by NavigationModel.
    @discardableResult func deliver(_ admitted: AdmittedSpeech, narrationID: UUID? = nil, alert: Detection? = nil) -> Bool {
        if let alert { alertSignals(alert) }
        if let narrationID { return speakAmbient(admitted.text, id: narrationID) }
        return speak(admitted.text, urgent: admitted.urgent, priority: admitted.priority)
    }
    var speechPriority: SpeechPriority? {
        if ProcessInfo.processInfo.systemUptime < urgentUntil { return .danger }
        return speech.isSpeaking || accessibilityAnnouncement != nil ? activePriority : nil
    }
    var onControlAnnouncement: ((String) -> Void)?
    func requestCancellationAnnouncement() {
        if UIAccessibility.isVoiceOverRunning { onControlAnnouncement?(arabic ? "أُلغي." : "Canceled.") }
    }
    @discardableResult private func speak(_ text: String, urgent: Bool = false, priority: SpeechPriority = .status) -> Bool {
        guard !text.isEmpty else { return false }
        let now = ProcessInfo.processInfo.systemUptime
        if urgent { urgentUntil = now + 5 }
        else if now < urgentUntil { return false }
        let priority: SpeechPriority = urgent ? .danger : priority
        let active = speech.isSpeaking || accessibilityAnnouncement != nil ? activePriority : nil
        guard priority.canInterrupt(active) else { return false }
        if UIAccessibility.isVoiceOverRunning {
            finishNarration(success: false)
            speech.stopSpeaking(at: .immediate); speakingAmbient = false
            currentUtterance = nil; activePriority = priority
            announce(text)
            return true
        }
        if urgent { finishNarration(success: false); speech.stopSpeaking(at: .immediate) }
        else if speech.isSpeaking {
            finishNarration(success: false)
            speech.stopSpeaking(at: .immediate)
        }
        speakingAmbient = false
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: arabic ? "ar-SA" : "en-US")
        utterance.rate = urgent ? 0.52 : 0.47
        utterance.prefersAssistiveTechnologySettings = true
        currentUtterance = utterance; activePriority = priority; speech.speak(utterance)
        return true
    }
    var canSpeakAmbient: Bool {
        !speech.isSpeaking && accessibilityAnnouncement == nil && ProcessInfo.processInfo.systemUptime >= urgentUntil
    }
    @discardableResult private func speakAmbient(_ text: String, id: UUID) -> Bool {
        guard canSpeakAmbient, speak(text, priority: .information) else { return false }
        speakingAmbient = true; narrationText = text; narrationID = id; return true
    }
    func interruptAmbient() {
        if speakingAmbient {
            finishNarration(success: false)
            speech.stopSpeaking(at: .immediate); speakingAmbient = false
            if UIAccessibility.isVoiceOverRunning, accessibilityAnnouncement != nil {
                accessibilityAnnouncement = nil; activePriority = nil; currentUtterance = nil; announcementTimeout?.invalidate()
                requestCancellationAnnouncement()
            }
        }
    }
    private func announce(_ text: String) {
        // UIKit identifies completions by text, not our request ID. Reused text is ambiguous.
        announcementAmbiguous = seenAnnouncements.contains(text) || seenAnnouncements.count >= 512
        if !announcementAmbiguous { seenAnnouncements.insert(text) }
        accessibilityAnnouncement = text
        announcementStartedAt = ProcessInfo.processInfo.systemUptime
        announcementTimeout?.invalidate()
        let started = announcementStartedAt
        // A lost callback must not accumulate an unbounded speech queue.
        // Hold ordinary speech conservatively; never use elapsed time as proof of delivery.
        announcementTimeout = Timer.scheduledTimer(withTimeInterval: 120, repeats: false) { [weak self] _ in
            guard let self, self.announcementStartedAt == started else { return }
            self.finishNarration(outcome: .unknown)
            self.accessibilityAnnouncement = nil; self.speakingAmbient = false; self.activePriority = nil
            self.notifyIdle()
        }
        let value = NSAttributedString(string: text, attributes: [
            .accessibilitySpeechQueueAnnouncement: false,
            .accessibilitySpeechLanguage: arabic ? "ar-SA" : "en-US"
        ])
        UIAccessibility.post(notification: .announcement, argument: value)
    }
    @objc private func voiceOverChanged() { finishNarration(outcome: .unknown); speech.stopSpeaking(at: .immediate); speakingAmbient = false; accessibilityAnnouncement = nil; activePriority = nil; currentUtterance = nil; announcementTimeout?.invalidate(); notifyIdle() }
    @objc private func announcementFinished(_ notification: Notification) {
        if let text = notification.userInfo?[UIAccessibility.announcementStringValueUserInfoKey] as? String,
           text == accessibilityAnnouncement {
            // A failed/interrupted announcement is not recorded as successfully delivered.
            let successful = notification.userInfo?[UIAccessibility.announcementWasSuccessfulUserInfoKey] as? Bool == true
            finishNarration(outcome: announcementAmbiguous ? .unknown : successful ? .completed : .interrupted)
            accessibilityAnnouncement = nil; speakingAmbient = false; activePriority = nil; announcementTimeout?.invalidate()
            notifyIdle()
        }
    }
    private func finishNarration(success: Bool) {
        finishNarration(outcome: success ? .completed : .interrupted)
    }
    private func notifyIdle() { DispatchQueue.main.async { [weak self] in self?.onIdle?() } }
    private func finishNarration(outcome: NarrationDelivery) {
        if let text = narrationText, let id = narrationID {
            narrationText = nil; narrationID = nil; onNarrationFinished?(id, text, outcome)
        }
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        guard utterance === currentUtterance else { return }
        finishNarration(success: true); speakingAmbient = false; currentUtterance = nil; activePriority = nil
        notifyIdle()
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        guard utterance === currentUtterance else { return }
        finishNarration(success: false); speakingAmbient = false; currentUtterance = nil; activePriority = nil
        notifyIdle()
    }
    @discardableResult func stopInformation(announceCancellation: Bool = true) -> Bool {
        guard ProcessInfo.processInfo.systemUptime >= urgentUntil,
              activePriority != .mobility, activePriority != .danger else { return false }
        let hadAnnouncement = accessibilityAnnouncement != nil
        finishNarration(success: false)
        speakingAmbient = false; speech.stopSpeaking(at: .immediate)
        currentUtterance = nil; activePriority = nil
        announcementTimeout?.invalidate(); accessibilityAnnouncement = nil
        if announceCancellation && hadAnnouncement { requestCancellationAnnouncement() }
        return true
    }
    func stop(includingAlerts: Bool = false) {
        guard includingAlerts || ProcessInfo.processInfo.systemUptime >= urgentUntil else { return }
        if includingAlerts { urgentUntil = -.infinity }
        finishNarration(success: false)
        speakingAmbient = false; speech.stopSpeaking(at: .immediate); player.stop()
        if UIAccessibility.isVoiceOverRunning, accessibilityAnnouncement != nil {
            accessibilityAnnouncement = nil; activePriority = nil; currentUtterance = nil; announcementTimeout?.invalidate()
            requestCancellationAnnouncement()
        }
    }
    deinit { announcementTimeout?.invalidate(); NotificationCenter.default.removeObserver(self) }
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
