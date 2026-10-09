import XCTest
@testable import BlindCore

final class PlacePackageTests: XCTestCase {
    private func draft() throws -> PlacePackage {
        let map = IndoorMap(name: "Authored example", nodes: [
            MapNode(id: "entrance", name: "Entrance", level: "plan-level", position: Point3(0, 0, 0)),
            MapNode(id: "desk", name: "Desk", level: "plan-level", position: Point3(0, 0, -2))],
            edges: [MapEdge(from: "entrance", to: "desk", distance: 2)])
        return try PlacePackage.draft(map: map, author: "Test author", license: "Test data only")
    }
    func testRoundTripPreservesExplicitCoverageAndDoesNotInventRooms() throws {
        let value = try draft(), decoded = try PlacePackage.decode(value.encoded())
        XCTAssertEqual(decoded.id, value.id); XCTAssertEqual(decoded.visibility, "private")
        XCTAssertEqual(decoded.provenance, "authored"); XCTAssertTrue(decoded.rooms.isEmpty)
        XCTAssertTrue(decoded.connections.isEmpty); XCTAssertFalse(decoded.coverageGaps.isEmpty)
        XCTAssertEqual(decoded.routeMap?.nodes.count, 2)
    }
    func testRejectsPrivateMemoryEnvelopeAndOversizedInput() throws {
        var value = try XCTUnwrap(JSONSerialization.jsonObject(with: draft().encoded()) as? [String: Any])
        value["people"] = [["name": "Private family member"]]
        XCTAssertThrowsError(try PlacePackage.decode(JSONSerialization.data(withJSONObject: value)))
        XCTAssertThrowsError(try PlacePackage.decode(Data(repeating: 32, count: PlacePackage.maximumBytes + 1)))
    }
    func testRejectsUnknownFloorAndAmbiguousCoordinateFrames() throws {
        var value = try draft()
        value.routeMap?.nodes[0].level = "invented-floor"
        XCTAssertThrowsError(try value.validate())
        value = try draft()
        value.floors.append(.init(id: "other", name: "Other", frameID: "unrelated-scan"))
        value.routeMap?.nodes[1].level = "other"
        XCTAssertThrowsError(try value.validate())
    }
    func testRoomConnectionsRequireExplicitReferencesAndVerticalTransition() throws {
        var value = try draft(); value.routeMap = nil; value.localization = "preview-only"
        value.floors.append(.init(id: "upstairs", name: "Upstairs", frameID: "other-frame"))
        value.rooms = [.init(id: "bedroom", name: "Bedroom", floorID: "plan-level", kind: "room", description: ""),
                       .init(id: "bathroom", name: "Bathroom", floorID: "upstairs", kind: "room", description: "")]
        value.connections = [.init(id: "door", fromRoomID: "bedroom", toRoomID: "bathroom", kind: "door", state: "mapped", source: "Test")]
        XCTAssertThrowsError(try value.validate())
        value.connections[0].kind = "stairs"; XCTAssertNoThrow(try value.validate())
        value.connections[0].toRoomID = "missing"; XCTAssertThrowsError(try value.validate())
    }
    func testReviewCannotApplyToDifferentRevisionOrClaimGlobalSafety() throws {
        var value = try draft()
        value.reviews = [.init(id: "review", revision: "old", reviewer: "Reviewer", scope: "geometry",
            date: "2026-10-08T00:00:00Z", method: "Compared labels", limitations: "No device trial")]
        XCTAssertThrowsError(try value.validate())
        value.reviews[0].revision = value.revision; XCTAssertNoThrow(try value.validate())
        value.reviews[0].scope = "safe"; XCTAssertThrowsError(try value.validate())
    }
    func testImportedMapCannotBeRebrandedAsNewAuthoredContribution() throws {
        var value = try draft(); value.routeMap?.packageID = value.id; value.routeMap?.packageRevision = value.revision
        XCTAssertThrowsError(try PlacePackage.draft(map: XCTUnwrap(value.routeMap), author: "Someone else", license: "Mine"))
    }
    func testRouteRevisionMustMatchItsContainingPackage() throws {
        var value = try draft(); value.routeMap?.packageID = value.id; value.routeMap?.packageRevision = value.revision
        XCTAssertNoThrow(try value.validate())
        value.routeMap?.packageRevision = "different-revision"
        XCTAssertThrowsError(try value.validate())
    }
    func testPointRouteCannotInventAnInterFloorTransition() throws {
        var value = try draft()
        value.floors.append(.init(id: "upstairs", name: "Upstairs", frameID: value.floors[0].frameID))
        value.routeMap?.nodes[1].level = "upstairs"
        XCTAssertThrowsError(try value.validate())
    }
    func testLocalRouteEditCannotMasqueradeAsUnchangedCommunityRevision() throws {
        var value = try draft(); value.routeMap?.packageID = value.id; value.routeMap?.packageRevision = value.revision
        value.routeMap?.markLocalEdit()
        XCTAssertEqual(value.routeMap?.packageModified, true)
        XCTAssertNoThrow(try value.routeMap?.validate()) // Local route copy remains usable after separate alignment.
        XCTAssertThrowsError(try value.validate()) // Cannot reuse contributor review claims in a package.
        let copy = try JSONDecoder().decode(IndoorMap.self, from: JSONEncoder().encode(XCTUnwrap(value.routeMap)))
        XCTAssertEqual(copy.packageModified, true)
        XCTAssertEqual(copy.packageRevision, value.revision)
    }
    func testDownloadedAuthoredPlanHasNoFabricatedRouteOrCurrentPosition() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "oas-apartment", withExtension: "blindplace.json", subdirectory: "Fixtures"))
        let package = try PlacePackage.decode(Data(contentsOf: url))
        XCTAssertEqual(package.rooms.count, 5) // Four source rooms plus the explicitly connected exterior.
        XCTAssertEqual(package.connections.count, 4)
        XCTAssertNil(package.routeMap); XCTAssertEqual(package.localization, "preview-only")
        XCTAssertEqual(package.provenance, "authored")
        XCTAssertFalse(package.connections.contains { Set([$0.fromRoomID, $0.toRoomID]) == Set(["bedroom", "bathroom"]) })
    }
}
