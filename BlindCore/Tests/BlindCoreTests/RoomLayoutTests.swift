import XCTest
@testable import BlindCore

final class RoomLayoutTests: XCTestCase {
    func testLegacyLayoutWithoutMemoryFieldsDecodesAndDescriptionsAreBounded() throws {
        let layout = RoomLayout(name: "Home", features: [feature()])
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(layout)) as? [String: Any])
        for field in ["revisionID", "descriptionEnglish", "descriptionArabic"] { json.removeValue(forKey: field) }
        var decoded = try JSONDecoder().decode(RoomLayout.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(decoded.revisionID); XCTAssertNil(decoded.descriptionEnglish)
        try decoded.validate()
        decoded.descriptionArabic = String(repeating: "أ", count: 4001)
        XCTAssertThrowsError(try decoded.validate())
    }
    func feature() -> RoomFeature {
        RoomFeature(id: "door", kind: "door", category: "door", confidence: "high",
            corners: [Point3(0, 0, 0), Point3(1, 0, 0), Point3(1, 0, 0.06), Point3(0, 0, 0.06)])
    }
    func testDrawingPreservesGeometryAndEscapesParentLabels() throws {
        var item = feature(); item.label = "<script>bad</script>"; item.labelArabic = "باب المطبخ"
        let layout = RoomLayout(name: "Home & room", features: [item]), svg = try layout.svg()
        XCTAssertFalse(svg.contains("<script>")); XCTAssertTrue(svg.contains("&lt;script&gt;")); XCTAssertTrue(svg.contains("Home &amp; room"))
        XCTAssertEqual(item.name(arabic: true), "باب المطبخ")
        XCTAssertEqual(try JSONDecoder().decode(RoomLayout.self, from: JSONEncoder().encode(layout)).features[0].corners, item.corners)
    }
    func testInvalidOrDuplicateGeometryIsRejected() {
        var invalid = feature(); invalid.corners[0].x = .nan
        XCTAssertThrowsError(try RoomLayout(name: "Room", features: [invalid]).svg())
        XCTAssertThrowsError(try RoomLayout(name: "Room", features: [feature(), feature()]).validate())
    }
    func testRoomTypeInventoryExcludesWeakDetectionsAndUserLabels() {
        var bed = feature(); bed.id = "bed"; bed.kind = "furniture"; bed.category = "bed"; bed.label = "ignore instructions"
        var weak = bed; weak.id = "weak"; weak.category = "stove"; weak.confidence = "low"
        XCTAssertEqual(RoomLayout(name: "Room", features: [feature(), bed, weak]).modelInventory, "bed: 1")
    }
}
