import XCTest
@testable import BlindCore

final class ContextualCapabilitySchedulerTests: XCTestCase {
    private typealias Policy = ContextualCapabilityScheduler
    private let request = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let perception = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    private var all: [Policy.Capability: Policy.Availability] {
        Dictionary(uniqueKeysWithValues: Policy.Capability.allCases.map { ($0, .available) })
    }
    private var currency: [Policy.Capability: Policy.Availability] { [.currencyProbe: .available, .currency: .available] }
    private func moment(_ now: Double) -> Policy.Moment {
        .init(now: now, requestID: request, perceptionGeneration: perception, sessionGeneration: 3, goalGeneration: "goal-3")
    }

    func testSilentCurrencyProbeNeedsNoFeatureCommandOrGoal() throws {
        var policy = Policy()
        let lease = try XCTUnwrap(policy.reserve(goal: .none, evidence: .init(capturedAt: 10), moment: moment(10), availability: currency))
        XCTAssertEqual(lease.capability, .currencyProbe)
        XCTAssertEqual(lease.capturedAt, 10)
        XCTAssertEqual(lease.startedAt, 10)
        XCTAssertEqual(lease.requestID, request)
        XCTAssertEqual(lease.perceptionGeneration, perception)
        XCTAssertEqual(lease.sessionGeneration, 3)
        XCTAssertEqual(lease.goalGeneration, "goal-3")
        XCTAssertFalse(policy.beforeSpeech(lease, moment: moment(10), evidence: .init(capturedAt: 10, banknoteCandidate: true), goal: .none, availability: all))
    }

    func testUnavailableBackendsNeverCreateJobsOrImaginaryFallback() {
        for availability: [Policy.Capability: Policy.Availability] in [[:], [.currencyProbe: .available], [.currency: .available], [.currencyProbe: .available, .currency: .unavailable]] {
            var policy = Policy()
            XCTAssertNil(policy.reserve(goal: .none, evidence: .init(capturedAt: 10), moment: moment(10), availability: availability))
        }
        var policy = Policy()
        XCTAssertNil(policy.reserve(goal: [.shopping, .dressing, .lighting], evidence: .init(capturedAt: 10, lightAvailable: true), moment: moment(10), availability: [:]))
    }

    func testGeneralTaskSelectsProbesBeforeCandidateExists() throws {
        for (goal, capability): (Policy.Goal, Policy.Capability) in [(.shopping, .text), (.dining, .barcode), (.dressing, .color)] {
            var policy = Policy()
            let lease = try XCTUnwrap(policy.reserve(goal: goal, evidence: .init(capturedAt: 10), moment: moment(10), availability: [capability: .available]))
            XCTAssertEqual(lease.capability, capability)
            XCTAssertFalse(policy.beforeSpeech(lease, moment: moment(10), evidence: .init(capturedAt: 10), goal: goal, availability: [capability: .available]))
        }
    }

    func testNoTaskDoesNotStartUnselectedColorOrLightProbes() {
        for capability: Policy.Capability in [.light, .color] {
            var policy = Policy()
            XCTAssertNil(policy.reserve(goal: .none, evidence: .init(capturedAt: 10, textCandidate: true, barcodeCandidate: true, lightAvailable: true, centralIsolatedItem: true), moment: moment(10), availability: [capability: .available]))
        }
    }

    func testNoTaskStartsBoundedTextAndSavedProductDiscovery() throws {
        for capability: Policy.Capability in [.text, .barcode] {
            var policy = Policy()
            let availability: [Policy.Capability: Policy.Availability] = [capability: .available]
            let lease = try XCTUnwrap(policy.reserve(goal: .none, evidence: .init(capturedAt: 10), moment: moment(10), availability: availability))
            XCTAssertEqual(lease.capability, capability)
            XCTAssertFalse(policy.beforeSpeech(lease, moment: moment(10), evidence: .init(capturedAt: 10), goal: .none, availability: availability))
        }
        XCTAssertEqual(ContextualTextPolicy.select([.init(text: "Library", confidence: 0.95, x: 0.2, y: 0.2)], goalText: "  ", unrestrictedReading: false)?.text, "Library")
        XCTAssertNil(ContextualTextPolicy.select([.init(text: "Milk", confidence: 0.95, x: 0.2, y: 0.2)], goalText: "Find my book", unrestrictedReading: false))
    }

    func testUnsupportedRetainedTaskIsNotIdleDiscoveryPermission() {
        for text in ["Practice spelling", String(repeating: "unknown ", count: 200)] {
            let goal = Policy.Goal.infer(from: text)
            XCTAssertEqual(goal, .otherTask)
            for capability: Policy.Capability in [.text, .barcode] {
                var policy = Policy()
                XCTAssertNil(policy.reserve(goal: goal, evidence: .init(capturedAt: 10), moment: moment(10), availability: [capability: .available]))
            }
        }
        XCTAssertEqual(Policy.Goal.infer(from: "  "), .none)
    }

    func testIdleAllBackendRotationDoesNotStarveCurrencyAfterEmptyOrCancelledProbes() throws {
        for cancelFirst in [false, true] {
            var policy = Policy()
            for (now, expected): (Double, Policy.Capability) in [(10, .text), (12, .barcode), (14, .currencyProbe)] {
                let lease = try XCTUnwrap(policy.reserve(goal: .none, evidence: .init(capturedAt: now), moment: moment(now), availability: all))
                XCTAssertEqual(lease.capability, expected)
                if cancelFirst && now == 10 { policy.cancel() }
                else { policy.finish(lease, outcome: .noResult, now: now) }
                XCTAssertNil(policy.reserve(goal: .none, evidence: .init(capturedAt: now + 1), moment: moment(now + 1), availability: all), "Shared two-second gap is not replenished")
            }
        }
    }

    func testEnglishArabicGeneralGoalsWithoutFeatureSyntax() {
        XCTAssertTrue(Policy.Goal.infer(from: "I want to buy groceries").contains(.shopping))
        XCTAssertTrue(Policy.Goal.infer(from: "Get dressed for school").contains(.dressing))
        XCTAssertTrue(Policy.Goal.infer(from: "Find the restaurant for lunch").contains(.dining))
        XCTAssertTrue(Policy.Goal.infer(from: "Read my homework").contains(.reading))
        XCTAssertTrue(Policy.Goal.infer(from: "Turn on the lights").contains(.lighting))
        XCTAssertTrue(Policy.Goal.infer(from: "Pay for my food").contains(.payment))
        XCTAssertTrue(Policy.Goal.infer(from: "أريد شراء الطعام").contains(.shopping))
        XCTAssertTrue(Policy.Goal.infer(from: "أريد أن ألبس ملابس المدرسة").contains(.dressing))
        XCTAssertTrue(Policy.Goal.infer(from: "أريد أن أقرأ الواجب").contains(.reading))
        XCTAssertEqual(Policy.Goal.infer(from: "Find the bathroom"), .targetDiscovery)
        XCTAssertEqual(Policy.Goal.infer(from: "flight friendship highlighting"), .otherTask)
        XCTAssertEqual(Policy.Goal.infer(from: String(repeating: "buy ", count: 301)), .otherTask)
    }

    func testFindingAnObjectNeverGrantsUnrestrictedReading() {
        for goal in ["find my book", "find the document", "find the page", "find my reading glasses", "find the label", "finish my homework", "ابحث عن الكتاب", "أجد ورقة الواجب"] {
            XCTAssertFalse(Policy.Goal.infer(from: goal).contains(.reading), goal)
        }
        XCTAssertTrue(Policy.Goal.infer(from: "I am reading a book").contains(.reading))
        XCTAssertTrue(Policy.Goal.infer(from: "I want to read this page").contains(.reading))
    }

    func testLightRequiresActualMeasurementAndRelevantGoal() throws {
        var policy = Policy()
        XCTAssertNil(policy.reserve(goal: .lighting, evidence: .init(capturedAt: 10), moment: moment(10), availability: [.light: .available]))
        let lease = try XCTUnwrap(policy.reserve(goal: .lighting, evidence: .init(capturedAt: 10, lightAvailable: true), moment: moment(10), availability: [.light: .available]))
        XCTAssertTrue(policy.beforeSpeech(lease, moment: moment(10.1), evidence: .init(capturedAt: 10, lightAvailable: true), goal: .lighting, availability: [.light: .available]))
    }

    func testColorNeedsCentralIsolatedItemNotAnOutfitOrWholeFrame() throws {
        var policy = Policy()
        let lease = try XCTUnwrap(policy.reserve(goal: .dressing, evidence: .init(capturedAt: 10), moment: moment(10), availability: [.color: .available]))
        XCTAssertFalse(policy.beforeSpeech(lease, moment: moment(10.1), evidence: .init(capturedAt: 10), goal: .dressing, availability: [.color: .available]))
        XCTAssertTrue(policy.beforeSpeech(lease, moment: moment(10.2), evidence: .init(capturedAt: 10, centralIsolatedItem: true), goal: .dressing, availability: [.color: .available]))
        XCTAssertFalse(policy.beforeSpeech(lease, moment: moment(10.3), evidence: .init(capturedAt: 10, centralIsolatedItem: true), goal: .dressing, availability: [.color: .available]))
    }

    func testOCRAndBarcodeRequireObservedOutputEvidence() throws {
        for capability: Policy.Capability in [.text, .barcode] {
            var policy = Policy()
            let lease = try XCTUnwrap(policy.reserve(goal: .shopping, evidence: .init(capturedAt: 10), moment: moment(10), availability: [capability: .available]))
            XCTAssertFalse(policy.beforeSpeech(lease, moment: moment(10.1), evidence: .init(capturedAt: 10), goal: .shopping, availability: [capability: .available]))
            let evidence = Policy.Evidence(capturedAt: 10, textCandidate: capability == .text, barcodeCandidate: capability == .barcode)
            XCTAssertTrue(policy.beforeSpeech(lease, moment: moment(10.2), evidence: evidence, goal: .shopping, availability: [capability: .available]))
        }
    }

    func testPromotionKeepsOriginalCaptureIdentityAndSingleLease() throws {
        var policy = Policy()
        let probe = try XCTUnwrap(policy.reserve(goal: .none, evidence: .init(capturedAt: 10), moment: moment(10), availability: currency))
        let evidence = Policy.Evidence(capturedAt: 10, banknoteCandidate: true)
        let verifiedJob = try XCTUnwrap(policy.promoteCurrencyCandidate(probe, evidence: evidence, moment: moment(10.2), availability: currency))
        XCTAssertEqual(verifiedJob.capability, .currency)
        XCTAssertEqual(verifiedJob.id, probe.id)
        XCTAssertEqual(verifiedJob.startedAt, probe.startedAt)
        XCTAssertEqual(verifiedJob.capturedAt, probe.capturedAt)
        XCTAssertFalse(policy.beforeSpeech(probe, moment: moment(10.2), evidence: evidence, goal: .none, availability: currency))
        XCTAssertTrue(policy.beforeSpeech(verifiedJob, moment: moment(10.3), evidence: evidence, goal: .none, availability: currency))
        XCTAssertNil(policy.reserve(goal: .shopping, evidence: .init(capturedAt: 10.4), moment: moment(10.4), availability: all))
    }

    func testCandidateCannotPromoteFromDifferentFrameOrWithoutVerifier() throws {
        for mode in 0..<4 {
            var policy = Policy()
            let probe = try XCTUnwrap(policy.reserve(goal: .none, evidence: .init(capturedAt: 10), moment: moment(10), availability: currency))
            let evidence = Policy.Evidence(capturedAt: mode == 0 ? 10.1 : 10, banknoteCandidate: mode != 1, source: mode == 2 ? .languageModel : .onDevice)
            XCTAssertNil(policy.promoteCurrencyCandidate(probe, evidence: evidence, moment: moment(10.1), availability: mode == 3 ? [.currencyProbe: .available] : currency))
            XCTAssertNil(policy.activeLease)
        }
    }

    func testCurrencyCandidateDirectlySelectsVerifierButIsNotItselfSpeech() throws {
        var policy = Policy()
        let lease = try XCTUnwrap(policy.reserve(goal: .none, evidence: .init(capturedAt: 10, banknoteCandidate: true), moment: moment(10), availability: [.currency: .available]))
        XCTAssertEqual(lease.capability, .currency)
        XCTAssertFalse(policy.beforeSpeech(lease, moment: moment(10), evidence: .init(capturedAt: 10), goal: .none, availability: [.currency: .available]))
    }

    func testOnlyOneBackgroundJobCanRun() throws {
        var policy = Policy()
        let first = try XCTUnwrap(policy.reserve(goal: .shopping, evidence: .init(capturedAt: 10), moment: moment(10), availability: all))
        XCTAssertNil(policy.reserve(goal: .shopping, evidence: .init(capturedAt: 10.1), moment: moment(10.1), availability: all))
        XCTAssertEqual(policy.activeLease, first)
    }

    func testLifecycleAndAttentionExcludeAdmissionAndPermanentlyInvalidateOutput() throws {
        let exclusions: [(inout Policy.Moment) -> Void] = [
            { $0.cameraEnabled = false }, { $0.sessionActive = false }, { $0.foregroundActive = false },
            { $0.hazardActive = true }, { $0.listening = true }, { $0.busy = true }
        ]
        for exclude in exclusions {
            var disabled = moment(10); exclude(&disabled)
            var policy = Policy()
            XCTAssertNil(policy.reserve(goal: .reading, evidence: .init(capturedAt: 10), moment: disabled, availability: all))
            let lease = try XCTUnwrap(policy.reserve(goal: .reading, evidence: .init(capturedAt: 10), moment: moment(10), availability: [.text: .available]))
            XCTAssertFalse(policy.beforeSpeech(lease, moment: disabled, evidence: .init(capturedAt: 10, textCandidate: true), goal: .reading, availability: all))
            XCTAssertNil(policy.activeLease)
            XCTAssertFalse(policy.beforeSpeech(lease, moment: moment(10.1), evidence: .init(capturedAt: 10, textCandidate: true), goal: .reading, availability: all))
        }
    }

    func testHazardDuringProbeInvalidatesPromotionEvenAfterItClears() throws {
        var policy = Policy()
        let probe = try XCTUnwrap(policy.reserve(goal: .none, evidence: .init(capturedAt: 10), moment: moment(10), availability: currency))
        var danger = moment(10.1); danger.hazardActive = true
        XCTAssertNil(policy.promoteCurrencyCandidate(probe, evidence: .init(capturedAt: 10, banknoteCandidate: true), moment: danger, availability: currency))
        XCTAssertNil(policy.promoteCurrencyCandidate(probe, evidence: .init(capturedAt: 10, banknoteCandidate: true), moment: moment(10.2), availability: currency))
    }

    func testAllGenerationChangesInvalidatePendingSpeech() throws {
        let changes: [(inout Policy.Moment) -> Void] = [
            { $0.requestID = UUID() }, { $0.perceptionGeneration = UUID() },
            { $0.sessionGeneration += 1 }, { $0.goalGeneration = "other" }
        ]
        for change in changes {
            var policy = Policy()
            let lease = try XCTUnwrap(policy.reserve(goal: .reading, evidence: .init(capturedAt: 10), moment: moment(10), availability: all))
            var changed = moment(10.1); change(&changed)
            XCTAssertFalse(policy.beforeSpeech(lease, moment: changed, evidence: .init(capturedAt: 10, textCandidate: true), goal: .reading, availability: all))
            XCTAssertNil(policy.activeLease)
        }
    }

    func testChangedGoalFailsEvenIfCallerForgotToReviseGeneration() throws {
        var policy = Policy()
        let lease = try XCTUnwrap(policy.reserve(goal: .reading, evidence: .init(capturedAt: 10), moment: moment(10), availability: all))
        XCTAssertFalse(policy.beforeSpeech(lease, moment: moment(10.1), evidence: .init(capturedAt: 10, textCandidate: true), goal: .shopping, availability: all))
    }

    func testFreshFrameBoundariesAndNonDeviceEvidence() {
        for frame in [Double.nan, Double.infinity, -1, 10.01, 9.4999] {
            var policy = Policy()
            XCTAssertNil(policy.reserve(goal: .reading, evidence: .init(capturedAt: frame), moment: moment(10), availability: all))
        }
        for source: Policy.EvidenceSource in [.languageModel, .unknown] {
            var policy = Policy()
            XCTAssertNil(policy.reserve(goal: .reading, evidence: .init(capturedAt: 10, source: source), moment: moment(10), availability: all))
        }
        var policy = Policy()
        XCTAssertNotNil(policy.reserve(goal: .reading, evidence: .init(capturedAt: 9.5), moment: moment(10), availability: all))
    }

    func testDeliveryCannotRefreshCaptureOrUseModelEvidence() throws {
        for mode in 0..<3 {
            var policy = Policy()
            let lease = try XCTUnwrap(policy.reserve(goal: .reading, evidence: .init(capturedAt: 10), moment: moment(10), availability: all))
            let evidence = Policy.Evidence(capturedAt: mode == 0 ? 10.1 : 10, textCandidate: true, source: mode == 1 ? .languageModel : .onDevice)
            XCTAssertFalse(policy.beforeSpeech(lease, moment: moment(10.1), evidence: evidence, goal: .reading, availability: mode == 2 ? [:] : all))
            XCTAssertNil(policy.activeLease)
        }
    }

    func testResultFreshnessIsCaptureBasedAndCurrencyIsStricter() throws {
        for (capability, goal, maximum): (Policy.Capability, Policy.Goal, Double) in [(.text, .reading, 4), (.currency, .none, 2)] {
            for extra in [0.0, 0.001] {
                var policy = Policy()
                let evidence = Policy.Evidence(capturedAt: 10, banknoteCandidate: true, textCandidate: true)
                let lease = try XCTUnwrap(policy.reserve(goal: goal, evidence: evidence, moment: moment(10.5), availability: [capability: .available]))
                XCTAssertEqual(policy.beforeSpeech(lease, moment: moment(10 + maximum + extra), evidence: evidence, goal: goal, availability: [capability: .available]), extra == 0)
            }
        }
    }

    func testInvalidOrRegressingClockFailsClosed() throws {
        for time in [Double.nan, Double.infinity, -1, 9.99] {
            var policy = Policy()
            let lease = try XCTUnwrap(policy.reserve(goal: .reading, evidence: .init(capturedAt: 10), moment: moment(10), availability: all))
            XCTAssertFalse(policy.beforeSpeech(lease, moment: moment(time), evidence: .init(capturedAt: 10, textCandidate: true), goal: .reading, availability: all))
            XCTAssertNil(policy.activeLease)
            XCTAssertFalse(policy.beforeSpeech(lease, moment: moment(10.1), evidence: .init(capturedAt: 10, textCandidate: true), goal: .reading, availability: all))
        }
    }

    func testCancellationAndLateCompletionCannotDisturbSuccessor() throws {
        var policy = Policy()
        let first = try XCTUnwrap(policy.reserve(goal: .shopping, evidence: .init(capturedAt: 10), moment: moment(10), availability: all))
        policy.cancel()
        let next = try XCTUnwrap(policy.reserve(goal: .shopping, evidence: .init(capturedAt: 12), moment: moment(12), availability: all))
        XCTAssertEqual(next.capability, .barcode)
        policy.finish(first, outcome: .unavailable, now: 12.1)
        XCTAssertEqual(policy.activeLease, next)
        XCTAssertFalse(policy.beforeSpeech(first, moment: moment(12.1), evidence: .init(capturedAt: 10, textCandidate: true), goal: .shopping, availability: all))
        XCTAssertEqual(policy.activeLease, next)
    }

    func testRepeatedTogglingDoesNotReplenishCooldown() throws {
        var policy = Policy()
        _ = try XCTUnwrap(policy.reserve(goal: .none, evidence: .init(capturedAt: 10), moment: moment(10), availability: currency))
        policy.cancel(); policy.cancel()
        XCTAssertNil(policy.reserve(goal: .none, evidence: .init(capturedAt: 15.9), moment: moment(15.9), availability: currency))
        XCTAssertNotNil(policy.reserve(goal: .none, evidence: .init(capturedAt: 16), moment: moment(16), availability: currency))
    }

    func testSupersededCallbacksCannotPoisonSuccessorsClock() throws {
        for staleNow in [Double.nan, Double.infinity, 0, 1_000_000] {
            var policy = Policy()
            let first = try XCTUnwrap(policy.reserve(goal: .shopping, evidence: .init(capturedAt: 10), moment: moment(10), availability: all))
            policy.cancel()
            let next = try XCTUnwrap(policy.reserve(goal: .shopping, evidence: .init(capturedAt: 12), moment: moment(12), availability: all))
            policy.finish(first, outcome: .unavailable, now: staleNow)
            XCTAssertFalse(policy.beforeSpeech(first, moment: moment(staleNow), evidence: .init(capturedAt: 10, textCandidate: true), goal: .shopping, availability: all))
            XCTAssertNil(policy.promoteCurrencyCandidate(first, evidence: .init(capturedAt: 10, banknoteCandidate: true), moment: moment(staleNow), availability: all))
            XCTAssertEqual(policy.activeLease, next)
            XCTAssertTrue(policy.beforeSpeech(next, moment: moment(12.1), evidence: .init(capturedAt: 12, barcodeCandidate: true), goal: .shopping, availability: all))
        }
    }

    func testNoResultPollingIsBoundedAndFailuresBackOff() throws {
        var policy = Policy()
        let first = try XCTUnwrap(policy.reserve(goal: .none, evidence: .init(capturedAt: 10), moment: moment(10), availability: currency))
        policy.finish(first, outcome: .noResult, now: 10)
        XCTAssertNil(policy.reserve(goal: .none, evidence: .init(capturedAt: 21.9), moment: moment(21.9), availability: currency))
        let second = try XCTUnwrap(policy.reserve(goal: .none, evidence: .init(capturedAt: 22), moment: moment(22), availability: currency))
        policy.finish(second, outcome: .failed, now: 22)
        XCTAssertNil(policy.reserve(goal: .none, evidence: .init(capturedAt: 33.9), moment: moment(33.9), availability: currency))
        let third = try XCTUnwrap(policy.reserve(goal: .none, evidence: .init(capturedAt: 34), moment: moment(34), availability: currency))
        policy.finish(third, outcome: .failed, now: 34)
        XCTAssertNil(policy.reserve(goal: .none, evidence: .init(capturedAt: 57.9), moment: moment(57.9), availability: currency))
        let fourth = try XCTUnwrap(policy.reserve(goal: .none, evidence: .init(capturedAt: 58), moment: moment(58), availability: currency))
        policy.finish(fourth, outcome: .success, now: 58)
        XCTAssertNotNil(policy.reserve(goal: .none, evidence: .init(capturedAt: 64), moment: moment(64), availability: currency))
    }

    func testBackoffIsCappedAndUnavailableIsLonger() throws {
        var policy = Policy(), now = 10.0
        for gap in [12.0, 24, 48, 96, 120, 120, 120] {
            let lease = try XCTUnwrap(policy.reserve(goal: .none, evidence: .init(capturedAt: now), moment: moment(now), availability: currency))
            policy.finish(lease, outcome: .failed, now: now)
            XCTAssertNil(policy.reserve(goal: .none, evidence: .init(capturedAt: now + gap - 0.1), moment: moment(now + gap - 0.1), availability: currency))
            now += gap
        }
        let lease = try XCTUnwrap(policy.reserve(goal: .none, evidence: .init(capturedAt: now), moment: moment(now), availability: currency))
        policy.finish(lease, outcome: .unavailable, now: now)
        XCTAssertNil(policy.reserve(goal: .none, evidence: .init(capturedAt: now + 299), moment: moment(now + 299), availability: currency))
        XCTAssertNotNil(policy.reserve(goal: .none, evidence: .init(capturedAt: now + 300), moment: moment(now + 300), availability: currency))
    }

    func testRepeatedEmptyCurrencyViewsKeepFixedBoundedPolling() throws {
        var policy = Policy()
        for index in 0..<10 {
            let now = 10 + Double(index) * 12
            let lease = try XCTUnwrap(policy.reserve(goal: .none, evidence: .init(capturedAt: now), moment: moment(now), availability: currency))
            policy.finish(lease, outcome: .noResult, now: now)
            XCTAssertNil(policy.reserve(goal: .none, evidence: .init(capturedAt: now + 11.9), moment: moment(now + 11.9), availability: currency))
        }
    }

    func testFairSelectionAndGlobalJobGap() throws {
        var policy = Policy()
        let goal: Policy.Goal = [.shopping, .dressing, .reading]
        let availability: [Policy.Capability: Policy.Availability] = [.text: .available, .barcode: .available, .color: .available, .light: .available]
        for (index, capability) in [Policy.Capability.text, .barcode, .color, .light].enumerated() {
            let now = 10 + Double(index) * 2
            let lease = try XCTUnwrap(policy.reserve(goal: goal, evidence: .init(capturedAt: now, lightAvailable: true), moment: moment(now), availability: availability))
            XCTAssertEqual(lease.capability, capability)
            policy.finish(lease, outcome: .success, now: now)
            XCTAssertNil(policy.reserve(goal: goal, evidence: .init(capturedAt: now + 1, lightAvailable: true), moment: moment(now + 1), availability: availability))
        }
    }

    func testAbandonedLeaseTimesOutAndDoesNotBlockOtherCapabilities() throws {
        var policy = Policy()
        let first = try XCTUnwrap(policy.reserve(goal: .shopping, evidence: .init(capturedAt: 10), moment: moment(10), availability: all))
        let next = try XCTUnwrap(policy.reserve(goal: .shopping, evidence: .init(capturedAt: 17), moment: moment(17), availability: all))
        XCTAssertNotEqual(first.id, next.id)
        XCTAssertEqual(next.capability, .barcode)
        policy.finish(first, outcome: .success, now: 17)
        XCTAssertEqual(policy.activeLease, next)
    }

    func testConsensusNeedsTwoDifferentFreshVerifiedFrames() {
        var consensus = ContextualCurrencyConsensus()
        XCTAssertNil(consensus.observe(verifiedDenomination: 50, capturedAt: 10, now: 10, sessionGeneration: 1))
        XCTAssertNil(consensus.observe(verifiedDenomination: 50, capturedAt: 10, now: 10.5, sessionGeneration: 1))
        XCTAssertEqual(consensus.observe(verifiedDenomination: 50, capturedAt: 16, now: 16.5, sessionGeneration: 1), 50)
    }

    func testConsensusChangedValueNoResultAndSessionReset() {
        var consensus = ContextualCurrencyConsensus()
        XCTAssertNil(consensus.observe(verifiedDenomination: 50, capturedAt: 10, now: 10, sessionGeneration: 1))
        XCTAssertNil(consensus.observe(verifiedDenomination: 100, capturedAt: 11, now: 11, sessionGeneration: 1))
        XCTAssertEqual(consensus.observe(verifiedDenomination: 100, capturedAt: 12, now: 12, sessionGeneration: 1), 100)
        XCTAssertNil(consensus.observe(verifiedDenomination: nil, capturedAt: 13, now: 13, sessionGeneration: 1))
        XCTAssertNil(consensus.observe(verifiedDenomination: 100, capturedAt: 14, now: 14, sessionGeneration: 1))
        XCTAssertNil(consensus.observe(verifiedDenomination: 100, capturedAt: 15, now: 15, sessionGeneration: 2))
        XCTAssertEqual(consensus.observe(verifiedDenomination: 100, capturedAt: 16, now: 16, sessionGeneration: 2), 100)
        consensus.reset()
        XCTAssertNil(consensus.observe(verifiedDenomination: 100, capturedAt: 17, now: 17, sessionGeneration: 2))
    }

    func testConsensusRejectsStaleFutureInvalidUnknownAndReversedEvidence() {
        for (value, capture, now): (Int?, Double, Double) in [(2, 11, 11), (50, 10, 12.01), (50, 13, 12), (50, .nan, 12), (50, 12, .infinity), (50, 9, 9)] {
            var consensus = ContextualCurrencyConsensus()
            XCTAssertNil(consensus.observe(verifiedDenomination: 50, capturedAt: 10, now: 10, sessionGeneration: 1))
            XCTAssertNil(consensus.observe(verifiedDenomination: value, capturedAt: capture, now: now, sessionGeneration: 1))
            XCTAssertNil(consensus.observe(verifiedDenomination: 50, capturedAt: 13, now: 13, sessionGeneration: 1))
        }
        var consensus = ContextualCurrencyConsensus()
        XCTAssertNil(consensus.observe(verifiedDenomination: 50, capturedAt: 10, now: 10, sessionGeneration: 1))
        XCTAssertNil(consensus.observe(verifiedDenomination: 50, capturedAt: 9, now: 10, sessionGeneration: 1))
        XCTAssertNil(consensus.observe(verifiedDenomination: 50, capturedAt: 11, now: 11, sessionGeneration: 1))
    }

    func testConsensusWindowDoesNotCertifyDistantFrames() {
        var consensus = ContextualCurrencyConsensus()
        XCTAssertNil(consensus.observe(verifiedDenomination: 20, capturedAt: 10, now: 10, sessionGeneration: 1))
        XCTAssertNil(consensus.observe(verifiedDenomination: 20, capturedAt: 22.01, now: 22.01, sessionGeneration: 1))
        XCTAssertEqual(consensus.observe(verifiedDenomination: 20, capturedAt: 34.01, now: 34.01, sessionGeneration: 1), 20)
    }

    func testConflictingResultsFromSameFrameResetConsensus() {
        var consensus = ContextualCurrencyConsensus()
        XCTAssertNil(consensus.observe(verifiedDenomination: 20, capturedAt: 10, now: 10, sessionGeneration: 1))
        XCTAssertNil(consensus.observe(verifiedDenomination: 50, capturedAt: 10, now: 10.1, sessionGeneration: 1))
        XCTAssertNil(consensus.observe(verifiedDenomination: 20, capturedAt: 11, now: 11, sessionGeneration: 1))
        XCTAssertEqual(consensus.observe(verifiedDenomination: 20, capturedAt: 12, now: 12, sessionGeneration: 1), 20)
    }
}
