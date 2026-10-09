import Foundation

/// Explicit user goal and a small conversation window. Never contains live pose.
public struct AssistantDialogue: Codable, Sendable {
    public static let maximumTurnScalars = 2000
    public struct Turn: Codable, Sendable {
        public let role: String
        public let text: String
    }
    public private(set) var goal = ""
    public private(set) var goalRevision = UUID().uuidString
    public private(set) var turns: [Turn] = []
    public init() {}
    public mutating func setGoal(_ text: String) {
        goal = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(300))
        goalRevision = UUID().uuidString; turns = []
    }
    public mutating func record(role: String, text: String) {
        // Omit oversized turns instead of silently truncating a negation or qualification.
        guard ["user", "assistant"].contains(role), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              text.unicodeScalars.count <= Self.maximumTurnScalars else { return }
        guard turns.last?.role != role || turns.last?.text != text else { return }
        turns.append(Turn(role: role, text: text)); turns = Array(turns.suffix(6))
    }
    public var valid: Bool {
        goal.count <= 300 && !goalRevision.isEmpty && goalRevision.count <= 64 && turns.count <= 6 &&
        turns.allSatisfy { ["user", "assistant"].contains($0.role) && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.text.unicodeScalars.count <= Self.maximumTurnScalars }
    }
    public var prompt: String {
        guard let data = try? JSONEncoder().encode(self) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }
}
