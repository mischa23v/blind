import Foundation

/// Explicit routing ownership, not measured location. Selection epoch changes even
/// when a user returns to a previously selected owner with the same map/session.
public struct NativeLocalizationSelection: Equatable, Sendable {
    public enum Kind: String, Sendable { case connectedJourney, registeredPreview, localSavedFrameReference }
    public let kind: Kind
    public let epoch: UUID
    public let goalRevision: UUID?
    public init(kind: Kind, epoch: UUID = UUID(), goalRevision: UUID? = nil) {
        self.kind = kind; self.epoch = epoch; self.goalRevision = goalRevision
    }
}

/// Immutable exact context supplied by the actual route owner, never selected map
/// metadata from a different owner. It conveys no sensor/accuracy authority.
public struct NativeLocalizationRouteContext: Equatable, Sendable {
    public enum Scope: Equatable, Sendable { case route, localSavedFrameReference }
    public let scope: Scope
    public let sessionID: UUID
    public let artifact: SpatialMapArtifactIdentity
    public let revision: SpatialMapRevision
    public let goalRevision: UUID?
    public init(sessionID: UUID, artifact: SpatialMapArtifactIdentity,
                revision: SpatialMapRevision, goalRevision: UUID?, scope: Scope = .route) {
        self.scope = scope
        self.sessionID = sessionID; self.artifact = artifact
        self.revision = revision; self.goalRevision = goalRevision
    }
}
