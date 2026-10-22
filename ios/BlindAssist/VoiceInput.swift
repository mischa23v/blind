import AVFoundation
import Speech
import Combine
import os

/// On-device speech turns over a persistent microphone stream. A finished turn
/// renews recognition without stopping the audio engine. Hardware interruptions
/// remain observable failures, not claims of uninterrupted listening.
final class VoiceInput: ObservableObject {
    private static let logger = Logger(subsystem: "org.blindassist.mobility", category: "VoiceInput")
    @Published private(set) var listening = false
    @Published private(set) var transcript = ""
    @Published private(set) var message = ""
    private var engine: AVAudioEngine?
    private var recognizer: SFSpeechRecognizer?
    private var recognition: SFSpeechRecognitionTask?
    private let input = SpeechBufferSink()
    private var generation = UUID()
    private var turn = UUID()
    private var timer: Timer?
    private var silenceTimer: Timer?
    private var recovery: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    private var arabic = false
    private(set) var continuous = false
    /// An open microphone is not itself a speaking turn.
    var awaitingUtterance: Bool {
        listening && (!continuous || (!transcript.isEmpty && shouldIgnore?(transcript) != true))
    }
    private var failures = 0
    var onFinished: ((String) -> Void)?
    var onUnavailable: ((String) -> Void)?
    var shouldIgnore: ((String) -> Bool)?

    init() {
        observers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            guard let self, let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let kind = AVAudioSession.InterruptionType(rawValue: raw) else { return }
            if kind == .began {
                self.stopCapture()
                self.unavailable(self.arabic ? "انقطع الميكروفون." : "The microphone was interrupted.")
            } else if self.continuous {
                self.recover()
            }
        })
        observers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self, self.continuous else { return }
            self.stopCapture(); self.recover()
        })
    }

    deinit { observers.forEach(NotificationCenter.default.removeObserver); recovery?.cancel() }

    func start(arabic: Bool, timeout: Double = 20) {
        begin(arabic: arabic, continuous: false, timeout: timeout)
    }

    func startContinuous(arabic: Bool) {
        guard !continuous || !listening || self.arabic != arabic else { return }
        begin(arabic: arabic, continuous: true, timeout: 50)
    }

    private func begin(arabic: Bool, continuous: Bool, timeout: Double) {
        cancel(); self.arabic = arabic; self.continuous = continuous; failures = 0
        let id = generation
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            AVAudioSession.sharedInstance().requestRecordPermission { allowed in
                DispatchQueue.main.async {
                    guard let self, self.generation == id else { return }
                    guard status == .authorized, allowed else {
                        self.continuous = false
                        self.unavailable(arabic ? "أحتاج إذن الميكروفون والتعرف على الكلام. اطلب المساعدة في الإعدادات." : "I need microphone and speech permission. Ask for help in Settings.")
                        return
                    }
                    self.capture(timeout: timeout)
                }
            }
        }
    }

    private func capture(timeout: Double = 50) {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: arabic ? "ar-SA" : "en-US")),
              recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else {
            continuous = false
            unavailable(arabic ? "لا يتوفر الاستماع دون إنترنت بهذه اللغة على هذا الهاتف." : "Offline listening isn't available in this language on this phone.")
            return
        }
        do {
            let audio = AVAudioSession.sharedInstance()
            try audio.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
            try audio.setActive(true)
            let engine = AVAudioEngine()
            try engine.inputNode.setVoiceProcessingEnabled(true)
            let format = engine.inputNode.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else { throw CocoaError(.featureUnsupported) }
            self.recognizer = recognizer; self.engine = engine
            beginTurn(timeout: timeout)
            let sink = input
            engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in sink.append(buffer) }
            engine.prepare(); try engine.start(); listening = true
            message = arabic ? "أنا أستمع." : "I'm listening."
        } catch {
            let failure = error as NSError
            Self.logger.error("Capture failed: \(failure.domain, privacy: .public) code \(failure.code)")
            stopCapture()
            unavailable(arabic ? "لا أستطيع سماعك الآن. تحقق من الميكروفون في الإعدادات." : "I can't hear you right now. Check the microphone in Settings.")
        }
    }

    private func beginTurn(timeout: Double = 50) {
        silenceTimer?.invalidate(); timer?.invalidate()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true; request.shouldReportPartialResults = true
        let id = UUID(); turn = id; transcript = ""
        // Replace the sink before cancelling the old task. Audio capture stays active.
        input.replace(with: request)
        recognition?.cancel()
        recognition = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self, self.turn == id else { return }
                if let result {
                    let text = result.bestTranscription.formattedString
                    if text != self.transcript {
                        self.transcript = text; self.failures = 0
                        self.silenceTimer?.invalidate()
                        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            self.silenceTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
                                guard let self, self.turn == id else { return }
                                self.finish()
                            }
                        }
                    }
                    if result.isFinal { self.finish(); return }
                }
                if let error {
                    let failure = error as NSError
                    Self.logger.error("Recognition failed: \(failure.domain, privacy: .public) code \(failure.code)")
                    self.stopCapture()
                    self.unavailable(self.arabic ? "انقطع التعرف على الكلام. أحاول استعادته." : "Speech recognition was interrupted. I'm trying to reconnect.")
                    if self.continuous { self.recover() }
                }
            }
        }
        timer = Timer.scheduledTimer(withTimeInterval: continuous ? 50 : max(2, min(20, timeout)), repeats: false) { [weak self] _ in self?.finish() }
    }

    func finish() {
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let ignored = shouldIgnore?(text) == true
        if continuous && engine?.isRunning == true { beginTurn() } else { cancel() }
        guard !text.isEmpty, !ignored else { return }
        onFinished?(text)
    }

    /// Existing scene operations may end a manual turn, but never disable the companion microphone.
    func endManualTurn() { if !continuous { cancel() } }

    func cancel() {
        continuous = false; generation = UUID(); recovery?.cancel(); recovery = nil
        stopCapture()
    }

    private func stopCapture() {
        turn = UUID(); timer?.invalidate(); timer = nil; silenceTimer?.invalidate(); silenceTimer = nil
        input.replace(with: nil); recognition?.cancel(); recognition = nil
        engine?.stop(); engine?.inputNode.removeTap(onBus: 0); engine = nil; recognizer = nil; listening = false
    }

    private func recover() {
        recovery?.cancel(); failures += 1
        guard failures <= 3 else {
            continuous = false
            unavailable(arabic ? "تعذر استعادة الاستماع. اطلب المساعدة في الإعدادات." : "Listening couldn't recover. Ask for help in Settings.")
            return
        }
        let id = generation
        recovery = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled, let self, self.generation == id, self.continuous else { return }
            self.capture()
        }
    }

    private func unavailable(_ text: String) { message = text; onUnavailable?(text) }
}

/// Audio callbacks run off the main thread; swapping recognition requests is atomic.
private final class SpeechBufferSink: @unchecked Sendable {
    private let lock = NSLock()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    func replace(with next: SFSpeechAudioBufferRecognitionRequest?) {
        lock.lock(); let previous = request; request = next; lock.unlock()
        previous?.endAudio()
    }
    func append(_ buffer: AVAudioPCMBuffer) {
        lock.lock(); defer { lock.unlock() }
        request?.append(buffer)
    }
}
