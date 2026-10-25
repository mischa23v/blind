import XCTest
@testable import BlindCore

final class NativeObservationDurabilityBudgetTests: XCTestCase {
    typealias Budget = NativeObservationDurabilityBudget

    func budget(bytes: Int = 100, interval: Double = 1, burst: Int = 100,
                now: Double = 0) throws -> Budget {
        Budget(configuration: try .init(bytesPerInterval: bytes, intervalSeconds: interval, burstBytes: burst), now: now)
    }

    func testDefaultStartsEmptyAndEarnsExactlyOneBurstAfterOneInterval() {
        var value = Budget(now: 100)
        XCTAssertEqual(value.configuration.bytesPerInterval, 131_072)
        XCTAssertEqual(value.configuration.intervalSeconds, 60)
        XCTAssertEqual(value.configuration.burstBytes, 131_072)
        XCTAssertEqual(value.availableByteCredit, 0)
        XCTAssertEqual(value.charge(bytes: 1, now: 100), .insufficientCredit)
        XCTAssertEqual(value.charge(bytes: 131_072, now: 160), .admitted)
        XCTAssertEqual(value.availableByteCredit, 0)
        XCTAssertEqual(value.charge(bytes: 1, now: 160), .insufficientCredit)
    }

    func testFractionalRefillPreservesCreditAndCannotExceedBurst() throws {
        var value = try budget(bytes: 10, interval: 2, burst: 8)
        XCTAssertEqual(value.charge(bytes: 2, now: 0.25), .insufficientCredit)
        XCTAssertEqual(value.availableByteCredit, 1.25)
        XCTAssertEqual(value.charge(bytes: 2, now: 0.5), .admitted)
        XCTAssertEqual(value.availableByteCredit, 0.5)
        XCTAssertEqual(value.charge(bytes: 1, now: 0.5), .insufficientCredit)
        XCTAssertEqual(value.charge(bytes: 1, now: 0.75), .admitted)
        XCTAssertEqual(value.availableByteCredit, 0.75)
        XCTAssertEqual(value.charge(bytes: 8, now: 2.75), .admitted)
        XCTAssertEqual(value.charge(bytes: 1, now: 2.75), .insufficientCredit)
    }

    func testLongIdleCapsCreditWithoutOverflowAndCannotBankMultipleBursts() throws {
        var value = try budget()
        XCTAssertEqual(value.charge(bytes: 1, now: Double.greatestFiniteMagnitude), .admitted)
        XCTAssertEqual(value.availableByteCredit, 99)
        XCTAssertEqual(value.charge(bytes: 99, now: Double.greatestFiniteMagnitude), .admitted)
        XCTAssertEqual(value.charge(bytes: 1, now: Double.greatestFiniteMagnitude), .insufficientCredit)
        XCTAssertTrue(value.availableByteCredit.isFinite)
    }

    func testOversizedPayloadIsNotChargedOrSplit() throws {
        var value = try budget()
        XCTAssertEqual(value.charge(bytes: 101, now: 1), .oversizedRecord)
        XCTAssertEqual(value.availableByteCredit, 100)
        XCTAssertEqual(value.charge(bytes: Int.max, now: 1), .oversizedRecord)
        XCTAssertEqual(value.availableByteCredit, 100)
        // The policy accepts only a byte count. It cannot drop a volatile record,
        // modify its original timestamp, or re-encode it to fit the burst.
        XCTAssertEqual(value.charge(bytes: 100, now: 1), .admitted)
        XCTAssertEqual(value.availableByteCredit, 0)
    }

    func testInvalidSizesDoNotSpendCredit() throws {
        var value = try budget()
        for bytes in [0, -1, Int.min] {
            XCTAssertEqual(value.charge(bytes: bytes, now: 1), .invalidSize)
            XCTAssertEqual(value.availableByteCredit, 100)
        }
        XCTAssertEqual(value.charge(bytes: 100, now: 1), .admitted)
    }

    func testConfigurationRejectsInvalidValuesAndAcceptsDocumentedLimits() throws {
        let maximum = Budget.Configuration.maximumBytes
        for bytes in [Int.min, -1, 0, maximum + 1, Int.max] {
            XCTAssertThrowsError(try Budget.Configuration(bytesPerInterval: bytes, intervalSeconds: 1, burstBytes: 1)) {
                XCTAssertEqual($0 as? Budget.ConfigurationError, .invalidBytesPerInterval)
            }
            XCTAssertThrowsError(try Budget.Configuration(bytesPerInterval: 1, intervalSeconds: 1, burstBytes: bytes)) {
                XCTAssertEqual($0 as? Budget.ConfigurationError, .invalidBurstBytes)
            }
        }
        for interval in [Double.nan, .infinity, -.infinity, -1, 0, .leastNonzeroMagnitude,
                         Budget.Configuration.minimumIntervalSeconds.nextDown,
                         Budget.Configuration.maximumIntervalSeconds.nextUp] {
            XCTAssertThrowsError(try Budget.Configuration(bytesPerInterval: 1, intervalSeconds: interval, burstBytes: 1)) {
                XCTAssertEqual($0 as? Budget.ConfigurationError, .invalidIntervalSeconds)
            }
        }
        for bytes in [1, maximum] {
            for interval in [Budget.Configuration.minimumIntervalSeconds, Budget.Configuration.maximumIntervalSeconds] {
                XCTAssertNoThrow(try Budget.Configuration(bytesPerInterval: bytes, intervalSeconds: interval, burstBytes: bytes))
            }
        }
    }

    func testRollbackDiscardsCreditAndRequiresCatchUpBeforeFreshRefill() throws {
        var value = try budget()
        XCTAssertEqual(value.charge(bytes: 1, now: 10), .admitted)
        XCTAssertEqual(value.availableByteCredit, 99)
        XCTAssertEqual(value.charge(bytes: 1, now: 9), .invalidClock)
        XCTAssertEqual(value.availableByteCredit, 0)
        XCTAssertEqual(value.charge(bytes: 1, now: 9), .invalidClock)
        XCTAssertEqual(value.charge(bytes: 50, now: 9.5), .invalidClock)
        XCTAssertEqual(value.availableByteCredit, 0)
        XCTAssertEqual(value.charge(bytes: 1, now: 10), .invalidClock)
        XCTAssertEqual(value.charge(bytes: 1, now: 10), .insufficientCredit)
        XCTAssertEqual(value.charge(bytes: 50, now: 10.5), .admitted)
        XCTAssertEqual(value.charge(bytes: 1, now: 10.5), .insufficientCredit)
    }

    func testInvalidClocksDiscardCreditAndRecoveryOnlyEstablishesOrigin() throws {
        for invalid in [Double.nan, .infinity, -.infinity, -1] {
            var value = try budget()
            XCTAssertEqual(value.charge(bytes: 1, now: 1), .admitted)
            XCTAssertEqual(value.charge(bytes: 1, now: invalid), .invalidClock)
            XCTAssertEqual(value.availableByteCredit, 0)
            XCTAssertEqual(value.charge(bytes: 1, now: 10_000), .invalidClock)
            XCTAssertEqual(value.availableByteCredit, 0)
            XCTAssertEqual(value.charge(bytes: 1, now: 10_000), .insufficientCredit)
            XCTAssertEqual(value.charge(bytes: 100, now: 10_001), .admitted)
        }
    }

    func testInvalidInitialClockAndRepeatedFailuresNeverGrantRestartCredit() throws {
        for invalid in [Double.nan, .infinity, -.infinity, -1] {
            var value = try budget(now: invalid)
            XCTAssertEqual(value.availableByteCredit, 0)
            XCTAssertEqual(value.charge(bytes: 1, now: invalid), .invalidClock)
            XCTAssertEqual(value.charge(bytes: 1, now: 100), .invalidClock)
            XCTAssertEqual(value.charge(bytes: 1, now: 100), .insufficientCredit)
            XCTAssertEqual(value.charge(bytes: 100, now: 101), .admitted)
        }
    }

    func testInvalidSizeCannotHideAnInvalidClock() throws {
        var value = try budget()
        XCTAssertEqual(value.charge(bytes: 1, now: 1), .admitted)
        XCTAssertEqual(value.charge(bytes: 0, now: .nan), .invalidClock)
        XCTAssertEqual(value.availableByteCredit, 0)
        XCTAssertEqual(value.charge(bytes: 100, now: 100), .invalidClock)
        XCTAssertEqual(value.availableByteCredit, 0)
    }

    func testObservingClockDoesNotChargeOrHideClockFailure() throws {
        var value = try budget()
        XCTAssertTrue(value.observe(now: 0.5))
        XCTAssertEqual(value.availableByteCredit, 50)
        XCTAssertTrue(value.observe(now: 0.5))
        XCTAssertEqual(value.availableByteCredit, 50)
        XCTAssertFalse(value.observe(now: .infinity))
        XCTAssertEqual(value.availableByteCredit, 0)
        XCTAssertFalse(value.observe(now: 100))
        XCTAssertEqual(value.availableByteCredit, 0)
        XCTAssertTrue(value.observe(now: 100.5))
        XCTAssertEqual(value.availableByteCredit, 50)
        XCTAssertFalse(value.observe(now: 100))
        XCTAssertEqual(value.availableByteCredit, 0)
        XCTAssertFalse(value.observe(now: 100))
        XCTAssertEqual(value.availableByteCredit, 0)
        XCTAssertFalse(value.observe(now: 100.5))
        XCTAssertEqual(value.availableByteCredit, 0)
        XCTAssertTrue(value.observe(now: 100.5))
        XCTAssertEqual(value.availableByteCredit, 0)
        XCTAssertTrue(value.observe(now: 101))
        XCTAssertEqual(value.availableByteCredit, 50)
    }

    func testRepeatedRollbacksCannotReplayAlreadySpentClockSpan() {
        var value = Budget(now: 0)
        XCTAssertEqual(value.charge(bytes: 131_072, now: 60), .admitted)
        for _ in 0..<1_000 {
            XCTAssertFalse(value.observe(now: 0))
            XCTAssertEqual(value.charge(bytes: 131_072, now: 60), .invalidClock)
            XCTAssertEqual(value.charge(bytes: 1, now: 60), .insufficientCredit)
            XCTAssertEqual(value.availableByteCredit, 0)
        }
        XCTAssertEqual(value.charge(bytes: 131_072, now: 120), .admitted)
    }

    func testNonfiniteClockThenLowerOriginCannotReplayAlreadySpentClockSpan() {
        for invalid in [Double.nan, .infinity, -.infinity, -1] {
            var value = Budget(now: 0)
            XCTAssertEqual(value.charge(bytes: 131_072, now: 60), .admitted)
            for _ in 0..<100 {
                XCTAssertFalse(value.observe(now: invalid))
                XCTAssertFalse(value.observe(now: 0))
                XCTAssertFalse(value.observe(now: 30))
                XCTAssertFalse(value.observe(now: 59.999))
                XCTAssertEqual(value.charge(bytes: 131_072, now: 60), .invalidClock)
                XCTAssertEqual(value.charge(bytes: 1, now: 60), .insufficientCredit)
                XCTAssertEqual(value.availableByteCredit, 0)
            }
            XCTAssertEqual(value.charge(bytes: 131_072, now: 120), .admitted)
        }
    }

    func testClockRecoveryAtNewHighWaterNeverRefillsAcrossUntrustedGap() throws {
        var value = try budget()
        XCTAssertEqual(value.charge(bytes: 100, now: 1), .admitted)
        XCTAssertFalse(value.observe(now: .nan))
        XCTAssertEqual(value.charge(bytes: 100, now: 10_000), .invalidClock)
        XCTAssertEqual(value.charge(bytes: 1, now: 10_000), .insufficientCredit)
        XCTAssertEqual(value.charge(bytes: 50, now: 10_000.5), .admitted)
        XCTAssertFalse(value.observe(now: 1))
        XCTAssertEqual(value.charge(bytes: 100, now: 20_000), .invalidClock)
        XCTAssertEqual(value.charge(bytes: 1, now: 20_000), .insufficientCredit)
        XCTAssertEqual(value.charge(bytes: 100, now: 20_001), .admitted)
    }

    func testArbitraryClockFaultsCannotExceedHighWaterAllowance() throws {
        var value = try budget(bytes: 1_024, interval: 4, burst: 512)
        var state: UInt64 = 0x5eed
        func next() -> UInt64 {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return state
        }
        var highWater = 0.0
        var total = 0
        for _ in 0..<4_000 {
            let now: Double
            switch next() % 6 {
            case 0: now = .nan
            case 1: now = -.infinity
            case 2: now = max(0, highWater - Double(next() % 25) / 4)
            default: now = highWater + Double(next() % 17) / 4
            }
            if now.isFinite && now >= 0 { highWater = max(highWater, now) }
            let cost = Int(next() % 100) + 1
            if value.charge(bytes: cost, now: now) == .admitted { total += cost }
            XCTAssertLessThanOrEqual(Double(total), 256 * highWater)
            XCTAssertGreaterThanOrEqual(value.availableByteCredit, 0)
            XCTAssertLessThanOrEqual(value.availableByteCredit, 512)
        }
        XCTAssertGreaterThan(total, 1_000)
    }

    func testReconstructingBudgetNeverProvidesFreshBurstCredit() throws {
        var previous = try budget()
        XCTAssertEqual(previous.charge(bytes: 100, now: 1), .admitted)
        for index in 0..<1_000 {
            let now = 1 + Double(index) / 1_000
            var restarted = try budget(now: now)
            XCTAssertEqual(restarted.charge(bytes: 1, now: now), .insufficientCredit)
            XCTAssertEqual(restarted.availableByteCredit, 0)
        }
    }

    func testAdmittedChargeCannotBeRefundedByRetryingAtSameTime() throws {
        var value = try budget()
        XCTAssertEqual(value.charge(bytes: 100, now: 1), .admitted)
        // A simulated failed storage write still leaves the same charge spent.
        XCTAssertEqual(value.charge(bytes: 100, now: 1), .insufficientCredit)
        XCTAssertEqual(value.charge(bytes: 100, now: 1.5), .insufficientCredit)
        XCTAssertEqual(value.charge(bytes: 100, now: 2), .admitted)
    }

    func testTokenBucketAllowsBurstPlusRefillRatherThanClaimingRollingQuota() throws {
        var value = try budget()
        XCTAssertEqual(value.charge(bytes: 100, now: 10), .admitted)
        XCTAssertEqual(value.charge(bytes: 100, now: 11), .admitted)
        // 200 bytes over this 1-second interval exactly equals B + r*T, even
        // though bytesPerInterval is 100. It is not a 100-byte rolling window.
        XCTAssertEqual(value.charge(bytes: 1, now: 11), .insufficientCredit)
    }

    func testArbitrarySequenceRespectsColdStartAndEveryObservedWindowBound() throws {
        var value = try budget(bytes: 1_024, interval: 4, burst: 512)
        var state: UInt64 = 0x5eed
        func next() -> UInt64 {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return state
        }
        var now = 0.0
        var total = 0
        var samples: [(time: Double, before: Int)] = []
        for _ in 0..<1_000 {
            now += Double(next() % 17) / 16 // Includes simultaneous attempts.
            let cost = Int(next() % 600) + 1 // Includes oversized payloads.
            samples.append((now, total))
            if value.charge(bytes: cost, now: now) == .admitted { total += cost }
            XCTAssertLessThanOrEqual(Double(total), 256 * now)
            XCTAssertGreaterThanOrEqual(value.availableByteCredit, 0)
            XCTAssertLessThanOrEqual(value.availableByteCredit, 512)
            for start in samples {
                XCTAssertLessThanOrEqual(Double(total - start.before), 512 + 256 * (now - start.time))
            }
        }
        XCTAssertGreaterThan(total, 10_000) // Ensure the bound was exercised.
    }

    func testTinyAndBoundaryClockStepsNeverRoundUpIntoAnEarlyByte() throws {
        var value = try budget(bytes: 1, interval: 1, burst: 1)
        XCTAssertEqual(value.charge(bytes: 1, now: .leastNonzeroMagnitude), .insufficientCredit)
        XCTAssertEqual(value.charge(bytes: 1, now: 1.0.nextDown), .insufficientCredit)
        XCTAssertLessThan(value.availableByteCredit, 1)
        XCTAssertEqual(value.charge(bytes: 1, now: 2), .admitted)
        XCTAssertEqual(value.charge(bytes: 1, now: 2), .insufficientCredit)
    }
}
