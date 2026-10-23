import Foundation

/// Typed adapter receipts, not model classifications. Only existing native readers
/// supply these values. Capture ownership/pose is checked again by the controller.
public enum CompanionCapabilityEvidence {
    public enum Value: Sendable {
        case saudiBanknote(Int)
        case isolatedColor(ClothingColor.Name)
        case familiarPerson(String)
        case text(String)
    }
    public static func make(_ value: Value, capturedAt: Date, arabic: Bool) -> CompanionEvidence? {
        let kind: CompanionToolKind
        let text: String
        switch value {
        case .saudiBanknote(let amount):
            guard SaudiBanknotePolicy.denominations.contains(amount) else { return nil }
            kind = .saudiBanknote
            text = arabic ? "الورقة السعودية المقروءة: \(amount) ريال." : "Recognized Saudi note: \(amount) riyals."
        case .isolatedColor(let color):
            kind = .isolatedColor
            text = arabic ? "الغرض المنفصل في اللقطة يبدو \(color.localized(arabic: true)) في هذه الإضاءة." : "The isolated item in this view looks \(color.rawValue) in this lighting."
        case .familiarPerson(let label):
            guard validLabel(label) else { return nil }
            kind = .familiarPeople
            text = arabic ? "قد يكون هذا \(label)." : "I might see \(label)."
        case .text(let content):
            guard let candidate = CapturedViewEvidence.candidate(content, arabic: arabic) else { return nil }
            return CompanionEvidence(kind: .capturedView, text: candidate, source: "bounded on-device captured view",
                observedAt: capturedAt, expiresAt: capturedAt.addingTimeInterval(12))
        }
        return CompanionEvidence(kind: .currentObservation, text: text, source: source(kind),
            observedAt: capturedAt, expiresAt: capturedAt.addingTimeInterval(lifetime(kind)))
    }
    public static func lifetime(_ kind: CompanionToolKind) -> TimeInterval {
        kind == .readText ? 12 : kind == .familiarPeople ? 1.5 : 2
    }
    public static func source(_ kind: CompanionToolKind) -> String { "local verified capability: " + kind.rawValue }
    public static func valid(_ item: CompanionEvidence, for kind: CompanionToolKind, now: Date) -> Bool {
        if kind == .readText { return item.isCapturedViewValid(at: now) }
        guard [.saudiBanknote, .isolatedColor, .familiarPeople].contains(kind),
              item.source == source(kind), item.kind == .currentObservation,
              item.isCurrent(at: now), let at = item.observedAt,
              item.expiresAt == at.addingTimeInterval(lifetime(kind)) else { return false }
        // Reconstruct exact code-owned wording; a source label cannot bless a
        // model's amount, identity, direction or handling instruction.
        switch kind {
        case .saudiBanknote:
            return SaudiBanknotePolicy.denominations.contains { amount in
                [false, true].contains { make(.saudiBanknote(amount), capturedAt: at, arabic: $0)?.text == item.text }
            }
        case .isolatedColor:
            return ClothingColor.Name.allCases.contains { color in
                [false, true].contains { make(.isolatedColor(color), capturedAt: at, arabic: $0)?.text == item.text }
            }
        case .familiarPeople:
            for (prefix, suffix) in [("I might see ", "."), ("قد يكون هذا ", ".")] {
                if item.text.hasPrefix(prefix), item.text.hasSuffix(suffix) {
                    let label = String(item.text.dropFirst(prefix.count).dropLast(suffix.count))
                    if validLabel(label) { return true }
                }
            }
            return false
        default: return false
        }
    }
    private static func validLabel(_ label: String) -> Bool {
        !label.isEmpty && label.count <= 60 && label.unicodeScalars.allSatisfy {
            CharacterSet.letters.contains($0) || CharacterSet.decimalDigits.contains($0) ||
            CharacterSet.nonBaseCharacters.contains($0) || " '-’".unicodeScalars.contains($0)
        }
    }
}
