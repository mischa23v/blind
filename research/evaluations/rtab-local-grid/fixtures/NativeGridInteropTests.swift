import XCTest
import BridgeFixture
@testable import NativeRTABFixture
@testable import BlindCore
final class NativeGridInteropTests: XCTestCase {
    @MainActor func testRealSwiftCallbackCopiesBeforeCStorageExpiresAndCoalesces() async {
        let engine = RTABMap()
        var values: [NativeLocalGridPacket] = []
        engine.localGridReceived = { values.append($0) }
        engine.enableLocalGrid(generation: 7)
        emitBlindGridFixture(0, 1); emitBlindGridFixture(0, 2)
        for _ in 0..<100 where values.isEmpty { try? await Task.sleep(nanoseconds: 1_000_000) }
        XCTAssertEqual(values.count, 1); XCTAssertEqual(values.first?.eventRevision, 2)
        XCTAssertEqual(values.first?.ground.points.first?.x, 1)
        XCTAssertEqual(values.first?.generation, 7); XCTAssertEqual(engine.localGridDroppedPackets, 1)
        engine.disableLocalGrid()
    }
    @MainActor func testOversizedCCountRejectedBeforeReadingArray() async {
        let engine = RTABMap(); var result: NativeLocalGridPacket?
        engine.localGridReceived = { result = $0 }; engine.enableLocalGrid(generation: 8)
        emitBlindGridFixture(1, 1)
        for _ in 0..<100 where result == nil { try? await Task.sleep(nanoseconds: 1_000_000) }
        XCTAssertEqual(result?.status, .invalid); XCTAssertEqual(result?.ground.points.count, 0)
        engine.disableLocalGrid()
    }
    @MainActor func testDisabledCallbackCannotPublishPendingOldPacket() async {
        let engine = RTABMap(); var delivered = 0
        engine.localGridReceived = { _ in delivered += 1 }; engine.enableLocalGrid(generation: 9)
        emitBlindGridFixture(0, 1); engine.disableLocalGrid()
        try? await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertEqual(delivered, 0)
    }
    @MainActor func testReenableRetiresOldQueuedGenerationAndContext() async {
        let engine = RTABMap(); var delivered: [NativeLocalGridPacket] = []
        engine.localGridReceived = { delivered.append($0) }; engine.enableLocalGrid(generation: 10)
        emitBlindGridFixture(0, 1); engine.enableLocalGrid(generation: 11)
        try? await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertTrue(delivered.isEmpty)
        emitBlindGridFixture(0, 1)
        for _ in 0..<100 where delivered.isEmpty { try? await Task.sleep(nanoseconds: 1_000_000) }
        XCTAssertEqual(delivered.first?.generation, 11); engine.disableLocalGrid()
    }
    @MainActor func testDeinitDrainsCallbackAndPendingMailboxDoesNotRetainOwner() async {
        var engine: RTABMap? = RTABMap(); weak var weakEngine = engine; var delivered = 0
        engine?.localGridReceived = { _ in delivered += 1 }; engine?.enableLocalGrid(generation: 12)
        emitBlindGridFixture(0, 1); engine = nil
        XCTAssertNil(weakEngine)
        emitBlindGridFixture(0, 2)
        try? await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertEqual(delivered, 0)
    }

}
