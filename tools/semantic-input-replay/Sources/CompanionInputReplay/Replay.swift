import Foundation
import BlindCore

struct Packet: Decodable { let episodes: [Episode] }
struct Episode: Decodable {
    let id: String; let user: String
    var language: String?; var preferredName: String?; var audience: String?; var goal: String?
    var priorUserReports: [String]?; var receipts: [Receipt]?
}
struct Receipt: Decodable, Sendable {
    let capability: String; var text: String?; var amount: Int?; var ageSeconds: Double?
}
@main struct Replay {
    static func main() async throws {
        guard CommandLine.arguments.count == 3 else { fatalError("Usage: CompanionInputReplay input.json output.json") }
        let bytes = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
        guard bytes.count <= 1_000_000 else { fatalError("Input exceeds byte bound") }
        let packet = try JSONDecoder().decode(Packet.self, from: bytes)
        guard (1...500).contains(packet.episodes.count), Set(packet.episodes.map(\.id)).count == packet.episodes.count else { fatalError("Invalid episode count or duplicate IDs") }
        var results: [[String: Any]] = []
        for episode in packet.episodes {
            do {
                let arabic = episode.language == "ar"
                let context = try CompanionModelContext(preferredName: episode.preferredName ?? "",
                    audience: AssistantAudience(rawValue: episode.audience ?? "general") ?? .general,
                    currentGoal: episode.goal ?? "", goalRevision: "replay:" + episode.id)
                var actions = CompanionActionProgressLedger()
                let receipt = actions.ingestUserReport(episode.user, sourceID: episode.id, goalRevision: "replay:" + episode.id)
                let instructions = ProductionConversationPrompt.conversationInstructions(arabic: arabic, audience: context.audience)
                let plan = try ContextWindowPolicy.makePrompt(latest: episode.user, instructions: instructions,
                    mandatoryFields: context.mandatoryFields + actions.contextFields(goalRevision: "replay:" + episode.id),
                    fields: [.init("priorUserReportsNotVerified", episode.priorUserReports ?? [])], reduced: false)
                let supplied = episode.receipts ?? []
                let available = Set(supplied.compactMap { CompanionToolKind(rawValue: $0.capability) })
                let runtime = CompanionToolRuntime(available: available) { request in
                    let records = supplied.filter { $0.capability == request.kind.rawValue }.compactMap { value -> CompanionEvidence? in
                        let at = Date().addingTimeInterval(-max(0, value.ageSeconds ?? 0))
                        switch request.kind {
                        case .saudiBanknote:
                            return value.amount.flatMap { CompanionCapabilityEvidence.make(.saudiBanknote($0), capturedAt: at, arabic: arabic) }
                        case .isolatedColor:
                            guard let color = value.text.flatMap(ClothingColor.Name.init(rawValue:)) else { return nil }
                            return CompanionCapabilityEvidence.make(.isolatedColor(color), capturedAt: at, arabic: arabic)
                        case .familiarPeople:
                            return value.text.flatMap { CompanionCapabilityEvidence.make(.familiarPerson($0), capturedAt: at, arabic: arabic) }
                        case .readText, .currentObservation:
                            return value.text.flatMap { CompanionCapabilityEvidence.make(.text($0), capturedAt: at, arabic: arabic) }
                        case .savedMemory, .navigationState:
                            return value.text.map { CompanionEvidence(kind: .historicalMemory, text: $0, source: "scripted replay historical record", observedAt: at) }
                        case .deviceClock: return nil
                        }
                    }
                    return CompanionToolResult(status: records.isEmpty ? .unavailable : .success,
                        source: "scripted replay adapter; not real sensor", evidence: records)
                }
                var reads: [[String: Any]] = []
                // These are scripted invocations, NOT inferred/model-selected calls.
                for kind in available.sorted(by: { $0.rawValue < $1.rawValue }) {
                    let result = await runtime.run(.init(kind: kind, query: episode.user))
                    let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(result))
                    reads.append(["kind": kind.rawValue, "result": object])
                }
                results.append(["id": episode.id, "status": "adapter_executed", "prompt": plan.prompt,
                    "instructions": instructions, "scriptedToolReads": reads,
                    "modelResponseAllowed": ConversationDomainPolicy.allowsModelResponse(to: episode.user),
                    "actionReportAccepted": receipt.acceptedReport != nil])
            } catch {
                results.append(["id": episode.id, "status": "input_or_context_rejected", "error": String(describing: error)])
            }
        }
        let output: [String: Any] = ["path": "actual Core context policy and bounded tool runtime with scripted adapters",
            "modelExecuted": false, "recognitionExecuted": false, "deviceAcceptance": false,
            "dispatch": "scripted available kinds, not semantic model selection", "results": results]
        try JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys]).write(to: URL(fileURLWithPath: CommandLine.arguments[2]), options: .atomic)
    }
}
