import Foundation

/// Bounded admission for nonurgent on-device work, not a recognizer or a speech owner.
/// Capabilities stay available without a feature command. The current general task chooses
/// useful probes; a silent currency candidate probe also works without a task. No lease
/// establishes an object's identity, denomination, geometry, safety or presence.
public struct ContextualCapabilityScheduler: Sendable {
    public enum Capability: String, CaseIterable, Sendable {
        case currencyProbe, currency, text, barcode, light, color
    }
    public enum Availability: Equatable, Sendable { case available, unavailable }
    public enum Outcome: Equatable, Sendable { case success, noResult, failed, unavailable }
    public enum EvidenceSource: Equatable, Sendable { case onDevice, languageModel, unknown }

    /// Only caller-owned active goals/focus belong here, never arbitrary conversation,
    /// model-suggested goals, or an inference that a detector label is the user's intent.
    public struct Goal: OptionSet, Equatable, Sendable {
        public let rawValue: UInt8
        public init(rawValue: UInt8) { self.rawValue = rawValue }
        public static let none: Goal = []
        public static let shopping = Goal(rawValue: 1 << 0)
        public static let dining = Goal(rawValue: 1 << 1)
        public static let reading = Goal(rawValue: 1 << 2)
        public static let dressing = Goal(rawValue: 1 << 3)
        public static let lighting = Goal(rawValue: 1 << 4)
        public static let payment = Goal(rawValue: 1 << 5)

        /// A deliberately bounded lexical adapter, not general semantic planning.
        /// Unknown goals stay unknown. These words select probes, never camera facts.
        public static func infer(from text: String) -> Goal {
            guard text.unicodeScalars.count <= 1_200 else { return .none }
            let normalized = SpatialClaimGuard.normalizeArabic(text.lowercased())
            let words = Set(normalized.components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty })
            func contains(_ candidates: [String]) -> Bool {
                candidates.contains { words.contains($0) || words.contains("ال" + $0) }
            }
            var result: Goal = .none
            if contains(["shop", "shopping", "buy", "buying", "groceries", "grocery", "supermarket", "product", "products", "تسوق", "اشتري", "شراء", "بقاله", "منتج", "منتجات"]) { result.insert(.shopping) }
            if contains(["eat", "eating", "dine", "dining", "restaurant", "menu", "lunch", "dinner", "breakfast", "مطعم", "اكل", "طعام", "غداء", "عشاء", "فطور"]) { result.insert(.dining) }
            // A book/page/sign is an object, not permission to narrate all visible text.
            // Only a reading action receives unrestricted OCR relevance. Other goals
            // retain their separate, target-matching text filters in the caller.
            let findingObject = contains(["find", "locate", "looking", "ابحث", "اجد"])
            if contains(["read", "اقرا"]) || (!findingObject && contains(["reading", "قراءه"])) { result.insert(.reading) }
            if contains(["dress", "dressing", "dressed", "clothes", "clothing", "outfit", "wear", "shirt", "uniform", "color", "colour", "ملابس", "البس", "قميص", "ثوب", "زي", "لون"]) { result.insert(.dressing) }
            if contains(["light", "lights", "lighting", "brightness", "dark", "ضوء", "نور", "اضاءه", "ظلام"]) { result.insert(.lighting) }
            if contains(["pay", "paying", "payment", "cash", "money", "banknote", "banknotes", "دفع", "ادفع", "نقود", "فلوس", "عمله"]) { result.insert(.payment) }
            return result
        }
    }

    /// Flags are adapter observations from this exact frame, not model descriptions.
    /// Text/barcode/color may be absent when reserving a goal-driven probe. Their positive
    /// evidence is mandatory at delivery. A rectangle candidate is NOT a banknote verdict.
    public struct Evidence: Equatable, Sendable {
        public var capturedAt: Double
        public var banknoteCandidate: Bool
        public var textCandidate: Bool
        public var barcodeCandidate: Bool
        public var lightAvailable: Bool
        /// True only after native isolation/segmentation of one central item. A whole-frame
        /// color sample, a person/outfit label, or an LLM statement cannot set this flag.
        public var centralIsolatedItem: Bool
        public var source: EvidenceSource
        public init(capturedAt: Double, banknoteCandidate: Bool = false, textCandidate: Bool = false,
                    barcodeCandidate: Bool = false, lightAvailable: Bool = false,
                    centralIsolatedItem: Bool = false, source: EvidenceSource = .onDevice) {
            self.capturedAt = capturedAt; self.banknoteCandidate = banknoteCandidate
            self.textCandidate = textCandidate; self.barcodeCandidate = barcodeCandidate
            self.lightAvailable = lightAvailable; self.centralIsolatedItem = centralIsolatedItem
            self.source = source
        }
    }

    /// One immutable caller snapshot. Busy excludes this scheduler's own active lease;
    /// it includes explicit questions, reading, speech, navigation cues and other work.
    public struct Moment: Sendable {
        public var now: Double
        public var requestID: UUID
        public var perceptionGeneration: UUID
        public var sessionGeneration: UInt64
        public var goalGeneration: String
        public var cameraEnabled: Bool
        public var sessionActive: Bool
        public var foregroundActive: Bool
        public var stationary: Bool
        public var hazardActive: Bool
        public var listening: Bool
        public var busy: Bool
        public init(now: Double, requestID: UUID, perceptionGeneration: UUID,
                    sessionGeneration: UInt64, goalGeneration: String, cameraEnabled: Bool = true,
                    sessionActive: Bool = true, foregroundActive: Bool = true, stationary: Bool = true,
                    hazardActive: Bool = false, listening: Bool = false, busy: Bool = false) {
            self.now = now; self.requestID = requestID; self.perceptionGeneration = perceptionGeneration
            self.sessionGeneration = sessionGeneration; self.goalGeneration = goalGeneration
            self.cameraEnabled = cameraEnabled; self.sessionActive = sessionActive
            self.foregroundActive = foregroundActive; self.stationary = stationary
            self.hazardActive = hazardActive; self.listening = listening; self.busy = busy
        }
        fileprivate var quiescent: Bool {
            cameraEnabled && sessionActive && foregroundActive && stationary &&
                !hazardActive && !listening && !busy && !goalGeneration.isEmpty && goalGeneration.count <= 128
        }
    }

    public struct Lease: Equatable, Sendable {
        public let id: UUID
        public let capability: Capability
        public let capturedAt: Double
        public let startedAt: Double
        public let requestID: UUID
        public let perceptionGeneration: UUID
        public let sessionGeneration: UInt64
        public let goalGeneration: String
        public let goal: Goal
        fileprivate init(capability: Capability, evidence: Evidence, moment: Moment, goal: Goal, id: UUID = UUID()) {
            self.id = id; self.capability = capability; self.capturedAt = evidence.capturedAt
            self.startedAt = moment.now; self.requestID = moment.requestID
            self.perceptionGeneration = moment.perceptionGeneration; self.sessionGeneration = moment.sessionGeneration
            self.goalGeneration = moment.goalGeneration; self.goal = goal
        }
        fileprivate init(promoting lease: Lease) {
            id = lease.id; capability = .currency; capturedAt = lease.capturedAt; startedAt = lease.startedAt
            requestID = lease.requestID; perceptionGeneration = lease.perceptionGeneration
            sessionGeneration = lease.sessionGeneration; goalGeneration = lease.goalGeneration; goal = lease.goal
        }
    }

    public static let maximumFrameAge = 0.5
    public static let maximumResultAge = 4.0
    public static let leaseLifetime = 6.0
    public static let minimumJobGap = 2.0
    private struct Cooldown: Sendable { var nextAt: Double; var failures: Int }
    public private(set) var activeLease: Lease?
    private var speechPermitUsed = false
    private var cooldowns: [Capability: Cooldown] = [:]
    private var lastNow: Double?
    private var lastStart = -Double.infinity
    private var nextIndex = 0
    public init() {}

    /// Returns at most one job. Omitted backends are unavailable, not an invented fallback.
    /// The caller must cancel its async task when this policy invalidates the lease.
    public mutating func reserve(goal: Goal, evidence: Evidence, moment: Moment,
                                 availability: [Capability: Availability]) -> Lease? {
        guard observe(moment.now) else { return nil }
        if let lease = activeLease {
            if valid(lease, moment: moment) && lease.goal == goal && moment.now - lease.capturedAt <= Self.maximumResultAge &&
                backendAvailable(lease.capability, availability) { return nil }
            complete(lease, outcome: .failed, now: moment.now)
        }
        guard moment.quiescent, evidence.source == .onDevice,
              fresh(evidence.capturedAt, now: moment.now, maximumAge: Self.maximumFrameAge),
              moment.now - lastStart >= Self.minimumJobGap else { return nil }
        // Rotate useful work rather than letting a perpetually visible sign starve barcodes.
        let order: [Capability] = [.text, .barcode, .color, .light, .currencyProbe]
        if evidence.banknoteCandidate, eligible(.currency, goal: goal, evidence: evidence),
           ready(.currency, now: moment.now, availability: availability) {
            return begin(.currency, goal: goal, evidence: evidence, moment: moment)
        }
        for offset in 0..<order.count {
            let index = (nextIndex + offset) % order.count, capability = order[index]
            guard eligible(capability, goal: goal, evidence: evidence),
                  ready(capability, now: moment.now, availability: availability) else { continue }
            nextIndex = (index + 1) % order.count
            return begin(capability, goal: goal, evidence: evidence, moment: moment)
        }
        return nil
    }

    /// A candidate only permits the existing recognizer to inspect the SAME capture. It
    /// does not permit a denomination statement. No second lease or frame is reserved.
    public mutating func promoteCurrencyCandidate(_ lease: Lease, evidence: Evidence, moment: Moment,
                                                  availability: [Capability: Availability]) -> Lease? {
        guard activeLease == lease, lease.capability == .currencyProbe, observe(moment.now) else { return nil }
        guard valid(lease, moment: moment), evidence.source == .onDevice,
              evidence.capturedAt == lease.capturedAt, evidence.banknoteCandidate,
              fresh(lease.capturedAt, now: moment.now, maximumAge: Self.maximumResultAge),
              backendAvailable(.currency, availability) else { cancel(); return nil }
        let promoted = Lease(promoting: lease)
        activeLease = promoted
        return promoted
    }

    /// Consume a single delivery permit immediately before speech admission. Still requires
    /// caller-owned result/recognizer validation, capture pose, attention and narration budget.
    /// This cannot authorize geometry, an outfit-wide color, or a candidate denomination.
    public mutating func beforeSpeech(_ lease: Lease, moment: Moment, evidence: Evidence, goal: Goal,
                                      availability: [Capability: Availability]) -> Bool {
        guard activeLease == lease, !speechPermitUsed, observe(moment.now) else { return false }
        guard valid(lease, moment: moment), goal == lease.goal, evidence.source == .onDevice,
              evidence.capturedAt == lease.capturedAt,
              fresh(lease.capturedAt, now: moment.now, maximumAge: Self.maximumResultAge),
              backendAvailable(lease.capability, availability),
              eligible(lease.capability, goal: goal, evidence: evidence) else { cancel(); return false }
        let hasResultEvidence: Bool
        switch lease.capability {
        case .currencyProbe: hasResultEvidence = false
        case .currency:
            hasResultEvidence = evidence.banknoteCandidate && SaudiBanknotePolicy.fresh(capturedAt: lease.capturedAt, now: moment.now)
        case .text: hasResultEvidence = evidence.textCandidate
        case .barcode: hasResultEvidence = evidence.barcodeCandidate
        case .light: hasResultEvidence = evidence.lightAvailable
        case .color: hasResultEvidence = evidence.centralIsolatedItem
        }
        guard hasResultEvidence else { return false }
        speechPermitUsed = true
        return true
    }

    /// A late/duplicate result cannot finish or alter a successor's lease or cooldown.
    public mutating func finish(_ lease: Lease, outcome: Outcome, now: Double) {
        guard activeLease == lease, observe(now) else { return }
        complete(lease, outcome: outcome, now: now)
    }

    /// Camera off/end/new question/hazard cancels outstanding output. Preserve cooldowns so
    /// rapidly toggling a control cannot replenish the background resource budget.
    public mutating func cancel() { activeLease = nil; speechPermitUsed = false }

    private mutating func begin(_ capability: Capability, goal: Goal, evidence: Evidence, moment: Moment) -> Lease {
        let lease = Lease(capability: capability, evidence: evidence, moment: moment, goal: goal)
        activeLease = lease; speechPermitUsed = false; lastStart = moment.now
        // Reserve the base cooldown now, including work cancelled before completion.
        let key = cooldownKey(capability)
        cooldowns[key] = Cooldown(nextAt: moment.now + baseGap(capability), failures: cooldowns[key]?.failures ?? 0)
        return lease
    }
    private func eligible(_ capability: Capability, goal: Goal, evidence: Evidence) -> Bool {
        switch capability {
        case .currencyProbe: return true
        case .currency: return evidence.banknoteCandidate
        case .text: return !goal.intersection([.shopping, .dining, .reading, .payment]).isEmpty
        case .barcode: return !goal.intersection([.shopping, .dining]).isEmpty
        case .light: return evidence.lightAvailable && !goal.intersection([.lighting, .reading, .dressing]).isEmpty
        case .color: return goal.contains(.dressing)
        }
    }
    private func valid(_ lease: Lease, moment: Moment) -> Bool {
        moment.quiescent && moment.requestID == lease.requestID &&
            moment.perceptionGeneration == lease.perceptionGeneration &&
            moment.sessionGeneration == lease.sessionGeneration && moment.goalGeneration == lease.goalGeneration &&
            moment.now >= lease.startedAt && moment.now - lease.startedAt <= Self.leaseLifetime
    }
    private func fresh(_ capturedAt: Double, now: Double, maximumAge: Double) -> Bool {
        capturedAt.isFinite && capturedAt >= 0 && now >= capturedAt && now - capturedAt <= maximumAge
    }
    private func backendAvailable(_ capability: Capability, _ availability: [Capability: Availability]) -> Bool {
        availability[capability] == .available && (capability != .currencyProbe || availability[.currency] == .available)
    }
    private func ready(_ capability: Capability, now: Double, availability: [Capability: Availability]) -> Bool {
        backendAvailable(capability, availability) && now >= (cooldowns[cooldownKey(capability)]?.nextAt ?? 0)
    }
    private func cooldownKey(_ capability: Capability) -> Capability { capability == .currency ? .currencyProbe : capability }
    private func baseGap(_ capability: Capability) -> Double {
        switch capability {
        case .currencyProbe, .currency: return 6
        case .text: return 12
        case .barcode: return 15
        case .light: return 30
        case .color: return 20
        }
    }
    private mutating func complete(_ lease: Lease, outcome: Outcome, now: Double) {
        let key = cooldownKey(lease.capability)
        let failures = outcome == .success || outcome == .noResult ? 0 : min(5, (cooldowns[key]?.failures ?? 0) + 1)
        let gap: Double
        switch outcome {
        case .unavailable: gap = 300
        case .noResult:
            // An ordinary empty view is not a broken backend. Keep silent candidate
            // discovery responsive instead of backing off to minutes after an empty room.
            gap = key == .currencyProbe ? 12 : min(30, baseGap(lease.capability) * 2)
        case .success, .failed: gap = min(120, baseGap(lease.capability) * pow(2, Double(failures)))
        }
        cooldowns[key] = Cooldown(nextAt: now + gap, failures: failures)
        cancel()
    }
    private mutating func observe(_ now: Double) -> Bool {
        guard now.isFinite, now >= 0, lastNow.map({ now >= $0 }) ?? true else { cancel(); return false }
        lastNow = now
        return true
    }
}

/// Temporal stability of already-verified Saudi denominations, not an accuracy guarantee.
/// Two distinct fresh frames can share correlated recognition errors. The caller retains
/// recognizer/pose/availability gates and spoken-result deduplication. Candidates never enter.
public struct ContextualCurrencyConsensus: Sendable {
    public static let maximumSeparation = 12.0
    private var sessionGeneration: UInt64?
    private var previous: (value: Int, capturedAt: Double)?
    private var lastNow: Double?
    public init() {}
    public mutating func reset() { self = Self() }

    public mutating func observe(verifiedDenomination: Int?, capturedAt: Double, now: Double,
                                 sessionGeneration: UInt64) -> Int? {
        guard now.isFinite, now >= 0, lastNow.map({ now >= $0 }) ?? true else { previous = nil; return nil }
        lastNow = now
        if self.sessionGeneration != sessionGeneration { previous = nil; self.sessionGeneration = sessionGeneration }
        guard let value = verifiedDenomination, SaudiBanknotePolicy.denominations.contains(value),
              capturedAt.isFinite, capturedAt >= 0, SaudiBanknotePolicy.fresh(capturedAt: capturedAt, now: now) else {
            previous = nil; return nil
        }
        if let old = previous {
            guard capturedAt > old.capturedAt else {
                if capturedAt < old.capturedAt || value != old.value { previous = nil }
                return nil
            }
            previous = (value, capturedAt)
            if old.value == value && capturedAt - old.capturedAt <= Self.maximumSeparation { return value }
        } else { previous = (value, capturedAt) }
        return nil
    }
}
