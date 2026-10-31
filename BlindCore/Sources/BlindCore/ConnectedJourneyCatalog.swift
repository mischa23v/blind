import Foundation

/// A sourced portal requires BOTH bound endpoint landmarks and an explicit known
/// path length/accessibility contract. No zero-length/outside edge is invented.
/// Its presence does not authorize crossing instructions or establish clearance.
public struct JourneyPortal: Codable, Equatable, Sendable {
    public enum Direction: String, Codable, Sendable { case fromToOnly, bidirectional }
    public let direction: Direction
    public let transitionID: String
    public let from: JourneyEndpoint
    public let to: JourneyEndpoint
    public let source: String
    public let surveyedDistance: Double
    public let accessible: Bool
    public init(transitionID: String, from: JourneyEndpoint, to: JourneyEndpoint,
                source: String, surveyedDistance: Double, accessible: Bool, direction: Direction) {
        self.transitionID = transitionID; self.from = from; self.to = to
        self.source = source; self.surveyedDistance = surveyedDistance; self.accessible = accessible; self.direction = direction
    }
}

public enum JourneyLeg: Equatable, Sendable {
    case local(from: JourneyEndpoint, to: JourneyEndpoint)
    case portal(id: String, from: JourneyEndpoint, to: JourneyEndpoint)
    public var from: JourneyEndpoint {
        switch self { case .local(let from, _), .portal(_, let from, _): return from }
    }
    public var to: JourneyEndpoint {
        switch self { case .local(_, let to), .portal(_, _, let to): return to }
    }
}

/// Immutable, already-installed geometry. Topology planning delegates to the
/// EXISTING IndoorMap.route implementation. Topology is not a live route ticket.
/// Missing maps or portal endpoints are omitted, never fabricated from GPS, labels,
/// appearance or old traversal history. All registry revisions remain explicit.
public struct ConnectedJourneyCatalog: Sendable {
    public let registry: SpatialFrameRegistry
    public let installations: [SpatialMapBinding: SpatialMapInstallation]
    public let portals: [JourneyPortal]
    public init(registry: SpatialFrameRegistry, installations: [SpatialMapInstallation], portals: [JourneyPortal]) throws {
        guard installations.count <= 32, portals.count <= 128,
              Set(installations.map(\.binding)).count == installations.count,
              Set(portals.map(\.transitionID)).count == portals.count,
              installations.allSatisfy({ $0.map.permitsRoutePlanning && $0.registry.snapshot == registry.snapshot }),
              installations.reduce(0, { $0 + $1.map.nodes.count }) <= 2000 else {
            throw ConnectedJourneyError.invalidCatalog
        }
        self.registry = registry; self.installations = Dictionary(uniqueKeysWithValues: installations.map { ($0.binding, $0) })
        self.portals = portals
        for portal in portals { try validate(portal) }
    }
    public func node(_ endpoint: JourneyEndpoint) throws -> MapNode {
        guard let installation = installations[endpoint.binding] else { throw ConnectedJourneyError.unavailableMap }
        try registry.validateLocation(floorID: endpoint.floorID, roomID: endpoint.roomID, in: endpoint.binding)
        let record = try registry.map(for: endpoint.binding)
        guard let node = installation.map.nodes.first(where: { $0.id == endpoint.nodeID }),
              record.floorLevels[node.level] == endpoint.floorID else { throw ConnectedJourneyError.unavailableReference }
        return node
    }
    public func context(_ endpoint: JourneyEndpoint) throws -> JourneyContext {
        _ = try node(endpoint)
        let nodes = Dictionary(uniqueKeysWithValues: registry.snapshot.nodes.map { ($0.id, $0) })
        guard let building = nodes[endpoint.floorID]?.parentID,
              let place = nodes[building]?.parentID, let world = nodes[place]?.parentID else {
            throw ConnectedJourneyError.unavailableReference
        }
        return .init(worldID: world, placeID: place, buildingID: building, floorID: endpoint.floorID, roomID: endpoint.roomID)
    }
    public func validate(_ reference: JourneyReference) throws {
        guard try context(reference.endpoint) == reference.context,
              installations[reference.endpoint.binding]?.artifact.sha256 == reference.artifactSHA256 else {
            throw ConnectedJourneyError.unavailableReference
        }
    }
    public func validate(_ portal: JourneyPortal) throws {
        guard !portal.source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              portal.source.utf8.count <= 200, portal.surveyedDistance.isFinite,
              portal.surveyedDistance > 0, portal.surveyedDistance <= 1000 else {
            throw ConnectedJourneyError.incompletePortal
        }
        let transition = try registry.validateTransition(id: portal.transitionID)
        guard transition.from == portal.from.binding, transition.to == portal.to.binding,
              transition.fromFloorID == portal.from.floorID, transition.toFloorID == portal.to.floorID,
              portal.from != portal.to else { throw ConnectedJourneyError.incompletePortal }
        let from = try node(portal.from), to = try node(portal.to)
        let transform = try registry.transform(from: portal.from.binding, to: portal.to.binding)
        guard try transform.applying(to: from.position).distance(to: to.position) <= portal.surveyedDistance + 0.000001 else {
            throw ConnectedJourneyError.incompletePortal
        }
        // validateTransition requires a composed known transform. Neither endpoint
        // equality nor transform composition itself is a crossing/clearance proof.
    }
    public func reference(endpoint: JourneyEndpoint, kind: JourneyReference.Kind,
                          at: Date, captureID: UUID? = nil) throws -> JourneyReference {
        let context = try context(endpoint)
        guard let installation = installations[endpoint.binding] else { throw ConnectedJourneyError.unavailableMap }
        return .init(id: UUID(), kind: kind, endpoint: endpoint, context: context,
                     artifactSHA256: installation.artifact.sha256, recordedAt: at, historicalCaptureID: captureID)
    }
    public func plan(from: JourneyEndpoint, to: JourneyEndpoint, body: BodyEnvelope) throws -> [JourneyLeg] {
        _ = try node(from); _ = try node(to)
        if from == to { return [] }
        var nodes: [MapNode] = [], edges: [MapEdge] = []
        var endpoints: [String: JourneyEndpoint] = [:], keys: [JourneyEndpoint: String] = [:]
        // Node identity includes its exact binding and floor. A room name cannot
        // alias another map or floor. Per-node room metadata is preserved where known.
        for (mapIndex, installation) in installations.values.sorted(by: { $0.binding.mapID < $1.binding.mapID }).enumerated() {
            let record = try registry.map(for: installation.binding)
            for (nodeIndex, local) in installation.map.nodes.enumerated() {
                let endpoint = JourneyEndpoint(binding: installation.binding, floorID: record.floorLevels[local.level]!, nodeID: local.id)
                let key = "m\(mapIndex)n\(nodeIndex)"
                endpoints[key] = endpoint; keys[endpoint] = key
                nodes.append(.init(id: key, name: local.name, level: key, position: local.position))
            }
            // Reuse existing collision/restriction predicates; the graph below has
            // no merged geometric surface and is explicitly only a topology view.
            for edge in installation.map.edges {
                let a = installation.map.nodes.first { $0.id == edge.from }!
                let b = installation.map.nodes.first { $0.id == edge.to }!
                let ea = JourneyEndpoint(binding: installation.binding, floorID: record.floorLevels[a.level]!, nodeID: a.id)
                let eb = JourneyEndpoint(binding: installation.binding, floorID: record.floorLevels[b.level]!, nodeID: b.id)
                guard a.level == b.level, edge.accessible,
                      !installation.currentRestrictions.blocked.contains(.init(MapConnection(a.id, b.id))),
                      installation.map.restriction(from: a.position, to: b.position, level: a.level, body: body) == nil,
                      !installation.currentRestrictions.zones.contains(where: { $0.level == a.level && $0.intersects(from: a.position, to: b.position, padding: body.radius + body.margin) }),
                      let surface = installation.map.surfaces?.first(where: { $0.level == a.level }),
                      surface.permitsLeg(from: a.position, to: b.position, body: body) else { continue }
                edges.append(.init(from: keys[ea]!, to: keys[eb]!, distance: edge.distance))
            }
        }
        func canonical(_ endpoint: JourneyEndpoint) -> JourneyEndpoint {
            .init(binding: endpoint.binding, floorID: endpoint.floorID, nodeID: endpoint.nodeID)
        }
        var connections: [MapConnection: JourneyPortal] = [:]
        for portal in portals where portal.accessible {
            let a = keys[canonical(portal.from)]!, b = keys[canonical(portal.to)]!
            // A duplicate portal for the same exact endpoints is ambiguous rather
            // than an arbitrary selection between stairs/lift/source identities.
            let connection = MapConnection(a, b)
            guard connections[connection] == nil else { throw ConnectedJourneyError.incompletePortal }
            connections[connection] = portal
            edges.append(.init(from: a, to: b, distance: portal.surveyedDistance))
        }
        let topology = IndoorMap(name: "Connected topology only; not clearance", nodes: nodes, edges: edges)
        let selected = try topology.route(from: keys[canonical(from)]!, to: keys[canonical(to)]!, body: body)
        var legs: [JourneyLeg] = []
        for (a, b) in zip(selected, selected.dropFirst()) {
            var ea = endpoints[a.id]!, eb = endpoints[b.id]!
            if ea == canonical(from) { ea = from }
            if eb == canonical(to) { eb = to }
            if let portal = connections[MapConnection(a.id, b.id)] {
                let forward = canonical(portal.from) == canonical(ea)
                // IndoorMap is undirected. Reject a selected reverse one-way edge
                // rather than adding a new directed planner or inventing permission.
                guard forward || portal.direction == .bidirectional else { throw MapError.unreachable }
                legs.append(.portal(id: portal.transitionID, from: forward ? portal.from : portal.to, to: forward ? portal.to : portal.from))
            } else {
                if case .local(let first, let previous)? = legs.last, previous.binding == ea.binding,
                   previous.floorID == ea.floorID, previous.nodeID == ea.nodeID {
                    legs[legs.count - 1] = .local(from: first, to: eb)
                } else { legs.append(.local(from: ea, to: eb)) }
            }
        }
        return legs
    }
}
