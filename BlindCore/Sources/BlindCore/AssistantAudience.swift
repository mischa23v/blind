import Foundation

/// An explicitly selected, local communication preference, not an age profile.
/// It grants no permissions and does not alter any domain or evidence gate.
/// In particular, `childWithGuardian` never establishes guardian presence,
/// consent, suitability for independent use, or child-safety certification.
public enum AssistantAudience: String, CaseIterable, Codable, Identifiable, Sendable {
    case general
    case adult
    case childWithGuardian

    public static let defaultValue: Self = .general
    public var id: String { rawValue }

    /// Restore only exact, explicitly supported values. Missing, stale or
    /// malformed preferences cannot silently opt someone into adult mode.
    public init(persistedValue: String?) {
        self = persistedValue.flatMap(Self.init(rawValue:)) ?? Self.defaultValue
    }

    public init(from decoder: Decoder) throws {
        let value = try? decoder.singleValueContainer().decode(String.self)
        self.init(persistedValue: value)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var title: String {
        switch self {
        case .general: return "General"
        case .adult: return "Adult"
        case .childWithGuardian: return "Child with adult support"
        }
    }

    public static let selectionNotice = "This is a local communication preference, not verified age, proof that a guardian is present, or child-safety certification. Safety checks stay the same."

    public var detail: String {
        let explanation: String
        switch self {
        case .general:
            explanation = "Clear, broadly age-appropriate answers without assuming an age."
        case .adult:
            explanation = "Adult-oriented explanations, selected explicitly rather than inferred."
        case .childWithGuardian:
            explanation = "Simple, age-appropriate explanations. Encourages help from a trusted adult for important decisions or real-world safety."
        }
        return explanation + " " + Self.selectionNotice
    }

    /// A bounded prompt addition, not a content classifier or an enforcement
    /// mechanism. Existing code-owned safety gates still run independently.
    /// Keep it separate from user text and never derive the mode from a model.
    public var modelInstructions: String {
        let mode: String
        switch self {
        case .general:
            mode = "General mode: age is unknown. Use broadly age-appropriate language and adapt explanations to the request without assuming an age."
        case .adult:
            mode = "Adult mode is explicitly selected, not age verification. Use adult-oriented explanations; this grants no extra permissions and does not relax safety."
        case .childWithGuardian:
            mode = "Child-support mode is explicitly selected. Use simple, age-appropriate language without baby talk. Encourage help from a trusted adult for high-stakes decisions or real-world safety. The assistant does not replace adult supervision."
        }
        return """
        \(mode)
        Never infer age from appearance, voice or wording, or request a date of birth. Be respectful, not patronizing. Keep all sensor-evidence, domain, consent and privacy gates unchanged. Never claim a guardian is present or that child safety is certified. Do not encourage secrecy from trusted people, exclusivity or emotional dependence, or pressure the user to keep talking.
        """
    }
}
