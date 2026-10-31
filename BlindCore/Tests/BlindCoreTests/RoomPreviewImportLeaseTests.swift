import XCTest
import BlindCore

final class RoomPreviewImportLeaseTests: XCTestCase {
    func testRetiredImportCannotRepopulateAfterReactivation() throws {
        var lease = RoomPreviewImportLease()
        XCTAssertNil(lease.begin())
        lease.activate()
        let old = try XCTUnwrap(lease.begin())
        lease.retire()
        XCTAssertFalse(lease.finish(old))
        lease.activate()
        XCTAssertFalse(lease.finish(old))
    }
    func testReopenedPickerRejectsOldCallbackWithoutConsumingNew() throws {
        var lease = RoomPreviewImportLease(); lease.activate()
        let old = try XCTUnwrap(lease.begin()), current = try XCTUnwrap(lease.begin())
        XCTAssertNotEqual(old, current)
        XCTAssertFalse(lease.finish(old))
        XCTAssertTrue(lease.finish(current))
        XCTAssertFalse(lease.finish(current))
    }
    func testNormalPresentationCompletesExactlyOnce() throws {
        var lease = RoomPreviewImportLease(); lease.activate()
        let token = try XCTUnwrap(lease.begin())
        XCTAssertTrue(lease.finish(token))
        XCTAssertFalse(lease.finish(token))
        let next = try XCTUnwrap(lease.begin())
        XCTAssertTrue(lease.finish(next))
    }
}
