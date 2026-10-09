import XCTest
@testable import BlindCore

/// "Is this HIS cup?" is decided by image distances with a margin over look-alikes, never by a model.
final class ItemAppearanceMatchTests: XCTestCase {
    func testClearMatchIsSame() {
        XCTAssertEqual(ItemAppearanceMatch.decide(["my cup": 0.2, "ahmed's cup": 0.6]), .same("my cup"))
        XCTAssertEqual(ItemAppearanceMatch.decide(["my cup": 0.3]), .same("my cup"))
    }

    func testLookAlikeWithinMarginIsOnlySimilar() {
        // A brother's near-identical cup is too close to call.
        XCTAssertEqual(ItemAppearanceMatch.decide(["my cup": 0.30, "ahmed's cup": 0.36]), .similar("my cup"))
    }

    func testWeakMatchesAreSimilarOrNone() {
        XCTAssertEqual(ItemAppearanceMatch.decide(["my cup": 0.55]), .similar("my cup"))
        XCTAssertEqual(ItemAppearanceMatch.decide(["my cup": 0.9]), .none)
        XCTAssertEqual(ItemAppearanceMatch.decide([:]), .none)
        XCTAssertEqual(ItemAppearanceMatch.decide(["my cup": .nan, "spoon": .infinity]), .none)
    }

    func testLearnCommandParsesEnglishAndArabic() {
        XCTAssertEqual(ItemCommand.parse("This is my cup"), .learn("cup"))
        XCTAssertEqual(ItemCommand.parse("هذا كوبي"), .learn("كوبي"))
        XCTAssertEqual(ItemCommand.parse("where is my cup"), .find("cup"))
        XCTAssertNotEqual(ItemCommand.parse("هذا ماذا؟"), .learn("ماذا"), "an Arabic question is not a request to learn")
    }

    func testDescriptionIsStoredForSpeakingOnly() {
        var memory = ItemMemory()
        memory.remember(name: "cup", at: Date(timeIntervalSince1970: 0))
        XCTAssertTrue(memory.describe("cup", as: "Blue mug with a white handle."))
        XCTAssertEqual(memory.find("cup")?.description, "Blue mug with a white handle.")
        XCTAssertFalse(memory.describe("spoon", as: "Silver spoon."))
        memory.remember(name: "cup", roomName: "kitchen", at: Date(timeIntervalSince1970: 60))
        XCTAssertEqual(memory.find("cup")?.description, "Blue mug with a white handle.", "re-saving keeps the description")
    }
}
