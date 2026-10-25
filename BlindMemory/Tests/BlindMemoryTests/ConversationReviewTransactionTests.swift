import XCTest
import GRDB
@testable import BlindMemory
final class ConversationReviewTransactionTests: XCTestCase {
 func testReviewCommitIsAtomicAcrossSecondWriteFailureAndReopen() throws {
  let directory=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
  defer { try? FileManager.default.removeItem(at:directory) }
  let path=directory.appendingPathComponent("review.sqlite").path
  let store=try MemoryStore(path:path,profile:"A")
  let oldDialogue=Data("old dialogue".utf8),oldState=Data("old state".utf8)
  try store.saveConversationReview(dialogue:oldDialogue,workingState:oldState)
  let sql=try DatabaseQueue(path:path)
  try sql.write { db in try db.execute(sql:"CREATE TRIGGER fail_review BEFORE UPDATE ON memoryValue WHEN NEW.namespace='companion' BEGIN SELECT RAISE(ABORT,'authored write fault'); END") }
  XCTAssertThrowsError(try store.saveConversationReview(dialogue:Data("new dialogue".utf8),workingState:Data("new state".utf8)))
  let reopened=try MemoryStore(path:path,profile:"A")
  XCTAssertEqual(try reopened.value(namespace:"dialogue",id:"active"),oldDialogue)
  XCTAssertEqual(try reopened.value(namespace:"companion",id:"working-state"),oldState)
  try sql.write { db in try db.execute(sql:"DROP TRIGGER fail_review") }
  try reopened.saveConversationReview(dialogue:Data("new dialogue".utf8),workingState:Data("new state".utf8))
  let after=try MemoryStore(path:path,profile:"A")
  XCTAssertEqual(try after.value(namespace:"dialogue",id:"active"),Data("new dialogue".utf8))
  XCTAssertEqual(try after.value(namespace:"companion",id:"working-state"),Data("new state".utf8))
  let other=try MemoryStore(path:path,profile:"B");XCTAssertNil(try other.value(namespace:"dialogue",id:"active"))
 }
 func testOversizeReviewRejectsBeforeEitherRowChanges() throws {
  let store=try MemoryStore(path:":memory:");let old=Data("old".utf8)
  try store.saveConversationReview(dialogue:old,workingState:old)
  XCTAssertThrowsError(try store.saveConversationReview(dialogue:Data("new".utf8),workingState:Data(repeating:0,count:8*1024*1024+1)))
  XCTAssertEqual(try store.value(namespace:"dialogue",id:"active"),old)
 }
 func testV5PreservesV4RowsAndExpandsOnlyExactConversationKeys() throws {
  let directory=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
  defer { try? FileManager.default.removeItem(at:directory) }
  let path=directory.appendingPathComponent("upgrade.sqlite").path
  let old=try DatabaseQueue(path:path);var migrator=DatabaseMigrator()
  for (name,resource) in [("assistant-memory-v1","schema"),("assistant-memory-v2-deletion","deletion"),("assistant-memory-v3-narration","narration"),("assistant-memory-v4-private-values","private_values")] {
   migrator.registerMigration(name) { db in try db.execute(sql:MemoryStore.sql(resource)) }
  }
  try migrator.migrate(old)
  try old.write { db in
   try db.execute(sql:"INSERT INTO memoryValue VALUES ('A','dialogue','active',?,123)",arguments:[Data("original".utf8)])
   try db.execute(sql:"INSERT INTO memoryValue VALUES ('B','preferences','keep',?,456)",arguments:[Data("other profile".utf8)])
  }
  let store=try MemoryStore(path:path,profile:"A")
  XCTAssertEqual(try store.value(namespace:"dialogue",id:"active"),Data("original".utf8))
  let other=try MemoryStore(path:path,profile:"B");XCTAssertEqual(try other.value(namespace:"preferences",id:"keep"),Data("other profile".utf8))
  let fullState=Data(repeating:42,count:4*1024*1024),fullDialogue=Data(repeating:42,count:128*1024)
  try store.saveConversationReview(dialogue:fullDialogue,workingState:fullState)
  let reopened=try MemoryStore(path:path,profile:"A")
  XCTAssertEqual(try reopened.value(namespace:"companion",id:"working-state"),fullState)
  XCTAssertEqual(try reopened.value(namespace:"dialogue",id:"active"),fullDialogue)
  for (namespace,id,count) in [("companion","working-state",8*1024*1024+1),("dialogue","active",128*1024+1),("companion","other",64001),("dialogue","other",64001)] {
   XCTAssertThrowsError(try old.write { db in try db.execute(sql:"INSERT OR REPLACE INTO memoryValue VALUES ('A',?,?,?,123)",arguments:[namespace,id,Data(repeating:0,count:count)]) })
  }
 }

}
