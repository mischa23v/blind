import XCTest
import BlindCore
@testable import NativeLookupReplay
final class NativeHistoricalRecallTests: XCTestCase {
 func scope(_ place: String) -> CompanionMemoryScope { .init(map:.init(mapID:place,frameID:place,revision:"revision-7"),placeID:place,floorID:"floor-2",roomID:"kitchen",objectInstanceID:"fridge-3")! }
 func record(_ state: inout CompanionWorkingState, time: Date = Date(timeIntervalSince1970:1_700_000_000)) {
  let text="My milk is in the fridge";state.record(text,at:time)
  _=state.respond(to:CompanionUtterance.parse(text)!,message:text,now:time,arabic:false)
 }
 func testSR029LegacyOnlyPositiveControlKeepsActualNativeRecall() {
  let c=ExtractedAfterItemRecall();record(&c.companionWorkingState)
  XCTAssertTrue(c.run("Where is my milk"));XCTAssertTrue(c.outputs.joined().contains("in the fridge"))
  let sensors=ExtractedAfterFullItemRecall();record(&sensors.companionWorkingState)
  XCTAssertTrue(sensors.run("Where is my milk"));XCTAssertTrue(sensors.outputs.joined().contains("in the fridge"))
 }
 func testSR030ExplicitHistoryRetainsOriginalTimeAndAWhileCurrentBIsDenied() {
  let c=ExtractedAfterFullItemRecall();c.companionWorkingState.transitionMemoryScope(scope("house-A"));record(&c.companionWorkingState)
  c.companionWorkingState.transitionMemoryScope(scope("house-B"));let revision=c.companionWorkingState.goalRevision;let goal=c.companionWorkingState.goal
  XCTAssertTrue(c.run("Where is my milk"));XCTAssertFalse(c.outputs.joined().contains("in the fridge"));c.outputs=[]
  XCTAssertTrue(c.run("Where did I last leave my milk?"));let answer=c.message
  XCTAssertTrue(c.outputs.joined().contains("in the fridge"));XCTAssertTrue(answer.contains("2023-11-14T22:13:20Z"));XCTAssertTrue(answer.contains("place ID: house-A"));XCTAssertFalse(answer.contains("house-B"));XCTAssertTrue(answer.contains("object instance ID: fridge-3"));XCTAssertTrue(answer.contains("revision: revision-7"));XCTAssertTrue(answer.contains("I don't know where it is now"))
  XCTAssertEqual(c.companionWorkingState.goalRevision,revision);XCTAssertEqual(c.companionWorkingState.goal,goal);XCTAssertNil(c.objectSearch)
 }
 func testSR031RestartIdentityLossStillAllowsAttributedHistoryNotCurrentLookup() throws {
  let c=ExtractedAfterItemRecall();c.companionWorkingState.transitionMemoryScope(scope("house-A"));record(&c.companionWorkingState)
  c.companionWorkingState=try JSONDecoder().decode(CompanionWorkingState.self,from:JSONEncoder().encode(c.companionWorkingState));XCTAssertNil(c.companionWorkingState.memoryScope)
  XCTAssertTrue(c.run("Where did I leave my milk"));XCTAssertTrue(c.message.contains("place ID: house-A"));c.outputs=[]
  XCTAssertTrue(c.run("Where is my milk"));XCTAssertFalse(c.outputs.joined().contains("in the fridge"))
 }
 func testSR032UnknownHistoricalPlaceNeverInventsAnIdentity() {
  let c=ExtractedAfterFullItemRecall();record(&c.companionWorkingState);c.companionWorkingState.transitionMemoryScope(scope("house-B"));c.companionWorkingState.transitionMemoryScope(nil)
  XCTAssertTrue(c.run("Where did I last put my milk"));XCTAssertTrue(c.message.contains("place identity unknown"));XCTAssertFalse(c.message.contains("place ID: house-B"))
 }
}
extension NativeHistoricalRecallTests {
 func testSR033ActualReceiveEntryRoutesHistoryBeforeExistingTaskMutation() {
  let c=ExtractedHistoricalIngress();c.companionWorkingState.transitionMemoryScope(scope("A"));record(&c.companionWorkingState);c.companionWorkingState.changeGoal("Make breakfast")
  let goal=c.companionWorkingState.goal,revision=c.companionWorkingState.goalRevision
  c.receiveCompanionUtterance("Where did I leave my milk?")
  XCTAssertEqual(c.taskCalls,0);XCTAssertEqual(c.companionWorkingState.goal,goal);XCTAssertEqual(c.companionWorkingState.goalRevision,revision);XCTAssertFalse(c.outputs.isEmpty)
  c.receiveCompanionUtterance("Where did I leave my milk?",fromVoice:true);XCTAssertEqual(c.voiceCalls,1);XCTAssertEqual(c.outputs.count,1)
 }
 func testSR034LongHistoryFallsBackInsteadOfSpeakingAnIncompleteClue() {
  let c=ExtractedAfterFullItemRecall();let id=String(repeating:"identity ",count:14);let scope=CompanionMemoryScope(map:.init(mapID:id,frameID:id,revision:id),placeID:id,floorID:id,roomID:id,objectInstanceID:id)!
  c.companionWorkingState.transitionMemoryScope(scope);let text="My milk is in "+String(repeating:"a ",count:30)+"original place";c.companionWorkingState.record(text)
  _=c.companionWorkingState.respond(to:CompanionUtterance.parse(text)!,message:text,arabic:false)
  XCTAssertTrue(c.run("Where did I last leave my milk"));XCTAssertEqual(c.outputs.count,1);XCTAssertTrue(c.outputs.allSatisfy { CompanionReferenceReading.wordCount($0) <= 30 })
  XCTAssertTrue(c.outputs[0].contains("too long for one spoken reply"));XCTAssertFalse(c.outputs.joined().contains("original place"));XCTAssertTrue(c.message.contains(id));XCTAssertTrue(c.message.contains("revision:"));XCTAssertTrue(c.message.contains("original place"))
 }
}
extension NativeHistoricalRecallTests {
 func testSR035PartialScopedSnapshotRetiresUnboundActiveProgressOnDecode() throws {
  var s=CompanionWorkingState();s.transitionMemoryScope(scope("A"));record(&s);s.reportedCompletedSteps=["old completion"]
  var json=try XCTUnwrap(JSONSerialization.jsonObject(with:JSONEncoder().encode(s)) as? [String:Any]);json.removeValue(forKey:"memoryScope");json.removeValue(forKey:"scopedTaskHistory")
  let restored=try JSONDecoder().decode(CompanionWorkingState.self,from:JSONSerialization.data(withJSONObject:json))
  XCTAssertTrue(restored.hasScopedMemoryHistory);XCTAssertNil(restored.memoryScope);XCTAssertTrue(restored.reports.isEmpty);XCTAssertTrue(restored.reportedCompletedSteps.isEmpty);XCTAssertNil(restored.currentContextFact(for:"milk"))
  XCTAssertTrue(restored.historicalLocationReply(to:"Where did I leave my milk",arabic:false)?.contains("place ID: A") == true)
 }
 func testSR036LongHistoricalNegationNeverBecomesPartialSpokenDirection() {
  let c=ExtractedAfterFullItemRecall();c.companionWorkingState.transitionMemoryScope(scope("A"))
  let place="in "+String(repeating:"a ",count:30)+"not freezer"
  XCTAssertNotNil(c.companionWorkingState.factBook.record(object:"cup",place:place,tense:.earlier,hedged:false,scope:scope("A")))
  XCTAssertTrue(c.run("Where did I leave my cup"));XCTAssertEqual(c.outputs.count,1);XCTAssertTrue(c.outputs[0].contains("too long for one spoken reply"));XCTAssertFalse(c.outputs[0].contains("freezer"));XCTAssertTrue(c.message.contains("not freezer"))
 }
}
extension NativeHistoricalRecallTests {
 func testSR037HedgedShortAndChunkedHistoryRetainsUncertaintyAndClue() {
  for place in ["on the shelf", "in "+String(repeating:"a ",count:30)+"not freezer"] {
   let c=ExtractedAfterFullItemRecall();c.companionWorkingState.transitionMemoryScope(scope("A"))
   XCTAssertNotNil(c.companionWorkingState.factBook.record(object:"cup",place:place,tense:.earlier,hedged:true,scope:scope("A")))
   XCTAssertTrue(c.run("Where did I last leave my cup"));XCTAssertFalse(c.outputs.isEmpty)
   XCTAssertTrue(c.outputs.allSatisfy { CompanionReferenceReading.wordCount($0) <= 30 })
   if place == "on the shelf" { XCTAssertTrue(c.outputs.joined().contains("Uncertain historical report"));XCTAssertTrue(c.outputs.joined().contains("on the shelf")) }
   else { XCTAssertTrue(c.outputs.joined().contains("too long for one spoken reply"));XCTAssertTrue(c.message.contains("not freezer"));XCTAssertTrue(c.message.contains("you thought")) }
  }
 }
}
