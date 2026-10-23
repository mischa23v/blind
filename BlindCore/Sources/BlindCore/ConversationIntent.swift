import Foundation

public enum AssistantSessionControl: String, Sendable, Equatable {
    case start, mute, unmute, end
}
public enum AssistantTaskControl: String, Sendable, Equatable {
    case pause, resume, cancel
}

/// Conservative routing only, not an LLM or authority to act. Camera availability
/// is intentionally absent: ordinary conversation must not become image inference
/// just because a camera is running. Unclear utterances stay conversational.
public enum ConversationIntent: Sendable, Equatable {
    case conversation
    case visualRequest
    case sessionControl(AssistantSessionControl)
    case taskControl(AssistantTaskControl)

    public static func classify(_ text: String) -> ConversationIntent {
        let value = normalized(text)
        guard !value.isEmpty, value.unicodeScalars.count <= AssistantDialogue.maximumTurnScalars else { return .conversation }
        let sessionControls: [(AssistantSessionControl, Set<String>)] = [
            (.mute, ["mute", "mute microphone", "mute the microphone", "stop listening", "turn off the microphone", "pause listening", "اكتم الميكروفون", "اغلق الميكروفون", "توقف عن الاستماع"]),
            (.unmute, ["unmute", "unmute microphone", "unmute the microphone", "resume listening", "turn on the microphone", "شغل الميكروفون", "استأنف الاستماع", "استانف الاستماع"]),
            (.start, ["start assistant", "start the assistant", "start session", "start the session", "start listening", "ابدأ المساعد", "ابدا المساعد", "ابدأ الجلسة", "ابدا الجلسة", "ابدأ الاستماع", "ابدا الاستماع"]),
            (.end, ["end session", "end the session", "end conversation", "end the conversation", "stop the assistant", "انه الجلسة", "انه المحادثة", "اوقف المساعد"])
        ]
        for (control, phrases) in sessionControls where phrases.contains(value) { return .sessionControl(control) }
        let taskControls: [(AssistantTaskControl, Set<String>)] = [
            (.pause, ["pause", "pause task", "pause the task", "pause this task", "pause my task", "stop", "wait", "hold on", "توقف", "انتظر", "اوقف المهمة مؤقتا"]),
            // Bare "resume" keeps the established resume-descriptions meaning.
            (.resume, ["resume task", "resume the task", "resume my task", "continue the task", "continue my task", "استأنف المهمة", "استانف المهمة", "اكمل المهمة"]),
            (.cancel, ["cancel", "cancel task", "cancel the task", "cancel this task", "cancel my task", "cancel that", "forget the task", "الغ المهمة", "الغاء المهمة", "الغي المهمة"])
        ]
        for (control, phrases) in taskControls where phrases.contains(value) { return .taskControl(control) }

        let exact: Set<String> = [
            "what do you see", "what can you see", "what is this", "what's this", "what is that", "what's that",
            "what is in front of me", "what's in front of me", "what is around me", "what's around me", "who is here",
            "look around", "describe the scene", "describe my surroundings", "describe the surroundings", "describe this", "read this", "read that",
            "ماذا ترى", "ماذا تري", "ما هذا", "ما هذه", "ماذا امامي", "ما الذي امامي", "من هنا", "انظر حولي", "صف ما تراه", "صف المكان", "اقرا هذا", "اقرا هذه"
        ]
        if exact.contains(value) { return .visualRequest }
        let prefixes = [
            "look at ", "look for ", "can you look at ", "can you look for ", "can you see ", "do you see ", "describe what you see",
            "describe this ", "describe that ", "read this ", "read that ", "read the sign", "read the label", "read the menu", "read the text",
            "scan the ", "scan this ", "scan that ", "what color is this ", "what colour is this ", "what does this sign ", "what does the sign ",
            "انظر الى ", "انظر الي ", "هل ترى ", "هل تري ", "صف هذا ", "صف هذه ", "اقرا اللافتة", "اقرا الملصق", "اقرا القائمة", "اقرا هذا ", "اقرا هذه ", "ما لون هذا ", "ما لون هذه "
        ]
        if prefixes.contains(where: { value.hasPrefix($0) }) { return .visualRequest }
        return .conversation
    }

    /// Save an unambiguous requested task before inference, without asking a model
    /// to extract, rewrite or commit the person's goal. This narrow adapter does
    /// not infer goals from conceptual questions or authorize a visual operation.
    /// Unmatched requests remain available to ordinary conversation/clarification.
    public static func explicitTaskGoal(_ text: String) -> String? {
        let request = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !request.isEmpty, text.unicodeScalars.count <= 300,
              !request.contains(where: { $0.isNewline }) else { return nil }
        var value = normalized(text)
        for prefix in ["actually, ", "actually ", "instead, ", "instead ", "في الواقع، ", "في الواقع ", "بدلا من ذلك، ", "بدلا من ذلك "] where value.hasPrefix(prefix) {
            value = normalized(String(value.dropFirst(prefix.count)))
            break
        }
        // A conditional/negative/quoted request is not an unconditional new goal.
        // Prefer a false negative over replacing a still-active task incorrectly.
        guard !value.contains(where: { "\"“”«»\n\r.!?؟;؛".contains($0) }) else { return nil }
        let words = Set(value.split { !$0.isLetter && $0 != "'" }.map(String.init))
        let uncertain: Set<String> = ["if", "unless", "when", "not", "no", "never", "don't", "dont", "cannot", "can't", "without", "لا", "لن", "لم", "بدون", "اذا", "لو", "عندما"]
        guard words.isDisjoint(with: uncertain) else { return nil }
        let prefixes = [
            "help me find ", "help me locate ", "find ", "locate ",
            "can you help me find ", "could you help me find ", "can you find ", "could you find ",
            "ساعدني في العثور على ", "ساعدني على العثور على ", "ساعدني في ايجاد ", "ساعدني اجد ",
            "ساعدني ابحث عن ", "ابحث عن ", "دور على ", "هل يمكنك مساعدتي في العثور على "
        ]
        guard let prefix = prefixes.first(where: { value.hasPrefix($0) }) else { return nil }
        let target = String(value.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else { return nil }
        let conceptual = ["out", "why", "how", "whether", "what", "meaning", "the meaning", "a meaning", "definition", "the definition", "an explanation", "معنى", "معني", "تعريف", "سبب", "لماذا", "كيف"]
        guard !conceptual.contains(where: { target == $0 || target.hasPrefix($0 + " ") }) else { return nil }
        // Preserve every qualification and the exact original wording/casing.
        return text
    }

    private static func normalized(_ text: String) -> String {
        // Whole commands only; do not match "stop sign", quoted commands or a
        // negative/conditional request such as "don't stop listening".
        let unmarked = String(text.unicodeScalars.filter { !(0x064B...0x065F).contains($0.value) })
        var result = unmarked.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".!?؟،,؛;:"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "أ", with: "ا")
            .replacingOccurrences(of: "إ", with: "ا")
            .replacingOccurrences(of: "آ", with: "ا")
            .replacingOccurrences(of: "ـ", with: "")
        result = result.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        for prefix in ["please ", "من فضلك ", "لو سمحت "] where result.hasPrefix(prefix) { result = String(result.dropFirst(prefix.count)) }
        for suffix in [" please", " من فضلك", " لو سمحت"] where result.hasSuffix(suffix) { result = String(result.dropLast(suffix.count)) }
        return result
    }
}
