import Foundation

/// Evidence is supplied by a measured localization adapter, not generated from this type.
/// GPS and appearance may shortlist candidates but never establish metric pose/heading.
/// Intentionally not Codable: monotonic capture times cannot outlive their session.
public struct SpatialLocalizationCapture: Equatable, Sendable {
    public enum Source: Equatable, Sendable { case coarseLocation, roomAppearance, alignedMapPose }
    public enum HeadingSource: Equatable, Sendable { case cameraOnly, bodyAligned }
    public let id: UUID
    public let sessionID: UUID
    public let binding: SpatialMapBinding
    public let floorID: String
    public let roomID: String?
    public let position: Point3
    public let bodyYaw: Double
    public let source: Source
    public let headingSource: HeadingSource
    public let trackingNormal: Bool
    public let positionUncertainty: Double
    public let headingUncertainty: Double
    /// Monotonic seconds in sessionID, never wall-clock restoration.
    public let capturedAt: Double
    public init(id: UUID = UUID(), sessionID: UUID, binding: SpatialMapBinding,
                floorID: String, roomID: String? = nil, position: Point3, bodyYaw: Double,
                source: Source, headingSource: HeadingSource, trackingNormal: Bool,
                positionUncertainty: Double, headingUncertainty: Double, capturedAt: Double) {
        self.id = id; self.sessionID = sessionID; self.binding = binding; self.floorID = floorID
        self.roomID = roomID; self.position = position; self.bodyYaw = bodyYaw; self.source = source
        self.headingSource = headingSource; self.trackingNormal = trackingNormal
        self.positionUncertainty = positionUncertainty; self.headingUncertainty = headingUncertainty
        self.capturedAt = capturedAt
    }
}

/// Configuration values are policy limits, not measured safety/accuracy certification.
public struct SpatialLocalizationLimits: Sendable {
    public let maximumPositionUncertainty: Double
    public let maximumHeadingUncertainty: Double
    public let maximumCaptureAge: Double
    public init(maximumPositionUncertainty: Double, maximumHeadingUncertainty: Double,
                maximumCaptureAge: Double = SavedWorldFrameRecovery.maximumFrameAge) {
        self.maximumPositionUncertainty = maximumPositionUncertainty
        self.maximumHeadingUncertainty = maximumHeadingUncertainty
        self.maximumCaptureAge = maximumCaptureAge
    }
    public var valid: Bool {
        maximumPositionUncertainty.isFinite && maximumPositionUncertainty > 0 &&
        maximumHeadingUncertainty.isFinite && maximumHeadingUncertainty > 0 &&
        maximumHeadingUncertainty <= .pi && maximumCaptureAge.isFinite &&
        maximumCaptureAge > 0 && maximumCaptureAge <= SavedWorldFrameRecovery.maximumFrameAge
    }
}

/// Binds a queued route/collision result to exact geometry and live capture ownership.
/// A valid lease is necessary but NOT sufficient: the existing route/clearance and
/// target-specific evidence guards must independently pass immediately before delivery.
public struct SpatialOutputLease: Equatable, Sendable {
    public enum Purpose: Equatable, Sendable { case route, collision }
    public let purpose: Purpose
    public let binding: SpatialMapBinding
    public let floorID: String
    public let captureID: UUID
    public let sessionID: UUID
    /// Local acceptance generation prevents capture-ID reuse from reviving old results.
    public let acceptanceID: UUID
    fileprivate init(purpose: Purpose, capture: SpatialLocalizationCapture, acceptanceID: UUID) {
        self.purpose = purpose; binding = capture.binding; floorID = capture.floorID
        captureID = capture.id; sessionID = capture.sessionID; self.acceptanceID = acceptanceID
    }
}

/// Volatile gate only, separate from SpatialRegistrySnapshot. A new process/session
/// always starts unknown even with the complete durable hierarchy and map history.
public struct SpatialLocalizationLease: Sendable {
    public private(set) var sessionID: UUID
    private let limits: SpatialLocalizationLimits
    private var accepted: SpatialLocalizationCapture?
    private var acceptanceID: UUID?
    private var acceptedInstallationID: UUID?
    private var lastFrameTime: Double?
    private var seenCaptureIDs = Set<UUID>()
    public init(limits: SpatialLocalizationLimits) {
        self.limits = limits; sessionID = UUID()
    }
    public mutating func restart() {
        sessionID = UUID(); accepted = nil; acceptanceID = nil; acceptedInstallationID = nil; lastFrameTime = nil; seenCaptureIDs.removeAll()
    }
    /// Rotate ownership as well as clearing the pose: pre-loss asynchronous captures
    /// cannot recover tracking. The native adapter must obtain fresh-session evidence.
    public mutating func loseTracking() { restart() }
    public mutating func accept(_ capture: SpatialLocalizationCapture,
                                registry: SpatialFrameRegistry, now: Double) throws {
        // A rejected update must not leave an older pose available as current.
        accepted = nil; acceptanceID = nil; acceptedInstallationID = nil
        guard capture.sessionID == sessionID,
              lastFrameTime.map({ capture.capturedAt > $0 }) ?? true,
              !seenCaptureIDs.contains(capture.id) else { throw SpatialRegistryError.invalidCapture }
        try validate(capture, registry: registry, now: now)
        // Bound the replay set; time is strictly increasing even after old IDs retire.
        if seenCaptureIDs.count >= 2048 { seenCaptureIDs.removeAll(keepingCapacity: true) }
        seenCaptureIDs.insert(capture.id); lastFrameTime = capture.capturedAt
        accepted = capture; acceptanceID = UUID(); acceptedInstallationID = registry.installationID
    }
    public func current(registry: SpatialFrameRegistry, now: Double) -> SpatialLocalizationCapture? {
        guard acceptedInstallationID == registry.installationID, let accepted,
              (try? validate(accepted, registry: registry, now: now)) != nil else { return nil }
        return accepted
    }
    public func output(purpose: SpatialOutputLease.Purpose, binding: SpatialMapBinding, floorID: String,
                       registry: SpatialFrameRegistry, now: Double) throws -> SpatialOutputLease {
        guard let capture = current(registry: registry, now: now), let acceptanceID else {
            throw SpatialRegistryError.noCurrentPose
        }
        // Converting geometry does not establish a new map's live localization.
        guard binding == capture.binding, floorID == capture.floorID else { throw SpatialRegistryError.invalidCapture }
        return SpatialOutputLease(purpose: purpose, capture: capture, acceptanceID: acceptanceID)
    }
    public func permits(_ output: SpatialOutputLease, purpose: SpatialOutputLease.Purpose,
                        registry: SpatialFrameRegistry, now: Double) -> Bool {
        guard let capture = current(registry: registry, now: now) else { return false }
        return output.purpose == purpose && output.binding == capture.binding && output.floorID == capture.floorID &&
            output.captureID == capture.id && output.sessionID == sessionID && output.acceptanceID == acceptanceID
    }
    private func validate(_ capture: SpatialLocalizationCapture,
                          registry: SpatialFrameRegistry, now: Double) throws {
        guard limits.valid, capture.sessionID == sessionID, capture.source == .alignedMapPose,
              capture.headingSource == .bodyAligned, capture.trackingNormal,
              capture.position.isFinite, capture.bodyYaw.isFinite,
              capture.positionUncertainty.isFinite, capture.positionUncertainty >= 0,
              capture.positionUncertainty <= limits.maximumPositionUncertainty,
              capture.headingUncertainty.isFinite, capture.headingUncertainty >= 0,
              capture.headingUncertainty <= limits.maximumHeadingUncertainty,
              capture.capturedAt.isFinite, capture.capturedAt >= 0, now.isFinite, now >= capture.capturedAt,
              now - capture.capturedAt <= limits.maximumCaptureAge else { throw SpatialRegistryError.invalidCapture }
        try registry.validateLocation(floorID: capture.floorID, roomID: capture.roomID, in: capture.binding)
    }
}
