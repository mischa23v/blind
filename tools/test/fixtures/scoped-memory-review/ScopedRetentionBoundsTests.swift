import XCTest
import BlindCore
@testable import NativeReviewReplay
final class ScopedRetentionBoundsTests: XCTestCase {
 func decode(_ fields: [String:Any]) throws -> CompanionWorkingState {
  var data=try XCTUnwrap(JSONSerialization.jsonObject(with:JSONEncoder().encode(CompanionWorkingState())) as? [String:Any]);for (key,value) in fields { data[key]=value }
  return try JSONDecoder().decode(CompanionWorkingState.self,from:JSONSerialization.data(withJSONObject:data))
 }
 func testSR038MalformedCombiningScalarsCannotEscapeRetainedFieldBudgets() throws {
  let huge="x"+String(repeating:"\u{301}",count:5000);XCTAssertEqual(huge.count,1)
  let s=try decode(["goal":huge,"goalRevision":String(repeating:"r",count:1000),"proposedStep":huge,"reportedCompletedSteps":[huge],"focusObject":huge,
   "facts":[["subject":huge,"value":"reported","quote":"source"]],
   "suspendedGoals":[["goal":"normal goal","proposedStep":"","reportedCompletedSteps":[huge],"focusObject":huge,"parentGoal":["goal":huge,"reportedCompletedSteps":[]]]]])
  XCTAssertTrue(s.goal.isEmpty);XCTAssertTrue(s.proposedStep.isEmpty);XCTAssertTrue(s.reportedCompletedSteps.isEmpty);XCTAssertTrue(s.facts.isEmpty);XCTAssertTrue(s.focusObject.isEmpty);XCTAssertLessThanOrEqual(s.goalRevision.utf8.count,64)
  XCTAssertNil(s.suspendedGoals.first?.focusObject);XCTAssertNil(s.suspendedGoals.first?.parentGoal);XCTAssertTrue(s.suspendedGoals.first?.reportedCompletedSteps.isEmpty == true)
 }
 func testSR039MalformedArchiveRejectedWholeWithoutTruncatingOtherSource() throws {
  let huge="x"+String(repeating:"\u{301}",count:5000)
  let invalid:[String:Any]=["goal":huge,"goalRevision":"old","reports":[],"facts":[],"completedSteps":[]]
  let valid:[String:Any]=["goal":"Do not move the milk","goalRevision":"retained","reports":[["text":"Do not move the milk","sourceID":"original-source","time":123]],"facts":[],"completedSteps":[]]
  let s=try decode(["scopedTaskHistory":[invalid,valid]])
  XCTAssertFalse(s.scopedTaskHistory.contains { $0.goal==huge });let kept=try XCTUnwrap(s.scopedTaskHistory.first { $0.goalRevision=="retained" })
  XCTAssertEqual(kept.reports.first?.text,"Do not move the milk");XCTAssertEqual(kept.reports.first?.sourceID,"original-source");XCTAssertEqual(kept.reports.first?.time,Date(timeIntervalSinceReferenceDate:123))
 }
}
extension ScopedRetentionBoundsTests {
 func testSR040DialogueRejectsOversizeIdentifierBytesWithoutTruncation() throws {
  let huge="x"+String(repeating:"\u{301}",count:5000)
  for fields:[String:Any] in [["goal":"","goalRevision":huge,"turns":[],"userRecords":[]],["goal":"","goalRevision":"valid","turns":[],"userRecords":[["id":huge,"text":"Do not move the milk"]]]] {
   XCTAssertThrowsError(try JSONDecoder().decode(AssistantDialogue.self,from:JSONSerialization.data(withJSONObject:fields)))
  }
  let id=String(repeating:"a",count:64);let valid:[String:Any]=["goal":"","goalRevision":id,"turns":[],"userRecords":[["id":id,"text":"Do not move the milk"]]]
  let decoded=try JSONDecoder().decode(AssistantDialogue.self,from:JSONSerialization.data(withJSONObject:valid));XCTAssertTrue(decoded.valid);XCTAssertEqual(decoded.userRecords.first?.id,id);XCTAssertEqual(decoded.userRecords.first?.text,"Do not move the milk")
 }
}
extension ScopedRetentionBoundsTests {
 func testSR041ActiveReportDatesRejectMalformedAndPreserveUnknownOriginalTime() throws {
  let s=try decode(["reports":[["text":"bad dated report","sourceID":"bad","time":1e20],["text":"unknown time report","sourceID":"unknown"],["text":"dated report","sourceID":"dated","time":123]]])
  XCTAssertFalse(s.reports.contains { $0.sourceID=="bad" });XCTAssertFalse(s.reviewSelections.contains { $0.sourceID=="bad" })
  XCTAssertNil(s.reports.first { $0.sourceID=="unknown" }?.time);XCTAssertTrue(s.reports.contains { $0.sourceID=="unknown" })
  XCTAssertEqual(s.reports.first { $0.sourceID=="dated" }?.time,Date(timeIntervalSinceReferenceDate:123))
 }
}
