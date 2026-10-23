import Foundation
import XCTest
import CryptoKit
import BlindCore
@testable import BlindAssist

/// Opt-in app-hosted replay of the real conversation/context/tool/stream path.
/// Fixtures replace sensor reads only in this test, never the running app.
/// No oracle, expected answer or scoring rule is passed to the model.
final class CompanionNativeReplayTests: XCTestCase {
    struct Packet: Decodable { let episodes: [Episode] }
    struct Episode: Decodable {
        let id: String
        let user: String
        var language: String?
        var preferredName: String?
        var audience: String?
        var goal: String?
        var priorUserReports: [String]?
        var receipts: [Receipt]?
    }
    struct Receipt: Decodable, Sendable {
        let capability: String
        var text: String?
        var amount: Int?
        var ageSeconds: Double?
    }
    actor Calls {
        var values: [String] = []
        func record(_ value: String) { values.append(value) }
        func all() -> [String] { values }
    }
    @MainActor func testInputOnlyConversationBatch() async throws {
        guard let input = ProcessInfo.processInfo.environment["BLIND_COMPANION_REPLAY_INPUT"],
              let output = ProcessInfo.processInfo.environment["BLIND_COMPANION_REPLAY_OUTPUT"] else {
            throw XCTSkip("Set input/output paths in the test scheme environment to run the frozen input-only packet.")
        }
        guard OnDeviceLanguage.available else { throw XCTSkip("FoundationModels unavailable. This is not a passing model evaluation.") }
        let bytes = try Data(contentsOf: URL(fileURLWithPath: input))
        guard bytes.count <= 1_000_000 else { XCTFail("Input exceeds replay bound"); return }
        let packet = try JSONDecoder().decode(Packet.self, from: bytes)
        guard (1...500).contains(packet.episodes.count), Set(packet.episodes.map(\.id)).count == packet.episodes.count else { XCTFail("Invalid episode count"); return }
        var results: [[String: Any]] = []
        for episode in packet.episodes {
            let arabic = episode.language == "ar"
            guard OnDeviceLanguage.supports(arabic: arabic) else {
                results.append(["id": episode.id, "status": "requested_language_unsupported", "pipelineInvoked": false]); continue
            }
            var dialogue = AssistantDialogue(), state = CompanionWorkingState()
            state.changeGoal(episode.goal ?? "")
            for report in (episode.priorUserReports ?? []).suffix(12) {
                state.record(report); dialogue.record(role: "user", text: report)
            }
            state.record(episode.user); state.ingestDirectActionReport(episode.user)
            dialogue.record(role: "user", text: episode.user)
            let context = try CompanionModelContext(preferredName: episode.preferredName ?? "",
                audience: AssistantAudience(rawValue: episode.audience ?? "general") ?? .general,
                currentGoal: state.goal, goalRevision: state.goalRevision)
            let receipts = episode.receipts ?? [], calls = Calls()
            let available = Set(receipts.compactMap { CompanionToolKind(rawValue: $0.capability) })
            let started = Date()
            let answer = await LocalImageAssistant.converse(dialogue: dialogue, arabic: arabic,
                audience: context.audience, workingState: state, modelContext: context,
                availableTools: available, toolExecutor: { request in
                    await calls.record(request.kind.rawValue + ":" + request.query)
                    let records = receipts.filter { $0.capability == request.kind.rawValue }.compactMap { receipt -> CompanionEvidence? in
                        let at = Date().addingTimeInterval(-max(0, receipt.ageSeconds ?? 0))
                        switch request.kind {
                        case .saudiBanknote:
                            guard let value = receipt.amount else { return nil }
                            return CompanionCapabilityEvidence.make(.saudiBanknote(value), capturedAt: at, arabic: arabic)
                        case .isolatedColor:
                            guard let value = receipt.text.flatMap(ClothingColor.Name.init(rawValue:)) else { return nil }
                            return CompanionCapabilityEvidence.make(.isolatedColor(value), capturedAt: at, arabic: arabic)
                        case .familiarPeople:
                            guard let value = receipt.text else { return nil }
                            return CompanionCapabilityEvidence.make(.familiarPerson(value), capturedAt: at, arabic: arabic)
                        case .readText, .currentObservation:
                            guard let value = receipt.text else { return nil }
                            return CompanionCapabilityEvidence.make(.text(value), capturedAt: at, arabic: arabic)
                        case .savedMemory, .navigationState:
                            guard let value = receipt.text else { return nil }
                            return CompanionEvidence(kind: .historicalMemory, text: value, source: "scripted replay historical record", observedAt: at)
                        case .deviceClock: return nil // Real clock has separate production tests; never invent fixture time.
                        }
                    }
                    return CompanionToolResult(status: records.isEmpty ? .unavailable : .success,
                        source: "scripted replay adapter; not real sensor", evidence: records)
                })
            if let update = answer.taskUpdate { state.apply(update, latest: episode.user) }
            results.append(["id": episode.id, "reply": answer.text ?? "", "status": answer.status,
                "toolCalls": await calls.all(), "goal": state.goal, "proposedStep": state.proposedStep,
                "reportedCompletedStepsNotVerified": state.reportedCompletedSteps,
                "latencyMS": Int(Date().timeIntervalSince(started) * 1000), "pipelineInvoked": true])
        }
        let result: [String: Any] = ["path": "LocalImageAssistant.converse production context and tool runtime",
            "sensorInput": "scripted receipts only", "deviceAcceptance": false,
            "inputSHA256": SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined(),
            "operatingSystem": ProcessInfo.processInfo.operatingSystemVersionString,
            "sourceRevision": ProcessInfo.processInfo.environment["BLIND_REPLAY_SOURCE_REVISION"] ?? "unrecorded",
            "results": results]
        try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            .write(to: URL(fileURLWithPath: output), options: .atomic)
    }
}
