import Foundation
import UIKit
import Security
import BlindCore

enum SceneClientError: LocalizedError {
    case configuration, server, invalidReply
    var errorDescription: String? {
        switch self {
        case .configuration: return "Configure an HTTPS scene service and its access token in Settings."
        case .server: return "The scene service could not answer."
        case .invalidReply: return "The scene service returned an unreadable answer."
        }
    }
}
enum TokenStore {
    private static let account = "scene-relay"
    static func read() -> String {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrService as String: "BlindAssist", kSecAttrAccount as String: account,
                                   kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
    static func save(_ value: String) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrService as String: "BlindAssist", kSecAttrAccount as String: account]
        SecItemDelete(query as CFDictionary)
        guard !value.isEmpty else { return }
        var add = query; add[kSecValueData as String] = Data(value.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }
}
// The photo-sending client exists only in developer comparison builds (privacy rule).
#if BLIND_DEVELOPER_CLOUD
struct SceneQuestionClient {
    var endpoint: String
    var token: String
    func ask(question: String, jpeg: Data, context: SceneContext, focus: String, situation: [String: Any], wordAllowance: Int) async throws -> String {
        guard let url = URL(string: endpoint), url.scheme == "https", url.host != nil,
              !token.isEmpty else { throw SceneClientError.configuration }
        var request = URLRequest(url: url.appendingPathComponent("v1/scene"))
        request.httpMethod = "POST"; request.timeoutInterval = 20
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let now = ProcessInfo.processInfo.systemUptime
        let evidence: [String: Any] = ["version": 1, "motion": context.motion, "monitoring": context.monitoring, "situation": situation,
            "observations": context.observations.compactMap { item -> [String: Any]? in
                let age = (now - item.capturedAt) * 1000
                guard age >= 0, age <= 3000 else { return nil }
                return ["id": item.id, "kind": item.kind.rawValue, "text": item.text, "confidence": item.confidence, "ageMS": age]
            }]
        request.httpBody = try JSONSerialization.data(withJSONObject: ["question": String(question.prefix(1000)),
            "image": "data:image/jpeg;base64,\(jpeg.base64EncodedString())", "language": context.language,
            "detail": context.detail, "focus": focus, "context": evidence, "wordAllowance": wordAllowance])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw SceneClientError.server }
        struct Reply: Decodable { var answer: String }
        guard data.count <= 32_000, let result = try? JSONDecoder().decode(Reply.self, from: data),
              !result.answer.isEmpty, result.answer.unicodeScalars.count <= AssistantDialogue.maximumTurnScalars else { throw SceneClientError.invalidReply }
        return result.answer
    }
    func checkConnection() async throws -> Bool {
        guard let url = URL(string: endpoint), url.scheme == "https", url.host != nil, !token.isEmpty else { throw SceneClientError.configuration }
        var request = URLRequest(url: url.appendingPathComponent("v1/status")); request.timeoutInterval = 8
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw SceneClientError.server }
        struct Status: Decodable { var sceneConfigured: Bool }
        return try JSONDecoder().decode(Status.self, from: data).sceneConfigured
    }
}
#endif

enum OfflineSummary {
    static func status(arabic: Bool) -> String {
        if OnDeviceLanguage.supports(arabic: arabic) { return arabic ? "النموذج المحلي يدعم العربية على هذا الجهاز." : "On-device language model supports English on this device." }
        return arabic ? "النموذج المحلي لا يدعم العربية حالياً على هذا الجهاز. سنستخدم عبارات عربية جاهزة من المعلومات المرصودة." : "On-device language model unavailable for English; using evidence templates."
    }
    static func summarize(_ context: SceneContext, question: String, dialogue: AssistantDialogue, preferences: AssistantPreferences = AssistantPreferences(), modelContext: CompanionModelContext) async -> String {
        guard let json = try? context.json() else { return context.fallback }
        let interests = preferences.interests.map { "\($0.category): \($0.value)" }.joined(separator: "\n")
        let modes = AssistantPreferences.categories.map { "\($0): \(preferences.mode(for: $0))" }.joined(separator: ", ")
        let result = await OnDeviceLanguage.select(instructions: AssistantPrompts.observations,
            prompt: "Evidence: \(json)\nOrdinary delivery modes: \(modes). Muted categories require a specific question about that category.",
            maximumIDs: context.observations.count, arabic: context.language == "ar", modelContext: modelContext,
            latest: question.isEmpty ? "Select useful observations for the current task." : question,
            optionalContext: [.init("userStatedInterestsNotEvidence", [interests]),
                              .init("priorDialogueNotEvidence", dialogue.turns.suffix(4).map { "\($0.role): \($0.text)" })])
        return context.rendering(ids: result.ids)
    }
    static func destination(_ context: MapContext, question: String, arabic: Bool, modelContext: CompanionModelContext) async -> String? {
        guard let json = try? context.json() else { return nil }
        let result = await OnDeviceLanguage.select(instructions: AssistantPrompts.destination,
            prompt: "Map context: \(json)", maximumIDs: 1, arabic: arabic, modelContext: modelContext, latest: question)
        return result.ids.count == 1 ? context.acceptedID(result.ids[0]) : nil
    }
}
