import Foundation

/// Bounded novelty bookkeeping for automatic scene descriptions only. This is
/// exact normalized observation comparison, NOT semantic inference or evidence
/// of absence, identity, scene equivalence, or safe movement. No generated answer
/// participates. Requested answers, repeats and hazards use their existing lanes.
public struct PassiveSceneDelivery: Sendable {
    public struct Signature: Equatable, Sendable {
        fileprivate let entries: [String]
    }
    private var owner: String?
    private var completed: Signature?
    private var pending: (id: UUID, signature: Signature)?
    public init() {}

    /// Call with already freshness/quality-filtered observations and the existing
    /// multi-frame detector agreement. Reject oversized inputs, never truncate a
    /// changed suffix into an apparently unchanged observation.
    public static func signature(observations: [SceneObservation], confirmedObjects: [String]) -> Signature? {
        guard observations.count <= 32, confirmedObjects.count <= 128 else { return nil }
        func normalized(_ value: String) -> String? {
            guard value.utf8.count <= 2048 else { return nil }
            return value.precomposedStringWithCanonicalMapping.lowercased()
                .split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        }
        var entries = Set<String>()
        for observation in observations {
            // Range measurements retain their independent warning/physical lanes.
            guard observation.kind != .range else { continue }
            guard let text = normalized(observation.text) else { return nil }
            if !text.isEmpty { entries.insert(observation.kind.rawValue + ":" + text) }
        }
        for label in confirmedObjects {
            guard let text = normalized(label) else { return nil }
            if !text.isEmpty { entries.insert("confirmed-object:" + text) }
        }
        guard !entries.isEmpty else { return nil }
        return Signature(entries: entries.sorted())
    }

    /// Source/session/room ownership is separate from content novelty. A new
    /// capture ID or timestamp must never be supplied as a new content signature.
    public mutating func allows(_ signature: Signature, owner currentOwner: String) -> Bool {
        guard !currentOwner.isEmpty, currentOwner.utf8.count <= 2048 else { return false }
        synchronize(currentOwner)
        return pending == nil && completed != signature
    }
    public mutating func begin(id: UUID, signature: Signature, owner currentOwner: String) -> Bool {
        guard allows(signature, owner: currentOwner) else { return false }
        pending = (id, signature)
        return true
    }
    /// Only an exact completed playback commits novelty. Old callbacks cannot
    /// consume a successor or restore a previous source's content.
    @discardableResult public mutating func finish(id: UUID, completed didComplete: Bool, currentOwner: String) -> Bool {
        guard let item = pending, item.id == id else { return false }
        pending = nil
        guard owner == currentOwner else { synchronize(currentOwner); return true }
        if didComplete { completed = item.signature }
        return true
    }
    @discardableResult public mutating func cancelPending() -> UUID? {
        defer { pending = nil }
        return pending?.id
    }
    private mutating func synchronize(_ currentOwner: String) {
        if owner != currentOwner { owner = currentOwner; completed = nil; pending = nil }
    }
}
