import XCTest
import CryptoKit
import RoomPlan
import BlindCore
@testable import BlindAssist

/// Original Apple prescanned JSON, not hand-authored CapturedRoom-shaped data.
/// The saved-frame descriptor below is SYNTHETIC test metadata: these fixtures
/// include no paired ARWorldMap, live recovery, camera track or accuracy evidence.
@MainActor final class SavedRoomDiagnosticGeometryAppleFixtureTests: XCTestCase {
    private enum Fixture: String, CaseIterable {
        case hallway = "Hallway2", bedroom = "Bedroom3"
        var digest: String {
            switch self {
            case .hallway: return "f4cf3460fd9e746a86fe6538e2b1980e22e18207a2d3c7ea3f7679f58c8c6f4d"
            case .bedroom: return "44df7bd5f4d1961bf13344916384dcfa20d42c7ef8dc58b0e13d1c2f7c6a4d2e"
            }
        }
        var byteCount: Int { self == .hallway ? 27_575 : 69_516 }
        var counts: SavedRoomDiagnosticGeometry.Counts {
            switch self {
            case .hallway: return .init(floors: 1, walls: 6, doors: 6, windows: 0, openings: 0, furniture: 0)
            case .bedroom: return .init(floors: 1, walls: 4, doors: 2, windows: 1, openings: 0, furniture: 3)
            }
        }
    }
    private enum Failure: Error { case invalidFixture, timeout }
    private struct CategoryPayload: Decodable {}
    private struct RawFeature: Decodable {
        let identifier: UUID
        let dimensions: [Double]
        let transform: [Double]
        let polygonCorners: [[Double]]?
        let category: [String: CategoryPayload]
    }
    /// Independent raw-JSON view of the original numeric fields. This does not
    /// construct CapturedRoom and does not call the production transform adapter.
    private struct RawRoom: Decodable {
        let version, story: Int
        let floors, walls, doors, windows, openings, objects: [RawFeature]
        var groups: [(SavedRoomDiagnosticGeometry.Kind, [RawFeature])] {
            [(.floor, floors), (.wall, walls), (.door, doors), (.window, windows), (.opening, openings), (.furniture, objects)]
        }
    }
    private func bytes(_ fixture: Fixture) throws -> Data {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "\(fixture.rawValue).capturedRoom",
            withExtension: "json", subdirectory: "RoomPlanApple"), "Missing hosted-test-only original Apple resource")
        let data = try Data(contentsOf: url)
        XCTAssertEqual(data.count, fixture.byteCount)
        XCTAssertEqual(SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(), fixture.digest)
        return data
    }
    private func syntheticDescriptor(_ fixture: Fixture) -> SavedWorldFrame {
        // Deliberately invented test IDs/map digest/date, NOT a claimed source map.
        .init(placeID: UUID().uuidString, revision: UUID().uuidString,
            worldMapSHA256: String(repeating: "a", count: 64), roomCaptureSHA256: fixture.digest,
            originAnchorID: UUID().uuidString, capturedAt: Date(timeIntervalSince1970: 1))
    }
    private func assertPoint(_ actual: Point3, _ expected: [Double], file: StaticString = #filePath, line: UInt = #line) {
        guard expected.count == 3 else { return XCTFail("Invalid independent point witness", file: file, line: line) }
        XCTAssertEqual(actual.x, expected[0], accuracy: 0.00001, file: file, line: line)
        XCTAssertEqual(actual.y, expected[1], accuracy: 0.00001, file: file, line: line)
        XCTAssertEqual(actual.z, expected[2], accuracy: 0.00001, file: file, line: line)
    }
    private func assertEveryOriginalField(_ geometry: SavedRoomDiagnosticGeometry, raw: RawRoom) throws {
        XCTAssertEqual(raw.version, 2)
        XCTAssertEqual(geometry.story, raw.story)
        let originalIDs = raw.groups.flatMap { $0.1.map(\.identifier) }
        XCTAssertEqual(Set(geometry.features.map(\.id)), Set(originalIDs))
        XCTAssertEqual(geometry.features.count, originalIDs.count)
        for (kind, originals) in raw.groups {
            XCTAssertEqual(geometry.features.filter { $0.kind == kind }.count, originals.count)
            for original in originals {
                guard original.dimensions.count == 3, original.transform.count == 16,
                      original.category.count == 1,
                      (original.polygonCorners ?? []).allSatisfy({ $0.count == 3 }) else { throw Failure.invalidFixture }
                let feature = try XCTUnwrap(geometry.features.first { $0.id == original.identifier })
                XCTAssertEqual(feature.kind, kind)
                XCTAssertEqual(feature.category, try XCTUnwrap(original.category.keys.first))
                assertPoint(feature.dimensions, original.dimensions)
                XCTAssertEqual(feature.transform.columns.count, 16)
                for (actual, expected) in zip(feature.transform.columns, original.transform) {
                    XCTAssertEqual(actual, expected, accuracy: 0.00001)
                }
                let corners = original.polygonCorners ?? []
                XCTAssertEqual(feature.polygonCorners.count, corners.count)
                for (actual, expected) in zip(feature.polygonCorners, corners) { assertPoint(actual, expected) }
                let lines = geometry.polylines.filter { $0.featureID == feature.id }
                XCTAssertEqual(lines.count, corners.isEmpty ? 12 : 1)
                if !corners.isEmpty {
                    let polygon = try XCTUnwrap(lines.first)
                    XCTAssertTrue(polygon.closed)
                    XCTAssertEqual(polygon.points.count, corners.count)
                    for (point, corner) in zip(polygon.points, corners) {
                        // Column-major multiplication of original JSON numbers,
                        // independent from NativeCameraTransform.applying(to:).
                        let t = original.transform
                        let expected = (0..<3).map { r in
                            t[r] * corner[0] + t[4+r] * corner[1] + t[8+r] * corner[2] + t[12+r]
                        }
                        assertPoint(point, expected)
                    }
                }
            }
        }
        XCTAssertFalse(geometry.permitsPhysicalGuidance)
    }
    func testBothOriginalAppleRoomsDecodeThroughNativeFrameworkAndProductionExtractor() throws {
        for fixture in Fixture.allCases {
            let data = try bytes(fixture)
            let room = try JSONDecoder().decode(CapturedRoom.self, from: data)
            let frame = syntheticDescriptor(fixture)
            let geometry = try SavedRoomDiagnosticGeometryDecoder.decode(data, frame: frame)
            let nativeCounts = SavedRoomDiagnosticGeometry.Counts(floors: room.floors.count, walls: room.walls.count,
                doors: room.doors.count, windows: room.windows.count, openings: room.openings.count, furniture: room.objects.count)
            XCTAssertEqual(nativeCounts, fixture.counts)
            // The original JSON has no room identifier. Native run40664336968
            // observed different framework-assigned IDs on separate decodes.
            // Test identifier copying only from the SAME native room instance;
            // stable source ownership uses the frame/hash and persisted features.
            let sameNativeRoom = try SavedRoomDiagnosticGeometryDecoder.extract(room, frame: frame)
            XCTAssertEqual(sameNativeRoom.capturedRoomID, room.identifier)
            XCTAssertEqual(geometry.frame, frame)
            XCTAssertEqual(geometry.frame.roomCaptureSHA256, fixture.digest)
            XCTAssertEqual(geometry.sourceCounts, nativeCounts)
            XCTAssertEqual(geometry.features, sameNativeRoom.features)
            XCTAssertEqual(geometry.sourceCounts, fixture.counts)
            XCTAssertEqual(geometry.features.count, try XCTUnwrap(fixture.counts.total))
            try assertEveryOriginalField(geometry, raw: JSONDecoder().decode(RawRoom.self, from: data))
        }
    }
    func testRepeatedOriginalDecodesBindStableSourceAndFeaturesNotRoomUUID() throws {
        for fixture in Fixture.allCases {
            let data = try bytes(fixture), frame = syntheticDescriptor(fixture)
            let original = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            XCTAssertNil(original["identifier"])
            let first = try SavedRoomDiagnosticGeometryDecoder.decode(data, frame: frame)
            let second = try SavedRoomDiagnosticGeometryDecoder.decode(data, frame: frame)
            XCTAssertEqual(first.frame, second.frame)
            XCTAssertEqual(first.frame, frame)
            XCTAssertEqual(second.frame.roomCaptureSHA256, fixture.digest)
            XCTAssertEqual(first.story, second.story)
            XCTAssertEqual(first.sourceCounts, second.sourceCounts)
            XCTAssertEqual(first.features, second.features)
            XCTAssertEqual(first.polylines, second.polylines)
            // No equality OR inequality assertion on cross-decode capturedRoomID:
            // its persistence is not the source contract, even if an SDK changes it.
            XCTAssertFalse(first.permitsPhysicalGuidance)
            XCTAssertFalse(second.permitsPhysicalGuidance)
        }
    }
    func testBedroomOriginalFloorPolygonAndBedDepthHaveIndependentWorldWitnesses() throws {
        let geometry = try SavedRoomDiagnosticGeometryDecoder.decode(bytes(.bedroom), frame: syntheticDescriptor(.bedroom))
        let floorID = try XCTUnwrap(UUID(uuidString: "B95427E8-846F-4367-A2DA-87892E259635"))
        let floor = try XCTUnwrap(geometry.features.first { $0.id == floorID })
        assertPoint(floor.dimensions, [3.5544705, 3.3611374, 0]) // No inflated wall/floor thickness.
        let outline = try XCTUnwrap(geometry.polylines.first { $0.featureID == floorID })
        let world = [[2.323137373056058, -1.465985, 16.703357492181844],
                     [-1.185866286299784, -1.465985, 16.205300397357025],
                     [-0.7174753508629721, -1.465985, 12.905301991829168],
                     [2.791528137945333, -1.465985, 13.403358153426467]]
        XCTAssertEqual(outline.points.count, world.count)
        for (actual, expected) in zip(outline.points, world) { assertPoint(actual, expected) }
        let furniture = geometry.features.filter { $0.kind == .furniture }
        XCTAssertEqual(Set(furniture.map(\.category)), ["bed", "table", "chair"])
        let bed = try XCTUnwrap(furniture.first { $0.id.uuidString == "45597D99-3218-4419-A2E4-2ADFA824D033" })
        assertPoint(bed.dimensions, [1.6728522, 0.6448028, 2.1749296])
        let edges = geometry.polylines.filter { $0.featureID == bed.id }
        XCTAssertEqual(edges.count, 12)
        let firstCorner = try XCTUnwrap(edges.first?.points.first)
        assertPoint(firstCorner, [2.6284449060697, -1.4659849, 14.552343561668101])
    }
    func testRealSourceHashMismatchIsRejectedInsteadOfBorrowingOtherRoom() throws {
        XCTAssertThrowsError(try SavedRoomDiagnosticGeometryDecoder.decode(bytes(.bedroom), frame: syntheticDescriptor(.hallway))) {
            XCTAssertEqual($0 as? SavedRoomDiagnosticGeometryDecoder.Failure, .sourceMismatch)
        }
    }
    func testDefaultProviderReadsOriginalRoomAndRetiresAtDeletionAdmission() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("AppleRoomGeometry-\(UUID().uuidString)")
        let directory = root.appendingPathComponent("Places")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let frame = syntheticDescriptor(.bedroom), id = try XCTUnwrap(UUID(uuidString: frame.placeID))
        let place = SavedPlace(id: id, name: "Apple original fixture; synthetic descriptor", createdAt: frame.capturedAt,
            objects: [], worldFrame: frame)
        try JSONEncoder().encode(place).write(to: directory.appendingPathComponent("\(id).json"))
        try bytes(.bedroom).write(to: directory.appendingPathComponent("\(id).room.json"))
        let store = PlaceStore(directory: directory)
        let provider = SavedRoomDiagnosticGeometryProvider(places: store) // No injected geometry/loader.
        defer { provider.cancel() }
        provider.select(frame)
        let deadline = ProcessInfo.processInfo.systemUptime + 10
        while provider.hasPendingWork, ProcessInfo.processInfo.systemUptime < deadline {
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        guard !provider.hasPendingWork else { XCTFail("Native decode did not complete"); throw Failure.timeout }
        XCTAssertEqual(provider.status, .ready)
        let geometry = try XCTUnwrap(provider.geometry)
        XCTAssertEqual(geometry.frame, frame)
        XCTAssertEqual(geometry.sourceCounts, Fixture.bedroom.counts)
        store.retireDiagnosticGeometry(for: place)
        provider.select(frame)
        XCTAssertEqual(provider.status, .unavailable)
        XCTAssertNil(provider.geometry)
        XCTAssertNil(store.diagnosticGeometrySource(for: frame))
    }
}
