import XCTest
@testable import BlindCore

final class WorkRevisionTests: XCTestCase {
    func testQueuedItemWriteCannotResurrectDeletedRecord() {
        var revisions = WorkRevision()
        let queued = revisions.token(for: "cup")
        XCTAssertTrue(revisions.accepts(queued))
        revisions.invalidate("cup")
        XCTAssertFalse(revisions.accepts(queued))
    }
    func testRoomDeletionDoesNotCancelOtherRoomWrites() {
        var revisions = WorkRevision()
        let deleted = revisions.token(for: "bedroom"), other = revisions.token(for: "kitchen")
        revisions.invalidate("bedroom")
        XCTAssertFalse(revisions.accepts(deleted))
        XCTAssertTrue(revisions.accepts(other))
    }
    func testNewExplicitEnrollmentWorksButOldCompletionDoesNot() {
        var revisions = WorkRevision()
        let old = revisions.token(for: "cup")
        revisions.invalidate("cup")
        let new = revisions.token(for: "cup")
        XCTAssertTrue(revisions.accepts(new))
        XCTAssertFalse(revisions.accepts(old))
        revisions.invalidate("cup")
        XCTAssertFalse(revisions.accepts(new))
    }
    func testSessionEndInvalidatesAllQueuedWorkIncludingDeletedKeys() {
        var revisions = WorkRevision()
        revisions.invalidate("bedroom")
        let room = revisions.token(for: "bedroom"), item = revisions.token(for: "cup")
        revisions.invalidateAll()
        XCTAssertFalse(revisions.accepts(room))
        XCTAssertFalse(revisions.accepts(item))
        XCTAssertTrue(revisions.accepts(revisions.token(for: "bedroom")))
        XCTAssertTrue(revisions.accepts(revisions.token(for: "cup")))
    }
}
