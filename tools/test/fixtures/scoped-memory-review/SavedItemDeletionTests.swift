// Authored saved-item ownership regressions, separate from scoped conversation report review.
// The native release-path action body and public ItemMemory execute; storage/perception are stubs.
import XCTest
import BlindCore
@testable import NativeReviewReplay
final class SavedItemDeletionTests: XCTestCase {
 func scope(_ id: String) -> CompanionMemoryScope {
  CompanionMemoryScope(map: SpatialMapBinding(mapID: "map-"+id, frameID: "frame", revision: "1"), placeID: "house-"+id, floorID: "floor", roomID: "kitchen", objectInstanceID: "cup-"+id)!
 }
 @MainActor func testSI024DuplicateNameDeletesOnlySelectedRecordAndPersistsOtherScope() async throws {
  let c = ExtractedSavedItemDeletionController()
  let a = try XCTUnwrap(c.items.remember(name: "my cup", at: Date(timeIntervalSince1970: 10), scope: scope("A")))
  let b = try XCTUnwrap(c.items.remember(name: "my cup", at: Date(timeIntervalSince1970: 20), scope: scope("B")))
  XCTAssertEqual(a.key, b.key); XCTAssertNotEqual(a.id, b.id)
  let deleted = c.deleteAfterPurge(a)
  print("SI-024 authored duplicate-name witness: returned=\(deleted); A remains=\(c.items.items.contains(a)); B remains=\(c.items.items.contains(b))")
  XCTAssertTrue(deleted)
  XCTAssertFalse(c.items.items.contains(a), "A reported successful deletion must remove the exact selected record.")
  XCTAssertEqual(c.items.items, [b], "A same-name record owned by B must survive unchanged.")
  let store = try XCTUnwrap(c.places.memory)
  XCTAssertEqual(store.writes, 1)
  let reopened = try JSONDecoder().decode(ItemMemory.self, from: XCTUnwrap(store.payload))
  XCTAssertEqual(reopened.items, [b], "The persisted item list must match the exact selected-ID deletion.")
  XCTAssertEqual(c.itemAppearance.forgotten, [a.key]); XCTAssertEqual(c.removedHistory, [a.name])
 }
 @MainActor func testSI025StalePostPurgeSelectionRejectsBeforeMutationOrWrite() async throws {
  let c = ExtractedSavedItemDeletionController()
  let stale = try XCTUnwrap(c.items.remember(name: "my cup", at: Date(timeIntervalSince1970: 10), scope: scope("A")))
  let current = try XCTUnwrap(c.items.remember(name: "my cup", at: Date(timeIntervalSince1970: 30), scope: scope("A")))
  XCTAssertEqual(stale.id, current.id); XCTAssertNotEqual(stale, current)
  let before = c.items, revision = c.itemMemoryRevision
  c.learningItem = current
  XCTAssertFalse(c.deleteAfterPurge(stale))
  XCTAssertEqual(c.items, before); XCTAssertEqual(c.itemMemoryRevision, revision); XCTAssertEqual(c.learningItem, current)
  XCTAssertEqual(c.invalidations, 0); XCTAssertEqual(c.cancellations, 0); XCTAssertEqual(c.diagnosticPurges, 0)
  XCTAssertTrue(c.itemAppearance.forgotten.isEmpty); XCTAssertTrue(c.removedHistory.isEmpty)
  XCTAssertEqual(c.places.memory?.writes, 0); XCTAssertEqual(c.objectWillChange.count, 0); XCTAssertTrue(c.spoken.isEmpty)
 }
 @MainActor func testSI026StaleOuterSelectionRejectsBeforeNativePurgeAndSearchRetirement() async throws {
  let c = ExtractedSavedItemDeletionController()
  let stale = try XCTUnwrap(c.items.remember(name: "my cup", at: Date(timeIntervalSince1970: 10), scope: scope("A")))
  let current = try XCTUnwrap(c.items.remember(name: "my cup", at: Date(timeIntervalSince1970: 30), scope: scope("A")))
  let before = c.items, revision = c.itemMemoryRevision
  c.learningItem = current
  var completions: [Bool] = []
  c.forgetItem(stale) { completions.append($0) }
  XCTAssertEqual(completions, [false])
  XCTAssertEqual(c.items, before); XCTAssertEqual(c.itemMemoryRevision, revision); XCTAssertEqual(c.learningItem, current)
  XCTAssertEqual(c.retirements, 0); XCTAssertEqual(c.nativeObservations.purges, 0)
  XCTAssertEqual(c.invalidations, 0); XCTAssertEqual(c.cancellations, 0); XCTAssertEqual(c.diagnosticPurges, 0)
  XCTAssertTrue(c.itemAppearance.forgotten.isEmpty); XCTAssertTrue(c.removedHistory.isEmpty)
  XCTAssertEqual(c.places.memory?.writes, 0); XCTAssertEqual(c.objectWillChange.count, 0); XCTAssertTrue(c.spoken.isEmpty)
 }
}
