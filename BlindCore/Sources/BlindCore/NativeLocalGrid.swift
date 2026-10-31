import Foundation

/// Already-decoded upstream local-grid XYZ samples. These are node/base-local
/// 3D cells, NOT ARKit-world points. Ground/empty labels are not walking support.
public struct NativeLocalGridCells: Equatable, Sendable {
    public let points: [Point3]
    public let originalCount: Int
    public let available, truncated: Bool
    public init(points: [Point3], originalCount: Int, available: Bool, truncated: Bool) {
        self.points = points; self.originalCount = originalCount
        self.available = available; self.truncated = truncated
    }
    public static let unavailable = NativeLocalGridCells(points: [], originalCount: 0, available: false, truncated: false)
    fileprivate var valid: Bool {
        guard points.count <= 4096, originalCount >= points.count,
              points.allSatisfy({ $0.isFinite && abs($0.x) <= 100_000 && abs($0.y) <= 100_000 && abs($0.z) <= 100_000 }) else { return false }
        if !available { return points.isEmpty && originalCount == 0 && !truncated }
        return truncated == (originalCount > points.count)
    }
}

public struct NativeLocalGridNodePose: Equatable, Sendable {
    public let id: Int
    public let transform: NativeCameraTransform
    public init(id: Int, transform: NativeCameraTransform) { self.id = id; self.transform = transform }
}

/// Bounded, copied output from the pinned RTAB-Map producer. All transforms use
/// full column-major rigid matrices. Map coordinates are RTAB Z-up; optical means
/// the upstream RGB camera model (including its image rotation), not ARKit GL.
/// This packet carries no calibrated position error, body pose or release right.
public struct NativeLocalGridPacket: Equatable, Sendable {
    public enum Status: String, Sendable { case available, unavailable, invalid, unassociated }
    public let status: Status
    public let generation, frameRevision, eventRevision, captureSequence: UInt64
    public let capturedAt, upstreamStamp: Double
    public let nodeID, mapID: Int
    public let cellSize: Double
    public let mapCorrection, cameraToARWorld: NativeCameraTransform
    public let mapFromCameraOptical: NativeCameraTransform?
    public let poses: [NativeLocalGridNodePose]
    public let ground, obstacles, empty: NativeLocalGridCells
    public let graphTruncated: Bool
    public init(status: Status, generation: UInt64, frameRevision: UInt64, eventRevision: UInt64,
                captureSequence: UInt64, capturedAt: Double, upstreamStamp: Double, nodeID: Int, mapID: Int,
                cellSize: Double, mapCorrection: NativeCameraTransform, cameraToARWorld: NativeCameraTransform,
                mapFromCameraOptical: NativeCameraTransform?, poses: [NativeLocalGridNodePose],
                ground: NativeLocalGridCells, obstacles: NativeLocalGridCells, empty: NativeLocalGridCells,
                graphTruncated: Bool) {
        self.status = status; self.generation = generation; self.frameRevision = frameRevision
        self.eventRevision = eventRevision; self.captureSequence = captureSequence
        self.capturedAt = capturedAt; self.upstreamStamp = upstreamStamp; self.nodeID = nodeID; self.mapID = mapID
        self.cellSize = cellSize; self.mapCorrection = mapCorrection; self.cameraToARWorld = cameraToARWorld
        self.mapFromCameraOptical = mapFromCameraOptical; self.poses = poses
        self.ground = ground; self.obstacles = obstacles; self.empty = empty; self.graphTruncated = graphTruncated
    }
}

public struct NativeLocalGridTile: Equatable, Sendable {
    public let nodeID, mapID: Int
    public let captureSequence: UInt64
    public let capturedAt, upstreamStamp, cellSize: Double
    /// Apply this transform exactly once to a cell to obtain RTAB-map coordinates.
    public let mapFromNode: NativeCameraTransform
    public let ground, obstacles, empty: NativeLocalGridCells
    public var cellCount: Int { ground.points.count + obstacles.points.count + empty.points.count }
    public var truncated: Bool { ground.truncated || obstacles.truncated || empty.truncated }
    fileprivate func corrected(_ pose: NativeCameraTransform) -> NativeLocalGridTile {
        .init(nodeID: nodeID, mapID: mapID, captureSequence: captureSequence, capturedAt: capturedAt,
              upstreamStamp: upstreamStamp, cellSize: cellSize, mapFromNode: pose,
              ground: ground, obstacles: obstacles, empty: empty)
    }
}

public struct NativeLocalGridSnapshot: Equatable, Sendable {
    public enum Status: String, Sendable { case available, unavailable, invalid, unassociated, expired, truncated }
    public let status: Status
    public let generation: UInt64?
    public let frameRevision, eventRevision: UInt64
    public let capturedAt: Double?
    /// Exact upstream capture association; not an AR session/frame identity.
    public let currentCaptureSequence: UInt64?
    public let currentNodeID: Int?
    public let mapCorrection: NativeCameraTransform?
    public let cameraToARWorld, currentOpticalPose: NativeCameraTransform?
    public let tiles: [NativeLocalGridTile]
    public let evictedTileCount: Int
    public var tileCount: Int { tiles.count }
    public var groundCellCount: Int { tiles.reduce(0) { $0 + $1.ground.points.count } }
    public var obstacleCellCount: Int { tiles.reduce(0) { $0 + $1.obstacles.points.count } }
    public var emptyCellCount: Int { tiles.reduce(0) { $0 + $1.empty.points.count } }
    public var cellCount: Int { groundCellCount + obstacleCellCount + emptyCellCount }
    public var authorizesPhysicalGuidance: Bool { false }
}

/// Ownership/retention adapter only: no new SLAM, ray carving, floor inference or
/// planner. The native producer supplies original capture associations and every
/// retained node's corrected pose on each event. Omitted nodes become unknown.
public struct NativeLocalGridConsumer: Sendable {
    public static let maximumTiles = 32
    public static let maximumCells = 16_384
    public static let maximumNodePoses = 64
    private var generation: UInt64?
    private var frameRevision: UInt64 = 0
    private var eventRevision: UInt64 = 0
    private var status: NativeLocalGridSnapshot.Status = .unavailable
    private var tiles: [Int: NativeLocalGridTile] = [:]
    private var mapID: Int?
    private var correction: NativeCameraTransform?
    private var capturedAt: Double?
    private var opticalPose, arPose: NativeCameraTransform?
    private var lastAssociation: (sequence: UInt64, time: Double, stamp: Double, node: Int, map: Int, ar: NativeCameraTransform)?
    private var evicted = 0
    private var resourceTruncated = false
    public init() {}
    public mutating func begin(generation: UInt64) {
        self = NativeLocalGridConsumer()
        if generation > 0 { self.generation = generation }
    }
    /// Retires the owner too: a queued packet cannot restart an invalidated map.
    public mutating func invalidate() { self = NativeLocalGridConsumer() }
    public func snapshot() -> NativeLocalGridSnapshot {
        .init(status: status, generation: generation, frameRevision: frameRevision, eventRevision: eventRevision,
              capturedAt: capturedAt, currentCaptureSequence: lastAssociation?.sequence, currentNodeID: lastAssociation?.node,
              mapCorrection: correction, cameraToARWorld: arPose,
              currentOpticalPose: opticalPose, tiles: tiles.values.sorted { $0.nodeID < $1.nodeID }, evictedTileCount: evicted)
    }
    /// Call from the native watchdog as well as on receipt; silence cannot extend
    /// a capture's half-second current-pose lease or the 30-second hit history.
    public mutating func snapshot(now: Double) -> NativeLocalGridSnapshot {
        guard now.isFinite, now >= 0 else {
            opticalPose = nil; arPose = nil; status = .invalid; return snapshot()
        }
        tiles = tiles.filter { now >= $0.value.capturedAt && now - $0.value.capturedAt <= 30 }
        if let capturedAt, now < capturedAt || now - capturedAt > 0.5 {
            opticalPose = nil; arPose = nil
            if status == .available || status == .truncated { status = .expired }
        }
        return snapshot()
    }
    @discardableResult public mutating func consume(_ packet: NativeLocalGridPacket, now: Double) -> NativeLocalGridSnapshot {
        // Wrong owners and already superseded events may not even expire or
        // change diagnostics belonging to a newer owner.
        guard generation == packet.generation, generation != nil,
              packet.frameRevision > frameRevision ||
                (packet.frameRevision == frameRevision && packet.eventRevision > eventRevision) else { return snapshot() }
        guard packet.frameRevision > 0, packet.eventRevision > 0 else { return snapshot() }
        if packet.frameRevision > frameRevision || (mapID != nil && mapID != packet.mapID) {
            tiles = [:]; correction = nil; resourceTruncated = false; lastAssociation = nil
        }
        frameRevision = packet.frameRevision; eventRevision = packet.eventRevision; mapID = packet.mapID
        opticalPose = nil; arPose = nil; capturedAt = nil

        // Check finite/bounded structure before dictionary construction or point
        // transforms. A malformed newest graph retires old graph geometry.
        guard now.isFinite, now >= 0, packet.poses.count <= Self.maximumNodePoses,
              packet.poses.allSatisfy({ $0.id > 0 && Self.validTransform($0.transform) }),
              Set(packet.poses.map(\.id)).count == packet.poses.count,
              Self.validTransform(packet.mapCorrection), packet.ground.valid,
              packet.obstacles.valid, packet.empty.valid else {
            tiles = [:]; correction = nil; status = .invalid; return snapshot()
        }
        let poses = Dictionary(uniqueKeysWithValues: packet.poses.map { ($0.id, $0.transform) })
        correction = packet.mapCorrection
        // Even a truncated graph is not permission to retain a missing pose.
        tiles = tiles.compactMapValues { tile in
            guard let pose = poses[tile.nodeID], now >= tile.capturedAt, now - tile.capturedAt <= 30 else { return nil }
            return tile.corrected(pose)
        }
        guard packet.status == .available else {
            switch packet.status {
            case .unavailable: status = .unavailable
            case .invalid: status = .invalid
            case .unassociated: status = .unassociated
            case .available: break
            }
            return snapshot()
        }
        guard packet.captureSequence > 0, packet.nodeID > 0, packet.mapID >= 0,
              let nodePose = poses[packet.nodeID] else {
            status = .unassociated; return snapshot()
        }
        guard packet.capturedAt.isFinite, packet.capturedAt >= 0, packet.upstreamStamp.isFinite, packet.upstreamStamp > 0,
              packet.capturedAt <= now, packet.cellSize.isFinite, (0.01...1).contains(packet.cellSize),
              Self.validTransform(packet.cameraToARWorld),
              packet.mapFromCameraOptical.map(Self.validTransform) ?? true else {
            status = .invalid; return snapshot()
        }
        if let previous = lastAssociation {
            let repeated = packet.captureSequence == previous.sequence && packet.capturedAt == previous.time &&
                packet.upstreamStamp == previous.stamp && packet.nodeID == previous.node && packet.mapID == previous.map &&
                packet.cameraToARWorld == previous.ar
            let newer = packet.captureSequence > previous.sequence && packet.capturedAt > previous.time &&
                packet.upstreamStamp > previous.stamp
            guard repeated || newer else {
                status = .unassociated; return snapshot()
            }
        }
        lastAssociation = (packet.captureSequence, packet.capturedAt, packet.upstreamStamp, packet.nodeID, packet.mapID, packet.cameraToARWorld)
        capturedAt = packet.capturedAt
        let hasLayer = packet.ground.available || packet.obstacles.available || packet.empty.available
        if now - packet.capturedAt <= 30, hasLayer {
            tiles[packet.nodeID] = .init(nodeID: packet.nodeID, mapID: packet.mapID,
                captureSequence: packet.captureSequence, capturedAt: packet.capturedAt,
                upstreamStamp: packet.upstreamStamp, cellSize: packet.cellSize, mapFromNode: nodePose,
                ground: packet.ground, obstacles: packet.obstacles, empty: packet.empty)
        } else {
            // A replaced current tile whose layers disappeared is unknown, not
            // an excuse to revive that node's older obstacle/support samples.
            tiles.removeValue(forKey: packet.nodeID)
        }
        trim()
        guard now - packet.capturedAt <= 0.5 else { status = .expired; return snapshot() }
        opticalPose = packet.mapFromCameraOptical; arPose = packet.cameraToARWorld
        if packet.graphTruncated || resourceTruncated || tiles.values.contains(where: \.truncated) {
            status = .truncated
        } else {
            status = hasLayer && opticalPose != nil ? .available : .unavailable
        }
        return snapshot()
    }
    private mutating func trim() {
        var count = tiles.values.reduce(0) { $0 + $1.cellCount }
        for tile in tiles.values.sorted(by: { $0.capturedAt == $1.capturedAt ? $0.nodeID < $1.nodeID : $0.capturedAt < $1.capturedAt }) {
            guard tiles.count > Self.maximumTiles || count > Self.maximumCells else { break }
            tiles.removeValue(forKey: tile.nodeID); count -= tile.cellCount
            evicted = min(1_000_000_000, evicted + 1); resourceTruncated = true
        }
    }
    private static func validTransform(_ transform: NativeCameraTransform) -> Bool {
        transform.valid && [12,13,14].allSatisfy { abs(transform.columns[$0]) <= 1_000_000 }
    }
}

/// Current capture-only view over upstream evidence, never an accumulated map
/// presented as present-day clearance. Coordinates remain RTAB node/map-local.
public struct NativeCurrentNavigationEvidence: Equatable, Sendable {
    public struct Revision: Equatable, Sendable {
        public let generation, frame, event, captureSequence: UInt64
        public let nodeID, mapID: Int
    }
    public let revision: Revision
    public let capturedAt, evaluatedAt: Double
    public var age: Double { evaluatedAt - capturedAt }
    public let tile: NativeLocalGridTile
    public let historicalTileCount: Int
    // The upstream mailbox does not carry the original AR session/frame UUID or
    // a registered metric-frame identity. Never manufacture these from time/IDs.
    public var originalARCaptureIdentityAvailable: Bool { false }
    public var registeredMetricFrameAvailable: Bool { false }
    public var fullFootprintSupportKnown: Bool { false }
    public var absenceEstablishesFreeSpace: Bool { false }
    public var authorizesPhysicalGuidance: Bool { false }
}

public enum NativeNavigationEvidence: Equatable, Sendable {
    public enum Unavailable: String, Sendable {
        case dependencyAbsent, inactive, invalidClock, missingCapture, staleCapture
        case sourceUnavailable, truncated, captureTileMissing, unassociated
    }
    case unavailable(Unavailable)
    case current(NativeCurrentNavigationEvidence)
    public var authorizesPhysicalGuidance: Bool { false }
}

extension NativeLocalGridSnapshot {
    /// Re-evaluate at every consumer/delivery boundary. Cached available status
    /// cannot extend freshness. Older tiles stay history, not current obstacles,
    /// and missing/replaced objects do not become a proof of empty space.
    public func navigationEvidence(now: Double) -> NativeNavigationEvidence {
        guard now.isFinite, now >= 0 else { return .unavailable(.invalidClock) }
        guard let capturedAt, capturedAt.isFinite, capturedAt >= 0 else { return .unavailable(.missingCapture) }
        guard now >= capturedAt, now - capturedAt <= 0.5 else { return .unavailable(.staleCapture) }
        guard status != .truncated else { return .unavailable(.truncated) }
        guard status == .available else { return .unavailable(.sourceUnavailable) }
        guard let generation, let sequence = currentCaptureSequence, let node = currentNodeID,
              currentOpticalPose != nil, cameraToARWorld != nil else { return .unavailable(.unassociated) }
        let matching = tiles.filter { $0.nodeID == node && $0.captureSequence == sequence && $0.capturedAt == capturedAt }
        guard matching.count == 1, let tile = matching.first else { return .unavailable(.captureTileMissing) }
        guard !tile.truncated else { return .unavailable(.truncated) }
        return .current(.init(revision: .init(generation: generation, frame: frameRevision,
            event: eventRevision, captureSequence: sequence, nodeID: node, mapID: tile.mapID),
            capturedAt: capturedAt, evaluatedAt: now, tile: tile, historicalTileCount: max(0, tiles.count - 1)))
    }
    public func isCurrent(_ evidence: NativeCurrentNavigationEvidence, now: Double) -> Bool {
        guard case .current(let current) = navigationEvidence(now: now) else { return false }
        return current.revision == evidence.revision && current.tile == evidence.tile
    }
}
