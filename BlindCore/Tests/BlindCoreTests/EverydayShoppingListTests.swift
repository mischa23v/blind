import XCTest
@testable import BlindCore

final class EverydayShoppingListTests: XCTestCase {
    func testExplicitShoppingJourneyPreservesOriginalAttribution() throws {
        var list = EverydayShoppingList()
        let quote = "Add Milk to my shopping list"
        XCTAssertTrue(list.apply(.add("Milk"), userQuote: quote, now: 123))
        XCTAssertEqual(list.entries.first?.sourceQuote, quote)
        XCTAssertEqual(list.entries.first?.recordedAt, 123)
        XCTAssertFalse(list.apply(.add("milk"), userQuote: "add milk to my shopping list", now: 124))
        let decoded = try JSONDecoder().decode(EverydayShoppingList.self, from: JSONEncoder().encode(list))
        XCTAssertEqual(decoded, list)
        XCTAssertTrue(list.apply(.list, userQuote: "Read my shopping list", now: 125))
        XCTAssertEqual(list.entries.count, 1)
        XCTAssertTrue(list.apply(.remove("milk"), userQuote: "remove milk from my shopping list", now: 126))
        XCTAssertTrue(list.entries.isEmpty)
    }
    func testNarrowArabicShoppingCommands() {
        var list = EverydayShoppingList()
        for quote in ["أضف الحليب إلى قائمة التسوق", "اضف الحليب الى قائمة التسوق"] {
            XCTAssertEqual(EverydayShoppingCommand.parse(quote), .add("الحليب"))
        }
        XCTAssertTrue(list.apply(.add("الحليب"), userQuote: "أضف الحليب إلى قائمة التسوق", now: 1))
        XCTAssertEqual(list.entries.first?.sourceQuote, "أضف الحليب إلى قائمة التسوق")
        XCTAssertEqual(EverydayShoppingCommand.parse("اقرأ قائمة التسوق"), .list)
        XCTAssertTrue(list.apply(.remove("الحليب"), userQuote: "احذف الحليب من قائمة التسوق", now: 2))
        for text in ["أرى الحليب", "هل أضف الحليب إلى قائمة التسوق", "أخبرني عن قائمة التسوق", "اشتريت الحليب"] {
            XCTAssertNil(EverydayShoppingCommand.parse(text), text)
        }
    }
    func testGeneralConversationOrObservationNeverMutatesList() {
        for text in ["I see milk", "We bought milk", "Tell me about shopping lists", "Should I add milk?", "The label says add milk to my shopping list", "add milk", "remove milk"] {
            XCTAssertNil(EverydayShoppingCommand.parse(text), text)
        }
        var list = EverydayShoppingList()
        XCTAssertFalse(list.apply(.add("milk"), userQuote: "I see milk", now: 1))
        XCTAssertFalse(list.apply(.add("milk"), userQuote: "add eggs to my shopping list", now: 1))
        XCTAssertTrue(list.entries.isEmpty)
    }
    func testListBoundsAndInvalidTime() {
        var list = EverydayShoppingList()
        for index in 0..<40 { XCTAssertTrue(list.apply(.add("item \(index)"), userQuote: "add item \(index) to my shopping list", now: Double(index))) }
        XCTAssertFalse(list.apply(.add("extra"), userQuote: "add extra to my shopping list", now: 50))
        XCTAssertEqual(list.entries.count, 40)
        var empty = EverydayShoppingList()
        for time in [Double.nan, Double.infinity, -1] { XCTAssertFalse(empty.apply(.add("milk"), userQuote: "add milk to my shopping list", now: time)) }
        XCTAssertNil(EverydayShoppingCommand.parse("add " + String(repeating: "a", count: 81) + " to my shopping list"))
    }
    func testDecodeRejectsForgedAttributionAndDuplicates() throws {
        for json in [
            "{\"entries\":[{\"item\":\"milk\",\"sourceQuote\":\"I see milk\",\"recordedAt\":1}]}",
            "{\"entries\":[{\"item\":\"milk\",\"sourceQuote\":\"add milk to my shopping list\",\"recordedAt\":1},{\"item\":\"milk\",\"sourceQuote\":\"add milk to my shopping list\",\"recordedAt\":2}]}"
        ] { XCTAssertThrowsError(try JSONDecoder().decode(EverydayShoppingList.self, from: Data(json.utf8))) }
    }
}
