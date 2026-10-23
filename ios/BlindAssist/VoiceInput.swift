import AVFoundation
import Speech
import Combine
import UIKit
import BlindCore
import os

/// On-device recognition turns over a persistent microphone stream. The supported
/// fallback rotates SFSpeech requests; it is not unlimited SpeechAnalyzer capture.
/// All control methods and observable state are used on the main thread.
final class VoiceInput: ObservableObject {
    enum State: Equatable {
        case idle, requestingPermission, starting, listening, recovering, interrupted, failed
    }

    private static let logger = Logger(subsystem: "org.blindassist.mobility", category: "VoiceInput")
    @Published private(set) var state: State = .idle
    @Published private(set) var listening = false
    @Published private(set) var acousticSpeechActive = false
    @Published private(set) var transcript = ""
    @Published private(set) var message = ""
    private var engine: AVAudioEngine?
    private var recognizer: SFSpeechRecognizer?
    private var recognition: SFSpeechRecognitionTask?
    private let input = SpeechBufferSink()
    private var lifecycle = VoiceCaptureRecoveryPolicy()
    private var utterance = VoiceUtteranceTracker()
    private var turn = UUID()
    private var captureGeneration = UUID()
    private var speechBeganDelivered = false
    private var timer: Timer?
    private var inactivityTimer: Timer?
    private var healthTimer: Timer?
    private var recovery: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    private var tapInstalled = false
    private var arabic = false
    private var backgroundAllowed = false
    var continuous: Bool { lifecycle.continuous }
    /// An open microphone is not itself a speaking turn.
    var awaitingUtterance: Bool {
        listening && (!continuous || acousticSpeechActive || (utterance.hasUserSpeech && !utterance.text.isEmpty && !utterance.ignored))
    }
    var onFinished: ((String) -> Void)?
    /// Early voice-processed energy onset, with a non-echo partial fallback.
    /// This is not semantic VAD or speaker identity; residual echo can trigger it.
    var onSpeechBegan: (() -> Void)?
    /// Acoustic release can unblock a final queued reply with no further chunks.
    var onReadyForReply: (() -> Void)?
    /// Synchronous main-actor notification after capture/retries have been stopped.
    /// The controller mutes ordinary output; never announce this through the speaker.
    var onPrivateRouteLost: (@MainActor () -> Void)?
    var onUnavailable: ((String) -> Void)?
    var shouldIgnore: ((String) -> Bool)?

    init() {
        observe(AVAudioSession.interruptionNotification) { [weak self] note in self?.interruption(note) }
        observe(AVAudioSession.mediaServicesWereLostNotification) { [weak self] _ in
            guard let self, self.lifecycle.requested else { return }
            self.lifecycle.mediaServicesLost(); self.cancelRecovery(); self.stopCapture()
            self.state = .interrupted
            self.message = self.arabic ? "خدمة الصوت متوقفة مؤقتاً." : "Audio is temporarily unavailable."
        }
        observe(AVAudioSession.mediaServicesWereResetNotification) { [weak self] _ in
            guard let self, self.lifecycle.requested else { return }
            self.lifecycle.mediaServicesReset()
            // A media reset must not override an interruption or the user's mute.
            guard self.canCapture else { return }
            self.recover(message: self.arabic ? "أستعيد الاستماع." : "Restoring listening.", announce: false)
        }
        observe(AVAudioSession.routeChangeNotification) { [weak self] note in
            guard let self,
                  let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: raw) else { return }
            if reason == .oldDeviceUnavailable {
                // Losing headphones must never fall back to speaking or listening
                // on the phone's speaker. Stop even during recovery/interruption,
                // or when recognition failed while a reply may still be playing.
                self.lifecycle.privateRouteLost()
                self.cancelRecovery(); self.stopCapture()
                self.state = .idle
                self.message = self.arabic ? "انقطع جهاز الصوت. توقفت المحادثة الصوتية." : "Audio device disconnected. Voice conversation paused."
                // observe() delivers synchronously on .main. Do not enqueue this
                // privacy stop behind another speech-completion/recovery callback.
                MainActor.assumeIsolated {
                    if let callback = self.onPrivateRouteLost { callback() }
                }
                return
            }
            guard self.lifecycle.requested, self.canCapture else { return }
            // setCategory causes our own notification; rebuilding for it can loop.
            guard reason != .categoryChange, reason != .unknown else { return }
            self.recover(message: self.arabic ? "أعيد توصيل الميكروفون." : "Reconnecting the microphone.", announce: false)
        }
        observe(.AVAudioEngineConfigurationChange) { [weak self] note in
            guard let self, let changed = note.object as? AVAudioEngine,
                  let current = self.engine, changed === current, self.canCapture else { return }
            self.recover(message: self.arabic ? "أعيد توصيل الميكروفون." : "Reconnecting the microphone.", announce: false)
        }
        observe(UIApplication.didEnterBackgroundNotification) { [weak self] _ in
            guard let self, !self.backgroundAllowed, self.lifecycle.requested else { return }
            self.cancel()
            self.message = self.arabic ? "توقف الاستماع خارج التطبيق." : "Listening stopped outside the app."
        }
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
        recovery?.cancel(); timer?.invalidate(); inactivityTimer?.invalidate(); healthTimer?.invalidate()
        input.cancelCapture(); input.replace(with: nil); recognition?.cancel(); engine?.stop()
        if tapInstalled { engine?.inputNode.removeTap(onBus: 0) }
    }

    /// The controller must obtain explicit user opt-in and configure audio background
    /// mode. This permits audio only, never camera capture or a 24-hour guarantee.
    func setBackgroundAllowed(_ allowed: Bool) {
        backgroundAllowed = allowed
        if !allowed, inBackground { cancel() }
    }

    func start(arabic: Bool, timeout: Double = 20) {
        // A manual/answer-window request cannot demote an active hands-free
        // session or bypass its recovery/interruption. Explicit mute/end still
        // cancel the lifecycle and never schedule automatic capture afterward.
        if continuous, lifecycle.requested, self.arabic == arabic { return }
        begin(arabic: arabic, continuous: false, timeout: timeout)
    }

    func startContinuous(arabic: Bool) {
        // Do not duplicate permission requests or bypass an active interruption.
        guard !continuous || !lifecycle.requested || self.arabic != arabic else { return }
        begin(arabic: arabic, continuous: true, timeout: 50)
    }

    private var inBackground: Bool { UIApplication.shared.applicationState == .background }
    private var canCapture: Bool {
        lifecycle.allowsCapture(session: lifecycle.session, inBackground: inBackground,
                                backgroundAllowed: backgroundAllowed)
    }

    private func begin(arabic: Bool, continuous: Bool, timeout: Double) {
        cancel(); self.arabic = arabic
        let session = lifecycle.begin(continuous: continuous)
        guard canCapture else { cancel(); return }
        state = .requestingPermission
        message = arabic ? "أتحقق من إذن الميكروفون والكلام." : "Checking microphone and speech permission."
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                guard let self, self.lifecycle.session == session, self.canCapture else { return }
                guard status == .authorized else { self.permissionUnavailable(); return }
                AVAudioSession.sharedInstance().requestRecordPermission { [weak self] allowed in
                    DispatchQueue.main.async {
                        guard let self, self.lifecycle.session == session, self.canCapture else { return }
                        guard allowed else { self.permissionUnavailable(); return }
                        self.capture(timeout: timeout)
                    }
                }
            }
        }
    }

    private func permissionUnavailable() {
        fail(arabic ? "أحتاج إذن الميكروفون والتعرف على الكلام. اطلب المساعدة في الإعدادات." : "I need microphone and speech permission. Ask for help in Settings.")
    }

    private func capture(timeout: Double = 50) {
        guard canCapture else { return }
        // Recovery must never bypass permission, including interruptions while the
        // original authorization sheets were visible or a later Settings change.
        guard SFSpeechRecognizer.authorizationStatus() == .authorized,
              AVAudioSession.sharedInstance().recordPermission == .granted else {
            permissionUnavailable(); return
        }
        state = .starting
        message = arabic ? "أشغّل الاستماع." : "Starting listening."
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: arabic ? "ar-SA" : "en-US")),
              recognizer.supportsOnDeviceRecognition else {
            fail(arabic ? "لا يتوفر الاستماع دون إنترنت بهذه اللغة على هذا الهاتف." : "Offline listening isn't available in this language on this phone.")
            return
        }
        guard recognizer.isAvailable else {
            recover(message: arabic ? "التعرف المحلي على الكلام غير متاح الآن." : "On-device speech recognition is unavailable right now.")
            return
        }
        do {
            let audio = AVAudioSession.sharedInstance()
            try audio.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
            try audio.setActive(true)
            let engine = AVAudioEngine()
            // Apple documents enabling voice processing while the engine is stopped.
            // Both I/O nodes are switched to the echo-cancelled voice-processing mode.
            try engine.inputNode.setVoiceProcessingEnabled(true)
            let format = engine.inputNode.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else { throw CocoaError(.featureUnsupported) }
            self.recognizer = recognizer; self.engine = engine
            let sink = input
            let captureID = UUID(), sessionID = lifecycle.session
            captureGeneration = captureID
            sink.beginCapture(captureID) { [weak self] update in
                guard let self, self.listening, self.captureGeneration == update.capture,
                      self.accepts(session: sessionID, turn: update.turn) else { return }
                let wasActive = self.acousticSpeechActive
                self.acousticSpeechActive = update.isActive
                if let onsetAt = update.onsetAt,
                   ProcessInfo.processInfo.systemUptime - onsetAt <= 0.75,
                   !self.speechBeganDelivered {
                    self.speechBeganDelivered = true
                    self.onSpeechBegan?()
                    guard self.accepts(session: sessionID, turn: update.turn) else { return }
                }
                if wasActive && !self.acousticSpeechActive && !self.awaitingUtterance {
                    self.onReadyForReply?()
                }
            }
            engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in sink.append(buffer) }
            tapInstalled = true
            beginTurn(timeout: timeout)
            engine.prepare(); try engine.start()
            lifecycle.captureStarted(at: ProcessInfo.processInfo.systemUptime)
            listening = true; state = .listening
            message = arabic ? "أنا أستمع." : "I'm listening."
            startHealthCheck()
        } catch {
            let failure = error as NSError
            Self.logger.error("Capture failed: \(failure.domain, privacy: .public) code \(failure.code)")
            recover(message: arabic ? "لا أستطيع سماعك الآن. أحاول استعادة الميكروفون." : "I can't hear you right now. Trying to restore the microphone.")
        }
    }

    private func beginTurn(timeout: Double = 50) {
        inactivityTimer?.invalidate(); timer?.invalidate()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        let id = UUID(); turn = id
        let session = lifecycle.session
        utterance = VoiceUtteranceTracker(); transcript = ""
        speechBeganDelivered = false
        // Fence callbacks and read energy state in the same sink transaction.
        // Do not reset the envelope when renewing a recognizer request.
        acousticSpeechActive = input.replace(with: request, turn: id)
        recognition?.cancel()
        recognition = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self, self.accepts(session: session, turn: id) else { return }
                if let result {
                    let text = result.bestTranscription.formattedString
                    let changed = text.trimmingCharacters(in: .whitespacesAndNewlines) != self.utterance.text
                    let began = self.utterance.observe(text, isEcho: self.shouldIgnore?(text) == true)
                    self.transcript = self.utterance.text
                    if self.utterance.ignored { self.inactivityTimer?.invalidate() }
                    if began, !self.speechBeganDelivered {
                        self.speechBeganDelivered = true
                        self.onSpeechBegan?()
                        // The callback may mute/end/restart the session.
                        guard self.accepts(session: session, turn: id) else { return }
                    }
                    if changed, !self.utterance.text.isEmpty, !self.utterance.ignored {
                        self.inactivityTimer?.invalidate()
                        // Text inactivity is a fallback endpoint heuristic, NOT acoustic silence.
                        self.inactivityTimer = self.scheduled(after: 1.5) { [weak self] in
                            guard let self, self.accepts(session: session, turn: id) else { return }
                            self.finish()
                        }
                    }
                    if result.isFinal { self.finish(); return }
                }
                if let error {
                    let failure = error as NSError
                    Self.logger.error("Recognition failed: \(failure.domain, privacy: .public) code \(failure.code)")
                    // Do not submit a potentially incomplete hypothesis after an error.
                    self.recover(message: self.arabic ? "انقطع التعرف على الكلام. أحاول استعادته." : "Speech recognition was interrupted. Trying to restore it.")
                }
            }
        }
        let duration = continuous ? 50 : (timeout.isFinite ? max(2, min(20, timeout)) : 20)
        timer = scheduled(after: duration) { [weak self] in
            guard let self, self.accepts(session: session, turn: id) else { return }
            self.finish()
        }
    }

    func finish() {
        guard lifecycle.requested, canCapture else { return }
        let text = utterance.deliverable(isEcho: shouldIgnore?(utterance.text) == true)
        if continuous, engine?.isRunning == true, canCapture { beginTurn() }
        else { cancel() }
        guard let text else { return }
        onFinished?(text)
    }

    /// Scene operations may end a manual turn without disabling hands-free input.
    func endManualTurn() { if !continuous { cancel() } }

    func cancel() {
        lifecycle.cancel(); cancelRecovery(); stopCapture()
        state = .idle; message = ""
    }

    private func stopCapture() {
        turn = UUID(); captureGeneration = UUID()
        input.cancelCapture()
        speechBeganDelivered = false; acousticSpeechActive = false
        timer?.invalidate(); timer = nil
        inactivityTimer?.invalidate(); inactivityTimer = nil
        healthTimer?.invalidate(); healthTimer = nil
        input.replace(with: nil); recognition?.cancel(); recognition = nil
        engine?.stop()
        if tapInstalled { engine?.inputNode.removeTap(onBus: 0) }
        tapInstalled = false; engine = nil; recognizer = nil
        utterance = VoiceUtteranceTracker(); transcript = ""; listening = false
        // Feedback shares AVAudioSession; do not deactivate its urgent speech here.
    }

    private func recover(message text: String, announce: Bool = true) {
        guard lifecycle.requested else { return }
        // Route changes often arrive with an engine-configuration notification.
        // Coalesce them instead of spending the retry budget on one physical event.
        if state == .recovering, recovery != nil { return }
        cancelRecovery(); stopCapture()
        guard canCapture else { return }
        guard continuous else { fail(text); return }
        guard let retry = lifecycle.nextRetry(inBackground: inBackground, backgroundAllowed: backgroundAllowed,
                                              now: ProcessInfo.processInfo.systemUptime) else {
            fail(arabic ? "تعذر استعادة الاستماع. اضغط إعادة الاتصال أو تحقق من الإعدادات." : "Listening couldn't recover. Tap Reconnect or check Settings.")
            return
        }
        state = .recovering; message = text
        if announce, lifecycle.attempts == 1 { onUnavailable?(text) }
        // A notification callback can cause the controller to cancel synchronously.
        guard lifecycle.session == retry.session, canCapture else { return }
        recovery = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(retry.delay)) } catch { return }
            guard !Task.isCancelled, let self,
                  self.lifecycle.claim(retry, inBackground: self.inBackground,
                                       backgroundAllowed: self.backgroundAllowed) else { return }
            self.recovery = nil
            self.capture()
        }
    }

    private func interruption(_ note: Notification) {
        guard lifecycle.requested,
              let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let kind = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        if kind == .began {
            lifecycle.interruptionBegan(); cancelRecovery(); stopCapture(); state = .interrupted
            message = arabic ? "انقطع الميكروفون مؤقتاً." : "The microphone is temporarily interrupted."
        } else {
            let rawOptions = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let shouldResume = AVAudioSession.InterruptionOptions(rawValue: rawOptions).contains(.shouldResume)
            guard lifecycle.interruptionEnded(shouldResume: shouldResume) else {
                if !lifecycle.requested { fail(arabic ? "توقف الاستماع. اضغط إعادة الاتصال." : "Listening paused. Tap Reconnect.") }
                return
            }
            guard canCapture else { return }
            recover(message: arabic ? "أستعيد الاستماع." : "Restoring listening.", announce: false)
        }
    }

    private func startHealthCheck() {
        let session = lifecycle.session
        healthTimer?.invalidate()
        healthTimer = scheduled(after: 4, repeats: true) { [weak self] in
            guard let self, self.lifecycle.session == session, self.listening, self.canCapture else { return }
            let age = ProcessInfo.processInfo.systemUptime - self.input.lastBufferTime
            guard self.engine?.isRunning != true || age > 8 else { return }
            self.recover(message: self.arabic ? "توقف صوت الميكروفون. أحاول استعادته." : "Microphone audio stopped. Trying to restore it.")
        }
    }

    private func accepts(session: UUID, turn: UUID) -> Bool {
        lifecycle.session == session && self.turn == turn && canCapture
    }
    private func cancelRecovery() { recovery?.cancel(); recovery = nil }
    private func fail(_ text: String) {
        cancel(); state = .failed; message = text; onUnavailable?(text)
    }
    private func observe(_ name: Notification.Name, handler: @escaping (Notification) -> Void) {
        observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main, using: handler))
    }
    private func scheduled(after interval: TimeInterval, repeats: Bool = false, action: @escaping () -> Void) -> Timer {
        let timer = Timer(timeInterval: interval, repeats: repeats) { _ in action() }
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }
}

/// AVAudioEngine taps run off the main thread; swapping requests is atomic.
/// PCM is inspected synchronously, never stored, uploaded or shared across queues.
private final class SpeechBufferSink: @unchecked Sendable {
    private let lock = NSLock()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var lastBuffer = ProcessInfo.processInfo.systemUptime
    private var detector = AcousticSpeechOnset()
    private var mailbox = AcousticOnsetMailbox()
    private var onAcousticUpdate: ((AcousticOnsetMailbox.Update) -> Void)?
    var lastBufferTime: TimeInterval { lock.lock(); defer { lock.unlock() }; return lastBuffer }

    func beginCapture(_ id: UUID, onUpdate: @escaping (AcousticOnsetMailbox.Update) -> Void) {
        lock.lock(); defer { lock.unlock() }
        detector = AcousticSpeechOnset(); mailbox.beginCapture(id)
        onAcousticUpdate = onUpdate; lastBuffer = ProcessInfo.processInfo.systemUptime
    }
    func cancelCapture() {
        lock.lock(); defer { lock.unlock() }
        mailbox.cancel(); onAcousticUpdate = nil; detector = AcousticSpeechOnset()
    }
    @discardableResult func replace(with next: SFSpeechAudioBufferRecognitionRequest?, turn: UUID? = nil) -> Bool {
        lock.lock()
        let previous = request; request = next
        if let turn { mailbox.beginTurn(turn) }
        let active = detector.isActive
        lock.unlock()
        previous?.endAudio()
        return active
    }
    func append(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        let now = ProcessInfo.processInfo.systemUptime
        if buffer.frameLength > 0 { lastBuffer = now }
        request?.append(buffer)
        var scheduleDrain = false
        if onAcousticUpdate != nil, buffer.frameLength > 0,
           let channel = buffer.floatChannelData?[0] {
            // AVAudioEngine's voice-processed first channel is used. Unsupported
            // PCM formats retain transcript onset rather than guessing samples.
            let stride = max(1, Int(buffer.stride))
            let frames = Int(buffer.frameLength)
            let samples = UnsafeBufferPointer(start: channel, count: (frames - 1) * stride + 1)
            let wasActive = detector.isActive
            let began = detector.process(samples: samples, sampleRate: buffer.format.sampleRate, stride: stride)
            if began || wasActive != detector.isActive {
                scheduleDrain = mailbox.offer(isActive: detector.isActive, began: began, at: now)
            }
        }
        lock.unlock()
        // Only a bounded edge notification crosses queues, never the PCM buffer.
        // The one-slot mailbox coalesces transitions while main is busy.
        if scheduleDrain {
            DispatchQueue.main.async { [weak self] in self?.drainAcousticUpdate() }
        }
    }
    private func drainAcousticUpdate() {
        lock.lock()
        let update = mailbox.drain(), callback = onAcousticUpdate
        lock.unlock()
        if let update { callback?(update) }
    }
}
