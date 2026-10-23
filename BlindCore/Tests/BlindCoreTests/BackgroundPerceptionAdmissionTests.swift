import XCTest
@testable import BlindCore

final class BackgroundPerceptionAdmissionTests: XCTestCase {
    private typealias Policy = BackgroundPerceptionAdmission
    private let generation = UUID()
    private var both: Set<Policy.Producer> { [.passiveMemory, .contextual] }

    func testIdleAndUnavailableWorkDoNotTakeASlot() throws {
        var policy = Policy()
        XCTAssertNil(policy.reserve(eligible: [], generation: generation, now: 10))
        let lease = try XCTUnwrap(policy.reserve(eligible: [.passiveMemory], generation: generation, now: 10))
        XCTAssertEqual(lease.producer, .passiveMemory)
        XCTAssertTrue(policy.accepts(lease, generation: generation, now: 10))
    }

    func testOnlyOneJobAdmittedAndBothEligibleProducersAlternate() throws {
        var policy = Policy()
        for index in 0..<12 {
            let now = 10 + Double(index) * 2
            let lease = try XCTUnwrap(policy.reserve(eligible: both, generation: generation, now: now))
            XCTAssertEqual(lease.producer, index.isMultiple(of: 2) ? .contextual : .passiveMemory)
            XCTAssertNil(policy.reserve(eligible: both, generation: generation, now: now + 0.1))
            XCTAssertEqual(policy.activeLease, lease)
            XCTAssertTrue(policy.finish(lease, now: now + 1))
        }
    }

    func testSlowMemoryCannotReclaimEveryDueFrameAheadOfContextualWork() throws {
        var policy = Policy()
        // Passive work's old three-second cadence has already elapsed at completion.
        // It remains eligible on every next frame, but cannot starve contextual work.
        let memory = try XCTUnwrap(policy.reserve(eligible: [.passiveMemory], generation: generation, now: 10))
        XCTAssertTrue(policy.finish(memory, now: 13.5))
        for index in 0..<8 {
            let now = 13.6 + Double(index) * 4
            let lease = try XCTUnwrap(policy.reserve(eligible: both, generation: generation, now: now))
            XCTAssertEqual(lease.producer, index.isMultiple(of: 2) ? .contextual : .passiveMemory)
            XCTAssertTrue(policy.finish(lease, now: now + 3.5))
        }
    }

    func testSingleEligibleProducerCanRunWithoutWaitingForOtherTurn() throws {
        var policy = Policy()
        for index in 0..<5 {
            let now = 10 + Double(index)
            let lease = try XCTUnwrap(policy.reserve(eligible: [.contextual], generation: generation, now: now))
            XCTAssertEqual(lease.producer, .contextual)
            XCTAssertTrue(policy.finish(lease, now: now + 0.5))
        }
        XCTAssertEqual(policy.reserve(eligible: both, generation: generation, now: 15)?.producer, .passiveMemory)
    }

    func testCancellationRetiresOutputButKeepsNativeSlotUntilCompletion() throws {
        var policy = Policy()
        let lease = try XCTUnwrap(policy.reserve(eligible: both, generation: generation, now: 10))
        policy.invalidate()
        XCTAssertFalse(policy.accepts(lease, generation: generation, now: 10.1))
        XCTAssertNil(policy.reserve(eligible: both, generation: generation, now: 10.2))
        XCTAssertEqual(policy.activeLease, lease)
        XCTAssertTrue(policy.finish(lease, now: 11))
        let next = try XCTUnwrap(policy.reserve(eligible: both, generation: generation, now: 11.1))
        XCTAssertNotEqual(next.id, lease.id)
        XCTAssertTrue(policy.accepts(next, generation: generation, now: 11.2))
        XCTAssertFalse(policy.finish(lease, now: 11.3))
        XCTAssertEqual(policy.activeLease, next)
    }

    func testGenerationChangeCannotRecycleAnUnfinishedNativeJob() throws {
        var policy = Policy()
        let lease = try XCTUnwrap(policy.reserve(eligible: both, generation: generation, now: 10))
        let replacement = UUID()
        XCTAssertFalse(policy.accepts(lease, generation: replacement, now: 10.1))
        XCTAssertNil(policy.reserve(eligible: both, generation: replacement, now: 10.2))
        // Even a mistaken return to the old generation cannot revive retired output.
        XCTAssertFalse(policy.accepts(lease, generation: generation, now: 10.3))
        XCTAssertTrue(policy.finish(lease, now: 11))
        let next = try XCTUnwrap(policy.reserve(eligible: both, generation: replacement, now: 11.1))
        XCTAssertEqual(next.generation, replacement)
        XCTAssertTrue(policy.accepts(next, generation: replacement, now: 11.2))
    }

    func testTimeoutDisablesStalledProducerAndAllowsOnlyOtherProducer() throws {
        var policy = Policy()
        let stuck = try XCTUnwrap(policy.reserve(eligible: [.passiveMemory], generation: generation, now: 10))
        XCTAssertNil(policy.expire(now: 15.999))
        XCTAssertEqual(policy.expire(now: 16), stuck)
        XCTAssertEqual(policy.disabledProducers, [.passiveMemory])
        XCTAssertNil(policy.reserve(eligible: [.passiveMemory], generation: generation, now: 16.1))
        let other = try XCTUnwrap(policy.reserve(eligible: both, generation: generation, now: 16.2))
        XCTAssertEqual(other.producer, .contextual)
        XCTAssertFalse(policy.accepts(stuck, generation: generation, now: 16.3))
        XCTAssertFalse(policy.finish(stuck, now: 16.4))
        XCTAssertEqual(policy.activeLease, other)
        XCTAssertEqual(policy.disabledProducers, [.passiveMemory])
    }

    func testCancelledStalledWorkStillTimesOutWithoutReplacementPileup() throws {
        var policy = Policy()
        let stuck = try XCTUnwrap(policy.reserve(eligible: both, generation: generation, now: 10))
        policy.invalidate()
        for step in 1..<6 {
            policy.invalidate()
            XCTAssertNil(policy.reserve(eligible: both, generation: UUID(), now: 10 + Double(step)))
        }
        let next = try XCTUnwrap(policy.reserve(eligible: both, generation: UUID(), now: 16))
        XCTAssertNotEqual(next.producer, stuck.producer)
        XCTAssertEqual(policy.disabledProducers, [stuck.producer])
    }

    func testCompletionAtOrBeyondTimeoutCannotReenableProducer() throws {
        for end in [16.0, 20] {
            var policy = Policy()
            let lease = try XCTUnwrap(policy.reserve(eligible: [.contextual], generation: generation, now: 10))
            XCTAssertFalse(policy.accepts(lease, generation: generation, now: end))
            XCTAssertFalse(policy.finish(lease, now: end))
            XCTAssertEqual(policy.disabledProducers, [.contextual])
            policy.invalidate()
            XCTAssertNil(policy.reserve(eligible: [.contextual], generation: UUID(), now: end + 1))
        }
    }

    func testBothStalledProducersStopRatherThanCreatingAnUnboundedQueue() throws {
        var policy = Policy()
        let first = try XCTUnwrap(policy.reserve(eligible: both, generation: generation, now: 10))
        let second = try XCTUnwrap(policy.reserve(eligible: both, generation: generation, now: 16))
        XCTAssertNotEqual(first.producer, second.producer)
        XCTAssertNil(policy.reserve(eligible: both, generation: generation, now: 22))
        XCTAssertEqual(policy.disabledProducers, both)
        XCTAssertFalse(policy.finish(first, now: 23))
        XCTAssertFalse(policy.finish(second, now: 24))
        XCTAssertNil(policy.reserve(eligible: both, generation: UUID(), now: 25))
    }

    func testBadClockRetiresOutputWithoutFreeingNativeWork() throws {
        for bad in [Double.nan, .infinity, -1, 9.9] {
            var policy = Policy()
            let lease = try XCTUnwrap(policy.reserve(eligible: both, generation: generation, now: 10))
            XCTAssertFalse(policy.accepts(lease, generation: generation, now: bad))
            XCTAssertNil(policy.reserve(eligible: both, generation: generation, now: bad))
            XCTAssertEqual(policy.activeLease, lease)
            XCTAssertFalse(policy.accepts(lease, generation: generation, now: 10.1))
            XCTAssertTrue(policy.finish(lease, now: 11))
            XCTAssertTrue(policy.disabledProducers.isEmpty)
        }
    }

    func testDuplicateCompletionCannotAffectSuccessorOrFairness() throws {
        var policy = Policy()
        let first = try XCTUnwrap(policy.reserve(eligible: both, generation: generation, now: 10))
        XCTAssertTrue(policy.finish(first, now: 11))
        let second = try XCTUnwrap(policy.reserve(eligible: both, generation: generation, now: 12))
        XCTAssertFalse(policy.finish(first, now: 12.1))
        // Irrelevant late callbacks do not even advance the successor's clock or
        // expire its resource slot. Only its own completion/watchdog can do that.
        XCTAssertFalse(policy.finish(first, now: 100))
        XCTAssertEqual(policy.activeLease, second)
        XCTAssertTrue(policy.finish(second, now: 13))
        XCTAssertEqual(policy.reserve(eligible: both, generation: generation, now: 14)?.producer, first.producer)
    }

    func testInvalidTimeoutUsesBoundedDefault() {
        for timeout in [Double.nan, .infinity, -1, 0] {
            XCTAssertEqual(Policy(timeout: timeout).timeout, Policy.defaultTimeout)
        }
        XCTAssertEqual(Policy(timeout: 2).timeout, 2)
    }
}
