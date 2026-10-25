// Authored source ownership fixtures, not physical camera accuracy.
import XCTest
import BlindCore
@testable import NativeLookupReplay
final class AutomaticHistoryTests: XCTestCase {
 func scope(_ home:String,_ fridge:String = "fridge-1") -> CompanionMemoryScope { .init(map:.init(mapID:home,frameID:home,revision:"1"),placeID:home,floorID:"upstairs",roomID:"kitchen",objectInstanceID:fridge)! }
 func record(_ c:ExtractedAfterFullItemRecall,_ home:String,_ text:String = "My backpack is on the shelf",_ at:Double = 1700000000,_ fridge:String = "fridge-1") {
  c.companionWorkingState.transitionMemoryScope(scope(home,fridge));let t=Date(timeIntervalSince1970:at);c.companionWorkingState.record(text,at:t)
  _=c.companionWorkingState.respond(to:CompanionUtterance.parse(text)!,message:text,now:t,arabic:false)
 }
 func testAH001OrdinaryUnknownRequestAutomaticallyOffersDatedOwnedHistory() throws {
  let c=ExtractedAfterFullItemRecall();record(c,"house-A");c.companionWorkingState=try JSONDecoder().decode(CompanionWorkingState.self,from:JSONEncoder().encode(c.companionWorkingState))
  XCTAssertTrue(c.run("Where is my backpack?"));XCTAssertTrue(c.companionWorkingState.ordinaryHistoricalLocationReply(object:"backpack",arabic:false)!.contains("place ID: house-A"));XCTAssertTrue(c.companionWorkingState.ordinaryHistoricalLocationReply(object:"backpack",arabic:false)!.contains("floor ID: upstairs"));XCTAssertTrue(c.companionWorkingState.ordinaryHistoricalLocationReply(object:"backpack",arabic:false)!.contains("room ID: kitchen"));XCTAssertTrue(c.companionWorkingState.ordinaryHistoricalLocationReply(object:"backpack",arabic:false)!.contains("2023-11-14T22:13:20Z"))
  XCTAssertTrue(c.outputs.joined().contains("on the shelf"));XCTAssertTrue(c.outputs.joined().contains("I don't know where it is now"));XCTAssertNil(c.recordedSpotSpeech);XCTAssertNil(c.objectSearch)
 }
 func testAH002CompetingHomesAndFridgesAskRatherThanMerge() {
  for pair in [("house-B","fridge-1"),("house-A","fridge-2")] {
   let c=ExtractedAfterFullItemRecall();record(c,"house-A");record(c,pair.0,"My backpack is under the table",1700000010,pair.1);c.companionWorkingState.transitionMemoryScope(nil)
   XCTAssertTrue(c.run("Where is my backpack?"));XCTAssertTrue(c.outputs.joined().contains("Which context"));XCTAssertFalse(c.outputs.joined().contains("on the shelf"));XCTAssertFalse(c.outputs.joined().contains("under the table"));XCTAssertNil(c.objectSearch)
  }
 }
 func testAH003ExactCurrentOwnerOutranksNewerOtherHomeReport() {
  let c=ExtractedAfterFullItemRecall();record(c,"house-B","My backpack is on the shelf",1700000000);record(c,"house-A","My backpack is under the table",1700000010)
  if case .report(let f)=c.companionWorkingState.factBook.historicalLookup(object:"backpack",currentScope:scope("house-B")) { XCTAssertEqual(f.scope,scope("house-B"));XCTAssertEqual(f.at,Date(timeIntervalSince1970:1700000000)) } else { XCTFail("exact owner missing") }
 }
 func testAH004DeletedSourceCannotReturnThroughAutomaticFallback() throws {
  let c=ExtractedAfterFullItemRecall();record(c,"house-A");let source=try XCTUnwrap(c.companionWorkingState.factBook.facts.first?.sourceID)
  XCTAssertTrue(c.companionWorkingState.removeLocationReport(sourceID:source));c.companionWorkingState.transitionMemoryScope(nil)
  XCTAssertNil(c.companionWorkingState.ordinaryHistoricalLocationReply(object:"backpack",arabic:false));_=c.run("Where is my backpack?");XCTAssertFalse(c.outputs.joined().contains("on the shelf"))
 }
 func testAH005NewerSavedCategoryObservationPrecedesReportWithoutClaimingCurrentInstance() throws {
  let c=ExtractedAfterFullItemRecall();let old=Date().addingTimeInterval(-3600)
  c.companionWorkingState.record("My backpack is on the shelf",at:old);_=c.companionWorkingState.respond(to:CompanionUtterance.parse("My backpack is on the shelf")!,message:"My backpack is on the shelf",now:old,arabic:false)
  let now=Date();_=c.observedObjects.observe(category:"backpack",source:.roomPlanScan,frameID:"new",roomName:"New room",at:now,now:now)
  XCTAssertTrue(c.run("Where is my backpack?"));XCTAssertTrue(c.outputs.joined().contains("New room"));XCTAssertFalse(c.outputs.joined().contains("on the shelf"));XCTAssertEqual(c.companionWorkingState.factBook.facts.first?.at,old)
 }
}

extension AutomaticHistoryTests {
 func testAH006FreshScopedContradictionWinsArbitrationWhileHistoryKeepsOriginalSource() throws {
  let c=ExtractedAfterFullItemRecall();record(c,"house-A","My milk is in the fridge")
  let source=try XCTUnwrap(c.companionWorkingState.factBook.facts.first),now=Date(timeIntervalSince1970:1700001000)
  let observed=CompanionEvidence(id:"fresh-label",kind:.currentObservation,text:"The current label says oat milk",source:"authored validated observation fixture, not camera accuracy",observedAt:now,expiresAt:now.addingTimeInterval(1))
  let selected=CompanionScopedRecall.select(object:"milk",scope:scope("house-A"),now:now,observations:[.init(scope:scope("house-A"),object:"milk",evidence:observed)],book:c.companionWorkingState.factBook)
  XCTAssertEqual(selected,.observation(observed));XCTAssertEqual(c.companionWorkingState.factBook.facts.first,source)
 }
}

extension AutomaticHistoryTests {
 func testAH007ArabicSameHomeDifferentContainerAsksForContextNotAnotherHouse() {
  let c=ExtractedAfterFullItemRecall();record(c,"house-A");record(c,"house-A","My backpack is under the table",1700000010,"fridge-2");c.companionWorkingState.transitionMemoryScope(nil);c.arabic=true
  XCTAssertTrue(c.run("Where is my backpack?"));let words=c.outputs.joined()
  XCTAssertTrue(words.contains("سياقات أغراض مختلفة"));XCTAssertTrue(words.contains("أي سياق"));XCTAssertFalse(words.contains("أي مكان"));XCTAssertNil(c.objectSearch)
 }
}
