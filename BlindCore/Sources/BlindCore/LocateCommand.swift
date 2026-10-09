import Foundation

/// "Where is the exit sign?" — a live search of the current view (E14 fast path). Saved items
/// ("where is my braille book?") are handled by ItemCommand first; this covers everything else.
/// Whole utterance only, like AssistantControl.
public enum LocateCommand {
    public static func target(_ text: String) -> String? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        let lower = value.lowercased()
        for prefix in ["where is the ", "where's the ", "where are the ", "where is a ", "find the ", "find a ", "find "] where lower.hasPrefix(prefix) {
            return bounded(String(value.dropFirst(prefix.count)))
        }
        let arabic = value.replacingOccurrences(of: "أ", with: "ا").replacingOccurrences(of: "إ", with: "ا")
        for prefix in ["اين ", "وين ", "ابحث عن ", "دور على "] where arabic.hasPrefix(prefix) {
            return bounded(String(arabic.dropFirst(prefix.count)))
        }
        return nil
    }

    private static func bounded(_ target: String) -> String? {
        let trimmed = target.trimmingCharacters(in: .whitespacesAndNewlines)
        // A long remainder is a question about something else, not a search target.
        guard !trimmed.isEmpty, trimmed.count <= 40, trimmed.split(separator: " ").count <= 4 else { return nil }
        return trimmed
    }

    /// Case- and diacritic-insensitive word match between the target and a detected label or sign text.
    public static func matches(target: String, label: String) -> Bool {
        let fold = { (text: String) in text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX")) }
        let wanted = fold(target), found = fold(label)
        guard !wanted.isEmpty, !found.isEmpty else { return false }
        return found.contains(wanted) || wanted.split(separator: " ").allSatisfy { found.contains($0) }
    }
}
