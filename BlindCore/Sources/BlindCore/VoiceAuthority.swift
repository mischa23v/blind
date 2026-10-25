import Foundation

/// Acoustic provenance, never a speaker authentication claim. The capture adapter
/// binds this immutable event before rotating ASR; text cannot select its origin.
public struct CapturedVoiceTurn: Equatable, Sendable {
    public let id: UUID
    public let session: UUID
    public let capture: UUID
    public let recognitionTurn: UUID
    public let text: String
    public let completedAt: TimeInterval
    public var origin: CompanionCommandOrigin { .unverifiedMicrophone }
    public init(id: UUID = UUID(), session: UUID, capture: UUID, recognitionTurn: UUID,
                text: String, completedAt: TimeInterval) {
        self.id = id; self.session = session; self.capture = capture
        self.recognitionTurn = recognitionTurn; self.text = text; self.completedAt = completedAt
    }
}

/// Labels describe upstream evidence, not permission. In particular even matched
/// speaker + explicit address + no detected replay is not validated child authority.
public enum VoiceSpeakerCandidate: Equatable, Sendable { case unavailable, rejected, uncertain, enrolledCandidate }
public enum VoiceAddresseeEvidence: Equatable, Sendable { case unavailable, notAddressed, uncertain, explicitAddressCandidate }
public enum VoiceReplayEvidence: Equatable, Sendable { case unavailable, suspected, noReplayDetected }
public struct VoiceEvidence: Equatable, Sendable {
    public let turn: CapturedVoiceTurn
    public let speaker: VoiceSpeakerCandidate
    public let addressee: VoiceAddresseeEvidence
    public let replay: VoiceReplayEvidence
    public init(turn: CapturedVoiceTurn, speaker: VoiceSpeakerCandidate = .unavailable,
                addressee: VoiceAddresseeEvidence = .unavailable, replay: VoiceReplayEvidence = .unavailable) {
        self.turn = turn; self.speaker = speaker; self.addressee = addressee; self.replay = replay
    }
}

/// One in-flight audio/evidence owner. Rotation, route/source changes, mute/end
/// and deletion must invalidate it. A late embedding may not bind to newer words.
public struct VoiceEvidenceOwnership: Sendable {
    private var pending: CapturedVoiceTurn?
    private var epoch = UUID()
    public init() {}
    public mutating func begin(_ turn: CapturedVoiceTurn) -> UUID {
        epoch = UUID(); pending = turn; return epoch
    }
    public mutating func invalidate() { epoch = UUID(); pending = nil }
    public func accepts(_ evidence: VoiceEvidence, ticket: UUID, now: TimeInterval,
                        maximumAge: TimeInterval) -> Bool {
        guard ticket == epoch, pending == evidence.turn,
              now.isFinite, evidence.turn.completedAt.isFinite,
              maximumAge.isFinite, maximumAge >= 0 else { return false }
        let age = now - evidence.turn.completedAt
        return age >= 0 && age <= maximumAge
    }
    public mutating func consume(_ evidence: VoiceEvidence, ticket: UUID, now: TimeInterval,
                                 maximumAge: TimeInterval) -> Bool {
        guard accepts(evidence, ticket: ticket, now: now, maximumAge: maximumAge) else { return false }
        invalidate(); return true
    }
}

public enum VoiceAuthorityPolicy {
    /// Candidate scores/labels do not unlock action or private-history lanes.
    /// Missing calibration, replay and addressee validation are explicit blockers.
    public static func permits(_ effect: CompanionCommandEffect, evidence: VoiceEvidence) -> Bool {
        // The caller separately checks lifecycle/ownership and content-domain gates.
        // Generic chat/time is not dependent on camera or spatial sensor readiness.
        guard evidence.speaker != .rejected, evidence.addressee != .notAddressed,
              evidence.replay != .suspected else { return false }
        return CommandAuthority.permits(effect, from: evidence.turn.origin)
    }
    public static func permitsPrivateContext(evidence: VoiceEvidence) -> Bool { false }
    public static let unresolvedRequirements = ["child/headset calibration", "addressee validation", "replay/liveness validation"]
}

public enum VoiceConversationPrivacy {
    /// Current-turn-only generic conversation is an explicit release limitation,
    /// not a completed private continuous conversation feature. Trusted interface
    /// history remains in its existing separate controller path. A future verified
    /// path needs a reviewed identity/session-bound context receipt, not these labels.
    public static func anonymousTurn(_ text: String) -> AssistantDialogue {
        var dialogue = AssistantDialogue()
        dialogue.record(role: "user", text: text)
        return dialogue
    }
}
