import Foundation

/// Decides whether an object seen now IS a saved item, from image-comparison distances only
/// (feature prints of the cut-out object against each saved item's views). A language model never
/// makes this decision. Where the object sits in the frame does not matter. A look-alike (a family
/// member's similar cup) must be clearly further away than the best match, or the answer is "similar".
public enum ItemAppearanceMatch {
    public enum Result: Equatable, Sendable {
        /// Clearly this saved item.
        case same(String)
        /// Looks like this item, but another saved item or the threshold leaves real doubt.
        case similar(String)
        case none
    }
    /// Distances are Vision feature-print distances (lower is closer). Calibrate on the iPhone.
    public static let acceptDistance: Float = 0.45
    public static let similarDistance: Float = 0.65
    /// The best match must beat every other saved item by at least this much.
    public static let margin: Float = 0.12

    /// `distances`: for each saved item key, the smallest distance between the seen object and any of
    /// that item's saved views. Non-finite distances are ignored.
    public static func decide(_ distances: [String: Float]) -> Result {
        decide(distances, accept: acceptDistance, similar: similarDistance, margin: margin)
    }

    /// Shared rule with explicit thresholds (people use their own, set for the chosen face model).
    public static func decide(_ distances: [String: Float], accept: Float, similar: Float, margin: Float) -> Result {
        let ranked = distances.filter { $0.value.isFinite && $0.value >= 0 }.sorted { $0.value < $1.value }
        guard let best = ranked.first else { return .none }
        let runnerUp = ranked.dropFirst().first?.value ?? .infinity
        // With nothing else saved there is no look-alike to beat, so an unsaved sibling's cup could
        // pass the margin trivially: require a stricter distance in that case.
        let limit = ranked.count < 2 ? accept * 0.75 : accept
        if best.value <= limit && runnerUp - best.value >= margin { return .same(best.key) }
        if best.value <= similar { return .similar(best.key) }
        return .none
    }
}
