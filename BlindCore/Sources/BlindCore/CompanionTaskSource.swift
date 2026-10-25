import Foundation

/// Code-owned provenance for a requested goal. A canonical/display label is not
/// the person's words. This receipt is neither completion nor motion authority.
public struct CompanionTaskSource: Codable, Equatable, Sendable {
    public let originalRequest: String
    public let canonicalLabel: String
    /// Leaves room for the saved-memory tool's five-character "task:" namespace.
    public let sourceID: String
    public let recordedAt: Date?

    /// `originalRequest` must be the complete trusted user turn, never model text.
    /// A missing legacy source remains missing; do not reconstruct one from a label.
    public init?(originalRequest: String, canonicalLabel: String, sourceID: String, recordedAt: Date? = nil) {
        guard Self.valid(originalRequest, limit: AssistantDialogue.maximumTurnScalars),
              Self.valid(canonicalLabel, limit: 300), Self.valid(sourceID, limit: 75),
              recordedAt.map({ $0.timeIntervalSinceReferenceDate.isFinite && $0 >= .distantPast && $0 <= .distantFuture }) ?? true else { return nil }
        self.originalRequest = originalRequest
        self.canonicalLabel = canonicalLabel
        self.sourceID = sourceID
        self.recordedAt = recordedAt
    }

    public var memoryNote: CompanionMemoryNote {
        CompanionMemoryNote(id: sourceID, subject: canonicalLabel, text: originalRequest,
            source: "original user goal request, not completed action", recordedAt: recordedAt)
    }

    private static func valid(_ value: String, limit: Int) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && value.unicodeScalars.count <= limit &&
        !value.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) && $0 != "\n" && $0 != "\t" }
    }

    private enum CodingKeys: String, CodingKey { case originalRequest, canonicalLabel, sourceID, recordedAt }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        guard let valid = Self(originalRequest: try values.decode(String.self, forKey: .originalRequest),
            canonicalLabel: try values.decode(String.self, forKey: .canonicalLabel),
            sourceID: try values.decode(String.self, forKey: .sourceID),
            recordedAt: try values.decodeIfPresent(Date.self, forKey: .recordedAt)) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid task source"))
        }
        self = valid
    }
}

/// Exact, code-bound location report supplied by the current task/fact store.
/// Do not infer a pronoun's object from a retrieval subset: a missing intervening
/// cup/keys turn would otherwise silently change the referent.
public struct CompanionLocationReport: Codable, Equatable, Sendable {
    public let id: String
    public let object: String
    public let originalReport: String
    public let recordedAt: Date?
    public let scope: CompanionMemoryScope?

    public init?(id: String, object: String, originalReport: String, recordedAt: Date? = nil, scope: CompanionMemoryScope? = nil) {
        guard scope?.valid != false, !id.isEmpty, id.count <= 80, !object.isEmpty, object.count <= ItemMemory.nameLimit,
              !originalReport.isEmpty, originalReport.count <= 500,
              recordedAt.map({ $0.timeIntervalSinceReferenceDate.isFinite && $0 >= .distantPast && $0 <= .distantFuture }) ?? true,
              case .report(let named, _, _, _)? = CompanionUtterance.parse(originalReport),
              named.map({ ItemMemory.key(for: $0) == ItemMemory.key(for: object) }) ?? true else { return nil }
        self.id = id; self.object = object; self.originalReport = originalReport; self.recordedAt = recordedAt; self.scope = scope
    }

    private enum CodingKeys: String, CodingKey { case id, object, originalReport, recordedAt, scope }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        guard let valid = Self(id: try values.decode(String.self, forKey: .id),
            object: try values.decode(String.self, forKey: .object),
            originalReport: try values.decode(String.self, forKey: .originalReport),
            recordedAt: try values.decodeIfPresent(Date.self, forKey: .recordedAt),
            scope: try values.decodeIfPresent(CompanionMemoryScope.self, forKey: .scope)) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid location report"))
        }
        self = valid
    }
}
