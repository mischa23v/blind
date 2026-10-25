import XCTest
import BlindCore
@testable import NativeLookupReplay
final class NativeSensorScopeAfterTests: XCTestCase {
 func scope() -> CompanionMemoryScope { .init(map:.init(mapID:"B",frameID:"B",revision:"1"),placeID:"B",floorID:"floor",roomID:"kitchen",objectInstanceID:"fridge")! }
 func testSR027FullSensorFirstPathWithholdsLegacySightingsWhenScoped() {
  let c=ExtractedAfterFullItemRecall();c.companionWorkingState.transitionMemoryScope(scope())
  let now=Date();_=c.observedObjects.observe(category:"milk",source:.roomPlanScan,frameID:"old",roomName:"Old kitchen",at:now,now:now)
  XCTAssertTrue(c.run("Where is my milk"));XCTAssertFalse(c.outputs.joined().contains("Old kitchen"))
 }
 func testSR028FullSensorFirstPathWithholdsLegacyItemsWhenScoped() {
  let c=ExtractedAfterFullItemRecall();c.companionWorkingState.transitionMemoryScope(scope());_=c.items.remember(name:"milk",roomName:"Old kitchen")
  XCTAssertTrue(c.run("Where is my milk"));XCTAssertFalse(c.outputs.joined().contains("Old kitchen"))
 }
}
