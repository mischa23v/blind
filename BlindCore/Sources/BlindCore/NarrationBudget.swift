import Foundation

/// Word accounting only; platform speech rate remains under the user's control.
/// Urgent and necessary mobility cues use their independent feedback path.
public struct NarrationBudget: Sendable {
    private var dispatched: [(at: Double, words: Int)] = []
    private var latest = -Double.infinity
    public init() {}
    public mutating func allowance(limit: Int, now: Double) -> Int {
        guard now.isFinite, now >= latest, limit > 0 else { return 0 }
        latest = now; dispatched.removeAll { now - $0.at >= 60 }
        return max(0, limit - dispatched.reduce(0) { $0 + $1.words })
    }
    @discardableResult public mutating func charge(words: Int, limit: Int, now: Double) -> Bool {
        guard words > 0, words <= allowance(limit: limit, now: now) else { return false }
        dispatched.append((now, words)); return true
    }
}
