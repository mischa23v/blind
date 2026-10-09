import XCTest
@testable import BlindCore

final class NavigationSurfaceTests: XCTestCase {
    func surface() -> NavigationSurface {
        NavigationSurface(level: "0", origin: Point3(0, 0, 0), resolution: 0.25, width: 32, depth: 24,
            cells: Array(repeating: SurfaceCell(floor: 0, clearance: 3), count: 32 * 24))
    }
    let start = Point3(1, 0, 2), end = Point3(7, 0, 2)
    func testSweptBodyFitsKnownFloor() { XCTAssertTrue(surface().permitsLeg(from: start, to: end)) }
    func testObstacleBesideCenterLineStillHitsBody() {
        var grid = surface(); grid.cells[9 * grid.width + 16].blocked = true
        XCTAssertFalse(grid.permitsLeg(from: start, to: end))
    }
    func testUnknownDropsRisesAndHeadObstaclesRejectLeg() {
        for cell in [SurfaceCell(), SurfaceCell(floor: -0.2, clearance: 3),
                     SurfaceCell(floor: 0.2, clearance: 3), SurfaceCell(floor: 0, clearance: 1.6)] {
            var grid = surface(); grid.cells[8 * grid.width + 16] = cell
            XCTAssertFalse(grid.permitsLeg(from: start, to: end))
        }
    }
    func testMapBoundaryAndInvalidBodyAreRejected() {
        XCTAssertFalse(surface().permitsLeg(from: Point3(0.1, 0, 2), to: end))
        XCTAssertFalse(surface().permitsLeg(from: start, to: end, body: BodyEnvelope(radius: .nan)))
        var grid = surface(); grid.width = Int.max
        XCTAssertThrowsError(try grid.validate())
        XCTAssertFalse(grid.permitsLeg(from: start, to: end))
    }
    func testGraphSelectsAuthoredAlternativeAroundShelf() throws {
        var grid = surface(); grid.cells[8 * grid.width + 16].blocked = true
        let nodes = [MapNode(id: "entrance", name: "Entrance", level: "0", position: start),
                     MapNode(id: "left", name: "Aisle start", level: "0", position: Point3(1, 0, 4)),
                     MapNode(id: "right", name: "Aisle end", level: "0", position: Point3(7, 0, 4)),
                     MapNode(id: "checkout", name: "Checkout", level: "0", position: end)]
        let map = IndoorMap(name: "Test shop", nodes: nodes, edges: [
            MapEdge(from: "entrance", to: "checkout", distance: 6), MapEdge(from: "entrance", to: "left", distance: 2),
            MapEdge(from: "left", to: "right", distance: 6), MapEdge(from: "right", to: "checkout", distance: 2)], surfaces: [grid])
        XCTAssertEqual(try map.route(from: "entrance", to: "checkout").map(\.id), ["entrance", "left", "right", "checkout"])
        XCTAssertThrowsError(try map.route(from: "entrance", to: "checkout", blocked: [MapConnection("left", "right")]))
        let decoded = try JSONDecoder().decode(IndoorMap.self, from: JSONEncoder().encode(map))
        XCTAssertEqual(try decoded.route(from: "entrance", to: "checkout").count, 4)
    }
    func testCollisionMapCannotAssumeMissingFloorOrLiftTransition() throws {
        let nodes = [MapNode(id: "a", name: "A", level: "1", position: start), MapNode(id: "b", name: "B", level: "1", position: end)]
        var map = IndoorMap(name: "Test", nodes: nodes, edges: [MapEdge(from: "a", to: "b", distance: 6)], surfaces: [surface()])
        XCTAssertThrowsError(try map.route(from: "a", to: "b"))
        map.nodes[0].level = "0"
        XCTAssertThrowsError(try map.route(from: "a", to: "b"))
    }
}
