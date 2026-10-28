import XCTest
@testable import BlindCore

final class SavedRoomDiagnosticGeometryTests: XCTestCase {
    private var frame: SavedWorldFrame {
        .init(placeID: UUID().uuidString, revision: UUID().uuidString,
            worldMapSHA256: String(repeating: "a", count: 64), roomCaptureSHA256: String(repeating: "b", count: 64),
            originAnchorID: UUID().uuidString, capturedAt: Date(timeIntervalSince1970: 1))
    }
    private func make(_ features: [SavedRoomDiagnosticGeometry.Feature],
                      counts: SavedRoomDiagnosticGeometry.Counts? = nil) throws -> SavedRoomDiagnosticGeometry {
        try .init(frame: frame, capturedRoomID: UUID(), story: 0,
            sourceCounts: counts ?? .init(floors: features.filter { $0.kind == .floor }.count,
                walls: features.filter { $0.kind == .wall }.count, doors: features.filter { $0.kind == .door }.count,
                windows: features.filter { $0.kind == .window }.count, openings: features.filter { $0.kind == .opening }.count,
                furniture: features.filter { $0.kind == .furniture }.count), features: features)
    }
    private func feature(kind: SavedRoomDiagnosticGeometry.Kind = .furniture, dimensions: Point3 = Point3(2, 4, 6),
                         transform: NativeCameraTransform = .identity, polygon: [Point3] = []) -> SavedRoomDiagnosticGeometry.Feature {
        .init(id: UUID(), kind: kind, category: kind.rawValue, transform: transform, dimensions: dimensions, polygonCorners: polygon)
    }
    func testOriginalDimensionalBoxRetainsAllAxesAndFullTransform() throws {
        // Tilt about X, translate. Collapsing to yaw/centre-plane would lose Y->Z.
        let transform = NativeCameraTransform(columns: [1,0,0,0, 0,0,1,0, 0,-1,0,0, 10,20,30,1])
        let original = feature(transform: transform)
        let geometry = try make([original])
        XCTAssertEqual(geometry.features[0], original)
        XCTAssertEqual(geometry.polylines.count, 12)
        XCTAssertTrue(geometry.polylines.allSatisfy { !$0.closed && $0.points.count == 2 })
        let points = geometry.polylines.flatMap(\.points)
        XCTAssertEqual(points.map(\.x).min(), 9); XCTAssertEqual(points.map(\.x).max(), 11)
        XCTAssertEqual(points.map(\.y).min(), 17); XCTAssertEqual(points.map(\.y).max(), 23)
        XCTAssertEqual(points.map(\.z).min(), 28); XCTAssertEqual(points.map(\.z).max(), 32)
        XCTAssertFalse(geometry.permitsPhysicalGuidance)
    }
    func testZeroWallThicknessIsNeverInflated() throws {
        let geometry = try make([feature(kind: .wall, dimensions: Point3(4, 3, 0))])
        XCTAssertEqual(geometry.features[0].dimensions.z, 0)
        XCTAssertTrue(geometry.polylines.flatMap(\.points).allSatisfy { $0.z == 0 })
    }
    func testProvidedPolygonIsPreservedInsteadOfReplacedByBounds() throws {
        let polygon = [Point3(0,0,0), Point3(4,0,0), Point3(3,0,2), Point3(0,0,1)]
        let matrix = NativeCameraTransform(columns: [0,0,-1,0, 0,1,0,0, 1,0,0,0, 5,6,7,1])
        let geometry = try make([feature(kind: .floor, dimensions: Point3(99,99,99), transform: matrix, polygon: polygon)])
        XCTAssertEqual(geometry.polylines.count, 1)
        XCTAssertTrue(geometry.polylines[0].closed)
        XCTAssertEqual(geometry.polylines[0].points, try polygon.map { try matrix.applying(to: $0) })
        XCTAssertEqual(geometry.features[0].polygonCorners, polygon)
    }
    func testCompleteRoomCanExceedMatcherCapWithoutDroppingFeatures() throws {
        let features = (0..<33).map { _ in feature() } + [feature(kind: .wall), feature(kind: .door)]
        let geometry = try make(features)
        XCTAssertEqual(geometry.features, features)
        XCTAssertEqual(geometry.sourceCounts.total, 35)
        XCTAssertEqual(geometry.polylines.count, 35 * 12)
        XCTAssertEqual(RoomRegistrationAcquisition.maximumFeatures, 32)
    }
    func testWholeDocumentBoundsRejectRatherThanTruncate() {
        let tooMany = (0...SavedRoomDiagnosticGeometry.maximumFeatures).map { _ in feature() }
        XCTAssertThrowsError(try make(tooMany)) { XCTAssertEqual($0 as? SavedRoomDiagnosticGeometry.Failure, .unsupportedSize) }
        let polygon = Array(repeating: Point3(0,0,0), count: SavedRoomDiagnosticGeometry.maximumCornersPerFeature + 1)
        XCTAssertThrowsError(try make([feature(kind: .floor, polygon: polygon)]))
        let each = Array(repeating: Point3(0,0,0), count: SavedRoomDiagnosticGeometry.maximumCornersPerFeature)
        XCTAssertThrowsError(try make((0..<17).map { _ in feature(kind: .floor, polygon: each) }))
        let absurd = SavedRoomDiagnosticGeometry.Counts(floors: Int.max, walls: 0, doors: 0, windows: 0, openings: 0, furniture: 0)
        XCTAssertFalse(absurd.withinBounds); XCTAssertNil(absurd.total)
    }
    func testSourceCountsDetectMissingKindsOrFeatures() {
        let a = feature(kind: .wall), b = feature(kind: .furniture)
        XCTAssertThrowsError(try make([a], counts: .init(floors: 0, walls: 1, doors: 0, windows: 0, openings: 0, furniture: 1)))
        XCTAssertThrowsError(try make([a,b], counts: .init(floors: 0, walls: 0, doors: 1, windows: 0, openings: 0, furniture: 1)))
        XCTAssertThrowsError(try make([a,a]))
    }
    func testInvalidRawMeasurementsRejectWholeGeometry() {
        for invalid in [feature(dimensions: Point3(-1,2,3)), feature(dimensions: Point3(.nan,2,3)),
                        feature(transform: NativeCameraTransform(columns: [])),
                        feature(polygon: [Point3(0,0,0), Point3(1,0,0)]),
                        feature(polygon: [Point3(0,0,0), Point3(1,0,0), Point3(.infinity,0,0)])] {
            XCTAssertThrowsError(try make([feature(), invalid]))
        }
    }
    func testGeometryRoundTripRemainsHistoricalAndRejectsTamperedSourceCount() throws {
        let value = try make([feature(kind: .wall), feature()])
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(SavedRoomDiagnosticGeometry.self, from: data)
        XCTAssertEqual(decoded, value); XCTAssertFalse(decoded.permitsPhysicalGuidance)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var counts = try XCTUnwrap(object["sourceCounts"] as? [String: Any]); counts["walls"] = 0
        object["sourceCounts"] = counts
        XCTAssertThrowsError(try JSONDecoder().decode(SavedRoomDiagnosticGeometry.self,
            from: JSONSerialization.data(withJSONObject: object)))
    }
}
