import Foundation

/// A bounded retained REQUEST, not a cached detection, frame, position or search
/// result. Explicit resume creates one new bounded search only after fresh view
/// admission and native resource availability. Never auto-starts sensing.
public struct HeldSearchIntent: Sendable {
    public private(set) var held = false
    private var target: String?
    private var goalRevision: String?
    private var resumeRequested = false
    public var hasIntent: Bool { target != nil }
    public init() {}
    @discardableResult
    public mutating func hold(target supplied: String?, goalRevision: String, origin: CompanionCommandOrigin) -> Bool {
        guard CommandAuthority.permits(.changeGoal, from: origin) else { return false }
        held = true; resumeRequested = false
        if self.goalRevision != goalRevision { target = nil }
        self.goalRevision = goalRevision
        if let supplied {
            let cleaned = supplied.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleaned.isEmpty, cleaned.utf8.count <= 200 { target = cleaned }
        }
        return true
    }
    @discardableResult
    public mutating func resume(origin: CompanionCommandOrigin) -> Bool {
        guard CommandAuthority.permits(.changeGoal, from: origin) else { return false }
        held = false; resumeRequested = true; return true
    }
    public mutating func takeForFreshSearch(goalRevision current: String, freshViewAvailable: Bool,
                                           nativeResourceIdle: Bool) -> String? {
        guard goalRevision == current else { cancel(); return nil }
        guard !held, resumeRequested, freshViewAvailable, nativeResourceIdle, let target else { return nil }
        cancel(); return target
    }
    public mutating func cancel() { held = false; resumeRequested = false; target = nil; goalRevision = nil }
}
