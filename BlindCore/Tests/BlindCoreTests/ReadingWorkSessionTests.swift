import XCTest
@testable import BlindCore

final class ReadingWorkSessionTests: XCTestCase {
    func testSameToolRestartRejectsOldCompletion() {
        var work = ReadingWorkSession()
        let old = work.begin()
        XCTAssertTrue(work.accepts(old, capturedAt: 1, now: 1.1))
        work.cancel()
        let fresh = work.begin()
        XCTAssertFalse(work.owns(old))
        XCTAssertTrue(work.accepts(fresh, capturedAt: 2, now: 2.1))
    }
    func testStopNewGoalAndBackgroundCannotAdmitPageResult() {
        for _ in 0..<3 {
            var work = ReadingWorkSession()
            let capture = work.begin()
            work.cancel()
            XCTAssertFalse(work.accepts(capture, capturedAt: 1, now: 1.1))
        }
    }
    func testFreshnessRejectsFutureNonfiniteAndExpiredFrames() {
        var work = ReadingWorkSession(); let token = work.begin()
        for (capture, now) in [(2.0, 1.0), (1, 1.5), (Double.nan, 1), (1, Double.infinity)] {
            XCTAssertFalse(work.accepts(token, capturedAt: capture, now: now))
        }
        XCTAssertTrue(work.accepts(token, capturedAt: 1, now: 1.49))
    }
    func testFramingRequiresSamePolygonNotThreeUnrelatedPages() {
        var state = DocumentStability()
        let left = [(x: 0.1, y: 0.1), (x: 0.6, y: 0.1), (x: 0.6, y: 0.8), (x: 0.1, y: 0.8)]
        let right = left.map { (x: $0.x + 0.2, y: $0.y) }
        XCTAssertFalse(state.observe(left)); XCTAssertFalse(state.observe(right)); XCTAssertFalse(state.observe(left))
        XCTAssertFalse(state.observe(left)); XCTAssertTrue(state.observe(left))
        XCTAssertFalse(state.observe(nil)); XCTAssertFalse(state.observe(left))
    }
    func testLiveReaderDoesNotMarkUnspokenOverflowAsRead() {
        var reader = LiveTextReader()
        let lines = (0..<5).map { TextLine(text: "line \($0)", confidence: 0.9, x: 0.5, y: Double($0) / 5) }
        XCTAssertEqual(reader.newLines(lines, now: 1), ["line 0", "line 1", "line 2"])
        XCTAssertEqual(reader.newLines(lines, now: 2), ["line 3", "line 4"])
        XCTAssertEqual(reader.newLines(lines, now: 3), [])
    }

    func testInvalidPolygonCannotBeReady() {
        var state = DocumentStability()
        let malformed = [(x: Double.nan, y: 0.1), (x: 0.6, y: 0.1), (x: 0.6, y: 0.8), (x: 0.1, y: 0.8)]
        for _ in 0..<4 { XCTAssertFalse(state.observe(malformed)) }
    }
}
