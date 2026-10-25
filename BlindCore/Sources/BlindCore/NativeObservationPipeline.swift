import Foundation

/// Existing GRDB adapter operations. Only the dedicated durability queue calls these.
public struct NativeObservationStorage: @unchecked Sendable {
    public struct Commit: Sendable {
        public let retainedIDs: Set<UUID>
        public let evictedRecordCount: Int
        public let insertedRecordCount: Int
        public let insertedPayloadBytes: Int
        public init(retainedIDs: Set<UUID>, evictedRecordCount: Int, insertedRecordCount: Int, insertedPayloadBytes: Int) {
            self.retainedIDs = retainedIDs; self.evictedRecordCount = evictedRecordCount
            self.insertedRecordCount = insertedRecordCount; self.insertedPayloadBytes = insertedPayloadBytes
        }
    }
    public let load: () throws -> NativeObservationHistory
    public let append: ([NativeObservationEncodedRecord]) throws -> Commit
    public let delete: () throws -> Void
    public init(load: @escaping () throws -> NativeObservationHistory,
                append: @escaping ([NativeObservationEncodedRecord]) throws -> Commit, delete: @escaping () throws -> Void) {
        self.load = load; self.append = append; self.delete = delete
    }
}

public enum NativeObservationVolatileReason: Equatable, Sendable {
    case pending, budgetExhausted, oversizedRecord, clockUnavailable, writeFailed
    case supersededByFresherRecord, expiredBeforeWrite, inactiveSession
}

/// Volatile history is independently readable. Only acknowledged retained IDs are durable.
public struct NativeObservationSnapshot: Sendable {
    public let history: NativeObservationHistory
    public let durableRecordIDs: Set<UUID>
    public let volatileReasons: [UUID: NativeObservationVolatileReason]
    public let durableEvictedRecordCount: Int
    /// Includes a bounded budget-admission job, not proof that SQL is executing.
    public let writeInFlight: Bool
    public let pendingRecordCount: Int
    public var volatileRecordIDs: Set<UUID> { Set(history.encodedRecords.map(\.id)).subtracting(durableRecordIDs) }
}

/// One admitted extraction; a separate one-write + one-freshest-record durability lane.
/// A blocked/failed writer never holds the frame slot or the in-memory read queue.
public final class NativeObservationPipeline: @unchecked Sendable {
    public enum DurabilityPolicy: Sendable {
        case budgeted(NativeObservationDurabilityBudget.Configuration)
        #if DEBUG
        /// Verification only; absent from Release and never selected by the native bridge.
        case unboundedForTesting
        #endif
    }
    public enum Outcome: Equatable, Sendable { case ready, observed, invalidObservation, storageFailed, cleared, clearFailed, controlBusy }
    public struct Statistics: Equatable, Sendable {
        public fileprivate(set) var admitted = 0
        public fileprivate(set) var droppedBusy = 0
        public fileprivate(set) var droppedRateOrOrder = 0
        public fileprivate(set) var droppedInactive = 0
        public fileprivate(set) var droppedInvalidTimestamp = 0
        public fileprivate(set) var rejectedObsolete = 0
        public fileprivate(set) var observed = 0
        public fileprivate(set) var invalidRecords = 0
        public fileprivate(set) var writeFailures = 0
        public fileprivate(set) var encodedRecordBytes = 0
        public fileprivate(set) var logicalBytesSubmitted = 0
        public fileprivate(set) var attemptedTransactions = 0
        public fileprivate(set) var committedTransactions = 0
        public fileprivate(set) var committedRecords = 0
        public fileprivate(set) var committedPayloadBytes = 0
        public fileprivate(set) var evictedBeforeDurableConfirmation = 0
        public fileprivate(set) var skippedObsoleteDurabilityRecords = 0
        public fileprivate(set) var pendingBatchReplacements = 0
        public fileprivate(set) var discardedUnconfirmedOnRestart = 0
        public fileprivate(set) var budgetDeferrals = 0
        public fileprivate(set) var oversizedVolatileRecords = 0
        public fileprivate(set) var durabilityClockFailures = 0
        public fileprivate(set) var availableDurabilityByteCredit: Double = 0
        public let lockContentionDropsCounted = false
    }
    public static let maximumCaptureAge: Double = 3
    private var counters = Statistics()
    private let now: () -> Double
    private let queue: DispatchQueue
    private let writer: DispatchQueue
    private let lock = NSLock()
    private var generation = UUID()
    private var sessionID: UUID?
    private var accepting = false
    private var busy = false
    private var controlPending = false
    private var readPending = false
    private var lastAdmitted = -Double.infinity
    // A rejected frame may still reveal a clock rollback. Fence the next writer
    // without scheduling work for that frame or granting restored credits.
    private var lastSampledClock: Double?
    private var budgetClockInvalidationPending = false
    // All fields below are confined to the extraction/history queue, never the writer queue.
    private var history = NativeObservationHistory()
    private var storage: NativeObservationStorage?
    private var durableIDs = Set<UUID>()
    private var durableEvictions = 0
    private var writeInFlight = false
    private var pending: (token: UUID, record: NativeObservationEncodedRecord)?
    private var volatileReasons: [UUID: NativeObservationVolatileReason] = [:]
    private let durability: DurabilityPolicy
    private let maximumDurableRecordBytes: Int
    // Accessed only on writer. Never reset by begin/stop/clear; cold restart starts empty.
    private var budget: NativeObservationDurabilityBudget
    private enum WriteOutcome {
        case committed(NativeObservationStorage.Commit), failed
        case budgetDenied(NativeObservationDurabilityBudget.Decision)
        case obsolete
    }
    public init(queue: DispatchQueue = DispatchQueue(label: "org.blind-assist.native-observation", qos: .utility),
                writer: DispatchQueue = DispatchQueue(label: "org.blind-assist.native-observation-durability", qos: .utility),
                durability: DurabilityPolicy = .budgeted(.provisionalDefault),
                now: @escaping () -> Double = { ProcessInfo.processInfo.systemUptime }) {
        self.queue = queue; self.writer = writer; self.now = now; self.durability = durability
        switch durability {
        case .budgeted(let configuration):
            budget = NativeObservationDurabilityBudget(configuration: configuration, now: now())
            maximumDurableRecordBytes = configuration.burstBytes
        #if DEBUG
        case .unboundedForTesting:
            budget = NativeObservationDurabilityBudget(now: now())
            maximumDurableRecordBytes = NativeObservationHistory.maximumBytes
        #endif
        }
    }
    public func statistics() -> Statistics { lock.lock(); defer { lock.unlock() }; return counters }
    private func releaseControl() { lock.lock(); controlPending = false; lock.unlock() }
    private func count(_ update: (inout Statistics) -> Void) { lock.lock(); update(&counters); lock.unlock() }
    private func sampleClockLocked(_ value: Double) {
        if !value.isFinite || value < 0 { budgetClockInvalidationPending = true; lastSampledClock = nil; return }
        if let previous = lastSampledClock, value < previous { budgetClockInvalidationPending = true }
        lastSampledClock = value
    }
    private static func fresh(_ time: Double, at current: Double) -> Bool {
        current.isFinite && time.isFinite && current >= time && current - time <= maximumCaptureAge
    }
    private func fresh(_ time: Double) -> Bool {
        lock.lock(); let value = now(); sampleClockLocked(value); lock.unlock()
        return Self.fresh(time, at: value)
    }
    private func current(_ token: UUID) -> Bool { lock.lock(); defer { lock.unlock() }; return generation == token }

    /// Restoration reads only the dedicated observation database. Old callbacks cannot overwrite it.
    public func begin(sessionID: UUID, storage: NativeObservationStorage, completion: @escaping (Outcome) -> Void = { _ in }) {
        lock.lock()
        guard !controlPending else { lock.unlock(); completion(.controlBusy); return }
        let token = UUID(); generation = token; self.sessionID = sessionID; accepting = false
        lastAdmitted = -.infinity; controlPending = true; lock.unlock()
        queue.async { [self] in
            count { $0.discardedUnconfirmedOnRestart += Set(history.encodedRecords.map(\.id)).subtracting(durableIDs).count }
            pending = nil; history = NativeObservationHistory(); durableIDs = []; durableEvictions = 0; volatileReasons = [:]
            self.storage = nil
            writer.async { [self] in
                let result = Result { try storage.load() }
                queue.async { [self] in
                    guard current(token) else { releaseControl(); return }
                    switch result {
                    case .success(let restored):
                        // Volatile-window evictions are local to this window, distinct from durable row evictions.
                        do { history = try NativeObservationHistory(records: restored.encodedRecords, evictedRecordCount: 0) }
                        catch { releaseControl(); completion(.storageFailed); return }
                        self.storage = storage; durableIDs = Set(restored.encodedRecords.map(\.id)); durableEvictions = restored.evictedRecordCount
                        lock.lock(); if generation == token { accepting = true }; lock.unlock()
                        releaseControl(); completion(.ready)
                    case .failure: releaseControl(); completion(.storageFailed)
                    }
                }
            }
        }
    }
    /// Synchronous bounded admission precedes retaining an ARFrame in any queued closure.
    /// Completion reports volatile observation admission, NOT durability.
    @discardableResult public func offer(sessionID: UUID, capturedAt: Double,
                                         extract: @escaping () throws -> NativeObservationRecord,
                                         completion: @escaping (Outcome) -> Void = { _ in }) -> Bool {
        guard lock.try() else { return false }
        guard accepting, self.sessionID == sessionID else { counters.droppedInactive += 1; lock.unlock(); return false }
        guard !busy else { counters.droppedBusy += 1; lock.unlock(); return false }
        let admissionClock = now(); sampleClockLocked(admissionClock)
        guard capturedAt >= 0, Self.fresh(capturedAt, at: admissionClock) else { counters.droppedInvalidTimestamp += 1; lock.unlock(); return false }
        guard capturedAt - lastAdmitted >= 0.5 else { counters.droppedRateOrOrder += 1; lock.unlock(); return false }
        counters.admitted += 1; busy = true; lastAdmitted = capturedAt; let token = generation; lock.unlock()
        queue.async { [self] in
            var outcome: Outcome?
            defer {
                lock.lock(); busy = false; lock.unlock()
                if let outcome { completion(outcome) }
            }
            guard current(token), fresh(capturedAt) else { count { $0.rejectedObsolete += 1 }; return }
            do {
                let record = try extract()
                guard record.sessionID == sessionID, record.capturedAt == capturedAt else { throw NativeObservationError.invalidMetadata }
                let encoded = try NativeObservationEncodedRecord(record)
                guard current(token), fresh(capturedAt) else { count { $0.rejectedObsolete += 1 }; return }
                let priorIDs = Set(history.encodedRecords.map(\.id))
                try history.append(encoded)
                let evicted = priorIDs.subtracting(history.encodedRecords.map(\.id)).subtracting(durableIDs).count
                count { $0.observed += 1; $0.encodedRecordBytes += encoded.encodedBytes; $0.evictedBeforeDurableConfirmation += evicted }
                let retained = Set(history.encodedRecords.map(\.id))
                volatileReasons = volatileReasons.filter { retained.contains($0.key) }
                // Size-ineligible observations keep full geometry in volatile memory.
                // They do not replace the freshest still-eligible pending record.
                if encoded.encodedBytes > maximumDurableRecordBytes {
                    volatileReasons[encoded.id] = .oversizedRecord
                    count { $0.oversizedVolatileRecords += 1 }
                } else {
                    if let old = pending {
                        count { $0.pendingBatchReplacements += 1 }
                        if retained.contains(old.record.id), !durableIDs.contains(old.record.id) {
                            volatileReasons[old.record.id] = .supersededByFresherRecord
                        }
                    }
                    volatileReasons[encoded.id] = .pending
                    pending = (token, encoded)
                }
                drainDurability()
                outcome = .observed
            } catch { count { $0.invalidRecords += 1 }; outcome = .invalidObservation }
        }
        return true
    }
    /// No timers/delayed work. Only a new offer or active-write completion retries the
    /// freshest eligible pending record; budget exhaustion never schedules database work.
    private func drainDurability() {
        guard !writeInFlight, let candidate = pending, let storage else { return }
        pending = nil
        guard current(candidate.token), fresh(candidate.record.capturedAt) else {
            if history.encodedRecords.contains(where: { $0.id == candidate.record.id }) {
                volatileReasons[candidate.record.id] = current(candidate.token) ? .expiredBeforeWrite : .inactiveSession
            }
            count { $0.skippedObsoleteDurabilityRecords += 1 }; return
        }
        writeInFlight = true
        writer.async { [self] in
            // One synchronized clock/ownership/freshness/budget admission sample.
            // Never sample freshness again and charge against an earlier clock instant.
            lock.lock(); let instant = now(); sampleClockLocked(instant)
            let invalidateBudgetClock = budgetClockInvalidationPending
            budgetClockInvalidationPending = false
            var clockValid = true
            switch durability {
            case .budgeted:
                if invalidateBudgetClock { _ = budget.observe(now: .nan) }
                clockValid = budget.observe(now: instant)
            #if DEBUG
            case .unboundedForTesting: break
            #endif
            }
            var denied: WriteOutcome?
            if generation != candidate.token || !Self.fresh(candidate.record.capturedAt, at: instant) { denied = .obsolete }
            else if !clockValid { denied = .budgetDenied(.invalidClock) }
            else {
                let decision: NativeObservationDurabilityBudget.Decision
                switch durability {
                case .budgeted: decision = budget.charge(bytes: candidate.record.encodedBytes, now: instant)
                #if DEBUG
                case .unboundedForTesting: decision = .admitted
                #endif
                }
                if decision != .admitted { denied = .budgetDenied(decision) }
            }
            if denied == nil {
                counters.attemptedTransactions += 1
                counters.logicalBytesSubmitted += candidate.record.encodedBytes
            }
            counters.availableDurabilityByteCredit = budget.availableByteCredit
            lock.unlock()
            // This attempt is now admitted. Clear is ordered after the serial writer;
            // failure/uncertain SQL outcome does not refund its already charged bytes.
            let result: WriteOutcome
            if let denied { result = denied }
            else {
                do { result = .committed(try storage.append([candidate.record])) }
                catch { result = .failed }
            }
            queue.async { [self] in
                writeInFlight = false
                let retained = history.encodedRecords.contains { $0.id == candidate.record.id }
                func keepForLater(_ reason: NativeObservationVolatileReason) {
                    guard current(candidate.token), retained else { return }
                    if pending == nil { pending = candidate; volatileReasons[candidate.record.id] = reason }
                    else { volatileReasons[candidate.record.id] = .supersededByFresherRecord }
                }
                switch result {
                case .committed(let commit):
                    count { $0.committedTransactions += 1; $0.committedRecords += commit.insertedRecordCount; $0.committedPayloadBytes += commit.insertedPayloadBytes }
                    if current(candidate.token) {
                        durableIDs = commit.retainedIDs; durableEvictions = commit.evictedRecordCount
                        volatileReasons = volatileReasons.filter { !durableIDs.contains($0.key) }
                        drainDurability()
                    }
                case .failed:
                    count { $0.writeFailures += 1 }; keepForLater(.writeFailed)
                case .budgetDenied(let decision):
                    switch decision {
                    case .insufficientCredit: count { $0.budgetDeferrals += 1 }; keepForLater(.budgetExhausted)
                    case .invalidClock: count { $0.durabilityClockFailures += 1 }; keepForLater(.clockUnavailable)
                    case .oversizedRecord: if retained { volatileReasons[candidate.record.id] = .oversizedRecord }
                    default: if retained { volatileReasons[candidate.record.id] = .writeFailed }
                    }
                case .obsolete:
                    count { $0.skippedObsoleteDurabilityRecords += 1 }
                    if retained { volatileReasons[candidate.record.id] = .inactiveSession }
                    if current(candidate.token) { drainDurability() }
                }
            }
        }
    }
    public func stop() { lock.lock(); accepting = false; generation = UUID(); sessionID = nil; lock.unlock() }
    /// Immediate invalidation, then a serial barrier after any write already inside SQLite.
    /// One control slot prevents repeated clear/start calls from building an unbounded queue.
    public func clear(storage: NativeObservationStorage, completion: @escaping (Outcome) -> Void) {
        stop(); lock.lock()
        guard !controlPending else { lock.unlock(); completion(.controlBusy); return }
        controlPending = true; lock.unlock()
        queue.async { [self] in
            pending = nil
            writer.async { [self] in
                let result = Result { try storage.delete() }
                queue.async { [self] in
                    switch result {
                    case .success:
                        history = NativeObservationHistory(); durableIDs = []; durableEvictions = 0; volatileReasons = [:]; self.storage = nil
                        releaseControl(); completion(.cleared)
                    case .failure: releaseControl(); completion(.clearFailed)
                    }
                }
            }
        }
    }
    /// Reads volatile history without waiting behind database IO. One read slot bounds callbacks.
    @discardableResult public func readSnapshot(_ completion: @escaping (NativeObservationSnapshot) -> Void) -> Bool {
        lock.lock(); guard !readPending else { lock.unlock(); return false }; readPending = true; lock.unlock()
        queue.async { [self] in
            let snapshot = NativeObservationSnapshot(history: history,
                durableRecordIDs: durableIDs.intersection(history.encodedRecords.map(\.id)),
                volatileReasons: volatileReasons,
                durableEvictedRecordCount: durableEvictions, writeInFlight: writeInFlight,
                pendingRecordCount: pending == nil ? 0 : 1)
            lock.lock(); readPending = false; lock.unlock(); completion(snapshot)
        }
        return true
    }
}
