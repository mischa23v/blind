import Foundation

/// A bounded history of actual depth hits in one continuous sensor frame. A voxel
/// records a surface HIT, never an empty/free volume, a room label or floor safety.
public struct ObservedSceneCell: Sendable {
    public let x, y, z: Int
    public let point: Point3
    public let firstSeen, lastSeen: Double
    public let observations: Int
}

public struct ObservedSceneSnapshot: Sendable {
    public enum Status: String, Sendable { case observing, unavailable, wrongSession, invalidFrame, stale, outOfOrder }
    public let sessionID: UUID?
    public let revision: UUID
    public let status: Status
    public let capturedAt: Double?
    public let resolution: Double
    public let cells: [ObservedSceneCell]
    public let evictedCellCount: Int
    public let startCameraPosition: Point3?
    public let recordedCameraDistance: Double
    public let returnState: ReturnTrail.State
    public var authorizesPhysicalGuidance: Bool { false }
}

/// Actual LocalPlanner output, retaining its evidence ownership and explicit
/// candidate-only meaning. Never convert this to a SpatialLocalizationCapture.
public struct ObservedScenePlan: Sendable {
    public let sessionID: UUID?
    public let sceneRevision: UUID
    public let goalRevision: UUID
    public let capturedAt: Double?
    public let target: Point3
    public let local: LocalPlan
    public var authorizesPhysicalGuidance: Bool { false }
}

/// Adapter, not a SLAM/occupancy algorithm. Reuses the existing world projection
/// and LocalPlanner. Historical hits help inspect a growing scene; planning uses
/// ONLY the current observation so a newly occluded/missing cell stays unknown.
/// RTAB-Map's future timestamped local-grid adapter may supply free/ground cells;
/// no equivalent clearance is invented here from sparse hits or absent detections.
public struct ObservedSceneAccumulator: Sendable {
    public enum Intent: Equatable, Sendable { case lookAhead, destination(Point3), returnToStart }
    public struct Configuration: Sendable {
        public let resolution, historyAge, radius: Double
        public let maximumCells, maximumSamples: Int
        public init(resolution: Double = 0.1, historyAge: Double = 60, radius: Double = 12,
                    maximumCells: Int = 4096, maximumSamples: Int = 16384) {
            self.resolution = resolution; self.historyAge = historyAge; self.radius = radius
            self.maximumCells = maximumCells; self.maximumSamples = maximumSamples
        }
        var valid: Bool {
            resolution.isFinite && (0.05...1).contains(resolution) &&
            historyAge.isFinite && (0.5...120).contains(historyAge) &&
            radius.isFinite && (1...30).contains(radius) &&
            (1...16384).contains(maximumCells) && (1...32768).contains(maximumSamples)
        }
    }
    private struct Key: Hashable, Comparable, Sendable {
        let x, y, z: Int
        static func < (a: Key, b: Key) -> Bool {
            if a.x != b.x { return a.x < b.x }; if a.y != b.y { return a.y < b.y }; return a.z < b.z
        }
    }
    private let configuration: Configuration
    public private(set) var sessionID: UUID?
    public private(set) var revision = UUID()
    public private(set) var intent: Intent = .lookAhead
    public private(set) var goalRevision = UUID()
    private var status: ObservedSceneSnapshot.Status = .unavailable
    private var cells: [Key: ObservedSceneCell] = [:]
    private var current: Observation?
    private var lastTime: Double?
    private var start: Point3?
    private var recorder = JourneyRecorder()
    private var returnTrail = ReturnTrail()
    private var evicted = 0
    public init(configuration: Configuration = .init()) { self.configuration = configuration }
    public mutating func begin(sessionID: UUID) {
        self.sessionID = sessionID; cells = [:]; current = nil; lastTime = nil; start = nil
        recorder = JourneyRecorder(); returnTrail = ReturnTrail()
        evicted = 0; revision = UUID(); status = .unavailable
        intent = .lookAhead; goalRevision = UUID()
    }
    /// Tracking/coordinate continuity is gone. An old origin must not become a
    /// new session's return reference, even if its raw numeric coordinates match.
    public mutating func invalidate() {
        cells = [:]; current = nil; start = nil; recorder = JourneyRecorder(); returnTrail.invalidate()
        revision = UUID(); status = .unavailable
    }
    /// Intent never supplies pose/support. Return refers only to this continuous
    /// camera-frame origin, not a measured body position or cross-map reference.
    public mutating func setIntent(_ next: Intent, revision: UUID) {
        if goalRevision != revision {
            returnTrail = ReturnTrail()
            if next == .returnToStart, let current {
                _ = returnTrail.begin(journey: recorder.journey, camera: current.camera, at: current.timestamp)
            }
        }
        intent = next; goalRevision = revision
    }
    public func planCurrent(floor: Double?, body: BodyEnvelope, now: Double) -> ObservedScenePlan? {
        guard let current else { return nil }
        let target: Point3
        switch intent {
        case .lookAhead:
            target = Point3(current.camera.x + current.forward.x * 1.8, current.camera.y,
                            current.camera.z + current.forward.z * 1.8)
        case .destination(let point): target = point
        case .returnToStart:
            guard let recordedTarget = returnTrail.candidateTarget else { return nil }; target = recordedTarget
        }
        return plan(target: target, floor: floor, body: body, now: now)
    }
    public func snapshot() -> ObservedSceneSnapshot {
        .init(sessionID: sessionID, revision: revision, status: status, capturedAt: current?.timestamp,
              resolution: configuration.resolution, cells: cells.sorted { $0.key < $1.key }.map(\.value),
              evictedCellCount: evicted, startCameraPosition: start,
              recordedCameraDistance: recorder.distance, returnState: returnTrail.state)
    }
    @discardableResult public mutating func observe(_ observation: Observation, sessionID: UUID,
                                                   now: Double, hazard: Hazard = .uncertain) -> ObservedSceneSnapshot {
        // A delayed callback owned by another session cannot mutate this scene.
        guard self.sessionID == sessionID else {
            return .init(sessionID: self.sessionID, revision: revision, status: .wrongSession,
                capturedAt: current?.timestamp, resolution: configuration.resolution,
                cells: [], evictedCellCount: evicted, startCameraPosition: nil,
                recordedCameraDistance: recorder.distance, returnState: returnTrail.state)
        }
        current = nil; revision = UUID()
        guard configuration.valid, observation.trackingNormal,
              observation.timestamp.isFinite, observation.timestamp >= 0, now.isFinite,
              observation.camera.isFinite, observation.forward.isFinite,
              observation.samples.count <= configuration.maximumSamples,
              [observation.camera.x, observation.camera.y, observation.camera.z].allSatisfy({ abs($0) < 100_000 }) else {
            invalidate(); status = .invalidFrame; return snapshot()
        }
        guard now >= observation.timestamp, now - observation.timestamp <= 0.5 else {
            status = .stale; return snapshot()
        }
        guard lastTime.map({ observation.timestamp > $0 }) ?? true else {
            status = .outOfOrder; return snapshot()
        }
        // A long unseen gap cannot establish continuous return-frame ownership.
        if let lastTime, observation.timestamp - lastTime > 0.5 { invalidate() }
        lastTime = observation.timestamp; current = observation; status = .observing
        if start == nil { start = observation.camera }
        let continuityLost: Bool
        if intent == .returnToStart {
            let previousReturnState = returnTrail.state
            _ = returnTrail.update(camera: observation.camera, forward: observation.forward, at: observation.timestamp,
                                   tracking: observation.trackingNormal, hazard: hazard)
            continuityLost = previousReturnState != .invalidated && returnTrail.state == .invalidated
        } else {
            recorder.observe(camera: observation.camera, time: observation.timestamp, tracking: observation.trackingNormal)
            continuityLost = recorder.journey.points.last.map { $0.segment != 0 } ?? false
        }
        if continuityLost {
            // Reuse the existing recorder/trail jump policy. Do not blend a
            // normal-tracking coordinate discontinuity into earlier geometry.
            invalidate(); current = observation; start = observation.camera; status = .observing
            if intent != .returnToStart { recorder.observe(camera: observation.camera, time: observation.timestamp, tracking: true) }
        }
        cells = cells.filter { now - $0.value.lastSeen <= configuration.historyAge &&
            $0.value.point.distance(to: observation.camera) <= configuration.radius }
        var seen = Set<Key>()
        for sample in observation.samples where sample.confidence == 2 && sample.position.isFinite {
            guard sample.position.distance(to: observation.camera) <= configuration.radius else { continue }
            let p = sample.position, r = configuration.resolution
            let key = Key(x: Int(floor(p.x / r)), y: Int(floor(p.y / r)), z: Int(floor(p.z / r)))
            guard seen.insert(key).inserted else { continue } // correlated pixels do not become multiple frame observations
            let old = cells[key]
            cells[key] = .init(x: key.x, y: key.y, z: key.z, point: p,
                firstSeen: old?.firstSeen ?? observation.timestamp, lastSeen: observation.timestamp,
                observations: min(1_000_000, (old?.observations ?? 0) + 1))
        }
        if cells.count > configuration.maximumCells {
            let excess = cells.count - configuration.maximumCells
            let oldest = cells.sorted { a, b in a.value.lastSeen == b.value.lastSeen ? a.key < b.key : a.value.lastSeen < b.value.lastSeen }
            for entry in oldest.prefix(excess) { cells.removeValue(forKey: entry.key) }
            evicted = min(1_000_000_000, evicted + excess)
        }
        return snapshot()
    }
    public func plan(target: Point3, floor: Double?, body: BodyEnvelope, now: Double) -> ObservedScenePlan {
        var local = LocalPlan(.needsPosition)
        if let current, body.valid, target.isFinite,
           [target.x, target.y, target.z].allSatisfy({ abs($0) < 100_000 }) {
            var planner = LocalPlanner()
            planner.bodyRadius = body.radius + body.margin
            local = planner.plan(observation: current, floor: floor, target: target, now: now)
        }
        return .init(sessionID: sessionID, sceneRevision: revision, goalRevision: goalRevision, capturedAt: current?.timestamp,
                     target: target, local: local)
    }
}
