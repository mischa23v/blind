import XCTest
@testable import BlindCore

final class SpeechPriorityTests: XCTestCase {
    func testDangerPreemptsEveryProducer() {
        for priority in [SpeechPriority.status, .information, .mobility, .danger] {
            XCTAssertTrue(SpeechPriority.danger.canInterrupt(priority))
        }
    }
    func testMobilityPreemptsDescriptionButNotAnotherMobilityCueOrDanger() {
        XCTAssertTrue(SpeechPriority.mobility.canInterrupt(.information))
        XCTAssertTrue(SpeechPriority.mobility.canInterrupt(.status))
        XCTAssertFalse(SpeechPriority.mobility.canInterrupt(.mobility))
        XCTAssertFalse(SpeechPriority.mobility.canInterrupt(.danger))
    }
    func testOrdinaryProducersWaitForCompletionInsteadOfInterruptingOneAnother() {
        for incoming in [SpeechPriority.status, .information] {
            XCTAssertTrue(incoming.canInterrupt(nil))
            for active in [SpeechPriority.status, .information, .mobility, .danger] {
                XCTAssertFalse(incoming.canInterrupt(active))
            }
        }
    }
}
