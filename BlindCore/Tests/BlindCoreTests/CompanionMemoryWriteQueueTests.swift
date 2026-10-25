import XCTest
@testable import BlindCore
final class CompanionMemoryWriteQueueTests: XCTestCase {
 final class Backend: @unchecked Sendable {
  let lock = NSLock(), started = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
  private var block = false, failing = false
  private var saved: [String] = []
  func configure(block: Bool = false, failing: Bool = false) { lock.lock(); self.block=block; self.failing=failing; lock.unlock() }
  func values() -> [String] { lock.lock(); defer { lock.unlock() }; return saved }
  func write(_ snapshot: CompanionMemoryWriteQueue.Snapshot) throws {
   lock.lock(); let blocked=block, failed=failing; block=false; lock.unlock()
   if blocked { started.signal(); guard release.wait(timeout: .now() + 5) == .success else { throw CocoaError(.fileWriteUnknown) } }
   if failed { throw CocoaError(.fileWriteUnknown) }
   lock.lock(); saved.append(String(decoding:snapshot.workingState,as:UTF8.self)); lock.unlock()
  }
 }
 @MainActor func enqueue(_ value: String, into queue: CompanionMemoryWriteQueue, owner: UUID, backend: Backend) -> CompanionMemoryWriteQueue.Receipt {
  queue.submit(owner:owner,encode:{ .init(dialogue:Data(value.utf8),workingState:Data(value.utf8)) },write:backend.write)!
 }
 @MainActor func testSlowWriterDoesNotBlockOwnerAndCoalescesToOneLatestSnapshot() async {
  let q=CompanionMemoryWriteQueue(), owner=UUID(), backend=Backend();backend.configure(block:true)
  _=enqueue("before",into:q,owner:owner,backend:backend)
  await Task.detached { backend.started.wait() }.value
  var last: CompanionMemoryWriteQueue.Receipt!
  for index in 1...100 { last=enqueue("retired source + new report \(index)",into:q,owner:owner,backend:backend);XCTAssertEqual(q.pendingCount,1) }
  // This MainActor code runs while the actual background backend is blocked.
  XCTAssertTrue(q.isWriting);XCTAssertTrue(backend.values().isEmpty)
  backend.release.signal();let saved=await q.waitForCommit(last);XCTAssertTrue(saved)
  XCTAssertEqual(backend.values(),["before","retired source + new report 100"])
 }
 @MainActor func testFailedCommitIsExplicitAndRetryUsesLatestRetiredSnapshot() async {
  let q=CompanionMemoryWriteQueue(),owner=UUID(),backend=Backend();backend.configure(failing:true)
  let first=enqueue("source removed",into:q,owner:owner,backend:backend)
  let failed=await q.waitForCommit(first);XCTAssertFalse(failed);XCTAssertTrue(q.hasFailed);XCTAssertTrue(backend.values().isEmpty)
  let latest=enqueue("source removed + new report",into:q,owner:owner,backend:backend)
  let second=await q.waitForCommit(latest);XCTAssertFalse(second)
  backend.configure();let retry=q.retryLatest(owner:owner)!;let saved=await q.waitForCommit(retry);XCTAssertTrue(saved)
  XCTAssertEqual(backend.values(),["source removed + new report"])
 }
 @MainActor func testStoreReplacementCannotPublishOrRetryOldOwnerIntoNewStore() async {
  let q=CompanionMemoryWriteQueue(),a=UUID(),b=UUID(),old=Backend(),new=Backend();old.configure(block:true)
  var callbacks:[UUID]=[];q.onCompletion={ receipt,_ in callbacks.append(receipt.owner) }
  let receipt=enqueue("old private context",into:q,owner:a,backend:old)
  await Task.detached { old.started.wait() }.value
  q.bindOwner(b);XCTAssertNil(q.retryLatest(owner:a));let retired=await q.waitForCommit(receipt);XCTAssertFalse(retired)
  let latest=enqueue("new store",into:q,owner:b,backend:new);old.release.signal()
  let saved=await q.waitForCommit(latest);XCTAssertTrue(saved);XCTAssertEqual(new.values(),["new store"]);XCTAssertEqual(callbacks,[b])
 }
 @MainActor func testBulkClearAfterBlockedWriteIsLastDurableSnapshot() async {
  let q=CompanionMemoryWriteQueue(),owner=UUID(),backend=Backend();backend.configure(block:true)
  _=enqueue("old source",into:q,owner:owner,backend:backend);await Task.detached { backend.started.wait() }.value
  _=enqueue("source correction",into:q,owner:owner,backend:backend)
  let clear=enqueue("empty dialogue and task state",into:q,owner:owner,backend:backend);backend.release.signal()
  let saved=await q.waitForCommit(clear);XCTAssertTrue(saved);XCTAssertEqual(backend.values().last,"empty dialogue and task state")
 }
 @MainActor func testEncodedBoundsRejectBeforeBackend() async {
  let q=CompanionMemoryWriteQueue(),owner=UUID(),backend=Backend()
  let receipt=q.submit(owner:owner,encode:{ .init(dialogue:Data([1]),workingState:Data(repeating:0,count:8*1024*1024+1)) },write:backend.write)!
  let saved=await q.waitForCommit(receipt);XCTAssertFalse(saved);XCTAssertTrue(backend.values().isEmpty)
 }
 @MainActor func testOneSynchronousTurnCommitsOnlyFinalCoherentPair() async {
  let q=CompanionMemoryWriteQueue(),owner=UUID(),backend=Backend()
  _=enqueue("new dialogue, old state",into:q,owner:owner,backend:backend)
  let final=enqueue("new dialogue, new state",into:q,owner:owner,backend:backend)
  let saved=await q.waitForCommit(final);XCTAssertTrue(saved);XCTAssertEqual(backend.values(),["new dialogue, new state"])
 }

}
