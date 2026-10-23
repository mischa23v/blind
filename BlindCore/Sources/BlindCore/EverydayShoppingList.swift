import Foundation

/// Explicit user speech only. A scene caption or model-generated plan is not a
/// shopping-list instruction and must never be passed to this parser as user input.
public enum EverydayShoppingCommand: Equatable, Sendable {
    case add(String), remove(String), list
    public static func parse(_ text: String) -> Self? {
        guard let bounded = EverydayTaskRequest(capability: .savedMemory, query: text) else { return nil }
        let value = bounded.query.trimmingCharacters(in: .punctuationCharacters)
        let lower = value.lowercased()
        if ["what is on my shopping list", "what's on my shopping list", "read my shopping list", "show my shopping list", "what do i need to buy", "ما في قائمة التسوق", "ما هي قائمة التسوق", "اقرأ قائمة التسوق", "اقرا قائمة التسوق", "اعرض قائمة التسوق"].contains(lower) { return .list }
        for (prefix, suffix, adding) in [("add ", " to my shopping list", true), ("remove ", " from my shopping list", false),
                                         ("أضف ", " إلى قائمة التسوق", true), ("اضف ", " إلى قائمة التسوق", true),
                                         ("أضف ", " الى قائمة التسوق", true), ("اضف ", " الى قائمة التسوق", true),
                                         ("احذف ", " من قائمة التسوق", false), ("أزل ", " من قائمة التسوق", false),
                                         ("ازل ", " من قائمة التسوق", false)] {
            guard lower.hasPrefix(prefix), lower.hasSuffix(suffix), value.count > prefix.count + suffix.count else { continue }
            let item = String(value.dropFirst(prefix.count).dropLast(suffix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !item.isEmpty, item.count <= 80 else { return nil }
            return adding ? .add(item) : .remove(item)
        }
        return nil
    }
}

/// A list is a record of what the user requested, not proof of stock, possession,
/// purchase, product identity or location. Store locally under the existing app
/// memory policy. Explicit removal is supported; no observation marks items done.
public struct EverydayShoppingList: Codable, Equatable, Sendable {
    public struct Entry: Codable, Equatable, Sendable {
        public let item: String
        public let sourceQuote: String
        public let recordedAt: Double
    }
    public static let maximumEntries = 40
    public private(set) var entries: [Entry] = []
    public init() {}
    /// Reparse the original user quote so an inferred/generated command cannot
    /// accidentally be paired with unrelated provenance. Invalid clocks rejected.
    @discardableResult
    public mutating func apply(_ command: EverydayShoppingCommand, userQuote: String, now: Double) -> Bool {
        guard now.isFinite, now >= 0, EverydayShoppingCommand.parse(userQuote) == command else { return false }
        switch command {
        case .list: return true
        case .add(let item):
            guard !entries.contains(where: { Self.key($0.item) == Self.key(item) }), entries.count < Self.maximumEntries else { return false }
            entries.append(Entry(item: item, sourceQuote: userQuote, recordedAt: now))
            return true
        case .remove(let item):
            guard let index = entries.firstIndex(where: { Self.key($0.item) == Self.key(item) }) else { return false }
            entries.remove(at: index)
            return true
        }
    }
    private static func key(_ item: String) -> String { item.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
    private enum CodingKeys: String, CodingKey { case entries }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decoded = try container.decode([Entry].self, forKey: .entries)
        var validated = Self()
        guard decoded.count <= Self.maximumEntries else { throw DecodingError.dataCorruptedError(forKey: .entries, in: container, debugDescription: "Shopping list exceeds bound") }
        for entry in decoded {
            guard validated.apply(.add(entry.item), userQuote: entry.sourceQuote, now: entry.recordedAt) else {
                throw DecodingError.dataCorruptedError(forKey: .entries, in: container, debugDescription: "Invalid or duplicate attributed shopping entry")
            }
        }
        self = validated
    }
}
