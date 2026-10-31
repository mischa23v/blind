import XCTest
#if canImport(CryptoKit)
import CryptoKit
import BlindCore

final class RoomMeshPreviewTests: XCTestCase {
    let digest = "e60c008fd5759ebf81863774f8335c27429a20b19253c95b2b6db45291bb44d2"
    func bytes() throws -> Data {
        try Data(contentsOf: XCTUnwrap(Bundle.module.url(forResource: "recorded-room-route-diagnostic", withExtension: "json", subdirectory: "Fixtures")))
    }
    func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    func context() throws -> RoomPreviewContext {
        try .init(placeID: "MuSHRoom-recorded", floorID: "recorded-level", roomID: "Koivu",
            frameID: "phone-corrected-level-game-yup-v1", poseProvenance: "Recorded supplied query poses; not live localization",
            supportProvenance: "Reference-assisted study; not current phone floor support")
    }
    func testAllRealSavedRoutesPreserveCoordinatesWithoutAuthority() throws {
        let data = try bytes()
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        for variant in [SavedRoomMeshPreview.Variant.original, .replayed, .excluded] {
            let routes = try XCTUnwrap(json[variant.rawValue] as? [[String: Any]])
            for i in routes.indices {
                let preview = try SavedRoomMeshPreview.load(data: data, expectedSHA256: digest, sha256: hash,
                    variant: variant, index: i, context: context())
                let expected = try XCTUnwrap(routes[i]["points"] as? [[NSNumber]])
                XCTAssertEqual(preview.points, expected.map { $0.map(\.floatValue) })
                XCTAssertFalse(preview.physicalAuthority); XCTAssertFalse(preview.clearanceVerified)
                XCTAssertFalse(preview.bodyHeadingKnown); XCTAssertFalse(preview.actualWorldCoverageKnown)
                XCTAssertEqual(preview.state, .withheldUnknownCoverage)
                XCTAssertFalse(preview.unknownCoverage.isEmpty)
                XCTAssertEqual(preview.context.roomID, "Koivu")
            }
        }
    }
    func testHashMismatchAndOutOfRangeRejected() throws {
        let data = try bytes(), context = try context()
        XCTAssertThrowsError(try SavedRoomMeshPreview.load(data: data, expectedSHA256: String(repeating: "0", count: 64), sha256: hash, variant: .original, index: 0, context: context))
        for index in [-1, 5] {
            XCTAssertThrowsError(try SavedRoomMeshPreview.load(data: data, expectedSHA256: digest, sha256: hash, variant: .original, index: index, context: context))
        }
    }
    func testAuthorityAndMalformedRouteRejectedEvenWhenHashMatches() throws {
        let original = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes()) as? [String: Any])
        var authority = original; authority["physicalAuthority"] = true
        var malformed = original
        var routes = try XCTUnwrap(malformed["actualOriginal"] as? [[String: Any]])
        routes[0]["points"] = [[0, 1]]; malformed["actualOriginal"] = routes
        for object in [authority, malformed] {
            let data = try JSONSerialization.data(withJSONObject: object)
            XCTAssertThrowsError(try SavedRoomMeshPreview.load(data: data, expectedSHA256: hash(data), sha256: hash, variant: .original, index: 0, context: context()))
        }
    }
    func testEmptyContextRejected() {
        XCTAssertThrowsError(try RoomPreviewContext(placeID: "", floorID: "f", roomID: "r", frameID: "frame", poseProvenance: "recorded", supportProvenance: "unknown"))
    }
}

#endif
