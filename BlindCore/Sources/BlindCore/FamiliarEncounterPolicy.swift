import Foundation

/// Arrival notification bookkeeping, not a recognizer or a cross-frame face tracker.
/// Only the native, current-frame matcher supplies identities. No location is retained.
public struct FamiliarEncounterPolicy: Sendable {
    private struct Evidence: Sendable {
        var last: Double
        var hits: Int
        var encounter: UUID
    }
    private var evidence: [UUID: Evidence] = [:]
    private var announced: Set<UUID> = []
    private var emptySince: Double?
    private var previousTime: Double?
    public init() {}

    /// Incomplete scans, unknown faces and brief occlusions never reset the latch.
    /// Only ten seconds of repeatedly observed empty camera view starts a new encounter.
    /// Two separate fresh matches reduce chatter; they are not independent accuracy proof.
    public mutating func observe(_ identities: [UUID], detectedFaces: Int, now: Double) -> [UUID] {
        guard now.isFinite, now >= 0, detectedFaces >= 0, identities.count <= min(32, detectedFaces),
              Set(identities).count == identities.count else { invalidateEvidence(); return [] }
        if let previousTime, now <= previousTime { invalidateEvidence(); return [] }
        let continuous = previousTime.map { now - $0 <= 4 } ?? false
        previousTime = now
        if detectedFaces == 0 {
            if !continuous { emptySince = now }
            if emptySince == nil { emptySince = now }
            if let emptySince, now - emptySince >= 10 { evidence = [:]; announced = [] }
            return []
        }
        emptySince = nil
        for identity in identities {
            if let old = evidence[identity], now - old.last <= 30 {
                evidence[identity] = Evidence(last: now, hits: min(2, old.hits + 1), encounter: old.encounter)
            } else {
                evidence[identity] = Evidence(last: now, hits: 1, encounter: UUID())
            }
        }
        return identities.filter { !announced.contains($0) && evidence[$0]?.hits == 2 }
    }
    public func encounterID(for identity: UUID) -> UUID? { evidence[identity]?.encounter }
    /// Mark only speech admitted by the caller's attention gate, never merely proposed.
    public mutating func markAnnounced(_ identity: UUID) {
        guard evidence[identity]?.hits == 2 else { return }
        announced.insert(identity)
    }
    /// Motion, hazards and camera gaps revoke evidence, not previously delivered notices.
    public mutating func invalidateEvidence() { evidence = [:]; emptySince = nil; previousTime = nil }
    public mutating func reset() { self = Self() }
}

/// Conservative bookkeeping for a single frame. No nearest-face fallback or identity
/// propagation through anonymous body tracks. Duplicate identity assignments abstain.
public enum FamiliarFaceBatchPolicy {
    public static func uniqueCandidates(_ candidates: [UUID?]) -> [UUID?] {
        guard candidates.count <= 32 else { return Array(repeating: nil, count: candidates.count) }
        let counts = candidates.compactMap { $0 }.reduce(into: [UUID: Int]()) { $0[$1, default: 0] += 1 }
        return candidates.map { candidate in candidate.flatMap { counts[$0] == 1 ? $0 : nil } }
    }
    public static func validBounds(x: Double, y: Double, width: Double, height: Double) -> Bool {
        [x, y, width, height].allSatisfy(\.isFinite) && x >= 0 && y >= 0 && width > 0 && height > 0 &&
            x + width <= 1 && y + height <= 1
    }
}
