import Foundation

/// A bounded conversation receipt, not a workflow engine or physical-world model.
/// Only direct user input enters `ingestUserReport`, before model generation.
/// Model captions, proposed steps, photographs and missing observations cannot
/// establish completion. Open/close language is deliberately the only supported
/// action family; proposal bookkeeping never authorizes handling or speech.
public struct CompanionActionProgressLedger: Codable, Equatable, Sendable {
    public static let maximumSuggestions = 12
    public static let maximumReports = 24
    public static let maximumSourceScalars = 600
    /// Entire encoded field dictionary, including keys and escaping. Whole
    /// source records are omitted with an explicit status, never truncated.
    public static let maximumContextUTF8Bytes = 1_800

    public enum Kind: String, Codable, Sendable {
        case proposed, issuedSuggestion, userReportedCompleted, userReportedState, sensorConfirmed
    }
    public enum Action: String, Codable, Sendable {
        case open, close
        public var resultingReportedState: ReportedState { self == .open ? .open : .closed }
    }
    public enum Target: String, Codable, CaseIterable, Sendable {
        case door, refrigeratorDoor, freezerDoor, cupboardDoor, bedroomDoor, bathroomDoor, frontDoor, backDoor
        case window, box
        fileprivate var isDoor: Bool { self != .window && self != .box }
    }
    public enum ReportedState: String, Codable, Sendable {
        case open, closed, notOpen, notClosed
    }
    public struct Binding: Codable, Equatable, Sendable {
        public let action: Action
        public let target: Target
        public init(action: Action, target: Target) { self.action = action; self.target = target }
    }
    public struct Suggestion: Codable, Equatable, Sendable {
        public let id: String
        public let binding: Binding
        public let text: String
        public let sourceID: String
        public let goalRevision: String
        public let proposedAt: Date
        public fileprivate(set) var issuedAt: Date?
        public fileprivate(set) var retiredByReportID: String?
        public var kind: Kind { issuedAt == nil ? .proposed : .issuedSuggestion }
        public var isRetired: Bool { retiredByReportID != nil }
    }
    public struct Report: Codable, Equatable, Sendable {
        public let id: String
        public let kind: Kind
        public let target: Target
        public let action: Action?
        public let reportedState: ReportedState
        /// Verbatim complete input, not a model-selected positive substring.
        public let sourceReport: String
        public let sourceID: String
        public let at: Date
        public let goalRevision: String
        public fileprivate(set) var relatedSuggestionID: String?
        /// Supersession is retained even if the correcting source is deleted.
        /// Deletion must not resurrect an older reported state as current.
        public fileprivate(set) var supersededByReportID: String?
        public var source: String { "direct user report" }
        public var sourceAttributedSummary: String {
            let time = ISO8601DateFormatter().string(from: at)
            return "User reported \(kind.rawValue), target=\(target.rawValue), state=\(reportedState.rawValue), at=\(time), source=\(sourceID), goalRevision=\(goalRevision): «\(sourceReport)». Not independently confirmed."
        }
    }
    public struct Reduction: Equatable, Sendable {
        public let acceptedReport: Report?
        public let retiredSuggestionIDs: [String]
        /// Only a receipt about this step, never completion of the whole goal.
        public var reportedCompletedSuggestionID: String? {
            acceptedReport?.kind == .userReportedCompleted ? acceptedReport?.relatedSuggestionID : nil
        }
    }

    public private(set) var suggestions: [Suggestion] = []
    public private(set) var reports: [Report] = []
    public init() {}

    /// Closed grammar: unrecognized proposals remain outside this ledger.
    public static func parseProposal(_ text: String) -> Binding? {
        guard boundedText(text), let parsed = Parser.proposal(text), let target = parsed.target else { return nil }
        return Binding(action: parsed.action, target: target)
    }

    @discardableResult
    public mutating func recordProposedSuggestion(_ text: String, goalRevision: String,
                                                  sourceID: String, at: Date = Date()) -> Suggestion? {
        guard validID(goalRevision), validID(sourceID), validDate(at),
              let binding = Self.parseProposal(text), allowsProposal(text, goalRevision: goalRevision) else { return nil }
        // Repeated bookkeeping is idempotent and does not create multiple steps.
        if let existing = suggestions.last(where: {
            !$0.isRetired && $0.goalRevision == goalRevision && $0.binding == binding && $0.sourceID == sourceID
        }) { return existing }
        let value = Suggestion(id: UUID().uuidString, binding: binding, text: text,
            sourceID: sourceID, goalRevision: goalRevision, proposedAt: at)
        suggestions.append(value)
        trim()
        return value
    }

    /// Call only after the actual suggestion was delivered, not after generation
    /// or queueing. It still records words, never physical execution.
    @discardableResult
    public mutating func markIssued(suggestionID: String, goalRevision: String, at: Date = Date()) -> Bool {
        guard validDate(at), let index = suggestions.firstIndex(where: {
            $0.id == suggestionID && $0.goalRevision == goalRevision && !$0.isRetired
        }), suggestions[index].proposedAt <= at else { return false }
        if suggestions[index].issuedAt == nil { suggestions[index].issuedAt = at }
        return true
    }

    /// Consume the original user turn BEFORE generating any new answer. Explicit
    /// named reports can be retained without a step. Pronouns and bare "done"
    /// require exactly one current, actually issued suggestion in this revision.
    @discardableResult
    public mutating func ingestUserReport(_ text: String, sourceID: String, goalRevision: String,
                                         at: Date = Date()) -> Reduction {
        let none = Reduction(acceptedReport: nil, retiredSuggestionIDs: [])
        guard Self.boundedText(text), validID(sourceID), validID(goalRevision), validDate(at),
              !reports.contains(where: { $0.sourceID == sourceID }),
              let parsed = Parser.report(text),
              let resolved = resolve(parsed, current: currentSuggestions(goalRevision: goalRevision, at: at)) else { return none }
        var report = Report(id: UUID().uuidString, kind: parsed.completed ? .userReportedCompleted : .userReportedState,
            target: resolved.target, action: parsed.completed ? resolved.action : nil,
            reportedState: parsed.state ?? resolved.action.resultingReportedState,
            sourceReport: text, sourceID: sourceID, at: at, goalRevision: goalRevision,
            relatedSuggestionID: resolved.suggestionID)
        if let previous = latestReport(for: report.target, goalRevision: goalRevision), previous.at > at {
            report.supersededByReportID = previous.id
        } else {
            for index in reports.indices where reports[index].target == report.target
                && reports[index].goalRevision == goalRevision && reports[index].supersededByReportID == nil {
                reports[index].supersededByReportID = report.id
            }
        }
        reports.append(report)
        var retired: [String] = []
        // Out-of-order history can be kept, but cannot supersede a newer report.
        if latestReport(for: report.target, goalRevision: goalRevision)?.id == report.id {
            for index in suggestions.indices where !suggestions[index].isRetired
                && suggestions[index].goalRevision == goalRevision
                && suggestions[index].proposedAt <= at
                && suggestions[index].binding.target == report.target
                && suggestions[index].binding.action.resultingReportedState == report.reportedState {
                suggestions[index].retiredByReportID = report.id
                retired.append(suggestions[index].id)
            }
        }
        trim()
        return Reduction(acceptedReport: report, retiredSuggestionIDs: retired)
    }

    public func latestReport(for target: Target, goalRevision: String) -> Report? {
        reports.enumerated().filter { $0.element.target == target && $0.element.goalRevision == goalRevision && $0.element.supersededByReportID == nil }
            .max { left, right in left.element.at == right.element.at ? left.offset < right.offset : left.element.at < right.element.at }?.element
    }

    /// Only says whether the bounded proposal would repeat a superseded step.
    /// A true result is NOT safety, evidence or execution authorization. Unknown
    /// language must still pass the caller's existing physical/output gates.
    public func allowsProposal(_ text: String, goalRevision: String) -> Bool {
        guard Self.boundedText(text), validID(goalRevision) else { return false }
        guard let parsed = Parser.proposal(text) else { return true }
        var target = parsed.target
        let current = currentSuggestions(goalRevision: goalRevision, at: .distantFuture)
        if target == nil || target == .door {
            let possible = Set(current.map { $0.binding.target } + reports.filter { $0.goalRevision == goalRevision }.map(\.target))
                .filter { target == nil || $0.isDoor }
            if possible.count == 1 { target = possible.first }
            // An unresolved anaphoric repetition is not a safe new proposal.
            else if !possible.isEmpty { return false }
        }
        guard let target, let report = latestReport(for: target, goalRevision: goalRevision) else { return true }
        return report.reportedState != parsed.action.resultingReportedState
    }

    public func contextFields(goalRevision: String) -> [ContextWindowPolicy.Field] {
        let latest = reports.enumerated().filter {
            $0.element.goalRevision == goalRevision && latestReport(for: $0.element.target, goalRevision: goalRevision)?.id == $0.element.id
        }.sorted { $0.element.at == $1.element.at ? $0.offset > $1.offset : $0.element.at > $1.element.at }.map(\.element)
        let current = suggestions.filter { !$0.isRetired && $0.goalRevision == goalRevision }.suffix(1)
        var fields: [ContextWindowPolicy.Field] = [
            .init("userReportedActionProgressNotSensorConfirmed", []),
            .init("suggestedActionsNotExecuted", []),
            .init("actionSensorConfirmation", ["Unavailable: no validated target-bound door-state sensor. User reports do not establish current physical state or safe handling."]),
            .init("actionProgressContextStatus", [])
        ]
        func fits(_ candidate: [ContextWindowPolicy.Field]) -> Bool {
            let dictionary = Dictionary(uniqueKeysWithValues: candidate.map { ($0.key, $0.values) })
            return ((try? JSONEncoder().encode(dictionary).count) ?? Int.max) <= Self.maximumContextUTF8Bytes
        }
        // Reserve space for explicit omission metadata. Most recent first; if
        // the newest full report cannot fit, never replace it with older state.
        fields[3].values = ["Some source records were omitted. Omitted action context is unavailable, not completion; do not reconstruct it from older suggestions."]
        var omitted = latest.count > 2 || suggestions.filter { !$0.isRetired && $0.goalRevision == goalRevision }.count > 1
        for report in latest.prefix(2) {
            var candidate = fields
            candidate[0].values.append(report.sourceAttributedSummary)
            guard fits(candidate) else { omitted = true; break }
            fields = candidate
        }
        for suggestion in current {
            var candidate = fields
            candidate[1].values.append("\(suggestion.kind.rawValue): \(suggestion.text); target=\(suggestion.binding.target.rawValue); source=\(suggestion.sourceID); goalRevision=\(suggestion.goalRevision). Not completion.")
            if fits(candidate) { fields = candidate } else { omitted = true }
        }
        if !omitted { fields[3].values = [] }
        return fields
    }

    /// A goal change invalidates its current suggestions without erasing reports
    /// or changing a parent goal. Resuming requires a new revision/new suggestion.
    public mutating func retireSuggestions(forGoalRevision revision: String) {
        let removed = Set(suggestions.filter { $0.goalRevision == revision }.map(\.id))
        suggestions.removeAll { removed.contains($0.id) }
        // Retain independently named reports, but not orphaned anaphoric receipts.
        detachReports(from: removed)
    }

    public mutating func removeSource(_ sourceID: String) {
        removeSources(sourceIDs: [sourceID], exactReport: nil)
    }
    public mutating func removeReport(exactText: String) {
        removeSources(sourceIDs: Set(reports.filter { $0.sourceReport == exactText }.map(\.sourceID)), exactReport: exactText)
    }

    private mutating func removeSources(sourceIDs: Set<String>, exactReport: String?) {
        let deletedReports = Set(reports.filter { sourceIDs.contains($0.sourceID) || $0.sourceReport == exactReport }.map(\.id))
        let deletedSuggestions = Set(suggestions.filter {
            sourceIDs.contains($0.sourceID) || $0.retiredByReportID.map(deletedReports.contains) == true
        }.map(\.id))
        suggestions.removeAll { deletedSuggestions.contains($0.id) }
        reports.removeAll { deletedReports.contains($0.id) }
        detachReports(from: deletedSuggestions)
        // Superseded history stays superseded if the correcting source is removed.
    }

    private func currentSuggestions(goalRevision: String, at: Date) -> [Suggestion] {
        suggestions.filter { !$0.isRetired && $0.goalRevision == goalRevision && $0.proposedAt <= at }.map {
            var value = $0
            if let issuedAt = value.issuedAt, issuedAt > at { value.issuedAt = nil }
            return value
        }
    }
    private struct Resolved {
        let target: Target
        let action: Action
        let suggestionID: String?
    }
    private func resolve(_ parsed: Parser.ParsedReport, current: [Suggestion]) -> Resolved? {
        if parsed.target == nil {
            // An unissued candidate, or a second candidate, makes "it/done" ambiguous.
            guard current.count == 1, let step = current.first, step.issuedAt != nil,
                  parsed.action == nil || parsed.action == step.binding.action else { return nil }
            return Resolved(target: step.binding.target, action: parsed.action ?? step.binding.action, suggestionID: step.id)
        }
        var target = parsed.target!
        if target == .door {
            let doorTargets = Set(current.filter { $0.binding.target.isDoor }.map { $0.binding.target })
            if doorTargets.count == 1, let only = doorTargets.first { target = only }
            else if doorTargets.count > 1 { return nil }
        }
        let matching = current.filter { $0.binding.target == target && (parsed.action == nil || $0.binding.action == parsed.action) }
        return Resolved(target: target, action: parsed.action ?? (parsed.state == .closed || parsed.state == .notClosed ? .close : .open),
                        suggestionID: matching.count == 1 ? matching.first?.id : nil)
    }

    private mutating func trim() {
        let previousIDs = Set(suggestions.map(\.id))
        suggestions = Array(suggestions.suffix(Self.maximumSuggestions))
        reports = Array(reports.suffix(Self.maximumReports))
        let reportIDs = Set(reports.map(\.id))
        // Eviction/deletion may forget a step, but never revive a retired one.
        suggestions.removeAll { $0.retiredByReportID.map { !reportIDs.contains($0) } == true }
        detachReports(from: previousIDs.subtracting(Set(suggestions.map(\.id))))
    }
    private mutating func detachReports(from removedSuggestions: Set<String>) {
        reports.removeAll { report in
            report.relatedSuggestionID.map(removedSuggestions.contains) == true
                && Parser.report(report.sourceReport)?.target != report.target
        }
        for index in reports.indices where reports[index].relatedSuggestionID.map(removedSuggestions.contains) == true {
            reports[index].relatedSuggestionID = nil
        }
    }
    private enum CodingKeys: String, CodingKey { case suggestions, reports }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let savedSuggestions = try values.decodeIfPresent([Suggestion].self, forKey: .suggestions) ?? []
        let savedReports = try values.decodeIfPresent([Report].self, forKey: .reports) ?? []
        suggestions = Array(savedSuggestions.filter { item in
            validID(item.id) && validID(item.sourceID) && validID(item.goalRevision) && validDate(item.proposedAt)
                && Self.parseProposal(item.text) == item.binding
                && (item.issuedAt.map { validDate($0) && $0 >= item.proposedAt } ?? true)
                && (item.retiredByReportID.map(validID) ?? true)
        }.suffix(Self.maximumSuggestions))
        var seenSuggestionIDs = Set<String>()
        suggestions = suggestions.filter { seenSuggestionIDs.insert($0.id).inserted }
        reports = Array(savedReports.filter { item in
            guard validID(item.id), validID(item.sourceID), validID(item.goalRevision), validDate(item.at),
                  Self.boundedText(item.sourceReport), (item.supersededByReportID.map(validID) ?? true),
                  let parsed = Parser.report(item.sourceReport),
                  item.kind == (parsed.completed ? .userReportedCompleted : .userReportedState) else { return false }
            let candidates = suggestions.filter {
                $0.goalRevision == item.goalRevision && $0.proposedAt <= item.at
                    && (item.relatedSuggestionID == nil || $0.id == item.relatedSuggestionID)
            }.map {
                var value = $0
                if let issuedAt = value.issuedAt, issuedAt > item.at { value.issuedAt = nil }
                return value
            }
            guard item.relatedSuggestionID == nil || candidates.count == 1,
                  let resolved = resolve(parsed, current: candidates), resolved.target == item.target,
                  (parsed.completed ? resolved.action : nil) == item.action,
                  (parsed.state ?? resolved.action.resultingReportedState) == item.reportedState else { return false }
            return true
        }.suffix(Self.maximumReports))
        var seenReportIDs = Set<String>(), seenSourceIDs = Set<String>()
        reports = reports.filter { seenReportIDs.insert($0.id).inserted && seenSourceIDs.insert($0.sourceID).inserted }
        // Older persisted active reports cannot outweigh a newer report. Existing
        // supersession markers stay tombstoned even when their source was deleted.
        for index in reports.indices where reports[index].supersededByReportID == nil {
            if let newer = latestReport(for: reports[index].target, goalRevision: reports[index].goalRevision), newer.id != reports[index].id {
                reports[index].supersededByReportID = newer.id
            }
        }
        for index in suggestions.indices {
            guard let reportID = suggestions[index].retiredByReportID else { continue }
            let suggestion = suggestions[index]
            if !reports.contains(where: { $0.id == reportID && $0.goalRevision == suggestion.goalRevision
                && $0.target == suggestion.binding.target && $0.reportedState == suggestion.binding.action.resultingReportedState
                && $0.at >= suggestion.proposedAt }) {
                // A forged or lost retirement cannot restore a pending action.
                suggestions[index].retiredByReportID = "invalid-retirement"
            }
        }
        trim()
    }

    private static func boundedText(_ text: String) -> Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && text.unicodeScalars.count <= maximumSourceScalars && text.utf8.count <= 2_400
    }
}

private func validID(_ value: String) -> Bool {
    !value.isEmpty && value.utf8.count <= 120 && !value.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) }
}
private func validDate(_ value: Date) -> Bool {
    value.timeIntervalSinceReferenceDate.isFinite && value >= Date(timeIntervalSince1970: 0) && value < .distantFuture
}

private enum Parser {
    typealias Ledger = CompanionActionProgressLedger
    struct ParsedReport {
        let completed: Bool
        let action: Ledger.Action?
        let target: Ledger.Target?
        let state: Ledger.ReportedState?
    }
    struct ParsedProposal { let action: Ledger.Action; let target: Ledger.Target? }

    static func normalized(_ input: String) -> String {
        SpatialClaimGuard.normalizeArabic(input.lowercased())
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    static func matches(_ pattern: String, _ input: String) -> [String]? {
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let result = expression.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) else { return nil }
        return (1..<result.numberOfRanges).map { index in
            Range(result.range(at: index), in: input).map { String(input[$0]) } ?? ""
        }
    }
    static func clean(_ text: String) -> String? {
        // Entire-turn rejection prevents a quotation, game, conditional, planned
        // action or a positive substring of a negation becoming a receipt.
        guard !text.contains(where: { "?؟\"“”«»`\n\r".contains($0) }) else { return nil }
        var value = normalized(text)
        guard matches(#"\b(?:if|unless|when|would|could|might|maybe|perhaps|will|gonna|going to|pretend|pretended|imagine|imagined|game|story|dream|dreamed|dreamt|said|says|quoted|quote|yesterday|earlier|before|tomorrow|not sure|think|guess|apparently)\b|(?:^| )(?:لو|اذا|سوف|راح|بكره|يمكن|ربما|اظن|اعتقد|لعبه|اللعبه|قصه|القصه|حلم|حلمت|قال|قالت|قلت|امس|سابقا|قبل)(?: |$)"#, value) == nil else { return nil }
        value = value.trimmingCharacters(in: CharacterSet(charactersIn: ".! "))
        value = value.replacingOccurrences(of: #"^(?:no|okay|ok|yes|لا|ايه|نعم)[,،] +"#, with: "", options: .regularExpression)
        return value
    }
    static func target(_ text: String) -> Ledger.Target? {
        var value = normalized(text)
        value = value.replacingOccurrences(of: #"^(?:the|my|our) +"#, with: "", options: .regularExpression)
        let groups: [(Ledger.Target, [String])] = [
            (.refrigeratorDoor, ["fridge", "refrigerator", "fridge door", "refrigerator door", "door of the fridge", "door of the refrigerator", "الثلاجه", "ثلاجه", "باب الثلاجه", "باب ثلاجه"]),
            (.freezerDoor, ["freezer", "freezer door", "الفريزر", "فريزر", "باب الفريزر"]),
            (.cupboardDoor, ["cupboard", "cabinet", "cupboard door", "cabinet door", "الخزانه", "خزانه", "باب الخزانه", "الدولاب", "دولاب", "باب الدولاب"]),
            (.bedroomDoor, ["bedroom door", "باب غرفه النوم"]),
            (.bathroomDoor, ["bathroom door", "باب الحمام"]),
            (.frontDoor, ["front door", "الباب الامامي"]),
            (.backDoor, ["back door", "الباب الخلفي"]),
            (.door, ["door", "الباب", "باب"]),
            (.window, ["window", "النافذه", "نافذه", "الشباك", "شباك"]),
            (.box, ["box", "الصندوق", "صندوق", "العلبه", "علبه"])
        ]
        return groups.first { $0.1.contains(value) }?.0
    }
    static func isPronoun(_ text: String) -> Bool { ["it", "هذا", "هذه", "هو", "هي"].contains(normalized(text)) }
    static func report(_ text: String) -> ParsedReport? {
        guard let value = clean(text) else { return nil }
        if ["done", "finished", "completed", "i'm done", "i am done", "i did it", "i have finished", "i finished", "انتهيت", "خلصت", "تم", "تمت"].contains(value) {
            return ParsedReport(completed: true, action: nil, target: nil, state: nil)
        }
        let suffix = #"(?: already| now| just now| بالفعل| الان| الحين| خلاص)?"#
        if let groups = matches(#"^(?:i(?: have|'ve)? )?(?:already |just )?(opened|closed) (.+?)"# + suffix + "$", value)
            ?? matches(#"^(?:انا )?(?:قد |لقد )?(فتحت|اغلقت|قفلت|سكرت) (.+?)"# + suffix + "$", value) {
            guard let named = target(groups[1]) else {
                if isPronoun(groups[1]) {
                    return ParsedReport(completed: true, action: action(groups[0]), target: nil, state: nil)
                }
                return nil
            }
            return ParsedReport(completed: true, action: action(groups[0]), target: named, state: nil)
        }
        if let groups = matches(#"^(?:انا )?(فتحت|اغلقت|قفلت|سكرت)(?:ه|ها)"# + suffix + "$", value) {
            return ParsedReport(completed: true, action: action(groups[0]), target: nil, state: nil)
        }
        if let groups = matches(#"^(.+?)(?: is|'s| صار| صارت)? (?:already |still |now |الحين |الان )?(open|closed|not open|not closed|مفتوح|مفتوحه|مغلق|مغلقه|مقفل|مقفله|مسكر|مسكره|مو مفتوح|مو مفتوحه|مش مفتوح|ليس مفتوحا|ليست مفتوحه|مو مغلق|مو مغلقه|مو مقفل|مو مقفله|مش مغلق|ليس مغلقا|ليست مغلقه)"# + suffix + "$", value) {
            guard let state = state(groups[1]) else { return nil }
            if let named = target(groups[0]) { return ParsedReport(completed: false, action: nil, target: named, state: state) }
            if isPronoun(groups[0]) { return ParsedReport(completed: false, action: nil, target: nil, state: state) }
        }
        return nil
    }
    static func action(_ verb: String) -> Ledger.Action {
        ["open", "opening", "opened", "افتح", "فتح", "فتحت"].contains(verb) ? .open : .close
    }
    static func state(_ value: String) -> Ledger.ReportedState? {
        switch value {
        case "open", "مفتوح", "مفتوحه": return .open
        case "closed", "مغلق", "مغلقه", "مقفل", "مقفله", "مسكر", "مسكره": return .closed
        case "not open", "مو مفتوح", "مو مفتوحه", "مش مفتوح", "ليس مفتوحا", "ليست مفتوحه": return .notOpen
        case "not closed", "مو مغلق", "مو مغلقه", "مو مقفل", "مو مقفله", "مش مغلق", "ليس مغلقا", "ليست مغلقه": return .notClosed
        default: return nil
        }
    }
    static func proposal(_ text: String) -> ParsedProposal? {
        guard !text.contains(where: { "?؟\"“”«»`\n\r".contains($0) }) else { return nil }
        let value = normalized(text).trimmingCharacters(in: CharacterSet(charactersIn: ".! "))
        guard let groups = matches(#"^(?:(?:please|now|next|you can|you could|let's|lets|try to|try) )?(open|opening|close|closing|افتح|فتح|اغلق|اقفل|سكر) (.+?)(?: please| now| الان| الحين)?$"#, value) else { return nil }
        if let named = target(groups[1]) { return ParsedProposal(action: action(groups[0]), target: named) }
        if isPronoun(groups[1]) { return ParsedProposal(action: action(groups[0]), target: nil) }
        return nil
    }
}
