import Foundation

/// Explicit review of the one volatile captured page, never a new camera request.
/// Parsing is not permission: the native adapter must enforce trusted input and
/// current session/private-output ownership before reading or changing the source.
public enum CapturedTextReviewCommand: Equatable, Sendable {
    case repeatPart, previousPart, nextPart, readAgain, forget

    public static func parse(_ raw: String, hasCapturedSource: Bool = false) -> CapturedTextReviewCommand? {
        guard raw.unicodeScalars.count <= 200,
              !raw.contains(where: { "\"'“”‘’«»".contains($0) }) else { return nil }
        // Strip only outer sentence punctuation, not quotation marks or clauses.
        // In particular, quoted OCR/model text is not converted into a command.
        var text = raw.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".!?؟")))
            .split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        if text.hasPrefix("please ") { text = String(text.dropFirst("please ".count)) }
        if text.hasPrefix("من فضلك ") { text = String(text.dropFirst("من فضلك ".count)) }
        let arabic = SpatialClaimGuard.normalizeArabic(text).replacingOccurrences(of: "ى", with: "ي")
        if hasCapturedSource && (["repeat"].contains(text) || ["كرر"].contains(arabic)) { return .repeatPart }
        let commands: [(CapturedTextReviewCommand, [String])] = [
            (.repeatPart, ["repeat part", "repeat that part", "repeat current part", "repeat the current part",
                           "repeat last part", "repeat the last part", "repeat last spoken part",
                           "repeat the last spoken part", "كرر الجزء الحالي", "اعد الجزء الحالي",
                           "كرر الجزء الاخير", "اعد الجزء الاخير", "اعد اخر جزء قراته"]),
            (.previousPart, ["previous part", "read previous part", "read the previous part",
                             "الجزء السابق", "اقرا الجزء السابق"]),
            (.nextPart, ["next part", "read next part", "read the next part",
                         "الجزء التالي", "اقرا الجزء التالي"]),
            (.readAgain, ["read captured text again", "read the captured text again", "read this page again",
                          "اقرا النص الملتقط مره اخري", "اعد قراءه النص الملتقط", "اقرا هذه الصفحه مره اخري"]),
            (.forget, ["forget this page", "forget the captured page", "forget captured text",
                       "انس هذه الصفحه", "احذف النص الملتقط"])
        ]
        return commands.first { $0.1.contains(text) || $0.1.contains(arabic) }?.0
    }
}
