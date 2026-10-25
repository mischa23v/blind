/// Provenance is assigned at the input boundary, never inferred from words,
/// acoustic energy, a familiar face, a name, or a model's identity claim.
/// This release has no verified-speaker backend. Even speech following a tap,
/// an offer, or a confirmation prompt remains unverified microphone input.
public enum CompanionCommandOrigin: String, CaseIterable, Equatable, Sendable {
    case trustedInterface
    case unverifiedMicrophone
    case modelOutput
    case observedContent
    case unknown
}

public enum CompanionCommandEffect: String, CaseIterable, Equatable, Sendable {
    case conversation
    case interruptOrdinarySpeech
    case changeGoal
    case cancelTaskOrNavigation
    case startReturn
    case changeMonitoring
    case requestPhysicalGuidance
    case commitUserReport
}

/// Small app-specific authorization adapter around existing input and evidence
/// policies, not a recognizer. Permission to request guidance is never evidence
/// that guidance is safe: target, pose, age and hazard gates still apply.
/// Independent local hazard alerts do not consult this command policy.
public enum CommandAuthority {
    public static func permits(_ effect: CompanionCommandEffect,
                               from origin: CompanionCommandOrigin) -> Bool {
        switch origin {
        case .trustedInterface:
            return true
        case .unverifiedMicrophone:
            return effect == .conversation || effect == .interruptOrdinarySpeech
        case .modelOutput, .observedContent, .unknown:
            return false
        }
    }
}
