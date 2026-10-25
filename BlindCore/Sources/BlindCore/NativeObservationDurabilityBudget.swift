/// A pure payload-byte token bucket for the raw-observation durability lane.
///
/// For a valid monotonic clock interval of length T, admitted payload bytes are
/// bounded by B + r * T, where B = burstBytes and
/// r = bytesPerInterval / intervalSeconds. This is NOT a fixed or rolling-window
/// quota: after an idle period, one interval may admit the burst plus one refill.
/// From a cold start the stronger bound is r * T, because credit starts EMPTY.
/// Reconstructing this value on a process restart therefore cannot grant a fresh
/// burst. Keep the same value across session changes and history deletion.
///
/// The caller supplies monotonic time and encoded payload sizes. This policy
/// reads no clock, starts no timer, writes nothing, and never receives or renews
/// observation timestamps. Rejected records may remain in full-rate volatile
/// history. An admitted charge is never refunded, even if its storage write fails.
public struct NativeObservationDurabilityBudget: Sendable {
    public enum ConfigurationError: Error, Equatable, Sendable {
        case invalidBytesPerInterval, invalidIntervalSeconds, invalidBurstBytes
    }

    public struct Configuration: Equatable, Sendable {
        /// Matches the raw-history payload cap without coupling this pure policy
        /// to storage, history, or record representations.
        public static let maximumBytes = 2 * 1024 * 1024
        /// Explicit bounds exclude impractical rates and arithmetic overflow.
        public static let minimumIntervalSeconds = 0.001
        public static let maximumIntervalSeconds = 86_400.0

        public let bytesPerInterval: Int
        public let intervalSeconds: Double
        public let burstBytes: Int

        public init(bytesPerInterval: Int, intervalSeconds: Double, burstBytes: Int) throws {
            guard (1...Self.maximumBytes).contains(bytesPerInterval) else {
                throw ConfigurationError.invalidBytesPerInterval
            }
            guard intervalSeconds.isFinite,
                  (Self.minimumIntervalSeconds...Self.maximumIntervalSeconds).contains(intervalSeconds) else {
                throw ConfigurationError.invalidIntervalSeconds
            }
            guard (1...Self.maximumBytes).contains(burstBytes) else {
                throw ConfigurationError.invalidBurstBytes
            }
            self.bytesPerInterval = bytesPerInterval
            self.intervalSeconds = intervalSeconds
            self.burstBytes = burstBytes
        }

        /// Provisional raw-payload budget, not a measured device-energy budget.
        public static let provisionalDefault = Configuration(
            validatedBytesPerInterval: 131_072, intervalSeconds: 60, burstBytes: 131_072)

        private init(validatedBytesPerInterval: Int, intervalSeconds: Double, burstBytes: Int) {
            self.bytesPerInterval = validatedBytesPerInterval
            self.intervalSeconds = intervalSeconds
            self.burstBytes = burstBytes
        }
    }

    public enum Decision: Equatable, Sendable {
        case admitted, insufficientCredit, oversizedRecord, invalidClock, invalidSize
    }

    public let configuration: Configuration
    /// Diagnostic snapshot as of the latest observe/charge. Reading it does not
    /// advance time. Fractional credit is preserved; admission never uses epsilon.
    public private(set) var availableByteCredit: Double = 0
    private var highWaterTime: Double?
    private var clockRecoveryRequired: Bool
    private let maximumRefillSeconds: Double

    /// Invalid initial time is allowed but earns no credit. The first subsequent
    /// finite, nonnegative time only establishes an origin: observe returns false
    /// and charge returns invalidClock, without granting a refill.
    public init(configuration: Configuration = .provisionalDefault, now: Double) {
        self.configuration = configuration
        highWaterTime = now.isFinite && now >= 0 ? now : nil
        clockRecoveryRequired = highWaterTime == nil
        // An upward-rounded time to refill an EMPTY bucket lets very long idle
        // periods saturate safely, before an elapsed-time multiplication overflows.
        maximumRefillSeconds = Self.divideUp(
            Self.multiplyUp(Double(configuration.burstBytes), configuration.intervalSeconds),
            Double(configuration.bytesPerInterval))
    }

    /// Updates clock state and credit without charging a payload. Returns false
    /// for an invalid clock, rollback, or recovery-origin establishment.
    /// Invalid or backward time discards credit, but NEVER lowers the previous
    /// monotonic high-water mark. Earlier clock spans cannot be replayed to earn
    /// another refill. Recovery requires a finite, nonnegative sample at or above
    /// that high-water mark; that sample establishes a fresh origin without credit.
    /// Only later forward time refills. No credit is earned across an untrusted gap.
    @discardableResult
    public mutating func observe(now: Double) -> Bool {
        guard now.isFinite, now >= 0 else {
            availableByteCredit = 0
            clockRecoveryRequired = true
            return false
        }
        guard let previous = highWaterTime else {
            highWaterTime = now
            clockRecoveryRequired = false
            return false
        }
        guard now >= previous else {
            availableByteCredit = 0
            clockRecoveryRequired = true
            return false
        }
        highWaterTime = now
        if clockRecoveryRequired {
            clockRecoveryRequired = false
            return false
        }
        let elapsed = Self.subtractDown(now, previous)
        if elapsed >= maximumRefillSeconds {
            availableByteCredit = Double(configuration.burstBytes)
        } else if elapsed > 0 {
            let refill = Self.divideDown(
                Self.multiplyDown(elapsed, Double(configuration.bytesPerInterval)),
                configuration.intervalSeconds)
            availableByteCredit = min(Double(configuration.burstBytes),
                                      Self.addDown(availableByteCredit, refill))
        }

        return true
    }

    /// Clock validity takes precedence over size validity, so malformed requests
    /// cannot hide a clock failure. Rejected sizes spend no credit.
    @discardableResult
    public mutating func charge(bytes: Int, now: Double) -> Decision {
        guard observe(now: now) else { return .invalidClock }
        guard bytes > 0 else { return .invalidSize }
        guard bytes <= configuration.burstBytes else { return .oversizedRecord }
        guard availableByteCredit >= Double(bytes) else { return .insufficientCredit }
        availableByteCredit = Self.subtractDown(availableByteCredit, Double(bytes))
        return .admitted
    }

    // Conservative IEEE-754 arithmetic avoids accumulating rounded-up refill
    // credit beyond B + r*T. Exact arithmetic stays exact (e.g. 128 KiB at 60 s).
    // Inputs are nonnegative and finite; configuration and the saturation check
    // bound products. Fused multiply-add recovers the multiplication/division
    // residual; FastTwoSum/TwoSum recover addition/subtraction residuals.
    private static func addDown(_ a: Double, _ b: Double) -> Double {
        let sum = a + b
        let error = min(a, b) - (sum - max(a, b))
        return error < 0 ? sum.nextDown : sum
    }

    private static func subtractDown(_ a: Double, _ b: Double) -> Double {
        let difference = a - b
        let virtualB = difference - a
        let error = (a - (difference - virtualB)) + (-b - virtualB)
        return error < 0 ? difference.nextDown : difference
    }

    private static func multiplyDown(_ a: Double, _ b: Double) -> Double {
        let product = a * b
        let error = (-product).addingProduct(a, b)
        if product > 0 && (!product.isNormal || error < 0) { return product.nextDown }
        return product
    }

    private static func divideDown(_ a: Double, _ b: Double) -> Double {
        let quotient = a / b
        let error = a.addingProduct(-quotient, b)
        if quotient > 0 && (!quotient.isNormal || error < 0) { return quotient.nextDown }
        return quotient
    }

    private static func multiplyUp(_ a: Double, _ b: Double) -> Double {
        let product = a * b
        return (-product).addingProduct(a, b) > 0 ? product.nextUp : product
    }

    private static func divideUp(_ a: Double, _ b: Double) -> Double {
        let quotient = a / b
        return a.addingProduct(-quotient, b) > 0 ? quotient.nextUp : quotient
    }
}
