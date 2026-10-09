import XCTest
@testable import BlindCore

/// The on-device prompt is the shared guide-prompt.txt and fits the built-in model's window.
final class GuidePromptTests: XCTestCase {
    func testSharedPromptLoadsWithSafetyRule() {
        XCTAssertNotEqual(GuidePrompt.text, GuidePrompt.fallback, "resource should load, not the fallback")
        XCTAssertTrue(GuidePrompt.text.hasPrefix("You are the guide"))
        XCTAssertTrue(GuidePrompt.text.contains("SPATIAL SAFETY RULE"))
        XCTAssertTrue(GuidePrompt.fallback.contains("SPATIAL SAFETY RULE"))
        let arabic = GuidePrompt.instructions(arabic: true, wordAllowance: 6, requested: false)
        XCTAssertTrue(arabic.hasSuffix("Answer in Arabic, at most 6 words."))
        XCTAssertLessThan(GuidePrompt.text.utf8.count, 2400, "keep the guide prompt small for the on-device window")
    }

    func testCompactSituationDropsBulkFirstAndKeepsTheCore() throws {
        let entities = (0..<32).map { ["id": "entity-\($0)", "description": String(repeating: "wooden shelf ", count: 20)] }
        let situation: [String: Any] = ["goal": ["description": "reach the closet"], "location": ["state": "unknown"],
                                        "entities": entities, "snapshotID": "s1", "places": [["id": "p", "name": "Home"]]]
        let data = try XCTUnwrap(GuidePrompt.compactSituation(situation))
        XCTAssertLessThanOrEqual(data.count, 4000)
        let kept = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNotNil(kept["goal"]); XCTAssertNotNil(kept["location"])
        XCTAssertNil(kept["entities"]); XCTAssertNil(kept["snapshotID"])
        XCTAssertNil(GuidePrompt.compactSituation(["goal": ["description": String(repeating: "x", count: 5000)]]))
    }
}
