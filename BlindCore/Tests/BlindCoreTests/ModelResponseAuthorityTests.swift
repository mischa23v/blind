import Foundation
import XCTest
@testable import BlindCore

/// Request/receipt policy only. These fixtures inject model strings; they do not
/// run a model, ARKit, TTS, a real route, or a physical-device safety evaluation.
final class ModelResponseAuthorityTests: XCTestCase {
    private let requestID = UUID(uuidString: "2C1188D6-C9BF-4A98-A952-0DCB7A69F152")!
    private let wallTime = Date(timeIntervalSince1970: 1_000_000)
    private let ordinaryText = "I enjoy jokes."

    private func binding(requestID: UUID? = nil, session: UInt64 = 7,
                         goal: String = "retained-kitchen-goal") -> ModelResponseAuthority.Binding {
        .init(requestID: requestID ?? self.requestID, sessionGeneration: session, goalRevision: goal)
    }

    private func conversation(question: String = "Tell me a joke.",
                              producer: ModelResponseAuthority.Producer = .conversation) -> ModelResponseAuthority {
        var authority = ModelResponseAuthority()
        authority.begin(question: question, binding: binding(), producer: producer, at: 100)
        return authority
    }

    private func admitted(_ authority: ModelResponseAuthority, text: String? = nil,
                          producer: ModelResponseAuthority.Producer = .conversation,
                          createdAt: Double = 100, now: Double = 100) throws -> ModelResponseAuthority.Lease {
        try XCTUnwrap(authority.admit(text ?? ordinaryText, producer: producer, binding: binding(),
                                     createdAt: createdAt, now: now, date: wallTime))
    }

    func testPhysicalRequestRejectsBareModelAnswerWithoutDependingOnItsWords() {
        for question in ["Can I walk to the door?", "هل أستطيع أن أصعد هذا الدرج؟"] {
            var authority = ModelResponseAuthority()
            authority.begin(question: question, binding: binding(), at: 100)
            XCTAssertEqual(authority.owner, .physicalRequest, question)
            for reply in ["Yes.", "نعم.", ordinaryText] {
                for producer in [ModelResponseAuthority.Producer.conversation, .sceneDescription] {
                    XCTAssertNil(authority.admit(reply, producer: producer, binding: binding(),
                                                 createdAt: 100, now: 100, date: wallTime), question + " / " + reply)
                }
            }
        }
    }

    func testKnownContinuationRequestsRetainPhysicalOwnershipEvenForBareYes() {
        for question in ["How do I continue to the kitchen?", "كيف أكمل للمطبخ؟", "كيف أواصل للمطبخ؟"] {
            var authority = ModelResponseAuthority()
            authority.begin(question: question, binding: binding(), at: 100)
            XCTAssertEqual(authority.owner, .physicalRequest, question)
            for reply in ["Yes.", "نعم."] {
                XCTAssertNil(authority.admit(reply, binding: binding(), createdAt: 100, now: 100, date: wallTime), question)
            }
        }
    }

    func testKnownMovementOutputsAreRejectedEvenDuringOrdinaryConversation() {
        let authority = conversation()
        for reply in ["Continue straight through the doorway.", "Continue straight.", "Head straight.",
                      "Sidestep twice.", "كمل على طول.", "واصل على طول."] {
            XCTAssertNil(authority.admit(reply, binding: binding(), createdAt: 100, now: 100, date: wallTime), reply)
        }
    }

    func testGeneratedSceneCannotBorrowNavigationAuthority() {
        let authority = conversation(question: "Describe my surroundings.", producer: .sceneDescription)
        XCTAssertEqual(authority.owner, .conversation)
        for reply in ["Head straight.", "Continue straight through the doorway.", "كمل على طول.", "واصل على طول."] {
            XCTAssertNil(authority.admit(reply, producer: .sceneDescription, binding: binding(),
                                         createdAt: 100, now: 100, date: wallTime), reply)
        }
    }

    func testPhysicalOwnerCannotBeOverriddenByFreshMeasuredTextOrSourceLabel() {
        var authority = ModelResponseAuthority()
        authority.begin(question: "Can I walk to the door?", binding: binding(), at: 100)
        // A test record deliberately claims an authoritative source. Even a
        // fresh exact evidence record cannot change who owns the answer.
        let evidence = CompanionEvidence(kind: .measuredState, text: "Yes.", source: "verified route",
                                         observedAt: wallTime, expiresAt: wallTime.addingTimeInterval(5))
        XCTAssertNil(authority.admit("Yes.", binding: binding(), evidence: [evidence],
                                     createdAt: 100, now: 100, date: wallTime))
    }

    func testDedicatedInspectionCannotFallBackToModelAnswer() {
        var authority = ModelResponseAuthority()
        authority.begin(question: "Is this note fifty?", binding: binding(), at: 100)
        XCTAssertEqual(authority.owner, .dedicatedRequest)
        XCTAssertNil(authority.admit("Yes.", binding: binding(), createdAt: 100, now: 100, date: wallTime))
    }

    func testOrdinaryEnglishAndArabicChatRemainAvailable() throws {
        for (question, reply) in [("Tell me a joke.", ordinaryText), ("قل لي نكتة.", "أحب القصص.")] {
            let authority = conversation(question: question)
            XCTAssertEqual(authority.owner, .conversation, question)
            let lease = try admitted(authority, text: reply)
            XCTAssertTrue(authority.permits(lease, text: reply, binding: binding(), now: 101, date: wallTime))
        }
    }

    func testNonphysicalStoryContinuationIsNotGloballyBanned() throws {
        for (question, reply) in [("How do I continue my story?", "A funny surprise could happen."),
                                  ("كيف أكمل قصتي؟", "أحب القصص.")] {
            let authority = conversation(question: question)
            XCTAssertEqual(authority.owner, .conversation, question)
            let lease = try admitted(authority, text: reply)
            XCTAssertTrue(authority.permits(lease, text: reply, binding: binding(), now: 101, date: wallTime))
        }
    }

    func testRetainedNavigationGoalDoesNotDisableANewChatTurn() throws {
        var authority = ModelResponseAuthority()
        let retained = binding()
        authority.begin(question: "Can I walk to the door?", binding: retained, at: 100)
        XCTAssertEqual(authority.owner, .physicalRequest)
        authority.begin(question: "Tell me a joke.", binding: retained, at: 100)
        let lease = try admitted(authority)
        XCTAssertEqual(lease.binding.goalRevision, retained.goalRevision)
        XCTAssertTrue(authority.permits(lease, text: ordinaryText, binding: retained, now: 101, date: wallTime))
    }

    func testUnstartedOrInvalidatedOwnerCannotAdmitOrPlay() throws {
        var authority = ModelResponseAuthority()
        XCTAssertNil(authority.owner)
        XCTAssertNil(authority.admit(ordinaryText, binding: binding(), createdAt: 100, now: 100, date: wallTime))
        authority.begin(question: "Tell me a joke.", binding: binding(), at: 100)
        let lease = try admitted(authority)
        authority.invalidate()
        XCTAssertNil(authority.owner)
        XCTAssertNil(authority.admit(ordinaryText, binding: binding(), createdAt: 101, now: 101, date: wallTime))
        XCTAssertFalse(authority.permits(lease, text: ordinaryText, binding: binding(), now: 101, date: wallTime))
    }

    func testRequestSessionAndGoalMismatchRejectAdmissionAndDelayedPlayback() throws {
        let authority = conversation()
        let lease = try admitted(authority)
        let changed = [binding(requestID: UUID()), binding(session: 8), binding(goal: "new-goal")]
        for next in changed {
            XCTAssertNil(authority.admit(ordinaryText, binding: next, createdAt: 100, now: 100, date: wallTime))
            XCTAssertFalse(authority.permits(lease, text: ordinaryText, binding: next, now: 101, date: wallTime))
        }
    }

    func testRestartingEvenTheSameBindingRetiresOldQueueAndRepeatLease() throws {
        var authority = conversation()
        let old = try admitted(authority)
        authority.begin(question: "Tell me a joke.", binding: binding(), at: 101)
        XCTAssertFalse(authority.permits(old, text: ordinaryText, binding: binding(), now: 101, date: wallTime))
        let current = try admitted(authority, createdAt: 101, now: 101)
        XCTAssertTrue(authority.permits(current, text: ordinaryText, binding: binding(), now: 101, date: wallTime))
        XCTAssertNotEqual(old.id, current.id)
    }

    func testQueuedReplyAndRepeatsNeverRefreshTheOriginalDeadline() throws {
        let authority = conversation()
        let lease = try admitted(authority)
        XCTAssertEqual(lease.createdAt, 100)
        XCTAssertEqual(lease.expiresAt, 130)
        for now in [100.0, 110.0, 129.999] {
            XCTAssertTrue(authority.permits(lease, text: ordinaryText, binding: binding(), now: now, date: wallTime))
            XCTAssertEqual(lease.expiresAt, 130)
        }
        XCTAssertFalse(authority.permits(lease, text: ordinaryText, binding: binding(), now: 130, date: wallTime))
        XCTAssertFalse(authority.permits(lease, text: ordinaryText, binding: binding(), now: 131, date: wallTime))
        XCTAssertNil(authority.admit(ordinaryText, binding: binding(), createdAt: 100, now: 130, date: wallTime))
    }

    func testLateFinalDisplayOrQueueAdmissionCannotRenewTheSameRequest() throws {
        let authority = conversation()
        let streamed = try admitted(authority)
        let final = try admitted(authority, createdAt: 125, now: 125)
        XCTAssertEqual(streamed.expiresAt, 130)
        XCTAssertEqual(final.expiresAt, streamed.expiresAt)
        XCTAssertTrue(authority.permits(final, text: ordinaryText, binding: binding(), now: 129, date: wallTime))
        XCTAssertFalse(authority.permits(final, text: ordinaryText, binding: binding(), now: 130, date: wallTime))
        XCTAssertNil(authority.admit(ordinaryText, binding: binding(), createdAt: 130, now: 130, date: wallTime))
    }

    func testConversationInterruptionRetiresDisplayedAndQueuedConversationLeases() throws {
        var authority = conversation()
        let lease = try admitted(authority)
        authority.invalidateConversation()
        XCTAssertNil(authority.owner)
        XCTAssertFalse(authority.permits(lease, text: ordinaryText, binding: binding(), now: 101, date: wallTime))
        XCTAssertNil(authority.admit(ordinaryText, binding: binding(), createdAt: 101, now: 101, date: wallTime))
    }

    func testConversationInterruptionDoesNotRetireAnUnrelatedSceneOwner() throws {
        var authority = conversation(question: "Describe my surroundings.", producer: .sceneDescription)
        let lease = try admitted(authority, text: "A book.", producer: .sceneDescription)
        authority.invalidateConversation()
        XCTAssertEqual(authority.owner, .conversation)
        XCTAssertTrue(authority.permits(lease, text: lease.text, binding: binding(), now: 101, date: wallTime))
    }

    func testProducerCannotBeChangedToBorrowADifferentAdmissionPolicy() {
        let chat = conversation()
        XCTAssertNil(chat.admit("A book.", producer: .sceneDescription, binding: binding(),
                                createdAt: 100, now: 100, date: wallTime))
        let scene = conversation(question: "Describe my surroundings.", producer: .sceneDescription)
        XCTAssertNil(scene.admit(ordinaryText, producer: .conversation, binding: binding(),
                                 createdAt: 100, now: 100, date: wallTime))
    }

    func testSceneLeaseExpiresAtCaptureDeadlineNotAtDelayedAdmission() throws {
        let authority = conversation(question: "Describe my surroundings.", producer: .sceneDescription)
        let lease = try admitted(authority, text: "A book.", producer: .sceneDescription, createdAt: 100, now: 104)
        XCTAssertEqual(lease.expiresAt, 106)
        XCTAssertTrue(authority.permits(lease, text: "A book.", binding: binding(), now: 105, date: wallTime))
        XCTAssertFalse(authority.permits(lease, text: "A book.", binding: binding(), now: 106, date: wallTime))
        XCTAssertNil(authority.admit("A book.", producer: .sceneDescription, binding: binding(),
                                     createdAt: 100, now: 106, date: wallTime))
    }

    func testExactTextCannotBeReplacedOrNormalizedAtDelivery() throws {
        let authority = conversation()
        let lease = try admitted(authority)
        for altered in [" " + ordinaryText, ordinaryText.lowercased(), ordinaryText + " Yes.", "Head straight."] {
            XCTAssertFalse(authority.permits(lease, text: altered, binding: binding(), now: 101, date: wallTime), altered)
        }
    }

    func testNonfiniteFutureAndNegativeMonotonicTimesAreRejected() throws {
        let authority = conversation()
        for (createdAt, now) in [(Double.nan, 100.0), (100.0, Double.nan),
                                 (Double.infinity, 100.0), (100.0, Double.infinity), (-1.0, 100.0), (101.0, 100.0)] {
            XCTAssertNil(authority.admit(ordinaryText, binding: binding(), createdAt: createdAt, now: now, date: wallTime))
        }
        let lease = try admitted(authority)
        for now in [Double.nan, .infinity, -1, 99.999] {
            XCTAssertFalse(authority.permits(lease, text: ordinaryText, binding: binding(), now: now, date: wallTime))
        }
    }

    func testFreshObservationCannotOutliveItsOwnEvidenceDuringQueueDelay() throws {
        let authority = conversation()
        let text = "Current observation: a book."
        let evidence = CompanionEvidence(kind: .currentObservation, text: text, source: "synthetic test capture",
                                         observedAt: wallTime, expiresAt: wallTime.addingTimeInterval(5))
        let lease = try XCTUnwrap(authority.admit(text, binding: binding(), evidence: [evidence],
                                                 createdAt: 100, now: 100, date: wallTime))
        XCTAssertTrue(authority.permits(lease, text: text, binding: binding(), now: 101, date: wallTime.addingTimeInterval(1)))
        XCTAssertFalse(authority.permits(lease, text: text, binding: binding(), now: 105, date: wallTime.addingTimeInterval(5)))
        XCTAssertEqual(lease.expiresAt, 130) // The shorter evidence expiry still wins.
    }
}
