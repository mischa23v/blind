import Foundation
import XCTest
@testable import BlindCore

/// Run separately against the untouched model-tool path. This test is EXPECTED
/// TO FAIL and must not be folded into a claimed passing final suite. It keeps
/// the specific long-evidence loss visible rather than weakening the assertion.
final class ReferenceLegacyFailureWitnessTests: XCTestCase {
    func testOriginalOversizedReferenceBlocksAreNotLostToModelBudget() async throws {
        let blocks = (0..<4).map { index in
            CompanionEvidence(id: "authored-\(index)", kind: .historicalMemory,
                text: "Authored source block \(index): " + String(repeating: "Keep this entire condition and its negation. ", count: 8),
                source: "authored local reference")
        }
        let result = CompanionToolResult(status: .success, source: "authored local reference", evidence: blocks)
        let runtime = CompanionToolRuntime(available: [.savedMemory]) { _ in result }
        let bounded = await runtime.run(CompanionToolRequest(kind: .savedMemory, query: "authored"))
        XCTAssertTrue(bounded.evidence == blocks, "The generic model-result path must not lose original reference blocks. This is a preserved failure witness, not the new direct-reading API.")
    }
}
