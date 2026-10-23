import Foundation

/// Bounded crossing-intent boundary, not traffic perception or a route controller.
/// A selected adult communication mode never grants crossing clearance.
public enum RoadCrossingPolicy {
    public static func requiresCodeOwnedReply(_ request: String) -> Bool {
        let text = SpatialClaimGuard.normalizeArabic(request.lowercased())
        guard text.count <= 1_200 else { return false }
        func has(_ pattern: String) -> Bool { text.range(of: pattern, options: .regularExpression) != nil }
        let crossing = has(#"\b(?:cross (?:the |this |that |a )?(?:road|street|crosswalk)|(?:can|could|should|may) (?:i|we) cross|help (?:me|us) cross)\b|(?:^| )(?:اعبر|نعبر|عبور) (?:الشارع|الطريق)(?: |$)"#)
        if crossing { return true }
        let traffic = has(#"\b(?:traffic|crosswalk|pedestrians?|cars?|green light|red light|walk signal)\b|(?:^| )(?:السيارات|سيارات|المشاه|الاشاره|اشاره)(?: |$)"#)
        let proceed = has(#"\b(?:can|could|should|may) (?:i|we) (?:go|walk|cross|proceed)|\b(?:safe|clear) (?:to|for) (?:go|walk|cross)|\b(?:tell|say) (?:me|us) when\b|(?:^| )(?:اقدر|نقدر|هل يمكنني|هل استطيع) (?:امشي|اعبر|اروح)(?: |$)"#)
        return traffic && proceed
    }
    public static func reply(audience: AssistantAudience, arabic: Bool) -> String {
        if audience == .adult {
            return arabic
                ? "لا أستطيع تأكيد أمان العبور. الإشارة أو توقف السيارات لا يكشفان كل حركة المرور أو النقاط العمياء. لا تعتمد على التطبيق لاتخاذ قرار العبور."
                : "I can't confirm a safe crossing. A signal or stopped cars cannot establish all traffic or blind spots. Don't rely on the app to decide when to cross."
        }
        return arabic
            ? "لا أستطيع تأكيد أمان العبور. يحتاج الطفل إلى بالغ يرافقه. الإشارة الخضراء أو توقف السيارات أو عدم ظهورها لا يعني أمان العبور."
            : "I can't confirm a safe crossing. A child needs an accompanying adult. A green signal, stopped cars, or no visible cars does not mean it's safe."
    }
}
