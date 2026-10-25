import XCTest
import GRDB
@testable import BlindMemory
final class RoomRegistrationStorageTests: XCTestCase {
 func testRegistrationReopenPreservesOriginalBytesAndProfile() throws {
  let directory=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
  defer { try? FileManager.default.removeItem(at:directory) }
  let path=directory.appendingPathComponent("acquisition.sqlite").path, room=UUID().uuidString
  let source=Data("authored original source/session/time; no current identity".utf8)
  let a=try MemoryStore(path:path,profile:"A");try a.saveRoomRegistration(room:room,payload:source)
  let reopened=try MemoryStore(path:path,profile:"A")
  XCTAssertEqual(try reopened.value(namespace:"places",id:"registration:"+room),source)
  let b=try MemoryStore(path:path,profile:"B");XCTAssertNil(try b.value(namespace:"places",id:"registration:"+room))
 }
 func testRoomPrivacyTombstonePreventsDelayedRegistrationResurrection() throws {
  let store=try MemoryStore(path:":memory:"),a="AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA",b=UUID().uuidString
  try store.saveRoomRegistration(room:a,payload:Data("A measurement".utf8))
  try store.saveRoomRegistration(room:b,payload:Data("B measurement".utf8))
  try store.deleteRoom(a)
  XCTAssertNil(try store.value(namespace:"places",id:"registration:"+a))
  XCTAssertThrowsError(try store.saveRoomRegistration(room:a,payload:Data("late A completion".utf8)))
  XCTAssertThrowsError(try store.saveRoomRegistration(room:a.lowercased(),payload:Data("alternate-case late A".utf8)))
  XCTAssertEqual(try store.value(namespace:"places",id:"registration:"+b),Data("B measurement".utf8))
 }
 func testBoundsFailurePreservesPreviousAcquisitionWhole() throws {
  let store=try MemoryStore(path:":memory:"),room=UUID().uuidString,original=Data("negation preserved whole".utf8)
  try store.saveRoomRegistration(room:room,payload:original)
  for count in [0,64001] { XCTAssertThrowsError(try store.saveRoomRegistration(room:room,payload:Data(repeating:1,count:count))) }
  XCTAssertThrowsError(try store.saveRoomRegistration(room:"not an ID",payload:original))
  XCTAssertEqual(try store.value(namespace:"places",id:"registration:"+room),original)
 }
}
