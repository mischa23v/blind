import Foundation

// Test-only, no executor hops. All state is lock-protected; resumes/cancellation
// occur after unlocking. A result may win before continuation/wake installation.
final class PublicationDeadlineLatch: @unchecked Sendable {
    enum Outcome: Sendable, Equatable { case timely, timedOut, cancelled }
    let deadline: ContinuousClock.Instant
    private let lock = NSLock()
    private var outcome: Outcome?
    private var continuation: CheckedContinuation<Outcome, Never>?
    private var installed = false
    private var wake: Task<Void, Never>?
    init(deadline: ContinuousClock.Instant) { self.deadline = deadline }
    var pending: Bool {
        lock.lock(); defer { lock.unlock() }
        return outcome == nil
    }
    func install(_ next: CheckedContinuation<Outcome, Never>) {
        lock.lock()
        precondition(!installed, "Exactly one continuation per wait")
        installed = true
        let finished = outcome
        if finished == nil { continuation = next }
        lock.unlock()
        if let finished { next.resume(returning: finished) }
    }
    func installWake(_ next: Task<Void, Never>) {
        lock.lock()
        precondition(wake == nil, "Exactly one deadline wake per wait")
        let finished = outcome != nil
        if !finished { wake = next }
        lock.unlock()
        if finished { next.cancel() }
    }
    @discardableResult func observe(_ condition: Bool, at instant: ContinuousClock.Instant) -> Bool {
        if instant > deadline { return settle(.timedOut) }
        return condition ? settle(.timely) : false
    }
    @discardableResult func expire(at instant: ContinuousClock.Instant) -> Bool {
        precondition(instant >= deadline, "Deadline wake must not run early")
        return settle(.timedOut)
    }
    @discardableResult func cancel() -> Bool { settle(.cancelled) }
    private func settle(_ result: Outcome) -> Bool {
        lock.lock()
        guard outcome == nil else { lock.unlock(); return false }
        outcome = result
        let waiting = continuation
        continuation = nil
        let sleeper = wake
        wake = nil
        lock.unlock()
        sleeper?.cancel()
        waiting?.resume(returning: result)
        return true
    }
}
