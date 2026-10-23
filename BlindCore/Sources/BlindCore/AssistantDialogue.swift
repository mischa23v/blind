import Foundation

/// Bounded, reviewable conversational evidence. These are historical user reports,
/// never a restored live pose, observation, or model-authored fact/profile.
public struct AssistantDialogue: Codable, Sendable {
    public static let maximumTurnScalars = 2000
    public static let maximumRecentScalars = 6000
    public static let maximumUserRecords = 32
    public static let maximumMemoryScalars = 16000
    public static let maximumRetrievedScalars = 3000

    public struct Turn: Codable, Sendable, Equatable {
        public let role: String
        public let text: String
        public init(role: String, text: String) { self.role = role; self.text = text }
    }
    public struct UserRecord: Codable, Sendable, Equatable, Identifiable {
        public let id: String
        public let text: String
        public init(id: String = UUID().uuidString, text: String) { self.id = id; self.text = text }
    }
    public private(set) var goal = ""
    public private(set) var goalRevision = UUID().uuidString
    public private(set) var turns: [Turn] = []
    /// Oldest first. Original user words only; saved names/preferences live elsewhere.
    public private(set) var userRecords: [UserRecord] = []
    public init() {}

    public mutating func setGoal(_ text: String) {
        let proposed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Never truncate away a qualification/negation to fit a goal.
        guard proposed.unicodeScalars.count <= 300 else { return }
        goal = proposed
        goalRevision = UUID().uuidString
        // A new task invalidates pending work, not the person's conversation.
    }

    /// For assistant turns, the caller must supply only completed/delivered text.
    /// Generated but cancelled, queued, or interrupted text is not conversation history.
    public mutating func record(role: String, text: String) {
        guard Self.validTurn(role: role, text: text) else { return }
        guard turns.last?.role != role || turns.last?.text != text else { return }
        turns.append(Turn(role: role, text: text))
        trimRecent()
        if role == "user" {
            userRecords.append(UserRecord(text: text))
            trimMemory()
        }
    }

    /// Retrieval is deliberately small and lexical, not an invented LLM summary.
    /// It returns complete, original reports, oldest first; callers must label them
    /// historical and exclude them from current sensor/location claims.
    public func relevantUserReports(for query: String, maxScalars: Int = maximumRetrievedScalars) -> [UserRecord] {
        let budget = min(max(0, maxScalars), Self.maximumRetrievedScalars)
        guard budget > 0 else { return [] }
        let terms = Self.terms(query)
        let candidates = userRecords.enumerated().filter { $0.element.text != query }
        let recentIDs = Set(candidates.suffix(2).map { $0.element.id })
        let ranked = candidates.compactMap { entry -> (Int, UserRecord, Int)? in
            let score = terms.intersection(Self.terms(entry.element.text)).count
            guard score > 0 || recentIDs.contains(entry.element.id) else { return nil }
            return (entry.offset, entry.element, score)
        }.sorted {
            if $0.2 != $1.2 { return $0.2 > $1.2 }
            return $0.0 > $1.0
        }
        var selected: [(Int, UserRecord)] = []
        var used = 0
        for entry in ranked {
            let cost = entry.1.text.unicodeScalars.count
            guard used + cost <= budget else { continue }
            selected.append((entry.0, entry.1)); used += cost
        }
        return selected.sorted { $0.0 < $1.0 }.map { $0.1 }
    }

    /// An explicit, user-reviewed correction. Do not call from model inference.
    /// Drops old copies and derived assistant replies so the correction cannot be
    /// contradicted by stale prompt examples. The corrected record moves to newest.
    @discardableResult
    public mutating func correctUserRecord(id: String, replacement: String) -> Bool {
        guard Self.validTurn(role: "user", text: replacement),
              let index = userRecords.firstIndex(where: { $0.id == id }) else { return false }
        let previous = userRecords.remove(at: index)
        userRecords.removeAll { $0.text == previous.text }
        userRecords.append(UserRecord(id: id, text: replacement))
        if goal == previous.text.trimmingCharacters(in: .whitespacesAndNewlines) {
            let correctedGoal = replacement.trimmingCharacters(in: .whitespacesAndNewlines)
            goal = correctedGoal.unicodeScalars.count <= 300 ? correctedGoal : ""
        }
        turns.removeAll { $0.role == "assistant" || $0.text == previous.text }
        turns.append(Turn(role: "user", text: replacement))
        trimRecent(); trimMemory(); goalRevision = UUID().uuidString
        return true
    }

    /// Forget exact source and duplicate copies, including dependent model replies.
    @discardableResult
    public mutating func forgetUserRecord(id: String) -> Bool {
        guard let record = userRecords.first(where: { $0.id == id }) else { return false }
        userRecords.removeAll { $0.text == record.text }
        turns.removeAll { $0.role == "assistant" || $0.text == record.text }
        if goal == record.text.trimmingCharacters(in: .whitespacesAndNewlines) { goal = "" }
        goalRevision = UUID().uuidString
        return true
    }

    /// Clears this conversation/goal only; does not erase separately saved profile.
    public mutating func forgetConversation() { self = AssistantDialogue() }

    public var valid: Bool {
        goal.unicodeScalars.count <= 300 && !goalRevision.isEmpty && goalRevision.count <= 64 &&
        turns.count <= 6 && turns.allSatisfy { Self.validTurn(role: $0.role, text: $0.text) } &&
        turns.reduce(0) { $0 + $1.text.unicodeScalars.count } <= Self.maximumRecentScalars &&
        userRecords.count <= Self.maximumUserRecords && Set(userRecords.map(\.id)).count == userRecords.count &&
        userRecords.allSatisfy { !$0.id.isEmpty && $0.id.count <= 64 && Self.validTurn(role: "user", text: $0.text) } &&
        userRecords.reduce(0) { $0 + $1.text.unicodeScalars.count } <= Self.maximumMemoryScalars
    }

    /// Legacy wire shape: never send the durable archive as an unbounded prompt.
    public var prompt: String {
        struct Snapshot: Encodable { let goal: String; let goalRevision: String; let turns: [Turn] }
        guard let data = try? JSONEncoder().encode(Snapshot(goal: goal, goalRevision: goalRevision, turns: turns)) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    private enum CodingKeys: String, CodingKey { case goal, goalRevision, turns, userRecords }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        goal = try values.decodeIfPresent(String.self, forKey: .goal) ?? ""
        goalRevision = try values.decodeIfPresent(String.self, forKey: .goalRevision) ?? UUID().uuidString
        turns = try values.decodeIfPresent([Turn].self, forKey: .turns) ?? []
        userRecords = try values.decodeIfPresent([UserRecord].self, forKey: .userRecords)
            ?? turns.filter { $0.role == "user" }.map { UserRecord(text: $0.text) }
        // Old six-turn records could exceed today's aggregate prompt allowance.
        // Preserve their complete user sources in memory, then trim whole turns.
        guard goal.unicodeScalars.count <= 300, !goalRevision.isEmpty, goalRevision.count <= 64,
              turns.count <= 6, turns.allSatisfy({ Self.validTurn(role: $0.role, text: $0.text) }),
              userRecords.count <= Self.maximumUserRecords,
              userRecords.allSatisfy({ !$0.id.isEmpty && $0.id.count <= 64 && Self.validTurn(role: "user", text: $0.text) }),
              Set(userRecords.map(\.id)).count == userRecords.count else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid bounded conversation"))
        }
        trimRecent(); trimMemory()
    }

    private static func validTurn(role: String, text: String) -> Bool {
        ["user", "assistant"].contains(role) && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        text.unicodeScalars.count <= maximumTurnScalars
    }
    private mutating func trimRecent() {
        while turns.count > 6 || turns.reduce(0, { $0 + $1.text.unicodeScalars.count }) > Self.maximumRecentScalars { turns.removeFirst() }
    }
    private mutating func trimMemory() {
        while userRecords.count > Self.maximumUserRecords || userRecords.reduce(0, { $0 + $1.text.unicodeScalars.count }) > Self.maximumMemoryScalars { userRecords.removeFirst() }
    }
    private static func terms(_ text: String) -> Set<String> {
        let common: Set<String> = ["a", "an", "and", "are", "as", "at", "be", "but", "can", "could", "did", "do", "for", "from", "had", "has", "have", "how", "i", "in", "is", "it", "me", "my", "of", "on", "or", "please", "that", "the", "their", "there", "this", "to", "was", "were", "what", "when", "where", "which", "who", "with", "would", "you", "your"]
        return Set(text.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)).subtracting(common)
    }
}
