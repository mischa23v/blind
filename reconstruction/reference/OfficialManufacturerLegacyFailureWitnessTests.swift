import Foundation
import XCTest
@testable import BlindCore

// EXPECTED failure, run separately with the private extracted fixture. Do not
// publish the fixture or use equality assertions that print its full contents.
final class OfficialManufacturerLegacyFailureWitnessTests: XCTestCase {
    private struct Fixture: Decodable { struct Block: Decodable { let text: String }; let positive: Block }
    func testActualLongPDFSectionSurvivesGenericModelEvidencePath() async throws {
        let path = try XCTUnwrap(ProcessInfo.processInfo.environment["BLIND_REFERENCE_REPLAY_INPUT"])
        let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        let item = CompanionEvidence(kind: .historicalMemory, text: fixture.positive.text, source: "official manufacturer reference")
        let original = CompanionToolResult(status: .success, source: "official manufacturer reference", evidence: [item])
        let runtime = CompanionToolRuntime(available: [.savedMemory]) { _ in original }
        let bounded = await runtime.run(.init(kind: .savedMemory, query: "source section"))
        XCTAssertEqual(bounded.evidence.count, 1, "Expected-failure witness: complete real source record must not disappear.")
    }
}
