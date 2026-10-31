import Foundation

/// A deliberate, finite request to reacquire current native anchor values. The
/// producer supplies UUIDs from fresh frame callbacks and performs the copy there.
/// This value retains no ARFrame, anchor, Metal buffer, geometry or closure.
/// Admission means queued delivery only: it does not mean installation, current
/// obstacles/support, source completeness, capture freshness or physical clearance.
struct MeshBenchReacquisition {
    enum State: String { case idle, active, finished, timedOut, cancelled, rejected, invalidClock, invalidSequence }
    enum RejectionReason: String { case tooManyAnchors, duplicateAnchorIdentity, tooManyFrameAnchors }
    enum PendingReason: String {
        case notYetAttempted, absentFromLatestFrame, admissionRejected, admissionUnconfirmed, inFlight, attemptsExhausted, admitted
    }
    struct AnchorReceipt {
        let id: UUID
        let attempts: Int
        let reason: PendingReason
    }
    struct Receipt {
        let state: State
        let anchors: [AnchorReceipt]
        let totalAttempts: Int
        let inputAnchorCount: Int
        let rejectionReason: RejectionReason?
        let rejectedCount: Int?
        let beganAt: Double?
        let deadline: Double?
        let authorizesPhysicalGuidance = false
        let actualWorldCoverageKnown = false
        let meshCapturedAt: Double? = nil
        var pendingIDs: [UUID] { anchors.filter { $0.reason != .admitted }.map(\.id) }
        var admittedIDs: [UUID] { anchors.filter { $0.reason == .admitted }.map(\.id) }
        var status: State { state }
        var requested: Int { anchors.count }
        var admitted: Int { admittedIDs.count }
        var pending: Int { pendingIDs.count }
        var exhausted: Int { anchors.filter { $0.reason == .attemptsExhausted }.count }
    }
    static let maximumAnchors = 64
    static let maximumAttemptsPerAnchor = 3
    static let maximumAttempts = 192
    static let duration: Double = 8
    private struct Entry {
        let id: UUID
        var attempts = 0
        var admitted = false
        var rejected = false
        var present = true
    }
    private(set) var state: State = .idle
    var isActive: Bool { state == .active }
    private var entries: [Entry] = []
    private var inFlight: UUID?
    private var cursor = 0
    private var totalAttempts = 0
    private var inputAnchorCount = 0
    private var rejectionReason: RejectionReason?
    private var rejectedCount: Int?
    private var beganAt: Double?
    private var lastClock: Double?
    private var lastFrameCapture: Double?

    /// A second request never replaces active work. Input overflow/duplicates are
    /// rejected as a whole before UUID allocation; no partial coverage is invented.
    @discardableResult mutating func request(anchorIDs: [UUID], frameCapturedAt: Double, now: Double) -> Bool {
        guard state != .active else { return false }
        entries.removeAll(keepingCapacity: false); inFlight = nil; cursor = 0; totalAttempts = 0
        beganAt = nil; lastClock = nil; lastFrameCapture = nil
        inputAnchorCount = anchorIDs.count; rejectionReason = nil; rejectedCount = nil
        guard anchorIDs.count <= Self.maximumAnchors else {
            rejectionReason = .tooManyAnchors; rejectedCount = anchorIDs.count; state = .rejected; return false
        }
        guard Set(anchorIDs).count == anchorIDs.count else {
            rejectionReason = .duplicateAnchorIdentity; rejectedCount = anchorIDs.count; state = .rejected; return false
        }
        guard validFrame(frameCapturedAt, now: now) else { state = .invalidClock; return false }
        entries = anchorIDs.map { Entry(id: $0) }
        beganAt = now; lastClock = now; lastFrameCapture = frameCapturedAt
        state = entries.isEmpty ? .finished : .active
        return true
    }

    /// Exactly one attempt can be issued per strictly newer fresh frame. Missing
    /// IDs remain unresolved; absence is not a removal, tombstone or free space.
    mutating func next(presentIDs: Set<UUID>, frameCapturedAt: Double, now: Double) -> UUID? {
        guard advance(now: now) else { return nil }
        guard presentIDs.count <= 128 else {
            rejectionReason = .tooManyFrameAnchors; rejectedCount = presentIDs.count; finish(.rejected); return nil
        }
        guard validFrame(frameCapturedAt, now: now) else { finish(.invalidClock); return nil }
        guard let previousFrame = lastFrameCapture, frameCapturedAt >= previousFrame else {
            finish(.invalidClock); return nil
        }
        guard frameCapturedAt > previousFrame else { return nil }
        lastFrameCapture = frameCapturedAt
        guard inFlight == nil else { finish(.invalidSequence); return nil }
        for index in entries.indices { entries[index].present = presentIDs.contains(entries[index].id) }
        guard totalAttempts < Self.maximumAttempts else { finish(.finished); return nil }
        for offset in 0..<entries.count {
            let index = (cursor + offset) % entries.count
            guard !entries[index].admitted, entries[index].attempts < Self.maximumAttemptsPerAnchor,
                  entries[index].present else { continue }
            entries[index].attempts += 1; entries[index].rejected = false; totalAttempts += 1
            cursor = (index + 1) % entries.count; inFlight = entries[index].id
            return entries[index].id
        }
        settleIfFinished()
        return nil
    }

    /// Must follow the synchronous attempt, even on ingress backpressure. A true
    /// result suppresses duplicate retries only; snapshot receipts verify install.
    mutating func recordAdmission(anchorID: UUID, accepted: Bool, now: Double) {
        guard advance(now: now) else { return }
        guard inFlight == anchorID, let index = entries.firstIndex(where: { $0.id == anchorID }) else {
            finish(.invalidSequence); return
        }
        entries[index].admitted = accepted; entries[index].rejected = !accepted; inFlight = nil
        settleIfFinished()
    }
    mutating func cancel() { if state == .active { finish(.cancelled) } }
    mutating func receipt(now: Double) -> Receipt {
        _ = advance(now: now)
        return Receipt(state: state, anchors: entries.map { entry in
            let reason: PendingReason
            if entry.admitted { reason = .admitted }
            else if inFlight == entry.id { reason = .inFlight }
            else if entry.attempts == Self.maximumAttemptsPerAnchor { reason = .attemptsExhausted }
            else if !entry.present { reason = .absentFromLatestFrame }
            else if entry.rejected { reason = .admissionRejected }
            else if entry.attempts > 0 { reason = .admissionUnconfirmed }
            else { reason = .notYetAttempted }
            return AnchorReceipt(id: entry.id, attempts: entry.attempts, reason: reason)
        }, totalAttempts: totalAttempts, inputAnchorCount: inputAnchorCount, rejectionReason: rejectionReason,
            rejectedCount: rejectedCount, beganAt: beganAt, deadline: beganAt.map { $0 + Self.duration })
    }
    private func validFrame(_ capturedAt: Double, now: Double) -> Bool {
        capturedAt.isFinite && now.isFinite && capturedAt >= 0 && now >= capturedAt && now - capturedAt <= 0.5
            && (now + Self.duration).isFinite && now + Self.duration > now
    }
    private mutating func advance(now: Double) -> Bool {
        guard state == .active else { return false }
        guard now.isFinite, let lastClock, now >= lastClock, let beganAt else {
            finish(.invalidClock); return false
        }
        self.lastClock = now
        guard now - beganAt < Self.duration else { finish(.timedOut); return false }
        return true
    }
    private mutating func settleIfFinished() {
        if inFlight == nil && entries.allSatisfy({ $0.admitted || $0.attempts >= Self.maximumAttemptsPerAnchor }) {
            finish(.finished)
        }
    }
    private mutating func finish(_ state: State) { self.state = state; inFlight = nil }
}
