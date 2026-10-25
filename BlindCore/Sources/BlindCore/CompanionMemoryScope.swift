import Foundation

/// Source ownership only, NOT a localization/identity certificate. The native
/// adapter must supply independently established IDs; names, model output and
/// category matches cannot construct a current binding. No geometry is stored.
public struct CompanionMemoryScope: Codable, Equatable, Hashable, Sendable {
    public let map: SpatialMapBinding
    public let placeID: String
    public let floorID: String
    public let roomID: String
    /// Distinguishes two physical fridges even in the same room. Nil is room
    /// scope only and never matches any object-instance scope.
    public let objectInstanceID: String?
    public init?(map: SpatialMapBinding, placeID: String, floorID: String,
                 roomID: String, objectInstanceID: String? = nil) {
        self.map = map; self.placeID = placeID; self.floorID = floorID
        self.roomID = roomID; self.objectInstanceID = objectInstanceID
        guard valid else { return nil }
    }
    public var valid: Bool {
        let values = [map.mapID, map.frameID, map.revision, placeID, floorID, roomID] + (objectInstanceID.map { [$0] } ?? [])
        return values.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.utf8.count <= 128 &&
            !$0.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) }
    }
    /// Collision-free identity for existing dictionary-backed source provenance.
    public var storageKey: String {
        let values = [map.mapID, map.frameID, map.revision, placeID, floorID, roomID]
        return (values + [objectInstanceID == nil ? "room" : "instance", objectInstanceID ?? ""])
            .map { "\($0.utf8.count):\($0)" }.joined()
    }
}

/// Fresh read captured by an already permission/identity-gated native adapter.
/// It is not persisted or minted from a caption. Scope/source IDs alone never
/// establish perception accuracy. Reuse CompanionEvidence freshness rules.
public struct CompanionScopedObservation: Equatable, Sendable {
    public let scope: CompanionMemoryScope
    public let object: String
    public let evidence: CompanionEvidence
    public init(scope: CompanionMemoryScope, object: String, evidence: CompanionEvidence) {
        self.scope = scope; self.object = object; self.evidence = evidence
    }
}

public enum CompanionScopedRecall: Equatable, Sendable {
    case observation(CompanionEvidence)
    case reportedHistory(CompanionFact)
    case unknown

    /// Fresh matching observations outrank reports; stale observations are never
    /// refreshed by retrieval. Historical recall is explicit and stays historical.
    /// Unknown identity never performs a global name-only fallback.
    public static func select(object: String, scope: CompanionMemoryScope?, now: Date,
                              observations: [CompanionScopedObservation], book: CompanionFactBook) -> Self {
        guard let scope, scope.valid else { return .unknown }
        let key = ItemMemory.key(for: object)
        guard !key.isEmpty, object.count <= ItemMemory.nameLimit, object.utf8.count <= 640 else { return .unknown }
        let fact = book.latest(for: object, in: scope)
        let fresh = observations.filter { observation in
            observation.scope == scope && !observation.object.isEmpty && observation.object.count <= ItemMemory.nameLimit && observation.object.utf8.count <= 640 && ItemMemory.key(for: observation.object) == key &&
            observation.evidence.kind == .currentObservation && !observation.evidence.id.isEmpty &&
            observation.evidence.isCurrent(at: now) && !SpatialClaimGuard.containsSpatialClaim(observation.evidence.text) &&
            (fact.map { fact in (observation.evidence.observedAt ?? .distantPast) >= fact.at } ?? true)
        }.max { ($0.evidence.observedAt ?? .distantPast) < ($1.evidence.observedAt ?? .distantPast) }
        if let fresh { return .observation(fresh.evidence) }
        if let fact { return .reportedHistory(fact) }
        return .unknown
    }
}
