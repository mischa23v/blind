import Foundation

/// Containment is durable knowledge, not a claim about the person's current location.
public struct SpatialPlaceNode: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Equatable, Sendable { case world, place, building, floor, room }
    public let id: String
    public let kind: Kind
    public let parentID: String?
    public init(id: String, kind: Kind, parentID: String? = nil) {
        self.id = id; self.kind = kind; self.parentID = parentID
    }
}

/// Map, coordinate frame and geometry revision travel together. A room name is not a frame.
public struct SpatialMapBinding: Codable, Equatable, Hashable, Sendable {
    public let mapID: String
    public let frameID: String
    public let revision: String
    public init(mapID: String, frameID: String, revision: String) {
        self.mapID = mapID; self.frameID = frameID; self.revision = revision
    }
}

public struct SpatialMapRevision: Codable, Equatable, Sendable {
    public let binding: SpatialMapBinding
    public let nodeID: String
    /// An explicit conversion contract. Only metre coordinates are accepted here.
    public let metersPerUnit: Double?
    /// Existing IndoorMap level strings mapped explicitly to durable floor IDs.
    public let floorLevels: [String: String]
    public let savedWorldFrame: SavedWorldFrame?
    public init(binding: SpatialMapBinding, nodeID: String, metersPerUnit: Double?,
                floorLevels: [String: String], savedWorldFrame: SavedWorldFrame? = nil) {
        self.binding = binding; self.nodeID = nodeID; self.metersPerUnit = metersPerUnit
        self.floorLevels = floorLevels; self.savedWorldFrame = savedWorldFrame
    }
}

/// Gravity-aligned rigid transform: parentPoint = R_y(yaw) * childPoint + translation.
/// Uses existing Point3 / ARKit conventions (Y up, forward -Z), radians and metres.
/// No scale/shear or inferred GPS alignment. Tilted/non-gravity-aligned frames need a
/// different measured adapter and are deliberately not representable by this contract.
public struct SpatialRigidTransform: Codable, Equatable, Sendable {
    public let translation: Point3
    public let yaw: Double
    public init(translation: Point3, yaw: Double) { self.translation = translation; self.yaw = yaw }
    public static let identity = SpatialRigidTransform(translation: Point3(0, 0, 0), yaw: 0)
    public var valid: Bool { translation.isFinite && yaw.isFinite }
    public func applying(to point: Point3) throws -> Point3 {
        guard valid, point.isFinite else { throw SpatialRegistryError.invalidTransform }
        let result = Point3(cos(yaw) * point.x + sin(yaw) * point.z + translation.x,
                            point.y + translation.y,
                            -sin(yaw) * point.x + cos(yaw) * point.z + translation.z)
        guard result.isFinite else { throw SpatialRegistryError.invalidTransform }
        return result
    }
    public func applying(toYaw heading: Double) throws -> Double {
        guard valid, heading.isFinite, (heading + yaw).isFinite else { throw SpatialRegistryError.invalidTransform }
        return atan2(sin(heading + yaw), cos(heading + yaw))
    }
    public func inverted() throws -> SpatialRigidTransform {
        let rotation = SpatialRigidTransform(translation: Point3(0, 0, 0), yaw: -yaw)
        return try SpatialRigidTransform(translation: rotation.applying(to:
            Point3(-translation.x, -translation.y, -translation.z)), yaw: -yaw)
    }
    /// self after inner, not component-wise addition of translations.
    public func composed(after inner: SpatialRigidTransform) throws -> SpatialRigidTransform {
        guard valid, inner.valid, (yaw + inner.yaw).isFinite else { throw SpatialRegistryError.invalidTransform }
        return try SpatialRigidTransform(translation: applying(to: inner.translation),
                                         yaw: applying(toYaw: inner.yaw))
    }
}

public struct SpatialFrameLink: Codable, Equatable, Sendable {
    public let child: SpatialMapBinding
    public let parent: SpatialMapBinding
    public let childToParent: SpatialRigidTransform
    /// Identifies the measured/surveyed source. Metadata is not independent accuracy proof.
    public let source: String
    public init(child: SpatialMapBinding, parent: SpatialMapBinding,
                childToParent: SpatialRigidTransform, source: String) {
        self.child = child; self.parent = parent; self.childToParent = childToParent; self.source = source
    }
}

/// A known connection is not proof it is open, traversable, or currently crossed.
public struct SpatialTransition: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Equatable, Sendable { case doorway, entrance, stairs, elevator }
    public let id: String
    public let kind: Kind
    public let from: SpatialMapBinding
    public let to: SpatialMapBinding
    public let fromFloorID: String
    public let toFloorID: String
    public init(id: String, kind: Kind, from: SpatialMapBinding, to: SpatialMapBinding,
                fromFloorID: String, toFloorID: String) {
        self.id = id; self.kind = kind; self.from = from; self.to = to
        self.fromFloorID = fromFloorID; self.toFloorID = toFloorID
    }
}

/// Local-only persistence payload. No live pose, session clock, tracking or confidence.
/// Geometry stays in existing IndoorMap/ARWorldMap stores, not a second database here.
public struct SpatialRegistrySnapshot: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let nodes: [SpatialPlaceNode]
    public let maps: [SpatialMapRevision]
    public let activeBindings: [SpatialMapBinding]
    public let links: [SpatialFrameLink]
    public let transitions: [SpatialTransition]
    public init(nodes: [SpatialPlaceNode], maps: [SpatialMapRevision], activeBindings: [SpatialMapBinding],
                links: [SpatialFrameLink] = [], transitions: [SpatialTransition] = []) {
        schemaVersion = 1; self.nodes = nodes; self.maps = maps; self.activeBindings = activeBindings
        self.links = links; self.transitions = transitions
    }
}

public enum SpatialRegistryError: Error, Equatable {
    case invalidHierarchy, invalidMap, invalidMetricScale, invalidTransform, invalidTransition
    case staleRevision, missingTransform, unknownFloor, historyRewrite, invalidCapture, noCurrentPose
}

/// Validation/association foundation only. Does not localize, plan routes or prove clearance.
/// Immutable snapshots retain old map revisions; live evidence is separate and never encoded.
public struct SpatialFrameRegistry: Sendable {
    public private(set) var snapshot: SpatialRegistrySnapshot
    /// Volatile install identity. Any validated snapshot replacement retires live leases,
    /// even if a prior map revision is explicitly reselected later.
    public private(set) var installationID: UUID
    public init(snapshot: SpatialRegistrySnapshot) throws {
        self.snapshot = snapshot; installationID = UUID()
        try validate()
    }
    public init(data: Data) throws {
        try self.init(snapshot: JSONDecoder().decode(SpatialRegistrySnapshot.self, from: data))
    }
    public func encodedSnapshot() throws -> Data { try JSONEncoder().encode(snapshot) }
    public mutating func update(snapshot next: SpatialRegistrySnapshot) throws {
        let checked = try SpatialFrameRegistry(snapshot: next)
        // A revision cannot be silently overwritten or discarded by a geometry update.
        guard snapshot.maps.allSatisfy({ next.maps.contains($0) }),
              snapshot.nodes.allSatisfy({ next.nodes.contains($0) }),
              snapshot.links.allSatisfy({ next.links.contains($0) }),
              snapshot.transitions.allSatisfy({ next.transitions.contains($0) }) else {
            throw SpatialRegistryError.historyRewrite
        }
        self = checked
    }
    public func map(for binding: SpatialMapBinding) throws -> SpatialMapRevision {
        guard snapshot.activeBindings.contains(binding) else { throw SpatialRegistryError.staleRevision }
        guard let map = snapshot.maps.first(where: { $0.binding == binding }) else { throw SpatialRegistryError.invalidMap }
        return map
    }
    public func validateFloor(_ floorID: String, in binding: SpatialMapBinding) throws {
        let map = try map(for: binding)
        guard snapshot.nodes.contains(where: { $0.id == floorID && $0.kind == .floor }),
              map.floorLevels.values.contains(floorID) else { throw SpatialRegistryError.unknownFloor }
    }
    public func validateLocation(floorID: String, roomID: String?, in binding: SpatialMapBinding) throws {
        try validateFloor(floorID, in: binding)
        let record = try map(for: binding)
        let nodes = Dictionary(uniqueKeysWithValues: snapshot.nodes.map { ($0.id, $0) })
        if let roomID {
            guard nodes[roomID]?.kind == .room, nodes[roomID]?.parentID == floorID,
                  Self.isAncestor(record.nodeID, of: roomID, nodes: nodes) else {
                throw SpatialRegistryError.unknownFloor
            }
        } else if nodes[record.nodeID]?.kind == .room {
            throw SpatialRegistryError.unknownFloor
        }
    }
    /// Adapter validation reuses IndoorMap's own geometry validation. No routing replacement.
    public func validateIndoorMap(_ indoorMap: IndoorMap, for binding: SpatialMapBinding) throws {
        let record = try map(for: binding)
        try indoorMap.validate()
        // An unbound legacy graph can still be previewed elsewhere, but a caller-supplied
        // binding alone must not relabel arbitrary geometry as the active map.
        guard indoorMap.packageID == binding.mapID, indoorMap.packageRevision == binding.revision,
              indoorMap.packageModified != true else { throw SpatialRegistryError.staleRevision }
        if !indoorMap.permitsRoutePlanning {
            guard record.savedWorldFrame != nil, record.floorLevels.isEmpty,
                  snapshot.nodes.first(where: { $0.id == record.nodeID })?.kind == .place else {
                throw SpatialRegistryError.invalidMap
            }
        }
        let levels = indoorMap.nodes.map(\.level) + (indoorMap.surfaces ?? []).map(\.level)
            + (indoorMap.keepOutZones ?? []).map(\.level)
        guard levels.allSatisfy({ record.floorLevels[$0] != nil }) else { throw SpatialRegistryError.unknownFloor }
    }
    /// Standard parent/local transform composition, not path planning. Never bridges
    /// independent roots or map revisions by proximity, equal labels or identity default.
    public func transform(from: SpatialMapBinding, to: SpatialMapBinding) throws -> SpatialRigidTransform {
        _ = try map(for: from); _ = try map(for: to)
        if from == to { return .identity }
        let source = try ancestors(of: from)
        let target = try ancestors(of: to)
        for (common, sourceToCommon) in source {
            if let (_, targetToCommon) = target.first(where: { $0.0 == common }) {
                return try targetToCommon.inverted().composed(after: sourceToCommon)
            }
        }
        throw SpatialRegistryError.missingTransform
    }
    public func validateTransition(id: String) throws -> SpatialTransition {
        guard let transition = snapshot.transitions.first(where: { $0.id == id }) else {
            throw SpatialRegistryError.invalidTransition
        }
        try validateFloor(transition.fromFloorID, in: transition.from)
        try validateFloor(transition.toFloorID, in: transition.to)
        _ = try transform(from: transition.from, to: transition.to)
        return transition // Still not a crossing/clearance authorization.
    }
    private func ancestors(of binding: SpatialMapBinding) throws -> [(SpatialMapBinding, SpatialRigidTransform)] {
        var result = [(binding, SpatialRigidTransform.identity)]
        var current = binding, accumulated = SpatialRigidTransform.identity
        while let link = snapshot.links.first(where: { $0.child == current }) {
            _ = try map(for: link.parent)
            accumulated = try link.childToParent.composed(after: accumulated)
            current = link.parent; result.append((current, accumulated))
        }
        return result
    }
    private func validate() throws {
        let s = snapshot
        guard s.schemaVersion == 1, !s.nodes.isEmpty, s.nodes.count <= 10_000,
              s.maps.count <= 10_000, s.links.count <= 10_000, s.transitions.count <= 10_000,
              Set(s.nodes.map(\.id)).count == s.nodes.count,
              s.nodes.filter({ $0.kind == .world }).count == 1 else { throw SpatialRegistryError.invalidHierarchy }
        let nodes = Dictionary(uniqueKeysWithValues: s.nodes.map { ($0.id, $0) })
        for node in s.nodes {
            guard Self.validID(node.id) else { throw SpatialRegistryError.invalidHierarchy }
            let expected: SpatialPlaceNode.Kind?
            switch node.kind {
            case .world: expected = nil
            case .place: expected = .world
            case .building: expected = .place
            case .floor: expected = .building
            case .room: expected = .floor
            }
            guard (expected == nil ? node.parentID == nil : node.parentID.flatMap({ nodes[$0]?.kind }) == expected) else {
                throw SpatialRegistryError.invalidHierarchy
            }
        }
        guard Set(s.maps.map(\.binding)).count == s.maps.count,
              Set(s.activeBindings.map(\.mapID)).count == s.activeBindings.count else { throw SpatialRegistryError.invalidMap }
        var versions: [String: Set<String>] = [:]
        for map in s.maps {
            let binding = map.binding
            guard Self.validID(binding.mapID), Self.validID(binding.frameID), Self.validID(binding.revision),
                  nodes[map.nodeID] != nil, versions[binding.mapID, default: []].insert(binding.revision).inserted else {
                throw SpatialRegistryError.invalidMap
            }
            guard map.metersPerUnit == 1 else { throw SpatialRegistryError.invalidMetricScale }
            guard Set(map.floorLevels.values).count == map.floorLevels.count else { throw SpatialRegistryError.unknownFloor }
            for (level, floorID) in map.floorLevels {
                guard Self.validID(level), nodes[floorID]?.kind == .floor,
                      Self.isAncestor(map.nodeID, of: floorID, nodes: nodes)
                        || Self.isAncestor(floorID, of: map.nodeID, nodes: nodes) else { throw SpatialRegistryError.unknownFloor }
            }
            if let saved = map.savedWorldFrame {
                guard saved.valid, saved.frameID == binding.frameID, saved.revision == binding.revision else {
                    throw SpatialRegistryError.invalidMap
                }
            }
        }
        let bindings = Set(s.maps.map(\.binding))
        guard s.activeBindings.allSatisfy({ bindings.contains($0) }),
              Set(s.links.map(\.child)).count == s.links.count else { throw SpatialRegistryError.invalidMap }
        for link in s.links {
            guard bindings.contains(link.child), bindings.contains(link.parent), link.child != link.parent,
                  link.childToParent.valid, Self.validID(link.source) else { throw SpatialRegistryError.invalidTransform }
            var visited = Set<SpatialMapBinding>(), current = link.child
            while let next = s.links.first(where: { $0.child == current }) {
                guard visited.insert(current).inserted else { throw SpatialRegistryError.invalidTransform }
                current = next.parent
            }
        }
        guard Set(s.transitions.map(\.id)).count == s.transitions.count else { throw SpatialRegistryError.invalidTransition }
        for transition in s.transitions {
            guard Self.validID(transition.id), bindings.contains(transition.from), bindings.contains(transition.to),
                  let from = s.maps.first(where: { $0.binding == transition.from }),
                  let to = s.maps.first(where: { $0.binding == transition.to }),
                  from.floorLevels.values.contains(transition.fromFloorID),
                  to.floorLevels.values.contains(transition.toFloorID),
                  transition.kind != .doorway || transition.fromFloorID == transition.toFloorID else {
                throw SpatialRegistryError.invalidTransition
            }
        }
    }
    private static func validID(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && value.utf8.count <= 200
    }
    private static func isAncestor(_ ancestor: String, of child: String, nodes: [String: SpatialPlaceNode]) -> Bool {
        var current: String? = child
        while let id = current {
            if id == ancestor { return true }
            current = nodes[id]?.parentID
        }
        return false
    }
}
