import XCTest
import BlindCore
@testable import NativeReviewReplay
final class ScopedReviewTests: XCTestCase {
 func scope(_ id: String) -> CompanionMemoryScope {
  CompanionMemoryScope(map: SpatialMapBinding(mapID: "map-"+id, frameID: "frame", revision: "1"), placeID: "house-"+id, floorID: "floor", roomID: "kitchen", objectInstanceID: "fridge-"+id)!
 }
 func report(_ text: String, into state: inout CompanionWorkingState, time: TimeInterval) -> CompanionWorkingState.ReviewSelection {
  state.record(text, at: Date(timeIntervalSince1970: time))
  if let parsed = CompanionUtterance.parse(text) { _ = state.respond(to: parsed, message: text, now: Date(timeIntervalSince1970: time), arabic: false, sourceID: state.reports.last?.sourceID) }
  return state.reviewSelections.first { $0.sourceID == state.reports.last?.sourceID }!
 }
 func testSR001ArchivedCorrectionRetainsOriginalScopeAndCurrentProgress() throws {
  var s=CompanionWorkingState();s.transitionMemoryScope(scope("A"));_ = report("My milk is in the fridge", into: &s, time: 10)
  s.transitionMemoryScope(scope("B"));_ = report("My milk is in the fridge", into: &s, time: 20)
  s.changeGoal("Make breakfast");s.reportedCompletedSteps=["B step"];s.proposedStep="B proposal"
  let a=s.reviewSelections.first { $0.scope == scope("A") }!; let revision=s.goalRevision
  XCTAssertTrue(s.reviseReviewedSource(a,replacement:"My milk is on the table",at:Date(timeIntervalSince1970:30)))
  XCTAssertEqual(s.goalRevision,revision);XCTAssertEqual(s.reportedCompletedSteps,["B step"]);XCTAssertEqual(s.proposedStep,"B proposal")
  XCTAssertEqual(s.factBook.latest(for:"milk",in:scope("B"))?.place,"in the fridge")
  XCTAssertEqual(s.factBook.latest(for:"milk",in:scope("A"))?.place,"on the table")
  XCTAssertFalse(s.reviewSelections.contains { $0.sourceID == a.sourceID })
  let corrected=s.reviewSelections.first { $0.scope == scope("A") }!;XCTAssertEqual(corrected.report.correctionOrigin?.sourceID,a.sourceID);XCTAssertEqual(corrected.report.correctionOrigin?.reportedAt,a.report.time)
  print("SR-001 authored fixture: same words in A/B; correcting selected A keeps B progress and original A scope.")
 }
 func testSR002StaleSelectionAndRestartRejectBeforeMutation() throws {
  var s=CompanionWorkingState();s.transitionMemoryScope(scope("A"));let old=report("My milk is in the fridge",into:&s,time:10)
  s.transitionMemoryScope(scope("B"));let bytes=try JSONEncoder().encode(s)
  XCTAssertFalse(s.reviseReviewedSource(old,replacement:"My milk is on the table"));XCTAssertEqual(try JSONEncoder().encode(s).count,bytes.count)
  let current=s.reviewSelections.first!;var restarted=try JSONDecoder().decode(CompanionWorkingState.self,from:bytes)
  XCTAssertFalse(restarted.reviseReviewedSource(current,replacement:nil));XCTAssertTrue(restarted.reviseReviewedSource(restarted.reviewSelections.first!,replacement:nil))
 }
 func testSR003InvalidEditIsAtomicAndReplayedReceiptFails() throws {
  var s=CompanionWorkingState();s.transitionMemoryScope(scope("A"));let a=report("My milk is in the fridge",into:&s,time:10)
  XCTAssertFalse(s.reviseReviewedSource(a,replacement:"  "));XCTAssertTrue(s.acceptsReviewSelection(a))
  XCTAssertTrue(s.reviseReviewedSource(a,replacement:nil));XCTAssertFalse(s.reviseReviewedSource(a,replacement:nil))
 }
 @MainActor func testSR004ControllerDeletionCancelsOnlyConversationAndSameTextBRemains() async {
  let c=ExtractedScopedReviewController();c.companionWorkingState.transitionMemoryScope(scope("A"));let a=report("My milk is in the fridge",into:&c.companionWorkingState,time:10)
  c.assistantDialogue.record(role:"user",text:a.report.text,sourceID:a.sourceID)
  c.companionWorkingState.transitionMemoryScope(scope("B"));let b=report("My milk is in the fridge",into:&c.companionWorkingState,time:20)
  c.assistantDialogue.record(role:"user",text:b.report.text,sourceID:b.sourceID)
  let currentA=c.scopedConversationReviews.first { $0.sourceID == a.sourceID }!
  c.questionIsChat=true;c.busy=true;let task=Task<Void,Never> { try? await Task.sleep(nanoseconds:1_000_000_000) };c.questionTask=task
  c.conversationSpeech=[.init()];c.activeConversationSpeech = .init();let request=c.requestID;let memoryRevision=c.testMemoryRevision
  let reviewResult0 = await c.reviseScopedConversationRecord(currentA,replacement:nil); XCTAssertTrue(reviewResult0);XCTAssertTrue(task.isCancelled);XCTAssertFalse(c.busy);XCTAssertNil(c.questionTask)
  XCTAssertTrue(c.conversationSpeech.isEmpty);XCTAssertEqual(c.feedback.stopped.count,1);XCTAssertEqual(c.requestID,request);XCTAssertNotEqual(c.testMemoryRevision,memoryRevision)
  XCTAssertEqual(c.searchRetirements,0);XCTAssertEqual(c.journeyRetirements,0);XCTAssertEqual(c.assistantDialogue.userRecords.map(\.sourceID),[b.sourceID])
 }
 @MainActor func testSR005StaleControllerSelectionHasNoSideEffects() async {
  let c=ExtractedScopedReviewController();c.companionWorkingState.transitionMemoryScope(scope("A"));let a=report("My milk is in the fridge",into:&c.companionWorkingState,time:10)
  c.companionWorkingState.transitionMemoryScope(scope("B"));c.busy=true;c.questionIsChat=true;let token=c.testMemoryRevision
  let reviewResult0 = await c.reviseScopedConversationRecord(a,replacement:nil); XCTAssertFalse(reviewResult0);XCTAssertTrue(c.busy);XCTAssertEqual(c.persisted,0);XCTAssertEqual(c.privacyPurges,0);XCTAssertEqual(c.testMemoryRevision,token)
 }
 @MainActor func testSR006ArchivedDeletionDoesNotOrphanNonConversationWork() async {
  let c=ExtractedScopedReviewController();c.companionWorkingState.transitionMemoryScope(scope("A"));_ = report("My milk is in the fridge",into:&c.companionWorkingState,time:10)
  c.companionWorkingState.transitionMemoryScope(scope("B"));c.busy=true;c.questionIsChat=false;let task=Task<Void,Never> {};c.questionTask=task;let request=c.requestID
  let reviewResult0 = await c.reviseScopedConversationRecord(c.scopedConversationReviews.first!,replacement:nil); XCTAssertTrue(reviewResult0);XCTAssertTrue(c.busy);XCTAssertNotNil(c.questionTask);XCTAssertFalse(task.isCancelled);XCTAssertEqual(c.requestID,request)
 }
 @MainActor func testSR007LossRetiresOnceWithoutInventingIdentity() async {
  let c=ExtractedScopedReviewController();c.retireCompanionMemoryScope();XCTAssertEqual(c.persisted,0)
  c.companionWorkingState.transitionMemoryScope(scope("A"));c.companionWorkingState.changeGoal("Make breakfast");c.retireCompanionMemoryScope()
  XCTAssertNil(c.companionWorkingState.memoryScope);XCTAssertEqual(c.companionWorkingState.goal,"Make breakfast");XCTAssertEqual(c.journeyRetirements,1);XCTAssertEqual(c.searchRetirements,1)
  c.retireCompanionMemoryScope();XCTAssertEqual(c.journeyRetirements,1)
 }
 @MainActor func testSR008ExtractedEditorActionsStayOpenOnStaleSelection() async {
  let c=ExtractedScopedReviewController();c.companionWorkingState.transitionMemoryScope(scope("A"));let a=report("My milk is in the fridge",into:&c.companionWorkingState,time:10)
  let ui=ExtractedScopedReviewUIActions(model:c,selection:a);c.companionWorkingState.transitionMemoryScope(scope("B"));ui.replacement="My milk is on the table";await ui.save()
  XCTAssertTrue(ui.failed);XCTAssertFalse(ui.dismissed);XCTAssertEqual(c.persisted,0)
  await ui.delete();XCTAssertFalse(ui.dismissed);XCTAssertEqual(c.persisted,0)
 }
 @MainActor func testSR009ExtractedEditorSuccessfulCorrectionAndDeletion() async {
  let c=ExtractedScopedReviewController();c.companionWorkingState.transitionMemoryScope(scope("A"));let a=report("My milk is in the fridge",into:&c.companionWorkingState,time:10)
  let ui=ExtractedScopedReviewUIActions(model:c,selection:a);ui.replacement="My milk is on the table";await ui.save();XCTAssertTrue(ui.dismissed);XCTAssertFalse(ui.failed)
  let deletion=ExtractedScopedReviewUIActions(model:c,selection:c.scopedConversationReviews.first!);await deletion.delete();XCTAssertTrue(deletion.dismissed);XCTAssertTrue(c.scopedConversationReviews.isEmpty)
 }
 func testSR010DeletionRemovesArchivedDerivativesNotOtherScope() {
  var s=CompanionWorkingState();let text="My milk is in the fridge"
  s.transitionMemoryScope(scope("A"));_ = report(text,into:&s,time:10)
  s.apply(.init(goal:"",nextStep:"",completionReport:"",fact:.init(subject:"milk",value:text,quote:text),contextRevision:s.goalRevision),latest:text)
  s.transitionMemoryScope(scope("B"));_ = report(text,into:&s,time:20)
  s.apply(.init(goal:"",nextStep:"",completionReport:"",fact:.init(subject:"milk",value:text,quote:text),contextRevision:s.goalRevision),latest:text)
  XCTAssertTrue(s.reviseReviewedSource(s.reviewSelections.first { $0.scope == scope("A") }!,replacement:nil))
  XCTAssertTrue(s.scopedTaskHistory.filter { $0.scope == scope("A") }.flatMap(\.facts).isEmpty);XCTAssertEqual(s.facts.count,1)
 }
 func testSR011BoundedCorrectionProvenanceAndDialogueDecode() throws {
  var s=CompanionWorkingState();s.transitionMemoryScope(scope("A"));let a=report("My milk is in the fridge",into:&s,time:10)
  XCTAssertTrue(s.reviseReviewedSource(a,replacement:"My milk is on the table",at:Date(timeIntervalSince1970:20)))
  var json=try JSONSerialization.jsonObject(with:JSONEncoder().encode(s)) as! [String:Any];var reports=json["reports"] as! [[String:Any]]
  reports[0]["correctionOrigin"]=["sourceID":String(repeating:"x",count:65)];json["reports"]=reports
  let restored=try JSONDecoder().decode(CompanionWorkingState.self,from:JSONSerialization.data(withJSONObject:json));XCTAssertTrue(restored.scopedTaskHistory.flatMap(\.reports).isEmpty)
  var d=AssistantDialogue();d.record(role:"user",text:"report",sourceID:"source");var dj=try JSONSerialization.jsonObject(with:JSONEncoder().encode(d)) as! [String:Any]
  var records=dj["userRecords"] as! [[String:Any]];records[0]["sourceID"]=String(repeating:"x",count:65);dj["userRecords"]=records
  XCTAssertThrowsError(try JSONDecoder().decode(AssistantDialogue.self,from:JSONSerialization.data(withJSONObject:dj)))
 }

 func testSR012SourceBoundCarriedGoalAndParentAreInvalidated() {
  var s=CompanionWorkingState();s.transitionMemoryScope(scope("A"));let a=report("Find my milk",into:&s,time:10)
  XCTAssertEqual(s.goalSource?.sourceID,a.sourceID);s.transitionMemoryScope(scope("B"))
  let selected=s.reviewSelections.first { $0.sourceID == a.sourceID }!;XCTAssertTrue(s.reviseReviewedSource(selected,replacement:nil))
  XCTAssertTrue(s.goal.isEmpty);XCTAssertNil(s.goalSource);XCTAssertTrue(s.scopedTaskHistory.allSatisfy { $0.goalSource?.sourceID != a.sourceID })
 }
 @MainActor func testSR013ActualBulkClearInvalidatesEverySelection() async throws {
  let c=ExtractedScopedReviewController();c.companionWorkingState.transitionMemoryScope(scope("A"));let a=report("My milk is in the fridge",into:&c.companionWorkingState,time:10)
  c.companionWorkingState.transitionMemoryScope(scope("B"));let b=report("My milk is on the table",into:&c.companionWorkingState,time:20)
  c.assistantDialogue.record(role:"user",text:b.report.text,sourceID:b.sourceID);let prior=c.scopedConversationReviews
  c.clearAssistantConversation();XCTAssertTrue(c.scopedConversationReviews.isEmpty);XCTAssertTrue(c.assistantDialogue.userRecords.isEmpty)
  for receipt in prior { let reviewResult0 = await c.reviseScopedConversationRecord(receipt,replacement:"new"); XCTAssertFalse(reviewResult0) }
  let text=String(data:try JSONEncoder().encode(c.companionWorkingState),encoding:.utf8)!;XCTAssertFalse(text.contains(a.sourceID));XCTAssertFalse(text.contains(b.sourceID))
 }

 func testSR014DeletedCompletionCannotReturnThroughSuspendedTask() {
  var s=CompanionWorkingState();s.transitionMemoryScope(scope("A"));s.changeGoal("Help me make breakfast");s.proposedStep="Check the milk"
  let words="I got the milk";s.record(words);s.apply(.init(goal:"",nextStep:"",completionReport:words,completionStep:"Check the milk",contextRevision:s.goalRevision),latest:words)
  XCTAssertEqual(s.reportedCompletedSteps,["Check the milk"]);XCTAssertTrue(s.suspendGoal())
  XCTAssertTrue(s.reviseReviewedSource(s.reviewSelections.first!,replacement:nil));XCTAssertTrue(s.resumeGoal());XCTAssertTrue(s.reportedCompletedSteps.isEmpty)
 }

 @MainActor func testSR015ExplicitNativeGoalRecordsOneBoundSourceAndTime() async {
  let c=ExtractedScopedReviewController();c.companionWorkingState.transitionMemoryScope(scope("A"));c.commitExplicitGoal("Actually help me find my backpack")
  XCTAssertEqual(c.companionWorkingState.reports.count,1);XCTAssertEqual(c.assistantDialogue.userRecords.count,1)
  let source=c.companionWorkingState.reports.first!;XCTAssertEqual(c.companionWorkingState.goalSource?.sourceID,source.sourceID);XCTAssertEqual(c.companionWorkingState.goalSource?.recordedAt,source.time)
  let reviewResult0 = await c.reviseScopedConversationRecord(c.scopedConversationReviews.first!,replacement:nil); XCTAssertTrue(reviewResult0);XCTAssertTrue(c.companionWorkingState.goal.isEmpty);XCTAssertTrue(c.assistantDialogue.goal.isEmpty)
 }
 func testSR016ReviewDisplayDistinguishesSameTextByOriginalScope() {
  var s=CompanionWorkingState();s.transitionMemoryScope(scope("A"));_ = report("My milk is in the fridge",into:&s,time:10)
  s.transitionMemoryScope(scope("B"));_ = report("My milk is in the fridge",into:&s,time:10)
  let a=s.reviewSelections.first { $0.scope == scope("A") }!;let b=s.reviewSelections.first { $0.scope == scope("B") }!
  XCTAssertNotEqual(a.originalContext(arabic:false),b.originalContext(arabic:false));XCTAssertTrue(a.originalContext(arabic:false).contains("fridge-A"));XCTAssertTrue(a.originalContext(arabic:false).contains("Revision: 1"))
 }

 @MainActor func testSR017FailedDurabilityRetiresLiveSourceAndExplicitRetrySavesNewerReport() async throws {
  let c=ExtractedScopedReviewController();c.companionWorkingState.transitionMemoryScope(scope("A"));c.appendCurrentReport("My milk is in the fridge")
  let initial=await c.waitForAllMemorySaves();XCTAssertTrue(initial);let selected=c.scopedConversationReviews.first!
  let store=c.places.memory!;store.configureFailure(true)
  let failed=await c.reviseScopedConversationRecord(selected,replacement:nil);XCTAssertFalse(failed)
  XCTAssertTrue(c.scopedConversationReviews.isEmpty);XCTAssertFalse(c.scopedReviewError.isEmpty)
  let old=try JSONDecoder().decode(CompanionWorkingState.self,from:store.snapshots().1!);XCTAssertTrue(old.reviewSelections.contains { $0.sourceID == selected.sourceID })
  c.appendCurrentReport("My bread is on the table");let nextFailed=await c.waitForAllMemorySaves();XCTAssertFalse(nextFailed)
  store.configureFailure(false);let saved=await c.reviseScopedConversationRecord(selected,replacement:nil);XCTAssertTrue(saved)
  let reopened=try JSONDecoder().decode(CompanionWorkingState.self,from:store.snapshots().1!)
  XCTAssertFalse(reopened.reviewSelections.contains { $0.sourceID == selected.sourceID });XCTAssertTrue(reopened.reviewSelections.contains { $0.report.text == "My bread is on the table" })
  let duplicate=await c.reviseScopedConversationRecord(selected,replacement:nil);XCTAssertTrue(duplicate)
 }
 @MainActor func testSR018SlowCommitRetiresSpeechImmediatelyAndBulkClearWinsDurably() async throws {
  let c=ExtractedScopedReviewController();c.companionWorkingState.transitionMemoryScope(scope("A"));c.appendCurrentReport("My milk is in the fridge");_=await c.waitForAllMemorySaves()
  let selected=c.scopedConversationReviews.first!,store=c.places.memory!;store.configureBlock();c.conversationSpeech=[.init()];c.activeConversationSpeech = .init();c.questionIsChat=true;c.busy=true
  let task=Task { await c.reviseScopedConversationRecord(selected,replacement:nil) }
  await Task.detached { store.started.wait() }.value
  XCTAssertTrue(c.conversationSpeech.isEmpty);XCTAssertFalse(c.busy);XCTAssertEqual(c.feedback.stopped.count,1)
  XCTAssertTrue(c.scopedConversationReviews.isEmpty)
  c.clearAssistantConversation();store.release.signal();let superseded=await task.value;XCTAssertFalse(superseded)
  let cleared=await c.waitForAllMemorySaves();XCTAssertTrue(cleared)
  let reopened=try JSONDecoder().decode(CompanionWorkingState.self,from:store.snapshots().1!);XCTAssertTrue(reopened.reviewSelections.isEmpty)
  let dialogue=try JSONDecoder().decode(AssistantDialogue.self,from:store.snapshots().0!);XCTAssertTrue(dialogue.userRecords.isEmpty)
 }
 @MainActor func testSR019ReplacingStoreCannotReportOldReviewSuccessOrRebindSnapshot() async {
  for retry in [false,true] {
  let c=ExtractedScopedReviewController();c.companionWorkingState.transitionMemoryScope(scope("A"));c.appendCurrentReport("My milk is in the fridge");_=await c.waitForAllMemorySaves()
  let selected=c.scopedConversationReviews.first!,old=c.places.memory!;old.configureBlock()
  let task=Task { await c.reviseScopedConversationRecord(selected,replacement:nil) };await Task.detached { old.started.wait() }.value
  let replacement=MemoryStore();c.places.memory=replacement;if retry { c.retryCompanionMemorySave() };old.release.signal()
  let saved=await task.value;XCTAssertFalse(saved);XCTAssertEqual(replacement.writeCount,0);XCTAssertFalse(c.memorySaveError.isEmpty);XCTAssertFalse(c.memorySavePending);XCTAssertFalse(c.scopedReviewError.isEmpty)
  }
 }
 func testSR020UnboundLegacyTaskReferencesRefuseWithoutRelabeling() {
  var s=CompanionWorkingState();s.transitionMemoryScope(scope("A"));s.record("Find my cup")
  s.changeGoal("Find my cup",originalRequest:"Find my cup",sourceID:"unbound-legacy-source")
  let selected=s.reviewSelections.first!;XCTAssertTrue(s.hasUnboundTaskDependency(selected));XCTAssertFalse(s.reviseReviewedSource(selected,replacement:nil))
  XCTAssertEqual(s.goal,"Find my cup");XCTAssertEqual(s.reports.count,1)
 }
 func testSR021MaximumRetainedUnicodeStateFitsWholeSnapshotBudget() throws {
  var s=CompanionWorkingState()
  let words=String(repeating:"🟦",count:2000)
  for context in 0..<13 {
   s.transitionMemoryScope(scope(String(context)))
   for _ in 0..<12 { s.record(words) }
   s.facts=s.reports.map { .init(subject:String(repeating:"🟦",count:100),value:String(repeating:"🟦",count:100),quote:words,sourceReport:words,sourceID:$0.sourceID) }
  }
  XCTAssertEqual(s.scopedTaskHistory.count,12);XCTAssertTrue(s.scopedTaskHistory.allSatisfy(\.valid))
  let bytes=try JSONEncoder().encode(s);XCTAssertGreaterThan(bytes.count,64_000);XCTAssertLessThanOrEqual(bytes.count,CompanionMemoryWriteQueue.maximumWorkingStateBytes)
  let restored=try JSONDecoder().decode(CompanionWorkingState.self,from:bytes);XCTAssertFalse(restored.reviewSelections.isEmpty)
  print("SR-021 authored maximum Unicode retention snapshot bytes=\(bytes.count); whole reports retained")
 }

 @MainActor func testSR022UnknownPlaceStillHasUsableSourceBoundReview() async {
  let c=ExtractedScopedReviewController();c.appendCurrentReport("My milk is in the fridge");_=await c.waitForAllMemorySaves()
  XCTAssertTrue(c.usesScopedConversationReview);let selection=c.scopedConversationReviews.first!;XCTAssertNil(selection.scope)
  XCTAssertTrue(selection.originalContext(arabic:false).contains("unknown"))
  let saved=await c.reviseScopedConversationRecord(selection,replacement:"My milk is on the table");XCTAssertTrue(saved)
  XCTAssertNil(c.companionWorkingState.memoryScope);XCTAssertEqual(c.scopedConversationReviews.first?.report.text,"My milk is on the table")
 }
 @MainActor func testSR023EditorCannotQueueDuplicateSavesWhileStorageBlocked() async {
  let c=ExtractedScopedReviewController();c.appendCurrentReport("My milk is in the fridge");_=await c.waitForAllMemorySaves()
  let ui=ExtractedScopedReviewUIActions(model:c,selection:c.scopedConversationReviews.first!);ui.replacement="My milk is on the table"
  let store=c.places.memory!;let before=store.writeCount;store.configureBlock()
  let first=Task { await ui.save() };await Task.detached { store.started.wait() }.value
  XCTAssertTrue(ui.saving);await ui.save();XCTAssertFalse(ui.dismissed)
  store.release.signal();await first.value;XCTAssertTrue(ui.dismissed);XCTAssertFalse(ui.saving);XCTAssertEqual(store.writeCount,before+1)
 }

}
