"""Swift observer text; no production source changes outside disposable instrumentation."""
LOGGER = r'''
// Disposable Apple CI diagnostic only. Never record map bytes, paths or errors.
enum IndoorIOPhaseTrace {
    private struct Event {
        let sequence: Int
        let uptime: TimeInterval
        let main: Bool
        let phase: String
        let token: UUID?
    }
    private static let lock = NSLock()
    private static let capacity = 256
    private static var events = [Event?](repeating: nil, count: capacity)
    private static var count = 0
    private static var dropped = 0
    private static var closed = false
    static func preparing<T>(_ token: UUID, body: () throws -> T) rethrows -> T {
        let dictionary = Thread.current.threadDictionary
        let key = "BlindAssist.diagnostic.io-token"
        let previous = dictionary[key]
        dictionary[key] = token
        defer { if let previous { dictionary[key] = previous } else { dictionary.removeObject(forKey: key) } }
        return try body()
    }
    static func emit(_ phase: String, _ explicitToken: UUID? = nil, at: TimeInterval? = nil) {
        // Capture before recorder contention. Sequence is insertion, NOT event-time order.
        let captured = at ?? ProcessInfo.processInfo.systemUptime
        let main = Thread.isMainThread
        let token = explicitToken ?? (Thread.current.threadDictionary["BlindAssist.diagnostic.io-token"] as? UUID)
        lock.lock()
        defer { lock.unlock() }
        guard !closed else { return }
        guard count < capacity else { if dropped < Int.max { dropped += 1 }; return }
        events[count] = Event(sequence: count + 1, uptime: captured, main: main, phase: phase, token: token)
        count += 1
    }
    static func flushAfterWait() {
        lock.lock()
        guard !closed else { lock.unlock(); return }
        closed = true
        let cutoff = ProcessInfo.processInfo.systemUptime
        let snapshot = events
        let retained = count
        let overflow = dropped
        lock.unlock()
        // Snapshot is closed before output. No output while holding the recorder lock.
        // All events arriving after close are censored, including older delayed records.
        print("INDOOR_IO_BUFFER snapshot=closed cutoff=\(cutoff) retained=\(retained) dropped=\(overflow) capacity=\(capacity) late_events=censored missing_events=inconclusive")
        for event in snapshot.compactMap({ $0 }).sorted(by: {
            $0.uptime == $1.uptime ? $0.sequence < $1.sequence : $0.uptime < $1.uptime
        }) {
            print("INDOOR_IO_PHASE seq=\(event.sequence) uptime=\(event.uptime) main=\(event.main) phase=\(event.phase) token=\(event.token?.uuidString ?? "none")")
        }
        print("INDOOR_IO_BUFFER flush=complete retained=\(retained)")
    }
}
'''
