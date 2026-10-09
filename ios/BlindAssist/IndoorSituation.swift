import Foundation
import CoreGraphics
import CryptoKit
import BlindCore

/// Adapts existing manual alignment and contributor geometry. No place recognition,
/// route planning or clearance inference occurs here. Core Graphics owns containment.
struct IndoorSituation {
    let places: [[String: Any]]
    let connections: [[String: Any]]
    let location: [String: Any]
    let entities: [[String: Any]]
    let mapNotes: [[String: Any]]
    let revision: String
    /// The single unambiguous candidate room from manual alignment, if any. Not automatic localization.
    let roomID: String?
    let roomName: String?
    static var unknownLocation: [String: Any] {
        let unknown = NSNull()
        return ["state": "unknown", "placeID": unknown, "floorID": unknown, "frameID": unknown,
                "mapRevision": unknown, "ageMS": 0, "position": unknown, "cameraForward": unknown, "bodyForward": unknown]
    }
    private static func point(_ p: Point3) -> [String: Double] { ["x": p.x, "y": p.y, "z": p.z] }
    private static func identifier(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    init(map: IndoorMap, package: PlacePackage?, revision: String, alignment: String, level: String?,
         position: Point3?, cameraForward: Point3?, bodyForward: Point3?, age: Double) {
        self.revision = revision
        let package = package.flatMap { value -> PlacePackage? in
            guard IndoorNavigator.matches(map: map, package: value) else { return nil }
            return value
        }
        let source = package?.revision ?? revision
        let root = Self.identifier("venue:\(package?.id ?? revision)")
        let bounded: (String) -> String = { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unnamed map area" : String($0.unicodeScalars.prefix(300)) }
        var places: [[String: Any]] = [["id": root, "name": bounded(package?.name ?? map.name),
            "kind": "building", "parentID": NSNull(), "sourceID": source]]
        let levelNames = package?.floors.map { ($0.id, $0.name) } ?? Set(map.nodes.map(\.level)).sorted().map { ($0, $0) }
        let selectedLevels = levelNames.sorted { ($0.0 == level ? 0 : 1, $0.0) < ($1.0 == level ? 0 : 1, $1.0) }.prefix(32)
        let floorIDs = Dictionary(uniqueKeysWithValues: selectedLevels.map { ($0.0, Self.identifier("\(root):floor:\($0.0)")) })
        for (id, name) in selectedLevels {
            places.append(["id": floorIDs[id]!, "name": bounded(name), "kind": "floor", "parentID": root, "sourceID": source])
        }
        // Manual coordinates identify at most a candidate room in the supplied map.
        // Require the point and a half-metre neighborhood to be inside one boundary.
        let candidates = (package?.rooms ?? []).filter { room in
            guard room.floorID == level, let position, position.isFinite, let boundary = room.boundary,
                  let first = boundary.first else { return false }
            let path = CGMutablePath(); path.move(to: CGPoint(x: first.x, y: first.z))
            boundary.dropFirst().forEach { path.addLine(to: CGPoint(x: $0.x, y: $0.z)) }; path.closeSubpath()
            return [(0.0, 0.0), (0.5, 0.0), (-0.5, 0.0), (0.0, 0.5), (0.0, -0.5)].allSatisfy {
                path.contains(CGPoint(x: position.x + $0.0, y: position.z + $0.1), using: .evenOdd)
            }
        }
        let candidate = candidates.count == 1 ? candidates[0].id : nil
        roomID = candidate.map { "\(package?.id ?? revision):\($0)" }
        roomName = candidates.count == 1 ? bounded(candidates[0].name) : nil
        let rooms = (package?.rooms ?? []).filter { floorIDs[$0.floorID] != nil }.sorted {
            ($0.id == candidate ? 0 : 1, $0.id) < ($1.id == candidate ? 0 : 1, $1.id)
        }.prefix(64 - places.count)
        let roomIDs = Dictionary(uniqueKeysWithValues: rooms.map { ($0.id, Self.identifier("\(root):room:\($0.id)")) })
        for room in rooms {
            places.append(["id": roomIDs[room.id]!, "name": bounded(room.name), "kind": room.kind,
                           "parentID": floorIDs[room.floorID]!, "sourceID": source])
        }
        self.places = places
        let mapDate = package.flatMap { ISO8601DateFormatter().date(from: $0.surveyedAt ?? $0.createdAt) }
        let mapAge = max(0, mapDate.map { Date().timeIntervalSince($0) * 1000 } ?? 0)
        entities = Array(rooms.flatMap { room -> [[String: Any]] in
            (room.layout?.features ?? []).filter { $0.kind != "wall" }.prefix(32).map { feature in
                ["id": Self.identifier("\(root):\(room.id):\(feature.id)"), "category": feature.kind == "furniture" ? "furniture" : "landmark",
                 "description": bounded(feature.label ?? feature.category), "placeID": roomIDs[room.id]!,
                 "state": "mapped", "ageMS": mapAge, "sourceID": source]
            }
        }.prefix(32))
        mapNotes = Array(rooms.filter { !$0.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.prefix(2).map {
            ["placeID": roomIDs[$0.id]!, "text": $0.description, "sourceID": source, "state": "mapped"]
        })
        connections = Array((package?.connections ?? []).compactMap { edge -> [String: Any]? in
            guard let from = roomIDs[edge.fromRoomID], let to = roomIDs[edge.toRoomID] else { return nil }
            return ["from": from, "to": to, "state": edge.state, "sourceID": source]
        }.prefix(128))
        guard let level, let floor = floorIDs[level], let position, position.isFinite,
              let cameraForward, cameraForward.isFinite, age.isFinite, (0...0.5).contains(age) else {
            location = Self.unknownLocation; return
        }
        location = ["state": "manuallyAligned", "placeID": candidate.flatMap { roomIDs[$0] } ?? floor,
            "floorID": floor, "frameID": alignment, "mapRevision": revision, "ageMS": age * 1000,
            "position": Self.point(position), "cameraForward": Self.point(cameraForward),
            "bodyForward": bodyForward.map { Self.point($0) as Any } ?? NSNull()]
    }
}
