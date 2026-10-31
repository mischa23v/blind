import Foundation

/// Inject the platform's established SHA-256 implementation (CryptoKit on iOS).
/// No custom cryptography, network access or fallback hash is provided by Core.
public typealias SpatialMapSHA256 = @Sendable (Data) throws -> String

public struct SpatialMapArtifactIdentity: Codable, Equatable, Sendable {
    public let binding: SpatialMapBinding
    public let sha256: String
    public init(binding: SpatialMapBinding, sha256: String) { self.binding = binding; self.sha256 = sha256 }
}

/// Durable conservative restriction, not a current obstacle observation or clearance.
public struct SpatialBlockedEdge: Codable, Equatable, Hashable, Sendable {
    public let a: String
    public let b: String
    public init(_ edge: MapConnection) { a = edge.a; b = edge.b }
    public var connection: MapConnection { MapConnection(a, b) }
}
public struct SpatialMapRestrictions: Codable, Equatable, Sendable {
    public let binding: SpatialMapBinding
    public let blocked: [SpatialBlockedEdge]
    public let zones: [KeepOutZone]
    public init(binding: SpatialMapBinding, blocked: [SpatialBlockedEdge], zones: [KeepOutZone]) {
        self.binding = binding; self.blocked = blocked; self.zones = zones
    }
    public func contains(_ prior: SpatialMapRestrictions) -> Bool {
        binding == prior.binding && prior.blocked.allSatisfy { blocked.contains($0) } &&
            prior.zones.allSatisfy { zones.contains($0) }
    }
}

/// One durable install commit. Exact map bytes, their identity and the registry are
/// persisted together. Prior artifact digests remain history, not live geometry.
/// No pose, session, route ticket, obstacle observation or localization confidence.
public struct SpatialMapInstallationEnvelope: Codable, Sendable {
    public let schemaVersion: Int
    public let snapshot: SpatialRegistrySnapshot
    public let binding: SpatialMapBinding
    public let mapBytes: Data
    public let artifactHistory: [SpatialMapArtifactIdentity]
    public let restrictions: [SpatialMapRestrictions]
    public init(snapshot: SpatialRegistrySnapshot, binding: SpatialMapBinding, mapBytes: Data,
                artifactHistory: [SpatialMapArtifactIdentity], restrictions: [SpatialMapRestrictions] = []) {
        schemaVersion = 1; self.snapshot = snapshot; self.binding = binding
        self.mapBytes = mapBytes; self.artifactHistory = artifactHistory; self.restrictions = restrictions
    }
}

public enum SpatialInstallationError: Error, Equatable {
    case invalidEnvelope, invalidDigest, artifactMismatch, historyRewrite, noInstalledMap
}

/// Immutable validated bytes and decoded geometry. Copying map returns a value, not
/// mutable access to the installed geometry. Hash association is not map accuracy,
/// physical alignment, publisher authentication or clearance certification.
public struct SpatialMapInstallation: Sendable {
    public static let maximumEnvelopeBytes = 4_000_000
    public static let maximumMapBytes = 2_000_000
    public let envelope: SpatialMapInstallationEnvelope
    public let registry: SpatialFrameRegistry
    public let map: IndoorMap
    public let artifact: SpatialMapArtifactIdentity
    public var binding: SpatialMapBinding { envelope.binding }

    public init(envelope: SpatialMapInstallationEnvelope, sha256: SpatialMapSHA256) throws {
        guard envelope.schemaVersion == 1, !envelope.mapBytes.isEmpty,
              envelope.mapBytes.count <= Self.maximumMapBytes,
              envelope.artifactHistory.count <= 10_000,
              Set(envelope.artifactHistory.map(\.binding)).count == envelope.artifactHistory.count else {
            throw SpatialInstallationError.invalidEnvelope
        }
        let registry = try SpatialFrameRegistry(snapshot: envelope.snapshot)
        let known = Set(envelope.snapshot.maps.map(\.binding))
        guard envelope.artifactHistory.allSatisfy({ known.contains($0.binding) && Self.validDigest($0.sha256) }),
              let artifact = envelope.artifactHistory.first(where: { $0.binding == envelope.binding }) else {
            throw SpatialInstallationError.invalidDigest
        }
        let digest = try sha256(envelope.mapBytes)
        guard Self.validDigest(digest), digest == artifact.sha256 else { throw SpatialInstallationError.artifactMismatch }
        let map = try JSONDecoder().decode(IndoorMap.self, from: envelope.mapBytes)
        try registry.validateIndoorMap(map, for: envelope.binding)
        try Self.validateRestrictions(envelope.restrictions, snapshot: envelope.snapshot, activeMap: map, binding: envelope.binding)
        self.envelope = envelope; self.registry = registry; self.map = map; self.artifact = artifact
        _ = try encoded() // Enforce the combined history/geometry size before installation.
    }
    public init(data: Data, sha256: SpatialMapSHA256) throws {
        guard !data.isEmpty, data.count <= Self.maximumEnvelopeBytes else { throw SpatialInstallationError.invalidEnvelope }
        try self.init(envelope: JSONDecoder().decode(SpatialMapInstallationEnvelope.self, from: data), sha256: sha256)
    }
    /// Uses standard Foundation encoding. The resulting exact bytes are persisted
    /// and hashed, never re-encoded on restore to guess an original artifact hash.
    public static func canonicalMapBytes(_ map: IndoorMap) throws -> Data {
        try map.validate()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let bytes = try encoder.encode(map)
        guard bytes.count <= maximumMapBytes else { throw SpatialInstallationError.invalidEnvelope }
        return bytes
    }
    /// Local pairing reference, NOT a navigation map. Actual paired bytes must
    /// match the capture-owned descriptor; no names/story/GPS or transform guesses.
    /// Native caller already checks the archived origin anchor and decodes RoomPlan.
    /// Run hashing/encoding on the existing bounded utility worker, not AR callbacks.
    public static func localSavedFrameReference(frame: SavedWorldFrame,
        worldMapBytes: Data, roomCaptureBytes: Data, sha256: SpatialMapSHA256) throws -> SpatialMapInstallation {
        guard frame.valid, !worldMapBytes.isEmpty, worldMapBytes.count <= 32 * 1024 * 1024,
              !roomCaptureBytes.isEmpty, roomCaptureBytes.count <= 8 * 1024 * 1024,
              try frame.matches(worldMapSHA256: sha256(worldMapBytes), roomCaptureSHA256: sha256(roomCaptureBytes))
        else { throw SpatialInstallationError.artifactMismatch }
        let place = "private-place:" + frame.placeID
        let binding = SpatialMapBinding(mapID: "local-saved-" + frame.placeID.lowercased(),
            frameID: frame.frameID, revision: frame.revision)
        let record = SpatialMapRevision(binding: binding, nodeID: place, metersPerUnit: 1,
            floorLevels: [:], savedWorldFrame: frame)
        // This is a private catalog namespace, not geographic/building assignment.
        let snapshot = SpatialRegistrySnapshot(nodes: [
            .init(id: "private-saved-world", kind: .world),
            .init(id: place, kind: .place, parentID: "private-saved-world")],
            maps: [record], activeBindings: [binding])
        var map = IndoorMap(name: "Local saved-frame reference; no route or floor assignment", nodes: [], edges: [])
        map.purpose = .localizationReferenceOnly
        map.packageID = binding.mapID; map.packageRevision = binding.revision
        let bytes = try canonicalMapBytes(map)
        return try .init(envelope: .init(snapshot: snapshot, binding: binding, mapBytes: bytes,
            artifactHistory: [.init(binding: binding, sha256: try sha256(bytes))]), sha256: sha256)
    }
    public func encoded() throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let bytes = try encoder.encode(envelope)
        guard bytes.count <= Self.maximumEnvelopeBytes else { throw SpatialInstallationError.invalidEnvelope }
        return bytes
    }
    public func validateReplacement(of previous: SpatialMapInstallation) throws {
        var previousRegistry = previous.registry
        try previousRegistry.update(snapshot: envelope.snapshot)
        guard previous.envelope.artifactHistory.allSatisfy({ envelope.artifactHistory.contains($0) }),
              previous.envelope.restrictions.allSatisfy({ prior in
                  envelope.restrictions.contains(where: { $0.contains(prior) })
              }) else {
            throw SpatialInstallationError.historyRewrite
        }
    }
    public var currentRestrictions: SpatialMapRestrictions {
        envelope.restrictions.first(where: { $0.binding == binding }) ?? .init(binding: binding, blocked: [], zones: [])
    }
    /// Adds immutable conservative restrictions without changing the geometry frame
    /// or invalidating its accepted pose. The owner persists this envelope atomically.
    public func addingRestrictions(blocked: Set<MapConnection>, zones: [KeepOutZone]) throws -> SpatialMapInstallation {
        let previous = currentRestrictions
        var combinedZones = previous.zones
        for zone in zones {
            if let existing = combinedZones.first(where: { $0.id == zone.id }) {
                guard existing == zone else { throw SpatialInstallationError.historyRewrite }
            } else { combinedZones.append(zone) }
        }
        let edges = Set(previous.blocked).union(blocked.map(SpatialBlockedEdge.init)).sorted {
            ($0.a, $0.b) < ($1.a, $1.b)
        }
        let updated = SpatialMapRestrictions(binding: binding, blocked: edges, zones: combinedZones)
        let restrictions = envelope.restrictions.filter { $0.binding != binding } + [updated]
        try Self.validateRestrictions(restrictions, snapshot: registry.snapshot, activeMap: map, binding: binding)
        let envelope = SpatialMapInstallationEnvelope(snapshot: registry.snapshot, binding: binding,
            mapBytes: self.envelope.mapBytes, artifactHistory: self.envelope.artifactHistory, restrictions: restrictions)
        let result = SpatialMapInstallation(envelope: envelope, registry: registry, map: map, artifact: artifact)
        _ = try result.encoded(); return result
    }
    private init(envelope: SpatialMapInstallationEnvelope, registry: SpatialFrameRegistry,
                 map: IndoorMap, artifact: SpatialMapArtifactIdentity) {
        self.envelope = envelope; self.registry = registry; self.map = map; self.artifact = artifact
    }
    private static func validateRestrictions(_ restrictions: [SpatialMapRestrictions], snapshot: SpatialRegistrySnapshot,
                                             activeMap: IndoorMap, binding: SpatialMapBinding) throws {
        guard restrictions.count <= 10_000, Set(restrictions.map(\.binding)).count == restrictions.count else {
            throw SpatialInstallationError.invalidEnvelope
        }
        for record in restrictions {
            guard let map = snapshot.maps.first(where: { $0.binding == record.binding }),
                  record.blocked.count <= 10_000, Set(record.blocked).count == record.blocked.count,
                  record.zones.count <= 500, Set(record.zones.map(\.id)).count == record.zones.count,
                  record.zones.allSatisfy({ $0.valid && map.floorLevels[$0.level] != nil }),
                  record.blocked.allSatisfy({ !$0.a.isEmpty && !$0.b.isEmpty && $0.a <= $0.b }) else {
                throw SpatialInstallationError.invalidEnvelope
            }
            if record.binding == binding {
                let nodes = Set(activeMap.nodes.map(\.id)), staticIDs = Set((activeMap.keepOutZones ?? []).map(\.id))
                guard record.blocked.allSatisfy({ nodes.contains($0.a) && nodes.contains($0.b) }),
                      record.zones.allSatisfy({ !staticIDs.contains($0.id) }) else { throw SpatialInstallationError.invalidEnvelope }
            }
        }
    }
    private static func validDigest(_ digest: String) -> Bool {
        digest.utf8.count == 64 && digest.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }
}
