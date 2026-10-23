import XCTest
@testable import BlindCore

/// Synthetic label-mask contract tests only: not Vision, camera, fabric, or held-item accuracy.
final class ClothingColorTargetTests: XCTestCase {
    private let width = 100, height = 100
    private func mask(_ boxes: [(Int, Int, Int, Int, UInt8)], stride: Int = 100) -> [UInt8] {
        var result = [UInt8](repeating: 0, count: stride * height)
        for (x0, y0, x1, y1, label) in boxes {
            for y in y0..<y1 { for x in x0..<x1 { result[y * stride + x] = label } }
        }
        return result
    }
    private func select(_ labels: [UInt8], stride: Int = 100, valid: Set<Int> = [1, 2],
                        people: [ClothingColorTarget.Region] = []) -> ClothingColorTarget.Decision {
        ClothingColorTarget.select(labels: labels, maskWidth: width, maskHeight: height, bytesPerRow: stride,
            validInstances: valid, imageWidth: 100, imageHeight: 100, people: people)
    }
    func testSingleOffCentreItemUsesItsOwnInteriorNotImageCentre() throws {
        let labels = mask([(5, 10, 45, 90, 1)])
        guard case .anonymous(let selected) = select(labels) else { return XCTFail("off-centre item not sampled") }
        XCTAssertEqual(selected.instance, 1)
        XCTAssertEqual(selected.bounds, .init(x: 0.05, y: 0.1, width: 0.4, height: 0.8))
        XCTAssertGreaterThanOrEqual(selected.samplePixels.count, 64)
        XCTAssertTrue(selected.samplePixels.allSatisfy { $0.x < 45 && labels[$0.y * width + $0.x] == 1 })
        XCTAssertFalse(selected.samplePixels.contains { $0.x == 50 && $0.y == 50 })
    }
    func testTwoItemsNeverSelectCentreOrLargestAsTheReferent() {
        XCTAssertEqual(select(mask([(5, 20, 40, 80, 1), (45, 5, 99, 95, 2)])), .unresolved(.multipleForegroundItems))
        XCTAssertEqual(select(mask([(2, 2, 4, 4, 1), (10, 10, 90, 90, 2)])), .unresolved(.multipleForegroundItems))
    }
    func testCentralBackgroundWithNoForegroundAbstains() {
        XCTAssertEqual(select(mask([])), .unresolved(.noForeground))
    }
    func testPersonOverlapAwayFromImageCentreStillAbstains() {
        let labels = mask([(5, 10, 45, 90, 1)])
        let person = ClothingColorTarget.Region(x: 0, y: 0, width: 0.2, height: 1)
        XCTAssertEqual(select(labels, people: [person]), .unresolved(.personOverlap))
    }
    func testNonoverlappingPersonDoesNotSelectOrContaminateObject() {
        let labels = mask([(5, 10, 45, 90, 1)])
        let person = ClothingColorTarget.Region(x: 0.6, y: 0, width: 0.3, height: 1)
        guard case .anonymous = select(labels, people: [person]) else { return XCTFail("separate person was treated as target") }
    }
    func testTopLeftPersonCoordinatesDoNotMirrorToBottom() {
        let labels = mask([(10, 5, 90, 40, 1)])
        XCTAssertEqual(select(labels, people: [.init(x: 0.2, y: 0, width: 0.5, height: 0.2)]), .unresolved(.personOverlap))
        guard case .anonymous = select(labels, people: [.init(x: 0.2, y: 0.8, width: 0.5, height: 0.2)]) else {
            return XCTFail("vertical coordinate convention was mirrored")
        }
    }
    func testPaddedRowsAreNotExtraForegroundInstances() {
        var labels = mask([(10, 10, 90, 90, 1)], stride: 104)
        for y in 0..<height { for x in 100..<104 { labels[y * 104 + x] = 255 } }
        guard case .anonymous = select(labels, stride: 104) else { return XCTFail("row padding treated as pixels") }
    }
    func testUndeclaredInstanceOrMalformedMaskAbstains() {
        XCTAssertEqual(select(mask([(10, 10, 90, 90, 3)])), .unresolved(.invalidMask))
        XCTAssertEqual(select([0]), .unresolved(.invalidMask))
        XCTAssertEqual(select(mask([(10, 10, 90, 90, 1)]), valid: [0, 1]), .unresolved(.invalidMask))
        XCTAssertEqual(ClothingColorTarget.select(labels: [], maskWidth: Int.max, maskHeight: 100,
            bytesPerRow: Int.max, validInstances: [], imageWidth: 100, imageHeight: 100, people: []), .unresolved(.invalidMask))
    }
    func testTinyForegroundCannotPassMinimumInteriorSamples() {
        XCTAssertEqual(select(mask([(45, 45, 55, 55, 1)])), .unresolved(.insufficientInterior))
    }
    func testMaskHoleAtTargetInteriorNeverBecomesBackgroundColor() {
        var labels = mask([(10, 10, 90, 90, 1)])
        for y in 30..<70 { for x in 30..<70 { labels[y * width + x] = 0 } }
        XCTAssertEqual(select(labels), .unresolved(.insufficientInterior))
    }
    func testMalformedPersonRegionDoesNotSilentlyBypassRejection() {
        for person in [ClothingColorTarget.Region(x: .nan, y: 0, width: 0.5, height: 0.5),
                       .init(x: 0.9, y: 0, width: 0.2, height: 1),
                       .init(x: 0, y: 0, width: -0.2, height: 1)] {
            XCTAssertEqual(select(mask([(10, 10, 90, 90, 1)]), people: [person]), .unresolved(.personOverlap))
        }
    }
    func testSelectedPixelsNeverCrossMaskEdgeEvenAtFrameEdge() {
        let labels = mask([(0, 0, 100, 100, 1)])
        guard case .anonymous(let selected) = select(labels) else { return XCTFail("single full item failed") }
        XCTAssertTrue(selected.samplePixels.allSatisfy { $0.x >= 2 && $0.x < 98 && $0.y >= 2 && $0.y < 98 })
    }
    func testTypedFailuresDoNotInventAnObjectOrDemandManualPositioning() {
        let reasons: [ClothingColorTarget.Unresolved] = [.invalidMask, .noForeground, .multipleForegroundItems, .personOverlap, .insufficientInterior]
        for reason in reasons {
            let english = reason.speech(arabic: false)
            XCTAssertFalse(english.isEmpty)
            XCTAssertFalse(reason.speech(arabic: true).isEmpty)
            for unsupported in ["Hold", "Move", "centre", "fabric", "pot", "outfit", "safe", "hot"] {
                XCTAssertFalse(english.contains(unsupported), "\(reason): \(unsupported)")
            }
        }
        XCTAssertTrue(ClothingColorTarget.Unresolved.multipleForegroundItems.speech(arabic: false).contains("haven't established"))
        XCTAssertFalse(ClothingColorTarget.Unresolved.noForeground.speech(arabic: false).contains("no item"))
    }

}
