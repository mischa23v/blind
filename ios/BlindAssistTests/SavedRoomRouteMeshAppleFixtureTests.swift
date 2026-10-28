import XCTest
import CryptoKit
import simd
@testable import BlindAssist

/// Executes Apple's real RoomPlan mesh export and Model I/O importer over the
/// unchanged official fixtures. No synthetic CapturedRoom, supplied mesh or AR
/// registration. Numerical tolerances concern Float32 export arithmetic only.
@MainActor final class SavedRoomRouteMeshAppleFixtureTests: XCTestCase {
    private enum Fixture: String, CaseIterable {
        case hallway = "Hallway2", bedroom = "Bedroom3"
        var digest: String {
            self == .hallway ? "f4cf3460fd9e746a86fe6538e2b1980e22e18207a2d3c7ea3f7679f58c8c6f4d" :
                "44df7bd5f4d1961bf13344916384dcfa20d42c7ef8dc58b0e13d1c2f7c6a4d2e"
        }
    }
    private struct RawCategory: Decodable { let isOpen: Bool? }
    private struct RawFeature: Decodable {
        let identifier: UUID
        let parentIdentifier: UUID?
        let dimensions, transform: [Double]
        let polygonCorners: [[Double]]?
        let category: [String: RawCategory]
    }
    private struct RawRoom: Decodable {
        let floors, walls, doors, windows, openings, objects: [RawFeature]
        var all: [RawFeature] { floors + walls + doors + windows + openings + objects }
    }
    private func bytes(_ fixture: Fixture) throws -> Data {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "\(fixture.rawValue).capturedRoom",
            withExtension: "json", subdirectory: "RoomPlanApple"))
        let data = try Data(contentsOf: url)
        XCTAssertEqual(SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(), fixture.digest)
        return data
    }
    private func snapshot(_ fixture: Fixture) async throws -> (SavedRoomRouteMeshSnapshot, RawRoom) {
        let data = try bytes(fixture), expected = fixture.digest
        let mesh = try await Task.detached(priority: .utility) {
            try SavedRoomRouteMeshAdapter.decode(data: data, expectedSHA256: expected)
        }.value
        return (mesh, try JSONDecoder().decode(RawRoom.self, from: data))
    }
    private func vertex(_ mesh: SavedRoomRouteMeshSnapshot, _ index: Int32) -> SIMD3<Double> {
        let i = Int(index) * 3
        return SIMD3(mesh.vertices[i], mesh.vertices[i + 1], mesh.vertices[i + 2])
    }
    private func triangle(_ mesh: SavedRoomRouteMeshSnapshot, _ index: Int) -> [SIMD3<Double>] {
        (0..<3).map { vertex(mesh, mesh.triangles[index * 3 + $0]) }
    }
    // Independent multiplication from original JSON, not adapter helpers.
    private func world(_ local: [Double], _ source: RawFeature) -> SIMD3<Double> {
        let t = source.transform
        let p = (0..<3).map { r in t[r] * local[0] + t[4 + r] * local[1] + t[8 + r] * local[2] + t[12 + r] }
        return SIMD3(p[0], p[1], p[2])
    }
    private func localXY(_ world: SIMD3<Double>, _ source: RawFeature) -> SIMD2<Double> {
        let t = source.transform, x = world.x - source.transform[12], y = world.y - source.transform[13], z = world.z - source.transform[14]
        return SIMD2(t[0] * x + t[1] * y + t[2] * z, t[4] * x + t[5] * y + t[6] * z)
    }
    private func cross(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double { a.x * b.y - a.y * b.x }
    private func contains(_ p: SIMD2<Double>, triangle: [SIMD2<Double>]) -> Bool {
        guard cross(triangle[1] - triangle[0], triangle[2] - triangle[0]) != 0 else { return false }
        let a = cross(triangle[1] - triangle[0], p - triangle[0])
        let b = cross(triangle[2] - triangle[1], p - triangle[1])
        let c = cross(triangle[0] - triangle[2], p - triangle[2])
        return (a >= 0 && b >= 0 && c >= 0) || (a <= 0 && b <= 0 && c <= 0)
    }
    private struct BoundaryEdge { let a, b: SIMD3<Double> }
    /// Export may legitimately omit collinear source vertices. Compare complete
    /// boundary segments instead of requiring identical tessellation topology.
    /// Coincident exported Float32 vertices have identical copied Double bits;
    /// coordinate keys also work when Model I/O duplicates vertices per face.
    private func boundary(_ mesh: SavedRoomRouteMeshSnapshot, indices: [Int]) throws -> [BoundaryEdge] {
        var edges: [String: (edge: BoundaryEdge, count: Int)] = [:]
        func key(_ p: SIMD3<Double>) -> String { "\(p.x == 0 ? 0 : p.x.bitPattern):\(p.y == 0 ? 0 : p.y.bitPattern):\(p.z == 0 ? 0 : p.z.bitPattern)" }
        for index in indices {
            let points = triangle(mesh,index)
            guard simd_cross(points[1]-points[0],points[2]-points[0]).y > 0 else { continue }
            for i in 0..<3 {
                let a = points[i], b = points[(i+1)%3]
                let id = [key(a),key(b)].sorted().joined(separator:"|")
                if let previous = edges[id] { edges[id] = (previous.edge, previous.count+1) }
                else { edges[id] = (BoundaryEdge(a:a,b:b),1) }
            }
        }
        XCTAssertTrue(edges.values.allSatisfy { $0.count <= 2 },"Nonmanifold/overlapping upward floor mesh")
        return edges.values.filter { $0.count == 1 }.map(\.edge)
    }
    private func distance(_ point: SIMD3<Double>, edge: BoundaryEdge) -> Double {
        let segment = edge.b-edge.a, squaredLength = simd_length_squared(segment)
        guard squaredLength > 0 else { return simd_length(point-edge.a) }
        let fraction = max(0,min(1,simd_dot(point-edge.a,segment)/squaredLength))
        return simd_length(point-(edge.a+fraction*segment))
    }

    func testOriginalAppleExportInventoryPreservesFeatureIdentityAndHistoricalDoorState() async throws {
        for fixture in Fixture.allCases {
            let (mesh, raw) = try await snapshot(fixture)
            XCTAssertEqual(mesh.sourceSHA256, fixture.digest)
            XCTAssertEqual(Set(mesh.features.map(\.id)), Set(raw.all.map(\.identifier)))
            XCTAssertEqual(mesh.floorSupport.count * 3, mesh.triangles.count)
            XCTAssertEqual(mesh.triangleFeatureIDs.count, mesh.floorSupport.count)
            XCTAssertFalse(mesh.physicalAuthority)
            XCTAssertFalse(mesh.currentDoorStateKnown)
            XCTAssertFalse(mesh.actualWorldCoverageKnown)
            XCTAssertFalse(mesh.vertices.isEmpty)
            XCTAssertGreaterThan(mesh.upwardFloorTriangles, 0, "Export must provide upward floor support; no silent winding repair")
            let floorIDs = Set(raw.floors.map(\.identifier))
            for index in mesh.floorSupport.indices {
                XCTAssertEqual(mesh.floorSupport[index], floorIDs.contains(mesh.triangleFeatureIDs[index]))
            }
            let originals = Dictionary(uniqueKeysWithValues: raw.all.map { ($0.identifier, $0) })
            for feature in mesh.features {
                let source = try XCTUnwrap(originals[feature.id])
                XCTAssertEqual(feature.parentID, source.parentIdentifier)
                XCTAssertEqual(feature.transform.count, 16)
                for (actual, expected) in zip(feature.transform, source.transform) {
                    XCTAssertEqual(actual, expected, accuracy: Double(Float.ulpOfOne) * max(1, abs(expected)))
                }
                for (actual, expected) in zip(feature.dimensions, source.dimensions) {
                    XCTAssertEqual(actual, expected, accuracy: Double(Float.ulpOfOne) * max(1, abs(expected)))
                }
                XCTAssertEqual(feature.polygonCorners.count,source.polygonCorners?.count ?? 0)
                for (actual,expected) in zip(feature.polygonCorners,source.polygonCorners ?? []) {
                    XCTAssertEqual(actual.count,expected.count)
                    for (component,original) in zip(actual,expected) {
                        XCTAssertEqual(component,original,accuracy:Double(Float.ulpOfOne)*max(1,abs(original)))
                    }
                }
                XCTAssertEqual(feature.capturedDoorOpen, source.category["door"]?.isOpen)
                if feature.kind == .door, feature.capturedDoorOpen == false {
                    XCTAssertTrue(mesh.exportedFeatureIDs.contains(feature.id), "Closed captured door needs actual blocking geometry")
                }
            }
            XCTAssertEqual(raw.doors.filter { $0.category["door"]?.isOpen == false }.count, fixture == .hallway ? 4 : 2)
            XCTAssertEqual(raw.doors.filter { $0.category["door"]?.isOpen == true }.count, fixture == .hallway ? 2 : 0)
            if fixture == .bedroom {
                XCTAssertEqual(Set(mesh.features.filter { $0.kind == .furniture }.map(\.category)), ["bed", "table", "chair"])
                for object in raw.objects {
                    let indices = mesh.triangleFeatureIDs.indices.filter { mesh.triangleFeatureIDs[$0] == object.identifier }
                    XCTAssertFalse(indices.isEmpty)
                    XCTAssertTrue(indices.allSatisfy { !mesh.floorSupport[$0] }, "Furniture top faces never become original floor")
                }
            }
        }
    }

    func testRealFloorTriangulationPreservesOriginalConcavityAreaAndWorldCorners() async throws {
        for fixture in Fixture.allCases {
            let (mesh, raw) = try await snapshot(fixture)
            let floor = try XCTUnwrap(raw.floors.first), polygon = try XCTUnwrap(floor.polygonCorners)
            XCTAssertEqual(polygon.count, fixture == .hallway ? 8 : 4)
            let indices = mesh.triangleFeatureIDs.indices.filter { mesh.triangleFeatureIDs[$0] == floor.identifier }
            var area = 0.0
            for index in indices {
                let points = triangle(mesh, index)
                if simd_cross(points[1] - points[0], points[2] - points[0]).y <= 0 { continue }
                let local = points.map { localXY($0, floor) }
                area += abs(cross(local[1] - local[0], local[2] - local[0])) / 2
            }
            let sourceArea = abs(polygon.indices.reduce(0.0) { total, i in
                let j = (i + 1) % polygon.count
                return total + polygon[i][0] * polygon[j][1] - polygon[j][0] * polygon[i][1]
            }) / 2
            XCTAssertEqual(area, sourceArea, accuracy: 64 * Double(Float.ulpOfOne) * max(1, sourceArea),
                "Upward floor triangles must cover exactly the original polygon, not its bounding rectangle")
            let exportedBoundary = try boundary(mesh,indices:indices)
            XCTAssertFalse(exportedBoundary.isEmpty)
            let originalPoints = polygon.map { world($0,floor) }
            let originalBoundary = polygon.indices.map { BoundaryEdge(a:originalPoints[$0],b:originalPoints[($0+1)%polygon.count]) }
            // Both directions matter: original corners/edges cannot disappear,
            // and an invented edge or unsupported hole cannot appear. Midpoints
            // plus endpoints cover any collinear edge subdivisions in this input.
            for (source,target) in [(originalBoundary,exportedBoundary),(exportedBoundary,originalBoundary)] {
                for edge in source {
                    for expected in [edge.a,(edge.a+edge.b)/2,edge.b] {
                        let nearest = target.map { distance(expected,edge:$0) }.min() ?? .infinity
                        let scale = max(1,max(abs(expected.x),max(abs(expected.y),abs(expected.z))))
                        XCTAssertLessThanOrEqual(nearest,64*Double(Float.ulpOfOne)*scale,
                            "Original floor boundary must be preserved; collinear tessellation vertices need not be identical")
                    }
                }
            }
            if fixture == .hallway {
                // Fixed original-source witness: within floor bounds but outside
                // its concave upper indentation. Never move this after results.
                let unsupported = SIMD2<Double>(0, 0.5)
                XCTAssertFalse(indices.contains { index in
                    contains(unsupported, triangle: triangle(mesh, index).map { localXY($0, floor) })
                }, "Concave missing floor must not be filled by a rectangle or naive fan")
            }
        }
    }

    func testAppleWallMeshHasRealDoorAndWindowCutoutsWithClosedDoorBarrierSeparate() async throws {
        for fixture in Fixture.allCases {
            let (mesh, raw) = try await snapshot(fixture)
            for opening in raw.doors + raw.windows + raw.openings {
                let parentID = try XCTUnwrap(opening.parentIdentifier)
                let wall = try XCTUnwrap(raw.walls.first { $0.identifier == parentID })
                let center = world([0, 0, 0], opening)
                let wallPoint = localXY(center, wall)
                let wallTriangles = mesh.triangleFeatureIDs.indices.filter { mesh.triangleFeatureIDs[$0] == parentID }
                XCTAssertFalse(wallTriangles.isEmpty)
                XCTAssertFalse(wallTriangles.contains { index in
                    contains(wallPoint, triangle: triangle(mesh, index).map { localXY($0, wall) })
                }, "Whole-wall quads must not conceal the actual Apple cutout")
                if opening.category["door"]?.isOpen == false {
                    let leafTriangles = mesh.triangleFeatureIDs.indices.filter { mesh.triangleFeatureIDs[$0] == opening.identifier }
                    XCTAssertFalse(leafTriangles.isEmpty)
                    XCTAssertTrue(leafTriangles.contains { index in
                        contains(SIMD2<Double>(0, 0), triangle: triangle(mesh, index).map { localXY($0, opening) })
                    }, "Wall cutout is separate from the original closed-door obstacle")
                }
            }
        }
    }

    func testWrongOriginalRoomDigestFailsBeforeExport() async throws {
        let data = try bytes(.bedroom), wrong = Fixture.hallway.digest
        let result = await Task.detached(priority: .utility) { () -> SavedRoomRouteMeshAdapter.Failure? in
            do { _ = try SavedRoomRouteMeshAdapter.decode(data: data, expectedSHA256: wrong); return nil }
            catch { return error as? SavedRoomRouteMeshAdapter.Failure }
        }.value
        XCTAssertEqual(result, .sourceMismatch)
    }
}
