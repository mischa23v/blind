import Foundation
import CoreVideo
import ImageIO
import os
import NaturalLanguage
import BlindCore
#if canImport(FoundationModels)
import FoundationModels
#endif

struct LocalImageAnswer {
    let text: String?
    let status: String
    var taskUpdate: CompanionTaskUpdate? = nil
    // Operational failure is not model content or an evidence-guard refusal.
    // Keep text nil so integration fixtures cannot pass on this fallback.
    enum ConversationRuntimeFailure: String, Equatable {
        case generationFailed
        case modelUnavailable
    }
    var conversationRuntimeFailure: ConversationRuntimeFailure? = nil

    static func conversationFailure(_ failure: ConversationRuntimeFailure, arabic: Bool) -> LocalImageAnswer {
        let message: String
        switch failure {
        case .generationFailed:
            message = arabic ? "تعذر إكمال الرد على الجهاز الآن." : "I couldn't finish an on-device reply just now."
        case .modelUnavailable:
            message = arabic ? "نموذج المحادثة غير متاح على هذا الجهاز. لا يلزم اشتراك أو مفتاح API." : "The on-device conversation model is unavailable on this device. No subscription or API key is needed."
        }
        return LocalImageAnswer(text: nil, status: message, conversationRuntimeFailure: failure)
    }

    /// Controllers still apply their current request/session/cancellation fences.
    var conversationOperationalFallback: String? {
        guard text == nil, conversationRuntimeFailure != nil else { return nil }
        return status
    }
}

/// App-owned state: a proposed step is never recorded as an executed action.
struct CompanionTaskUpdate: Codable, Sendable {
    var goal: String
    var nextStep: String
    var completionReport: String
    var completionStep: String = ""
    var cancellationReport: String = ""
    var fact: CompanionReportedFact? = nil
    var contextRevision: String? = nil
}
struct CompanionReportedFact: Codable, Sendable {
    var subject: String
    var value: String
    var quote: String
    // Optional for backwards-compatible decoding of older local records.
    // Retain the complete original report for review/correction/deletion.
    var sourceReport: String? = nil
    var sourceID: String? = nil
}
struct CompanionWorkingState: Codable, Sendable {
    struct CorrectionOrigin: Codable, Sendable, Equatable {
        let sourceID: String
        let reportedAt: Date?
        var valid: Bool { !sourceID.isEmpty && sourceID.utf8.count <= 64 && (reportedAt.map {
            $0.timeIntervalSinceReferenceDate.isFinite && $0 >= .distantPast && $0 <= .distantFuture
        } ?? true) }
    }
    struct Report: Codable, Sendable, Equatable {
        var text: String
        var time: Date?
        var sourceID: String? = nil
        var correctionOrigin: CorrectionOrigin? = nil
    }
    /// Selection receipts are transient and cannot survive process restart.
    private var reviewEpoch = UUID().uuidString
    struct ReviewSelection: Equatable, Identifiable, Sendable {
        let sourceID: String
        let scope: CompanionMemoryScope?
        let report: Report
        let epoch: String
        let contextRevision: String
        var id: String { sourceID }
        /// Stored identity fields, not inferred human names or live localization.
        func originalContext(arabic: Bool) -> String {
            guard let scope else { return arabic ? "السياق الأصلي غير معروف؛ تقرير غير مرتبط بمكان" : "Original context unknown; unscoped report" }
            let fields = arabic
                ? ["المكان: " + scope.placeID, "الطابق: " + scope.floorID, "الغرفة: " + scope.roomID,
                   "الغرض المحدد: " + (scope.objectInstanceID ?? "غير معروف؛ سياق الغرفة فقط"),
                   "الخريطة: " + scope.map.mapID, "الإطار: " + scope.map.frameID, "المراجعة: " + scope.map.revision]
                : ["Place ID: " + scope.placeID, "Floor ID: " + scope.floorID, "Room ID: " + scope.roomID,
                   "Object-instance ID: " + (scope.objectInstanceID ?? "unknown; room-level context only"),
                   "Map ID: " + scope.map.mapID, "Frame ID: " + scope.map.frameID, "Revision: " + scope.map.revision]
            return fields.joined(separator: "; ")
        }
    }
    var reviewSelections: [ReviewSelection] {
        var candidates: [(CompanionMemoryScope?, Report)] = reports.map { (memoryScope, $0) }
        candidates += scopedTaskHistory.flatMap { history in history.reports.map { (history.scope, $0) } }
        let retained = Set(candidates.compactMap { $0.1.sourceID })
        candidates += factBook.facts.compactMap { fact in
            guard let sourceID = fact.sourceID, !retained.contains(sourceID), let text = locationReportSources[fact.storageKey] else { return nil }
            return (fact.scope, Report(text: text, time: fact.at, sourceID: sourceID))
        }
        let counts = Dictionary(grouping: candidates.compactMap { $0.1.sourceID }, by: { $0 }).mapValues(\.count)
        return candidates.compactMap { scope, report in
            guard let id = report.sourceID, !id.isEmpty, id.utf8.count <= 64, counts[id] == 1 else { return nil }
            return ReviewSelection(sourceID: id, scope: scope, report: report, epoch: reviewEpoch, contextRevision: goalRevision)
        }
    }
    /// Legacy task sources sometimes have independent IDs. A text match can
    /// detect ambiguity and refuse an edit, never assign ownership or erase it.
    func hasUnboundTaskDependency(_ selection: ReviewSelection) -> Bool {
        let bound = Set(reviewSelections.map(\.sourceID))
        let sources = [goalSource, parentGoal?.source] + suspendedGoals.flatMap { [$0.source, $0.parentGoal?.source] } + scopedTaskHistory.map(\.goalSource)
        let unboundLabels = [goalSource == nil ? goal : nil, parentGoal?.source == nil ? parentGoal?.goal : nil]
            + suspendedGoals.flatMap { [$0.source == nil ? $0.goal : nil, $0.parentGoal?.source == nil ? $0.parentGoal?.goal : nil] }
            + scopedTaskHistory.map { $0.goalSource == nil ? $0.goal : nil }
        return unboundLabels.compactMap { $0 }.contains(selection.report.text) ||
            sources.compactMap { $0 }.contains { !bound.contains($0.sourceID) && $0.originalRequest == selection.report.text }
    }
    func acceptsReviewSelection(_ selection: ReviewSelection) -> Bool {
        selection.epoch == reviewEpoch && selection.contextRevision == goalRevision && reviewSelections.contains(selection) && !hasUnboundTaskDependency(selection)
    }
    /// An atomic explicit edit retains the ORIGINAL ownership, not the current
    /// room. The new source is a correction report, never an observation.
    @discardableResult mutating func reviseReviewedSource(_ selection: ReviewSelection, replacement: String?, at: Date = Date()) -> Bool {
        guard acceptsReviewSelection(selection), at.timeIntervalSinceReferenceDate.isFinite,
              at >= .distantPast, at <= .distantFuture else { return false }
        if let replacement {
            guard !replacement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  replacement.unicodeScalars.count <= AssistantDialogue.maximumTurnScalars else { return false }
        }
        var next = self
        if next.searchAreaClue.clue?.sourceID == selection.sourceID { next.searchAreaClue.clear() }
        let originalFact = next.factBook.facts.first { $0.sourceID == selection.sourceID }
        let active = next.memoryScope == selection.scope
        let old = selection.report.text
        if let originalFact {
            next.retireSearchClue(object: originalFact.object, scope: originalFact.scope)
            _ = next.factBook.forgetSource(selection.sourceID)
            next.locationReportSources.removeValue(forKey: originalFact.storageKey)
        }
        func dependent(_ fact: CompanionReportedFact) -> Bool {
            fact.sourceID == selection.sourceID || (fact.sourceID == nil && (fact.sourceReport == old || fact.quote == old))
        }
        if active {
            next.reports.removeAll { $0.sourceID == selection.sourceID }
            next.facts.removeAll(where: dependent)
            next.actionProgress.removeSource(selection.sourceID)
            next.actionProgress.removeReport(exactText: old)
            next.reportedStepAssociations.removeAll { $0.report == old }
            next.reportedCompletedSteps = []; next.proposedStep = ""
            next.parentGoal?.reportedCompletedSteps = []
            // Scope transitions already strip suspended physical progress. While
            // still in this scope, invalidate legacy completion derivatives too.
            for index in next.suspendedGoals.indices {
                next.suspendedGoals[index].reportedCompletedSteps = []
                next.suspendedGoals[index].proposedStep = ""
                next.suspendedGoals[index].parentGoal?.reportedCompletedSteps = []
            }
            next.goalRevision = UUID().uuidString
        }
        for index in next.scopedTaskHistory.indices where next.scopedTaskHistory[index].scope == selection.scope {
            next.scopedTaskHistory[index].reports.removeAll { $0.sourceID == selection.sourceID }
            next.scopedTaskHistory[index].facts.removeAll(where: dependent)
            next.scopedTaskHistory[index].completedSteps = []
        }
        // Goal intent is removed only through an actual source-ID dependency,
        // including an intent carried across rooms. Never guess by matching text.
        if next.goalSource?.sourceID == selection.sourceID {
            next.goal = ""; next.goalSource = nil; next.proposedStep = ""
            next.focusObject = ""; next.lastSearch = nil
            next.reportedCompletedSteps = []; next.reportedStepAssociations = []
            next.goalRevision = UUID().uuidString
        }
        if next.parentGoal?.source?.sourceID == selection.sourceID { next.parentGoal = nil }
        next.suspendedGoals.removeAll { $0.source?.sourceID == selection.sourceID }
        for index in next.suspendedGoals.indices where next.suspendedGoals[index].parentGoal?.source?.sourceID == selection.sourceID {
            next.suspendedGoals[index].parentGoal = nil
        }
        for index in next.scopedTaskHistory.indices where next.scopedTaskHistory[index].goalSource?.sourceID == selection.sourceID {
            next.scopedTaskHistory[index].goal = ""; next.scopedTaskHistory[index].goalSource = nil
            next.scopedTaskHistory[index].completedSteps = []
        }
        if let replacement {
            let report = Report(text: replacement, time: at, sourceID: UUID().uuidString,
                correctionOrigin: CorrectionOrigin(sourceID: selection.sourceID, reportedAt: selection.report.time))
            if active { next.reports = Array((next.reports + [report]).suffix(12)) }
            else if let index = next.scopedTaskHistory.lastIndex(where: { $0.scope == selection.scope }) {
                next.scopedTaskHistory[index].reports = Array((next.scopedTaskHistory[index].reports + [report]).suffix(12))
            } else {
                next.scopedTaskHistory.append(ScopedTaskHistory(scope: selection.scope, goal: "", goalRevision: UUID().uuidString,
                    reports: [report], facts: [], completedSteps: []))
                next.scopedTaskHistory = Array(next.scopedTaskHistory.suffix(12))
            }
            if case .report(let named, let place, let tense, let hedged)? = CompanionUtterance.parse(replacement),
               let object = named ?? originalFact?.object,
               let fact = next.factBook.record(object: object, place: place, tense: tense, hedged: hedged,
                    at: at, scope: selection.scope, sourceID: report.sourceID!) {
                next.locationReportSources[fact.storageKey] = replacement
            }
        }
        next.reviewEpoch = UUID().uuidString
        self = next
        return true
    }
    /// Set only by the controller's established place/instance adapter. Never by
    /// a goal string or language model. Nil means identity unknown.
    private(set) var memoryScope: CompanionMemoryScope?
    struct ScopedTaskHistory: Codable, Sendable {
        var scope: CompanionMemoryScope?
        var goal: String
        var goalRevision: String
        var reports: [Report]
        var facts: [CompanionReportedFact]
        var completedSteps: [String]
        var goalSource: CompanionTaskSource? = nil
        var valid: Bool {
            (goalSource == nil || goalSource?.canonicalLabel == goal) && scope?.valid != false && goal.unicodeScalars.count <= 300 && !goalRevision.isEmpty && goalRevision.utf8.count <= 64 &&
            reports.count <= 12 && facts.count <= 12 && completedSteps.count <= 12 &&
            reports.allSatisfy { ($0.correctionOrigin?.valid ?? true) && !$0.text.isEmpty && $0.text.unicodeScalars.count <= AssistantDialogue.maximumTurnScalars &&
                ($0.sourceID.map { !$0.isEmpty && $0.utf8.count <= 64 } ?? true) &&
                ($0.time.map { $0.timeIntervalSinceReferenceDate.isFinite && $0 >= .distantPast && $0 <= .distantFuture } ?? true) } &&
            facts.allSatisfy { $0.subject.unicodeScalars.count <= 100 && $0.value.unicodeScalars.count <= 100 &&
                ($0.sourceID.map { !$0.isEmpty && $0.utf8.count <= 64 } ?? true) &&
                $0.quote.unicodeScalars.count <= AssistantDialogue.maximumTurnScalars &&
                ($0.sourceReport.map { $0.unicodeScalars.count <= AssistantDialogue.maximumTurnScalars } ?? true) } &&
            completedSteps.allSatisfy { $0.unicodeScalars.count <= 300 }
        }
    }
    private(set) var scopedTaskHistory: [ScopedTaskHistory] = []
    var goal = ""
    var goalSource: CompanionTaskSource?
    var goalRevision = UUID().uuidString
    var proposedStep = ""
    var reportedCompletedSteps: [String] = []
    var reports: [Report] = []
    var facts: [CompanionReportedFact] = []
    var actionProgress = CompanionActionProgressLedger()
    var reportedStepAssociations: [CompanionReportedStep] = []
    /// Location reports are parsed and rendered by code, never written by the model.
    var factBook = CompanionFactBook()
    var focusObject = ""
    /// A search receipt is historical; it never supplies a current object position.
    // Transient conversational ownership: never decoded as a location fact.
    var searchAreaClue = CompanionSearchClue()
    var searchAreaClarificationTarget: String? = nil
    var lastSearch: SearchRecord?
    /// Exact original reports make derived location memories removable with their source.
    private var locationReportSources: [String: String] = [:]
    /// One non-find destination retained while an explicit object find is active.
    /// This is user task context, never route/arrival authority or an executable step.
    struct ParentGoal: Codable, Sendable {
        var goal: String
        var reportedCompletedSteps: [String]
        var source: CompanionTaskSource? = nil
    }
    var parentGoal: ParentGoal?
    struct SuspendedGoal: Codable, Sendable {
        var goal: String
        var proposedStep: String
        var reportedCompletedSteps: [String]
        var focusObject: String? = nil
        var parentGoal: ParentGoal? = nil
        var source: CompanionTaskSource? = nil
    }
    var suspendedGoals: [SuspendedGoal] = []

    private enum CodingKeys: String, CodingKey { case memoryScope, scopedTaskHistory, goal, goalSource, goalRevision, proposedStep, reportedCompletedSteps, reports, facts, suspendedGoals, parentGoal, factBook, focusObject, lastSearch, locationReportSources, actionProgress, reportedStepAssociations }
    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        goal = try c.decodeIfPresent(String.self, forKey: .goal) ?? ""
        goalSource = try c.decodeIfPresent(CompanionTaskSource.self, forKey: .goalSource)
        if goalSource?.canonicalLabel != goal { goalSource = nil }
        goalRevision = try c.decodeIfPresent(String.self, forKey: .goalRevision) ?? UUID().uuidString
        if goalRevision.isEmpty || goalRevision.utf8.count > 64 { goalRevision = UUID().uuidString }
        proposedStep = try c.decodeIfPresent(String.self, forKey: .proposedStep) ?? ""
        reportedCompletedSteps = try c.decodeIfPresent([String].self, forKey: .reportedCompletedSteps) ?? []
        reports = try c.decodeIfPresent([Report].self, forKey: .reports) ?? []
        facts = try c.decodeIfPresent([CompanionReportedFact].self, forKey: .facts) ?? []
        actionProgress = try c.decodeIfPresent(CompanionActionProgressLedger.self, forKey: .actionProgress) ?? CompanionActionProgressLedger()
        reportedStepAssociations = Array((try c.decodeIfPresent([CompanionReportedStep].self, forKey: .reportedStepAssociations) ?? []).filter {
            CompanionReportedStep.proposed(step: $0.step, currentStep: $0.step, quote: $0.report, latest: $0.report, goalRevision: $0.goalRevision) != nil
        }.suffix(12))
        let savedBook = try c.decodeIfPresent(CompanionFactBook.self, forKey: .factBook) ?? CompanionFactBook()
        let savedSources = try c.decodeIfPresent([String: String].self, forKey: .locationReportSources) ?? [:]
        focusObject = try c.decodeIfPresent(String.self, forKey: .focusObject) ?? ""
        if focusObject.unicodeScalars.count > ItemMemory.nameLimit { focusObject = "" }
        lastSearch = try c.decodeIfPresent(SearchRecord.self, forKey: .lastSearch)
        if let search = lastSearch, search.target.unicodeScalars.count > ItemMemory.nameLimit || search.key != ItemMemory.key(for: search.target) {
            lastSearch = nil
        }
        // Reconstruct provenance for older code-owned records when the source is
        // still retained. Untraceable derived records are not trusted as memories.
        var recoveredSources: [String: String] = [:]
        var recoveredFocus = ""
        for report in reports.suffix(12) {
            switch CompanionUtterance.parse(report.text) {
            case .find(let object)?: recoveredFocus = object
            case .report(let named, _, _, _)?:
                if let named { recoveredFocus = named }
                if !recoveredFocus.isEmpty { recoveredSources[ItemMemory.key(for: recoveredFocus)] = report.text }
            case nil: break
            }
        }
        for fact in savedBook.facts.suffix(CompanionFactBook.limit) {
            guard let source = savedSources[fact.storageKey] ?? (fact.scope == nil ? savedSources[fact.key] ?? recoveredSources[fact.key] : nil),
                  !source.isEmpty, source.unicodeScalars.count <= AssistantDialogue.maximumTurnScalars,
                  case .report(let named, let place, let tense, let hedged)? = CompanionUtterance.parse(source),
                  named.map({ ItemMemory.key(for: $0) == fact.key }) ?? true,
                  place == fact.place, tense == fact.tense, hedged == fact.hedged,
                  fact.key == ItemMemory.key(for: fact.object),
                  factBook.record(object: fact.object, place: fact.place, tense: fact.tense,
                                  hedged: fact.hedged, at: fact.at, scope: fact.scope, sourceID: fact.sourceID) != nil else { continue }
            locationReportSources[fact.storageKey] = source
        }
        suspendedGoals = Array((try c.decodeIfPresent([SuspendedGoal].self, forKey: .suspendedGoals) ?? [])
            .filter { !$0.goal.isEmpty && $0.goal.unicodeScalars.count <= 300 && $0.proposedStep.unicodeScalars.count <= 300 }.suffix(3)).map { saved in
                var bounded = saved
                bounded.reportedCompletedSteps = Array(saved.reportedCompletedSteps.filter { $0.unicodeScalars.count <= 300 }.suffix(12))
                if let focus = bounded.focusObject, focus.unicodeScalars.count > ItemMemory.nameLimit { bounded.focusObject = nil }
                bounded.parentGoal = Self.boundedParent(saved.parentGoal, activeGoal: saved.goal)
                if bounded.source?.canonicalLabel != saved.goal { bounded.source = nil }
                return bounded
            }
        if goal.unicodeScalars.count > 300 { goal = ""; goalSource = nil }
        parentGoal = Self.boundedParent(try c.decodeIfPresent(ParentGoal.self, forKey: .parentGoal), activeGoal: goal)
        if proposedStep.unicodeScalars.count > 300 { proposedStep = "" }
        reportedCompletedSteps = Array(reportedCompletedSteps.filter { $0.unicodeScalars.count <= 300 }.suffix(12))
        reports = Array(reports.filter { ($0.correctionOrigin?.valid ?? true) && !$0.text.isEmpty && $0.text.unicodeScalars.count <= AssistantDialogue.maximumTurnScalars &&
            ($0.time.map { $0.timeIntervalSinceReferenceDate.isFinite && $0 >= .distantPast && $0 <= .distantFuture } ?? true) &&
            ($0.sourceID.map { !$0.isEmpty && $0.utf8.count <= 64 } ?? true) }.suffix(12))
        facts = Array(facts.filter { $0.subject.unicodeScalars.count <= 100 && $0.value.unicodeScalars.count <= 100 && $0.quote.unicodeScalars.count <= AssistantDialogue.maximumTurnScalars &&
            ($0.sourceID.map { !$0.isEmpty && $0.utf8.count <= 64 } ?? true) &&
            ($0.sourceReport.map { $0.unicodeScalars.count <= AssistantDialogue.maximumTurnScalars } ?? true) }.suffix(12))
        scopedTaskHistory = Array((try c.decodeIfPresent([ScopedTaskHistory].self, forKey: .scopedTaskHistory) ?? []).filter(\.valid).suffix(12))
        memoryScope = try c.decodeIfPresent(CompanionMemoryScope.self, forKey: .memoryScope)
        if hasScopedMemoryHistory { retireScopedContext(to: nil) }
    }

    /// Same established identity preserves progress. Any different place, floor,
    /// map revision, room, target instance or identity loss retires the generation
    /// but not the user's goal. History is retained separately, never auto-resumed.
    mutating func transitionMemoryScope(_ proposed: CompanionMemoryScope?) {
        let next = proposed?.valid == true ? proposed : nil
        guard next != memoryScope else { return }
        retireScopedContext(to: next)
    }
    private mutating func retireScopedContext(to next: CompanionMemoryScope?) {
        scopedTaskHistory.append(ScopedTaskHistory(scope: memoryScope, goal: goal,
            goalRevision: goalRevision, reports: reports, facts: facts, completedSteps: reportedCompletedSteps, goalSource: goalSource))
        scopedTaskHistory = Array(scopedTaskHistory.suffix(12))
        memoryScope = next
        actionProgress = CompanionActionProgressLedger()
        goalRevision = UUID().uuidString
        proposedStep = ""; reportedCompletedSteps = []; reportedStepAssociations = []
        searchAreaClue.clear()
        facts = []; reports = []; lastSearch = nil; focusObject = ""
        // Parent/suspended goals retain intent only, not another target's progress.
        parentGoal?.reportedCompletedSteps = []
        for index in suspendedGoals.indices {
            suspendedGoals[index].proposedStep = ""
            suspendedGoals[index].reportedCompletedSteps = []
            suspendedGoals[index].focusObject = nil
            suspendedGoals[index].parentGoal?.reportedCompletedSteps = []
        }
    }

    /// Scoped task prompts cannot backfill from the unscoped dialogue archive.
    /// Old words remain reviewable history, not evidence for the current fridge.
    var hasScopedMemoryHistory: Bool { memoryScope != nil || !scopedTaskHistory.isEmpty || factBook.facts.contains { $0.scope != nil } }
    func currentContextFact(for object: String) -> CompanionFact? {
        guard !hasScopedMemoryHistory || memoryScope != nil else { return nil }
        if let memoryScope { return factBook.latest(for: object, in: memoryScope) }
        // Only a never-scoped legacy state retains its original lookup behavior.
        return factBook.latest(for: object).flatMap { $0.scope == nil ? $0 : nil }
    }
    /// Explicit historical questions are cross-place recall, never a live search
    /// or a task/scope transition. Labels below are stored IDs, not guessed names.
    func historicalLocationReply(to question: String, now: Date = Date(), arabic: Bool, concise: Bool = false) -> String? {
        guard question.unicodeScalars.count <= 300 else { return nil }
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        let pattern = #"^(?:where did i (?:last )?(?:leave|put|have) (?:my|our) |where was my |أين تركت |وين تركت )(.+)$"#
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = expression.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        let object = String(text[range])
        guard !ItemMemory.key(for: object).isEmpty, object.unicodeScalars.count <= ItemMemory.nameLimit else { return nil }
        guard let fact = factBook.latest(for: object) else { return CompanionFact.unknown(object: object, arabic: arabic) }
        return renderHistoricalFact(fact, now: now, arabic: arabic, concise: concise)
    }
    /// An ordinary find has no permission to substitute old context for current
    /// perception. This produces labelled history or a scope clarification only.
    func ordinaryHistoricalLocationReply(object: String, now: Date = Date(), arabic: Bool, concise: Bool = false) -> String? {
        switch factBook.historicalLookup(object: object, currentScope: memoryScope) {
        case .none: return nil
        case .report(let fact):
            // Scope IDs are helper metadata, not human place names. Do not read
            // opaque IDs aloud or infer labels that were never source-bound.
            return renderHistoricalFact(fact, now: now, arabic: arabic, concise: concise)
        case .ambiguous(let facts):
            let question = arabic ? "لدي تقارير من أماكن محفوظة أو سياقات أغراض مختلفة. أي سياق تقصد؟ لا يؤكد أي منها الموقع الحالي." : "I have reports from different saved places or item contexts. Which context do you mean? None confirms where it is now."
            if concise { return question }
            return question + "\n" + facts.map { renderHistoricalFact($0, now: now, arabic: arabic, concise: false) }.joined(separator: "\n")
        }
    }
    private func renderHistoricalFact(_ fact: CompanionFact, now: Date, arabic: Bool, concise: Bool) -> String {
        let scope: String
        if let saved = fact.scope {
            scope = "place ID: \(saved.placeID); floor ID: \(saved.floorID); room ID: \(saved.roomID); object instance ID: \(saved.objectInstanceID ?? "unknown"); map ID: \(saved.map.mapID); frame ID: \(saved.map.frameID); revision: \(saved.map.revision)"
        } else { scope = arabic ? "هوية المكان غير معروفة" : "place identity unknown" }
        if concise {
            let calendar = Calendar.current
            let when: String
            if calendar.isDate(fact.at, inSameDayAs: now) { when = arabic ? "اليوم" : "today" }
            else if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
                    calendar.isDate(fact.at, inSameDayAs: yesterday) { when = arabic ? "أمس" : "yesterday" }
            else {
                let formatter = DateFormatter(); formatter.locale = Locale(identifier: arabic ? "ar" : "en")
                formatter.dateStyle = .medium; formatter.timeStyle = .none
                when = (arabic ? "في " : "on ") + formatter.string(from: fact.at)
            }
            if arabic {
                let hedge = fact.hedged ? "أنك تظن أن" : "إن"
                return "قلت لي \(when) \(hedge) \(fact.object) كان \(fact.place). لا أعرف أين هو الآن."
            }
            let hedge = fact.hedged ? "you thought " : ""
            return "You told me \(when) \(hedge)your \(fact.object) was \(fact.place). I don't know where it is now."
        }
        let date = ISO8601DateFormatter().string(from: fact.at)
        let prefix = arabic ? "تقرير سابق، \(date). السياق الأصلي المحفوظ: \(scope). " : "Historical report, \(date). Original stored context: \(scope). "
        return prefix + fact.recall(now: now, arabic: arabic)
    }
    func currentContextItem(_ name: String, in items: ItemMemory) -> RememberedItem? {
        hasScopedMemoryHistory ? items.find(name, in: memoryScope) : items.find(name)
    }
    func taskContextReports(_ candidates: [String]) -> [String] {
        guard hasScopedMemoryHistory else { return candidates }
        let retained = Set(reports.map(\.text))
        return candidates.filter { retained.contains($0) }
    }

    /// Retrieve source-owned current-context reports directly. Never join an old
    /// dialogue ID to a newer same-text report or assign it the newer date.
    func memoryToolReports(from dialogue: AssistantDialogue, query: String) -> [CompanionEvidence] {
        if hasScopedMemoryHistory {
            return reports.compactMap { report in
                guard let id = report.sourceID, !id.isEmpty, id.utf8.count <= 64 else { return nil }
                return CompanionEvidence(id: "report:" + id, kind: .userReport, text: report.text,
                    source: "original scoped user report; not an observation", observedAt: report.time)
            }
        }
        return dialogue.relevantUserReports(for: query, maxScalars: 1200).map {
            CompanionEvidence(id: $0.id, kind: .userReport, text: $0.text, source: "original user conversation record")
        }
    }

    func taskContextItems(_ candidates: [RememberedItem]) -> [RememberedItem] {
        guard hasScopedMemoryHistory else { return candidates.filter { $0.scope == nil } }
        guard let memoryScope else { return [] }
        return candidates.filter { $0.scope == memoryScope }
    }
    /// The legacy category archive has no exact map revision/target-container
    /// binding. Do not infer one from room labels or category names.
    func taskContextObservations(_ history: ObservedObjectMemory) -> ObservedObjectMemory {
        hasScopedMemoryHistory ? ObservedObjectMemory() : history
    }

    mutating func record(_ text: String, at: Date? = Date()) {
        guard !text.isEmpty, text.unicodeScalars.count <= AssistantDialogue.maximumTurnScalars,
              at.map({ $0.timeIntervalSinceReferenceDate.isFinite && $0 >= .distantPast && $0 <= .distantFuture }) ?? true else { return }
        if at == nil, reports.contains(where: { $0.text == text }) { return }
        reviewEpoch = UUID().uuidString
        reports.append(Report(text: text, time: at, sourceID: UUID().uuidString))
        reports = Array(reports.suffix(12))
    }
    mutating func ingestDirectActionReport(_ text: String) {
        let source = reports.last(where: { $0.text == text })
        let reduction = actionProgress.ingestUserReport(text, sourceID: source?.sourceID ?? UUID().uuidString,
            goalRevision: goalRevision, at: source?.time ?? Date())
        if reduction.acceptedReport != nil, !actionProgress.allowsProposal(proposedStep, goalRevision: goalRevision) {
            proposedStep = ""
        }
    }
    /// Forget only this named target in the explicitly selected memory scope.
    /// A provisional clue is not a saved item/location, but must not survive
    /// an explicit forget of its corresponding object just because no item exists.
    @discardableResult
    mutating func retireSearchClue(object: String, scope: CompanionMemoryScope?) -> Bool {
        let key = ItemMemory.key(for: object)
        guard !key.isEmpty else { return false }
        let clearedClue = searchAreaClue.clue.map { $0.binding.key == key && $0.binding.scope == scope } ?? false
        let bindings = [searchAreaClue.question?.binding, searchAreaClue.clue?.binding].compactMap { $0 }
        if bindings.contains(where: { $0.key == key && $0.scope == scope }) { searchAreaClue.clear() }
        return clearedClue
    }

    /// Deleting an explicitly scoped saved place retires only its derived clue context.
    mutating func retireSearchClue(placeID: String) {
        let bindings = [searchAreaClue.question?.binding, searchAreaClue.clue?.binding].compactMap { $0 }
        if bindings.contains(where: { $0.scope?.placeID == placeID }) { searchAreaClue.clear() }
    }

    /// Explicit review/correction/deletion only. Remove exact source records,
    /// not similarly worded unrelated memories. Invalidate pending generation.
    /// Legacy dialogue IDs are not bound to scoped source IDs. Fail closed
    /// before any mutation rather than deleting same-text reports in two homes.
    var allowsLegacyReportMutation: Bool { !hasScopedMemoryHistory }
    @discardableResult mutating func removeReport(_ exactText: String) -> Bool {
        guard allowsLegacyReportMutation else { return false }
        // Legacy text deletion may outlive the bounded report list. Retire the
        // exact accepted clue too, not an unrelated goal's similarly named place.
        if searchAreaClue.clue?.originalInput == exactText { searchAreaClue.clear() }
        for index in scopedTaskHistory.indices {
            let affected = scopedTaskHistory[index].reports.contains { $0.text == exactText }
            scopedTaskHistory[index].reports.removeAll { $0.text == exactText }
            scopedTaskHistory[index].facts.removeAll { $0.sourceReport == exactText || $0.quote == exactText }
            // Archived completions have no executable authority; retire them
            // conservatively when correcting one of that archive's sources.
            if affected { scopedTaskHistory[index].completedSteps = [] }
        }
        actionProgress.removeReport(exactText: exactText)
        let removedSteps = reportedStepAssociations.filter { $0.report == exactText }.map(\.step)
        reportedStepAssociations.removeAll { $0.report == exactText }
        reportedCompletedSteps.removeAll { removedSteps.contains($0) }
        parentGoal?.reportedCompletedSteps.removeAll { removedSteps.contains($0) }
        for index in suspendedGoals.indices {
            let previous = suspendedGoals[index].reportedCompletedSteps
            let previousParent = suspendedGoals[index].parentGoal?.reportedCompletedSteps
            suspendedGoals[index].reportedCompletedSteps.removeAll { removedSteps.contains($0) }
            suspendedGoals[index].parentGoal?.reportedCompletedSteps.removeAll { removedSteps.contains($0) }
            if previous != suspendedGoals[index].reportedCompletedSteps || previousParent != suspendedGoals[index].parentGoal?.reportedCompletedSteps { suspendedGoals[index].proposedStep = "" }
        }
        reports.removeAll { $0.text == exactText }
        let removedLocationKeys = locationReportSources.filter { $0.value == exactText }.map(\.key)
        for key in removedLocationKeys {
            factBook.forget(storageKey: key)
            locationReportSources.removeValue(forKey: key)
        }
        facts.removeAll { $0.sourceReport == exactText || $0.quote == exactText ||
            ($0.sourceReport == nil && !$0.quote.isEmpty && exactText.contains($0.quote)) }
        let matchingGoal = exactText.trimmingCharacters(in: .whitespacesAndNewlines)
        suspendedGoals.removeAll { $0.goal == matchingGoal || $0.source?.originalRequest == exactText }
        for index in suspendedGoals.indices where suspendedGoals[index].parentGoal?.goal == matchingGoal || suspendedGoals[index].parentGoal?.source?.originalRequest == exactText {
            suspendedGoals[index].parentGoal = nil
        }
        if parentGoal?.goal == matchingGoal || parentGoal?.source?.originalRequest == exactText { parentGoal = nil }
        actionProgress.retireSuggestions(forGoalRevision: goalRevision)
        if goal == matchingGoal || goalSource?.originalRequest == exactText {
            goalSource = nil
            goal = ""; reportedCompletedSteps = []; focusObject = ""; parentGoal = nil
            goalRevision = UUID().uuidString
        }
        // The controller cancels pending generation. Unrelated source deletion
        // must not erase still-valid user reports by silently replacing the goal.
        proposedStep = ""
        return true
    }
    /// Exact location-memory source deletion, usable by a future source-bound
    /// review UI. Does not erase another scope's same-word report or task.
    @discardableResult mutating func removeLocationReport(sourceID: String) -> Bool {
        guard let fact = factBook.facts.first(where: { $0.sourceID == sourceID }) else { return false }
        guard factBook.forgetSource(sourceID) else { return false }
        retireSearchClue(object: fact.object, scope: fact.scope)
        let original = locationReportSources.removeValue(forKey: fact.storageKey)
        func dependsOnSource(_ derived: CompanionReportedFact) -> Bool {
            derived.sourceID == sourceID || (derived.sourceID == nil && original.map {
                derived.sourceReport == $0 || derived.quote == $0
            } == true)
        }
        if memoryScope == fact.scope {
            facts.removeAll(where: dependsOnSource)
            actionProgress.removeSource(sourceID)
            // Older associations lack source IDs. Invalidate dependent evidence
            // only inside this exact scope, never another home's same words.
            if let original {
                actionProgress.removeReport(exactText: original)
                reportedStepAssociations.removeAll { $0.report == original }
            }
            reportedCompletedSteps = []
            parentGoal?.reportedCompletedSteps = []
        }
        reports.removeAll { $0.sourceID == sourceID }
        for index in scopedTaskHistory.indices where scopedTaskHistory[index].scope == fact.scope {
            scopedTaskHistory[index].reports.removeAll { $0.sourceID == sourceID }
            scopedTaskHistory[index].facts.removeAll(where: dependsOnSource)
            scopedTaskHistory[index].completedSteps = []
        }
        actionProgress.retireSuggestions(forGoalRevision: goalRevision)
        goalRevision = UUID().uuidString
        proposedStep = ""
        return true
    }
    mutating func changeGoal(_ value: String, originalRequest: String? = nil, sourceID: String? = nil, at: Date? = Date()) {
        let source = originalRequest.flatMap {
            CompanionTaskSource(originalRequest: $0, canonicalLabel: value, sourceID: sourceID ?? UUID().uuidString, recordedAt: at)
        }
        guard goal != value else {
            if goalSource == nil { goalSource = source }
            return
        }
        searchAreaClue.clear()
        actionProgress.retireSuggestions(forGoalRevision: goalRevision)
        goal = value; goalSource = source; goalRevision = UUID().uuidString
        proposedStep = ""; reportedCompletedSteps = []
        focusObject = ""; parentGoal = nil
    }
    private static func isFindGoal(_ goal: String) -> Bool {
        if case .find? = CompanionUtterance.parse(goal) { return true }
        return ConversationIntent.explicitTaskGoal(goal) != nil
    }
    private static func boundedParent(_ saved: ParentGoal?, activeGoal: String) -> ParentGoal? {
        guard let saved, isFindGoal(activeGoal), !saved.goal.isEmpty,
              saved.goal.unicodeScalars.count <= 300, !isFindGoal(saved.goal) else { return nil }
        return ParentGoal(goal: saved.goal,
            reportedCompletedSteps: Array(saved.reportedCompletedSteps.filter { $0.unicodeScalars.count <= 300 }.suffix(12)),
            source: saved.source?.canonicalLabel == saved.goal ? saved.source : nil)
    }
    /// Find is a bounded subtask of a non-find goal. Switching objects replaces
    /// that subtask, never stacks another destination or silently resumes one.
    private mutating func beginFindGoal(_ request: String, object: String, sourceID: String? = nil, at: Date? = Date()) {
        // A paraphrase of the same current object search is not a new goal.
        // Keep its original source, parent and already-reported progress.
        if Self.isFindGoal(goal), !focusObject.isEmpty,
           ItemMemory.key(for: focusObject) == ItemMemory.key(for: object) { return }
        let retained = parentGoal ?? (!goal.isEmpty && goal.unicodeScalars.count <= 300 && !Self.isFindGoal(goal)
            ? ParentGoal(goal: goal, reportedCompletedSteps: reportedCompletedSteps, source: goalSource) : nil)
        changeGoal(request, originalRequest: request, sourceID: sourceID, at: at)
        parentGoal = Self.boundedParent(retained, activeGoal: request)
        focusObject = object
    }
    /// Applies only an explicit parsed request/report; the controller owns live
    /// sensor search and completion-accounted speech. No model action is involved.
    mutating func respond(to utterance: CompanionUtterance, message: String, now: Date = Date(), arabic: Bool, sourceID: String? = nil) -> String {
        searchAreaClarificationTarget = nil
        guard CompanionUtterance.parse(message) == utterance else {
            return arabic ? "لم أستطع تأكيد هذا الطلب." : "I couldn't verify that request."
        }
        if let history = historicalLocationReply(to: message, now: now, arabic: arabic, concise: true) { return history }
        switch utterance {
        case .find(let object):
            let request = message.trimmingCharacters(in: .whitespacesAndNewlines)
            guard request.unicodeScalars.count <= 300 else {
                return arabic ? "اختصر طلب البحث من فضلك." : "Please shorten that search request."
            }
            beginFindGoal(request, object: object, sourceID: sourceID, at: sourceID.flatMap { id in reports.last { $0.sourceID == id }?.time } ?? now)
            if let fact = currentContextFact(for: object) { return fact.recall(now: now, arabic: arabic) }
            if let search = lastSearch, search.matches(object) {
                if !search.located { searchAreaClarificationTarget = object }
                let ask = " " + CompanionFact.searchAreaQuestion(arabic: arabic)
                return search.sentence(now: now, arabic: arabic) + (search.located ? "" : ask)
            }
            if let history = ordinaryHistoricalLocationReply(object: object, now: now, arabic: arabic, concise: true) { return history }
            searchAreaClarificationTarget = object
            return CompanionFact.unknown(object: object, arabic: arabic)
        case .report(let named, let place, let tense, let hedged):
            guard let object = named ?? (focusObject.isEmpty ? nil : focusObject) else {
                return arabic ? "أي غرض تقصد؟ قل اسمه." : "Which thing do you mean? Tell me its name."
            }
            let boundSource = sourceID.flatMap { id in reports.last(where: { $0.sourceID == id && $0.text == message }) }
            guard sourceID == nil || (boundSource != nil && boundSource?.time != nil),
                  !message.isEmpty, message.unicodeScalars.count <= AssistantDialogue.maximumTurnScalars,
                  let fact = factBook.record(object: object, place: place, tense: tense, hedged: hedged,
                    at: boundSource?.time ?? now, scope: memoryScope, sourceID: sourceID ?? UUID().uuidString) else {
                return arabic ? "لم أستطع حفظ ذلك." : "I couldn't save that."
            }
            focusObject = object
            locationReportSources[fact.storageKey] = message
            let retainedKeys = Set(factBook.facts.map(\.storageKey))
            locationReportSources = locationReportSources.filter { retainedKeys.contains($0.key) }
            return fact.acknowledgement(arabic: arabic)
        }
    }

    /// The original pronoun report is bound while the full conversation state is
    /// available, never guessed later from a ranked/truncated retrieval subset.
    var locationReports: [CompanionLocationReport] {
        guard !hasScopedMemoryHistory || memoryScope != nil else { return [] }
        return factBook.facts.filter { $0.scope == memoryScope }.compactMap { fact in
            guard let source = locationReportSources[fact.storageKey] else { return nil }
            return CompanionLocationReport(id: "location:" + (fact.sourceID ?? fact.key), object: fact.object,
                originalReport: source, recordedAt: fact.at, scope: fact.scope)
        }
    }

    mutating func cancelTask(arabic: Bool) -> String {
        changeGoal(""); focusObject = ""
        return arabic ? "حسناً، أوقفت هذه المهمة." : "Okay, I've stopped that task."
    }

    /// An explicit report completes conversational bookkeeping only. It does
    /// not assert possession, arrival, identity, or start a parent action.
    @discardableResult mutating func recordCompletedSubtask(_ task: String, report: String) -> Bool {
        guard !task.isEmpty, task.unicodeScalars.count <= 300,
              let request = EverydayTaskRequest.route(task),
              CompanionTaskCompletion.matches(report, request: request) else { return false }
        let receipt = "User reported completing \(task): \(report)"
        let endsFind = Self.isFindGoal(goal) &&
            (goal == task || ItemMemory.key(for: request.query) == ItemMemory.key(for: focusObject))
        guard endsFind else { return false }
        if endsFind {
            let parent = parentGoal
            changeGoal(parent?.goal ?? "")
            goalSource = parent?.source
            reportedCompletedSteps = parent?.reportedCompletedSteps ?? []
        }
        if !reportedCompletedSteps.contains(receipt) {
            reportedCompletedSteps.append(receipt)
            reportedCompletedSteps = Array(reportedCompletedSteps.suffix(12))
        }
        proposedStep = ""
        return true
    }

    /// Explicit controller commands only. Neither a model proposal nor a new
    /// topic silently resumes an old task.
    @discardableResult mutating func suspendGoal() -> Bool {
        guard !goal.isEmpty else { return false }
        suspendedGoals.append(SuspendedGoal(goal: goal, proposedStep: proposedStep,
                                           reportedCompletedSteps: reportedCompletedSteps, focusObject: focusObject,
                                           parentGoal: parentGoal, source: goalSource))
        suspendedGoals = Array(suspendedGoals.suffix(3))
        changeGoal("")
        return true
    }
    @discardableResult mutating func resumeGoal() -> Bool {
        // An explicit resume during a find returns to its parent destination.
        // A detector match, room entry or reported completion never calls this.
        if !goal.isEmpty, let parent = parentGoal {
            changeGoal(parent.goal)
            goalSource = parent.source
            reportedCompletedSteps = parent.reportedCompletedSteps
            return true
        }
        guard goal.isEmpty, let previous = suspendedGoals.popLast() else { return false }
        changeGoal(previous.goal)
        goalSource = previous.source
        parentGoal = Self.boundedParent(previous.parentGoal, activeGoal: previous.goal)
        // A remembered suggestion is not a currently valid action. Preserve the
        // reports, but require a new grounded next step after resuming.
        reportedCompletedSteps = previous.reportedCompletedSteps
        if let previousFocus = previous.focusObject, previousFocus.unicodeScalars.count <= ItemMemory.nameLimit {
            focusObject = previousFocus
        } else if case .find(let object)? = CompanionUtterance.parse(previous.goal) {
            focusObject = object
        }
        return true
    }
    mutating func apply(_ update: CompanionTaskUpdate, latest: String) {
        // Native model proposals carry the exact generation they read. Legacy
        // unscoped fixtures remain readable, but never enter a scoped task.
        if update.contextRevision != nil || memoryScope != nil || !scopedTaskHistory.isEmpty {
            guard update.contextRevision == goalRevision else { return }
        }
        if var fact = update.fact,
           CompanionTaskMutationPolicy.currentReport(quote: fact.quote, latest: latest),
           !fact.subject.isEmpty, fact.subject.unicodeScalars.count <= 100,
           fact.quote.localizedCaseInsensitiveContains(fact.subject) {
            // Retain the whole assertion, not a model-extracted value that could
            // omit "not". It still remains a user report, never an observation.
            fact.value = fact.quote; fact.sourceReport = latest
            fact.sourceID = reports.last(where: { $0.text == latest })?.sourceID
            facts.removeAll { $0.subject.caseInsensitiveCompare(fact.subject) == .orderedSame }
            facts.append(fact); facts = Array(facts.suffix(12))
        }
        // Cancellation and replacement retire the old proposed step together.
        if CompanionTaskMutationPolicy.cancellation(quote: update.cancellationReport, latest: latest) {
            changeGoal("")
            proposedStep = ""
            return
        } else if CompanionTaskMutationPolicy.newGoal(proposal: update.goal, latest: latest) { changeGoal(update.goal, originalRequest: latest, sourceID: reports.last?.sourceID, at: reports.last?.time) }
        // A user report is not sensor confirmation or proof of physical arrival.
        if let progress = CompanionReportedStep.proposed(step: update.completionStep,
            currentStep: proposedStep, quote: update.completionReport, latest: latest, goalRevision: goalRevision) {
            reportedStepAssociations.append(progress)
            reportedStepAssociations = Array(reportedStepAssociations.suffix(12))
            reportedCompletedSteps.append(progress.step)
            reportedCompletedSteps = Array(reportedCompletedSteps.suffix(12))
            proposedStep = ""
        }
        if !goal.isEmpty, !update.nextStep.isEmpty, update.nextStep.unicodeScalars.count <= 300,
           actionProgress.allowsProposal(update.nextStep, goalRevision: goalRevision),
           !SpatialClaimGuard.containsSpatialClaim(update.nextStep),
           CompanionEvidenceGuard.allows(update.nextStep, reports: [latest]) {
            proposedStep = update.nextStep
        }
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
private struct CompanionDecision {
    @Guide(description: "Exact standalone declarative sentence in the latest user message reporting an object's current state. Empty if there is no assertion. Never extract a question as a fact.")
    var factQuote: String
    @Guide(description: "Exact object phrase from that sentence, e.g. cupboard door. Empty if no factQuote.")
    var factSubject: String
    @Guide(description: "Exact complete current state words, preserving negation and uncertainty. Empty if no factQuote.")
    var factValue: String
    @Guide(description: "If the user requests help doing something or replaces the task, copy their entire latest request exactly as the new goal. Empty for observations, questions about facts, or cancellation.")
    var newGoal: String
    @Guide(description: "An exact quote from the latest message explicitly cancelling the current goal without replacing it. Otherwise empty.")
    var cancellationReport: String
    @Guide(description: "Copy the entire latest user message exactly only when it directly reports achieving the exact current proposed step. Empty for questions, plans, unrelated actions, roleplay, quoted speech, bare done, or no proposed step.")
    var completionReport: String
    @Guide(description: "Copy the exact current proposedStepNotExecuted only if the entire latest direct first-person user report states that specific step was achieved. Never match an unrelated action, quote, roleplay, negation or bare done. Empty otherwise. This association is unverified conversational progress, not sensor confirmation.")
    var completionStep: String
    @Guide(description: "One proposed next step only when asked for help with a task; empty for factual questions and scene updates. A proposal is not an executed action.")
    var nextStep: String
}
#endif

#if BLIND_APPLE_MULTIMODAL && canImport(FoundationModels)
/// Model output remains an uncertain image hint, not a measured search success.
@available(iOS 26.0, *)
@Generable
enum SpotAnswer { case yes, no, unsure }

@available(iOS 26.0, *)
@Generable
enum SpotSide { case left, centre, right, unknown }

@available(iOS 26.0, *)
@Generable
struct SpotResult {
    @Guide(description: "yes only when the named thing is clearly visible in the photo")
    var visible: SpotAnswer
    @Guide(description: "Which part of the photo it is in")
    var side: SpotSide
}
#endif

// Swift adaptation of BehaviorTree.CPP ReactiveSequence::tick (MIT).
// Copyright 2020-2025 Davide Faconti, Eurecat. See ThirdParty/BehaviorTreeCPP.
// Conditions are evaluated afresh; failure halts later work instead of continuing
// with a plan whose prerequisites have changed. No sensor algorithm is implemented here.
enum CompanionReactiveSequence {
    enum Status { case success, failure, running, skipped }
    struct Node {
        var tick: () -> Status
        var halt: () -> Void = {}
    }
    static func tick(_ nodes: [Node]) -> Status {
        var allSkipped = true
        for (index, node) in nodes.enumerated() {
            let status = node.tick()
            allSkipped = allSkipped && status == .skipped
            switch status {
            case .running:
                for (other, child) in nodes.enumerated() where other != index { child.halt() }
                return .running
            case .failure:
                nodes.forEach { $0.halt() }
                return .failure
            case .success: break
            case .skipped: node.halt()
            }
        }
        nodes.forEach { $0.halt() }
        return allSkipped ? .skipped : .success
    }
}

// Adapted from ROSA RobotSystemPrompts.__str__, Apache-2.0.
// Copyright (c) 2024 Jet Propulsion Laboratory. See ThirdParty/ROSA/LICENSE and NOTICE.
// Swift port: typed sections replace Python reflection; empty sections remain omitted.
private struct CompanionSystemPrompts {
    var embodiment: String
    var operators: String
    var capabilities: String
    var mission: String
    var constraints: String
    var responseStyle: String

    var rendered: String {
        let sections = [("Embodiment", embodiment), ("About Your Operators", operators),
                        ("About Your Capabilities", capabilities), ("Mission And Objectives", mission),
                        ("Constraints And Guardrails", constraints), ("Response Style", responseStyle)]
        return sections.filter { !$0.1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { "\($0.0): \($0.1)" }.joined(separator: "\n---\n")
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
private struct ReadLocalEvidence: Tool {
    let name = "readLocalEvidence"
    let description: String
    let runtime: CompanionToolRuntime
    #if DEBUG
    var debugTrace: DebugNativeSessionTrace? = nil
    #endif

    @Generable struct Arguments {
        @Guide(description: "One advertised read-only capability: currentObservation, savedMemory, navigationState, deviceClock, saudiBanknote, isolatedColor, familiarPeople, or readText.")
        var capability: String
        @Guide(description: "A short search subject, at most 300 characters; not an instruction to perform an action.")
        var query: String
    }
    enum Failure: Error { case unsupportedCapability, callLimitReached }
    func call(arguments: Arguments) async throws -> String {
        try Task.checkCancellation()
        #if DEBUG
        debugTrace?.event(.toolCall, source: .toolRuntime) {
            .init(text: arguments.query, label: "readLocalEvidence." + arguments.capability + "; SDKCallID=unbound")
        }
        #endif
        guard let kind = CompanionToolKind(rawValue: arguments.capability) else {
            #if DEBUG
            debugTrace?.event(.toolResult, source: .toolRuntime) { .init(label: "unsupportedCapability") }
            #endif
            throw Failure.unsupportedCapability
        }
        let result = await runtime.run(CompanionToolRequest(kind: kind, query: arguments.query))
        try Task.checkCancellation()
        // Throwing stops Foundation Models' loop instead of feeding an unlimited
        // stream of "limit reached" messages back to the model.
        guard result.status != .callLimit else {
            #if DEBUG
            debugTrace?.event(.toolResult, source: .toolRuntime) { .init(label: "callLimitReached") }
            #endif
            throw Failure.callLimitReached
        }
        let payload = String(decoding: try JSONEncoder().encode(result), as: UTF8.self)
        #if DEBUG
        // Log the exact already-created return string, not a second tool execution.
        debugTrace?.event(.toolResult, source: .toolRuntime) {
            .init(text: payload, label: "readLocalEvidence.returnedJSON; SDKCallID=unbound")
        }
        #endif
        return payload
    }
}
#endif

/// Thin adapter for Apple's documented Attachment / LanguageModelSession API.
/// Compile the image path with an iOS 27 SDK; no remote model is selected here.
enum LocalImageAssistant {
    /// Conversation remains available without a tracked camera. No visual or
    /// positional evidence is inferred from the conversation history.
    /// Ground reported-state changes in explicit source text. These remain user
    /// reports, never sensor measurements. Compare stored values in code.
    private static func reportedFact(quote: String, subject: String, value: String, latest: String) -> CompanionReportedFact? {
        guard !quote.isEmpty, !subject.isEmpty, !value.isEmpty, subject.count <= 100, value.count <= 100,
              latest.contains(quote), quote.localizedCaseInsensitiveContains(subject), quote.localizedCaseInsensitiveContains(value),
              !quote.contains("?"), !quote.contains("؟"),
              CompanionTaskMutationPolicy.currentReport(quote: quote, latest: latest) else { return nil }
        let tokenizer = NLTokenizer(unit: .sentence); tokenizer.string = latest
        let hasStatement = tokenizer.tokens(for: latest.startIndex..<latest.endIndex).contains { range in
            let sentence = String(latest[range])
            return sentence.contains(quote) && !sentence.contains("?") && !sentence.contains("؟")
        }
        guard hasStatement else { return nil }
        return CompanionReportedFact(subject: subject, value: quote, quote: quote, sourceReport: latest)
    }
    private static func usableChatReply(_ text: String) -> Bool {
        let lower = text.lowercased()
        return !text.isEmpty && text.split(whereSeparator: { $0.isWhitespace }).count <= 35 &&
            !lower.contains("earlier conversation:") && !lower.contains("child:") &&
            !lower.contains("assistant:")
    }

    // Apple recommends a concise role, task-specific context and clear conditional
    // behavior. User-controlled profile/context belongs in the prompt, not Instructions.
    private static func conversationInstructions(arabic: Bool, audience: AssistantAudience) -> String {
        CompanionSystemPrompts(
            embodiment: CompanionModelContext.sharedInstructions,
            operators: "The person chooses what to do, can change topics, pause tasks, or change their mind. " + audience.modelInstructions,
            capabilities: "Read-only local tools provide evidence. For current time, call deviceClock; repeat its fresh evidence, never guess. Tool failures and empty results mean unknown, never absent. No external actions or internet access. Saved maps and user reports are not current observations.",
            mission: "Answer the latest request naturally; keep relevant continuity, not replaced topics. Do not repeat acknowledged announcements unless asked again. Ask one useful question if needed. For a lost item, first query savedMemory for observed-object history, explicit item records and user reports. Treat old sightings as last-seen clues, never current presence. Ask where they last had it only if these records cannot help. If a search remains unresolved, offer one useful evidence-grounded next check, not an invented route or a demand to aim blindly. Goals and lists do not prove completion or possession. When blocked, offer one useful next check supported by available capabilities; never invent a tool or a physical action.",
            constraints: "Never invent a perception, location, identity, action result, or safe route. Never produce physical movement, approach, reach, pickup, object-distance or direction instructions, even hedged or requested; only a separately validated code-owned controller can authorize those. For a present local fact, use a fresh tool and repeat its complete evidence text without adding claims. For a user report, attribute an exact short quote: You said: “original words”. Last left means historical, not still there. New reports may correct old reports, not prove current reality. Prior delivered assistant words only resolve conversation references, never verify facts; quote them as I said: “original words”. Suggestions are not completed actions. A newer user action report retires a repeated suggestion, but is not sensor confirmation; check a fresh view for the next factual answer. A familiar-person hint stays tentative, never proof of identity or permission to follow. Captured-view evidence is a past snapshot: repeat its complete attribution, never convert it to current presence.",
            responseStyle: "Use \(arabic ? "Arabic" : "English"), one or two short sentences, at most 35 words. Use plain words and one useful next step, without technical camera jargon. Respond to ordinary conversation too. Do not ask permission to help with what was already requested."
        ).rendered
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private static func isContextOverflow(_ error: Error) -> Bool {
        // Apple TN3193 documents this iOS26 typed case. SDK27 exposes the
        // replacement LanguageModelError. SDK27+ text-only builds must explicitly
        // set BLIND_FOUNDATION_MODELS_V2; the image flag retains compatibility.
        // Never infer overflow from a localized error string or retry refusals.
        #if BLIND_FOUNDATION_MODELS_V2 || BLIND_APPLE_MULTIMODAL
        if #available(iOS 27.0, *), let failure = error as? LanguageModelError,
           case .contextSizeExceeded = failure { return true }
        #endif
        if let failure = error as? LanguageModelSession.GenerationError,
           case .exceededContextWindowSize = failure { return true }
        return false
    }
    #endif

    /// Provenance reaches onSpeechCandidate before onPartial so display can use
    /// the same admitted evidence, without changing the display callback API.
    /// onPartial receives each new validated sentence exactly once (not a
    /// cumulative snapshot) for display. onSpeechCandidate carries provenance
    /// for a second freshness/safety check at actual queued speech dispatch.
    /// onReplyComplete fires before task bookkeeping.
    /// Both callbacks are revision/cancellation-gated again by the controller.
    static func converse(dialogue: AssistantDialogue, arabic: Bool, preferredName: String = "", audience: AssistantAudience = .general,
                         situation: [String: Any] = [:], workingState: CompanionWorkingState = CompanionWorkingState(), modelContext suppliedContext: CompanionModelContext? = nil,
                         availableTools: Set<CompanionToolKind> = [], toolExecutor: CompanionToolExecutor? = nil,
                         requestID: UUID? = nil,
                         onSpeechCandidate: (@MainActor @Sendable (String, [String], [CompanionEvidence]) -> Void)? = nil,
                         onReplyComplete: (@MainActor @Sendable (String) -> Void)? = nil,
                         onPartial: (@MainActor @Sendable (String) -> Void)? = nil) async -> LocalImageAnswer {
        #if DEBUG
        let debugTrace = DebugNativeSessionTrace(requestID: requestID)
        #endif
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), OnDeviceLanguage.supports(arabic: arabic) {
            do {
                try Task.checkCancellation()
                let latest = dialogue.turns.last?.text ?? ""
                let currentGoal = workingState.goal.isEmpty ? dialogue.goal : workingState.goal
                let modelContext = try suppliedContext ?? CompanionModelContext(preferredName: preferredName, audience: audience,
                    currentGoal: currentGoal, goalRevision: workingState.goalRevision, parentGoal: workingState.parentGoal?.goal, proposedStep: workingState.proposedStep)
                var earlierReports = workingState.reports.map(\.text)
                if earlierReports.last == latest { earlierReports.removeLast() }
                if earlierReports.isEmpty && !workingState.hasScopedMemoryHistory {
                    earlierReports = dialogue.turns.dropLast().filter { $0.role == "user" }.map(\.text)
                }
                // Retrieve bounded relevant original reports, not generated
                // summaries. Keep newest reports too so explicit corrections win.
                let retrieved = workingState.taskContextReports(dialogue.relevantUserReports(for: latest, maxScalars: 1200).map(\.text))
                var reports: [String] = []
                for report in retrieved + Array(earlierReports.suffix(4)) + [latest] {
                    reports.removeAll { $0 == report }; reports.append(report)
                }
                // Bound total context without truncating the content of a report,
                // which could remove a negation or a temporal qualification.
                var reportBudget = max(0, 2200 - latest.count)
                let boundedReports = reports.filter { $0 != latest }.reversed().filter { report in
                    guard report.count <= reportBudget else { return false }
                    reportBudget -= report.count; return true
                }.reversed()
                var assistantWordBudget = 800
                let priorAssistantWords = dialogue.turns.filter { $0.role == "assistant" && !workingState.hasScopedMemoryHistory }.suffix(3).reversed().filter { turn in
                    guard turn.text.count <= assistantWordBudget else { return false }
                    assistantWordBudget -= turn.text.count; return true
                }.reversed().map(\.text)
                let assistantEvidence = priorAssistantWords.map {
                    CompanionEvidence(kind: .assistantUtterance, text: $0, source: "prior delivered assistant words; not observations")
                }
                let normalFields: [ContextWindowPolicy.Field] = [
                    .init("currentGoal", [currentGoal]),
                    .init("originalUserGoalRequestNotCanonicalLabel", workingState.goalSource.map { [$0.originalRequest] } ?? []),
                    .init("parentGoalOriginalUserRequest", workingState.parentGoal.flatMap(\.source).map { [$0.originalRequest] } ?? []),
                    .init("originalUserReportsNotObservationsOldestFirst", boundedReports.map {
                        "Source: user report; scope: \(CompanionEvidenceGuard.reportScope($0).rawValue). Original words: \($0)"
                    }),
                    .init("priorDeliveredAssistantWordsNotFacts", priorAssistantWords),
                    .init("proposedStepNotExecuted", [workingState.proposedStep]),
                    .init("modelAssociatedStepReportsNotVerified", workingState.reportedStepAssociations.filter { $0.goalRevision == workingState.goalRevision }.suffix(2).map { "Step: «\($0.step)». User report: «\($0.report)». Not independently confirmed." }),
                    .init("userReportedCompletedStepsNotVerified", Array(workingState.reportedCompletedSteps.suffix(3))),

                    .init("latestStructuredUserReportsNotObservations", workingState.facts.suffix(3).map { $0.sourceReport ?? $0.quote }),
                    .init("suspendedGoalsNotActive", workingState.suspendedGoals.map(\.goal)),
                    .init("parentGoalNotCurrentTask", workingState.parentGoal.map { [$0.goal] } ?? []),
                    .init("availableReadOnlyTools", toolExecutor == nil ? [] : availableTools.map(\.rawValue).sorted())
                ]
                // Legacy arbitrary dictionaries are not prompt inputs. Only the
                // bounded typed fields above and sanitized tool results enter.
                _ = situation
                let instructions = conversationInstructions(arabic: arabic, audience: audience)
                let mandatoryFields = modelContext.mandatoryFields + workingState.actionProgress.contextFields(goalRevision: workingState.goalRevision)
                let runtime: CompanionToolRuntime?
                let tools: [any Tool]
                if let toolExecutor, !availableTools.isEmpty {
                    let local = CompanionToolRuntime(available: availableTools, executor: toolExecutor)
                    runtime = local
                    var tool = ReadLocalEvidence(description: "Read local evidence only. Available: \(availableTools.map(\.rawValue).sorted().joined(separator: ", ")). At most three reads. Use saudiBanknote for money, isolatedColor for anonymous appearance, familiarPeople for tentative enrolled matches, readText for OCR. Missing tools/results mean unknown. No side effects.", runtime: local)
                    #if DEBUG
                    tool.debugTrace = debugTrace
                    #endif
                    tools = [tool]
                } else { runtime = nil; tools = [] }
                let started = ProcessInfo.processInfo.systemUptime
                let logger = Logger(subsystem: "org.blindassist.mobility", category: "CompanionAgent")
                var text = ""
                var chunks = CompanionSentenceStream()
                var sentFirst = false
                var recovery = ContextWindowPolicy.Recovery()
                var reduced = false
                generation: while true {
                    try Task.checkCancellation()
                    let fields = reduced ? [
                        ContextWindowPolicy.Field("originalUserReportsNotObservationsOldestFirst", Array(boundedReports.suffix(1)).map {
                            "Source: user report; scope: \(CompanionEvidenceGuard.reportScope($0).rawValue). Original words: \($0)"
                        }),
                        .init("priorDeliveredAssistantWordsNotFacts", Array(priorAssistantWords.suffix(1))),
                        .init("currentGoal", [currentGoal])
                    ] : normalFields
                    let plan = try ContextWindowPolicy.makePrompt(latest: latest, instructions: instructions, mandatoryFields: mandatoryFields, fields: fields, reduced: reduced,
                        task: reduced ? "Answer the latest message. No tools are available in this reduced attempt; ask if necessary context is missing." : "Answer the latest message.")
                    // A new session is mandatory after overflow. A retry has no
                    // tools and therefore cannot repeat reads or reset call limits.
                    #if DEBUG
                    debugTrace?.prompt(plan, instructions: instructions, scope: reduced ? "conversation.reducedRetry" : "conversation")
                    #endif
                    let session = LanguageModelSession(tools: reduced ? [] : tools, instructions: instructions)
                    do {
                        let stream = session.streamResponse(to: plan.prompt,
                            options: GenerationOptions(samplingMode: .greedy, maximumResponseTokens: ContextWindowPolicy.responseTokenLimit))
                        for try await snapshot in stream {
                            try Task.checkCancellation()
                            text = snapshot.content
                            #if DEBUG
                            debugTrace?.event(.modelResponseChunk) { .init(text: snapshot.content, label: "conversation.cumulativeUnvalidatedSnapshot") }
                            #endif
                            let evidence = assistantEvidence + (await runtime?.currentEvidence() ?? [])
                            for chunk in chunks.append(text, reports: reports, evidence: evidence) {
                                try Task.checkCancellation()
                                if !sentFirst {
                                    logger.info("First verified sentence after \(ProcessInfo.processInfo.systemUptime - started, privacy: .public) seconds")
                                    sentFirst = true
                                }
                                await onSpeechCandidate?(chunk, reports, evidence)
                                try Task.checkCancellation()
                                await onPartial?(chunk)
                            }
                            if chunks.rejected {
                                #if DEBUG
                                debugTrace?.event(.outputGate, source: .outputGate) { .init(label: "sentenceEvidenceGuard.rejected") }
                                #endif
                                break
                            }
                        }
                        break generation
                    } catch {
                        try Task.checkCancellation()
                        guard isContextOverflow(error) else { throw error }
                        switch recovery.onOverflow(emittedText: chunks.delivered, cancelled: Task.isCancelled) {
                        case .retryReduced:
                            reduced = true; text = ""; chunks = CompanionSentenceStream()
                            continue generation
                        case .preservePartial:
                            let suffix = ContextWindowPolicy.incompleteSuffix(delivered: chunks.delivered, arabic: arabic)
                            let evidence = assistantEvidence + (await runtime?.currentEvidence() ?? [])
                            if !suffix.isEmpty {
                                try Task.checkCancellation()
                                await onSpeechCandidate?(suffix, reports, evidence)
                                try Task.checkCancellation()
                                await onPartial?(suffix)
                            }
                            let kept = [chunks.delivered, suffix].filter { !$0.isEmpty }.joined(separator: " ")
                            try Task.checkCancellation()
                            await onReplyComplete?(kept)
                            return LocalImageAnswer(text: kept, status: "Local context limit reached; partial reply preserved, not replayed.")
                        case .stop:
                            return LocalImageAnswer(text: nil, status: arabic ? "وصلت إلى حد سياق النموذج المحلي. جرّب سؤالاً أقصر." : "The local model reached its context limit. Try a shorter question.")
                        case .cancelled: throw CancellationError()
                        }
                    }
                }
                try Task.checkCancellation()
                let evidence = assistantEvidence + (await runtime?.currentEvidence() ?? [])
                for chunk in chunks.append(text, final: true, reports: reports, evidence: evidence) {
                    try Task.checkCancellation()
                    await onSpeechCandidate?(chunk, reports, evidence)
                    try Task.checkCancellation()
                    await onPartial?(chunk)
                }
                text = text.trimmingCharacters(in: .whitespacesAndNewlines)
                let finalRejected = chunks.rejected || !usableChatReply(text) || !CompanionEvidenceGuard.allows(text, reports: reports, evidence: evidence)
                #if DEBUG
                debugTrace?.event(.modelResponse) { .init(text: text, label: "conversation.finalTrimmedUnvalidatedText") }
                debugTrace?.event(.outputGate, source: .outputGate) {
                    .init(text: text, label: finalRejected ? "conversation.finalGuard.rejected" : "conversation.finalGuard.accepted")
                }
                #endif
                if finalRejected {
                    // Never repair a model's claim by dropping its uncertainty or
                    // by turning a past report into a present fact. Deterministic
                    // unknown wording is not another expensive model round-trip.
                    let remainingWords = 35 - chunks.delivered.split(whereSeparator: \.isWhitespace).count
                    var fallback = CompanionEvidenceGuard.unavailableReply(arabic: arabic)
                    if fallback.split(whereSeparator: \.isWhitespace).count > remainingWords {
                        fallback = arabic ? "لا أستطيع تأكيد الباقي." : "I can't verify more."
                    }
                    if fallback.split(whereSeparator: \.isWhitespace).count > remainingWords { fallback = "" }
                    try Task.checkCancellation()
                    if !fallback.isEmpty {
                        await onSpeechCandidate?(fallback, reports, evidence)
                        try Task.checkCancellation()
                        await onPartial?(fallback)
                    }
                    let safeText = [chunks.delivered, fallback].filter { !$0.isEmpty }.joined(separator: " ")
                    await onReplyComplete?(safeText)
                    return LocalImageAnswer(text: safeText, status: "Unsupported local claim withheld; current evidence is unknown.")
                }
                try Task.checkCancellation()
                await onReplyComplete?(text)
                logger.info("Conversational reply finished in \(ProcessInfo.processInfo.systemUptime - started, privacy: .public) seconds")
                // Bookkeeping uses a fresh session with NO tools. It cannot cause
                // side effects or delay the first spoken sentence. Its output is
                // only a proposal; the controller validates current goal revision.
                let bookkeepingInstructions = modelContext.instructions(for: .bookkeeping) + " Historical and uncertain reports are not current facts. Empty fields mean no update."
                let bookkeeping = LanguageModelSession(instructions: bookkeepingInstructions)
                guard let bookkeepingPlan = try? ContextWindowPolicy.makePrompt(latest: latest, instructions: bookkeepingInstructions,
                    mandatoryFields: mandatoryFields, fields: modelContext.optionalFields, reduced: true,
                    task: "Record task metadata, using only the exact complete user statement as source.") else {
                    return LocalImageAnswer(text: text, status: "Reply available; task update exceeded local context budget.")
                }
                #if DEBUG
                debugTrace?.prompt(bookkeepingPlan, instructions: bookkeepingInstructions, scope: "bookkeeping")
                #endif
                let result = try? await bookkeeping.respond(to: bookkeepingPlan.prompt, generating: CompanionDecision.self,
                    options: GenerationOptions(samplingMode: .greedy, maximumResponseTokens: ContextWindowPolicy.bookkeepingResponseTokenLimit))
                try Task.checkCancellation()
                guard let decision = result?.content else {
                    return LocalImageAnswer(text: text, status: "Reply available; task update unavailable.")
                }
                #if DEBUG
                debugTrace?.event(.modelResponse) {
                    // Only returned structured fields, never model internals/reasoning.
                    let fields = ["factQuote": decision.factQuote, "factSubject": decision.factSubject,
                        "factValue": decision.factValue, "newGoal": decision.newGoal,
                        "cancellationReport": decision.cancellationReport, "completionReport": decision.completionReport,
                        "completionStep": decision.completionStep, "nextStep": decision.nextStep]
                    let bytes = try? JSONEncoder().encode(fields)
                    return .init(text: bytes.map { String(decoding: $0, as: UTF8.self) }, label: "bookkeeping.returnedFields.unvalidated")
                }
                #endif
                let fact = reportedFact(quote: decision.factQuote, subject: decision.factSubject, value: decision.factValue, latest: latest)
                return LocalImageAnswer(text: text, status: "On-device conversation; sources checked.", taskUpdate: CompanionTaskUpdate(
                    goal: decision.newGoal, nextStep: decision.nextStep, completionReport: decision.completionReport, completionStep: decision.completionStep,
                    cancellationReport: decision.cancellationReport, fact: fact, contextRevision: workingState.goalRevision))
            } catch is CancellationError {
                #if DEBUG
                debugTrace?.event(.unavailable) { .init(label: "conversation.cancelled") }
                #endif
                return LocalImageAnswer(text: nil, status: "Conversation interrupted.")
            } catch is ContextWindowPolicy.BudgetError {
                #if DEBUG
                debugTrace?.event(.unavailable) { .init(label: "conversation.contextBudgetError") }
                #endif
                return LocalImageAnswer(text: nil, status: arabic ? "هذا الطلب أطول من حد السياق المحلي. جرّب سؤالاً أقصر." : "That request exceeds the local context budget. Try a shorter question.")
            } catch {
                #if DEBUG
                debugTrace?.event(.unavailable) { .init(label: "conversation.failed; errorDetailsOmitted") }
                #endif
                // Some providers throw a non-CancellationError after cancellation.
                // Never turn an interrupted request into a new operational reply.
                guard !Task.isCancelled else { return LocalImageAnswer(text: nil, status: "Conversation interrupted.") }
                return LocalImageAnswer.conversationFailure(.generationFailed, arabic: arabic)
            }
        }
        #endif
        guard !Task.isCancelled else { return LocalImageAnswer(text: nil, status: "Conversation interrupted.") }
        return LocalImageAnswer.conversationFailure(.modelUnavailable, arabic: arabic)
    }
    /// A constrained uncertain hint, never a sensor search result or identity.
    /// The controller must revalidate the frame and guard the code-written hint.
    static func spot(target: String, image: CVPixelBuffer, arabic: Bool, modelContext: CompanionModelContext, requestID: UUID? = nil) async -> String? {
        #if DEBUG
        let debugTrace = DebugNativeSessionTrace(requestID: requestID)
        #endif
        guard !Task.isCancelled, !target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              target.count <= 40 else { return nil }
        #if BLIND_APPLE_MULTIMODAL && canImport(FoundationModels)
        if #available(iOS 27.0, *), OnDeviceLanguage.supports(arabic: arabic) {
            let instructions = modelContext.instructions(for: .spot) + " Answer yes only when the named target is clearly visible; otherwise unsure."
            let session = LanguageModelSession(instructions: instructions)
            do {
                try Task.checkCancellation()
                let plan = try ContextWindowPolicy.makePrompt(latest: "Check the named target in this captured view.", instructions: instructions,
                    mandatoryFields: modelContext.mandatoryFields + [.init("target", [target])], fields: [], reduced: false)
                #if DEBUG
                debugTrace?.prompt(plan, instructions: instructions, scope: "spot.imageOmitted")
                #endif
                let result = try await session.respond(generating: SpotResult.self,
                    options: GenerationOptions(samplingMode: .greedy, maximumResponseTokens: 30)) {
                    plan.prompt
                    Attachment(image, orientation: .right)
                }.content
                try Task.checkCancellation()
                #if DEBUG
                debugTrace?.event(.modelResponse) {
                    .init(text: "visible=\(result.visible); side=\(result.side)", label: "spot.returnedFields.notSensorEvidence")
                }
                #endif
                guard result.visible == .yes else { return nil }
                switch result.side {
                case .left: return "left"
                case .centre: return "centre"
                case .right: return "right"
                case .unknown: return ""
                }
            } catch { return nil }
        }
        #endif
        return nil
    }

    static func status(arabic: Bool) -> String {
        #if BLIND_APPLE_MULTIMODAL && canImport(FoundationModels)
        if #available(iOS 27.0, *) {
            return OnDeviceLanguage.supports(arabic: arabic) ? "On-device image descriptions available; device evaluation pending." : "On-device image model or requested language unavailable."
        }
        return "Image descriptions require iOS 27 or later."
        #else
        return "This build uses Vision evidence descriptions. The iOS 27 image-model adapter is not enabled."
        #endif
    }
    static func describe(image: CVPixelBuffer, question: String, context: SceneContext,
                         situation: [String: Any], wordAllowance: Int, confirmedObjects: [String] = [], modelContext: CompanionModelContext, requestID: UUID? = nil) async -> LocalImageAnswer {
        #if DEBUG
        let debugTrace = DebugNativeSessionTrace(requestID: requestID)
        #endif
        guard (1...300).contains(wordAllowance), context.monitoring == "observing" else {
            return LocalImageAnswer(text: nil, status: "Current monitoring does not permit a scene description.")
        }
        #if BLIND_APPLE_MULTIMODAL && canImport(FoundationModels)
        if #available(iOS 27.0, *), OnDeviceLanguage.supports(arabic: context.language == "ar") {
            do {
                // The free built-in model has a ~4,096-token window: the shared compact guide prompt
                // (~600 tokens) plus a situation summary capped near 1,000 tokens.
                guard let data = GuidePrompt.compactSituation(situation) else {
                    return LocalImageAnswer(text: nil, status: "Context exceeds local image-model allowance.")
                }
                let instructions = modelContext.instructions(for: .describe) + "\n" + GuidePrompt.instructions(
                    arabic: context.language == "ar", wordAllowance: wordAllowance, requested: context.requested)
                let session = LanguageModelSession(instructions: instructions)
                let evidence = try context.json()
                let compact = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
                let situationFields = compact.keys.sorted().compactMap { key -> ContextWindowPolicy.Field? in
                    guard let value = compact[key], JSONSerialization.isValidJSONObject(["value": value]),
                          let bytes = try? JSONSerialization.data(withJSONObject: ["value": value], options: [.sortedKeys]) else { return nil }
                    return .init("scene_" + key, [String(decoding: bytes, as: UTF8.self)])
                }
                let plan = try ContextWindowPolicy.makePrompt(latest: question.isEmpty ? "Describe this captured view." : question, instructions: instructions,
                    mandatoryFields: modelContext.mandatoryFields,
                    fields: [.init("capturedEvidence", [evidence]), .init("detectorObjectCandidatesNotIdentity", confirmedObjects.sorted())] + situationFields,
                    reduced: false)
                guard plan.context["capturedEvidence"] != nil else { return LocalImageAnswer(text: nil, status: "Captured evidence exceeds local budget.") }
                #if DEBUG
                debugTrace?.prompt(plan, instructions: instructions, scope: "describe.imageOmitted")
                #endif
                let response = try await session.respond {
                    plan.prompt
                    Attachment(image, orientation: .right)
                }
                try Task.checkCancellation()
                #if DEBUG
                debugTrace?.event(.modelResponse) { .init(text: response.content, label: "describe.rawReturnedText.unvalidated") }
                #endif
                let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty, text.unicodeScalars.count <= AssistantDialogue.maximumTurnScalars else { return LocalImageAnswer(text: nil, status: "Image model returned an unsupported answer.") }
                return LocalImageAnswer(text: text, status: "Described this camera image using the on-device model.")
            } catch is CancellationError {
                return LocalImageAnswer(text: nil, status: "Image description cancelled.")
            } catch {
                return LocalImageAnswer(text: nil, status: "Image model could not answer. Using available Vision evidence.")
            }
        }
        #endif
        return LocalImageAnswer(text: nil, status: status(arabic: context.language == "ar"))
    }
}


#if DEBUG
/// Captured diagnostic ownership, not model authority or a new sensor observer.
/// Nil without explicit launch opt-in. No callback fetches a newer recording token.
struct DebugNativeSessionTrace: Sendable {
    private let log: DebugSessionLog
    private let token: DebugSessionLog.SessionToken
    private let requestID: UUID?
    init?(recorder: DebugSessionLog? = DebugSessionLog.shared, requestID: UUID? = nil) {
        guard let log = recorder else { return nil }
        self.log = log; self.token = log.sessionToken; self.requestID = requestID
    }
    func event(_ kind: DebugSessionLog.Kind, source: DebugSessionLog.Source = .onDeviceModel,
               utteranceID: UUID? = nil, detail: () -> DebugSessionLog.Detail = { .init() }) {
        log.record(kind, source: source, session: token,
                   correlation: .init(requestID: requestID, utteranceID: utteranceID), detail: detail)
    }
    func prompt(_ plan: ContextWindowPolicy.PromptPlan, instructions: String, scope: String) {
        event(.modelRequest) { .init(text: instructions, label: scope + ".instructions") }
        event(.modelRequest) { .init(text: plan.prompt, label: scope + ".actualPrompt") }
        event(.modelRequest) {
            .init(text: plan.context.keys.sorted().joined(separator: ","),
                  label: scope + ".includedContextKeys; underlyingRecordIDs=unbound")
        }
    }
    func finish() { log.finish(session: token) }
    private static let purgeReportQueue = DispatchQueue(label: "BlindAssist.DebugPurgeReceipt", qos: .utility)
    private static let purgeReportSlot = DispatchSemaphore(value: 1)
    static func reportPurgeResult(_ success: Bool) {
        guard !success, purgeReportSlot.wait(timeout: .now()) == .success else { return }
        purgeReportQueue.async {
            defer { purgeReportSlot.signal() }
            // Fixed diagnostic only: no text, names, paths, secrets or user data.
            let message = "BlindAssist DEBUG: diagnostic purge failed or is unconfirmed; inspect private storage and retry.\n"
            try? FileHandle.standardError.write(contentsOf: Data(message.utf8))
        }
    }
    // Only the isolated helper harness may wait for this queue, never native callbacks.
    static func drainDeveloperReportsForTesting() { purgeReportQueue.sync {} }
}
#endif
