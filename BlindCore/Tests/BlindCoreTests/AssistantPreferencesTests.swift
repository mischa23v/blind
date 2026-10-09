import XCTest
@testable import BlindCore

final class AssistantPreferencesTests: XCTestCase {
    func testLegacyInterestsRestoreWithDefaultDeliveryAndModesRemainReversible() throws {
        var preferences = try JSONDecoder().decode(AssistantPreferences.self, from: Data("{\"interests\":[]}".utf8))
        XCTAssertTrue(preferences.valid); XCTAssertEqual(preferences.automaticCategories.count, 5)
        XCTAssertTrue(preferences.setMode("onRequest", for: "social"))
        XCTAssertFalse(preferences.automaticCategories.contains("social"))
        XCTAssertTrue(preferences.setMode("muted", for: "decor"))
        XCTAssertFalse(preferences.setMode("muted", for: "danger"))
        XCTAssertFalse(preferences.setMode("guess-expertise", for: "social"))
        let restored = try JSONDecoder().decode(AssistantPreferences.self, from: JSONEncoder().encode(preferences))
        XCTAssertEqual(restored.mode(for: "decor"), "muted"); XCTAssertTrue(restored.valid)
        XCTAssertTrue(preferences.setMode("automatic", for: "social"))
        XCTAssertTrue(preferences.automaticCategories.contains("social"))
    }
    func testExplicitInterestsAreBoundedReversibleAndNotInferred() throws {
        var preferences = AssistantPreferences()
        XCTAssertTrue(preferences.add(category: "interest", value: "Aquariums"))
        XCTAssertFalse(preferences.add(category: "interest", value: " aquariums "))
        XCTAssertFalse(preferences.add(category: "inferred_ability", value: "Fast reader"))
        XCTAssertFalse(preferences.add(category: "food", value: "   "))
        let restored = try JSONDecoder().decode(AssistantPreferences.self, from: JSONEncoder().encode(preferences))
        XCTAssertTrue(restored.valid); XCTAssertEqual(restored.interests[0].source, "user")
        preferences.remove(id: preferences.interests[0].id); XCTAssertTrue(preferences.interests.isEmpty)
    }
}
