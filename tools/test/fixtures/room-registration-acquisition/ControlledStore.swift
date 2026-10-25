// Authored delay/failure seam around the actual GRDB MemoryStore, not a second store.
import Foundation
import BlindMemory
final class MemoryStore: @unchecked Sendable {
 let real: BlindMemory.MemoryStore
 var writeOwner: UUID { real.writeOwner }
 let started=DispatchSemaphore(value:0),release=DispatchSemaphore(value:0)
 private let lock=NSLock()
 private var blockedRead=false,blockedWrite=false,failWrite=false
 init(path:String) throws { real=try BlindMemory.MemoryStore(path:path) }
 func holdRead() { lock.lock();blockedRead=true;lock.unlock() }
 func holdWrite(fail:Bool) { lock.lock();blockedWrite=true;failWrite=fail;lock.unlock() }
 func value(namespace:String,id:String) throws -> Data? {
  lock.lock();let hold=blockedRead;blockedRead=false;lock.unlock()
  if hold { started.signal();guard release.wait(timeout:.now()+5) == .success else { throw CocoaError(.fileReadUnknown) } }
  return try real.value(namespace:namespace,id:id)
 }
 func saveRoomRegistration(room:String,payload:Data) throws {
  lock.lock();let hold=blockedWrite,fail=failWrite;blockedWrite=false;failWrite=false;lock.unlock()
  if hold { started.signal();guard release.wait(timeout:.now()+5) == .success else { throw CocoaError(.fileWriteUnknown) } }
  if fail { throw CocoaError(.fileWriteUnknown) }
  try real.saveRoomRegistration(room:room,payload:payload)
 }
 var failDelete = false
 func deleteRoom(_ room:String) throws { if failDelete { throw CocoaError(.fileWriteUnknown) }; try real.deleteRoom(room) }
}

// Authored held-decode seam delegates all decoding to Foundation unchanged.
// This proves dispatch/owner behavior, not Apple CapturedRoom SDK decoding cost.
final class JSONDecoder {
 static let lock = NSLock(), started = DispatchSemaphore(value:0), release = DispatchSemaphore(value:0)
 static var held = false, decodedOnMain = false, count = 0
 static func hold() { lock.lock(); held=true; count=0; decodedOnMain=false; lock.unlock() }
 func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
  if type == CapturedRoom.self {
   Self.lock.lock();let hold=Self.held;Self.held=false;Self.count += 1;Self.decodedOnMain = Thread.isMainThread;Self.lock.unlock()
   if hold { Self.started.signal();guard Self.release.wait(timeout:.now()+5) == .success else { throw CocoaError(.fileReadUnknown) } }
  }
  return try Foundation.JSONDecoder().decode(type,from:data)
 }
}
