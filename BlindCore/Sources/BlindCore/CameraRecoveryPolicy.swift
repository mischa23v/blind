import Foundation

/// Camera-specific adaptation of the existing VoiceCaptureRecoveryPolicy retry
/// fencing. No camera is started here; permission and foreground state are checked
/// again when a single retry is claimed. This is not proof of sensor readiness.
public struct CameraRecoveryPolicy: Sendable {
    public struct Retry: Equatable, Sendable {
        public let id: UUID
        public let generation: UUID
        public let attempt: Int
        public let scheduledAt: Double
        public let readyAt: Double
    }

    public static let retryDelays: [Double] = [2, 5, 10]
    public static let healthyInterval = 30.0
    public static let maximumHealthyFrameGap = 0.5
    public private(set) var generation = UUID()
    public private(set) var requested = false
    public private(set) var attempts = 0
    public private(set) var blocked = false
    public private(set) var pendingRetry: Retry?
    /// No further automatic retry is available; an already-claimed launch may
    /// still be healthy. Only report exhaustion when recovery is actually needed.
    public var exhausted: Bool { attempts >= Self.retryDelays.count && pendingRetry == nil }
    private var healthySince: Double?
    private var lastHealthyFrame: Double?
    private var lastNow: Double?

    public init() {}

    /// Initial permitted startup or an explicit camera/start/retry action only.
    /// Never call from launch(), background/foreground return, or an error callback.
    public mutating func beginExplicitSession() {
        generation = UUID(); requested = true; attempts = 0; blocked = false
        pendingRetry = nil; healthySince = nil; lastHealthyFrame = nil
    }

    /// Lifecycle suspension cancels a scheduled callback without replenishing its
    /// resource budget or clearing a denial. Foreground alone is not new consent.
    public mutating func pause() {
        generation = UUID(); pendingRetry = nil
        healthySince = nil; lastHealthyFrame = nil
    }

    public mutating func permissionDenied() {
        pause(); blocked = true
    }

    /// At most one pending retry. The caller may retain/read pendingRetry instead
    /// of scheduling another callback for each watchdog tick or repeated error.
    public mutating func schedule(now: Double, foregroundActive: Bool, cameraEnabled: Bool,
                                  authorized: Bool) -> Retry? {
        guard observe(now) else { return nil }
        guard authorized else { permissionDenied(); return nil }
        guard requested, !blocked, foregroundActive, cameraEnabled,
              pendingRetry == nil, attempts < Self.retryDelays.count else { return nil }
        healthySince = nil; lastHealthyFrame = nil
        let delay = Self.retryDelays[attempts]
        attempts += 1
        let retry = Retry(id: UUID(), generation: generation, attempt: attempts,
            scheduledAt: now, readyAt: now + delay)
        pendingRetry = retry
        return retry
    }

    /// A retry is consumed once, no earlier than its recorded deadline. Checking
    /// an obsolete callback cannot retire a newer session's pending operation.
    public mutating func claim(_ retry: Retry, now: Double, foregroundActive: Bool,
                               cameraEnabled: Bool, authorized: Bool) -> Bool {
        guard pendingRetry == retry, retry.generation == generation, observe(now) else { return false }
        guard authorized else { permissionDenied(); return false }
        guard requested, !blocked, foregroundActive, cameraEnabled else { pause(); return false }
        guard now >= retry.readyAt else { return false }
        pendingRetry = nil
        return true
    }

    /// Call only for an actually fresh, normally tracked camera frame, not launch
    /// success or any arbitrary callback. A brief recovery does not reset backoff.
    public mutating func observeHealthyFrame(now: Double) {
        guard observe(now), requested, !blocked else { return }
        pendingRetry = nil
        if let previous = lastHealthyFrame, now - previous <= Self.maximumHealthyFrameGap {
            if let healthySince, now - healthySince >= Self.healthyInterval { attempts = 0 }
        } else { healthySince = now }
        lastHealthyFrame = now
    }

    private mutating func observe(_ now: Double) -> Bool {
        guard now.isFinite, now >= 0, lastNow.map({ now >= $0 }) ?? true else {
            pause()
            return false
        }
        lastNow = now
        return true
    }
}
