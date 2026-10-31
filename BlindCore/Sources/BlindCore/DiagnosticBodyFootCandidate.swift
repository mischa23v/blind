import Foundation

/// Seated diagnostic arithmetic only. No measured support, registration or speech authority.
public struct DiagnosticBodyFootCandidate: Equatable, Sendable {
    public struct Capture: Equatable, Sendable {
        public let session: UUID, frame: UUID, request: UUID
        public let capturedAt: Double
        public let cameraToWorld: NativeCameraTransform
        public init(session: UUID, frame: UUID, request: UUID = UUID(), capturedAt: Double, cameraToWorld: NativeCameraTransform) {
            self.session = session; self.frame = frame; self.request = request; self.capturedAt = capturedAt; self.cameraToWorld = cameraToWorld
        }
        public func isFresh(at now: Double, maximumAge: Double = 0.5) -> Bool {
            now.isFinite && capturedAt.isFinite && capturedAt >= 0 && now >= capturedAt && maximumAge.isFinite && (0...8).contains(maximumAge) && now - capturedAt <= maximumAge && cameraToWorld.valid
        }
    }
    public struct Source: Equatable, Sendable {
        public let captureSession: UUID
        public let session: String, generation: Int, revision: UInt64
        public init(captureSession: UUID, session: String, generation: Int, revision: UInt64) {
            self.captureSession = captureSession
            self.session = session; self.generation = generation; self.revision = revision
        }
    }
    public struct Declaration: Equatable, Sendable {
        public let revision: UUID
        public let profile: LocalBodyProfile
        /// Explicit helper-declared session-world yaw: zero faces -Z, positive turns left.
        /// Camera orientation is NOT substituted for this declaration.
        public let bodyYaw: Double?
        public let confirmed: Bool
        public init(revision: UUID = UUID(), profile: LocalBodyProfile, bodyYaw: Double?, confirmed: Bool) {
            self.revision = revision; self.profile = profile; self.bodyYaw = bodyYaw; self.confirmed = confirmed
        }
    }
    public let capture: Capture, source: Source, declaration: Declaration
    public let cameraOrigin: Point3, requestedFoot: Point3
    public var authorizesPhysicalGuidance: Bool { false }
    public var independentlyValidated: Bool { false }
    public let status = "UNVALIDATED — declared mount and heading; support and pose error unknown"

    public init?(capture: Capture?, source: Source, declaration: Declaration, now: Double) {
        guard let capture, capture.isFresh(at: now), capture.session == source.captureSession, !source.session.isEmpty, source.session.utf8.count <= 128, source.generation >= 0,
              declaration.confirmed, declaration.profile.valid, declaration.profile.mount.complete,
              let yaw = declaration.bodyYaw, yaw.isFinite, (-Double.pi...Double.pi).contains(yaw),
              let right = declaration.profile.mount.right, let up = declaration.profile.mount.up,
              let forward = declaration.profile.mount.forward,
              let origin = try? capture.cameraToWorld.applying(to: Point3(0,0,0)),
              let offset = try? SpatialRigidTransform(translation: Point3(0,0,0), yaw: yaw)
                .applying(to: Point3(right, up, -forward)) else { return nil }
        let foot = Point3(origin.x-offset.x, origin.y-offset.y, origin.z-offset.z)
        guard foot.isFinite, [foot.x,foot.y,foot.z].allSatisfy({ Float($0).isFinite }) else { return nil }
        self.capture = capture; self.source = source; self.declaration = declaration
        cameraOrigin = origin; requestedFoot = foot
    }
    /// Exact frozen request capture and declaration identity, not the newest frame.
    /// Eight-second historical display lease is NOT physical-guidance freshness.
    public func isCurrent(capture current: Capture?, source: Source, declaration: Declaration, now: Double) -> Bool {
        current == capture && source == self.source && declaration == self.declaration && capture.isFresh(at: now, maximumAge: 8)
    }
    public var queryPoint: [Float] { [Float(requestedFoot.x), Float(requestedFoot.y), Float(requestedFoot.z)] }

    /// Native association is diagnostic output, never an overwrite of the proposed foot.
    public struct Endpoint: Equatable, Sendable {
        public let requested: Point3, associated: Point3
        public var deltaY: Double { associated.y - requested.y }
        public var horizontalResidual: Double { hypot(associated.x-requested.x, associated.z-requested.z) }
        public let found: Bool, isOverPolygon: Bool
        public init?(requested: [Float], associated: [Float], found: Bool, isOverPolygon: Bool) {
            guard requested.count == 3, associated.count == 3,
                  requested.allSatisfy(\.isFinite), associated.allSatisfy(\.isFinite) else { return nil }
            self.requested = Point3(Double(requested[0]),Double(requested[1]),Double(requested[2]))
            self.associated = Point3(Double(associated[0]),Double(associated[1]),Double(associated[2]))
            self.found = found; self.isOverPolygon = isOverPolygon
        }
    }
    public func associatedEndpoint(requested: [Float], associated: [Float], found: Bool, isOverPolygon: Bool) -> Endpoint? {
        guard requested == queryPoint else { return nil }
        return Endpoint(requested: requested, associated: associated, found: found, isOverPolygon: isOverPolygon)
    }
}
