import Foundation

public struct AssistantInterest: Codable, Identifiable, Sendable {
    public let id: String
    public let category: String
    public let value: String
    public let source: String
    public init(category: String, value: String) {
        id = UUID().uuidString; self.category = category
        self.value = value.trimmingCharacters(in: .whitespacesAndNewlines); source = "user"
    }
}
public struct AssistantPreferences: Codable, Sendable {
    public private(set) var interests: [AssistantInterest] = []
    public static let categories = ["social", "signs", "objects", "decor", "interests"]
    public static let modes = ["automatic", "onRequest", "muted"]
    public private(set) var categoryModes: [String: String] = [:]
    private enum CodingKeys: String, CodingKey { case interests, categoryModes }
    public init() {}
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        interests = try values.decodeIfPresent([AssistantInterest].self, forKey: .interests) ?? []
        categoryModes = try values.decodeIfPresent([String: String].self, forKey: .categoryModes) ?? [:]
    }
    public func mode(for category: String) -> String { categoryModes[category] ?? "automatic" }
    public var automaticCategories: [String] { Self.categories.filter { mode(for: $0) == "automatic" } }
    @discardableResult public mutating func setMode(_ mode: String, for category: String) -> Bool {
        guard Self.categories.contains(category), Self.modes.contains(mode) else { return false }
        categoryModes[category] = mode; return true
    }
    public var valid: Bool {
        categoryModes.allSatisfy { Self.categories.contains($0.key) && Self.modes.contains($0.value) } &&
        interests.count <= 16 && Set(interests.map(\.id)).count == interests.count && interests.allSatisfy {
            !$0.id.isEmpty && $0.id.count <= 64 && $0.source == "user" &&
            ["interest", "shopping", "food", "description"].contains($0.category) &&
            !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.value.unicodeScalars.count <= 300
        }
    }
    @discardableResult public mutating func add(category: String, value: String) -> Bool {
        let interest = AssistantInterest(category: category, value: value)
        guard interests.count < 16, !interests.contains(where: { $0.category == category && $0.value.caseInsensitiveCompare(interest.value) == .orderedSame }) else { return false }
        let old = interests; interests.append(interest)
        guard valid else { interests = old; return false }; return true
    }
    public mutating func remove(id: String) { interests.removeAll { $0.id == id } }
}
