import Foundation
import XCTest
@testable import BlindCore
final class StoredTerrainAssessmentTests: XCTestCase {
    func testNumericalToleranceIsNotRiseOrSensorAllowance() {
        XCTAssertTrue(StoredTerrainPolicy.numericallyEqual(1, 1.nextUp))
        for delta in [1e-6, 0.001, 0.0064, 0.013, 0.08, 0.09] {
            for sign in [-1.0, 1.0] {
                let result = StoredTerrainPolicy.assess(sourceHeight: 0, destinationHeight: sign * delta, floorHeight: 0)
                XCTAssertFalse(result.permitsStoredLevelRoute)
                XCTAssertEqual(result.kind, sign > 0 ? .rise : .drop)
            }
        }
        XCTAssertFalse(StoredTerrainPolicy.numericallyEqual(1e15, (1e15).nextUp))
        XCTAssertFalse(StoredTerrainPolicy.numericallyEqual(.nan, .nan))
    }
    func testUnknownSupportAndUncertaintyDoNotBecomeLevel() {
        for floor in [Double?.none, .some(.nan), .some(.infinity)] {
            XCTAssertEqual(StoredTerrainPolicy.assess(sourceHeight: 0, destinationHeight: 0, floorHeight: floor).kind, .unknown)
        }
        for error in [Double.nan, .infinity, -0.01, 1e-15, 0.001, 0.1] {
            let result = StoredTerrainPolicy.assess(sourceHeight: 0, destinationHeight: 0, floorHeight: 0, floorUncertainty: error)
            XCTAssertFalse(result.permitsStoredLevelRoute); XCTAssertFalse(result.grantsPhysicalClearance)
        }
        let unknownMeasurement = StoredTerrainPolicy.assess(sourceHeight: 0, destinationHeight: 0, floorHeight: 0)
        XCTAssertTrue(unknownMeasurement.permitsStoredLevelRoute)
        XCTAssertNil(unknownMeasurement.measurementUncertaintyMetres)
        XCTAssertFalse(unknownMeasurement.grantsPhysicalClearance)
    }
    func testExplicitAnnotationsDoNotOverrideGeometry() {
        for annotation in [SurfaceTerrainAnnotation.rise, .drop, .slope, .step, .stairs, .unknown] {
            XCTAssertFalse(StoredTerrainPolicy.assess(sourceHeight: 0, destinationHeight: 0, floorHeight: 0, annotation: annotation).permitsStoredLevelRoute)
        }
        XCTAssertFalse(StoredTerrainPolicy.assess(sourceHeight: 0, destinationHeight: 0, floorHeight: 0.001, annotation: .level).permitsStoredLevelRoute)
        XCTAssertTrue(StoredTerrainPolicy.assess(sourceHeight: 0, destinationHeight: 0, floorHeight: 0, annotation: .level).permitsStoredLevelRoute)
    }
    func testGradualSlopeAndCrossSlopeRejectWithoutSlopePolicy() {
        var cells = Array(repeating: SurfaceCell(floor: 0, clearance: 3), count: 10000)
        for z in 0..<100 { for x in 0..<100 { cells[z * 100 + x].floor = Double(z) * 0.0001 } }
        var surface = NavigationSurface(level: "synthetic", origin: .init(0,0,0), resolution: 0.1, width: 100, depth: 100, cells: cells)
        XCTAssertFalse(surface.permitsLeg(from: .init(5,0.003,3), to: .init(5,0.007,7)))
        for z in 0..<100 { for x in 0..<100 { surface.cells[z * 100 + x].floor = Double(x) * 0.0001 } }
        XCTAssertFalse(surface.permitsLeg(from: .init(5,0.005,3), to: .init(5,0.005,7)))
    }
    func testWholeBodyFootprintAndHeadClearanceStillChecked() {
        let base = NavigationSurface(level: "synthetic", origin: .init(0,0,0), resolution: 0.1, width: 100, depth: 100, cells: Array(repeating: SurfaceCell(floor: 0, clearance: 3), count: 10000))
        var side = base; side.cells[50 * 100 + 53].floor = 0.001
        XCTAssertFalse(side.permitsLeg(from: .init(5,0,3), to: .init(5,0,7)))
        var overhead = base; overhead.cells[50 * 100 + 50].clearance = 1.5
        XCTAssertFalse(overhead.permitsLeg(from: .init(5,0,3), to: .init(5,0,7)))
        var unknown = base; unknown.cells[50 * 100 + 50].floor = nil
        XCTAssertFalse(unknown.permitsLeg(from: .init(5,0,3), to: .init(5,0,7)))
        var tagged = base; tagged.cells[50 * 100 + 50].terrain = .slope
        XCTAssertFalse(tagged.permitsLeg(from: .init(5,0,3), to: .init(5,0,7)))
        var uncertain = base; uncertain.cells[50 * 100 + 50].floorUncertainty = 0.01
        XCTAssertFalse(uncertain.permitsLeg(from: .init(5,0,3), to: .init(5,0,7)))
    }
    func testOldCellsDecodeAsGeometryNotMeasuredEvidenceAndNewAnnotationsRoundTrip() throws {
        let legacy = try JSONDecoder().decode(SurfaceCell.self, from: Data("{\"floor\":0,\"clearance\":3,\"blocked\":false}".utf8))
        XCTAssertNil(legacy.terrain); XCTAssertNil(legacy.floorUncertainty)
        let cell = SurfaceCell(floor: 0, clearance: 3, terrain: .step, floorUncertainty: 0.02)
        XCTAssertEqual(try JSONDecoder().decode(SurfaceCell.self, from: JSONEncoder().encode(cell)), cell)
    }
}
