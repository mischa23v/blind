import Foundation

/// Ephemeral foreground/background voice-session policy. Deliberately not Codable:
/// restoring saved conversation must never silently restore microphone permission.
/// Device permission, audio availability and independent safety gates still apply.
public struct AssistantSession: Sendable, Equatable {
    public enum State: String, Sendable { case idle, active, muted, ended }
    public private(set) var state: State = .idle
    public private(set) var generation: UInt64 = 0
    public private(set) var foregroundActive = true
    public private(set) var backgroundAllowed = false
    /// Route loss is not ordinary microphone mute: private ordinary audio stays held
    /// until an explicit Start/Unmute, even if camera and typed conversation continue.
    public private(set) var privateAudioHeld = false
    public var maySpeakOrdinary: Bool { mayRespond && !privateAudioHeld }
    public init() {}

    public var shouldListen: Bool { state == .active && (foregroundActive || backgroundAllowed) }
    public var mayRespond: Bool { (state == .active || state == .muted) && (foregroundActive || backgroundAllowed) }
    /// Background audio opt-in does not authorize background camera capture.
    public var shouldRunCamera: Bool { foregroundActive && (state == .active || state == .muted) }

    public mutating func start() {
        guard state != .active || privateAudioHeld else { return }
        privateAudioHeld = false
        state = .active; invalidate()
    }
    public mutating func mute() {
        guard state == .active else { return }
        state = .muted; invalidate()
    }
    /// Unmute only an existing session. An ended/never-started session needs Start.
    public mutating func unmute() {
        guard state == .muted else { return }
        privateAudioHeld = false
        state = .active; invalidate()
    }
    public mutating func losePrivateAudioRoute() {
        privateAudioHeld = true
        if state == .active { state = .muted }
        invalidate()
    }
    public mutating func end() {
        guard state != .ended else { return }
        state = .ended; invalidate()
    }
    public mutating func enterBackground() {
        guard foregroundActive else { return }
        foregroundActive = false; invalidate()
    }
    public mutating func enterForeground() {
        guard !foregroundActive else { return }
        foregroundActive = true; invalidate()
    }
    public mutating func setBackgroundAllowed(_ allowed: Bool) {
        guard backgroundAllowed != allowed else { return }
        backgroundAllowed = allowed; invalidate()
    }
    public mutating func invalidate() { generation &+= 1 }
    public func accepts(generation candidate: UInt64) -> Bool { candidate == generation && mayRespond }
}
