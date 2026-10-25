import Foundation
import XCTest
@testable import BlindCore

final class CompanionRoomRetrievalGapTests:XCTestCase {
 let now=Date(timeIntervalSince1970:1_700_000_000)
 let names=["Entry Hall","Living Room / Kitchen","Bedroom","Bathroom","Exterior connection"]
 func place(_ id:String="oas-authored-preview",_ roomNames:[String]?=nil)->CompanionPlaceMemory {
  .init(id:id,name:"Authored Apartment",roomNames:roomNames ?? names,recordedAt:nil)
 }
 func read(_ query:String,_ places:[CompanionPlaceMemory]?=nil)->CompanionToolResult {
  CompanionMemoryRetrieval.read(query:query,now:now,places:places ?? [place()])
 }
 func text(_ result:CompanionToolResult)->String{result.evidence.map(\.text).joined(separator:" ")}
 func testLaterListedExactMatchSurvivesBoundedWindow() {
  let result=read("exterior")
  XCTAssertEqual(result.evidence.count,1)
  XCTAssertTrue(text(result).contains("Exterior connection"))
  XCTAssertTrue(text(result).contains("Showing 4 of 5 recorded rooms"))
 }
 func testDifferentWordingKeepsExactSourceLabel() {
  for query in ["Tell me about the exterior connection", "What do you remember about EXTERIOR?", "exterior connection in that apartment"] {
   XCTAssertTrue(text(read(query)).contains("Exterior connection"),query)
  }
 }
 func testMultipleLateMatchesArePrioritized() {
  let result=read("terrace exterior",[place("source-A",names+["Roof terrace"])])
  XCTAssertTrue(text(result).contains("Exterior connection"))
  XCTAssertTrue(text(result).contains("Roof terrace"))
  XCTAssertTrue(text(result).contains("Showing 4 of 6 recorded rooms"))
 }
 func testMoreThanFourMatchesAreExplicitlyPartialAndStable() {
  let labels=(1...7).map{"Storage \($0)"}
  let first=text(read("storage",[place("storage-source",labels)]))
  let second=text(read("storage",[place("storage-source",labels)]))
  XCTAssertEqual(first,second)
  XCTAssertTrue(first.contains("Storage 1, Storage 2, Storage 3, Storage 4"))
  XCTAssertFalse(first.contains("Storage 5"))
  XCTAssertTrue(first.contains("Showing 4 of 7 recorded rooms"))
  XCTAssertTrue(first.contains("ask about a named room"))
 }
 func testGenericInventorySaysPartialRatherThanInventingPagination() {
  let value=text(read("rooms"))
  XCTAssertTrue(value.contains("Entry Hall, Living Room / Kitchen, Bedroom, Bathroom"))
  XCTAssertTrue(value.contains("Showing 4 of 5 recorded rooms"))
  XCTAssertFalse(value.contains("Exterior connection")) // GAP01 full-inventory oracle remains unmet.
  XCTAssertFalse(value.contains("next page")) // No paging capability is invented.
 }
 func testSingularGenericRoomQueryRetainsSourceOrder() {
  let value=text(read("room"))
  XCTAssertTrue(value.contains("Entry Hall, Living Room / Kitchen, Bedroom, Bathroom"))
  XCTAssertTrue(value.contains("Showing 4 of 5 recorded rooms"))
 }
 func testNoMatchDoesNotEmitUnrelatedPlace() {
  XCTAssertTrue(read("garage").evidence.isEmpty)
 }
 func testSeparateSourcesCannotBorrowMatchedRoom() {
  let result=read("exterior",[place("source-A"),.init(id:"source-B",name:"Other building",roomNames:["Storage","Office"],recordedAt:nil)])
  XCTAssertEqual(result.evidence.map(\.id),["place:source-A"])
  XCTAssertTrue(text(result).contains("Exterior connection"))
  XCTAssertFalse(text(result).contains("Other building"))
  XCTAssertFalse(text(result).contains("Office"))
 }
 func testOutputKeepsHistoricalDateAndNoLocalizationAuthority() {
  let result=read("exterior")
  XCTAssertTrue(result.evidence.allSatisfy{$0.kind == .historicalMemory && $0.observedAt == nil && $0.expiresAt == nil && $0.source == "private saved place inventory"})
  XCTAssertTrue(text(result).contains("date unknown"))
  XCTAssertTrue(text(result).contains("does not establish current room, position, or clearance"))
  XCTAssertTrue(result.evidence.allSatisfy{$0.text.count <= 500})
  XCTAssertLessThanOrEqual(result.evidence.map{$0.text.unicodeScalars.count}.reduce(0,+),800)
 }
}
