// Authored mixed-store compatibility scenario, not current identity, pose or device accuracy.
// Executes the complete native findWithSensors body and real Core item/observation storage models.
import XCTest
import BlindCore
@testable import NativeLookupReplay
final class MixedStoreHistoryTests: XCTestCase {
 func testUnknownWorkingStateDoesNotSelectScopedSavedRowButRetainsLegacyCategoryHistory() throws {
  let c = ExtractedAfterFullItemRecall()
  let scope = CompanionMemoryScope(map: .init(mapID: "A", frameID: "frame-A", revision: "1"),
    placeID: "private-house-A", floorID: "floor-A", roomID: "kitchen-A", objectInstanceID: "personal-cup-A")!
  let now = Date(), originalObservationTime = now.addingTimeInterval(-3600)
  let saved = try XCTUnwrap(c.items.remember(name: "my cup", roomName: "Private A pantry",
    position: Point3(3, 0, 0), frameID: "frame-A", at: now, scope: scope))
  let sighting = try XCTUnwrap(c.observedObjects.observe(category: "cup", source: .roomPlanScan,
    frameID: "legacy-frame", roomName: "Older shared kitchen", at: originalObservationTime, now: now))
  XCTAssertNil(c.companionWorkingState.memoryScope)
  XCTAssertFalse(c.companionWorkingState.hasScopedMemoryHistory)
  XCTAssertNil(c.companionWorkingState.currentContextItem("cup", in: c.items))
  XCTAssertNil(c.recordedSpotRecallContext()); XCTAssertNil(c.lastObservation)
  XCTAssertFalse(c.indoor.isAligned); XCTAssertNil(c.session.currentFrame)
  let revision = c.companionWorkingState.goalRevision
  let recall = c.observedObjects.recall(category: "cup", at: now, context: nil)
  let expected = ObservedObjectMemory.answer(for: recall, asked: "cup", now: now, arabic: false)
  XCTAssertTrue(c.run("Where is my cup"))
  XCTAssertEqual(c.outputs, [expected])
  let reply = try XCTUnwrap(c.outputs.first)
  XCTAssertTrue(reply.contains("The room scan recorded a cup"))
  XCTAssertTrue(reply.contains("Older shared kitchen")); XCTAssertTrue(reply.contains("1 hour ago"))
  XCTAssertTrue(reply.contains("Its current location is unconfirmed."))
  XCTAssertFalse(reply.contains("Private A pantry")); XCTAssertFalse(reply.contains("Your cup was saved"))
  for forbidden in ["Measured", "Earlier recorded spot", "ahead", "behind", "metres", "reach", "pick up", "completed"] {
   XCTAssertFalse(reply.contains(forbidden), forbidden)
  }
  XCTAssertEqual(c.items.items, [saved]); XCTAssertEqual(c.observedObjects.sightings.first?.id, sighting.id)
  XCTAssertEqual(c.observedObjects.sightings.first?.observedAt, originalObservationTime)
  XCTAssertEqual(c.companionWorkingState.goalRevision, revision)
  XCTAssertTrue(c.companionWorkingState.goal.isEmpty); XCTAssertTrue(c.companionWorkingState.reportedCompletedSteps.isEmpty)
  XCTAssertEqual(c.appearanceCalls, 0); XCTAssertNil(c.recordedSpotSpeech); XCTAssertNil(c.objectSearch)
 }
}
