import Foundation

/// Goal-led selection before speech (E02/E12/M12).
/// Familiar places are background knowledge for the current goal; descriptions are for
/// new places, waiting time or explicit requests. Hazards never wait for an offer, a goal,
/// quiet mode or the word budget. Producers re-propose fresh candidates each tick, so
/// nothing old is queued here; `wait` means "propose again later if still true".

public enum CompanionActivity: String, Codable, Sendable { case moving, stationary, unknown }

/// What happens on the first visit to a room: a short offer (default), a description, or nothing.
public enum FirstVisitMode: String, Codable, Sendable { case offer, describe, never }

public struct CompanionOffer: Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case describeRoom, confirmRoom, suggestion, itemDirections }
    public let kind: Kind
    public let subject: String
    public let prompt: String
    public let expiresAt: Double
}

public struct InformationCandidate: Equatable, Sendable {
    public enum Kind: String, Sendable { case hazard, mobility, operation, answer, goal, change, roomDescription, social, discovery, offer }
    /// Stable semantic subject, e.g. "room:kitchen:description" or "track:3:arrival".
    public let key: String
    public let kind: Kind
    public let text: String
    /// Counted by the caller with platform word segmentation, not by this policy.
    public let words: Int
    /// Content/evidence revision; the same key and revision is not said twice unless requested.
    public let revision: String
    public let createdAt: Double
    public let expiresAt: Double
    public var category: String?
    public var requested: Bool
    public var goalRelevant: Bool
    public var room: String?
    public var offerKind: CompanionOffer.Kind?
    public init(key: String, kind: Kind, text: String, words: Int, revision: String = "1",
                createdAt: Double, expiresAt: Double, category: String? = nil, requested: Bool = false,
                goalRelevant: Bool = false, room: String? = nil, offerKind: CompanionOffer.Kind? = nil) {
        self.key = key; self.kind = kind; self.text = text; self.words = words; self.revision = revision
        self.createdAt = createdAt; self.expiresAt = expiresAt; self.category = category
        self.requested = requested; self.goalRelevant = goalRelevant; self.room = room; self.offerKind = offerKind
    }
    public var priority: SpeechPriority { kind == .hazard ? .danger : kind == .mobility ? .mobility : .information }
}

public enum CompanionReason: String, Sendable {
    case hazard, mobility, operation, requested, goal, change, firstVisit, information, offered
    case invalid, expired, speechBusy, quiet, muted, onRequestOnly, alreadySaid, familiarRoom
    case goalInProgress, offerFirst, declined, never, tooSoon, offerPending, budget
}

public enum CompanionDecision: Equatable, Sendable {
    case say(InformationCandidate, CompanionReason)
    case offer(CompanionOffer, CompanionReason)
    case wait(String, CompanionReason)
    case drop(String, CompanionReason)
    public var reason: CompanionReason {
        switch self { case .say(_, let r), .offer(_, let r), .wait(_, let r), .drop(_, let r): return r }
    }
}

public enum OfferAnswer: Sendable { case yes, no, silence }
public enum RoomEntry: Equatable, Sendable { case firstVisit, familiar, unconfirmed }

/// A reviewable, removable pattern learned from repeated declines (M09). Never a capability label.
public struct LearnedHint: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let kind: CompanionOffer.Kind
    public let scope: String
    public let declines: Int
}

public struct RoomRecord: Codable, Equatable, Sendable {
    public var visits = 0
    public var described = false
    /// The room's spoken name, for questions such as "Is this your bedroom?".
    public var name: String?
    /// A user-stated identity; never geometry, alignment or clearance.
    public var confirmedByUser = false
    public init() {}
}

/// Persisted, reviewable memory. Session timing and delivered history are deliberately not stored.
public struct CompanionMemory: Codable, Equatable, Sendable {
    public var rooms: [String: RoomRecord] = [:]
    public private(set) var declineCounts: [String: Int] = [:]
    public private(set) var hints: [LearnedHint] = []
    public init() {}
    public mutating func removeHint(id: String) { hints.removeAll { $0.id == id }; declineCounts[id] = nil }
    public mutating func forgetRoom(_ id: String) { rooms[id] = nil }
    mutating func recordDecline(id: String, kind: CompanionOffer.Kind, scope: String, threshold: Int) {
        let count = (declineCounts[id] ?? 0) + 1
        declineCounts[id] = count
        if count >= threshold, !hints.contains(where: { $0.id == id }) {
            hints.append(LearnedHint(id: id, kind: kind, scope: scope, declines: count))
        }
    }
}

public struct CompanionSettings: Sendable {
    public var firstVisitRooms: FirstVisitMode
    /// Minimum seconds between unsolicited ordinary items; goal and requested information are exempt.
    public var minimumGap: Double
    public var wordsPerMinute: Int
    public var preferences: AssistantPreferences
    public var quiet: Bool
    /// Seconds the listener has to answer an offer, counted from when it is spoken.
    public var offerWindow: Double
    public init(firstVisitRooms: FirstVisitMode = .offer, minimumGap: Double = 10, wordsPerMinute: Int = 180,
                preferences: AssistantPreferences = AssistantPreferences(), quiet: Bool = false, offerWindow: Double = 8) {
        self.firstVisitRooms = firstVisitRooms; self.minimumGap = minimumGap
        self.wordsPerMinute = wordsPerMinute; self.preferences = preferences; self.quiet = quiet; self.offerWindow = offerWindow
    }
}

/// One immutable snapshot per decision.
public struct CompanionMoment: Sendable {
    public var now: Double
    public var goalActive: Bool
    /// A short explicit task, such as finding a named person, also focuses attention while still.
    /// This is not a motion estimate and does not replace the person's persistent destination.
    public var focusedTaskActive: Bool
    public var activity: CompanionActivity
    public var speaking: SpeechPriority?
    public init(now: Double, goalActive: Bool = false, focusedTaskActive: Bool = false,
                activity: CompanionActivity = .unknown, speaking: SpeechPriority? = nil) {
        self.now = now; self.goalActive = goalActive; self.focusedTaskActive = focusedTaskActive
        self.activity = activity; self.speaking = speaking
    }
}

/// Decisions are returned in priority order (hazard, mobility, requested, goal, change, other),
/// not input order. A requested answer waits while speech is active; callers interrupt ordinary
/// speech first when the person asks something.
public struct CompanionAttention: Sendable {
    public static let hintThreshold = 3
    public static let deliveredLimit = 512
    /// Essential feedback for one current explicit action, never a description or identity hint.
    public static let maximumOperationWords = 80
    public static let maximumOperationLifetime = 30.0
    public var memory: CompanionMemory
    public private(set) var pendingOffer: CompanionOffer?
    public private(set) var currentRoom: String?
    private var lastEstablishedRoom: String?
    private var roomCandidate: (id: String, since: Double)?
    private var delivered: [String: String] = [:]
    private var declinedThisSession: Set<String> = []
    private var budget = NarrationBudget()
    private var lastOrdinary = -Double.infinity

    public init(memory: CompanionMemory = CompanionMemory()) { self.memory = memory }

    /// `established` means map matching or the user confirmed the room. An unestablished
    /// room is not counted as a visit and leaves the current room unknown.
    /// Returning to the same room after a brief loss of localisation continues that visit.
    @discardableResult public mutating func enterRoom(_ id: String, established: Bool) -> RoomEntry {
        guard established, !id.isEmpty else { currentRoom = nil; return .unconfirmed }
        // An offer about the previous room no longer applies; withdrawing it is not a decline.
        if currentRoom != id { pendingOffer = nil }
        let record = memory.rooms[id] ?? RoomRecord()
        let continuing = id == lastEstablishedRoom
        let earlierVisits = record.visits - (continuing ? 1 : 0)
        let entry: RoomEntry = earlierVisits <= 0 && !record.described ? .firstVisit : .familiar
        if !continuing { memory.rooms[id, default: RoomRecord()].visits += 1 }
        currentRoom = id; lastEstablishedRoom = id
        return entry
    }

    /// Debounced room observations from localisation: a room becomes current only after it has
    /// been reported steadily for `settleTime`, so a doorway flicker never becomes a visit.
    public mutating func observeRoom(_ id: String?, established: Bool, now: Double, settleTime: Double = 2) -> RoomEntry? {
        guard established, let id, !id.isEmpty, now.isFinite else { roomCandidate = nil; currentRoom = nil; return nil }
        if id == currentRoom { roomCandidate = nil; return nil }
        guard let candidate = roomCandidate, candidate.id == id, now >= candidate.since else {
            roomCandidate = (id, now); return nil
        }
        guard now - candidate.since >= settleTime else { return nil }
        roomCandidate = nil
        return enterRoom(id, established: true)
    }

    /// An item chosen but never actually spoken (empty answer, view changed) can be proposed again.
    public mutating func release(_ key: String) { delivered[key] = nil }

    public mutating func userConfirmedRoom(_ id: String) {
        guard !id.isEmpty else { return }
        memory.rooms[id, default: RoomRecord()].confirmedByUser = true
    }

    /// Yes returns the accepted offer so the caller can run it as a requested item.
    /// No and silence are not repeated this session; only an explicit no counts toward a
    /// reviewable hint, because silence is not a preference.
    @discardableResult public mutating func answerOffer(_ answer: OfferAnswer) -> CompanionOffer? {
        guard let offer = pendingOffer else { return nil }
        pendingOffer = nil
        if answer == .yes { return offer }
        recordDecline(offer, explicit: answer == .no); return nil
    }

    /// Clears an offer that could not be spoken; not a decline.
    public mutating func withdrawOffer() { pendingOffer = nil }

    /// Runs the gates without committing, so callers can skip generation that would not be spoken.
    public mutating func check(_ item: InformationCandidate, moment: CompanionMoment, settings: CompanionSettings) -> CompanionDecision {
        gate(item, moment: moment, settings: settings, speaking: moment.speaking)
    }

    public mutating func decide(_ candidates: [InformationCandidate], moment: CompanionMoment,
                                settings: CompanionSettings) -> [CompanionDecision] {
        if let offer = pendingOffer, moment.now > offer.expiresAt { pendingOffer = nil; recordDecline(offer, explicit: false) }
        var speaking = moment.speaking
        var results: [CompanionDecision] = []
        for item in candidates.sorted(by: Self.order) {
            let decision = gate(item, moment: moment, settings: settings, speaking: speaking)
            switch decision {
            case .say(let said, _):
                speaking = said.priority
                if said.kind == .hazard { pendingOffer = nil }
                if said.kind != .hazard {
                    if delivered.count >= Self.deliveredLimit { delivered.removeAll(keepingCapacity: true) }
                    delivered[said.key] = said.revision
                }
                if said.priority == .information && said.kind != .operation {
                    budget.charge(words: said.words, limit: settings.wordsPerMinute, now: moment.now)
                    lastOrdinary = moment.now
                    if said.kind == .roomDescription, let room = said.room { memory.rooms[room, default: RoomRecord()].described = true }
                }
            case .offer(let offer, _):
                speaking = .information; pendingOffer = offer
                budget.charge(words: item.words, limit: settings.wordsPerMinute, now: moment.now)
                lastOrdinary = moment.now
            case .wait, .drop: break
            }
            results.append(decision)
        }
        return results
    }

    private mutating func gate(_ item: InformationCandidate, moment: CompanionMoment,
                               settings: CompanionSettings, speaking: SpeechPriority?) -> CompanionDecision {
        // A hazard is never dropped for bookkeeping reasons (zero words for a tone, open expiry),
        // but a stale hazard warning (past a finite expiry) is still dropped.
        if item.kind == .hazard, !item.key.isEmpty, moment.now.isFinite {
            if item.expiresAt.isFinite, moment.now > item.expiresAt { return .drop(item.key, .expired) }
            return .say(item, .hazard)
        }
        guard item.words > 0, !item.key.isEmpty, item.createdAt.isFinite, item.expiresAt.isFinite,
              moment.now.isFinite else { return .drop(item.key, .invalid) }
        guard moment.now <= item.expiresAt else { return .drop(item.key, .expired) }
        switch item.kind {
        case .hazard:
            return .say(item, .hazard)
        case .mobility:
            if delivered[item.key] == item.revision { return .drop(item.key, .alreadySaid) }
            return item.priority.canInterrupt(speaking) ? .say(item, .mobility) : .wait(item.key, .speechBusy)
        case .operation:
            // Consent, confirmation, cancellation, error and bounded progress for a current
            // user action must remain audible even when ordinary narration has used its budget.
            // Callers never queue these notices, and identity/scene answers stay ordinary answers.
            guard item.requested, item.words <= Self.maximumOperationWords,
                  item.createdAt <= moment.now, item.expiresAt >= item.createdAt,
                  item.expiresAt - item.createdAt <= Self.maximumOperationLifetime,
                  !item.revision.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .drop(item.key, .invalid) }
            return speaking == nil ? .say(item, .operation) : .wait(item.key, .speechBusy)
        default: break
        }
        // An explicit request is answered even for a muted category, in quiet mode, or as a repeat.
        if item.requested {
            if speaking != nil { return .wait(item.key, .speechBusy) }
            return fits(item, settings, moment) ? .say(item, .requested) : .wait(item.key, .budget)
        }
        // Reasons that remove an item come before reasons that only delay it.
        if let reason = dropReason(item, settings) { return .drop(item.key, reason) }
        if speaking != nil { return .wait(item.key, .speechBusy) }
        if item.goalRelevant { return fits(item, settings, moment) ? .say(item, .goal) : .wait(item.key, .budget) }
        // An explicit focused task suppresses unrelated narration even while stationary.
        // Fresh hazards, mobility, requested answers and task-relevant information passed above.
        if moment.focusedTaskActive { return .wait(item.key, .goalInProgress) }
        if pendingOffer != nil { return .wait(item.key, .offerPending) }
        // Walking toward a goal: offers and descriptions wait; room identity questions do not.
        if moment.goalActive && moment.activity != .stationary && item.offerKind != .confirmRoom {
            return .wait(item.key, .goalInProgress)
        }
        if moment.now - lastOrdinary < settings.minimumGap { return .wait(item.key, .tooSoon) }
        guard fits(item, settings, moment) else { return .wait(item.key, .budget) }
        if let kind = item.offerKind {
            return .offer(CompanionOffer(kind: kind, subject: item.room ?? item.key, prompt: item.text,
                                         expiresAt: moment.now + settings.offerWindow), .offered)
        }
        return .say(item, item.kind == .roomDescription ? .firstVisit : item.kind == .change ? .change : .information)
    }

    private func dropReason(_ item: InformationCandidate, _ settings: CompanionSettings) -> CompanionReason? {
        if settings.quiet { return .quiet }
        if let category = item.category {
            switch settings.preferences.mode(for: category) {
            case "muted": return .muted
            case "onRequest": return .onRequestOnly
            default: break
            }
        }
        if delivered[item.key] == item.revision { return .alreadySaid }
        if item.kind == .roomDescription || item.offerKind == .describeRoom {
            guard let room = item.room else { return .invalid }
            let record = memory.rooms[room] ?? RoomRecord()
            if record.described || record.visits > 1 { return .familiarRoom }
            if settings.firstVisitRooms == .never { return .never }
            if item.kind == .roomDescription && settings.firstVisitRooms == .offer { return .offerFirst }
        }
        if let kind = item.offerKind {
            let subject = item.room ?? item.key
            if declinedThisSession.contains(Self.sessionID(kind, subject)) { return .declined }
            if kind != .confirmRoom, memory.hints.contains(where: { $0.id == Self.hintID(kind, subject) }) { return .declined }
        }
        return nil
    }

    private mutating func fits(_ item: InformationCandidate, _ settings: CompanionSettings, _ moment: CompanionMoment) -> Bool {
        item.words <= budget.allowance(limit: settings.wordsPerMinute, now: moment.now)
    }

    private mutating func recordDecline(_ offer: CompanionOffer, explicit: Bool) {
        declinedThisSession.insert(Self.sessionID(offer.kind, offer.subject))
        // Room identity questions support orientation; declining them never becomes a habit.
        guard explicit, offer.kind != .confirmRoom else { return }
        memory.recordDecline(id: Self.hintID(offer.kind, offer.subject), kind: offer.kind,
                             scope: offer.kind == .describeRoom ? "*" : offer.subject, threshold: Self.hintThreshold)
    }

    static func sessionID(_ kind: CompanionOffer.Kind, _ subject: String) -> String { "\(kind.rawValue):\(subject)" }
    /// Room-description declines generalise across rooms; other offers stay tied to their subject.
    static func hintID(_ kind: CompanionOffer.Kind, _ subject: String) -> String {
        "\(kind.rawValue):\(kind == .describeRoom ? "*" : subject)"
    }

    static func order(_ a: InformationCandidate, _ b: InformationCandidate) -> Bool {
        let ra = rank(a), rb = rank(b)
        if ra != rb { return ra < rb }
        if a.createdAt != b.createdAt { return a.createdAt < b.createdAt }
        return a.key < b.key
    }
    static func rank(_ item: InformationCandidate) -> Int {
        switch item.kind {
        case .hazard: return 0
        case .mobility: return 1
        case .operation: return 2
        default: return item.requested ? 2 : item.goalRelevant ? 3 : item.kind == .change ? 4 : 5
        }
    }
}
