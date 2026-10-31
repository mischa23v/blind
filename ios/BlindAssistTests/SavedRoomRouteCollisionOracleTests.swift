import XCTest
import simd

/// Authored controls for the actual Apple collision backend, not real-room trials.
/// Real RoomPlan route fixtures consume the same helper separately.
@MainActor
final class SavedRoomRouteCollisionOracleTests: XCTestCase {
    private let wall = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
    private let floor = UUID(uuidString: "10000000-0000-0000-0000-000000000002")!

    func testBackendDiagnosticMatrixRecordsEveryControl() throws {
        let witness = SavedRoomRouteCollisionOracle.backendDiagnosticMatrix()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(witness)
        XCTAssertLessThanOrEqual(data.count, 131_072)
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "SavedRoomCollisionBackendMatrix-v1.json"
        attachment.lifetime = .keepAlways
        add(attachment) // retain evidence even when the candidate remains unavailable

        XCTAssertEqual(witness.cells.map(\.configurationID), ["restricted-no-renderer", "default-no-renderer",
            "restricted-offscreen-renderer", "default-offscreen-renderer"])
        XCTAssertFalse(witness.physicalAuthority)
        XCTAssertFalse(witness.fullFootprintSupportVerified)
        for cell in witness.cells {
            XCTAssertEqual(cell.queries.map(\.name), SavedRoomRouteCollisionOracle.ControlName.allCases)
            XCTAssertEqual(cell.failedControls, cell.queries.filter { !$0.passed }.map(\.name))
            XCTAssertEqual(cell.backendReady, cell.failedControls.isEmpty)
            XCTAssertTrue(cell.queries.filter { $0.errorCode != "none" }.allSatisfy { !$0.passed })
        }
        let candidate = try XCTUnwrap(witness.cells.last)
        XCTAssertEqual(candidate.configurationID, "default-offscreen-renderer")
        XCTAssertTrue(candidate.backendReady, "Candidate controls failed: \(candidate.failedControls.map(\.rawValue))")
        // Other cells are diagnostic controls, not an alternative success path.
        // This v1 bootstrap matrix retains combined queries. It does not replace
        // the newly mandatory mixed-scene/separated-query readiness controls.
    }

    func testMixedSceneCombinedAndSeparatedQueriesRecordEveryPhase() throws {
        let witness = SavedRoomRouteCollisionOracle.mixedSceneDiagnosticMatrix()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(witness)
        XCTAssertLessThanOrEqual(data.count, 131_072)
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "SavedRoomCollisionMixedScene-v1.json"
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertEqual(witness.cells.map(\.configurationID), ["wall-only-combined", "wall-and-floor-combined",
            "wall-only-separated", "wall-and-floor-separated"])
        XCTAssertFalse(witness.physicalAuthority)
        XCTAssertFalse(witness.fullFootprintSupportVerified)
        for cell in witness.cells {
            XCTAssertEqual(cell.queries.map(\.name), SavedRoomRouteCollisionOracle.mixedControlNames)
            XCTAssertEqual(cell.failedControls, cell.queries.filter { !$0.passed }.map(\.name))
            XCTAssertEqual(cell.backendReady, cell.failedControls.isEmpty)
            if cell.queryMode == "separated" {
                XCTAssertTrue(cell.backendReady, "\(cell.configurationID): \(cell.failedControls.map(\.rawValue))")
            }
        }
        // Combined cells record the previous behavior without authorizing a
        // fallback. The unchanged original mixed-scene test below must also pass.
    }

    private func wallAndFloor() throws -> SavedRoomRouteCollisionOracle {
        try SavedRoomRouteCollisionOracle(
            vertices: [0,0,-2, 0,3,-2, 0,3,2, 0,0,2,
                       -3,0,-3, 3,0,-3, 3,0,3, -3,0,3],
            triangles: [0,1,2, 0,2,3, 4,5,6, 4,6,7],
            floorSupport: [false,false,true,true], triangleFeatureIDs: [wall,wall,floor,floor])
    }

    func testThinWallSweepBothDirectionsAndNegativeControl() throws {
        let oracle = try wallAndFloor() // mandatory actual-backend calibration
        for (a,b) in [(SIMD3<Float>(-1,0,0),SIMD3<Float>(1,0,0)),
                      (SIMD3<Float>(1,0,0),SIMD3<Float>(-1,0,0))] {
            let hit = try oracle.sweep(from: a, to: b, radius: 0.2, height: 1.6)
            XCTAssertTrue(hit.initial.obstacleSurfaceIDs.isEmpty)
            XCTAssertTrue(hit.terminal.obstacleSurfaceIDs.isEmpty)
            XCTAssertEqual(hit.swept.obstacleSurfaceIDs, [wall])
            XCTAssertFalse(hit.physicalAuthority)
            XCTAssertFalse(hit.fullFootprintSupportVerified)
        }
        let clear = try oracle.sweep(from: SIMD3(-1,0,3), to: SIMD3(1,0,3), radius: 0.2, height: 1.6)
        XCTAssertFalse(clear.all.hasObstacleContact)
    }

    func testInitialOverlapIsNotLostByZeroLengthSweep() throws {
        let oracle = try wallAndFloor()
        let result = try oracle.sweep(from: SIMD3(0,0,0), to: SIMD3(0,0,0), radius: 0.2, height: 1.6)
        XCTAssertEqual(result.initial.obstacleSurfaceIDs, [wall])
        XCTAssertEqual(result.terminal.obstacleSurfaceIDs, [wall])
    }

    func testOriginalFurnitureSolidDetectsContainedStartSeparatelyFromShell() throws {
        let furniture = UUID(uuidString: "10000000-0000-0000-0000-000000000003")!
        // A 2x3x2 original model bound. Its separate shell is one outside face;
        // the contained cylinder cannot touch that face at x=-1.
        let oracle = try SavedRoomRouteCollisionOracle(vertices: [-1,0,-1,-1,3,-1,-1,3,1,-1,0,1],
            triangles: [0,1,2,0,2,3], floorSupport: [false,false], triangleFeatureIDs: [furniture,furniture],
            furnitureBoxes: [.init(featureID: furniture, dimensions: [2,3,2],
                transform: [1,0,0,0, 0,1,0,0, 0,0,1,0, 0,1.5,0,1])])
        let result = try oracle.sweep(from: SIMD3(0,0.5,0), to: SIMD3(0,0.5,0), radius: 0.2, height: 1)
        XCTAssertEqual(result.initial.furnitureBoundIDs, [furniture])
        XCTAssertTrue(result.initial.obstacleSurfaceIDs.isEmpty)
        XCTAssertTrue(result.all.hasObstacleContact)
    }

    func testHeadHeightAndSeparateFloorContact() throws {
        let top = UUID(uuidString: "10000000-0000-0000-0000-000000000004")!
        let oracle = try SavedRoomRouteCollisionOracle(vertices: [-1,1.4,-1,1,1.4,-1,1,1.4,1,-1,1.4,1,
            -3,0,-3,3,0,-3,3,0,3,-3,0,3], triangles: [0,1,2,0,2,3,4,5,6,4,6,7],
            floorSupport: [false,false,true,true], triangleFeatureIDs: [top,top,floor,floor])
        let short = try oracle.sweep(from: SIMD3(-2,0,0), to: SIMD3(2,0,0), radius: 0.2, height: 1)
        let tall = try oracle.sweep(from: SIMD3(-2,0,0), to: SIMD3(2,0,0), radius: 0.2, height: 1.6)
        XCTAssertFalse(short.all.hasObstacleContact)
        XCTAssertEqual(tall.swept.obstacleSurfaceIDs, [top])
        let floorContact = try oracle.sweep(from: SIMD3(2,-0.1,0), to: SIMD3(2,-0.1,0), radius: 0.2, height: 1.6)
        XCTAssertEqual(floorContact.initial.floorSurfaceIDs, [floor])
        XCTAssertFalse(floorContact.all.hasObstacleContact)
        XCTAssertFalse(floorContact.fullFootprintSupportVerified)
    }

    func testExplicitBodyVersusMarginBoundsAreNotInflatedAgain() throws {
        let oracle = try wallAndFloor()
        let from = SIMD3<Float>(0.3,0,-1), to = SIMD3<Float>(0.3,0,1)
        let body = try oracle.sweep(from: from, to: to, radius: 0.2, height: 1.6)
        let margin = try oracle.sweep(from: from, to: to, radius: 0.35, height: 1.75)
        XCTAssertFalse(body.all.hasObstacleContact)
        XCTAssertTrue(margin.all.obstacleSurfaceIDs.contains(wall))
        // A caller must count this as one margin-violating schedule, not the number
        // of triangle IDs or repeated start/sweep/end contact reports.
    }

    func testMalformedGeometryAndMissingFurnitureIdentityFail() throws {
        XCTAssertThrowsError(try SavedRoomRouteCollisionOracle(vertices: [0,0,0,1,0,0,0,1,0],
            triangles: [0,1,9], floorSupport: [false], triangleFeatureIDs: [wall]))
        XCTAssertThrowsError(try SavedRoomRouteCollisionOracle(vertices: [0,0,0,1,0,0,0,1,0],
            triangles: [0,1,2], floorSupport: [], triangleFeatureIDs: [wall]))
        XCTAssertThrowsError(try SavedRoomRouteCollisionOracle(vertices: [0,0,0,1,0,0,0,1,0],
            triangles: [0,1,2], floorSupport: [true], triangleFeatureIDs: [floor],
            furnitureBoxes: [.init(featureID: floor, dimensions: [1,1,1],
                transform: [1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1])]))
        let oracle = try wallAndFloor()
        XCTAssertThrowsError(try oracle.sweep(from: SIMD3(.nan,0,0), to: SIMD3(1,0,0), radius: 0.2, height: 1.6))
    }
}

