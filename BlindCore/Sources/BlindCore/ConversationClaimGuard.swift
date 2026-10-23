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
    private static let preposition = #"(?:on top of|in front of|next to|on|in|under|underneath|inside|behind|beside|near|by|at|over there|right there|there|here|to your (?:left|right)|nearby|close by|where you left (?:it|them))"#
    private static let adverbs = #"(?:(?:still|now|right|probably|likely|definitely|just|already)\s+)*"#
    private static let pose = #"(?:(?:sitting|lying|located|kept|placed|standing|resting)\s+)?"#
    private static let claims = [
        regex(#"\b(?:your|the|my|his|her|their|our|a|an|some)\s+[a-z][a-z' -]{0,30}?(?:'s|'re|\s+(?:is|are|'s|'re|sits|lies|stays|remains))\s+"# + adverbs + pose + preposition + #"\b"#),
        regex(#"\b(?:it|they)(?:'s|'re|\s+is|\s+are|\s+sits|\s+lies)\s+"# + adverbs + pose + preposition + #"\b"#),
        regex(#"\b(?:it|they)(?:'s|'re|\s+is|\s+are)\s+not\s+"# + preposition + #"\b"#),
        regex(#"\b(?:might|may|could|must|should)\s+(?:still\s+)?be\s+"# + pose + preposition + #"\b"#),
        regex(#"\b(?:is|are)\s*(?:not|n't)\s+"# + adverbs + #"(?:found|around|in (?:the|this|your) room|on|in|under|inside|behind|beside|near|by|at|here|there)\b"#),
        regex(#"\b(?:isn't|aren't)\s+(?:here|there|around|on|in|under|inside|behind|near)\b"#),
        regex(#"\b(?:not found|is missing|are missing|is gone|are gone|has gone|have gone|is lost|are lost|no longer there)\b"#),
        regex(#"\bi(?:'ve|\s+have|\s+just|\s+already)?\s+(?:can see|could see|found|spotted|located|noticed|saw|seen|see (?:a|an|the|your|it|them|some))\b"#),
        regex(#"\bi\s+(?:don't|do not|can't|cannot|couldn't|could not)\s+see\s+(?:your|the|it|them|a|an|any)\b"#),
        regex(#"\bhere (?:it is|they are)\b"#),
        regex(#"\byou(?:'ll|\s+will|\s+can|\s+should)?\s+find\s+(?:it|them|your\s+[a-z]+)\s+"# + preposition + #"\b"#),
        regex(#"\bthere(?:'s|\s+is|\s+are)\s+(?:no\s+[a-z]+|a|an|the|some|your|two|three|many|[a-z]+s)\b"#)
    ]
    /// A tag question ("…, right?") still asserts its statement.
    private static let tagQuestion = regex(#",\s*(?:right|isn't it|aren't they|isn't that right|ok|okay|yes|no)\s*[?؟]\s*$"#)
    private static let arabicClaims = [
        regex(#"(موجود|موجوده|يوجد|توجد|يقع|تقع)\s+(على|علي|في|تحت|عند|جنب|بجانب|قرب|فوق|داخل|هنا|هناك)"#),
        regex(#"(?:^|\s)(غير موجود|مفقود|ضاع|ضاعت|اختفي|اختفت|ليس هنا|مو هنا)(?=$|\s|[.!,،؛؟])"#),
        regex(#"(?:^|\s)(?:اشوف|اري|رايت|شفت|وجدت|لقيت|الاحظ)(?:ه|ها|هم)?(?=$|\s|[.!,،؛؟])"#)
    ]
    /// Arabic location sentences need no verb: "كوبك على الطاولة", "هو تحت الكنبة", "الكوب في المطبخ".
    private static let arabicLocation = regex(#"(?:^|\s)(?:\S+(?:ك|كم)|هو|هي|هم|ال\S+)\s+(?:على|علي|في|تحت|عند|جنب|بجانب|قرب|فوق|داخل|هنا|هناك)(?=$|\s|[.!,،؛؟])"#)
    /// Attributions to the child ("قلت إن كوبك كان …") are history, not current claims.
    private static let arabicAttribution = regex(#"(كان|كانت|قلت|تظن|ظننت)"#)
    private static let questionEnd = regex(#"[?؟]\s*$"#)

    private static func found(_ pattern: NSRegularExpression, _ text: String) -> Bool {
        pattern.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    static func isUnsupported(sentence: String) -> Bool {
        var plain = sentence.replacingOccurrences(of: "\u{2019}", with: "'").replacingOccurrences(of: "\u{2018}", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if found(tagQuestion, plain) {
            plain = tagQuestion.stringByReplacingMatches(in: plain, range: NSRange(plain.startIndex..., in: plain), withTemplate: ".")
        } else if found(questionEnd, plain) { return false }
        if claims.contains(where: { found($0, plain) }) { return true }
        let arabic = SpatialClaimGuard.normalizeArabic(plain).replacingOccurrences(of: "ى", with: "ي")
        if arabicClaims.contains(where: { found($0, arabic) }) { return true }
        return !found(arabicAttribution, arabic) && found(arabicLocation, arabic)
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
