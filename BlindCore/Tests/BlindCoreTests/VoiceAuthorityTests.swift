import XCTest
@testable import BlindCore

final class VoiceAuthorityTests: XCTestCase {
    private func turn(_ text: String = "hello") -> CapturedVoiceTurn {
        CapturedVoiceTurn(session: UUID(), capture: UUID(), recognitionTurn: UUID(), text: text, completedAt: 10)
    }
    func testCandidateEvidenceNeverGrantsConsequentialOrPrivateAuthority() {
        for speaker: VoiceSpeakerCandidate in [.unavailable, .rejected, .uncertain, .enrolledCandidate] {
            for addressee: VoiceAddresseeEvidence in [.unavailable, .notAddressed, .uncertain, .explicitAddressCandidate] {
                for replay: VoiceReplayEvidence in [.unavailable, .suspected, .noReplayDetected] {
                    let evidence = VoiceEvidence(turn: turn(), speaker: speaker, addressee: addressee, replay: replay)
                    XCTAssertFalse(VoiceAuthorityPolicy.permitsPrivateContext(evidence: evidence))
                    for effect in CompanionCommandEffect.allCases {
                        let lowRisk = effect == .conversation || effect == .interruptOrdinarySpeech
                        let rejected = speaker == .rejected || addressee == .notAddressed || replay == .suspected
                        XCTAssertEqual(VoiceAuthorityPolicy.permits(effect, evidence: evidence), lowRisk && !rejected)
                    }
                }
            }
        }
    }
    func testUnavailableIdentityDoesNotRequireSensorsForGenericConversation() {
        let evidence = VoiceEvidence(turn: turn("What time is it?"))
        XCTAssertTrue(VoiceAuthorityPolicy.permits(.conversation, evidence: evidence))
        XCTAssertFalse(VoiceAuthorityPolicy.permits(.changeGoal, evidence: evidence))
        XCTAssertFalse(VoiceAuthorityPolicy.permits(.requestPhysicalGuidance, evidence: evidence))
    }
    func testOwnershipIsExactFreshAndOneUse() {
        var owner = VoiceEvidenceOwnership()
        let value = turn(), ticket = owner.begin(value), evidence = VoiceEvidence(turn: value)
        XCTAssertFalse(owner.accepts(evidence, ticket: ticket, now: 9, maximumAge: 2))
        XCTAssertFalse(owner.accepts(evidence, ticket: ticket, now: 13, maximumAge: 2))
        XCTAssertFalse(owner.accepts(evidence, ticket: ticket, now: .nan, maximumAge: 2))
        let altered = CapturedVoiceTurn(id: value.id, session: value.session, capture: value.capture,
            recognitionTurn: value.recognitionTurn, text: "different words", completedAt: value.completedAt)
        XCTAssertFalse(owner.accepts(VoiceEvidence(turn: altered), ticket: ticket, now: 11, maximumAge: 2))
        XCTAssertTrue(owner.consume(evidence, ticket: ticket, now: 11, maximumAge: 2))
        XCTAssertFalse(owner.consume(evidence, ticket: ticket, now: 11, maximumAge: 2))
    }
    func testSourceSwitchAndInvalidationRejectLateEmbedding() {
        var owner = VoiceEvidenceOwnership()
        let old = turn(), ticket = owner.begin(old)
        _ = owner.begin(turn("new source"))
        XCTAssertFalse(owner.accepts(VoiceEvidence(turn: old), ticket: ticket, now: 11, maximumAge: 2))
        let current = turn(), currentTicket = owner.begin(current)
        owner.invalidate()
        XCTAssertFalse(owner.accepts(VoiceEvidence(turn: current), ticket: currentTicket, now: 11, maximumAge: 2))
    }
    func testAnonymousTurnsCannotSharePriorSpeakerTextOrIDs() {
        let first = VoiceConversationPrivacy.anonymousTurn("Authored fixture: my pet is Mango")
        let next = VoiceConversationPrivacy.anonymousTurn("Authored stranger: what did I say?")
        XCTAssertEqual(next.userRecords.count, 1)
        XCTAssertFalse(next.turns.contains(where: { $0.text.contains("Mango") }))
        XCTAssertTrue(Set(first.userRecords.map(\.id)).isDisjoint(with: Set(next.userRecords.map(\.id))))
        XCTAssertTrue(next.goal.isEmpty)
    }
    func testAnonymousContextDoesNotModifyTrustedConversation() {
        var trusted = AssistantDialogue()
        trusted.setGoal("trusted task")
        trusted.record(role: "user", text: "trusted report")
        let original = trusted
        _ = VoiceConversationPrivacy.anonymousTurn("TV command")
        XCTAssertEqual(trusted.goal, original.goal)
        XCTAssertEqual(trusted.turns, original.turns)
        XCTAssertEqual(trusted.userRecords, original.userRecords)
    }
}
