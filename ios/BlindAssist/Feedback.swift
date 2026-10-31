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
    private var currentSpatialRouteID: UUID?
    private var currentModelReply: ModelResponseAuthority.Lease?
    private var currentPrivateReference = false
    private var beaconOwnership = SpatialRouteBeaconOwnership()
    /// Only the exact route owner can revalidate a registered physical cue.
    var spatialRoutePermission: ((UUID) -> Bool)?
    var spatialRouteSpeechPermission: ((UUID, String) -> Bool)?
    /// Exact generated text retains its request owner at platform queue/start.
    var modelReplyPermission: ((ModelResponseAuthority.Lease, String) -> Bool)?
    /// Recheck source-bound requested information at enqueue and actual start.
    var requestedSpeechPermission: ((UUID, String) -> Bool)?
    #if DEBUG
    private let debugTrace = DebugNativeSessionTrace()
    private var debugSilentModelTestTransport = false
    private(set) var debugModelTestQueued: [String] = []
    private(set) var debugModelTestStarted: [String] = []
    /// XCTest-only silent platform boundary. All real controller, admission and
    /// delayed-start checks still run; no synthesizer, beacon or sensor starts.
    func debugEnableSilentModelTestTransport() -> Bool {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil else { return false }
        debugSilentModelTestTransport = true
        return true
    }
    func debugStartModelTestPlayback() -> Bool {
        guard debugSilentModelTestTransport, let utterance = currentUtterance else { return false }
        speechSynthesizer(speech, didStart: utterance)
        return currentUtterance === utterance && delivery.active != nil
    }
    var debugModelTestHasActiveAttempt: Bool { delivery.active != nil }
    #endif
    private var outputTimeout: Timer?
    private var urgentUntil = -Double.infinity
    private var urgentTimeout: Timer?
    var onNarrationFinished: ((UUID, String, NarrationDelivery) -> Void)?
    /// A phrase is complete only after its matching platform completion callback.
    /// Only accepted attempts emit a result; rejected delivery returns false.
    /// Exact synthesized start only. Nil is inert; admission is not onset.
    var onRequestedSpeechStarted: ((UUID, String) -> Void)?
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
            if detection.hazard.isUrgent && detection.reason != .visualStairs && detection.reason != .bodyEnvelope { beacon(sector: detection.sector, distance: detection.distance ?? 1) }
            else { beaconOwnership.replace(routeID: nil); player.stop() } // Missing coverage has no known hazard bearing.
            if WCSession.default.isReachable {
                WCSession.default.sendMessage(["hazard": detection.hazard.rawValue], replyHandler: nil)
            }
        }
    }

    /// No raw text is accepted by the public sink; admission is minted by NavigationModel.
    /// The controller owns a bounded phrase queue and revalidates every phrase.
    /// This sink holds one attempt only, including the time before AVFoundation starts.
    @discardableResult func deliver(_ admitted: AdmittedSpeech, narrationID: UUID? = nil,
                                    speechID: UUID? = nil, alert: Detection? = nil,
                                    independentAlert: Bool = false, spatialRouteID: UUID? = nil, modelReply: ModelResponseAuthority.Lease? = nil) -> Bool {
        #if DEBUG
        var debugAccepted = false
        defer {
            if !debugAccepted {
                debugTrace?.event(.speechRejected, source: .speechEngine, utteranceID: speechID ?? narrationID) {
                    .init(text: admitted.privateReference ? nil : admitted.text, label: "feedback.deliveryRejected")
                }
            }
        }
        #endif
        guard narrationID == nil || speechID == nil else { return false }
        if let modelReply {
            guard spatialRouteID == nil, alert == nil, !independentAlert,
                  !admitted.urgent, admitted.priority != .mobility,
                  modelReplyIsCurrent(modelReply, text: admitted.text) else { return false }
        }
        if let spatialRouteID {
            guard spatialRouteID == speechID, admitted.priority == .mobility,
                  !independentAlert, alert == nil,
                  spatialRoutePermission?(spatialRouteID) == true,
                   spatialRouteSpeechPermission?(spatialRouteID, admitted.text) == true else { return false }
        }
        let destination: SpeechDeliveryLedger.Destination
        if let narrationID {
            guard canSpeakAmbient else { return false }
            destination = .narration(narrationID)
        } else if let speechID {
            destination = .requested(speechID)
        } else {
            destination = .untracked
        }
        let verifiedIndependentAlert = independentAlert && alert != nil &&
            (admitted.priority == .mobility || admitted.urgent)
        let accepted = speak(admitted, destination: destination, alert: alert, independentAlert: verifiedIndependentAlert, spatialRouteID: spatialRouteID, modelReply: modelReply)
        #if DEBUG
        debugAccepted = accepted
        #endif
        return accepted
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
                                         alert: Detection?, independentAlert: Bool, spatialRouteID: UUID?, modelReply: ModelResponseAuthority.Lease?) -> Bool {
        guard !admitted.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        let priority: SpeechPriority = admitted.urgent ? .danger : admitted.priority
        guard priority.canInterrupt(speechPriority) else { return false }
        if admitted.urgent { reserveUrgentOutput() }
        if delivery.active != nil {
            finishActive(outcome: .interrupted, stopSynthesizer: true, notify: false)
        } else if speech.isSpeaking {
            speech.stopSpeaking(at: .immediate)
        }
        // UIKit announcements have no direct stop API. All potentially private
        // app speech uses cancellable synthesis, including ambient/route cues.
        // Only independent sensor alerts retain UIKit transport with VoiceOver on.
        // Apple's assistive-technology settings preserve the chosen rate:
        // https://developer.apple.com/videos/play/wwdc2020/10022/
        let transport = SpeechDeliveryLedger.transport(for: destination, priority: priority,
            voiceOverRunning: UIAccessibility.isVoiceOverRunning, independentAlert: independentAlert)
        guard let attempt = delivery.begin(text: admitted.text, priority: priority,
            destination: destination, transport: transport, independentAlert: independentAlert) else { return false }
        currentSpatialRouteID = spatialRouteID; currentModelReply = modelReply
        currentPrivateReference = admitted.privateReference
        if let alert { alertSignals(alert) }
        #if DEBUG
        debugTrace?.event(.speechRequested, source: .speechEngine,
                          utteranceID: transport == .synthesized ? attempt.token : nil) {
            let destinationID: String
            switch destination {
            case .requested(let id), .narration(let id): destinationID = id.uuidString
            case .untracked: destinationID = "unbound"
            }
            return .init(text: admitted.privateReference ? nil : attempt.text, label: "engine.admitted; destinationID=" + destinationID + (transport == .accessibility ? "; VoiceOverID=unbound" : ""))
        }
        #endif
        armOutputTimeout(token: attempt.token, modelReply: modelReply)
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
            // Revalidate after preparation, immediately before handing to the
            // platform queue. didStart below fences a delayed actual start too.
            if let modelReply, !modelReplyIsCurrent(modelReply, text: attempt.text) {
                finishActive(outcome: .interrupted, stopSynthesizer: true); return false
            }
            if let spatialRouteID, spatialRoutePermission?(spatialRouteID) != true || spatialRouteSpeechPermission?(spatialRouteID, attempt.text) != true {
                finishActive(outcome: .interrupted, stopSynthesizer: true); return false
            }
            if case .requested(let id) = attempt.destination, requestedSpeechPermission?(id, attempt.text) == false {
                finishActive(outcome: .interrupted, stopSynthesizer: true); return false
            }
            #if DEBUG
            if debugSilentModelTestTransport {
                debugModelTestQueued.append(attempt.text)
                return true
            }
            #endif
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

    /// Ordinary chat does not require a running camera watchdog. Its original
    /// model deadline still bounds playback; an old timer cannot stop a newer
    /// independent alert, document, or other delivery attempt.
    static func outputTimeoutInterval(modelReply: ModelResponseAuthority.Lease?, now: Double) -> TimeInterval {
        guard let modelReply else { return 120 }
        guard now.isFinite else { return 0 }
        return max(0, min(120, modelReply.expiresAt - now))
    }

    private func armOutputTimeout(token: UUID, modelReply: ModelResponseAuthority.Lease?) {
        outputTimeout?.invalidate()
        let interval = Self.outputTimeoutInterval(modelReply: modelReply, now: ProcessInfo.processInfo.systemUptime)
        let timer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            guard let self, self.delivery.active?.token == token else { return }
            // A lost callback must not strand the controller or claim text was heard.
            self.finishActive(outcome: modelReply == nil ? .unknown : .interrupted, stopSynthesizer: true,
                              diagnosticCause: modelReply == nil ? "speech.timeout.notCompletion" : "model.originalDeadlineExpired")
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
        beaconOwnership.replace(routeID: nil); player.stop()
    }

    @objc private func mediaServicesReset() {
        finishActive(outcome: .unknown, stopSynthesizer: true)
        beaconOwnership.replace(routeID: nil); player.stop(); spatialReady = false
    }

    @objc private func announcementFinished(_ notification: Notification) {
        guard let active = delivery.active, active.transport == .accessibility,
              let text = notification.userInfo?[UIAccessibility.announcementStringValueUserInfoKey] as? String,
              text == active.text else { return }
        let successful = notification.userInfo?[UIAccessibility.announcementWasSuccessfulUserInfoKey] as? Bool == true
        finishActive(outcome: successful ? .completed : .interrupted, diagnosticCause: "VoiceOver.textOnlyCallback")
    }

    private func notifyIdle() {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.canSpeakAmbient else { return }
            self.onIdle?()
        }
    }

    private func finishActive(outcome: NarrationDelivery, stopSynthesizer: Bool = false, notify: Bool = true,
                              diagnosticCause: String = "app.cancelOrLifecycle") {
        guard let active = delivery.active,
              let completion = delivery.finish(token: active.token, outcome: outcome,
                                               now: ProcessInfo.processInfo.systemUptime) else { return }
        #if DEBUG
        let kind: DebugSessionLog.Kind = completion.attempt.transport == .accessibility ? .unavailable
            : completion.outcome == .completed ? .speechCompleted
            : completion.outcome == .interrupted ? .speechInterrupted : .unavailable
        debugTrace?.event(kind, source: .speechEngine,
                          utteranceID: completion.attempt.transport == .synthesized ? completion.attempt.token : nil) {
            .init(text: currentPrivateReference ? nil : completion.attempt.text,
                  label: diagnosticCause + "; outcome=" + String(describing: completion.outcome)
                    + (completion.attempt.transport == .accessibility ? "; VoiceOverCorrelation=unbound" : ""))
        }
        #endif
        // Invalidate identity before stopping: didCancel can arrive after new output
        // starts. Clear all old state before invoking controller code, asynchronously.
        currentUtterance = nil; currentSpatialRouteID = nil; currentModelReply = nil; currentPrivateReference = false
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

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        guard utterance === currentUtterance, let active = delivery.active, active.transport == .synthesized else { return }
        #if DEBUG
        debugTrace?.event(.speechStarted, source: .speechEngine, utteranceID: active.token) {
            .init(text: currentPrivateReference ? nil : active.text, label: debugSilentModelTestTransport ? "test.injectedDidStart.silent" : "AVSpeech.didStart")
        }
        #endif
        if case .requested(let id) = active.destination, requestedSpeechPermission?(id, active.text) == false {
            finishActive(outcome: .interrupted, stopSynthesizer: true,
                         diagnosticCause: "source.expiredBeforePlayback"); return
        }
        if let modelReply = currentModelReply, !modelReplyIsCurrent(modelReply, text: active.text) {
            finishActive(outcome: .interrupted, stopSynthesizer: true,
                         diagnosticCause: "model.ownerExpiredBeforePlayback"); return
        }
        if let routeID = currentSpatialRouteID, spatialRoutePermission?(routeID) != true || spatialRouteSpeechPermission?(routeID, active.text) != true {
            finishActive(outcome: .interrupted, stopSynthesizer: true,
                         diagnosticCause: "route.expiredBeforePlayback"); return
        }
        #if DEBUG
        if debugSilentModelTestTransport { debugModelTestStarted.append(active.text) }
        #endif
        if case .requested(let id) = active.destination { onRequestedSpeechStarted?(id, active.text) }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        guard utterance === currentUtterance, delivery.active?.transport == .synthesized else { return }
        finishActive(outcome: .completed, diagnosticCause: "AVSpeech.didFinish")
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        guard utterance === currentUtterance, delivery.active?.transport == .synthesized else { return }
        finishActive(outcome: .interrupted, diagnosticCause: "AVSpeech.didCancel")
    }

    /// Revokes only the short-lived notice with this ID. A camera turn must not
    /// interrupt an unrelated answer or a higher-priority hazard/mobility alert.
    /// Shared by enqueue, platform start and revalidation; missing owner fails closed.
    /// Exposed internally for hosted gate tests without invoking speech or audio.
    func modelReplyIsCurrent(_ lease: ModelResponseAuthority.Lease, text: String) -> Bool {
        modelReplyPermission?(lease, text) == true
    }

    /// Does not touch an independent alert or unrelated document/OCR producer.
    func revalidateModelReply() {
        guard let lease = currentModelReply, let active = delivery.active else { return }
        guard modelReplyIsCurrent(lease, text: active.text) else {
            finishActive(outcome: .interrupted, stopSynthesizer: true,
                         diagnosticCause: "model.ownerExpiredDuringPlayback"); return
        }
    }

    func stopRequestedSpeech(_ id: UUID) {
        guard delivery.active?.destination == .requested(id) else { return }
        _ = stopInformation(announceCancellation: false)
    }

    /// Unlike ordinary information cancellation, this may revoke mobility speech,
    /// but only its exact registered route ID. Independent sensor alerts survive.
    func stopSpatialRouteSpeech(_ id: UUID) {
        guard currentSpatialRouteID == id, let active = delivery.active,
              active.destination == .requested(id), !active.independentAlert else { return }
        finishActive(outcome: .interrupted, stopSynthesizer: true,
                     diagnosticCause: "route.ticketRetired")
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

    /// Route privacy is stronger than ordinary information preemption: private
    /// mobility may contain a saved room or target name. Preserve only provenance-
    /// checked sensor alerts, never priority alone. Do not announce cancellation.
    func stopForPrivateRouteLoss() {
        guard !delivery.mayContinueAfterPrivateRouteLoss else { return }
        finishActive(outcome: .interrupted, stopSynthesizer: true, notify: false)
        // Also stop a synthesizer whose old completion is still settling.
        speech.stopSpeaking(at: .immediate)
    }

    func stop(includingAlerts: Bool = false) {
        guard includingAlerts || (ProcessInfo.processInfo.systemUptime >= urgentUntil && delivery.active?.priority != .danger) else { return }
        if includingAlerts {
            urgentUntil = -.infinity; urgentTimeout?.invalidate(); urgentTimeout = nil
        }
        let hadAnnouncement = delivery.active?.transport == .accessibility
        finishActive(outcome: .interrupted, stopSynthesizer: true)
        speech.stopSpeaking(at: .immediate); beaconOwnership.replace(routeID: nil); player.stop()
        if hadAnnouncement { requestCancellationAnnouncement() }
    }

    deinit {
        outputTimeout?.invalidate(); urgentTimeout?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    func beacon(sector: Int, distance: Double) {
        _ = playBeacon(sector: sector, distance: distance, routeID: nil)
    }
    @discardableResult func spatialRouteBeacon(sector: Int, distance: Double, id: UUID) -> Bool {
        guard spatialRoutePermission?(id) == true else { return false }
        return playBeacon(sector: sector, distance: distance, routeID: id)
    }
    func stopSpatialRouteBeacon(_ id: UUID) {
        guard beaconOwnership.retire(id) else { return }
        player.stop()
    }
    private func playBeacon(sector: Int, distance: Double, routeID: UUID?) -> Bool {
        guard spatialReady, let tone, (0..<8).contains(sector), distance.isFinite, distance >= 0 else { return false }
        if !engine.isRunning { try? engine.start() }
        if let routeID, spatialRoutePermission?(routeID) != true { return false }
        beaconOwnership.replace(routeID: routeID)
        let angle = Double(sector) * .pi / 4
        player.position = AVAudio3DPoint(x: Float(sin(angle) * distance), y: 0, z: Float(-cos(angle) * distance))
        player.stop(); player.scheduleBuffer(tone); player.play(); return true
    }
    func message(for hazard: Hazard) -> String {
        GuidanceText.hazard(hazard, arabic: arabic)
    }
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
}

