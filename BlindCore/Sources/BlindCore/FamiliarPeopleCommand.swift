import Foundation

/// Explicit, whole-utterance routing for the optional familiar-people experiment.
/// Parsing is not consent, identity evidence, or permission to mutate a gallery. The caller
/// must read back the exact label/action and bind confirmation to its pending revision.
public enum FamiliarPeopleCommand: Equatable, Sendable {
    case open, recognize
    case find(String)
    case enroll(String), addExamples(String), replaceExamples(String), review(String), deletePerson(String)
    /// One-based index in the currently reviewed person's examples, never a global index.
    case deleteExample(Int)
    case capture, importPhotos, confirm, cancel, retry, finishEnrollment, stop

    public static func parse(_ text: String) -> FamiliarPeopleCommand? {
        // Reject controls before trimming: newlines must not join two commands, and invisible
        // direction/format characters must not disguise the exact label being confirmed.
        guard text.count <= 120, !text.unicodeScalars.contains(where: {
            CharacterSet.controlCharacters.contains($0) || $0.properties.generalCategory == .format
                || $0.properties.generalCategory == .lineSeparator || $0.properties.generalCategory == .paragraphSeparator
        }) else { return nil }
        var value = text.trimmingCharacters(in: .whitespaces)
        // Speech transcription can add one terminal sentence mark, but not quotation marks.
        if let last = value.last, ".!?؟".contains(last) {
            value.removeLast()
            value = value.trimmingCharacters(in: .whitespaces)
        }
        let lower = value.lowercased()
        let exact: [String: FamiliarPeopleCommand] = [
            "familiar people": .open, "الأشخاص المألوفون": .open,
            "who is this": .recognize, "من هذا": .recognize,
            "capture face": .capture, "التقط الوجه": .capture,
            "import face photos": .importPhotos, "استورد صور الوجه": .importPhotos,
            "confirm face action": .confirm, "أكد إجراء الوجه": .confirm,
            "cancel face action": .cancel, "ألغ إجراء الوجه": .cancel,
            "retry face capture": .retry, "أعد التقاط الوجه": .retry,
            "finish face enrollment": .finishEnrollment, "أنهِ تسجيل الوجه": .finishEnrollment,
            "stop familiar people": .stop, "أوقف الأشخاص المألوفين": .stop
        ]
        if let command = exact[lower] { return command }
        let labeled: [(String, (String) -> FamiliarPeopleCommand)] = [
            ("find person ", Self.find), ("ابحث عن شخص ", Self.find),
            ("enroll person ", Self.enroll), ("سجل شخص ", Self.enroll),
            ("add face examples for ", Self.addExamples), ("أضف أمثلة وجه للشخص ", Self.addExamples),
            ("replace face examples for ", Self.replaceExamples), ("استبدل أمثلة وجه للشخص ", Self.replaceExamples),
            ("review person ", Self.review), ("راجع شخص ", Self.review),
            ("delete person ", Self.deletePerson), ("احذف شخص ", Self.deletePerson)
        ]
        for (prefix, command) in labeled where lower.hasPrefix(prefix) {
            // Use the original text for labels. Never translate Mom into a relationship,
            // lowercase a name, or fold Arabic spelling/diacritics in stored identity labels.
            guard let label = validLabel(String(value.dropFirst(prefix.count))) else { return nil }
            return command(label)
        }
        for prefix in ["delete face example ", "احذف مثال الوجه "] where lower.hasPrefix(prefix) {
            let index = String(value.dropFirst(prefix.count))
            let digits = ["1", "2", "3", "4", "5", "6"]
            let arabicDigits = ["١", "٢", "٣", "٤", "٥", "٦"]
            if let offset = digits.firstIndex(of: index) ?? arabicDigits.firstIndex(of: index) {
                return .deleteExample(offset + 1)
            }
            return nil
        }
        return nil
    }

    /// A deliberately narrow voice-label grammar: 1–4 words, up to 60 characters;
    /// letters, combining marks, decimal digits, spaces and internal hyphens/apostrophes.
    /// More elaborate labels can use an explicit UI flow rather than guessing command scope.
    private static func validLabel(_ value: String) -> String? {
        let label = value.trimmingCharacters(in: .whitespaces)
        let words = label.split(separator: " ", omittingEmptySubsequences: false)
        guard !label.isEmpty, label.count <= 60, (1...4).contains(words.count), !words.contains(where: { $0.isEmpty }) else { return nil }
        let clauses: Set<String> = ["and", "or", "then", "but", "please", "because", "when", "if", "also", "instead",
                                    "و", "أو", "او", "ثم", "لكن", "إذا", "اذا", "لأن", "لان", "فضلا"]
        guard !words.contains(where: { clauses.contains($0.lowercased()) }) else { return nil }
        for word in words {
            let scalars = Array(word.unicodeScalars)
            guard let first = scalars.first, let last = scalars.last,
                  CharacterSet.alphanumerics.contains(first),
                  CharacterSet.alphanumerics.union(.nonBaseCharacters).contains(last) else { return nil }
            guard scalars.allSatisfy({ CharacterSet.alphanumerics.union(.nonBaseCharacters).contains($0)
                || $0 == "-" || $0 == "'" || $0 == "’" }) else { return nil }
        }
        return label
    }
}
