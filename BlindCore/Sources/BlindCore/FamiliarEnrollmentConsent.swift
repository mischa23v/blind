import Foundation

/// Local consent attestation category, not proof of age, guardianship or identity.
/// Adult raw value preserves existing encrypted galleries. A child action requires
/// an explicit guardian-interface confirmation bound by FamiliarActionConfirmation.
public enum FamiliarEnrollmentConsent: String, Codable, Sendable {
    case consentingAdult = "self-or-consenting-adult"
    case guardianForChild = "guardian-consenting-child-v1"

    public var confirmationText: String {
        switch self {
        case .consentingAdult: return "Confirm this adult permits on-phone face templates and automatic tentative hints,"
        case .guardianForChild: return "The child's parent or legal guardian must explicitly permit on-phone face templates and automatic tentative hints in the helper screen,"
        }
    }
}
