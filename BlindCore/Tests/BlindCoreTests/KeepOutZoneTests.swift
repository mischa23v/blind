import XCTest
@testable import BlindCore

final class KeepOutZoneTests: XCTestCase {
    private var zone: KeepOutZone {
        KeepOutZone(id: "stairs", name: "Stairs", level: "0", minX: 1, maxX: 2, minZ: -0.5, maxZ: 0.5, nameArabic: "الدرج")
    }
    private var map: IndoorMap {
        IndoorMap(name: "Fictional school", nodes: [
            MapNode(id: "a", name: "A", level: "0", position: Point3(0, 0, 0)),
            MapNode(id: "b", name: "B", level: "0", position: Point3(3, 0, 0)),
            MapNode(id: "c", name: "C", level: "0", position: Point3(0, 0, 2)),
            MapNode(id: "d", name: "D", level: "0", position: Point3(3, 0, 2))
        ], edges: [MapEdge(from: "a", to: "b", distance: 3), MapEdge(from: "a", to: "c", distance: 2),
                   MapEdge(from: "c", to: "d", distance: 3), MapEdge(from: "d", to: "b", distance: 2)], keepOutZones: [zone])
    }
    func testPlannerDetoursAndBlocksBothDirections() throws {
        XCTAssertEqual(try map.route(from: "a", to: "b").map(\.id), ["a", "c", "d", "b"])
        XCTAssertEqual(try map.route(from: "b", to: "a").map(\.id), ["b", "d", "c", "a"])
        var closed = map; closed.edges = [closed.edges[0]]
        XCTAssertThrowsError(try closed.route(from: "a", to: "b"))
    }
    func testMarginAndTouchingRejectWholeSegment() {
        XCTAssertFalse(zone.intersects(from: Point3(0, 0, 0.8), to: Point3(3, 0, 0.8), padding: 0))
        XCTAssertTrue(zone.intersects(from: Point3(0, 0, 0.8), to: Point3(3, 0, 0.8), padding: 0.45))
        XCTAssertTrue(zone.intersects(from: Point3(0, 0, 0.5), to: Point3(3, 0, 0.5), padding: 0))
        XCTAssertTrue(zone.intersects(from: Point3(1, 0, -2), to: Point3(1, 0, 2), padding: 0))
        XCTAssertFalse(zone.intersects(from: Point3(0, 0, -2), to: Point3(0, 0, 2), padding: 0.45))
    }
    func testDestinationAndStationaryStartInsideAreRejected() {
        var covered = map
        covered.keepOutZones = [KeepOutZone(id: "closed", name: "Closed", level: "0", minX: -0.1, maxX: 0.1, minZ: -0.1, maxZ: 0.1)]
        XCTAssertThrowsError(try covered.route(from: "a", to: "a"))
        XCTAssertThrowsError(try covered.route(from: "b", to: "a"))
        XCTAssertThrowsError(try covered.route(from: "a", to: "b"))
    }
    func testOtherFloorDoesNotBlockButMisspelledFloorIsInvalid() throws {
        var upstairs = map
        upstairs.nodes.append(MapNode(id: "upper", name: "Upper", level: "1", position: Point3(0, 3, 0)))
        upstairs.keepOutZones![0].level = "1"
        XCTAssertEqual(try upstairs.route(from: "a", to: "b").map(\.id), ["a", "b"])
        upstairs.keepOutZones![0].level = "typo"
        XCTAssertThrowsError(try upstairs.validate())
    }
    func testInvalidAndDuplicateZonesRejectMap() {
        var invalid = map; invalid.keepOutZones![0].maxX = .nan
        XCTAssertThrowsError(try invalid.validate())
        invalid = map; invalid.keepOutZones![0].maxX = 0
        XCTAssertThrowsError(try invalid.validate())
        invalid = map; invalid.keepOutZones!.append(zone)
        XCTAssertThrowsError(try invalid.validate())
        XCTAssertTrue(zone.intersects(from: Point3(.nan, 0, 0), to: Point3(0, 0, 0), padding: 0))
    }
    func testZonesRoundTripAndLegacyMapStillLoads() throws {
        let decoded = try JSONDecoder().decode(IndoorMap.self, from: JSONEncoder().encode(map))
        XCTAssertEqual(decoded.keepOutZones, [zone])
        XCTAssertEqual(try decoded.route(from: "a", to: "b").map(\.id), ["a", "c", "d", "b"])
        var legacy = map; legacy.keepOutZones = nil
        let data = try JSONEncoder().encode(legacy)
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("keepOutZones"))
        XCTAssertEqual(try JSONDecoder().decode(IndoorMap.self, from: data).route(from: "a", to: "b").map(\.id), ["a", "b"])
    }
}
