import XCTest
@testable import BlindCore

final class PassiveSceneDeliveryTests: XCTestCase {
    private func observation(_ text: String, kind: SceneObservation.Kind = .text, id: String = "source", at: Double = 10) -> SceneObservation {
        .init(id: id, kind: kind, text: text, confidence: 0.9, capturedAt: at)
    }
    private func signature(_ text: String) -> PassiveSceneDelivery.Signature {
        PassiveSceneDelivery.signature(observations: [observation(text)], confirmedObjects: [])!
    }
    func testNormalizedEvidenceIgnoresCaptureIDsOrderingAndAnswerParaphrases() {
        let a = PassiveSceneDelivery.signature(observations: [observation("  OPEN\n NOW "), observation("2", kind: .people)], confirmedObjects: ["chair", "Table"])
        let b = PassiveSceneDelivery.signature(observations: [observation("2", kind: .people, id: "next", at: 20), observation("open now", id: "later", at: 20)], confirmedObjects: ["TABLE", "chair", "chair"])
        XCTAssertEqual(a, b) // no generated-answer parameter exists
        XCTAssertEqual(signature("  الباب\n مفتوح  "), signature("الباب مفتوح"))
        XCTAssertNotEqual(signature("12.50"), signature("12.05"))
        XCTAssertNotEqual(signature("not open"), signature("open"))
        XCTAssertNotEqual(signature("1"), signature("2"))
    }
    func testNoEvidenceOrRangeOnlyCannotMintAutomaticFreshness() {
        XCTAssertNil(PassiveSceneDelivery.signature(observations: [], confirmedObjects: []))
        XCTAssertNil(PassiveSceneDelivery.signature(observations: [observation(" ")], confirmedObjects: []))
        XCTAssertNil(PassiveSceneDelivery.signature(observations: [observation("distance changed", kind: .range)], confirmedObjects: []))
        XCTAssertNotNil(PassiveSceneDelivery.signature(observations: [], confirmedObjects: ["chair"]))
    }
    func testOnlyCompletedExactPlaybackConsumesEvidence() {
        var policy = PassiveSceneDelivery()
        let a = signature("A"), id = UUID()
        XCTAssertTrue(policy.allows(a, owner: "session-camera-room"))
        XCTAssertTrue(policy.begin(id: id, signature: a, owner: "session-camera-room"))
        XCTAssertFalse(policy.allows(a, owner: "session-camera-room"))
        XCTAssertFalse(policy.finish(id: UUID(), completed: true, currentOwner: "session-camera-room"))
        XCTAssertTrue(policy.finish(id: id, completed: false, currentOwner: "session-camera-room"))
        XCTAssertTrue(policy.allows(a, owner: "session-camera-room"))
        XCTAssertTrue(policy.begin(id: id, signature: a, owner: "session-camera-room"))
        XCTAssertTrue(policy.finish(id: id, completed: true, currentOwner: "session-camera-room"))
        XCTAssertFalse(policy.allows(a, owner: "session-camera-room"))
    }
    func testChangedEvidenceAndReturnToEarlierContentRemainAdmissible() {
        var policy = PassiveSceneDelivery()
        for text in ["A", "B", "A"] {
            let id = UUID(), value = signature(text)
            XCTAssertTrue(policy.begin(id: id, signature: value, owner: "same-owner"))
            XCTAssertTrue(policy.finish(id: id, completed: true, currentOwner: "same-owner"))
            XCTAssertFalse(policy.allows(value, owner: "same-owner"))
        }
    }
    func testCancelledOldCallbackCannotConsumeSuccessor() {
        var policy = PassiveSceneDelivery()
        let old = UUID(), next = UUID(), a = signature("A")
        XCTAssertTrue(policy.begin(id: old, signature: a, owner: "owner"))
        XCTAssertEqual(policy.cancelPending(), old)
        XCTAssertTrue(policy.begin(id: next, signature: a, owner: "owner"))
        XCTAssertFalse(policy.finish(id: old, completed: true, currentOwner: "owner"))
        XCTAssertFalse(policy.allows(a, owner: "owner"))
        XCTAssertTrue(policy.finish(id: next, completed: false, currentOwner: "owner"))
        XCTAssertTrue(policy.allows(a, owner: "owner"))
    }
    func testRoomVisitSessionAndSourceChangeRejectOldCompletion() {
        for changed in ["session2-camera1-room1", "session1-camera2-room1", "session1-camera1-room2", "session1-camera1-room1-visit2"] {
            var policy = PassiveSceneDelivery()
            let id = UUID(), a = signature("A")
            XCTAssertTrue(policy.begin(id: id, signature: a, owner: "session1-camera1-room1"))
            XCTAssertTrue(policy.finish(id: id, completed: true, currentOwner: changed))
            XCTAssertTrue(policy.allows(a, owner: changed))
            let next = UUID()
            XCTAssertTrue(policy.begin(id: next, signature: a, owner: changed))
            XCTAssertFalse(policy.finish(id: id, completed: true, currentOwner: changed))
            XCTAssertTrue(policy.finish(id: next, completed: true, currentOwner: changed))
            XCTAssertFalse(policy.allows(a, owner: changed))
        }
    }
    func testBoundedInputsRejectRatherThanTruncate() {
        XCTAssertNil(PassiveSceneDelivery.signature(observations: Array(repeating: observation("x"), count: 33), confirmedObjects: []))
        XCTAssertNil(PassiveSceneDelivery.signature(observations: [], confirmedObjects: Array(repeating: "x", count: 129)))
        XCTAssertNil(PassiveSceneDelivery.signature(observations: [observation(String(repeating: "x", count: 2049))], confirmedObjects: []))
        var policy = PassiveSceneDelivery()
        XCTAssertFalse(policy.allows(signature("A"), owner: ""))
        XCTAssertFalse(policy.allows(signature("A"), owner: String(repeating: "x", count: 2049)))
    }
    func testActualCompanionAndSpeechLedgerCancellationRetryCompletionAndBypasses() {
        var novelty = PassiveSceneDelivery(), companion = CompanionAttention(), speech = SpeechDeliveryLedger()
        let evidence = signature("Welcome"), owner = "session-camera-room"
        let settings = CompanionSettings(minimumGap: 10, wordsPerMinute: 100)
        func candidate(_ id: UUID, at time: Double, requested: Bool = false) -> InformationCandidate {
            .init(key: "passive-scene:" + id.uuidString, kind: requested ? .answer : .discovery,
                  text: "Welcome", words: 1, revision: id.uuidString, createdAt: time,
                  expiresAt: time + 6, requested: requested)
        }
        for (time, outcome) in [(10.0, NarrationDelivery.interrupted), (21.0, .completed)] {
            let id = UUID(), item = candidate(id, at: time)
            XCTAssertTrue(novelty.begin(id: id, signature: evidence, owner: owner))
            guard case .say = companion.decide([item], moment: .init(now: time), settings: settings).first else {
                return XCTFail("Normal companion admission unexpectedly rejected")
            }
            let attempt = speech.begin(text: item.text, priority: item.priority,
                                       destination: .narration(id), transport: .synthesized)!
            let completion = speech.finish(token: attempt.token, outcome: outcome, now: time + 1)!
            guard case .narration(let finishedID) = completion.attempt.destination else { return XCTFail() }
            novelty.finish(id: finishedID, completed: completion.outcome == .completed, currentOwner: owner)
            companion.release(item.key)
            XCTAssertEqual(novelty.allows(evidence, owner: owner), outcome != .completed)
            if outcome == .interrupted {
                // A new companion key must not bypass the ordinary rate gate.
                XCTAssertEqual(companion.check(candidate(UUID(), at: time + 2), moment: .init(now: time + 2), settings: settings).reason, .tooSoon)
            }
        }
        XCTAssertFalse(novelty.allows(evidence, owner: owner))
        XCTAssertEqual(companion.check(candidate(UUID(), at: 23, requested: true), moment: .init(now: 23), settings: settings).reason, .requested)
        let hazard = InformationCandidate(key: "sensor", kind: .hazard, text: "Warning", words: 1,
                                          createdAt: 23, expiresAt: 24)
        XCTAssertEqual(companion.check(hazard, moment: .init(now: 23, speaking: .information), settings: settings).reason, .hazard)
    }

}
