import Foundation

public struct MapConnection: Hashable, Sendable {
    public let a: String, b: String
    public init(_ from: String, _ to: String) { a = min(from, to); b = max(from, to) }
}

public struct MapNode: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var nameArabic: String?
    public var level: String
    public var position: Point3
    public init(id: String, name: String, level: String, position: Point3, nameArabic: String? = nil) {
        self.id = id; self.name = name; self.level = level; self.position = position; self.nameArabic = nameArabic
    }
    public func localizedName(arabic: Bool) -> String { arabic ? (nameArabic ?? name) : name }
}
public struct MapEdge: Codable, Equatable, Sendable {
    public var from: String
    public var to: String
    public var distance: Double
    public var accessible: Bool
    public init(from: String, to: String, distance: Double, accessible: Bool = true) {
        self.from = from; self.to = to; self.distance = distance; self.accessible = accessible
    }
}
public struct IndoorMap: Codable, Sendable {
    public var name: String
    public var nodes: [MapNode]
    public var edges: [MapEdge]
    public var surfaces: [NavigationSurface]?
    public var keepOutZones: [KeepOutZone]?
    public var packageID: String?
    public var packageRevision: String?
    public var packageModified: Bool?
    public init(name: String, nodes: [MapNode], edges: [MapEdge], surfaces: [NavigationSurface]? = nil, keepOutZones: [KeepOutZone]? = nil) {
        self.name = name; self.nodes = nodes; self.edges = edges; self.surfaces = surfaces
        self.keepOutZones = keepOutZones
    }
    public func validate() throws {
        guard packageModified != true || packageID != nil else { throw MapError.invalid }
        guard (packageID == nil && packageRevision == nil) ||
            (packageID.map(PlacePackage.validID) == true && packageRevision.map(PlacePackage.validID) == true) else { throw MapError.invalid }
        guard !nodes.isEmpty, nodes.count <= 2000, edges.count <= 10000, Set(nodes.map(\.id)).count == nodes.count,
              nodes.allSatisfy({ !$0.id.isEmpty && $0.position.isFinite }) else { throw MapError.invalid }
        let ids = Set(nodes.map(\.id))
        guard edges.allSatisfy({ ids.contains($0.from) && ids.contains($0.to) && $0.distance.isFinite && $0.distance > 0 })
        else { throw MapError.invalid }
        if let zones = keepOutZones {
            let levels = Set(nodes.map(\.level))
            guard zones.count <= 500, Set(zones.map(\.id)).count == zones.count,
                  zones.allSatisfy({ $0.valid && levels.contains($0.level) }) else { throw MapError.invalid }
        }
        if let surfaces {
            guard !surfaces.isEmpty, surfaces.count <= 30, Set(surfaces.map(\.level)).count == surfaces.count else { throw MapError.invalid }
            for surface in surfaces { try surface.validate() }
        }
    }
    public mutating func markLocalEdit() { if packageID != nil { packageModified = true } }
    public func route(from start: String, to destination: String, accessibleOnly: Bool = true, blocked: Set<MapConnection> = [], body: BodyEnvelope = BodyEnvelope()) throws -> [MapNode] {
        try validate()
        guard body.valid else { throw MapError.invalid }
        let byID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        guard byID[start] != nil, byID[destination] != nil else { throw MapError.unknownNode }
        for node in [byID[start]!, byID[destination]!] {
            guard restriction(from: node.position, to: node.position, level: node.level, body: body) == nil else { throw MapError.unreachable }
        }
        let usableEdges = edges.filter { edge in
            guard (!accessibleOnly || edge.accessible), !blocked.contains(MapConnection(edge.from, edge.to)) else { return false }
            let a = byID[edge.from]!, b = byID[edge.to]!
            // For cross-floor graph edges, conservatively check both endpoint floors.
            guard restriction(from: a.position, to: b.position, level: a.level, body: body) == nil,
                  restriction(from: a.position, to: b.position, level: b.level, body: body) == nil else { return false }
            guard let surfaces else { return true } // Legacy authored graph: no geometric-clearance claim.
            // A grid cannot establish a lift/stair transition. It needs a separately verified transition model.
            guard a.level == b.level, let surface = surfaces.first(where: { $0.level == a.level }) else { return false }
            return surface.permitsValidatedLeg(from: a.position, to: b.position, body: body)
        }
        var distances = [start: 0.0], previous: [String: String] = [:], remaining = Set(byID.keys)
        while let current = remaining.min(by: { distances[$0, default: .infinity] < distances[$1, default: .infinity] }) {
            guard let cost = distances[current], cost.isFinite else { break }
            if current == destination { break }
            remaining.remove(current)
            for edge in usableEdges where edge.from == current || edge.to == current {
                let next = edge.from == current ? edge.to : edge.from
                guard remaining.contains(next) else { continue }
                let candidate = cost + edge.distance
                if candidate < distances[next, default: .infinity] {
                    distances[next] = candidate; previous[next] = current
                }
            }
        }
        guard distances[destination] != nil else { throw MapError.unreachable }
        var ids = [destination]
        while ids.last != start {
            guard let parent = previous[ids.last!] else { throw MapError.unreachable }
            ids.append(parent)
        }
        return ids.reversed().compactMap { byID[$0] }
    }
    public func restriction(from a: Point3, to b: Point3, level: String, body: BodyEnvelope = BodyEnvelope()) -> KeepOutZone? {
        (keepOutZones ?? []).first { $0.level == level && $0.intersects(from: a, to: b, padding: body.radius + body.margin) }
    }
}
public enum MapError: Error { case invalid, unknownNode, unreachable }

/// Indoor mapping requires an authored walkable graph. IMDF polygons by
/// themselves do NOT establish safe paths or device localization.
public enum IMDFImporter {
    public static func landmarks(from data: Data, originLatitude: Double, originLongitude: Double) throws -> [MapNode] {
        let raw = try JSONSerialization.jsonObject(with: data)
        guard let document = raw as? [String: Any], document["type"] as? String == "FeatureCollection",
              let features = document["features"] as? [[String: Any]],
              originLatitude.isFinite, originLongitude.isFinite,
              abs(originLatitude) <= 90, abs(originLongitude) <= 180 else { throw MapError.invalid }
        return features.compactMap { feature in
            guard let id = feature["id"] as? String,
                  let geometry = feature["geometry"] as? [String: Any], geometry["type"] as? String == "Point",
                  let coordinates = geometry["coordinates"] as? [Double], coordinates.count >= 2,
                  coordinates[0].isFinite, coordinates[1].isFinite,
                  abs(coordinates[0]) <= 180, abs(coordinates[1]) <= 90 else { return nil }
            let properties = feature["properties"] as? [String: Any] ?? [:]
            let names = properties["name"] as? [String: String]
            let east = (coordinates[0] - originLongitude) * .pi / 180 * 6_371_000 * cos(originLatitude * .pi / 180)
            let north = (coordinates[1] - originLatitude) * .pi / 180 * 6_371_000
            return MapNode(id: id, name: names?["en"] ?? id,
                           level: properties["level_id"] as? String ?? "unknown", position: Point3(east, 0, -north))
        }
    }
}
