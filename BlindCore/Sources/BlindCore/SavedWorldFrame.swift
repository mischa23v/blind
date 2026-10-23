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
                normalFrames = 0; lastValidatedAt = nil; sawRelocalizing = false
            }
        }
        lastFrameTime = frameTime
        switch tracking {
        case .relocalizing:
            sawRelocalizing = true; normalFrames = 0; lastValidatedAt = nil
        case .unavailable:
            if lastValidatedAt != nil { sawRelocalizing = false }
            normalFrames = 0; lastValidatedAt = nil
        case .normal:
            guard sawRelocalizing, mappingAvailable, originAnchorMatches else {
                if lastValidatedAt != nil { sawRelocalizing = false }
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
}
