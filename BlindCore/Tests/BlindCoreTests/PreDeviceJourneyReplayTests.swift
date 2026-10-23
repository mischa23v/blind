import XCTest
@testable import BlindCore

/// Synthetic camera/recognizer adapters, executing the actual production admission,
/// session, freshness and task policies. This is NOT ARKit, recognition or latency QA.
final class PreDeviceJourneyReplayTests: XCTestCase {
    func testLongMemoryJobsCannotStarveGoalRelevantSignAndPrivateAudioStaysHeld() throws {
        var slots = BackgroundPerceptionAdmission()
        var session = AssistantSession(); session.start()
        var scheduler = ContextualCapabilityScheduler()
        let generation = UUID(), request = UUID()
        var counts: [BackgroundPerceptionAdmission.Producer: Int] = [:]
        var now = 10.0
        for _ in 0..<8 {
            let slot = try XCTUnwrap(slots.reserve(eligible: [.passiveMemory, .contextual], generation: generation, now: now))
            counts[slot.producer, default: 0] += 1
            if slot.producer == .contextual {
                let moment = ContextualCapabilityScheduler.Moment(now: now, requestID: request,
                    perceptionGeneration: generation, sessionGeneration: session.generation, goalGeneration: "visit-library")
                let job = try XCTUnwrap(scheduler.reserve(goal: .targetDiscovery, evidence: .init(capturedAt: now),
                    moment: moment, availability: [.text: .available]))
                XCTAssertNotNil(ContextualTextPolicy.select([.init(text: "Library", confidence: 0.95, x: 0.3, y: 0.4)],
                    goalText: "Go to the library", unrestrictedReading: false))
                XCTAssertTrue(scheduler.beforeSpeech(job, moment: moment, evidence: .init(capturedAt: now, textCandidate: true),
                    goal: .targetDiscovery, availability: [.text: .available]))
                scheduler.finish(job, outcome: .success, now: now)
                session.losePrivateAudioRoute()
                XCTAssertFalse(session.maySpeakOrdinary)
                XCTAssertTrue(session.shouldRunCamera)
            }
            // A 3.1 second memory producer repeatedly occupies more than its old
            // three-second polling interval; fair admission must still rotate.
            now += 3.1
            XCTAssertTrue(slots.accepts(slot, generation: generation, now: now))
            XCTAssertTrue(slots.finish(slot, now: now))
            now += 10
        }
        XCTAssertEqual(counts[.contextual], 4)
        XCTAssertEqual(counts[.passiveMemory], 4)
        session.enterBackground(); session.enterForeground()
        XCTAssertFalse(session.maySpeakOrdinary)
        session.start(); XCTAssertTrue(session.maySpeakOrdinary)
    }

    func testLateRecognitionAfterInterruptionCannotTakeSuccessorResourceOrSpeak() throws {
        var slots = BackgroundPerceptionAdmission()
        let oldGeneration = UUID(), newGeneration = UUID()
        let old = try XCTUnwrap(slots.reserve(eligible: [.contextual], generation: oldGeneration, now: 10))
        slots.invalidate()
        XCTAssertNil(slots.reserve(eligible: [.contextual, .passiveMemory], generation: newGeneration, now: 11))
        XCTAssertEqual(slots.expire(now: 16), old)
        let fresh = try XCTUnwrap(slots.reserve(eligible: [.contextual, .passiveMemory], generation: newGeneration, now: 16))
        XCTAssertEqual(fresh.producer, .passiveMemory)
        XCTAssertFalse(slots.accepts(old, generation: newGeneration, now: 16.1))
        XCTAssertFalse(slots.finish(old, now: 16.1))
        XCTAssertEqual(slots.activeLease, fresh)
        XCTAssertFalse(FrameTimestampPolicy.isFresh(capturedAt: 10, receivedAt: 16.1))
    }

    func testCameraRecoveryDoesNotResetAtEveryErrorOrForegroundReturn() throws {
        var recovery = CameraRecoveryPolicy(); recovery.beginExplicitSession()
        var time = 0.0
        for delay in CameraRecoveryPolicy.retryDelays {
            let retry = try XCTUnwrap(recovery.schedule(now: time, foregroundActive: true, cameraEnabled: true, authorized: true))
            XCTAssertEqual(retry.readyAt, time + delay)
            for offset in [0.1, 0.2, 0.5] {
                XCTAssertNil(recovery.schedule(now: time + offset, foregroundActive: true, cameraEnabled: true, authorized: true))
            }
            time += delay
            XCTAssertTrue(recovery.claim(retry, now: time, foregroundActive: true, cameraEnabled: true, authorized: true))
            time += 1
        }
        recovery.pause()
        XCTAssertNil(recovery.schedule(now: time, foregroundActive: true, cameraEnabled: true, authorized: true))
        recovery.beginExplicitSession()
        XCTAssertNotNil(recovery.schedule(now: time + 1, foregroundActive: true, cameraEnabled: true, authorized: true))
    }
}
