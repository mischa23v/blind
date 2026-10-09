import XCTest
@testable import BlindCore

final class MapContextTests: XCTestCase {
    let map = IndoorMap(name: "Cafe", nodes: [MapNode(id: "desk", name: "Cashier", level: "0", position: Point3(1, 0, 1)),
        MapNode(id: "wc", name: "Restroom", level: "0", position: Point3(3, 0, 1))], edges: [MapEdge(from: "desk", to: "wc", distance: 2)])
    func testQuestionSelectsOnlyNamedDestinations() {
        XCTAssertEqual(MapContext.matchingDestinations(question: "Take me to the cashier!", in: map).map(\.id), ["desk"])
        XCTAssertEqual(MapContext.matchingDestinations(question: "Where is the restroom?", in: map).map(\.id), ["wc"])
        XCTAssertTrue(MapContext.matchingDestinations(question: "cashiers", in: map).isEmpty)
        XCTAssertEqual(MapContext.matchingDestinations(question: "Cashier or restroom", in: map).count, 2)
    }
    func testModelCannotInventDestinationOrLocation() throws {
        let context = MapContext(map: map, position: nil, route: [])
        XCTAssertEqual(context.acceptedID("wc"), "wc")
        XCTAssertNil(context.acceptedID("invented-exit"))
        XCTAssertEqual(context.positionStatus, "unknown")
        XCTAssertNil(context.currentPosition)
        XCTAssertTrue(try context.json().contains("authored_graph_without_collision_surface"))
    }
    func testAmbiguousNamesRemainAmbiguousAndInvalidPositionIsUnknown() {
        var ambiguous = map
        ambiguous.nodes.append(MapNode(id: "wc2", name: "Restroom", level: "1", position: Point3(3, 3, 1)))
        XCTAssertEqual(MapContext.matchingDestinations(question: "Restroom", in: ambiguous).count, 2)
        XCTAssertNil(MapContext(map: ambiguous, position: Point3(.nan, 0, 0), route: []).currentPosition)
    }
    func testArabicNamesResolveWithoutEnglishOrLLM() {
        var arabic = map; arabic.nodes[0].nameArabic = "المحاسب"; arabic.nodes[1].nameArabic = "دورة المياه"
        XCTAssertEqual(MapContext.matchingDestinations(question: "أين دورة المياه؟", in: arabic).map(\.id), ["wc"])
        XCTAssertEqual(MapContext.matchingDestinations(question: "أريد المحاسب", in: arabic).map(\.id), ["desk"])
        XCTAssertEqual(arabic.nodes[1].localizedName(arabic: true), "دورة المياه")
        XCTAssertTrue(MapContext.matchingDestinations(question: "أين الصيدلية؟", in: arabic).isEmpty)
    }
}
