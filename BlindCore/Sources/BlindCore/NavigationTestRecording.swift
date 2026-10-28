import Foundation

/// Diagnostic-only sidecar to RecordedRouteStore. It consumes its already admitted
/// camera samples; it neither captures sensors nor grants navigation authority.
public struct NavigationTestRecording: Sendable {
    public static let maximumSamples = 3_000
    public static let maximumEvents = 128
    public static let maximumRoutePoints = 2_048
    public enum Status: String, Codable, Sendable { case recording, stopped, capacityReached }
    public enum Problem: String, Codable, Sendable {
        case apparentWallCrossing, apparentFurnitureCrossing, wrongDirection
        case missedObstacle, falseBlockage, trackingMismatch, other
    }
    public enum Failure: Error, Equatable { case notRecording, invalidInput, capacityReached }
    /// Supplied measured registration metadata, not independently verified here.
    /// Keeping it alongside the raw trajectory makes an erroneous alignment auditable.
    public struct Alignment: Codable, Equatable, Sendable {
        public let sessionID: UUID
        public let sourceFrameID, revision, calibrationRevision, evidenceID: String
        public let map: SpatialMapBinding
        public let sourceToMap: NativeCameraTransform
        public let validFrom, validThrough: Double
        public init(sessionID: UUID, sourceFrameID: String, revision: String,
                    calibrationRevision: String, evidenceID: String, map: SpatialMapBinding,
                    sourceToMap: NativeCameraTransform, validFrom: Double, validThrough: Double) {
            self.sessionID = sessionID; self.sourceFrameID = sourceFrameID; self.revision = revision
            self.calibrationRevision = calibrationRevision; self.evidenceID = evidenceID; self.map = map
            self.sourceToMap = sourceToMap; self.validFrom = validFrom; self.validThrough = validThrough
        }
        fileprivate var valid: Bool {
            [sourceFrameID, revision, calibrationRevision, evidenceID, map.mapID, map.frameID, map.revision]
                .allSatisfy(NativeObservationRecord.validID) && sourceFrameID != map.frameID &&
            sourceToMap.valid && validFrom.isFinite && validThrough.isFinite && validFrom >= 0 && validThrough >= validFrom
        }
        fileprivate func accepts(_ sample: RecordedRouteSample) -> Bool {
            valid && sample.sessionID == sessionID && sample.sourceFrameID == sourceFrameID &&
            sample.capturedAt >= validFrom && sample.capturedAt <= validThrough &&
            sample.tracking == .normal && sample.mapTarget == map
        }
    }
    /// Read-only copy of an existing code-owned route, not a new plan/lease.
    public struct OwnedRoute: Equatable, Sendable {
        public let map: SpatialMapBinding
        public let routeRevision, goalRevision, bodyRevision, obstacleRevision: UUID
        public let artifactSHA256: String
        public let points: [Point3]
        public init(map: SpatialMapBinding, routeRevision: UUID, goalRevision: UUID,
                    bodyRevision: UUID, obstacleRevision: UUID, artifactSHA256: String, points: [Point3]) {
            self.map = map; self.routeRevision = routeRevision; self.goalRevision = goalRevision
            self.bodyRevision = bodyRevision; self.obstacleRevision = obstacleRevision
            self.artifactSHA256 = artifactSHA256; self.points = points
        }
    }
    public struct Plan: Codable, Equatable, Sendable {
        /// Empty points explicitly record route cancellation/unavailability.
        public let revision, goalRevision: UUID
        public let map: SpatialMapBinding
        public let points: [Point3]
        public let alignment: Alignment?
        public let recordedAt: Double
        public let bodyRevision, obstacleRevision: UUID?
        public let artifactSHA256: String?
        public init(revision: UUID, goalRevision: UUID, map: SpatialMapBinding,
                    points: [Point3], alignment: Alignment?, recordedAt: Double,
                    bodyRevision: UUID? = nil, obstacleRevision: UUID? = nil, artifactSHA256: String? = nil) {
            self.bodyRevision = bodyRevision; self.obstacleRevision = obstacleRevision; self.artifactSHA256 = artifactSHA256
            self.revision = revision; self.goalRevision = goalRevision; self.map = map
            self.points = points; self.alignment = alignment; self.recordedAt = recordedAt
        }
    }
    public struct Entry: Codable, Equatable, Sendable {
        public let sample: RecordedRouteSample
        public let receivedAt: Double
        public let planIndex: Int?
        /// Nil is unregistered/expired/limited, NEVER snapped to the nearest route.
        public let cameraInMap: Point3?
    }
    public struct Marker: Codable, Equatable, Sendable {
        public let problem: Problem
        public let recordedAt: Double
        /// Last sample, not a fabricated position at the instant the user tapped.
        public let lastObservationID: UUID?
        public let planIndex: Int?
    }
    public let id: UUID
    public let startedAt: Double
    public private(set) var status: Status = .recording
    public private(set) var endedAt: Double?
    public private(set) var entries: [Entry] = []
    public private(set) var plans: [Plan] = []
    public private(set) var markers: [Marker] = []
    public private(set) var archiveEvents: [NavigationTestArchiveEvent] = []
    public private(set) var restoredHistorical = false
    public private(set) var restoredInterrupted = false
    public var permitsPhysicalGuidance: Bool { false }
    private var lastEventAt: Double
    /// Only call following explicit Record action. No default or automatic resume.
    public init(explicitStartAt time: Double, id: UUID = UUID()) throws {
        guard time.isFinite, time >= 0 else { throw Failure.invalidInput }
        self.id = id; startedAt = time; lastEventAt = time
    }
    private mutating func admit(time: Double, count: Int, limit: Int) throws {
        guard status == .recording else { throw Failure.notRecording }
        guard time.isFinite, time >= lastEventAt else { throw Failure.invalidInput }
        guard count < limit else { finish(.capacityReached, at: time); throw Failure.capacityReached }
    }
    public mutating func setPlan(_ plan: Plan) throws {
        try admit(time: plan.recordedAt, count: plans.count, limit: Self.maximumEvents)
        guard (plan.points.isEmpty || plan.points.count >= 2), plan.points.count <= Self.maximumRoutePoints,
              (!plan.points.isEmpty || plan.alignment == nil),
              plan.points.allSatisfy(\.isFinite),
              plan.artifactSHA256.map({ $0.utf8.count == 64 && $0.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) } }) ?? true,
              [plan.map.mapID, plan.map.frameID, plan.map.revision].allSatisfy(NativeObservationRecord.validID),
              plan.alignment.map({ $0.valid && $0.map == plan.map }) ?? true else { throw Failure.invalidInput }
        plans.append(plan); lastEventAt = plan.recordedAt; archiveEvents.append(.plan(plan))
    }
    /// `receivedAt` is the local monotonic receipt time; samples retain their own
    /// capture times, including delayed delivery and source-session resets.
    public mutating func observe(_ sample: RecordedRouteSample, receivedAt: Double) throws {
        try admit(time: receivedAt, count: entries.count, limit: Self.maximumSamples)
        try sample.validate()
        guard sample.capturedAt >= startedAt, sample.capturedAt <= receivedAt, !entries.contains(where: { $0.sample.observationID == sample.observationID }) else { throw Failure.invalidInput }
        let index = plans.indices.last.flatMap { sample.capturedAt >= plans[$0].recordedAt ? $0 : nil }
        let plan = index.map { plans[$0] }
        let alignment = plan?.alignment
        let mapped: Point3?
        // A late sample must not acquire a newly changed route or alignment.
        if let plan, sample.capturedAt >= plan.recordedAt, let alignment, alignment.accepts(sample) {
            mapped = try alignment.sourceToMap.applying(to: sample.cameraPosition)
        } else { mapped = nil }
        let entry = Entry(sample: sample, receivedAt: receivedAt, planIndex: index, cameraInMap: mapped)
        entries.append(entry); lastEventAt = receivedAt; archiveEvents.append(.sample(entry))
    }
    public mutating func mark(_ problem: Problem, at time: Double) throws {
        try admit(time: time, count: markers.count, limit: Self.maximumEvents)
        let marker = Marker(problem: problem, recordedAt: time, lastObservationID: entries.last?.sample.observationID,
                            planIndex: plans.indices.last)
        markers.append(marker); lastEventAt = time; archiveEvents.append(.marker(marker))
    }
    public mutating func stop(at time: Double) throws {
        guard time.isFinite, time >= lastEventAt else { throw Failure.invalidInput }
        if status == .recording { finish(.stopped, at: time) }
    }
    private mutating func finish(_ reason: Status, at time: Double) {
        status = reason; endedAt = time; lastEventAt = time
        archiveEvents.append(.ended(status: reason, at: time))
    }
    /// Reconstruct only the validated committed prefix. Historical reads never
    /// restart recording, reinterpret source frames, or append invented samples.
    public static func restored(id: UUID, startedAt: Double, events: [NavigationTestArchiveEvent]) throws -> Self {
        guard events.count <= maximumSamples + 2 * maximumEvents + 1 else { throw Failure.invalidInput }
        var result = try Self(explicitStartAt: startedAt, id: id)
        for event in events {
            guard result.status == .recording else { throw Failure.invalidInput }
            switch event {
            case .plan(let plan): try result.setPlan(plan)
            case .sample(let entry):
                try result.observe(entry.sample, receivedAt: entry.receivedAt)
                guard result.entries.last == entry else { throw Failure.invalidInput }
            case .marker(let marker):
                try result.mark(marker.problem, at: marker.recordedAt)
                guard result.markers.last == marker else { throw Failure.invalidInput }
            case .ended(let status, let time):
                guard time.isFinite, time >= result.lastEventAt, status != .recording else { throw Failure.invalidInput }
                if status == .capacityReached {
                    guard result.entries.count == maximumSamples || result.plans.count == maximumEvents ||
                          result.markers.count == maximumEvents else { throw Failure.invalidInput }
                }
                result.finish(status, at: time)
            }
        }
        result.restoredHistorical = true
        if result.status == .recording {
            result.restoredInterrupted = true; result.status = .stopped
            // No actual stop timestamp is known. Keep it absent instead of using reopen time.
            result.endedAt = nil
        }
        return result
    }
    /// Separate line segments: never draw across tracking loss, plan/alignment
    /// revisions or an unregistered sample. Planned points remain independently visible.
    public struct OverlaySegment: Equatable, Sendable {
        public let planIndex: Int
        public let map: SpatialMapBinding
        public let points: [Point3]
    }
    public var overlaySegments: [OverlaySegment] {
        var result: [OverlaySegment] = [], current: [Point3] = []
        var previous: Entry?, currentPlan: Int?
        func segment(_ points: [Point3], _ index: Int?) -> OverlaySegment? {
            guard !points.isEmpty, let index else { return nil }
            return .init(planIndex: index, map: plans[index].map, points: points)
        }
        for entry in entries {
            let continuous = entry.sample.boundaryBefore == nil && previous?.planIndex == entry.planIndex &&
                previous?.sample.sessionID == entry.sample.sessionID && previous?.sample.sourceFrameID == entry.sample.sourceFrameID &&
                previous.map { entry.sample.capturedAt > $0.sample.capturedAt && entry.sample.capturedAt - $0.sample.capturedAt <= 0.5 } == true
            if !continuous || entry.cameraInMap == nil {
                if let value = segment(current, currentPlan) { result.append(value) }; current = []
            }
            if let point = entry.cameraInMap { current.append(point); currentPlan = entry.planIndex }
            previous = entry
        }
        if let value = segment(current, currentPlan) { result.append(value) }; return result
    }
}
