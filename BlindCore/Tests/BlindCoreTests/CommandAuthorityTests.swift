import XCTest
@testable import BlindCore

final class CommandAuthorityTests: XCTestCase {
    func testMicrophoneMayConverseAndInterruptOrdinarySpeechOnly() {
        for effect in CompanionCommandEffect.allCases {
            XCTAssertEqual(CommandAuthority.permits(effect, from: .unverifiedMicrophone),
                effect == .conversation || effect == .interruptOrdinarySpeech, effect.rawValue)
        }
    }

    func testTrustedInterfaceStillRequestsActionsSubjectToSeparateEvidenceGates() {
        for effect in CompanionCommandEffect.allCases {
            XCTAssertTrue(CommandAuthority.permits(effect, from: .trustedInterface), effect.rawValue)
        }
    }

    func testModelObservedAndUnknownSourcesNeverAcquireCommandAuthority() {
        for origin: CompanionCommandOrigin in [.modelOutput, .observedContent, .unknown] {
            for effect in CompanionCommandEffect.allCases {
                XCTAssertFalse(CommandAuthority.permits(effect, from: origin), "\(origin): \(effect)")
            }
        }
    }

    func testNoReleaseOriginClaimsVerifiedSpeakerIdentity() {
        XCTAssertEqual(Set(CompanionCommandOrigin.allCases.map(\.rawValue)),
            ["trustedInterface", "unverifiedMicrophone", "modelOutput", "observedContent", "unknown"])
    }

    func testAmbientCommandsCannotAlterAnExistingNavigationState() {
        // Policy harness, not an execution of the iOS controller or microphone.
        for origin: CompanionCommandOrigin in [.unverifiedMicrophone, .modelOutput, .observedContent, .unknown] {
            var goal = "bathroom"
            var routeActive = true
            var returnActive = false
            var monitoringActive = true
            if CommandAuthority.permits(.changeGoal, from: origin) { goal = "exit" }
            if CommandAuthority.permits(.cancelTaskOrNavigation, from: origin) { routeActive = false }
            if CommandAuthority.permits(.startReturn, from: origin) { returnActive = true }
            if CommandAuthority.permits(.changeMonitoring, from: origin) { monitoringActive = false }
            XCTAssertEqual(goal, "bathroom")
            XCTAssertTrue(routeActive)
            XCTAssertFalse(returnActive)
            XCTAssertTrue(monitoringActive)
        }
    }
}
