import Foundation

/// Fresh measured support-height association in the same map as the pose. Camera Y
/// is not floor Y. A caller must supply the actual calibrated measurement, not a
/// route node's height or a default. This type is intentionally not Codable.
public struct SpatialFloorSupport: Equatable, Sendable {
    public let binding: SpatialMapBinding
    public let floorID: String
    public let sessionID: UUID
    public let captureID: UUID
    public let height: Double
    public let capturedAt: Double
    public init(binding: SpatialMapBinding, floorID: String, sessionID: UUID, captureID: UUID,
                height: Double, capturedAt: Double) {
        self.binding = binding; self.floorID = floorID; self.sessionID = sessionID
        self.captureID = captureID; self.height = height; self.capturedAt = capturedAt
    }
}

/// Stored-geometry route result, NOT proof a real-world path is clear. Sensor hazard
/// and target-specific delivery gates remain independent. Only the route owner can
/// mint this immutable ticket after validating the current leg and capture.
public struct SpatialRouteTicket: Sendable {
    public let target: MapNode
    public let currentFloorPoint: Point3
    public let bodyYaw: Double
    public let positionUncertainty: Double
    public let headingUncertainty: Double
    public let spatial: SpatialOutputLease
    public let routeID: UUID
    public let goalRevision: UUID
    public let bodyRevision: UUID
    public let obstacleRevision: UUID
    public let artifactSHA256: String
    fileprivate let support: SpatialFloorSupport
    fileprivate init(target: MapNode, currentFloorPoint: Point3, bodyYaw: Double,
                     positionUncertainty: Double, headingUncertainty: Double, spatial: SpatialOutputLease, routeID: UUID, goalRevision: UUID,
                     bodyRevision: UUID, obstacleRevision: UUID, artifactSHA256: String,
                     support: SpatialFloorSupport) {
        self.target = target; self.currentFloorPoint = currentFloorPoint; self.bodyYaw = bodyYaw
        self.positionUncertainty = positionUncertainty; self.headingUncertainty = headingUncertainty
        self.spatial = spatial; self.routeID = routeID; self.goalRevision = goalRevision
        self.bodyRevision = bodyRevision; self.obstacleRevision = obstacleRevision
        self.artifactSHA256 = artifactSHA256; self.support = support
    }
    /// Same uncertainty-disk tangency used by ObservedObjectMemory's recorded
    /// orientation guard, applied to the existing eight 45-degree beacon bins.
    /// These are map-relative geometry bounds, not physical-map accuracy proof.
    public func directionalCue() -> (sector: Int, distance: Double)? {
        let dx = target.position.x - currentFloorPoint.x, dz = target.position.z - currentFloorPoint.z
        let distance = hypot(dx, dz)
        guard distance.isFinite, distance > positionUncertainty,
              positionUncertainty.isFinite, positionUncertainty >= 0,
              headingUncertainty.isFinite, headingUncertainty >= 0 else { return nil }
        let fx = -sin(bodyYaw), fz = -cos(bodyYaw)
        let angle = atan2(-dx * fz + dz * fx, dx * fx + dz * fz)
        let binWidth = Double.pi / 4
        let rounded = (angle / binWidth).rounded()
        let deviation = abs(atan2(sin(angle - rounded * binWidth), cos(angle - rounded * binWidth)))
        let angularError = asin(positionUncertainty / distance) + headingUncertainty
        // Strict inequality withholds intervals touching or crossing a boundary.
        guard angle.isFinite, angularError.isFinite, deviation + angularError < binWidth / 2 else { return nil }
        return ((Int(rounded) + 8) % 8, distance)
    }
}

public enum SpatialRouteError: Error, Equatable {
    case invalidBody, staleGoal, noRoute, unsupportedTransition, missingSupport, blockedLeg, staleTicket, offRoute, ambiguousDirection, unpersistedRestrictions
}

/// Single-owner app adapter around the existing registry, lease, planner and collision
/// grid. No SLAM, planner, database or hazard detector is implemented here. An app
/// should isolate this value to one actor and publish it as one installation state.
public struct SpatialRouteOwner: Sendable {
    public private(set) var installation: SpatialMapInstallation?
    public private(set) var route: [MapNode] = []
    public private(set) var waypointIndex = 0
    public private(set) var goalRevision: UUID?
    public private(set) var body: BodyEnvelope
    public private(set) var routeID = UUID()
    public private(set) var bodyRevision = UUID()
    public private(set) var obstacleRevision = UUID()
    public private(set) var restrictionsDurable = true
    private var localization: SpatialLocalizationLease
    private var blocked = Set<MapConnection>()
    private var obstacleZones: [KeepOutZone] = []
    public var sessionID: UUID { localization.sessionID }

    public init(body: BodyEnvelope, limits: SpatialLocalizationLimits) throws {
        guard body.valid else { throw SpatialRouteError.invalidBody }
        self.body = body; localization = SpatialLocalizationLease(limits: limits)
    }
    /// The supplied persistence closure must atomically replace one protected local
    /// file/record. Validate and encode first, publish only after persistence succeeds.
    /// Throwing preserves the complete previous map/pose/route state in memory.
    public mutating func install(_ candidate: SpatialMapInstallation,
                                 persist: (Data) throws -> Void) throws {
        if let installation { try candidate.validateReplacement(of: installation) }
        let bytes = try candidate.encoded()
        try persist(bytes)
        installation = candidate
        blocked = Set(candidate.currentRestrictions.blocked.map(\.connection)); obstacleZones = candidate.currentRestrictions.zones
        restrictionsDurable = true; obstacleRevision = UUID()
        localization.restart(); cancelRoute()
    }
    /// Restoration is read-only and always starts with unknown live pose. The caller
    /// must use only the atomic local installation record, never a previous ticket.
    public mutating func restore(_ data: Data, sha256: SpatialMapSHA256) throws {
        guard installation == nil else { throw SpatialInstallationError.historyRewrite }
        let restored = try SpatialMapInstallation(data: data, sha256: sha256)
        installation = restored
        blocked = Set(restored.currentRestrictions.blocked.map(\.connection)); obstacleZones = restored.currentRestrictions.zones
        restrictionsDurable = true; obstacleRevision = UUID()
        localization.restart(); cancelRoute()
    }
    public mutating func accept(_ capture: SpatialLocalizationCapture, now: Double) throws {
        guard let installation else { throw SpatialInstallationError.noInstalledMap }
        // Accept only the installed artifact, not another active registry map whose
        // geometry has not been atomically loaded into this owner.
        guard capture.binding == installation.binding else {
            localization.loseTracking(); throw SpatialRegistryError.invalidCapture
        }
        try localization.accept(capture, registry: installation.registry, now: now)
    }
    public func currentPose(now: Double) -> SpatialLocalizationCapture? {
        guard let installation else { return nil }
        return localization.current(registry: installation.registry, now: now)
    }
    public mutating func loseTracking() { localization.loseTracking(); cancelRoute() }
    public mutating func setGoal(revision: UUID) {
        guard goalRevision != revision else { return }
        goalRevision = revision; cancelRoute() // No map, pose or independent hazard reset.
    }
    public mutating func cancelRoute() { routeID = UUID(); route = []; waypointIndex = 0 }
    public mutating func setBody(_ next: BodyEnvelope) throws {
        guard next.valid else { throw SpatialRouteError.invalidBody }
        guard next != body else { return }
        body = next; bodyRevision = UUID(); cancelRoute()
    }
    /// Restriction-only updates: delayed empty observations cannot reopen a closed
    /// path. Zone IDs are immutable within this installation; removal/replacement
    /// requires a separately owned fresh-evidence protocol, not implemented here.
    /// These restrictions do not assert live obstacle presence or general clearance.
    public mutating func addRestrictions(binding: SpatialMapBinding, blocked: Set<MapConnection>,
                                         zones: [KeepOutZone], persist: (Data) throws -> Void) throws {
        guard let installation, binding == installation.binding else { throw SpatialRegistryError.invalidMap }
        let candidate = try installation.addingRestrictions(blocked: blocked, zones: zones)
        let bytes = try candidate.encoded()
        // Positive restriction evidence immediately retires output, including when
        // storage fails. A failed save blocks new guidance until persistence succeeds.
        self.blocked = Set(candidate.currentRestrictions.blocked.map(\.connection)); obstacleZones = candidate.currentRestrictions.zones
        self.installation = candidate; obstacleRevision = UUID(); cancelRoute(); restrictionsDurable = false
        try persist(bytes)
        restrictionsDurable = true
    }
    public mutating func plan(from: String, to: String, goal: UUID, accessibleOnly: Bool = true) throws {
        guard goalRevision == goal else { throw SpatialRouteError.staleGoal }
        cancelRoute() // Failed replanning cannot leave the preceding route available.
        guard let installation else { throw SpatialInstallationError.noInstalledMap }
        var constrained = installation.map
        constrained.keepOutZones = (constrained.keepOutZones ?? []) + obstacleZones
        route = try constrained.route(from: from, to: to, accessibleOnly: accessibleOnly, blocked: blocked, body: body)
        waypointIndex = min(1, route.count)
    }
    /// Manual arrival changes only route progress; it is not fresh pose evidence.
    public mutating func confirmWaypoint() {
        guard waypointIndex < route.count else { return }
        waypointIndex += 1; routeID = UUID()
    }
    public func next(support: SpatialFloorSupport, now: Double) throws -> SpatialRouteTicket {
        guard let installation else { throw SpatialInstallationError.noInstalledMap }
        guard restrictionsDurable else { throw SpatialRouteError.unpersistedRestrictions }
        guard let goalRevision, waypointIndex > 0, waypointIndex < route.count else { throw SpatialRouteError.noRoute }
        guard let pose = currentPose(now: now) else { throw SpatialRegistryError.noCurrentPose }
        let target = route[waypointIndex]
        guard target.level == route[waypointIndex - 1].level else { throw SpatialRouteError.unsupportedTransition }
        let point = try validateLeg(pose: pose, source: route[waypointIndex - 1], target: target, support: support, installation: installation, now: now)
        let spatial = try localization.output(purpose: .route, binding: installation.binding,
                                               floorID: pose.floorID, registry: installation.registry, now: now)
        let ticket = SpatialRouteTicket(target: target, currentFloorPoint: point, bodyYaw: pose.bodyYaw,
                                  positionUncertainty: pose.positionUncertainty, headingUncertainty: pose.headingUncertainty,
                                  spatial: spatial, routeID: routeID, goalRevision: goalRevision,
                                  bodyRevision: bodyRevision, obstacleRevision: obstacleRevision,
                                  artifactSHA256: installation.artifact.sha256, support: support)
        guard ticket.directionalCue() != nil else { throw SpatialRouteError.ambiguousDirection }
        return ticket
    }
    /// Call immediately before speech/beacon dispatch and while an attempt is held.
    /// A changed body, restriction, goal, session, capture or map retires the old result.
    public func permits(_ ticket: SpatialRouteTicket, now: Double) -> Bool {
        guard restrictionsDurable, let installation, ticket.routeID == routeID, ticket.goalRevision == goalRevision,
              ticket.bodyRevision == bodyRevision, ticket.obstacleRevision == obstacleRevision,
              ticket.artifactSHA256 == installation.artifact.sha256, ticket.directionalCue() != nil,
              waypointIndex > 0, waypointIndex < route.count, ticket.target == route[waypointIndex],
              localization.permits(ticket.spatial, purpose: .route, registry: installation.registry, now: now),
              let pose = currentPose(now: now),
              (try? validateLeg(pose: pose, source: route[waypointIndex - 1], target: ticket.target, support: ticket.support,
                                installation: installation, now: now)) != nil else { return false }
        return true
    }
    private func validateLeg(pose: SpatialLocalizationCapture, source: MapNode, target: MapNode, support: SpatialFloorSupport,
                             installation: SpatialMapInstallation, now: Double) throws -> Point3 {
        let record = try installation.registry.map(for: installation.binding)
        guard record.floorLevels[target.level] == pose.floorID else { throw SpatialRegistryError.unknownFloor }
        guard support.binding == installation.binding, support.floorID == pose.floorID,
              support.sessionID == pose.sessionID, support.captureID == pose.id,
              support.height.isFinite, support.capturedAt.isFinite, support.capturedAt >= 0,
              support.capturedAt == pose.capturedAt, now >= support.capturedAt,
              now - support.capturedAt <= SavedWorldFrameRecovery.maximumFrameAge else { throw SpatialRouteError.missingSupport }
        let point = Point3(pose.position.x, support.height, pose.position.z)
        // A route selected from another landmark must not become a shortcut across
        // a blocked edge. Associate the estimated pose with this authored leg only;
        // off-route recovery/replanning is a separate request, never a guessed join.
        let dx = target.position.x - source.position.x, dz = target.position.z - source.position.z
        let lengthSquared = dx * dx + dz * dz
        guard lengthSquared.isFinite, lengthSquared > 0 else { throw SpatialRouteError.offRoute }
        let projection = ((point.x - source.position.x) * dx + (point.z - source.position.z) * dz) / lengthSquared
        let projected = Point3(source.position.x + projection * dx, point.y, source.position.z + projection * dz)
        guard projection.isFinite, (0...1).contains(projection),
              hypot(point.x - projected.x, point.z - projected.z) <= pose.positionUncertainty else {
            throw SpatialRouteError.offRoute
        }
        // Collision sweeps include the supplied measured positional uncertainty.
        // Never clamp an unsupported envelope down to a smaller permissive body.
        let uncertainBody = BodyEnvelope(radius: body.radius + pose.positionUncertainty,
                                         height: body.height, margin: body.margin)
        guard uncertainBody.valid else { throw SpatialRouteError.invalidBody }
        guard let surface = installation.map.surfaces?.first(where: { $0.level == target.level }),
              installation.map.restriction(from: point, to: target.position, level: target.level, body: uncertainBody) == nil,
              !obstacleZones.contains(where: { $0.level == target.level && $0.intersects(from: point, to: target.position, padding: uncertainBody.radius + uncertainBody.margin) }),
              surface.permitsLeg(from: point, to: target.position, body: uncertainBody) else { throw SpatialRouteError.blockedLeg }
        return point
    }
}
