import XCTest
@testable import BlindCore

final class SensorMeasurementTests: XCTestCase {
    func fragment(_ part: UInt8, time: UInt32 = 100, sequence: UInt8 = 1) -> Data {
        var bytes: [UInt8] = [2, 1, 2, part]
        for b in 0..<4 { bytes.append(UInt8(truncatingIfNeeded: time >> (b*8))) }
        bytes += [sequence, 16]
        for i in 0..<5 {
            let index = Int(part) * 5 + i
            let range: UInt16 = index < 16 ? UInt16(1000 + index) : .max
            bytes += [UInt8(truncatingIfNeeded: range), UInt8(range >> 8)]
        }
        return Data(bytes)
    }
    func testReassemblesOutOfOrderWithoutPartialOrDuplicateMeasurements() {
        var assembler = MeasurementAssembler()
        XCTAssertNil(assembler.accept(fragment(2), role: .belt, at: 1))
        XCTAssertNil(assembler.accept(fragment(2), role: .belt, at: 1.01))
        XCTAssertNil(assembler.accept(fragment(0), role: .belt, at: 1.02))
        XCTAssertNil(assembler.accept(fragment(3), role: .belt, at: 1.03))
        let sample = assembler.accept(fragment(1), role: .belt, at: 1.04)
        XCTAssertEqual(sample?.rangesMM, (1000..<1016).map(UInt16.init))
        XCTAssertTrue(sample?.isFresh(at: 1.2) ?? false)
        XCTAssertFalse(sample?.isFresh(at: 1.4) ?? true)
        XCTAssertNil(assembler.accept(fragment(0), role: .belt, at: 1.1))
    }
    func testLostFragmentsExpireAndDoNotCombineAcrossFrames() {
        var assembler = MeasurementAssembler()
        XCTAssertNil(assembler.accept(fragment(0), role: .belt, at: 1))
        for part: UInt8 in [1,2,3,0] { XCTAssertNil(assembler.accept(fragment(part), role: .belt, at: 2)) }
        for part: UInt8 in [0,1,2] { XCTAssertNil(assembler.accept(fragment(part, time: 200), role: .belt, at: 2.1)) }
        XCTAssertNotNil(assembler.accept(fragment(3, time: 200), role: .belt, at: 2.11))
    }
    func testRejectWrongRoleInvalidPaddingAndOldFrame() {
        var assembler = MeasurementAssembler()
        XCTAssertNil(assembler.accept(fragment(0), role: .wrist, at: 1))
        var invalid = fragment(3); invalid[19] = 0
        XCTAssertNil(assembler.accept(invalid, role: .belt, at: 1))
        for part: UInt8 in [0,1,2] { _ = assembler.accept(fragment(part, time: 300), role: .belt, at: 1) }
        XCTAssertNil(assembler.accept(fragment(3, time: 200), role: .belt, at: 1))
        XCTAssertNotNil(assembler.accept(fragment(3, time: 300), role: .belt, at: 1))
    }
    func testSharedSingleRangeGoldenBytes() {
        var assembler = MeasurementAssembler()
        let golden: [UInt8] = [2,2,0,0,4,3,2,1,7,1,232,3,255,255,255,255,255,255,255,255]
        let sample = assembler.accept(Data(golden), role: .wrist, at: 1)
        XCTAssertEqual(sample?.uptimeMS, 0x01020304)
        XCTAssertEqual(sample?.rangesMM, [1000])
    }
}
