import Foundation

/// Independent, one-generation freshness fence. A utility watchdog can retire it
/// while the serialized native producer is busy. The clock is sampled UNDER the
/// lock so cross-queue call ordering cannot manufacture a backwards timestamp.
/// Recent camera frames are not evidence of mesh capture time or physical safety.
final class MeshBenchFrameLease {
    enum Phase: String { case idle, awaitingNormalTracking, current, retired }
    enum RetirementReason: String { case stopped, invalidClock, invalidCapture, startupExpired, frameExpired, trackingLost }
    struct Receipt {
        let phase: Phase
        let retirementReason: RetirementReason?
        var reason: RetirementReason? { retirementReason }
        let beganAt: Double?
        let frameCapturedAt: Double?
        let frameReceivedAt: Double?
        let authorizesPhysicalGuidance = false
        let actualWorldCoverageKnown = false
        let meshCapturedAt: Double? = nil
    }
    private let lock = NSLock()
    private let clock: () -> Double
    private var phase: Phase = .idle
    private var reason: RetirementReason?
    private var notificationClaimed = false
    private var beganAt: Double?
    private var lastClock: Double?
    private var frameCapturedAt: Double?
    private var frameReceivedAt: Double?

    init(clock: @escaping () -> Double = { ProcessInfo.processInfo.systemUptime }) { self.clock = clock }
    @discardableResult func begin() -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard phase == .idle else { return false }
        let now = clock()
        guard now.isFinite, now >= 0, (now + 10).isFinite, now + 10 > now else {
            retire(.invalidClock); return false
        }
        beganAt = now; lastClock = now; phase = .awaitingNormalTracking
        return true
    }
    /// Called synchronously in the owned frame callback; stores only scalar times.
    @discardableResult func observe(capturedAt: Double, normal: Bool) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard checkTime(), let now = lastClock, let beganAt else { return false }
        guard capturedAt.isFinite, capturedAt >= beganAt, now >= capturedAt,
              now - capturedAt <= 0.5, frameCapturedAt.map({ capturedAt > $0 }) ?? true else {
            retire(.invalidCapture); return false
        }
        guard normal || phase != .current else { retire(.trackingLost); return false }
        frameCapturedAt = capturedAt; frameReceivedAt = now
        if normal { phase = .current }
        return true
    }
    func isCurrent() -> Bool {
        lock.lock(); defer { lock.unlock() }
        return checkTime() && phase == .current
    }
    /// Unlike !isCurrent(), this does not treat initial tracking grace as loss.
    func isRetired() -> Bool {
        lock.lock(); defer { lock.unlock() }
        _ = checkTime(); return phase == .retired
    }
    /// At most one cross-queue stop notification may be enqueued for this lease,
    /// even if the main owner is delayed and the utility watchdog keeps ticking.
    /// No reset exists; repeated stop/expiry observations preserve this claim.
    func claimRetirementNotification() -> Bool {
        lock.lock(); defer { lock.unlock() }
        _ = checkTime()
        guard phase == .retired, !notificationClaimed else { return false }
        notificationClaimed = true
        return true
    }
    func receipt() -> Receipt {
        lock.lock(); defer { lock.unlock() }
        _ = checkTime()
        return Receipt(phase: phase, retirementReason: reason, beganAt: beganAt,
            frameCapturedAt: frameCapturedAt, frameReceivedAt: frameReceivedAt)
    }
    func stop() {
        lock.lock(); defer { lock.unlock() }
        if phase != .retired { retire(.stopped) }
    }
    /// Must hold lock. Expiry is permanent; a later good frame cannot revive it.
    private func checkTime() -> Bool {
        guard phase != .idle, phase != .retired else { return false }
        let now = clock()
        guard now.isFinite, let lastClock, now >= lastClock, let beganAt else {
            retire(.invalidClock); return false
        }
        self.lastClock = now
        if phase == .awaitingNormalTracking, now - beganAt > 10 {
            retire(.startupExpired); return false
        }
        if phase == .current {
            guard let captured = frameCapturedAt, let received = frameReceivedAt,
                  now >= captured, now >= received, now - captured <= 0.5, now - received <= 0.5 else {
                retire(.frameExpired); return false
            }
        }
        return true
    }
    private func retire(_ reason: RetirementReason) { phase = .retired; self.reason = reason }
}
