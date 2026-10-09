import XCTest
@testable import BlindCore

/// Consent-based recognition: only enrolled people are named, look-alikes stay uncertain,
/// removal is immediate, and an approach is described as observed, never as intent.
final class PeopleRegistryTests: XCTestCase {
    func testEnrollmentNeedsConsentAndUniqueNames() {
        var registry = PeopleRegistry()
        XCTAssertNotNil(registry.enroll(name: "Mum", relationship: "mother", consentBy: "self"))
        XCTAssertNil(registry.enroll(name: "mum", consentBy: "self"), "duplicate name")
        XCTAssertNil(registry.enroll(name: "Sara", consentBy: "someone"), "consent source must be self or guardian")
        XCTAssertNotNil(registry.enroll(name: "Ahmed", relationship: "brother", consentBy: "guardian"))
        XCTAssertEqual(registry.people.count, 2)
    }

    func testIdentifyOnlyEnrolledAndRespectMargin() {
        var registry = PeopleRegistry()
        let mum = registry.enroll(name: "Mum", consentBy: "self")!, aunt = registry.enroll(name: "Aunt", consentBy: "self")!
        XCTAssertEqual(registry.identify([mum.id: 0.2, aunt.id: 0.5]), .same(mum.id))
        XCTAssertEqual(registry.identify([mum.id: 0.30, aunt.id: 0.34]), .similar(mum.id), "look-alikes stay uncertain")
        XCTAssertEqual(registry.identify(["stranger": 0.1]), .none, "unenrolled ids are ignored")
    }

    func testAnnouncementsAreCalmAndAnonymousWhenUnsure() {
        var registry = PeopleRegistry()
        let mum = registry.enroll(name: "Mum", consentBy: "self")!
        XCTAssertEqual(registry.announcement(for: .same(mum.id), approaching: false, arabic: false), "Mum is here.")
        XCTAssertEqual(registry.announcement(for: .same(mum.id), approaching: true, arabic: false), "Mum is coming closer.")
        XCTAssertEqual(registry.announcement(for: .similar(mum.id), approaching: false, arabic: false), "Possibly Mum, I'm not sure.")
        XCTAssertEqual(registry.announcement(for: .none, approaching: false, arabic: false), "Someone came in.")
        registry.setAnnounce(false, id: mum.id)
        XCTAssertEqual(registry.announcement(for: .same(mum.id), approaching: false, arabic: false), "Someone came in.")
        XCTAssertTrue(registry.remove(id: mum.id))
        XCTAssertEqual(registry.identify([mum.id: 0.1]), .none, "removed people are never named")
    }

    func testCodableRoundTrip() throws {
        var registry = PeopleRegistry()
        registry.enroll(name: "Sara", relationship: "coworker", consentBy: "self", at: Date(timeIntervalSince1970: 0))
        let restored = try JSONDecoder().decode(PeopleRegistry.self, from: JSONEncoder().encode(registry))
        XCTAssertEqual(restored, registry)
    }
}
