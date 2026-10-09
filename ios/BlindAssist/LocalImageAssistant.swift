import Foundation
import CoreVideo
import ImageIO
import BlindCore
#if canImport(FoundationModels)
import FoundationModels
#endif

struct LocalImageAnswer { let text: String?; let status: String }

/// Thin adapter for Apple's documented Attachment / LanguageModelSession API.
/// Compile the image path with an iOS 27 SDK; no remote model is selected here.
enum LocalImageAssistant {
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
    static func describe(image: CVPixelBuffer, question: String, context: SceneContext,
                         situation: [String: Any], wordAllowance: Int) async -> LocalImageAnswer {
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
                let prompt = "Question: \(String(question.prefix(1000)))\nEvidence: \(evidence)\nSituation: \(String(decoding: data, as: UTF8.self))"
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
