import Foundation

/// Narrow direct-user completion receipts, not a semantic classifier or proof of
/// possession/arrival. Unknown wording is left for clarification, not mutation.
/// Bare "done", arrival at a table, and naming an unrelated object never finish
/// an item search or its broader goal. UI confirmation uses the exact request
/// and revision in the controller, not this language parser.
public enum CompanionTaskCompletion {
    public static func matches(_ report: String, request: EverydayTaskRequest) -> Bool {
        guard request.capability == .findItem, !report.isEmpty, report.count <= 300 else { return false }
        var text = report.replacingOccurrences(of: "’", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if text.last == "." || text.last == "!" { text.removeLast() }
        // A whole assertion only. Never extract positive words from a correction,
        // quotation, question, conditional, game or third-party narration.
        guard !text.contains(where: { "\n\r.!?؟;؛,،:\"“”«»".contains($0) }) else { return false }
        text = SpatialClaimGuard.normalizeArabic(text).lowercased()
        let forbidden = #"\b(not|never|didn't|haven't|cannot|can't|will|would|might|maybe|if|pretend|game|story|said|says|told|yesterday|tomorrow|and|but)\b|لم|لن|ليس|لست|ربما|سوف|لو |لعبه|قصه|قال|امس|بكره|لكن"#
        guard text.range(of: forbidden, options: .regularExpression) == nil else { return false }
        let patterns = [
            #"^i (?:(?:have|just|already) )?(?:found|located|got|retrieved) (.+)$"#,
            #"^i've (?:found|located|got|retrieved) (.+)$"#,
            #"^(?:انا )?(?:وجدت|لقيت|حصلت على|جبت|احضرت|اخذت) (.+)$"#
        ]
        let target = ItemMemory.key(for: request.query)
        guard !target.isEmpty else { return false }
        for pattern in patterns {
            let regex = try! NSRegularExpression(pattern: pattern)
            guard let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  let range = Range(match.range(at: 1), in: text) else { continue }
            // Whole target, not token overlap: 'cupboard' is not 'cup', and a
            // completion for 'cup and keys' is not the current single-item task.
            return ItemMemory.key(for: String(text[range])) == target
        }
        return false
    }
}
