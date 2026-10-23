import Foundation

/// Conversation evidence is not a world model. In particular, a person's report
/// and a saved map can never be promoted to a fresh camera/sensor observation.
public enum CompanionEvidenceKind: String, Codable, Sendable {
    case userReport, historicalMemory, assistantUtterance, currentObservation, measuredState, capturedView
}

public struct CompanionEvidence: Codable, Sendable, Equatable {
    public var id: String
    public var kind: CompanionEvidenceKind
    public var text: String
    public var source: String
    public var observedAt: Date?
    public var expiresAt: Date?

    public init(id: String = UUID().uuidString, kind: CompanionEvidenceKind, text: String,
                source: String, observedAt: Date? = nil, expiresAt: Date? = nil) {
        self.id = id; self.kind = kind; self.text = text; self.source = source
        self.observedAt = observedAt; self.expiresAt = expiresAt
    }
    /// Attributed RGB snapshot only, never current presence, identity or spatial authority.
    public func isCapturedViewValid(at now: Date) -> Bool {
        guard kind == .capturedView, source == "bounded on-device captured view",
              CapturedViewEvidence.hasAttributedPrefix(text), !text.isEmpty,
              let observedAt, let expiresAt else { return false }
        return observedAt <= now && now.timeIntervalSince(observedAt) <= 12
            && expiresAt > now && expiresAt.timeIntervalSince(observedAt) <= 12
            && !SpatialClaimGuard.containsSpatialClaim(text)
            && !SaudiBanknotePolicy.containsUnverifiedMoneyValue(text)
    }
    public func isCurrent(at now: Date) -> Bool {
        guard kind == .currentObservation || kind == .measuredState,
              !source.isEmpty, !text.isEmpty, let observedAt, let expiresAt else { return false }
        // An injected future clock or arbitrarily distant expiry is not freshness.
        return observedAt <= now && now.timeIntervalSince(observedAt) <= 5
            && expiresAt > now && expiresAt.timeIntervalSince(observedAt) <= 5
    }
}

/// Code-owned quotation keeps OCR punctuation inside one attributed record.
/// Delimiter-bearing or oversized input is withheld instead of truncating a negation.
public enum CapturedViewEvidence {
    public static func hasAttributedPrefix(_ text: String) -> Bool {
        ["Captured view ", "The image seemed to show: «", "The captured text may read: «",
         "بدا في الصورة: «", "قد يكون النص في الصورة: «"].contains { text.hasPrefix($0) }
    }
    public static func candidate(_ content: String, appearance: Bool = false, arabic: Bool = false) -> String? {
        let content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, content.count <= 180,
              !content.contains("«"), !content.contains("»") else { return nil }
        // Provenance remains in typed source/age metadata, not technical spoken jargon.
        // Keep the whole quote and uncertainty; never shorten away a negation.
        let prefix = arabic
            ? (appearance ? "بدا في الصورة" : "قد يكون النص في الصورة")
            : (appearance ? "The image seemed to show" : "The captured text may read")
        let terminator = content.last.map { ".!?؟".contains($0) } == true ? "" : "."
        return "\(prefix): «\(content)»\(terminator)"
    }
}

public enum CompanionToolKind: String, Codable, CaseIterable, Sendable {
    case currentObservation, savedMemory, navigationState, deviceClock
    case saudiBanknote, isolatedColor, familiarPeople, readText
}
public struct CompanionToolRequest: Sendable, Equatable {
    public var kind: CompanionToolKind
    public var query: String
    public init(kind: CompanionToolKind, query: String = "") {
        self.kind = kind; self.query = query
    }
}
public enum CompanionToolStatus: String, Codable, Sendable {
    case success, unavailable, offline, stale, rejectedEvidence, cancelled, timedOut, callLimit
}
public struct CompanionToolResult: Codable, Sendable, Equatable {
    public var status: CompanionToolStatus
    public var source: String
    public var summary: String
    public var evidence: [CompanionEvidence]
    public init(status: CompanionToolStatus, source: String, summary: String = "", evidence: [CompanionEvidence] = []) {
        self.status = status; self.source = source; self.summary = summary; self.evidence = evidence
    }
}

/// A read of the device's configured wall clock, not network time, location or
/// camera evidence. The caller supplies both date and zone; tests never depend
/// on the machine's clock, locale or default time zone.
public enum CompanionClock {
    public static let lifetime: TimeInterval = 5
    private static let sourcePrefix = "on-device clock: "

    public static func read(now: Date, timeZone: TimeZone, arabic: Bool) -> CompanionToolResult {
        guard valid(now) else {
            return CompanionToolResult(status: .unavailable, source: "on-device clock",
                summary: "The device clock could not be read. Do not invent the current time.")
        }
        let source = sourcePrefix + timeZone.identifier
        let evidence = CompanionEvidence(kind: .measuredState,
            text: statement(now: now, timeZone: timeZone, arabic: arabic), source: source,
            observedAt: now, expiresAt: now.addingTimeInterval(lifetime))
        return CompanionToolResult(status: .success, source: source,
            summary: "Device-configured time zone: \(timeZone.identifier). observedAt is the read timestamp. This is clock evidence only, not location, camera or navigation evidence.",
            evidence: [evidence])
    }

    /// A measured clock record does not require a camera capture. Validate the
    /// complete code-written record before exempting it from that requirement;
    /// a source label alone cannot turn arbitrary measured claims into a clock.
    public static func isClockEvidence(_ item: CompanionEvidence) -> Bool {
        guard item.kind == .measuredState, item.source.hasPrefix(sourcePrefix),
              let observedAt = item.observedAt, valid(observedAt),
              item.expiresAt == observedAt.addingTimeInterval(lifetime),
              let zone = TimeZone(identifier: String(item.source.dropFirst(sourcePrefix.count))),
              item.source == sourcePrefix + zone.identifier else { return false }
        return item.text == statement(now: observedAt, timeZone: zone, arabic: false)
            || item.text == statement(now: observedAt, timeZone: zone, arabic: true)
    }

    private static func valid(_ date: Date) -> Bool {
        date.timeIntervalSinceReferenceDate.isFinite && date >= .distantPast && date <= .distantFuture
    }
    private static func statement(now: Date, timeZone: TimeZone, arabic: Bool) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: arabic ? "ar_SA" : "en_US")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateStyle = .none; formatter.timeStyle = .short
        let time = formatter.string(from: now)
        return arabic ? "ساعة الجهاز: \(time) (\(timeZone.identifier))."
            : "Device clock: \(time) (\(timeZone.identifier))."
    }
}

/// The controller supplies read-only, already permission/safety-gated local reads.
/// No network, camera start, navigation mutation, face naming, payment, or speech
/// action is authorized by this closure. It must cooperate with cancellation.
public typealias CompanionToolExecutor = @Sendable (CompanionToolRequest) async -> CompanionToolResult

/// One turn owns one runtime. A fixed call budget includes failed reads. A timeout
/// returns promptly even if a buggy reader ignores cancellation; late results are
/// discarded and cannot be added to the evidence ledger. Readers must be read-only.
public actor CompanionToolRuntime {
    private let executor: CompanionToolExecutor
    private let available: Set<CompanionToolKind>
    private let maximumCalls: Int
    private let timeoutNanoseconds: UInt64
    private var calls = 0
    private var remainingResultBytes = ContextWindowPolicy.maximumTurnToolResultUTF8Bytes
    private var evidence: [CompanionEvidence] = []
    private var results: [CompanionToolResult] = []

    public init(available: Set<CompanionToolKind>, maximumCalls: Int = 3,
                timeout: TimeInterval = 2, executor: @escaping CompanionToolExecutor) {
        self.available = available; self.maximumCalls = max(0, min(maximumCalls, 3))
        let boundedTimeout = timeout.isFinite ? max(0.001, min(timeout, 2)) : 2
        self.timeoutNanoseconds = UInt64(boundedTimeout * 1_000_000_000)
        self.executor = executor
    }
    public func run(_ request: CompanionToolRequest) async -> CompanionToolResult {
        guard !Task.isCancelled else { return failure(.cancelled, request.kind) }
        guard calls < maximumCalls else { return failure(.callLimit, request.kind) }
        calls += 1
        guard available.contains(request.kind), request.query.count <= 300,
              request.query.utf8.count <= ContextWindowPolicy.maximumToolQueryUTF8Bytes else {
            let result = boundOutput(failure(.unavailable, request.kind), kind: request.kind); results.append(result); return result
        }
        let race = CompanionReadRace()
        let executor = self.executor, timeout = timeoutNanoseconds
        let result = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                race.start(continuation: continuation, request: request, timeout: timeout, executor: executor)
            }
        } onCancel: {
            race.finish(CompanionToolResult(status: .cancelled, source: request.kind.rawValue))
        }
        guard !Task.isCancelled else { return failure(.cancelled, request.kind) }
        let checked = boundOutput(sanitize(result, for: request.kind, now: Date()), kind: request.kind)
        results.append(checked)
        evidence.append(contentsOf: checked.evidence)
        return checked
    }
    public func currentEvidence() -> [CompanionEvidence] { evidence }
    public func completedResults() -> [CompanionToolResult] { results }
    public func callCount() -> Int { calls }
    public func resultUTF8BytesUsed() -> Int { ContextWindowPolicy.maximumTurnToolResultUTF8Bytes - remainingResultBytes }

    private func boundOutput(_ result: CompanionToolResult, kind: CompanionToolKind) -> CompanionToolResult {
        let limit = min(remainingResultBytes, ContextWindowPolicy.maximumToolResultUTF8Bytes)
        func size(_ value: CompanionToolResult) -> Int { (try? JSONEncoder().encode(value).count) ?? Int.max }
        var bounded = result
        // Drop complete records, never a negation or qualifier within a record.
        while size(bounded) > limit && !bounded.evidence.isEmpty { bounded.evidence.removeLast() }
        if !result.evidence.isEmpty && bounded.evidence.isEmpty {
            bounded.status = .unavailable
            bounded.summary = "Local result exceeded the text budget; evidence remains unknown."
        }
        if size(bounded) > limit { bounded.summary = "" }
        if size(bounded) > limit { bounded = failure(.callLimit, kind) }
        let count = size(bounded)
        // Tool.call throws for callLimit, so this result is not fed back into the
        // model and cannot exceed the turn budget with repeated error receipts.
        guard count <= limit else { return failure(.callLimit, kind) }
        remainingResultBytes -= count
        return bounded
    }

    private func failure(_ status: CompanionToolStatus, _ kind: CompanionToolKind) -> CompanionToolResult {
        CompanionToolResult(status: status, source: kind.rawValue,
                            summary: "No observation was obtained. Do not infer absence, clearance, or completion.")
    }
    private func sanitize(_ result: CompanionToolResult, for kind: CompanionToolKind, now: Date) -> CompanionToolResult {
        guard !result.source.isEmpty, result.source.count <= 120, result.summary.count <= 600 else {
            return failure(.rejectedEvidence, kind)
        }
        guard result.status == .success else {
            // Failure payloads cannot smuggle observations into a reply.
            return CompanionToolResult(status: result.status, source: result.source, summary: result.summary)
        }
        // Reuse the same acceptance predicates to distinguish expiry from a
        // policy, provenance or shape rejection. This does not renew a receipt.
        func accepts(_ item: CompanionEvidence, at date: Date) -> Bool {
            switch kind {
            case .savedMemory:
                return item.kind == .historicalMemory || item.kind == .userReport
            case .currentObservation:
                return (item.kind == .currentObservation && item.isCurrent(at: date)) || item.isCapturedViewValid(at: date)
            case .navigationState:
                return item.kind == .historicalMemory || (item.kind == .measuredState && item.isCurrent(at: date))
            case .deviceClock:
                return CompanionClock.isClockEvidence(item) && item.isCurrent(at: date)
            case .saudiBanknote, .isolatedColor, .familiarPeople, .readText:
                return CompanionCapabilityEvidence.valid(item, for: kind, now: date)
            }
        }
        var remainingScalars = 800
        var onlyExpiredEvidence = true
        let usable = result.evidence.prefix(4).filter { item in
            guard !item.id.isEmpty, item.id.count <= 80, !item.text.isEmpty, item.text.count <= 500,
                  item.text.unicodeScalars.count <= remainingScalars,
                  !item.source.isEmpty, item.source.count <= 120 else {
                onlyExpiredEvidence = false
                return false
            }
            remainingScalars -= item.text.unicodeScalars.count
            let accepted = accepts(item, at: now)
            if !accepted {
                if let observedAt = item.observedAt, let expiresAt = item.expiresAt,
                   observedAt <= now, expiresAt <= now, accepts(item, at: observedAt) {
                    // Otherwise valid at capture and now expired; do not keep it.
                } else {
                    onlyExpiredEvidence = false
                }
            }
            return accepted
        }
        if !result.evidence.isEmpty && usable.isEmpty {
            return failure(onlyExpiredEvidence ? .stale : .rejectedEvidence, kind)
        }
        return CompanionToolResult(status: .success, source: result.source, summary: result.summary, evidence: usable)
    }
}

// NSLock protects a single continuation, not task scheduling. Unstructured reader
// tasks are required here: a structured task group waits for an uncooperative
// child on exit and therefore cannot enforce a caller-visible timeout.
private final class CompanionReadRace: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<CompanionToolResult, Never>?
    private var completed: CompanionToolResult?
    private var tasks: [Task<Void, Never>] = []

    func start(continuation: CheckedContinuation<CompanionToolResult, Never>, request: CompanionToolRequest,
               timeout: UInt64, executor: @escaping CompanionToolExecutor) {
        lock.lock()
        if let completed { lock.unlock(); continuation.resume(returning: completed); return }
        self.continuation = continuation
        let reader = Task { [self] in
            guard !Task.isCancelled else { return }
            let result = await executor(request)
            finish(result)
        }
        let timer = Task { [self] in
            do { try await Task.sleep(nanoseconds: timeout) } catch { return }
            finish(CompanionToolResult(status: .timedOut, source: request.kind.rawValue,
                                      summary: "Local read timed out; current evidence is unknown."))
        }
        tasks = [reader, timer]
        lock.unlock()
    }
    func finish(_ result: CompanionToolResult) {
        lock.lock()
        guard completed == nil else { lock.unlock(); return }
        completed = result
        let continuation = self.continuation, tasks = self.tasks
        self.continuation = nil; self.tasks = []
        lock.unlock()
        tasks.forEach { $0.cancel() }
        continuation?.resume(returning: result)
    }
}

public enum CompanionReportScope: String, Codable, Sendable { case historical, currentReported, uncertain }

/// Bounded lexical defense, not a semantic truth detector. The app applies this
/// before every streamed sentence AND the final answer, alongside SpatialClaimGuard.
/// Local-world assertions fail closed unless reproduced from a fresh, gated tool
/// record. Historical/current user reports may be quoted with explicit attribution,
/// never silently upgraded to independent observation. General conversation remains
/// model generated. Real bilingual adversarial/model/device evaluation is still due.
public enum CompanionEvidenceGuard {
    private static func matches(_ pattern: String, _ text: String) -> Bool {
        text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
    private static func normalized(_ text: String) -> String {
        SpatialClaimGuard.normalizeArabic(text.lowercased())
            .replacingOccurrences(of: #"[^\p{L}\p{N}]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    public static func reportScope(_ text: String) -> CompanionReportScope {
        let ar = SpatialClaimGuard.normalizeArabic(text)
        if matches(#"\b(last|earlier|yesterday|previously|before|used to|left|had|was|were|put|remember|ago)\b|امس|سابقا|تركت|وضعت|كان|اخر مره|قبل"#, ar) { return .historical }
        if matches(#"\b(maybe|perhaps|might|could|think|guess|not sure|if|will|would|plan|going to|should)\b|ربما|اظن|اعتقد|يمكن|لست متاكد|سوف"#, ar)
            || text.contains("?") || text.contains("؟") { return .uncertain }
        if matches(#"\b(is|are|am|have|now|currently)\b|الان|حاليا|مفتوح|مغلق"#, ar) { return .currentReported }
        return .uncertain
    }

    /// Model-selected substrings cannot turn "not done", a question, or a
    /// future plan into task completion. This is a user-report receipt only,
    /// never sensor verification or physical arrival.
    public static func explicitCompletionReport(_ quote: String, latest: String) -> Bool {
        guard !quote.isEmpty, quote.count <= 300,
              sentenceParts(latest).contains(where: { normalized($0.text) == normalized(quote) }),
              !latest.contains("?"), !latest.contains("؟") else { return false }
        let text = SpatialClaimGuard.normalizeArabic(quote)
        guard !matches(#"\b(not|n't|never|haven't|hasn't|didn't|don't|cannot|can't|will|going to|might|maybe|if|should|would)\b|لم|لن|ليس|لست|ربما|سوف|ما زلت"#, text) else { return false }
        return matches(#"\b(i (have |just |already )?(finished|completed|found)|i did it|i['’]m done|i am done|done|finished|completed)\b|انتهيت|خلصت|تمت|وجدته|وجدتها"#, text)
    }

    public static func allows(_ text: String, reports: [String], evidence: [CompanionEvidence] = [], now: Date = Date()) -> Bool {
        guard !text.isEmpty, text.unicodeScalars.count <= 2000,
              !SpatialClaimGuard.containsSpatialClaim(text),
              !matches(#"earlier conversation:|latest (child|user) message:|\b(child|user|assistant):|proposedStepNotExecuted|readLocalEvidence|historicalMapAndPreferences"#, text) else { return false }
        for part in sentenceParts(text).map(\.text) {
            let sentence = part.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !sentence.isEmpty else { continue }
            let clean = normalized(sentence)
            // A captured-view quote may finish after the live observation lease,
            // but cannot be silently rewritten as a current fact.
            if let snapshot = evidence.first(where: { $0.kind == .capturedView && normalized($0.text) == clean }) {
                guard snapshot.isCapturedViewValid(at: now) else { return false }
                continue
            }
            // Current tool claims must match one complete, code-approved record.
            // Token overlap is intentionally insufficient (it loses negation).
            if let exact = evidence.first(where: { ($0.kind == .currentObservation || $0.kind == .measuredState) && normalized($0.text) == clean }) {
                guard exact.isCurrent(at: now) else { return false }
                continue
            }
            // Explicit provenance phrases must not become a loophole when the
            // corresponding observation expires during generation.
            if matches(#"^(the image seemed to show|the captured text may read|captured view|visible text candidate|current observation|measured state|camera observation|device clock|recognized saudi note|the isolated item in this view|i might see)\b|^(بدا في الصوره|قد يكون النص في الصوره|ساعه الجهاز|الورقه السعوديه المقروءه|قد يكون هذا|الغرض المنفصل في اللقطه)"#, clean) { return false }
            let quoted = attributedQuotation(sentence, reports: reports, evidence: evidence)
            let remainder = quoted ?? sentence
            if quoted == nil, evidence.contains(where: { $0.source == CompanionCapabilityEvidence.source(.saudiBanknote) }),
               (SaudiBanknotePolicy.containsUnverifiedMoneyValue(remainder) ||
                matches(#"\b(total|sum|altogether|value)\b.*[0-9٠-٩۰-۹]|مجموع|الاجمالي"#, remainder)) { return false }
            if isLocalAssertion(remainder) || ConversationClaimGuard.containsUnsupportedClaim(remainder) { return false }
            // In a task/report context, possessive and anaphoric descriptions
            // cannot bypass the guard by changing the state verb ("sitting",
            // "waiting", "right where you left it", etc.). An uncertainty word
            // does not turn a made-up current location into evidence.
            if quoted == nil, reports.contains(where: { reportScope($0) != .uncertain }),
               matches(#"\b(your\s+[\p{L}' -]{1,45}|it|they|he|she|that|this)\s+(is|are|was|were|has|have|remains?|seems?|looks?|must|might|may|could|should|will|would)\b|\b(it['’]s|they['’]re)\b"#, sentence),
               !matches(#"^\s*(can|could|would|will|do|does|did|is|are|where|what|when|why|how)\b"#, sentence),
               !matches(#"^\s*that (could|might) be a (possible )?place to (check|start)[.!]?$"#, sentence) { return false }
            if quoted == nil && matches(#"\b(you (said|reported|mentioned|told)|i said|my earlier words|according to (you|your)|your (report|memory)|last (seen|reported))\b|قلت|ذكرت|حسب كلامك|اخر مره|كان ردي|ردي السابق"#, sentence) {
                // Fabricated attribution is not a workaround for missing evidence.
                return false
            }
        }
        return true
    }

    /// Bind only visual receipts used by complete sentences, including the same
    /// whitespace/punctuation normalization as allows(). Unrelated stale reads
    /// cannot block free conversation or a fresh clock answer.
    public static func requiredVisualEvidence(_ text: String, reports: [String], evidence: [CompanionEvidence], now: Date = Date()) -> [CompanionEvidence]? {
        func visual(_ item: CompanionEvidence) -> Bool {
            item.kind == .capturedView || item.kind == .currentObservation ||
                (item.kind == .measuredState && !CompanionClock.isClockEvidence(item))
        }
        let nonvisual = evidence.filter { !visual($0) }
        if allows(text, reports: reports, evidence: nonvisual, now: now) { return [] }
        let parts = sentenceParts(text).map { normalized($0.text) }
        let required = evidence.filter { visual($0) && parts.contains(normalized($0.text)) }
        guard !required.isEmpty, allows(text, reports: reports, evidence: nonvisual + required, now: now) else { return nil }
        return required
    }

    /// Sentence boundaries outside quoted source text. A period inside an exact
    /// user quote must not strip its attribution before the evidence check.
    static func sentenceParts(_ text: String) -> [(text: String, complete: Bool)] {
        let chars = Array(text)
        var result: [(String, Bool)] = [], buffer = ""
        var quoteClose: Character?
        for (index, char) in chars.enumerated() {
            buffer.append(char)
            var closedAfterPunctuation = false
            if let close = quoteClose {
                if char == close {
                    quoteClose = nil
                    closedAfterPunctuation = index > 0 && ".!?؟".contains(chars[index - 1])
                }
            } else if char == "“" { quoteClose = "”" }
            else if char == "«" { quoteClose = "»" }
            else if char == "\"" { quoteClose = "\"" }
            let decimal = char == "." && index > 0 && chars[index - 1].isNumber
                && (index + 1 == chars.count || chars[index + 1].isNumber)
            if quoteClose == nil && ((".!?؟\n".contains(char) && !decimal) || closedAfterPunctuation) {
                result.append((buffer, true)); buffer = ""
            }
        }
        if !buffer.isEmpty { result.append((buffer, false)) }
        return result
    }

    private static func attributedQuotation(_ text: String, reports: [String], evidence: [CompanionEvidence]) -> String? {
        guard matches(#"^\s*(you (said|reported|mentioned)|i said|my earlier words|your (earlier |last )?report|saved (note|memory)|قلت|ذكرت|حسب كلامك|كان ردي|ردي السابق)\s*[:،,]?\s*[\"“«]"#, text) else { return nil }
        let pairs: [(Character, Character)] = [("“", "”"), ("\"", "\""), ("«", "»")]
        for (open, close) in pairs {
            guard let first = text.firstIndex(of: open), let last = text[text.index(after: first)...].firstIndex(of: close) else { continue }
            let quote = String(text[text.index(after: first)..<last])
            let assistantAttribution = matches(#"^\s*(i said|my earlier words|كان ردي|ردي السابق)"#, text)
            let sources = assistantAttribution
                ? evidence.filter { $0.kind == .assistantUtterance }.map(\.text)
                : reports + evidence.filter { $0.kind == .historicalMemory || $0.kind == .userReport }.map(\.text)
            guard !quote.isEmpty, sources.contains(where: { normalized($0) == normalized(quote) }) else { return nil }
            return String(text[text.index(after: last)...])
        }
        return nil
    }

    private static func isLocalAssertion(_ text: String) -> Bool {
        let text = SpatialClaimGuard.normalizeArabic(text)
        // Deictic denomination statements require the exact specialized receipt,
        // not merely a nearby monetary number or a model rewrite of that receipt.
        if matches(#"\b(it(?:['’]s| is)?|this(?: note| bill)?(?: is)?|that(?: note| bill)?(?: is)?|the (?:note|bill)(?: is)?)\s+(?:worth |value is |value of )?(?:[0-9]+|one|five|ten|twenty|fifty|hundred|thousand)\s*(?:riyal|sar|dollar|euro|pound)|(?:هذه|هذي|هذا|هي|قيمتها|قيمته)\s*.{0,12}[0-9٠-٩]+\s*(?:ريال|دولار|يورو)"#, text) { return true }
        // Conversation has no authority to invent a physical route. Measured
        // navigation instructions remain code-owned, outside this model path.
        if matches(#"\b(turn (left|right|around)|(?:walk|go|head|move|step|proceed|cross|climb|descend) (?:straight |directly |carefully )?(?:ahead|forward|back|left|right|up|down|to|toward|towards|through|past|into|across)|follow (?:the|your|that|this) (?:path|route|hall|corridor|person))\b|اتجه|اذهب|امش|انعطف|اعبر|تقدم نحو"#, text) { return true }
        // First-person execution/perception is never licensed by a proposed step
        // or read-only tool. The controller speaks actual action receipts itself.
        if matches(#"\b(i|i've|i have|we|we've|we have)\s+(just |already |successfully )?(found|checked|searched|scanned|looked|verified|confirmed|opened|closed|saved|deleted|sent|booked|called|ordered|completed|finished|cancelled|canceled|moved|turned|see|saw|can see|notice|noticed)\b|تم (فتح|اغلاق|ارسال|حفظ|حجز|العثور)|وجدت|ارى|رايت|تحققت|فحصت|بحثت"#, text) { return true }
        if matches(#"\b((your|this|that|the)\s+[\p{L}' -]{1,45}|it|they|there)\s+(is|are|was|were|looks?|seems?|remains?|must be|might be|may be|could be|should be|can be|will be|'s|'re)\s+((still|probably|possibly|currently|now|not|no longer|definitely|apparently)\s+)*(on|in|at|under|inside|outside|behind|beside|near|by|next to|here|there|missing|lost|found|gone|open|closed|empty|full|locked|unlocked|safe|clear|red|blue|green|white|black|brown)\b"#, text) { return true }
        if matches(#"\b(your|the|this|that)\s+[\p{L}' -]{1,35}\s+(sits?|lies?|stands?|rests?|stays?|contains?|holds?|has|have|opened|closed|moved|is located|can be found)\b|\b(it|they)\s+(sits?|lies?|remains?|belongs?|stays?)\b|\b(it'?s|they'?re)\s+(on|in|at|under|behind|near|there|here|open|closed)\b"#, text) { return true }
        if matches(#"\b(the (label|sign|screen|document|page|note)|it) (says|reads)|\b(that['’]s|this is|that is) (your|a|an)|\b(this|that) (person|man|woman|child) is\b|\b(the (person|man|woman|child)) is your\b"#, text) { return true }
        if matches(#"\b(current (camera|image|frame|sensor|observation)|live (camera|image)|camera (shows|sees)|sensor (shows|says)|this is (your|a|an)|that is (your|a|an))\b|الكاميرا تظهر|هذه ورقه|هذا اخوك|هذا والدك"#, text) { return true }
        if matches(#"\b(no|nothing|nobody|someone|someone else)\s+(is|was|has|can|there)|\b(there (is|are)|i couldn't find|i could not find|not found)\b"#, text) { return true }
        if matches(#"\b(check|look for|search for|find|fetch|get|pick up|take)\b.{0,50}\b(your|the|it)\b.{0,35}\b(on|under|inside|behind|beside|at)\b"#, text)
            && !matches(#"\b(could|can|might|try|place to check|possible place)\b"#, text) { return true }
        if matches(#"(كوبك|كاسك|غرضك|حقيبتك|الباب|الكوب|المفتاح|المفاتيح|الحقيبه|هو|هي|انه|انها)\s+.{0,25}(على|تحت|داخل|بجانب|خلف|امام|موجود|مفتوح|مغلق)|يوجد|توجد|ليس هناك|لا يوجد"#, text) { return true }
        return false
    }
    public static func unavailableReply(arabic: Bool) -> String {
        arabic ? "لا أستطيع تأكيد ذلك من المعلومات المتاحة. ما ذكرته سابقاً ليس تأكيداً للحالة الآن." :
            "I can't confirm that from the information available. An earlier report isn't confirmation of the current situation."
    }
}

/// Apple's string stream is cumulative. Emit only newly completed sentences;
/// never repeat a prefix and never speak an incomplete or revised claim. No model
/// metadata round-trip is required to deliver these chunks.
public struct CompanionSentenceStream: Sendable {
    private var consumed = ""
    public private(set) var delivered = ""
    public private(set) var rejected = false
    public init() {}
    public mutating func append(_ snapshot: String, final: Bool = false,
                                reports: [String], evidence: [CompanionEvidence] = [], now: Date = Date()) -> [String] {
        guard !rejected else { return [] }
        guard snapshot.hasPrefix(consumed), snapshot.split(whereSeparator: \.isWhitespace).count <= 35 else {
            rejected = true; return []
        }
        let tail = String(snapshot.dropFirst(consumed.count))
        var chunks: [String] = []
        for part in CompanionEvidenceGuard.sentenceParts(tail) {
            guard part.complete || final else { break }
            let chunk = part.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard chunk.isEmpty || CompanionEvidenceGuard.allows(delivered + " " + chunk, reports: reports, evidence: evidence, now: now) else {
                rejected = true; return chunks
            }
            consumed += part.text
            if !chunk.isEmpty { chunks.append(chunk); delivered += (delivered.isEmpty ? "" : " ") + chunk }
        }
        return chunks
    }
}
