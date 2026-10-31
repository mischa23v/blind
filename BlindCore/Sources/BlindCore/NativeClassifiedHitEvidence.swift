import Foundation

/// Fresh sampled hits only. ARKit mesh labels are not a coverage/error estimate.
/// Original history records remain history-only; this receipt never grants support.
public struct NativeClassifiedHitEvidence: Equatable, Sendable {
    public enum Failure: String, Error, Sendable { case invalid, unavailable, stale, oversized }
    public enum Role: String, Sendable { case floor, nonFloor, unknown }
    public struct Surface: Equatable, Sendable {
        public let anchorID: String
        public let worldVertices: [Point3]
        public let triangleIndices: [Int]
        public let roles: [Role]
        public let originalTriangleCount: Int
        public let truncated: Bool
    }
    public let recordID, sessionID: UUID
    public let sourceID, coordinateFrameID: String
    public let capturedAt: Double
    public let surfaces: [Surface]
    public let omitted: [String]
    public let originalSurfaceCount: Int?
    public var sampledOrIncomplete: Bool { originalSurfaceCount == nil || originalSurfaceCount != surfaces.count || !omitted.isEmpty || surfaces.contains { $0.truncated || $0.roles.contains(.unknown) } }
    public var fullFootprintSupportKnown: Bool { false }
    public var authorizesPhysicalGuidance: Bool { false }
    public init(record: NativeObservationRecord, now: Double) throws {
        do { try record.validate() } catch { throw Failure.invalid }
        guard record.producer == .arkit, record.tracking == .normal else { throw Failure.unavailable }
        guard record.coordinateFrameID == "arkit-session:" + record.sessionID.uuidString else { throw Failure.invalid }
        guard FrameTimestampPolicy.isFresh(capturedAt: record.capturedAt, receivedAt: now) else { throw Failure.stale }
        let meshes = record.surfaces.filter { $0.kind == .arkitMesh }
        guard meshes.contains(where: { !$0.triangleIndices.isEmpty }) else { throw Failure.unavailable }
        guard meshes.reduce(0, { $0 + $1.vertices.count }) <= 2048,
              meshes.reduce(0, { $0 + $1.triangleIndices.count }) <= 24576 else { throw Failure.oversized }
        guard Set(meshes.map(\.sourceID)).count == meshes.count else { throw Failure.invalid }
        surfaces = try meshes.map { mesh in
            let roles = (0..<(mesh.triangleIndices.count / 3)).map { index -> Role in
                guard let labels = mesh.triangleClassifications else { return .unknown }
                switch labels[index] {
                case "floor": return .floor
                case "wall", "ceiling", "table", "seat", "door", "window": return .nonFloor
                default: return .unknown
                }
            }
            // Existing column-major rigid transform exactly once; no flattening.
            return Surface(anchorID: mesh.sourceID,
                worldVertices: try mesh.vertices.map { try mesh.localToSessionWorld.applying(to: $0) },
                triangleIndices: mesh.triangleIndices, roles: roles,
                originalTriangleCount: mesh.originalTriangleCount, truncated: mesh.truncated)
        }
        recordID = record.id; sessionID = record.sessionID; sourceID = record.sourceID
        coordinateFrameID = record.coordinateFrameID; capturedAt = record.capturedAt
        omitted = record.omitted; originalSurfaceCount = record.originalSurfaceCount
    }
    public func isFresh(session: UUID, now: Double) -> Bool {
        sessionID == session && FrameTimestampPolicy.isFresh(capturedAt: capturedAt, receivedAt: now)
    }
}

/// Exact-session replacement. Rejected newer extraction withdraws older evidence;
/// missed frames/silence never fill holes or extend the last capture's lease.
public struct NativeClassifiedHitState: Sendable {
    public private(set) var evidence: NativeClassifiedHitEvidence?
    public private(set) var revision = UUID()
    private var session: UUID?
    private var lastCapture = -Double.infinity
    public init() {}
    public mutating func begin(session: UUID) { self.session = session; lastCapture = -.infinity; retire() }
    public mutating func retire() { evidence = nil; revision = UUID() }
    public mutating func stop() { session = nil; retire() }
    @discardableResult public mutating func consume(_ value: NativeClassifiedHitEvidence?, session: UUID,
        capturedAt: Double, now: Double) -> Bool {
        guard self.session == session else { return false }
        guard capturedAt.isFinite, capturedAt >= 0 else { retire(); return true }
        guard capturedAt > lastCapture else { return false }
        retire()
        guard FrameTimestampPolicy.isFresh(capturedAt: capturedAt, receivedAt: now) else { return true }
        lastCapture = capturedAt
        guard let value, value.capturedAt == capturedAt, value.isFresh(session: session, now: now) else { return true }
        evidence = value; return true
    }
    @discardableResult public mutating func expire(now: Double) -> Bool {
        guard let evidence, let session, !evidence.isFresh(session: session, now: now) else { return false }
        retire(); return true
    }
}

/// One pending owned value, shared by the existing utility producer and main
/// consumer. Generation checks prevent obsolete extraction from replacing a
/// new owner's slot; only one callback is requested per pending generation.
public final class NativeClassifiedHitMailbox: @unchecked Sendable {
    public struct Delivery: Sendable {
        public let evidence: NativeClassifiedHitEvidence?
        public let session: UUID
        public let capturedAt: Double
        public let generation: UUID
        public init(evidence: NativeClassifiedHitEvidence?, session: UUID, capturedAt: Double, generation: UUID) {
            self.evidence = evidence; self.session = session; self.capturedAt = capturedAt; self.generation = generation
        }
    }
    private let lock = NSLock()
    private var pending: (UUID, Delivery)?
    private var generation: UUID?
    public init() {}
    public func begin(_ generation: UUID) { lock.lock(); pending = nil; self.generation = generation; lock.unlock() }
    public func offer(_ delivery: Delivery) -> UUID? {
        lock.lock(); defer { lock.unlock() }
        guard generation == delivery.generation else { return nil }
        if let current = pending {
            pending = (current.0, delivery); return nil
        }
        let token = UUID(); pending = (token, delivery); return token
    }
    public func take(_ token: UUID) -> Delivery? {
        lock.lock(); defer { lock.unlock() }
        guard let pending, pending.0 == token else { return nil }
        self.pending = nil; return pending.1
    }
    public func clear() { lock.lock(); pending = nil; generation = nil; lock.unlock() }
}
