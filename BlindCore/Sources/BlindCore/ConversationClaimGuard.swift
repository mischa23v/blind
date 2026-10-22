import Foundation

/// Conversation evidence rule (2026-10-22). A chat reply written by the model, with no live
/// camera, may not state where an object is now, that it is present or absent, or that the
/// assistant perceived anything. Code renders those facts from stored reports and sensors.
/// Past-tense attributions ("you said your cup was on the table") and questions are allowed.
/// Conservative lexical defence, not a semantic proof; it runs alongside SpatialClaimGuard.
/// Mirrors server/src/companion-guards.mjs; both run Tests/BlindCoreTests/Fixtures/companion-evidence.json.
public enum ConversationClaimGuard {
    private static func regex(_ pattern: String) -> NSRegularExpression {
        // Patterns are constants covered by the shared fixture tests.
        try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }
    private static let preposition = #"(?:on top of|in front of|next to|on|in|under|underneath|inside|behind|beside|near|by|at|over there|right there|there|here)"#
    private static let claims = [
        regex(#"\b(?:your|the|my|his|her|their|our)\s+[a-z][a-z' -]{0,30}?\s+(?:is|are|'s)\s+(?:still\s+|now\s+|right\s+|probably\s+|likely\s+|definitely\s+)?"# + preposition + #"\b"#),
        regex(#"\b(?:it|they)(?:'s|’s|\s+is|\s+are)\s+(?:still\s+|now\s+|right\s+|probably\s+|likely\s+)?"# + preposition + #"\b"#),
        regex(#"\b(?:might|may|could|must|should)\s+(?:still\s+)?be\s+"# + preposition + #"\b"#),
        regex(#"\b(?:is|are)\s*(?:not|n't)\s+(?:here|there|found|around|in (?:the|this|your) room)\b"#),
        regex(#"\b(?:isn't|aren't)\s+(?:here|there|around)\b"#),
        regex(#"\b(?:not found|is missing|are missing|is gone|are gone|has gone|have gone|is lost|are lost|no longer there)\b"#),
        regex(#"\bi\s+(?:can see|could see|found|spotted|located|noticed|see (?:a|an|the|your|it|them|some))\b"#),
        regex(#"\bthere(?:'s|’s|\s+is|\s+are)\s+(?:a|an|the|some|your|two|three|many)\s+[a-z]"#)
    ]
    private static let arabicClaims = [
        regex(#"(موجود|موجوده|يوجد|توجد|يقع|تقع)\s+(على|علي|في|تحت|عند|جنب|بجانب|قرب|فوق|داخل|هنا|هناك)"#),
        regex(#"(?:^|\s)(غير موجود|مفقود|ضاع|ضاعت|اختفي|اختفت|ليس هنا|مو هنا)(?=$|\s|[.!,،؛؟])"#),
        regex(#"(?:^|\s)(اشوف|اري|رايت|شفت|وجدت|لقيت|الاحظ)(?=$|\s|[.!,،؛؟])"#)
    ]
    private static let questionEnd = regex(#"[?؟]\s*$"#)

    private static func found(_ pattern: NSRegularExpression, _ text: String) -> Bool {
        pattern.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    static func isUnsupported(sentence: String) -> Bool {
        if found(questionEnd, sentence.trimmingCharacters(in: .whitespacesAndNewlines)) { return false }
        let plain = sentence.replacingOccurrences(of: "\u{2019}", with: "'").replacingOccurrences(of: "\u{2018}", with: "'")
        if claims.contains(where: { found($0, plain) }) { return true }
        let arabic = SpatialClaimGuard.normalizeArabic(sentence).replacingOccurrences(of: "ى", with: "ي")
        return arabicClaims.contains { found($0, arabic) }
    }

    public static func containsUnsupportedClaim(_ text: String) -> Bool {
        SpatialClaimGuard.sentences(text).contains(where: isUnsupported(sentence:))
    }

    /// The reply without its unsupported sentences; empty when none remain.
    public static func supportedText(_ text: String) -> String {
        SpatialClaimGuard.sentences(text).filter { !isUnsupported(sentence: $0) }.joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
