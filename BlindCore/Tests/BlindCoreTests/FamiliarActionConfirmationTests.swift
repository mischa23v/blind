import XCTest
@testable import BlindCore

final class FamiliarActionConfirmationTests: XCTestCase {
    func testConfirmationIsOneShot() throws {
        var gate = FamiliarActionConfirmation()
        let token = try XCTUnwrap(gate.request(now: 10))
        XCTAssertTrue(gate.consume(token, now: 11))
        XCTAssertFalse(gate.consume(token, now: 11))
    }

    func testCancelInvalidatesRequest() throws {
        var gate = FamiliarActionConfirmation()
        let token = try XCTUnwrap(gate.request(now: 0))
        gate.cancel()
        gate.cancel()
        XCTAssertFalse(gate.consume(token, now: 0))
    }

    func testReplacedTokenCannotConfirmAndAttemptConsumesReplacement() throws {
        var gate = FamiliarActionConfirmation()
        let oldToken = try XCTUnwrap(gate.request(now: 10))
        let newToken = try XCTUnwrap(gate.request(now: 11))
        XCTAssertNotEqual(oldToken, newToken)
        XCTAssertFalse(gate.consume(oldToken, now: 12))
        XCTAssertFalse(gate.consume(newToken, now: 12))
        let latestToken = try XCTUnwrap(gate.request(now: 13))
        XCTAssertTrue(gate.consume(latestToken, now: 13))
    }

    func testWrongTokenConsumesPendingRequest() throws {
        var gate = FamiliarActionConfirmation()
        let token = try XCTUnwrap(gate.request(now: 0))
        XCTAssertFalse(gate.consume(UUID(), now: 1))
        XCTAssertFalse(gate.consume(token, now: 1))
    }

    func testExactThirtySecondBoundaryIsInclusive() throws {
        var gate = FamiliarActionConfirmation()
        let token = try XCTUnwrap(gate.request(now: 100))
        XCTAssertTrue(gate.consume(token, now: 130))
        let nextToken = try XCTUnwrap(gate.request(now: 100))
        XCTAssertFalse(gate.consume(nextToken, now: 130.000001))
        XCTAssertFalse(gate.consume(nextToken, now: 129))
    }

    func testTimeBeforeRequestFailsAndClears() throws {
        var gate = FamiliarActionConfirmation()
        let token = try XCTUnwrap(gate.request(now: 100))
        XCTAssertFalse(gate.consume(token, now: 99.999))
        XCTAssertFalse(gate.consume(token, now: 100))
    }

    func testInvalidRequestTimeClearsPreviousToken() throws {
        for time in [-1.0, Double.nan, Double.infinity, -Double.infinity] {
            var gate = FamiliarActionConfirmation()
            let token = try XCTUnwrap(gate.request(now: 0))
            XCTAssertNil(gate.request(now: time))
            XCTAssertFalse(gate.consume(token, now: 1))
        }
    }

    func testInvalidConsumeTimeClearsRequest() throws {
        for time in [-1.0, Double.nan, Double.infinity, -Double.infinity] {
            var gate = FamiliarActionConfirmation()
            let token = try XCTUnwrap(gate.request(now: 0))
            XCTAssertFalse(gate.consume(token, now: time))
            XCTAssertFalse(gate.consume(token, now: 1))
        }
    }

    func testConsumeWithoutPendingRequestFails() {
        var gate = FamiliarActionConfirmation()
        XCTAssertFalse(gate.consume(UUID(), now: 0))
    }
}
