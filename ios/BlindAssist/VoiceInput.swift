import AVFoundation
import Speech
import Combine

/// Push-to-talk only. Audio is never sent to a recognizer that requires a network.
final class VoiceInput: ObservableObject {
    @Published private(set) var listening = false
    @Published private(set) var transcript = ""
    @Published private(set) var message = ""
    private var engine: AVAudioEngine?
    private var recognition: SFSpeechRecognitionTask?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var generation = UUID()
    private var timer: Timer?
    var onFinished: ((String) -> Void)?
    func start(arabic: Bool) {
        cancel(); transcript = ""
        let id = UUID(); generation = id
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            AVAudioSession.sharedInstance().requestRecordPermission { allowed in
                DispatchQueue.main.async {
                    guard let self, self.generation == id else { return }
                    guard status == .authorized, allowed else { self.message = "Enable microphone and speech permissions in Settings, or type your question."; return }
                    self.capture(arabic: arabic, id: id)
                }
            }
        }
    }
    private func capture(arabic: Bool, id: UUID) {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: arabic ? "ar-SA" : "en-US")),
              recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else {
            message = "Offline speech recognition is unavailable for this language. Type your question."; return
        }
        do {
            let audio = AVAudioSession.sharedInstance()
            try audio.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
            try audio.setActive(true)
            let engine = AVAudioEngine(), request = SFSpeechAudioBufferRecognitionRequest()
            request.requiresOnDeviceRecognition = true; request.shouldReportPartialResults = true
            let input = engine.inputNode, format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else { throw CocoaError(.featureUnsupported) }
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in request.append(buffer) }
            self.engine = engine; self.request = request
            recognition = recognizer.recognitionTask(with: request) { [weak self] result, error in
                DispatchQueue.main.async {
                    guard let self, self.generation == id else { return }
                    if let result { self.transcript = result.bestTranscription.formattedString }
                    if error != nil || result?.isFinal == true {
                        if error != nil && self.transcript.isEmpty { self.message = "Could not hear a question. Try again or type it." }
                        self.finish()
                    }
                }
            }
            engine.prepare(); try engine.start(); listening = true
            message = "Listening on this phone. Tap Finish question when done."
            timer = Timer.scheduledTimer(withTimeInterval: 20, repeats: false) { [weak self] _ in self?.finish() }
        } catch { cancel(); message = "Microphone unavailable. Type your question." }
    }
    func finish() {
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        cancel(); if !text.isEmpty { message = "Question ready."; onFinished?(text) }
    }
    func cancel() {
        generation = UUID(); timer?.invalidate(); timer = nil
        request?.endAudio(); recognition?.cancel(); recognition = nil; request = nil
        engine?.stop(); engine?.inputNode.removeTap(onBus: 0); engine = nil; listening = false
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
    }
}
