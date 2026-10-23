import Foundation

/// A bounded acoustic-energy heuristic for early interruption, not semantic VAD,
/// speaker recognition, or an endpoint detector. Other people, music, and residual
/// playback echo may trigger it. Recognition still owns words and turn completion.
public struct AcousticSpeechOnset: Sendable {
    public struct Configuration: Sendable {
        public let calibration: TimeInterval
        public let attack: TimeInterval
        public let release: TimeInterval
        public let cooldown: TimeInterval
        public let maximumHold: TimeInterval
        public let minimumLevelDBFS: Double
        public let noiseMarginDB: Double

        public init(calibration: TimeInterval = 0.20, attack: TimeInterval = 0.12,
                    release: TimeInterval = 0.30, cooldown: TimeInterval = 0.65,
                    maximumHold: TimeInterval = 3,
                    minimumLevelDBFS: Double = -44, noiseMarginDB: Double = 12) {
            self.calibration = calibration.isFinite ? min(1, max(0.10, calibration)) : 0.20
            self.attack = attack.isFinite ? min(1, max(0.08, attack)) : 0.12
            self.release = release.isFinite ? min(2, max(0.15, release)) : 0.30
            self.cooldown = cooldown.isFinite ? min(5, max(0.40, cooldown)) : 0.65
            self.maximumHold = maximumHold.isFinite ? min(10, max(1, maximumHold)) : 3
            self.minimumLevelDBFS = minimumLevelDBFS.isFinite ? min(-15, max(-65, minimumLevelDBFS)) : -44
            self.noiseMarginDB = noiseMarginDB.isFinite ? min(24, max(6, noiseMarginDB)) : 12
        }
    }

    public private(set) var isActive = false
    public private(set) var noiseFloorDBFS: Double = -80
    private let configuration: Configuration
    private var calibrationElapsed: TimeInterval = 0
    private var calibrationMinimum: Double = 0
    private var attackElapsed: TimeInterval = 0
    private var silenceElapsed: TimeInterval = 0
    private var activeElapsed: TimeInterval = 0
    private var heldUntilSilence = false
    private var sinceOnset: TimeInterval = 60

    public init(configuration: Configuration = Configuration()) { self.configuration = configuration }

    /// Reads PCM synchronously without storing its pointer or allocating a copy.
    /// At most 4,096 frames are examined; unsupported/invalid buffers fail closed.
    /// For an interleaved buffer, pass the selected channel pointer and its stride.
    @discardableResult public mutating func process(samples: UnsafeBufferPointer<Float>,
                                                    sampleRate: Double, stride: Int = 1) -> Bool {
        guard sampleRate.isFinite, (8_000...192_000).contains(sampleRate), stride > 0,
              !samples.isEmpty else { invalidateSignal(); return false }
        let availableFrames = 1 + (samples.count - 1) / stride
        guard Double(availableFrames) / sampleRate <= 0.25 else { invalidateSignal(); return false }
        let count = min(4_096, availableFrames)
        var power = 0.0
        for frame in 0..<count {
            let sample = Double(samples[frame * stride])
            guard sample.isFinite else { invalidateSignal(); return false }
            power += min(1, sample * sample)
        }
        let rms = sqrt(power / Double(count))
        return process(rms: rms, duration: Double(count) / sampleRate)
    }

    /// Energy-envelope entry point used by the PCM adapter and deterministic tests.
    @discardableResult public mutating func process(rms: Double, duration: TimeInterval) -> Bool {
        guard rms.isFinite, rms >= 0, duration.isFinite, duration > 0, duration <= 0.25 else {
            invalidateSignal(); return false
        }
        let level = max(-120, 20 * log10(max(0.000_001, min(1, rms))))
        sinceOnset = min(60, sinceOnset + duration)
        if calibrationElapsed < configuration.calibration {
            calibrationMinimum = min(calibrationMinimum, level)
            noiseFloorDBFS = min(-15, max(-80, calibrationMinimum))
            calibrationElapsed += duration
            return false
        }
        let onsetThreshold = max(configuration.minimumLevelDBFS, noiseFloorDBFS + configuration.noiseMarginDB)
        let releaseThreshold = onsetThreshold - 4

        if heldUntilSilence {
            activeElapsed += duration
            // Unclassified continuous noise must not block narration indefinitely.
            // Keep the onset latched until silence so it cannot repeatedly interrupt.
            if activeElapsed >= configuration.maximumHold { isActive = false }
            if level < releaseThreshold {
                silenceElapsed += duration
                adaptNoiseFloor(toward: level, duration: duration)
                if silenceElapsed + 0.000_001 >= configuration.release {
                    isActive = false; heldUntilSilence = false; silenceElapsed = 0; attackElapsed = 0
                }
            } else { silenceElapsed = 0 }
            return false
        }
        if level >= onsetThreshold {
            attackElapsed += duration
            guard attackElapsed + 0.000_001 >= configuration.attack,
                  sinceOnset + 0.000_001 >= configuration.cooldown else { return false }
            isActive = true; heldUntilSilence = true; activeElapsed = 0
            silenceElapsed = 0; attackElapsed = 0; sinceOnset = 0
            return true
        }
        attackElapsed = 0
        adaptNoiseFloor(toward: level, duration: duration)
        return false
    }

    private mutating func adaptNoiseFloor(toward level: Double, duration: TimeInterval) {
        // Follow quieter baseline quickly, rising background slowly. Never learn
        // above-threshold activity as the noise floor while a candidate is active.
        let timeConstant = level < noiseFloorDBFS ? 0.25 : 1.5
        let weight = 1 - exp(-duration / timeConstant)
        noiseFloorDBFS = min(-15, max(-80, noiseFloorDBFS + weight * (level - noiseFloorDBFS)))
    }

    private mutating func invalidateSignal() {
        isActive = false; heldUntilSilence = false; activeElapsed = 0
        attackElapsed = 0; silenceElapsed = 0
    }
}

/// One-slot handoff between a capture callback and its main-thread consumer.
/// The owner provides synchronization. Recognition renewal fences events without
/// resetting the acoustic envelope; cancellation also invalidates queued events.
public struct AcousticOnsetMailbox: Sendable {
    public struct Update: Sendable {
        public let capture: UUID
        public let turn: UUID
        public let isActive: Bool
        public let onsetAt: TimeInterval?
    }
    private var capture: UUID?
    private var turn: UUID?
    private var pending: Update?
    private var scheduled = false
    public init() {}
    public mutating func beginCapture(_ id: UUID) { capture = id; turn = nil; pending = nil }
    public mutating func beginTurn(_ id: UUID) { turn = id; pending = nil }
    public mutating func cancel() { capture = nil; turn = nil; pending = nil }

    /// True means the caller must enqueue one drain, not one callback per buffer.
    public mutating func offer(isActive: Bool, began: Bool, at now: TimeInterval) -> Bool {
        guard let capture, let turn, now.isFinite else { return false }
        pending = Update(capture: capture, turn: turn, isActive: isActive,
                         onsetAt: began ? now : pending?.onsetAt)
        guard !scheduled else { return false }
        scheduled = true
        return true
    }
    public mutating func drain() -> Update? {
        defer { scheduled = false; pending = nil }
        return pending
    }
}
