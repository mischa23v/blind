import Foundation

/// Local orchestration vocabulary. These are adapter selections, never authority
/// to name a face, state a denomination, move, or touch an object. Each adapter
/// retains its own permission, capture, identity and output-evidence gates.
public enum EverydayCapability: String, Codable, CaseIterable, Sendable {
    case savedMemory, readText, readDocument, barcode, clothingColor
    case findItem, familiarPerson, currency, light, deviceClock
}

public struct EverydayTaskRequest: Equatable, Sendable {
    public let capability: EverydayCapability
    public let query: String
    public init?(capability: EverydayCapability, query: String) {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.count <= 300, value.utf8.count <= 1_200,
              !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) || $0.properties.generalCategory == .format }) else { return nil }
        self.capability = capability; self.query = value
    }

    /// Reuse existing whole-request parsers rather than a second inference engine.
    /// Unmatched/ambiguous questions remain conversation. This function does not
    /// execute commands that enroll/delete people or change camera permissions.
    public static func route(_ text: String) -> EverydayTaskRequest? {
        guard EverydayTaskRequest(capability: .savedMemory, query: text) != nil else { return nil }
        if ConversationDomainPolicy.requiredInspection(for: text) == .banknote { return Self(capability: .currency, query: text) }
        if ClothingColorCommand.matches(text) { return Self(capability: .clothingColor, query: text) }
        if let command = FamiliarPeopleCommand.parse(text) {
            switch command {
            case .recognize: return Self(capability: .familiarPerson, query: text)
            case .find(let name): return Self(capability: .familiarPerson, query: name)
            default: return nil
            }
        }
        if case .start(let tool) = ReadingToolCommand.parse(text) {
            let capability: EverydayCapability
            switch tool {
            case .liveText: capability = .readText
            case .document: capability = .readDocument
            case .barcode: capability = .barcode
            case .light: capability = .light
            }
            return Self(capability: capability, query: text)
        }
        if case .find(let item) = ItemCommand.parse(text) { return Self(capability: .findItem, query: item) }
        if case .find(let item) = CompanionUtterance.parse(text) { return Self(capability: .findItem, query: item) }
        let normalized = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        if ["what time is it", "what's the time", "what is the time", "كم الساعة", "كم الساعه"].contains(normalized) {
            return Self(capability: .deviceClock, query: text)
        }
        if ["read this", "read that", "read the label", "read this label", "اقرأ هذا", "اقرا هذا"].contains(normalized) {
            return Self(capability: .readText, query: text)
        }
        return nil
    }
}

/// A bounded ephemeral task controller, separate from the conversation session,
/// sensor loop and navigation route. It preserves an explicit parent goal while
/// a requested reading/colour/item task runs. Ordinary conversation need not call
/// any mutating method. Restoring microphone/sensor permissions is not its job.
public struct EverydayTaskCoordinator: Sendable {
    public enum State: String, Sendable { case idle, active, paused, informationReady, needsHelp, cancelled }
    public enum Failure: String, Hashable, Sendable { case unavailable, notObserved, uncertain, stale, timedOut }
    public enum AdapterOutcome: Equatable, Sendable {
        /// Adapter has already validated its own result. This means information
        /// was obtained, NOT the coat picked up, money authentic or a path clear.
        case informationReady
        /// Useful history was retrieved. Continue the live adapter without
        /// pretending this proves current presence. Controller may speak history.
        case historicalClue
        case retryable(Failure)
        case unavailable
    }
    public struct Ticket: Equatable, Sendable {
        public let id: UUID
        public let request: EverydayTaskRequest
        public let issuedAt: Double
        fileprivate let generation: UUID
    }
    public enum Next: Equatable, Sendable {
        case run(Ticket)
        case unavailable(EverydayCapability)
        case waiting, finished
    }
    public struct Goal: Equatable, Sendable {
        public let id: UUID
        public let description: String
    }
    public static let maximumAttemptsPerAdapter = 2
    public static let attemptLifetime = 20.0
    public static let maximumCompletedSubtasks = 12
    public private(set) var goal: Goal?
    public private(set) var request: EverydayTaskRequest?
    public private(set) var state: State = .idle
    public private(set) var completedSubtasks: [String] = []
    public private(set) var lastFailure: Failure?
    public private(set) var attempts = 0
    public private(set) var historicalClueAvailable = false
    public private(set) var emittedPromptCount = 0
    private var generation = UUID()
    private var plan: [EverydayTaskRequest] = []
    private var index = 0
    private var inFlight: Ticket?
    private var promptReasons: Set<Failure> = []
    private var lastNow: Double?
    public init() {}

    @discardableResult
    public mutating func setGoal(_ text: String) -> Bool {
        guard let bounded = EverydayTaskRequest(capability: .savedMemory, query: text),
              goal?.description != bounded.query else { return false }
        invalidate(); goal = Goal(id: UUID(), description: bounded.query)
        request = nil; state = .idle; completedSubtasks = []; plan = []; index = 0
        attempts = 0; lastFailure = nil; historicalClueAvailable = false
        emittedPromptCount = 0; promptReasons = []; lastNow = nil
        return true
    }

    /// New subtask replaces only the current subtask. An explicit new primary
    /// objective must call setGoal. Repeating the same active request is idempotent.
    @discardableResult
    public mutating func begin(_ next: EverydayTaskRequest) -> Bool {
        if request == next && (state == .active || state == .paused) { return false }
        invalidate(); request = next; state = .active; lastFailure = nil
        historicalClueAvailable = false; attempts = 0; index = 0
        emittedPromptCount = 0; promptReasons = []; lastNow = nil
        if goal == nil { goal = Goal(id: UUID(), description: next.query) }
        plan = next.capability == .findItem
            ? [EverydayTaskRequest(capability: .savedMemory, query: next.query)!, next] : [next]
        return true
    }

    public mutating func next(available: Set<EverydayCapability>, now: Double) -> Next {
        guard state == .active else { return state == .paused ? .waiting : .finished }
        guard validTime(now) else { fail(.stale); return .finished }
        if let active = inFlight {
            if now - active.issuedAt < Self.attemptLifetime { return .waiting }
            inFlight = nil; lastFailure = .timedOut
        }
        guard index < plan.count else { state = .needsHelp; return .finished }
        let operation = plan[index]
        guard available.contains(operation.capability) else {
            lastFailure = .unavailable
            advance() // Memory may be absent while live search remains available.
            return .unavailable(operation.capability)
        }
        guard attempts < Self.maximumAttemptsPerAdapter else {
            if operation.capability == .savedMemory && index + 1 < plan.count {
                advance()
                return next(available: available, now: now)
            }
            fail(lastFailure ?? .timedOut); return .finished
        }
        attempts += 1
        let ticket = Ticket(id: UUID(), request: operation, issuedAt: now, generation: generation)
        inFlight = ticket
        return .run(ticket)
    }

    /// Returns false for late, cancelled, replaced, paused or duplicate results.
    @discardableResult
    public mutating func receive(_ ticket: Ticket, outcome: AdapterOutcome, now: Double) -> Bool {
        guard state == .active, inFlight == ticket, ticket.generation == generation,
              validTime(now), now >= ticket.issuedAt, now - ticket.issuedAt < Self.attemptLifetime else { return false }
        inFlight = nil
        switch outcome {
        case .informationReady:
            if ticket.request.capability == .savedMemory && request?.capability == .findItem {
                historicalClueAvailable = true; advance()
            } else { state = .informationReady }
        case .historicalClue:
            historicalClueAvailable = true
            if index + 1 < plan.count { advance() } else { state = .informationReady }
        case .unavailable:
            lastFailure = .unavailable; advance()
        case .retryable(let reason):
            lastFailure = reason
            if ticket.request.capability == .savedMemory { advance() }
            else if attempts >= Self.maximumAttemptsPerAdapter { state = .needsHelp }
        }
        return true
    }

    /// Prompt once per concrete reason for this subtask; not once per frame or
    /// failed attempt. Caller renders a truthful useful fallback, never "absent".
    public mutating func admitPrompt(for reason: Failure) -> Bool {
        guard state != .cancelled, request != nil, !promptReasons.contains(reason), promptReasons.count < 3 else { return false }
        promptReasons.insert(reason); emittedPromptCount += 1; return true
    }

    /// Acknowledging a tool result does not complete the parent's real-world goal.
    /// The caller invokes this only for an explicit task-completion confirmation.
    @discardableResult
    public mutating func confirmSubtaskComplete() -> Bool {
        guard let request, state != .cancelled, state != .idle else { return false }
        if !completedSubtasks.contains(request.query) {
            completedSubtasks.append(request.query)
            if completedSubtasks.count > Self.maximumCompletedSubtasks { completedSubtasks.removeFirst() }
        }
        invalidate(); self.request = nil; plan = []; state = .idle
        return true
    }
    public mutating func pause() {
        guard state == .active else { return }
        invalidate(); state = .paused
    }
    public mutating func resume() { if state == .paused { state = .active } }
    public mutating func cancelSubtask() { invalidate(); request = nil; plan = []; state = .cancelled }
    public mutating func cancelAll() { cancelSubtask(); goal = nil; completedSubtasks = [] }

    private mutating func advance() {
        index += 1; attempts = 0
        if index >= plan.count { state = .needsHelp }
    }
    private mutating func invalidate() { generation = UUID(); inFlight = nil }
    private mutating func fail(_ reason: Failure) { invalidate(); lastFailure = reason; state = .needsHelp }
    private mutating func validTime(_ now: Double) -> Bool {
        guard now.isFinite, lastNow.map({ now >= $0 }) ?? true else { return false }
        lastNow = now; return true
    }
}
