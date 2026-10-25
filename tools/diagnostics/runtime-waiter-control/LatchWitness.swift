import Foundation

final class Claims: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func add(_ won: Bool) { lock.lock(); count += won ? 1 : 0; lock.unlock() }
    var value: Int { lock.lock(); defer { lock.unlock() }; return count }
}

@main struct Witness {
    static func main() async {
        let now = ContinuousClock().now
        let deadline = now.advanced(by: .seconds(3))
        let timely = PublicationDeadlineLatch(deadline: deadline)
        let a = await withCheckedContinuation { c in
            timely.install(c)
            precondition(!timely.observe(false, at: now))
            precondition(timely.observe(true, at: deadline))
            precondition(!timely.observe(true, at: deadline))
            precondition(!timely.cancel())
        }
        precondition(a == .timely)
        let late = PublicationDeadlineLatch(deadline: deadline)
        precondition(late.observe(true, at: deadline.advanced(by: .nanoseconds(1))))
        let b = await withCheckedContinuation { late.install($0) }
        precondition(b == .timedOut)
        let lateFalse = PublicationDeadlineLatch(deadline: deadline)
        precondition(lateFalse.observe(false, at: deadline.advanced(by: .seconds(10))))
        let c = await withCheckedContinuation { lateFalse.install($0) }
        precondition(c == .timedOut)
        let expired = PublicationDeadlineLatch(deadline: deadline)
        let d = await withCheckedContinuation { c in
            expired.install(c)
            precondition(expired.expire(at: deadline.advanced(by: .seconds(20))))
            precondition(!expired.observe(true, at: now))
        }
        precondition(d == .timedOut)
        let cancelled = PublicationDeadlineLatch(deadline: deadline)
        precondition(cancelled.cancel())
        let e = await withCheckedContinuation { cancelled.install($0) }
        precondition(e == .cancelled)
        // Fixed-count concurrent cancellation/publication race, never retry-until-pass.
        for _ in 0..<100 {
            let latch = PublicationDeadlineLatch(deadline: deadline)
            let claims = Claims()
            let result = await withCheckedContinuation { c in
                latch.install(c)
                DispatchQueue.concurrentPerform(iterations: 2) { index in
                    claims.add(index == 0 ? latch.observe(true, at: now) : latch.cancel())
                }
            }
            precondition(claims.value == 1)
            precondition(result == .timely || result == .cancelled)
            precondition(!latch.pending)
        }
        // An already settled latch must cancel a subsequently installed wake.
        let wake = Task<Void, Never> { try? await Task.sleep(for: .seconds(60)) }
        cancelled.installWake(wake)
        precondition(wake.isCancelled)
        await wake.value
        print("PASS deterministic boundary/late/timeout/preinstall cancellation, 100 single-winner races, late wake cancellation")
    }
}
