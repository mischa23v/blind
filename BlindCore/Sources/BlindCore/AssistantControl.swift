import Foundation

/// Explicit commands only. Free-form goals/questions still go to the assistant;
/// words quoted inside a longer question never trigger a control action.
public enum AssistantControl: Equatable, Sendable {
    case quiet, resume, repeatDescription, moreDetail, lessDetail, moreInformation, lessInformation
    public static func parse(_ text: String) -> AssistantControl? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: "أ", with: "ا").replacingOccurrences(of: "إ", with: "ا").replacingOccurrences(of: "آ", with: "ا")
        switch value {
        case "quiet", "pause descriptions", "stop descriptions", "صمت", "اوقف الوصف": return .quiet
        case "resume", "resume descriptions", "استأنف الوصف", "استأنف", "استانف الوصف", "استانف": return .resume
        case "repeat", "repeat description", "repeat the description", "كرر", "كرر الوصف": return .repeatDescription
        case "more detail", "more details", "تفاصيل اكثر": return .moreDetail
        case "less detail", "less details", "تفاصيل اقل": return .lessDetail
        case "more information", "معلومات اكثر": return .moreInformation
        case "less information", "معلومات اقل": return .lessInformation
        default: return nil
        }
    }
    /// A whole-utterance yes/no reply to the current offer. Longer sentences are questions, not answers.
    public static func offerAnswer(_ text: String) -> OfferAnswer? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        switch value {
        case "yes", "yeah", "yes please", "sure", "ok", "okay", "go ahead", "نعم", "ايوه", "اي", "أجل", "اجل": return .yes
        case "no", "no thanks", "no thank you", "not now", "later", "لا", "لا شكرا", "ليس الآن", "ليس الان": return .no
        default: return nil
        }
    }
    public static func explicitGoal(_ text: String) -> String? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["set goal to ", "my goal is ", "take me to ", "go to ", "هدفي ", "أريد الذهاب إلى ", "اريد الذهاب الى ", "اذهب إلى ", "اذهب الى "] {
            guard let range = text.range(of: prefix, options: [.anchored, .caseInsensitive, .diacriticInsensitive]) else { continue }
            let destination = String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            return !destination.isEmpty && destination.unicodeScalars.count <= 300 ? destination : nil
        }
        return nil
    }
}
