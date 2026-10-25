import Foundation

/// Measured acquisition, not localization authority. These records let a helper
/// inspect independently selected cross-scan correspondences before calibration.
/// RoomPlan centers can shift with partial coverage; their residual is NOT a
/// total pose-error bound, an instance match, or proof of floor containment.
public struct RoomRegistrationAcquisition: Codable, Equatable, Sendable {
    public struct Feature: Codable, Equatable, Sendable {
        public let id: String
        public let kind: String
        /// Original RoomPlan feature-to-shared-world matrix, column-major metres.
        public let transform: [Double]
        public let dimensions: Point3
        /// Original local-plane corners, empty when not supplied by RoomPlan.
        public let polygonCorners: [Point3]
        public init(id: String, kind: String, transform: [Double], dimensions: Point3, polygonCorners: [Point3] = []) {
            self.id = id; self.kind = kind; self.transform = transform; self.dimensions = dimensions; self.polygonCorners = polygonCorners
        }
        fileprivate var center: Point3 { Point3(transform[12], transform[13], transform[14]) }
        public var valid: Bool {
            UUID(uuidString: id) != nil && !kind.isEmpty && kind.utf8.count <= 64 &&
            NativeCameraTransform(columns: transform).valid && [12,13,14].allSatisfy { abs(transform[$0]) <= 10_000 } && dimensions.isFinite &&
            polygonCorners.count <= 16 && polygonCorners.allSatisfy { $0.isFinite && abs($0.x) <= 100 && abs($0.y) <= 100 && abs($0.z) <= 100 } &&
            [dimensions.x, dimensions.y, dimensions.z].allSatisfy { $0 >= 0 && $0 <= 100 }
        }
    }
    public struct Correspondence: Codable, Equatable, Sendable {
        public let baselineID: String
        public let measuredID: String
        /// Explicit helper selection, never category/nearest-neighbour association.
        public init(baselineID: String, measuredID: String) {
            self.baselineID = baselineID; self.measuredID = measuredID
        }
    }
    public let schemaVersion: Int
    public let id: UUID
    public let frame: SavedWorldFrame
    public let sessionID: UUID
    public let scanID: UUID
    public let baselineRoomID: UUID
    public let measuredRoomID: UUID
    /// Framework story indices are raw scan metadata, not verified building-floor IDs.
    public let baselineStory: Int?
    public let measuredStory: Int?
    public let startedAt: Double
    public let capturedAt: Double
    public let recordedAt: Date
    public let cameraToWorld: [Double]
    public let baseline: [Feature]
    public let measured: [Feature]
    public private(set) var correspondences: [Correspondence]
    public static let maximumFeatures = 32
    public init?(id: UUID = UUID(), frame: SavedWorldFrame, sessionID: UUID, scanID: UUID,
                 baselineRoomID: UUID, measuredRoomID: UUID, startedAt: Double, capturedAt: Double,
                 recordedAt: Date, cameraToWorld: [Double], baseline: [Feature], measured: [Feature],
                 baselineStory: Int? = nil, measuredStory: Int? = nil) {
        schemaVersion = 1
        self.id = id; self.frame = frame; self.sessionID = sessionID; self.scanID = scanID
        self.baselineRoomID = baselineRoomID; self.measuredRoomID = measuredRoomID
        self.baselineStory = baselineStory; self.measuredStory = measuredStory
        self.startedAt = startedAt; self.capturedAt = capturedAt; self.recordedAt = recordedAt
        self.cameraToWorld = cameraToWorld; self.baseline = baseline; self.measured = measured
        self.correspondences = []
        guard valid else { return nil }
    }
    public var valid: Bool {
        schemaVersion == 1 && [baselineStory, measuredStory].allSatisfy { $0.map { (-4096...4096).contains($0) } ?? true } &&
        frame.valid && startedAt.isFinite && capturedAt.isFinite && startedAt >= 0 && capturedAt >= startedAt &&
        recordedAt >= .distantPast && recordedAt <= .distantFuture &&
        NativeCameraTransform(columns: cameraToWorld).valid &&
        [baseline, measured].allSatisfy { features in
            !features.isEmpty && features.count <= Self.maximumFeatures && features.allSatisfy(\.valid) &&
            Set(features.map(\.id)).count == features.count
        } && validPairs(correspondences) && ((try? JSONEncoder().encode(self).count).map { $0 <= 64_000 } ?? false)
    }
    private func validPairs(_ pairs: [Correspondence]) -> Bool {
        pairs.count <= 12 && Set(pairs.map(\.baselineID)).count == pairs.count &&
        Set(pairs.map(\.measuredID)).count == pairs.count && pairs.allSatisfy { pair in
            baseline.contains { $0.id == pair.baselineID } && measured.contains { $0.id == pair.measuredID }
        }
    }
    /// Exact acquisition receipt prevents a selection in rescan A editing rescan B.
    /// Pair selection changes no frame, scope, current pose, or physical output.
    @discardableResult public mutating func select(_ pairs: [Correspondence], acquisitionID: UUID) -> Bool {
        guard valid, acquisitionID == id, validPairs(pairs) else { return false }
        var candidate = self; candidate.correspondences = pairs
        guard candidate.valid else { return false }
        self = candidate; return true
    }
    /// Same-world coordinate consistency only. No fitted transform is invented.
    /// Empty until the helper explicitly selects independent correspondences.
    public var centerResidualsMetres: [Double] {
        guard valid else { return [] }
        return correspondences.compactMap { pair in
            guard let a = baseline.first(where: { $0.id == pair.baselineID }),
                  let b = measured.first(where: { $0.id == pair.measuredID }) else { return nil }
            return a.center.distance(to: b.center)
        }
    }
    public var maximumCenterResidualMetres: Double? { centerResidualsMetres.max() }
    // Deliberately no conversion to CompanionMemoryScope or localization capture.
}

/// Transient ownership of an existing same-world comparison scan. No Codable,
/// registration fitting, floor assignment or positive identity admission.
public struct RoomRegistrationCapture: Sendable {
    public struct Sample: Equatable, Sendable {
        public let capturedAt: Double
        public let cameraToWorld: [Double]
    }
    public private(set) var frame: SavedWorldFrame?
    public private(set) var sessionID: UUID?
    public private(set) var scanID: UUID?
    public private(set) var startedAt: Double?
    public private(set) var latest: Sample?
    public init() {}
    public mutating func begin(frame: SavedWorldFrame, sessionID: UUID, scanID: UUID, now: Double) {
        invalidate()
        guard frame.valid, now.isFinite, now >= 0 else { return }
        self.frame = frame; self.sessionID = sessionID; self.scanID = scanID; startedAt = now
    }
    public mutating func invalidate() { self = Self() }
    public mutating func observe(sessionID: UUID, scanID: UUID, capturedAt: Double,
                                 cameraToWorld: [Double], trackingNormal: Bool, now: Double) {
        // A retired owner cannot invalidate a newer acquisition.
        guard self.sessionID == sessionID, self.scanID == scanID else { return }
        guard let start = startedAt, capturedAt.isFinite else { invalidate(); return }
        // AR callbacks can be delayed across comparison scans in one session.
        // Old frames are not evidence about the newly admitted capture.
        guard capturedAt >= start else { return }
        if let previous = latest, capturedAt <= previous.capturedAt { return }
        guard trackingNormal, now.isFinite,
              now >= capturedAt, now - capturedAt <= SavedWorldFrameRecovery.maximumFrameAge,
              NativeCameraTransform(columns: cameraToWorld).valid else { invalidate(); return }
        if let previous = latest {
            guard capturedAt - previous.capturedAt <= SavedWorldFrameRecovery.maximumFrameAge else { invalidate(); return }
        }
        latest = Sample(capturedAt: capturedAt, cameraToWorld: cameraToWorld)
    }
    public func sample(sessionID: UUID, scanID: UUID, now: Double) -> Sample? {
        guard self.sessionID == sessionID, self.scanID == scanID, let latest,
              now.isFinite, now >= latest.capturedAt,
              now - latest.capturedAt <= SavedWorldFrameRecovery.maximumFrameAge else { return nil }
        return latest
    }
}
