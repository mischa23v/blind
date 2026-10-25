import XCTest
import BlindCore
@testable import NativeLookupReplay
final class NativeContextRecallAfterTests: XCTestCase {
 func scope(_ id: String) -> CompanionMemoryScope { .init(map:.init(mapID:id,frameID:id,revision:"1"),placeID:id,floorID:"floor",roomID:"kitchen",objectInstanceID:"fridge")! }
 func record(_ state: inout CompanionWorkingState) {
  let text="My milk is in the fridge";state.record(text)
  _=state.respond(to:CompanionUtterance.parse(text)!,message:text,arabic:false)
 }
 func testSR024ExactNativeFallbackCannotRecallOtherScope() {
  let c=ExtractedAfterItemRecall();c.companionWorkingState.transitionMemoryScope(scope("A"));record(&c.companionWorkingState);c.companionWorkingState.transitionMemoryScope(scope("B"))
  XCTAssertTrue(c.run("Where is my milk"));XCTAssertFalse(c.outputs.joined().contains("in the fridge"))
 }
 func testSR025RestartUnknownScopeCannotRecallScopedFact() throws {
  let c=ExtractedAfterItemRecall();c.companionWorkingState.transitionMemoryScope(scope("A"));record(&c.companionWorkingState)
  c.companionWorkingState=try JSONDecoder().decode(CompanionWorkingState.self,from:JSONEncoder().encode(c.companionWorkingState))
  XCTAssertNil(c.companionWorkingState.memoryScope);XCTAssertTrue(c.run("Where is my milk"));XCTAssertFalse(c.outputs.joined().contains("in the fridge"))
 }
 func testSR026IdentityLossCannotReturnToLegacyGlobalMode() {
  var s=CompanionWorkingState();record(&s);s.transitionMemoryScope(scope("A"));s.transitionMemoryScope(nil)
  let words="Find my milk";let reply=s.respond(to:CompanionUtterance.parse(words)!,message:words,arabic:false)
  XCTAssertFalse(reply.contains("in the fridge"))
 }
}
