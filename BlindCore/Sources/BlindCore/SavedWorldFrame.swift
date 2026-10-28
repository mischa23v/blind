import Foundation

/// Durable identity of one RoomPlan scan and its paired ARWorldMap, not a live pose.
/// RoomPlan uses the supplied ARSession's world coordinates. After ARKit relocalizes
/// an initialWorldMap, those coordinates are restored. Imported route-map coordinates
/// are unrelated unless a separate measured transform is established.
/// Sources: developer.apple.com/videos/play/wwdc2023/10192/ (custom ARSession/MultiRoom),
/// developer.apple.com/documentation/arkit/managing-session-life-cycle-and-tracking-quality.
public struct SavedWorldFrame: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let placeID: String
    public let revision: String
    public let worldMapSHA256: String
    public let roomCaptureSHA256: String
    public let originAnchorID: String
    public let capturedAt: Date
    public let coordinateSystem: String
    public let source: String

    public init(placeID: String, revision: String, worldMapSHA256: String,
                roomCaptureSHA256: String, originAnchorID: String, capturedAt: Date) {
        schemaVersion = 1
        self.placeID = placeID; self.revision = revision
        self.worldMapSHA256 = worldMapSHA256; self.roomCaptureSHA256 = roomCaptureSHA256
        self.originAnchorID = originAnchorID; self.capturedAt = capturedAt
        coordinateSystem = "arkit-gravity-metres"
        source = "roomplan-shared-arsession"
    }
    public var frameID: String { "arkit-worldmap:\(placeID):\(revision)" }
    public var originAnchorName: String { "blind-assist-world-origin:\(revision)" }
    public var valid: Bool {
        schemaVersion == 1 && UUID(uuidString: placeID) != nil && UUID(uuidString: revision) != nil &&
        UUID(uuidString: originAnchorID) != nil && Self.isDigest(worldMapSHA256) && Self.isDigest(roomCaptureSHA256) &&
        capturedAt.timeIntervalSince1970.isFinite && coordinateSystem == "arkit-gravity-metres" &&
        source == "roomplan-shared-arsession"
    }
    public func matches(worldMapSHA256: String, roomCaptureSHA256: String) -> Bool {
        valid && self.worldMapSHA256 == worldMapSHA256 && self.roomCaptureSHA256 == roomCaptureSHA256
    }
    private static func isDigest(_ value: String) -> Bool {
        value.utf8.count == 64 && value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }
}

/// A category-labelled RoomPlan measurement at scan time, never proof that a personal
/// item is there now. Its position belongs only to the paired saved world frame.
public struct SavedFurnitureObservation: Equatable, Sendable {
    public let id: String
    public let category: String
    public let position: Point3
    public let frame: SavedWorldFrame
    public let observedAt: Date
    public let source = "RoomPlan scan"
    public init?(id: String, category: String, position: Point3, frame: SavedWorldFrame) {
        guard !id.isEmpty, id.count <= 100, !category.isEmpty, category.count <= 100,
              position.isFinite, frame.valid else { return nil }
        self.id = id; self.category = category; self.position = position
        self.frame = frame; observedAt = frame.capturedAt
    }
}

/// A capture-bound diagnostic association with the SAME restored RoomPlan world.
/// This is not a fitted transform, a body/feet pose, an error estimate, or a live
/// guidance lease. It cannot be decoded or created by a caller. Retaining it as
/// history does not keep it current; consumers must preserve the raw camera sample.
public struct SavedWorldFrameCameraAssociation: Equatable, Sendable {
    public enum Reference: Equatable, Sendable { case camera }
    public enum Uncertainty: Equatable, Sendable { case unmeasured }
    public let frame: SavedWorldFrame
    public let sessionID: UUID
    public let recoveryID: UUID
    public let capturedAt: Double
    public var sourceFrameID: String { "arkit-session:\(sessionID.uuidString)" }
    public var reference: Reference { .camera }
    public var uncertainty: Uncertainty { .unmeasured }
    public var permitsPhysicalGuidance: Bool { false }
    fileprivate init(frame: SavedWorldFrame, sessionID: UUID, recoveryID: UUID, capturedAt: Double) {
        self.frame = frame; self.sessionID = sessionID; self.recoveryID = recoveryID; self.capturedAt = capturedAt
    }
}

/// Small lifecycle/evidence gate around Apple's relocalizer, not a SLAM implementation.
/// This state is deliberately not Codable: a restart must collect new live evidence.
/// The restored origin anchor binds the loaded artifact, not physical accuracy. A match
/// permits coordinate association only, never object identity, clearance or guidance.
public struct SavedWorldFrameRecovery: Sendable {
    public enum Tracking: Sendable { case relocalizing, normal, unavailable }
    public static let maximumFrameAge = 0.5
    public static let timeout = 30.0
    public static let minimumNormalFrames = 3
    private var expected: SavedWorldFrame?
    private var sessionID: UUID?
    private var startedAt: Double?
    private var lastFrameTime: Double?
    private var lastValidatedAt: Double?
    private var sawRelocalizing = false
    private var normalFrames = 0
    private var recoveryID = UUID()

    public init() {}
    public mutating func reset() { self = SavedWorldFrameRecovery() }
    public mutating func begin(frame: SavedWorldFrame, sessionID: UUID, now: Double) {
        reset()
        guard frame.valid, now.isFinite else { return }
        expected = frame; self.sessionID = sessionID; startedAt = now
    }
    @discardableResult
    public mutating func observe(sessionID: UUID, tracking: Tracking, mappingAvailable: Bool,
                                 originAnchorMatches: Bool, frameTime: Double, now: Double) -> SavedWorldFrame? {
        guard self.sessionID == sessionID, let expected, let startedAt,
              frameTime.isFinite, now.isFinite, now >= startedAt, frameTime >= startedAt,
              now >= frameTime, now - frameTime <= Self.maximumFrameAge else { reset(); return nil }
        if lastValidatedAt == nil && now - startedAt > Self.timeout { reset(); return nil }
        if let last = lastFrameTime {
            guard frameTime > last else { return nil }
            if frameTime - last > Self.maximumFrameAge {
                recoveryID = UUID()
                normalFrames = 0; lastValidatedAt = nil; sawRelocalizing = false
            }
        }
        lastFrameTime = frameTime
        switch tracking {
        case .relocalizing:
            if lastValidatedAt != nil { recoveryID = UUID() }
            sawRelocalizing = true; normalFrames = 0; lastValidatedAt = nil
        case .unavailable:
            if lastValidatedAt != nil { recoveryID = UUID(); sawRelocalizing = false }
            normalFrames = 0; lastValidatedAt = nil
        case .normal:
            guard sawRelocalizing, mappingAvailable, originAnchorMatches else {
                if lastValidatedAt != nil { recoveryID = UUID(); sawRelocalizing = false }
                normalFrames = 0; lastValidatedAt = nil; return nil
            }
            normalFrames = min(Self.minimumNormalFrames, normalFrames + 1)
            guard normalFrames >= Self.minimumNormalFrames else { return nil }
            // Callback latency must not renew evidence beyond its capture-time lease.
            lastValidatedAt = frameTime
            return expected
        }
        return nil
    }
    public func current(sessionID: UUID, now: Double) -> SavedWorldFrame? {
        guard self.sessionID == sessionID, let lastValidatedAt, now.isFinite,
              now >= lastValidatedAt, now - lastValidatedAt <= Self.maximumFrameAge else { return nil }
        return expected
    }
    /// Native pre-throttle loss hook. It cannot establish an association and does
    /// not inspect anchors. A real relocalizing callback is retained even when the
    /// normal frame-processing throttle skips it. Obsolete callbacks must not
    /// withdraw another recovery epoch or a newer accepted frame.
    public mutating func observeTrackingInterruption(sessionID: UUID, tracking: Tracking,
        frameTime: Double, now: Double) {
        guard self.sessionID == sessionID, let startedAt,
              frameTime.isFinite, frameTime >= startedAt,
              lastFrameTime.map({ frameTime > $0 }) ?? true else { return }
        switch tracking {
        case .normal: return
        case .relocalizing, .unavailable:
            _ = observe(sessionID: sessionID, tracking: tracking, mappingAvailable: false,
                originAnchorMatches: false, frameTime: frameTime, now: now)
        }
    }
    /// Exact latest validated capture only, checked against the REAL receipt clock.
    /// A previous frame's descriptor cannot associate a new/delayed camera sample.
    public func cameraAssociation(sessionID: UUID, capturedAt: Double, now: Double) -> SavedWorldFrameCameraAssociation? {
        guard let lastValidatedAt, capturedAt == lastValidatedAt,
              let frame = current(sessionID: sessionID, now: now) else { return nil }
        return .init(frame: frame, sessionID: sessionID, recoveryID: recoveryID, capturedAt: capturedAt)
    }
}
