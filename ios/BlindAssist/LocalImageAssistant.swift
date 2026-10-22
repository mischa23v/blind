import Foundation
import CoreVideo
import ImageIO
import os
import BlindCore
#if canImport(FoundationModels)
import FoundationModels
#endif

struct LocalImageAnswer {
    let text: String?
    let status: String
    var action: CompanionAction? = nil
}

/// What code does after a turn. The model may classify a message; only code changes state.
enum CompanionAction {
    case utterance(CompanionUtterance)
    case newTask(String)
    case cancelTask
}

/// App-owned conversation state, kept in the protected on-phone companion namespace.
/// Facts are the child's own reports with their time; generated replies never become facts.
struct CompanionWorkingState: Codable, Sendable {
    struct Report: Codable, Sendable {
        var text: String
        var time: Date
    }
    var goal = ""
    var goalRevision = UUID().uuidString
    var reports: [Report] = []
    var factBook = CompanionFactBook()
    /// The object being discussed, so "I left it on the table" resolves to it.
    var focusObject = ""

    // Older saved states also carried model-proposed steps and model-extracted facts; those
    // keys are ignored on decoding (2026-10-22: the model no longer writes task state).
    private enum CodingKeys: String, CodingKey { case goal, goalRevision, reports, factBook, focusObject }
    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        goal = try c.decodeIfPresent(String.self, forKey: .goal) ?? ""
        goalRevision = try c.decodeIfPresent(String.self, forKey: .goalRevision) ?? UUID().uuidString
        reports = try c.decodeIfPresent([Report].self, forKey: .reports) ?? []
        factBook = try c.decodeIfPresent(CompanionFactBook.self, forKey: .factBook) ?? CompanionFactBook()
        focusObject = try c.decodeIfPresent(String.self, forKey: .focusObject) ?? ""
    }

    mutating func record(_ text: String) {
        guard !text.isEmpty, text.unicodeScalars.count <= AssistantDialogue.maximumTurnScalars else { return }
        reports.append(Report(text: text, time: Date()))
        reports = Array(reports.suffix(12))
    }
    mutating func changeGoal(_ value: String) {
        guard goal != value else { return }
        goal = value; goalRevision = UUID().uuidString
    }

    /// Applies a parsed find request or location report and returns the code-written reply.
    mutating func respond(to utterance: CompanionUtterance, message: String, now: Date = Date(), arabic: Bool) -> String {
        switch utterance {
        case .find(let object):
            changeGoal(String(message.trimmingCharacters(in: .whitespacesAndNewlines).prefix(300)))
            focusObject = object
            if let fact = factBook.latest(for: object) { return fact.recall(now: now, arabic: arabic) }
            return CompanionFact.unknown(object: object, arabic: arabic)
        case .report(let named, let place, let tense, let hedged):
            guard let object = named ?? (focusObject.isEmpty ? nil : focusObject) else {
                return arabic ? "أي غرض تقصد؟ قل اسمه." : "Which thing do you mean? Tell me its name."
            }
            focusObject = object
            guard let fact = factBook.record(object: object, place: place, tense: tense, hedged: hedged, at: now) else {
                return arabic ? "لم أستطع حفظ ذلك." : "I couldn't save that."
            }
            return fact.acknowledgement(arabic: arabic)
        }
    }

    mutating func cancelTask(arabic: Bool) -> String {
        changeGoal(""); focusObject = ""
        return arabic ? "حسناً، أوقفت هذه المهمة." : "Okay, I've stopped that task."
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
enum CompanionIntentKind {
    case findObject, reportLocation, newTask, cancelTask, conversation
}

@available(iOS 26.0, *)
@Generable
enum CompanionReportTime {
    case lastHadEarlier, isThereNow, notALocationReport
}

/// The model only labels the message and copies words from it; code validates and acts.
@available(iOS 26.0, *)
@Generable
struct CompanionIntent {
    @Guide(description: "findObject: help finding one of their things. reportLocation: says where a thing is or where they last had it. newTask: asks for help with a different activity or destination. cancelTask: stops the current task without a new one. conversation: anything else, including questions.")
    var kind: CompanionIntentKind
    @Guide(description: "The thing's name copied exactly from the message, without my or the. Empty when none or only it.")
    var object: String
    @Guide(description: "The place words copied exactly from the message, starting with the preposition, such as on the kitchen table. Empty when none.")
    var place: String
    @Guide(description: "lastHadEarlier when they say where they left or last had it; isThereNow when they say where it is.")
    var time: CompanionReportTime
}

/// Each turn takes a fresh session whose instructions were processed ahead of time, so earlier
/// turns never leak in as generated "facts" and the first words are not delayed by setup.
@available(iOS 26.0, *)
final class CompanionSessions: @unchecked Sendable {
    enum Role: Hashable {
        case chat(arabic: Bool), intent
        var instructions: String {
            switch self {
            case .chat(let arabic): return LocalImageAssistant.chatInstructions(arabic: arabic)
            case .intent: return LocalImageAssistant.intentInstructions
            }
        }
    }
    static let shared = CompanionSessions()
    private let lock = NSLock()
    private var spares: [Role: LanguageModelSession] = [:]

    func take(_ role: Role) -> LanguageModelSession {
        lock.lock(); defer { lock.unlock() }
        let session = spares.removeValue(forKey: role) ?? LanguageModelSession(instructions: role.instructions)
        spares[role] = LanguageModelSession(instructions: role.instructions)
        return session
    }

    /// Loads the model and processes instructions ahead of the next message.
    func prewarm(arabic: Bool) {
        lock.lock()
        for role in [Role.intent, .chat(arabic: arabic)] where spares[role] == nil {
            spares[role] = LanguageModelSession(instructions: role.instructions)
        }
        let ready = [spares[.intent], spares[.chat(arabic: arabic)]].compactMap { $0 }
        lock.unlock()
        ready.forEach { $0.prewarm() }
    }
}
#endif

/// Thin adapter for Apple's documented LanguageModelSession / Attachment API. No remote model.
/// Conversation evidence rule (2026-10-22): code answers find requests and location reports from
/// stored child reports; the model labels other messages and chats, and its text passes
/// ConversationClaimGuard and SpatialClaimGuard before it is shown or spoken.
enum LocalImageAssistant {
    static let intentInstructions = "Label a blind child's latest message for a phone assistant. Copy object and place words exactly from the message; never add words."

    static func chatInstructions(arabic: Bool) -> String {
        "You are Blind Assist, a warm companion talking with a blind child. The phone's sensors and app code handle hazards, directions and finding things; you only talk. " +
        "Reply to the child's latest message in one or two short sentences, at most 35 words, in \(arabic ? "Arabic" : "English"). " +
        "You cannot see anything now. Never say where an object is, whether it is here or missing, or that you see or found something; if asked, say you don't know. " +
        "Use only what the child told you; their reports may be out of date. Never call a path, floor or stairs safe or clear. If the child gives a new name, use it. Ask a question only when you need missing information."
    }

    private static func usableChatReply(_ text: String) -> Bool {
        let lower = text.lowercased()
        return !text.isEmpty && text.split(whereSeparator: { $0.isWhitespace }).count <= 35 &&
            !lower.contains("earlier conversation:") && !lower.contains("child:") &&
            !lower.contains("assistant:")
    }

    /// Model chat text that may be shown and spoken.
    static func acceptableChat(_ text: String) -> Bool {
        usableChatReply(text) && !SpatialClaimGuard.containsSpatialClaim(text) &&
            !ConversationClaimGuard.containsUnsupportedClaim(text)
    }

    static func prewarm(arabic: Bool) {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), OnDeviceLanguage.supports(arabic: arabic) {
            CompanionSessions.shared.prewarm(arabic: arabic)
        }
        #endif
    }

    private static let placeStarts = ["on ", "in ", "under ", "underneath ", "inside ", "behind ", "beside ", "near ", "by ", "at ", "next to ", "in front of ", "on top of ",
                                      "على ", "في ", "تحت ", "عند ", "جنب ", "بجانب ", "قرب ", "فوق ", "داخل ", "ورا ", "خلف ", "امام ", "أمام ", "بال"]

    /// Words the model copied, checked against the message. Nil when invented.
    private static func copied(_ value: String, from message: String) -> String? {
        var text = value.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        for article in ["my ", "the ", "our "] where text.lowercased().hasPrefix(article) { text = String(text.dropFirst(article.count)) }
        guard !text.isEmpty, text.count <= 80, message.localizedCaseInsensitiveContains(text) else { return nil }
        return text
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private static func action(from intent: CompanionIntent, message: String, goal: String, focus: String) -> CompanionAction? {
        let object = copied(intent.object, from: message)
        let place = copied(intent.place, from: message)
        switch intent.kind {
        case .findObject:
            return object.map { CompanionAction.utterance(.find(object: $0)) }
        case .reportLocation:
            // "I am in the bedroom" is the child's own position, not a thing's location.
            guard let place, intent.time != .notALocationReport, object != nil || !focus.isEmpty,
                  placeStarts.contains(where: { place.lowercased().hasPrefix($0) }) else { return nil }
            let hedged = ["i think", "maybe", "probably", "أظن", "اظن", "ربما"].contains { message.lowercased().contains($0) }
            return .utterance(.report(object: object, place: place, tense: intent.time == .isThereNow ? .current : .earlier, hedged: hedged))
        case .newTask:
            return .newTask(String(message.trimmingCharacters(in: .whitespacesAndNewlines).prefix(300)))
        case .cancelTask:
            return goal.isEmpty ? nil : .cancelTask
        case .conversation:
            return nil
        }
    }
    #endif

    /// Plain lines, not JSON: the small on-device model reads short labelled text best.
    private static func chatPrompt(latest: String, earlier: [String], name: String, goal: String,
                                   facts: [CompanionFact], likes: [String], now: Date) -> String {
        var lines: [String] = []
        if !name.isEmpty { lines.append("Saved name: \(name).") }
        if !goal.isEmpty { lines.append("Current task: \(goal)") }
        if !likes.isEmpty { lines.append("The child likes: \(likes.joined(separator: ", ")).") }
        for fact in facts.suffix(3) {
            let elapsed = ItemMemory.relativeTime(from: fact.at, to: now, arabic: false)
            lines.append("The child said \(elapsed), not checked: \(fact.object) \(fact.tense == .earlier ? "last had" : "was") \(fact.place).")
        }
        if !earlier.isEmpty { lines.append("Earlier the child said: " + earlier.map { "\"\($0)\"" }.joined(separator: " ")) }
        lines.append("No camera view now; the child's location is unknown.")
        lines.append("Child's latest message: \(latest)")
        return lines.joined(separator: "\n")
    }

    static func converse(dialogue: AssistantDialogue, arabic: Bool, preferredName: String = "", situation: [String: Any] = [:], workingState: CompanionWorkingState = CompanionWorkingState(), onPartial: (@MainActor @Sendable (String) -> Void)? = nil) async -> LocalImageAnswer {
        let latest = dialogue.turns.last?.text ?? ""
        let goal = workingState.goal.isEmpty ? dialogue.goal : workingState.goal
        // Find requests and location reports are answered by code, instantly, from stored reports.
        if let utterance = CompanionUtterance.parse(latest) {
            var preview = workingState
            return LocalImageAnswer(text: preview.respond(to: utterance, message: latest, arabic: arabic),
                                    status: "Answered from what you told me.", action: .utterance(utterance))
        }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), OnDeviceLanguage.supports(arabic: arabic) {
            do {
                let logger = Logger(subsystem: "org.blindassist.mobility", category: "CompanionAgent")
                let started = ProcessInfo.processInfo.systemUptime
                defer { CompanionSessions.shared.prewarm(arabic: arabic) }
                var taskAction: CompanionAction?
                let intentPrompt = (goal.isEmpty ? "" : "Current task: \(goal)\n") + "Message: \(latest)"
                if let intent = try? await CompanionSessions.shared.take(.intent).respond(to: intentPrompt, generating: CompanionIntent.self,
                    options: GenerationOptions(samplingMode: .greedy, maximumResponseTokens: 60)).content {
                    logger.info("Message labelled after \(ProcessInfo.processInfo.systemUptime - started, privacy: .public) seconds")
                    switch action(from: intent, message: latest, goal: goal, focus: workingState.focusObject) {
                    case .utterance(let utterance)?:
                        var preview = workingState
                        return LocalImageAnswer(text: preview.respond(to: utterance, message: latest, arabic: arabic),
                                                status: "Answered from what you told me.", action: .utterance(utterance))
                    case .cancelTask?:
                        var preview = workingState
                        return LocalImageAnswer(text: preview.cancelTask(arabic: arabic), status: "Task stopped.", action: .cancelTask)
                    case .newTask(let task)?:
                        taskAction = .newTask(task)
                    case nil:
                        break
                    }
                }
                try Task.checkCancellation()
                var earlier = workingState.reports.map(\.text)
                if earlier.last == latest { earlier.removeLast() }
                if earlier.isEmpty { earlier = dialogue.turns.dropLast().filter { $0.role == "user" }.map(\.text) }
                let likes = (situation["preferences"] as? [[String: Any]] ?? []).compactMap { $0["value"] as? String }.prefix(4)
                let prompt = chatPrompt(latest: latest, earlier: Array(earlier.filter { $0 != latest }.suffix(4)),
                                        name: String(preferredName.prefix(80)), goal: goal, facts: workingState.factBook.facts,
                                        likes: Array(likes), now: Date())
                // One retry when nothing compliant came back, then refuse (same rule as the relay).
                for attempt in 0..<2 {
                    let request = attempt == 0 ? prompt : prompt + "\nYour previous reply claimed something you cannot know. Reply again without saying where anything is, whether it is missing, or what you see."
                    let stream = CompanionSessions.shared.take(.chat(arabic: arabic)).streamResponse(to: request,
                        options: GenerationOptions(samplingMode: .greedy, maximumResponseTokens: 90))
                    var text = "", delivered = ""
                    for try await snapshot in stream {
                        try Task.checkCancellation()
                        text = snapshot.content
                        // Show each completed sentence as soon as the whole reply so far passes the checks.
                        if let end = text.lastIndex(where: { ".!?؟".contains($0) }) {
                            let sentence = String(text[...end])
                            if sentence != delivered, acceptableChat(sentence) {
                                if delivered.isEmpty { logger.info("First complete sentence after \(ProcessInfo.processInfo.systemUptime - started, privacy: .public) seconds") }
                                delivered = sentence
                                await onPartial?(sentence)
                            }
                        }
                    }
                    text = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    let kept = acceptableChat(text) ? text : ConversationClaimGuard.supportedText(text)
                    if !kept.isEmpty, acceptableChat(kept) {
                        logger.info("Reply finished after \(ProcessInfo.processInfo.systemUptime - started, privacy: .public) seconds")
                        return LocalImageAnswer(text: kept, status: "On-device conversation.", action: taskAction)
                    }
                }
                return LocalImageAnswer(text: arabic ? "لا أعرف ذلك." : "I don't know that.",
                                        status: "The model's answer could not be verified.", action: taskAction)
            } catch is CancellationError {
                return LocalImageAnswer(text: nil, status: "Conversation interrupted.")
            } catch {
                return LocalImageAnswer(text: nil, status: "The on-device model could not answer.")
            }
        }
        #endif
        return LocalImageAnswer(text: nil, status: arabic ? "نموذج المحادثة غير متاح على هذا الجهاز." : "The on-device conversation model is unavailable on this device.")
    }
    static func status(arabic: Bool) -> String {
        #if BLIND_APPLE_MULTIMODAL && canImport(FoundationModels)
        if #available(iOS 27.0, *) {
            return OnDeviceLanguage.supports(arabic: arabic) ? "On-device image descriptions available; device evaluation pending." : "On-device image model or requested language unavailable."
        }
        return "Image descriptions require iOS 27 or later."
        #else
        return "This build uses Vision evidence descriptions. The iOS 27 image-model adapter is not enabled."
        #endif
    }
    /// `confirmedObjects` are the object groups the phone's detectors agreed on across recent frames
    /// (VisualGrounding). The caller still removes unhedged sentences naming anything else.
    static func describe(image: CVPixelBuffer, question: String, context: SceneContext,
                         situation: [String: Any], wordAllowance: Int, confirmedObjects: [String] = []) async -> LocalImageAnswer {
        guard (1...300).contains(wordAllowance), context.monitoring == "observing" else {
            return LocalImageAnswer(text: nil, status: "Current monitoring does not permit a scene description.")
        }
        #if BLIND_APPLE_MULTIMODAL && canImport(FoundationModels)
        if #available(iOS 27.0, *), OnDeviceLanguage.supports(arabic: context.language == "ar") {
            do {
                // The free built-in model has a ~4,096-token window: the shared compact guide prompt
                // (~600 tokens) plus a situation summary capped near 1,000 tokens.
                guard let data = GuidePrompt.compactSituation(situation) else {
                    return LocalImageAnswer(text: nil, status: "Context exceeds local image-model allowance.")
                }
                let session = LanguageModelSession(instructions: GuidePrompt.instructions(
                    arabic: context.language == "ar", wordAllowance: wordAllowance, requested: context.requested))
                let evidence = try context.json()
                let detected = confirmedObjects.isEmpty ? "none" : confirmedObjects.sorted().joined(separator: ", ")
                let prompt = "Question: \(String(question.prefix(1000)))\nObjects the phone's detectors confirmed: \(detected). Name any other object only with maybe.\nEvidence: \(evidence)\nSituation: \(String(decoding: data, as: UTF8.self))"
                let response = try await session.respond {
                    prompt
                    Attachment(image, orientation: .right)
                }
                try Task.checkCancellation()
                let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty, text.unicodeScalars.count <= AssistantDialogue.maximumTurnScalars else { return LocalImageAnswer(text: nil, status: "Image model returned an unsupported answer.") }
                return LocalImageAnswer(text: text, status: "Described this camera image using the on-device model.")
            } catch is CancellationError {
                return LocalImageAnswer(text: nil, status: "Image description cancelled.")
            } catch {
                return LocalImageAnswer(text: nil, status: "Image model could not answer. Using available Vision evidence.")
            }
        }
        #endif
        return LocalImageAnswer(text: nil, status: status(arabic: context.language == "ar"))
    }
}
