import XCTest
@testable import BlindCore

/// Verifies the preference contract and prompt wording, not model behavior,
/// verified age, adult supervision, or suitability for child-facing use.
final class AssistantAudienceTests: XCTestCase {
    func testDefaultAndMissingPreferenceDoNotAssumeAdultOrChild() {
        XCTAssertEqual(AssistantAudience.defaultValue, .general)
        XCTAssertEqual(AssistantAudience(persistedValue: nil), .general)
        XCTAssertEqual(AssistantAudience.allCases, [.general, .adult, .childWithGuardian])
    }

    func testOnlyExactSupportedStoredChoicesAreAccepted() {
        for audience in AssistantAudience.allCases {
            XCTAssertEqual(AssistantAudience(persistedValue: audience.rawValue), audience)
            XCTAssertEqual(audience.id, audience.rawValue)
        }
        for value in ["", "Adult", "ADULT", " adult ", "child", "8", "18", "verifiedAdult", "guardianPresent", "unknownFutureMode"] {
            XCTAssertEqual(AssistantAudience(persistedValue: value), .general, value)
        }
    }

    func testCodableRoundTripStoresOnlyOneExplicitModeString() throws {
        for audience in AssistantAudience.allCases {
            let data = try JSONEncoder().encode(audience)
            XCTAssertEqual(String(decoding: data, as: UTF8.self), "\"\(audience.rawValue)\"")
            XCTAssertEqual(try JSONDecoder().decode(AssistantAudience.self, from: data), audience)
        }
    }

    func testUnknownNullAndWrongTypedJSONFallBackToGeneral() throws {
        for json in ["\"retiredMode\"", "\" adult \"", "null", "18", "true", "[]", "{}", "{\"mode\":\"adult\"}"] {
            XCTAssertEqual(try JSONDecoder().decode(AssistantAudience.self, from: Data(json.utf8)), .general, json)
        }
    }

    func testInvalidJSONStillReportsTheContainerError() {
        XCTAssertThrowsError(try JSONDecoder().decode(AssistantAudience.self, from: Data("not JSON".utf8)))
    }

    func testEveryModeDisclosesTheLimitsInSettings() {
        for audience in AssistantAudience.allCases {
            XCTAssertFalse(audience.title.isEmpty)
            XCTAssertTrue(audience.detail.contains("local communication preference"))
            XCTAssertTrue(audience.detail.contains("not verified age"))
            XCTAssertTrue(audience.detail.contains("proof that a guardian is present"))
            XCTAssertTrue(audience.detail.contains("child-safety certification"))
            XCTAssertTrue(audience.detail.contains("Safety checks stay the same"))
        }
    }

    func testEveryModePreservesIndependentSafetyAndRelationshipBoundaries() {
        for audience in AssistantAudience.allCases {
            let instructions = audience.modelInstructions
            XCTAssertTrue(instructions.contains("Never infer age from appearance, voice or wording, or request a date of birth"))
            XCTAssertTrue(instructions.contains("Keep all sensor-evidence, domain, consent and privacy gates unchanged"))
            XCTAssertTrue(instructions.contains("Never claim a guardian is present or that child safety is certified"))
            XCTAssertTrue(instructions.contains("Do not encourage secrecy from trusted people, exclusivity or emotional dependence, or pressure the user to keep talking"))
            XCTAssertLessThan(instructions.utf8.count, 1_000, "Keep the local model's context addition bounded")
        }
    }

    func testGeneralModeLeavesAgeUnknownAndAdultModeCannotGrantPermissions() {
        XCTAssertTrue(AssistantAudience.general.modelInstructions.contains("age is unknown"))
        XCTAssertTrue(AssistantAudience.general.modelInstructions.contains("broadly age-appropriate"))
        XCTAssertTrue(AssistantAudience.adult.modelInstructions.contains("explicitly selected, not age verification"))
        XCTAssertTrue(AssistantAudience.adult.modelInstructions.contains("grants no extra permissions and does not relax safety"))
    }

    func testChildModeSupportsTrustedAdultsWithoutAssumingSupervision() {
        let instructions = AssistantAudience.childWithGuardian.modelInstructions
        XCTAssertTrue(instructions.contains("simple, age-appropriate language without baby talk"))
        XCTAssertTrue(instructions.contains("Encourage help from a trusted adult for high-stakes decisions or real-world safety"))
        XCTAssertTrue(instructions.contains("does not replace adult supervision"))
        XCTAssertTrue(instructions.contains("Never claim a guardian is present"))
        XCTAssertFalse(instructions.contains("eight-year-old"))
    }
}
