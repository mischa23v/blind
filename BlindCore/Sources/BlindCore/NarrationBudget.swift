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
    /// Earliest release from the actual rolling ledger, not an estimated reading
    /// duration. Does not reserve or charge words; admission must check again.
    public mutating func nextAvailableAt(words: Int, limit: Int, now: Double) -> Double? {
        guard now.isFinite, now >= latest, words > 0, words <= limit else { return nil }
        if words <= allowance(limit: limit, now: now) { return now }
        // A lower user limit can leave existing charges above the new limit.
        // Keep that debt rather than starting from the clamped zero allowance.
        var available = limit - dispatched.reduce(0) { $0 + $1.words }
        for item in dispatched {
            available += item.words
            if words <= available {
                let release = item.at + 60
                return release.isFinite && release >= now ? release : nil
            }
        }
        return nil
    }
    @discardableResult public mutating func charge(words: Int, limit: Int, now: Double) -> Bool {
        guard words > 0, words <= allowance(limit: limit, now: now) else { return false }
        dispatched.append((now, words)); return true
    }
}
