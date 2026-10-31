import Foundation

/// Original RoomPlan measurement bounds in one saved AR world. Historical camera
/// diagnostics only: not a body model, obstacle mesh, floor assignment or clearance.
public struct SavedRoomDiagnosticGeometry: Codable, Equatable, Sendable {
    public static let maximumFeatures = 512
    public static let maximumCornersPerFeature = 1_024
    public static let maximumTotalCorners = 16_384
    public enum Failure: Error, Equatable { case unsupportedSize, invalidGeometry }
    public enum Kind: String, Codable, CaseIterable, Sendable { case floor, wall, door, window, opening, furniture }
    public struct Counts: Codable, Equatable, Sendable {
        public let floors, walls, doors, windows, openings, furniture: Int
        public init(floors: Int, walls: Int, doors: Int, windows: Int, openings: Int, furniture: Int) {
            self.floors = floors; self.walls = walls; self.doors = doors
            self.windows = windows; self.openings = openings; self.furniture = furniture
        }
        public func count(for kind: Kind) -> Int {
            switch kind {
            case .floor: return floors
            case .wall: return walls
            case .door: return doors
            case .window: return windows
            case .opening: return openings
            case .furniture: return furniture
            }
        }
        public var withinBounds: Bool {
            let counts = Kind.allCases.map(count(for:))
            return counts.allSatisfy { (0...SavedRoomDiagnosticGeometry.maximumFeatures).contains($0) } &&
                counts.reduce(0, +) <= SavedRoomDiagnosticGeometry.maximumFeatures
        }
        public var total: Int? { withinBounds ? Kind.allCases.reduce(0) { $0 + count(for: $1) } : nil }
    }
    public struct Feature: Codable, Equatable, Sendable {
        public let id: UUID
        public let kind: Kind
        public let category: String
        /// Original feature-to-saved-world transform and measured dimensions.
        public let transform: NativeCameraTransform
        public let dimensions: Point3
        /// Original local-plane polygon, when provided; never synthesized corners.
        public let polygonCorners: [Point3]
        public init(id: UUID, kind: Kind, category: String, transform: NativeCameraTransform,
                    dimensions: Point3, polygonCorners: [Point3] = []) {
            self.id = id; self.kind = kind; self.category = category; self.transform = transform
            self.dimensions = dimensions; self.polygonCorners = polygonCorners
        }
        public var valid: Bool {
            !category.isEmpty && category.utf8.count <= 128 && transform.valid &&
                [12, 13, 14].allSatisfy { abs(transform.columns[$0]) <= 10_000 } &&
                dimensions.isFinite && [dimensions.x, dimensions.y, dimensions.z].allSatisfy { (0...100).contains($0) } &&
                (polygonCorners.isEmpty || polygonCorners.count >= 3) &&
                polygonCorners.count <= SavedRoomDiagnosticGeometry.maximumCornersPerFeature &&
                polygonCorners.allSatisfy { $0.isFinite && abs($0.x) <= 100 && abs($0.y) <= 100 && abs($0.z) <= 100 }
        }
        fileprivate var polylines: [Polyline] {
            guard valid else { return [] }
            if !polygonCorners.isEmpty {
                let points = polygonCorners.compactMap { try? transform.applying(to: $0) }
                guard points.count == polygonCorners.count else { return [] }
                return [.init(featureID: id, kind: kind, category: category, points: points, closed: true)]
            }
            // Original dimensional bounding box, NOT a reconstruction of furniture
            // legs or a guessed wall thickness. Zero dimensions remain zero.
            let x = dimensions.x / 2, y = dimensions.y / 2, z = dimensions.z / 2
            let local = [Point3(-x,-y,-z), Point3(x,-y,-z), Point3(x,y,-z), Point3(-x,y,-z),
                         Point3(-x,-y,z), Point3(x,-y,z), Point3(x,y,z), Point3(-x,y,z)]
            let world = local.compactMap { try? transform.applying(to: $0) }
            guard world.count == 8 else { return [] }
            let edges = [(0,1),(1,2),(2,3),(3,0),(4,5),(5,6),(6,7),(7,4),(0,4),(1,5),(2,6),(3,7)]
            return edges.map { .init(featureID: id, kind: kind, category: category,
                points: [world[$0.0], world[$0.1]], closed: false) }
        }
    }
    public struct Polyline: Equatable, Sendable {
        public let featureID: UUID
        public let kind: Kind
        public let category: String
        public let points: [Point3]
        public let closed: Bool
    }
    public let schemaVersion: Int
    public let frame: SavedWorldFrame
    public let capturedRoomID: UUID
    /// Framework story metadata only, never a verified building-floor identifier.
    public let story: Int
    public let sourceCounts: Counts
    public let features: [Feature]
    public var permitsPhysicalGuidance: Bool { false }
    public var polylines: [Polyline] { features.flatMap(\.polylines) }
    public init(frame: SavedWorldFrame, capturedRoomID: UUID, story: Int, sourceCounts: Counts,
                features: [Feature]) throws {
        schemaVersion = 1; self.frame = frame; self.capturedRoomID = capturedRoomID; self.story = story
        self.sourceCounts = sourceCounts; self.features = features
        try validate()
    }
    public func validate() throws {
        guard sourceCounts.withinBounds, features.count <= Self.maximumFeatures,
              features.allSatisfy({ $0.polygonCorners.count <= Self.maximumCornersPerFeature }),
              features.reduce(0, { $0 + $1.polygonCorners.count }) <= Self.maximumTotalCorners else { throw Failure.unsupportedSize }
        guard schemaVersion == 1, frame.valid, (-4096...4096).contains(story),
              sourceCounts.total == features.count, !features.isEmpty,
              features.allSatisfy(\.valid), Set(features.map(\.id)).count == features.count,
              Kind.allCases.allSatisfy({ kind in features.filter { $0.kind == kind }.count == sourceCounts.count(for: kind) })
        else { throw Failure.invalidGeometry }
    }
    private enum CodingKeys: String, CodingKey { case schemaVersion, frame, capturedRoomID, story, sourceCounts, features }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decode(Int.self, forKey: .schemaVersion)
        frame = try values.decode(SavedWorldFrame.self, forKey: .frame)
        capturedRoomID = try values.decode(UUID.self, forKey: .capturedRoomID)
        story = try values.decode(Int.self, forKey: .story)
        sourceCounts = try values.decode(Counts.self, forKey: .sourceCounts)
        features = try values.decode([Feature].self, forKey: .features)
        try validate()
    }
}
