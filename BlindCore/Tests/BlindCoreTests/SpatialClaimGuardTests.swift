import XCTest
@testable import BlindCore

/// Same shared fixture as server/test/spatial-guard.test.mjs, so Node and Swift cannot drift apart.
final class SpatialClaimGuardTests: XCTestCase {
    private struct Fixture: Decodable { let blocked: [String]; let allowed: [String] }

    func testSharedFixtureMatchesRelayRule() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "spatial-claims", withExtension: "json", subdirectory: "Fixtures"))
        let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
        XCTAssertFalse(fixture.blocked.isEmpty)
        for text in fixture.blocked { XCTAssertTrue(SpatialClaimGuard.containsSpatialClaim(text), text) }
        for text in fixture.allowed { XCTAssertFalse(SpatialClaimGuard.containsSpatialClaim(text), text) }
    }

    func testArabicNormalizationRemovesMarksAndUnifiesAlef() {
        XCTAssertEqual(SpatialClaimGuard.normalizeArabic("أمامكَ"), "امامك")
        XCTAssertEqual(SpatialClaimGuard.normalizeArabic("خطوة"), "خطوه")
    }

    func testSentenceBoundariesPreserveDecimalEstimates() {
        XCTAssertEqual(SpatialClaimGuard.sentences("About 2.5 metres. A lamp."), ["About 2.5 metres.", " A lamp."])
        XCTAssertEqual(SpatialClaimGuard.sentences("يوجد درج؛ هو أمامك."), ["يوجد درج؛", " هو أمامك."])
    }

}
