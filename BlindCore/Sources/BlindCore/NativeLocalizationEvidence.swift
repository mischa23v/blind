import Foundation

/// Candidate evidence only. Neither ARKit tracking quality nor this adapter estimates
/// error. Volatile, non-Codable ownership deliberately cannot survive restart.
public enum NativeLocalizationNotReady: String, Error, Equatable, Sendable {
    case noInstallation, noSelectedOwner, noConfiguredSession, noRecoveredWorldFrame, importedFrameNeedsMeasuredRegistration
    case descriptorMismatch, invalidCandidate, trackingUnavailable, staleCandidate
    case ownerChanged, supersededCandidate, replayedCandidate, missingCalibration, missingSupport, missingErrorModel
    case unvalidatedEvidence, outOfDomain, invalidEvidence, evidenceExpired
    case mountChanged, mountSlip, physicalReleaseNotApproved
}

public struct NativeLocalizationOwner: Equatable, Sendable {
    public let selection: NativeLocalizationSelection
    public let arSession: UUID
    public let registeredSession: UUID
    public let artifact: SpatialMapArtifactIdentity
    public let descriptor: SavedWorldFrame
    public let calibrationRevision: String
    public let mountRevision: UUID
    public init(arSession: UUID, registeredSession: UUID, artifact: SpatialMapArtifactIdentity,
                descriptor: SavedWorldFrame, calibrationRevision: String, mountRevision: UUID,
                selection: NativeLocalizationSelection = .init(kind: .registeredPreview)) {
        self.selection = selection
        self.arSession = arSession; self.registeredSession = registeredSession
        self.artifact = artifact; self.descriptor = descriptor
        self.calibrationRevision = calibrationRevision; self.mountRevision = mountRevision
    }
}

public struct NativeLocalizationCandidate: Equatable, Sendable {
    public let id: UUID
    public let owner: NativeLocalizationOwner
    /// Original ARFrame uptime, never completion time or Date.
    public let capturedAt: Double
    /// Full ARCamera camera-to-world 4x4, column-major; no yaw-only collapse.
    public let cameraToWorld: [Double]
    public let trackingNormal: Bool
    public init(id: UUID = UUID(), owner: NativeLocalizationOwner, capturedAt: Double,
                cameraToWorld: [Double], trackingNormal: Bool) {
        self.id = id; self.owner = owner; self.capturedAt = capturedAt
        self.cameraToWorld = cameraToWorld; self.trackingNormal = trackingNormal
    }
}

/// Exact references to independently retained local validation records. IDs are not
/// proof by themselves: a trusted validator MUST resolve records, verify hashes and
/// protocol/domain applicability, and reject self-attestation/untrusted producers.
public struct NativeEvidenceRecord: Equatable, Sendable {
    public let sourceID: String
    public let revision: String
    public let sha256: String
    public let protocolID: String
    public let datasetID: String
    public let observedAt: Double
    public let expiresAt: Double
    public init(sourceID: String, revision: String, sha256: String, protocolID: String,
                datasetID: String, observedAt: Double, expiresAt: Double) {
        self.sourceID = sourceID; self.revision = revision; self.sha256 = sha256
        self.protocolID = protocolID; self.datasetID = datasetID
        self.observedAt = observedAt; self.expiresAt = expiresAt
    }
    fileprivate func valid(at now: Double) -> Bool {
        !sourceID.isEmpty && !revision.isEmpty && !protocolID.isEmpty && !datasetID.isEmpty &&
        Self.digest(sha256) && observedAt.isFinite && expiresAt.isFinite &&
        observedAt >= 0 && observedAt <= now && expiresAt >= now && expiresAt >= observedAt
    }
    fileprivate static func digest(_ value: String) -> Bool {
        value.utf8.count == 64 && value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }
}

/// Input contract for a FUTURE independently validated measurement producer.
/// No production producer is supplied. A room label, depth confidence, heuristic
/// BodyHeading score or floor plane must never be inserted as these measurements.
public struct NativeLocalizationMeasurements: Sendable {
    public let candidate: NativeLocalizationCandidate
    public let calibration: NativeEvidenceRecord?
    public let support: NativeEvidenceRecord?
    public let errorModel: NativeEvidenceRecord?
    public let operatingDomainID: String
    public let floorID: String
    public let bodyPosition: Point3
    public let bodyYaw: Double
    public let supportHeight: Double
    public let supportHeightError: Double
    /// Geometry digest includes the actual body envelope and full footprint swept
    /// under all reported pose error; validator must verify observed coverage.
    public let coveredFootprintSHA256: String
    /// Conservative total metric/radian error from the reviewed producer: includes
    /// frame alignment, camera/body calibration, sensor, timing and support error.
    /// This bridge does not invent a combination rule or numeric bound.
    public let totalPositionError: Double
    public let totalHeadingError: Double
    public init(candidate: NativeLocalizationCandidate, calibration: NativeEvidenceRecord?,
                support: NativeEvidenceRecord?, errorModel: NativeEvidenceRecord?, operatingDomainID: String,
                floorID: String, bodyPosition: Point3, bodyYaw: Double, supportHeight: Double,
                supportHeightError: Double, coveredFootprintSHA256: String,
                totalPositionError: Double, totalHeadingError: Double) {
        self.candidate = candidate; self.calibration = calibration; self.support = support
        self.errorModel = errorModel; self.operatingDomainID = operatingDomainID; self.floorID = floorID
        self.bodyPosition = bodyPosition; self.bodyYaw = bodyYaw; self.supportHeight = supportHeight
        self.supportHeightError = supportHeightError; self.coveredFootprintSHA256 = coveredFootprintSHA256
        self.totalPositionError = totalPositionError; self.totalHeadingError = totalHeadingError
    }
}

public enum NativeEvidenceValidation: Sendable { case unvalidated, outsideDomain, independentlyValidated }
/// Implement with a reviewed, local evidence provider, NOT an LLM or a closure that
/// trusts booleans from incoming data. Inspect complete candidate and measurements.
/// Verify measured camera/body transform, body reference/envelope convention,
/// support floor identity/full uncertainty-expanded coverage and total error model.
/// No shipped implementation returns independentlyValidated.
public protocol NativeLocalizationEvidenceValidator {
    func validate(_ measurement: NativeLocalizationMeasurements) -> NativeEvidenceValidation
}

public struct NativeLocalizationBenchPair: Sendable {
    public let owner: NativeLocalizationOwner
    public let capture: SpatialLocalizationCapture
    public let support: SpatialFloorSupport
    public let expiresAt: Double
}

/// Portable admission plumbing; bench preparation is NOT motion authorization.
/// Production adapter below never calls acceptRegisteredCapture. This separation
/// prevents successful synthetic tests from accidentally enabling physical output.
public struct NativeLocalizationEvidenceGate: Sendable {
    public private(set) var owner: NativeLocalizationOwner?
    public private(set) var reason: NativeLocalizationNotReady = .noInstallation
    private var pending: NativeLocalizationCandidate?
    private var installedRevision: SpatialMapRevision?
    private var lastTime: Double?
    private let maximumAge: Double
    public init(maximumAge: Double = SavedWorldFrameRecovery.maximumFrameAge) { self.maximumAge = maximumAge }
    public mutating func reset(_ reason: NativeLocalizationNotReady) {
        owner = nil; pending = nil; installedRevision = nil; lastTime = nil; self.reason = reason
    }
    /// Diagnostic withdrawal must not reset the unchanged owner's frame high-water.
    public mutating func withholdCandidate(_ why: NativeLocalizationNotReady) {
        pending = nil; installedRevision = nil; reason = why
    }
    /// Owner is captured before asynchronous measurement. Changing either epoch,
    /// digest, calibration or mount abandons every pending result.
    public mutating func begin(_ candidate: NativeLocalizationCandidate, installed: SpatialMapRevision?,
                               recovered: SavedWorldFrame?, now: Double) throws {
        pending = nil
        guard let installed else { throw fail(.noInstallation) }
        guard let saved = installed.savedWorldFrame else { throw fail(.importedFrameNeedsMeasuredRegistration) }
        guard let recovered else { throw fail(.noRecoveredWorldFrame) }
        guard saved.valid, saved == recovered, recovered == candidate.owner.descriptor,
              installed.binding == candidate.owner.artifact.binding,
              installed.binding.frameID == saved.frameID, installed.binding.revision == saved.revision,
              NativeEvidenceRecord.digest(candidate.owner.artifact.sha256) else { throw fail(.descriptorMismatch) }
        if owner != candidate.owner { owner = candidate.owner; lastTime = nil }
        guard candidate.trackingNormal else { throw fail(.trackingUnavailable) }
        guard NativeCameraTransform(columns: candidate.cameraToWorld).valid,
              !candidate.owner.calibrationRevision.isEmpty else { throw fail(.invalidCandidate) }
        guard fresh(candidate.capturedAt, now: now) else { throw fail(.staleCandidate) }
        guard lastTime.map({ candidate.capturedAt > $0 }) ?? true else { throw fail(.replayedCandidate) }
        installedRevision = installed
        lastTime = candidate.capturedAt; pending = candidate; reason = .missingCalibration
    }
    /// Exact equality prevents swapping pose/time/matrix while retaining an ID.
    /// Caller must independently obtain CURRENT owner immediately before completion.
    public mutating func prepareForBench(_ measurement: NativeLocalizationMeasurements,
        currentOwner: NativeLocalizationOwner, validator: any NativeLocalizationEvidenceValidator,
        now: Double) throws -> NativeLocalizationBenchPair {
        guard owner == currentOwner else { throw fail(.ownerChanged) }
        // A completion for A must not consume the newer pending B, even in the
        // same owner epoch. Return a non-mutating rejection for obsolete work.
        guard measurement.candidate.owner == currentOwner,
              pending == measurement.candidate else { throw NativeLocalizationNotReady.supersededCandidate }
        pending = nil // Single-use completion, even when it fails.
        let c = measurement.candidate
        guard fresh(c.capturedAt, now: now) else { throw fail(.staleCandidate) }
        guard let calibration = measurement.calibration else { throw fail(.missingCalibration) }
        guard let support = measurement.support else { throw fail(.missingSupport) }
        guard let error = measurement.errorModel else { throw fail(.missingErrorModel) }
        guard [calibration, support, error].allSatisfy({ $0.valid(at: now) }) else { throw fail(.evidenceExpired) }
        guard calibration.revision == currentOwner.calibrationRevision,
              support.observedAt == c.capturedAt, error.observedAt == c.capturedAt,
              !measurement.floorID.isEmpty, installedRevision?.floorLevels.values.contains(measurement.floorID) == true,
              !measurement.operatingDomainID.isEmpty,
              NativeEvidenceRecord.digest(measurement.coveredFootprintSHA256),
              measurement.bodyPosition.isFinite, measurement.bodyYaw.isFinite,
              measurement.supportHeight.isFinite, measurement.supportHeightError.isFinite,
              measurement.supportHeightError >= 0, measurement.totalPositionError.isFinite,
              measurement.totalPositionError >= measurement.supportHeightError,
              measurement.totalHeadingError.isFinite, measurement.totalHeadingError >= 0,
              measurement.totalHeadingError <= .pi else { throw fail(.invalidEvidence) }
        switch validator.validate(measurement) {
        case .unvalidated: throw fail(.unvalidatedEvidence)
        case .outsideDomain: throw fail(.outOfDomain)
        case .independentlyValidated: break
        }
        reason = .physicalReleaseNotApproved
        let capture = SpatialLocalizationCapture(id: c.id, sessionID: currentOwner.registeredSession,
            binding: currentOwner.artifact.binding, floorID: measurement.floorID,
            position: measurement.bodyPosition, bodyYaw: measurement.bodyYaw, source: .alignedMapPose,
            headingSource: .bodyAligned, trackingNormal: c.trackingNormal,
            positionUncertainty: measurement.totalPositionError,
            headingUncertainty: measurement.totalHeadingError, capturedAt: c.capturedAt)
        return NativeLocalizationBenchPair(owner: currentOwner, capture: capture, support: SpatialFloorSupport(
            binding: capture.binding, floorID: capture.floorID, sessionID: capture.sessionID,
            captureID: capture.id, height: measurement.supportHeight, capturedAt: capture.capturedAt),
            expiresAt: min(c.capturedAt + maximumAge, calibration.expiresAt, support.expiresAt, error.expiresAt))
    }
    private func fresh(_ time: Double, now: Double) -> Bool {
        maximumAge.isFinite && maximumAge > 0 && maximumAge <= SavedWorldFrameRecovery.maximumFrameAge &&
        time.isFinite && time >= 0 && now.isFinite && now >= time && now - time <= maximumAge
    }
    private mutating func fail(_ why: NativeLocalizationNotReady) -> NativeLocalizationNotReady {
        pending = nil; reason = why; return why
    }
}
