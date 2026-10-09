import Foundation

/// Versioned metadata around existing room/route types. No localisation or geometry inference.
public struct PlacePackage: Codable, Sendable, Identifiable {
    public struct Floor: Codable, Sendable, Identifiable {
        public var id: String
        public var name: String
        public var frameID: String
    }
    public struct Room: Codable, Sendable, Identifiable {
        public var id: String
        public var name: String
        public var nameArabic: String?
        public var floorID: String
        public var kind: String
        public var description: String
        public var layout: RoomLayout?
        public var boundary: [Point3]?
    }
    public struct Connection: Codable, Sendable, Identifiable {
        public var id: String
        public var fromRoomID: String
        public var toRoomID: String
        public var kind: String
        public var state: String
        public var source: String
        public var widthMeters: Double?
        public var heightMeters: Double?
    }
    public struct Review: Codable, Sendable, Identifiable {
        public var id: String
        public var revision: String
        public var reviewer: String
        public var scope: String
        public var date: String
        public var method: String
        public var limitations: String
        public var evidenceURL: String?
        public init(id: String, revision: String, reviewer: String, scope: String, date: String,
                    method: String, limitations: String, evidenceURL: String? = nil) {
            self.id = id; self.revision = revision; self.reviewer = reviewer; self.scope = scope
            self.date = date; self.method = method; self.limitations = limitations; self.evidenceURL = evidenceURL
        }
    }
    public var schemaVersion: Int
    public var id: String
    public var revision: String
    public var name: String
    public var nameArabic: String?
    public var description: String
    public var author: String
    public var license: String
    public var licenseText: String?
    public var attribution: String?
    public var sourceURL: String?
    public var surveyedAt: String?
    public var createdAt: String
    public var visibility: String
    public var provenance: String
    public var coordinateSystem: String
    public var localization: String
    public var coverageGaps: [String]
    public var floors: [Floor]
    public var rooms: [Room]
    public var connections: [Connection]
    public var reviews: [Review]
    public var routeMap: IndoorMap?

    public static let maximumBytes = 2_000_000
    public func localizedName(arabic: Bool) -> String { arabic ? (nameArabic ?? name) : name }
    public static func validID(_ value: String) -> Bool {
        !value.isEmpty && value.count <= 64 && value.unicodeScalars.allSatisfy {
            CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_").contains($0)
        }
    }
    private static func text(_ value: String, maximum: Int = 300, empty: Bool = false) -> Bool {
        (empty || !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) && value.count <= maximum
    }
    private static func https(_ value: String?) -> Bool {
        guard let value else { return true }
        guard value.count <= 2000, let url = URL(string: value) else { return false }
        return url.scheme == "https" && url.host != nil && url.user == nil && url.password == nil
    }
    public func validate() throws {
        let date = ISO8601DateFormatter()
        guard schemaVersion == 1, Self.validID(id), Self.validID(revision), Self.text(name),
              Self.text(nameArabic ?? "", empty: true), Self.text(description, maximum: 4000, empty: true),
              Self.text(author), Self.text(license), Self.text(licenseText ?? "", maximum: 30000, empty: true),
              Self.text(attribution ?? "", maximum: 4000, empty: true), Self.https(sourceURL), date.date(from: createdAt) != nil,
              surveyedAt == nil || date.date(from: surveyedAt!) != nil,
              ["public", "private"].contains(visibility), ["authored", "measured", "mixed"].contains(provenance),
              coordinateSystem == "local-meters-y-up", ["preview-only", "manual-landmarks"].contains(localization),
              coverageGaps.count <= 32, coverageGaps.allSatisfy({ Self.text($0, maximum: 1000) }),
              !floors.isEmpty, floors.count <= 32, rooms.count <= 256, connections.count <= 512, reviews.count <= 100,
              Set(floors.map(\.id)).count == floors.count, Set(rooms.map(\.id)).count == rooms.count,
              Set(connections.map(\.id)).count == connections.count, Set(reviews.map(\.id)).count == reviews.count,
              floors.allSatisfy({ Self.validID($0.id) && Self.text($0.name) && Self.validID($0.frameID) }) else { throw MapError.invalid }
        let floorIDs = Set(floors.map(\.id)), roomIDs = Set(rooms.map(\.id))
        guard !floorIDs.contains(id), !roomIDs.contains(id), floorIDs.isDisjoint(with: roomIDs) else { throw MapError.invalid }
        for room in rooms {
            guard Self.validID(room.id), Self.text(room.name), Self.text(room.nameArabic ?? "", empty: true),
                  floorIDs.contains(room.floorID), ["room", "store", "restaurant", "corridor", "exit"].contains(room.kind),
                  Self.text(room.description, maximum: 4000, empty: true) else { throw MapError.invalid }
            try room.layout?.validate()
            if let boundary = room.boundary {
                guard (3...512).contains(boundary.count), boundary.allSatisfy({ $0.isFinite && abs($0.x) < 10000 && abs($0.y) < 10000 && abs($0.z) < 10000 }) else { throw MapError.invalid }
            }
        }
        guard connections.allSatisfy({ Self.validID($0.id) && roomIDs.contains($0.fromRoomID) && roomIDs.contains($0.toRoomID) &&
            $0.fromRoomID != $0.toRoomID && ["door", "opening", "lift", "stairs"].contains($0.kind) &&
            ["mapped", "blocked", "unknown"].contains($0.state) && Self.text($0.source, maximum: 1000) }) else { throw MapError.invalid }
        let byRoom = Dictionary(uniqueKeysWithValues: rooms.map { ($0.id, $0) })
        guard connections.allSatisfy({ connection in
            [connection.widthMeters, connection.heightMeters].allSatisfy { $0 == nil || ($0!.isFinite && $0! > 0 && $0! < 100) }
        }) else { throw MapError.invalid }
        guard connections.allSatisfy({ ["lift", "stairs"].contains($0.kind) || byRoom[$0.fromRoomID]?.floorID == byRoom[$0.toRoomID]?.floorID }) else { throw MapError.invalid }
        for review in reviews {
            guard Self.validID(review.id), review.revision == revision, Self.text(review.reviewer),
                  ["labels", "geometry", "accessibility", "localization", "walkthrough"].contains(review.scope),
                  date.date(from: review.date) != nil, Self.text(review.method, maximum: 1000),
                  Self.text(review.limitations, maximum: 2000, empty: true), Self.https(review.evidenceURL) else { throw MapError.invalid }
        }
        if let map = routeMap {
            try map.validate()
            guard map.packageModified != true else { throw MapError.invalid }
            guard map.packageID == nil || (map.packageID == id && map.packageRevision == revision) else { throw MapError.invalid }
            guard Self.text(map.name), map.nodes.allSatisfy({ Self.validID($0.id) && Self.text($0.name) &&
                Self.text($0.nameArabic ?? "", empty: true) && floorIDs.contains($0.level) &&
                abs($0.position.x) < 10000 && abs($0.position.y) < 10000 && abs($0.position.z) < 10000 }) else { throw MapError.invalid }
            let byNode = Dictionary(uniqueKeysWithValues: map.nodes.map { ($0.id, $0) })
            // The current route adapter cannot validate a lift/stair transition from point edges.
            guard map.edges.allSatisfy({ byNode[$0.from]?.level == byNode[$0.to]?.level }) else { throw MapError.invalid }
            // Existing manual alignment assumes a single coordinate frame. Do not merge unrelated scans.
            let usedFrames = Set(floors.filter { Set(map.nodes.map(\.level)).contains($0.id) }.map(\.frameID))
            guard usedFrames.count == 1 else { throw MapError.invalid }
        }
        guard localization != "manual-landmarks" || routeMap != nil else { throw MapError.invalid }
    }
    public static func decode(_ data: Data) throws -> PlacePackage {
        guard !data.isEmpty, data.count <= maximumBytes,
              let raw = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw MapError.invalid }
        // Refuse accidentally exported personal-memory containers and unsupported attachments.
        let allowed: Set<String> = ["schemaVersion", "id", "revision", "name", "nameArabic", "description", "author", "license", "licenseText", "attribution", "sourceURL", "surveyedAt", "createdAt", "visibility", "provenance", "coordinateSystem", "localization", "coverageGaps", "floors", "rooms", "connections", "reviews", "routeMap"]
        guard Set(raw.keys).isSubset(of: allowed) else { throw MapError.invalid }
        let package = try JSONDecoder().decode(PlacePackage.self, from: data)
        try package.validate(); return package
    }
    public func encoded() throws -> Data {
        try validate()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let data = try encoder.encode(self)
        guard data.count <= Self.maximumBytes else { throw MapError.invalid }; return data
    }
    /// A user-reviewed export draft from the existing authored map, not personal memory.
    public static func draft(map: IndoorMap, author: String, license: String) throws -> PlacePackage {
        // Export imported community packages with their original provenance instead.
        guard map.packageID == nil, map.packageRevision == nil else { throw MapError.invalid }
        let frame = UUID().uuidString
        let package = PlacePackage(schemaVersion: 1, id: UUID().uuidString, revision: UUID().uuidString,
            name: map.name, description: "", author: author, license: license,
            createdAt: ISO8601DateFormatter().string(from: Date()), visibility: "private", provenance: "authored",
            coordinateSystem: "local-meters-y-up", localization: "manual-landmarks",
            coverageGaps: ["Starting landmark and facing direction require confirmation. This package does not establish current clearance or cross-device localization."],
            floors: Set(map.nodes.map(\.level)).sorted().map { Floor(id: $0, name: $0, frameID: frame) },
            rooms: [], connections: [], reviews: [], routeMap: map)
        try package.validate(); return package
    }
}
