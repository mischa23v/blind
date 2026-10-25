import XCTest
@testable import BlindCore
final class TerrainFootingRegressionTests: XCTestCase {
    func surface(before: Double, after: Double) -> NavigationSurface {
        var cells = Array(repeating: SurfaceCell(floor: before, clearance: 3), count: 10000)
        for z in 50..<100 { for x in 0..<100 { cells[z * 100 + x].floor = after } }
        return .init(level: "synthetic", origin: .init(0,0,0), resolution: 0.1, width: 100, depth: 100, cells: cells)
    }
    func testEightCentimetreRiseRejects() {
        XCTAssertFalse(surface(before: 0, after: 0.08).permitsLeg(from: .init(5,0,3), to: .init(5,0.08,7)))
    }
    func testEightCentimetreDropRejects() {
        XCTAssertFalse(surface(before: 0, after: -0.08).permitsLeg(from: .init(5,0,3), to: .init(5,-0.08,7)))
    }
    func testSixteenCentimetreAdjacentDifferenceRejects() {
        XCTAssertFalse(surface(before: -0.08, after: 0.08).permitsLeg(from: .init(5,0,3), to: .init(5,0,7)))
    }
    func testFlatStoredGeometryRemainsUsableWithoutPhysicalClaim() {
        XCTAssertTrue(surface(before: 0, after: 0).permitsLeg(from: .init(5,0,3), to: .init(5,0,7)))
    }
}
