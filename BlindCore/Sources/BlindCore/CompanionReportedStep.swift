import Foundation

/// A model may associate a direct user report with one current proposed step.
/// This is conversational progress, never verified possession, arrival, safety,
/// successful handling, or whole-goal completion. The full report is preserved.
public struct CompanionReportedStep: Codable, Sendable, Equatable {
    public let step: String
    public let report: String
    public let goalRevision: String
    public let source = "model-associated direct user report; not sensor confirmed"
    public static func proposed(step: String, currentStep: String, quote: String,
                                latest: String, goalRevision: String) -> Self? {
        guard !step.isEmpty, step == currentStep, step.count <= 300,
              !goalRevision.isEmpty, goalRevision.count <= 64,
              quote == latest, !quote.isEmpty, quote.count <= 600 else { return nil }
        let text = SpatialClaimGuard.normalizeArabic(quote).lowercased()
        func has(_ pattern: String) -> Bool { text.range(of: pattern, options: .regularExpression) != nil }
        // These are rejection boundaries, not a semantic completion classifier.
        // The model still must name the exact current step. Bare done and third-
        // party speech cannot be silently bound to a physical action.
        guard !has(#"[?؟\"“”«»]|\b(not|never|cannot|can't|didn't|haven't|isn't|wasn't|will|would|might|maybe|if|pretend|game|story|said|says|told|yesterday|tomorrow)\b|لم|لن|ليس|لست|ربما|سوف|لو |لعبه|قصه|قال|امس|بكره"#),
              has(#"^\s*(i\b|i['’]ve\b|انا\b|انتهيت|خلصت|احضرت|جبت|اخذت|وضعت|حطيت|وجدت|لقيت|فتحت|اغلقت)"#),
              !has(#"^\s*(i (am|['’]m) done|i did it|i have finished|انتهيت|خلصت)[.!\s]*$"#) else { return nil }
        return Self(step: step, report: quote, goalRevision: goalRevision)
    }
}
