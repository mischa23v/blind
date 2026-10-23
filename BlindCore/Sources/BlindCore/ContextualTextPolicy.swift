import Foundation

/// Selects a short observed line relevant to an already retained user task. This is
/// text evidence, never proof of a shop's location, availability or safe route.
public enum ContextualTextPolicy {
    private static let ignored: Set<String> = ["i", "my", "me", "we", "our", "want", "need", "find", "locate", "looking", "help", "with", "this", "that", "where", "some", "please", "shopping", "read", "reading", "buy", "get", "the", "and", "for", "go", "going", "visit", "take", "to", "a", "an", "at", "in", "of", "is", "it", "am", "are", "can", "you", "let", "lets", "اريد", "ساعدني", "اين", "ابحث", "اجد", "الي", "عن", "هذا", "هذه", "في", "من", "اذهب"]
    public static func tokens(_ text: String) -> [String] {
        SpatialClaimGuard.normalizeArabic(text.lowercased()).components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }.map { word in
                word.hasPrefix("ال") && word.count > 3 ? String(word.dropFirst(2)) : word
            }
    }
    public static func targetWords(_ goal: String) -> Set<String> {
        guard goal.count <= 1_200 else { return [] }
        return Set(tokens(goal).filter { $0.count >= 3 && !ignored.contains($0) })
    }
    public static func supportsTargetDiscovery(_ goal: String) -> Bool {
        let words = Set(tokens(goal))
        let taskWords: Set<String> = ["find", "locate", "looking", "go", "going", "visit", "store", "shop", "mall", "ابحث", "اجد", "اذهب", "متجر", "مول"]
        return !words.isDisjoint(with: taskWords) && !targetWords(goal).isEmpty
    }
    public static func select(_ lines: [TextLine], goalText: String,
                              unrestrictedReading: Bool) -> TextLine? {
        let targets = targetWords(goalText)
        return lines.filter { line in
            guard line.confidence.isFinite, line.confidence >= 0.85, line.confidence <= 1,
                  line.x.isFinite, line.y.isFinite, (0...1).contains(line.x), (0...1).contains(line.y),
                  !line.text.isEmpty, line.text.count <= 100,
                  !SaudiBanknotePolicy.containsUnverifiedMoneyValue(line.text),
                  !SpatialClaimGuard.containsSpatialClaim(line.text), !SpatialClaimGuard.mentionsHazard(line.text) else { return false }
            // Token equality avoids “milk” matching “milkshake” and “art” matching “pharmacy”.
            return unrestrictedReading || !targets.isDisjoint(with: Set(tokens(line.text)))
        }.sorted { $0.y == $1.y ? $0.x < $1.x : $0.y < $1.y }.first
    }
}

/// AR frame timestamps and system uptime share a monotonic clock. Callback arrival
/// must never replace capture time or resurrect delayed images as fresh evidence.
public enum FrameTimestampPolicy {
    public static func isFresh(capturedAt: Double, receivedAt: Double) -> Bool {
        capturedAt.isFinite && receivedAt.isFinite && capturedAt >= 0 &&
            receivedAt >= capturedAt && receivedAt - capturedAt <= 0.5
    }
}
