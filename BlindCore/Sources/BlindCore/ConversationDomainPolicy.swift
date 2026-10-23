import Foundation

/// A request-scoped boundary between ordinary chat and dedicated physical
/// inspection. A model cannot satisfy an inspection by emitting a bare colour,
/// number, or yes/no answer. This gate does not ban these words in ordinary chat.
/// Lexical recognition is deliberately bounded; it is not a semantic classifier
/// or evidence that a camera, banknote model, or colour measurement is available.
public enum ConversationDomainPolicy {
    public enum Inspection: String, Equatable, Sendable {
        case clothingColor, banknote
    }

    public static func requiredInspection(for question: String) -> Inspection? {
        // Cash takes priority when an inspection mentions a banknote's colour.
        if requiresBanknoteInspection(question) { return .banknote }
        if ClothingColorCommand.matches(question) { return .clothingColor }
        return nil
    }

    /// Apply before inference and again before any streamed/displayed/spoken
    /// model answer. A recognized request has no model-answer exception, even
    /// if the dedicated tool is unavailable, fails, or asks for another capture.
    public static func allowsModelResponse(to question: String) -> Bool {
        requiredInspection(for: question) == nil
    }

    private static func requiresBanknoteInspection(_ text: String) -> Bool {
        let folded = text.lowercased().folding(options: [.diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX")).decomposedStringWithCanonicalMapping
        let unmarked = String(String.UnicodeScalarView(folded.unicodeScalars.filter {
            !CharacterSet.nonBaseCharacters.contains($0) && $0.value != 0x0640
        }))
        let words = unmarked.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        let tokens = Set(words)
        var phrase = words.joined(separator: " ")
        for _ in 0..<4 {
            if let prefix = ["please ", "can you ", "could you ", "would you ", "من فضلك ", "لو سمحت ", "هل يمكنك "].first(where: { phrase.hasPrefix($0) }) {
                phrase.removeFirst(prefix.count)
            } else { break }
        }
        if ["do not ", "don t ", "dont ", "never ", "stop ", "cancel ", "لا ", "توقف ", "الغ ", "الغاء "].contains(where: { phrase.hasPrefix($0) }) { return false }
        let discussion: Set<String> = ["history", "historical", "theory", "definition", "meaning", "mean", "means", "explain", "remember", "favorite", "favourite", "prefer", "budget", "budgeting", "salary", "salaries", "exchange", "price", "prices", "cost", "costs", "spent", "تاريخ", "معنى", "تعريف", "اشرح", "اتذكر", "تتذكر", "ميزانية", "راتب", "صرف", "سعر", "اسعار"]
        guard tokens.isDisjoint(with: discussion) else { return false }
        let cash: Set<String> = ["banknote", "banknotes", "cash", "money", "currency", "bill", "bills", "note", "notes", "نقود", "النقود", "فلوس", "الفلوس", "فلوسي", "عملة", "العملة", "عملتي", "الورقة", "ورقتي", "ورقة", "اوراق", "الاوراق"]
        var hasCash = !tokens.isDisjoint(with: cash)
        let nonCashNotes: Set<String> = ["meeting", "lecture", "lectures", "musical", "music", "piano", "class", "study", "notebook", "agenda", "الاجتماع", "ملاحظات", "موسيقية"]
        if !tokens.isDisjoint(with: nonCashNotes), tokens.isDisjoint(with: ["banknote", "banknotes", "cash", "money", "currency", "نقود", "النقود", "فلوس", "الفلوس"]) { hasCash = false }
        let physical: Set<String> = ["this", "that", "these", "those", "my", "it", "here", "holding", "hand", "hands", "هذا", "هذه", "هذي", "هاذي", "هذول", "ذلك", "تلك", "يدي", "بيدي", "معي", "فلوسي", "عملتي", "ورقتي"]
        let hasPhysical = !tokens.isDisjoint(with: physical)
            || ["the banknote", "the bank note", "the note", "the bill", "الورقة النقدية"].contains(where: { phrase.contains($0) })
        let amounts: Set<String> = ["one", "two", "five", "ten", "twenty", "fifty", "hundred", "thousand", "واحد", "اثنان", "خمسة", "عشرة", "عشرين", "عشرون", "خمسين", "خمسون", "مية", "مئة", "مائة", "ميتين", "مئتان", "مائتان", "الف"]
        let hasAmount = !tokens.isDisjoint(with: amounts) || words.contains { !$0.isEmpty && $0.allSatisfy(\.isNumber) }
        let authenticity: Set<String> = ["real", "genuine", "authentic", "counterfeit", "fake", "مزيفة", "مزيف", "مزورة", "مزور", "اصلية", "اصلي", "حقيقية", "حقيقي"]
        let questionStart = ["what ", "which ", "how much ", "how many ", "is ", "are ", "does ", "do ", "tell me if ", "tell me whether ", "هل ", "ما ", "كم ", "وش ", "ايش "]
            .contains(where: { phrase.hasPrefix($0) })
        let commandStart = ["identify ", "read ", "check ", "confirm ", "count ", "sum ", "total ", "tell me the value ", "tell me the denomination ", "اقرا ", "افحص ", "تاكد ", "حدد ", "عد ", "احسب ", "تعرف على "]
            .contains(where: { phrase.hasPrefix($0) })
        let valueWords: Set<String> = ["value", "worth", "denomination", "amount", "total", "قيمة", "قيمه", "فئة", "فئه"]
        let valueQuestion = hasAmount || !tokens.isDisjoint(with: valueWords) || !tokens.isDisjoint(with: authenticity)
            || phrase.hasPrefix("how much ") || phrase.hasPrefix("كم ")
        let identityQuestion = ["what banknote ", "what note ", "what bill ", "what currency ", "which banknote ", "which note ", "which bill ", "ما هي العملة ", "ما هذه العملة"].contains(where: { phrase.hasPrefix($0) })
        if hasCash, commandStart, !phrase.hasPrefix("read me ") { return true }
        if hasCash, hasPhysical, questionStart, valueQuestion || identityQuestion || ClothingColorCommand.matches(text) { return true }
        if hasCash, !tokens.isDisjoint(with: authenticity), questionStart { return true }
        // Bare "denomination" does not divert discussions of the concept.
        if tokens.contains("denomination"), hasPhysical, questionStart { return true }
        if phrase == "how much is this" || phrase == "what is this worth" || phrase == "what s this worth" { return true }
        // The user can hold a note and omit "banknote": "Is this fifty or a
        // hundred?". Do not mistake a quantified object ("these fifty shirts")
        // or an ordinary price comparison for a denomination inspection.
        let comparison = #"^(?:is (?:this|that|it)|are (?:these|those)|هل (?:هذا|هذه|هذي)) (?:a )?(?:[0-9٠-٩۰-۹]+|one|two|five|ten|twenty|fifty|hundred|thousand|خمسة|عشرة|عشرين|عشرون|خمسين|خمسون|مية|مئة|مائة|مئتان|مائتان)(?: (?:or|a|and|one|two|five|ten|twenty|fifty|hundred|thousand|riyals?|dollars?|euros?|pounds?|sar|usd|ام|او|ولا|خمسة|عشرة|عشرين|عشرون|خمسين|خمسون|مية|مئة|مائة|ريال|ريالات|دولار|[0-9٠-٩۰-۹]+))*$"#
        if hasAmount, phrase.range(of: comparison, options: .regularExpression) != nil { return true }
        // Arabic often omits هل in a spoken choice question.
        return hasCash && hasPhysical && hasAmount && (text.contains("؟") || !tokens.isDisjoint(with: ["ام", "او", "ولا"]))
    }
}
