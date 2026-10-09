import Foundation

/// A small semantic view of a map for a language model. Geometry stays in the planner.
/// The model can propose an existing destination ID, never a coordinate or walking command.
public struct MapContext: Encodable, Sendable {
    public struct Destination: Codable, Equatable, Sendable {
        public let id: String
        public let name: String
        public let nameArabic: String?
        public let level: String
    }
    public let version = 1
    public let venue: String
    public let positionStatus: String
    public let currentPosition: Point3?
    public let routeIDs: [String]
    public let destinations: [Destination]
    public let catalogTruncated: Bool
    public let geometryStatus: String
    public init(map: IndoorMap, position: Point3?, route: [MapNode]) {
        venue = String(map.name.prefix(120))
        currentPosition = position?.isFinite == true ? position : nil
        positionStatus = currentPosition == nil ? "unknown" : "manually_aligned_not_globally_verified"
        destinations = map.nodes.prefix(80).map { Destination(id: $0.id, name: String($0.name.prefix(120)), nameArabic: $0.nameArabic.map { String($0.prefix(120)) }, level: $0.level) }
        catalogTruncated = map.nodes.count > 80
        let known = Set(map.nodes.map(\.id)); routeIDs = route.map(\.id).filter { known.contains($0) }
        geometryStatus = map.surfaces == nil ? "authored_graph_without_collision_surface" : "stored_collision_surface_not_live_clearance"
    }
    public func json() throws -> String { String(decoding: try JSONEncoder().encode(self), as: UTF8.self) }
    public func acceptedID(_ proposed: String) -> String? { destinations.contains { $0.id == proposed } ? proposed : nil }
    /// Deterministic name matching remains available without an on-device LLM.
    public static func matchingDestinations(question: String, in map: IndoorMap) -> [MapNode] {
        func words(_ text: String) -> String {
            text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
                .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: " ")
        }
        let query = " " + words(String(question.prefix(1000))) + " "
        return map.nodes.filter { node in
            [node.name, node.nameArabic].compactMap { $0 }.contains { label in
                let name = words(label)
                return !name.isEmpty && query.contains(" " + name + " ")
            }
        }
    }
}
