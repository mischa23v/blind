// Actual native routes and actual first-tab reply getter; authored historical sources.
import XCTest
import BlindCore
@testable import NativeLookupReplay
final class ReadableHistoryTests: XCTestCase {
 func setup(_ c: ExtractedAfterFullItemRecall,at:Date=Date(),place:String="on the shelf",hedged:Bool=false) -> CompanionFact {
  let s=CompanionMemoryScope(map:.init(mapID:UUID().uuidString,frameID:UUID().uuidString,revision:UUID().uuidString),placeID:UUID().uuidString,floorID:UUID().uuidString,roomID:UUID().uuidString,objectInstanceID:UUID().uuidString)!
  c.companionWorkingState.transitionMemoryScope(s)
  let f=c.companionWorkingState.factBook.record(object:"backpack",place:place,tense:.earlier,hedged:hedged,at:at,scope:s,sourceID:UUID().uuidString)!
  c.companionWorkingState.transitionMemoryScope(nil);return f
 }
 func testRH001ActualFirstTabMatchesSpokenReplyWithoutTechnicalMetadata() {
  for query in ["Where is my backpack?","Where did I leave my backpack?"] {
   let c=ExtractedAfterFullItemRecall();let fact=setup(c,at:Date(timeIntervalSince1970:1700000000))
   XCTAssertTrue(c.run(query));let words=c.outputs.last!
   XCTAssertEqual(ExtractedHomeReply(model:c).value,words);XCTAssertEqual(c.sceneAnswer,words);XCTAssertEqual(c.message,words)
   XCTAssertTrue(words.contains("You told me on"));XCTAssertTrue(words.contains("2023"));XCTAssertTrue(words.contains("on the shelf"));XCTAssertTrue(words.contains("I don't know where it is now"))
   for forbidden in [fact.scope!.placeID,"place ID:","revision:","T22:","Historical report"] { XCTAssertFalse(words.contains(forbidden),forbidden) }
   XCTAssertEqual(c.companionWorkingState.factBook.facts.first,fact)
   XCTAssertTrue(c.companionWorkingState.historicalLocationReply(to:"Where did I leave my backpack",arabic:false)!.contains(fact.scope!.placeID))
  }
 }
 func testRH002RelativeDaysPreserveOriginalDateHedgeAndWholeNegation() {
  let now=Date(),yesterday=Calendar.current.date(byAdding:.day,value:-1,to:now)!
  for (time,label) in [(now,"today"),(yesterday,"yesterday")] {
   let c=ExtractedAfterFullItemRecall();let fact=setup(c,at:time,place:"in the cupboard, not the fridge",hedged:true)
   let words=c.companionWorkingState.historicalLocationReply(to:"Where did I leave my backpack",now:now,arabic:false,concise:true)!
   XCTAssertTrue(words.contains("You told me "+label+" you thought"));XCTAssertTrue(words.contains("in the cupboard, not the fridge"));XCTAssertTrue(words.contains("I don't know where it is now"));XCTAssertEqual(c.companionWorkingState.factBook.facts.first?.at,fact.at)
  }
 }
 func testRH003LongNegationNeverBecomesPartialFirstTabOrFalseDisplayedClaim() {
  let c=ExtractedAfterFullItemRecall();let fact=setup(c,place:"in "+String(repeating:"a ",count:30)+"not freezer",hedged:true)
  XCTAssertTrue(c.run("Where is my backpack?"));let words=c.outputs.last!
  XCTAssertEqual(ExtractedHomeReply(model:c).value,words);XCTAssertEqual(c.sceneAnswer,words);XCTAssertFalse(words.contains("freezer"));XCTAssertFalse(words.contains("displayed"));XCTAssertFalse(words.contains(fact.scope!.placeID))
  XCTAssertTrue(words.contains("longer saved report"));XCTAssertLessThanOrEqual(CompanionReferenceReading.wordCount(words),30)
  XCTAssertTrue(c.companionWorkingState.historicalLocationReply(to:"Where did I leave my backpack",arabic:false)!.contains("not freezer"))
 }
 func testRH004ArabicAccessibleReplyRetainsPlainAttributionAndUnknownCurrentLocation() {
  let c=ExtractedAfterFullItemRecall();_=setup(c,hedged:true);c.arabic=true
  XCTAssertTrue(c.run("Where is my backpack?"));let words=c.outputs.last!
  XCTAssertEqual(ExtractedHomeReply(model:c).value,words);XCTAssertTrue(words.contains("قلت لي اليوم"));XCTAssertTrue(words.contains("تظن"));XCTAssertTrue(words.contains("لا أعرف أين هو الآن"));XCTAssertFalse(words.contains("ID:"));XCTAssertFalse(words.contains("T00:"))
 }
}
