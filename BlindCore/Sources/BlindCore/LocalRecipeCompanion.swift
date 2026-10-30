import Foundation

/// Closed command syntax, not intent inference or speaker authentication.
/// The caller must retain the trusted-interface boundary; microphone/model/
/// observed content cannot read or mutate this private selected reference.
public enum LocalRecipeCommand: Equatable, Sendable {
    case readStep, nextStep, previousStep, startTimer, timerStatus, cancelTimer, forget

    public static func parse(_ raw: String) -> Self? {
        guard raw.utf8.count <= 200 else { return nil }
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let end = text.last, ".!?؟".contains(end) { text.removeLast() }
        if text.hasPrefix("please ") { text = String(text.dropFirst(7)) }
        else if text.hasPrefix("من فضلك ") { text = String(text.dropFirst("من فضلك ".count)) }
        let commands: [(Self, [String])] = [
            (.readStep, ["read recipe step", "read the recipe step", "اقرأ خطوة الوصفة", "اقرا خطوة الوصفة"]),
            (.nextStep, ["next recipe step", "الخطوة التالية في الوصفة"]),
            (.previousStep, ["previous recipe step", "الخطوة السابقة في الوصفة"]),
            (.startTimer, ["start recipe timer", "ابدأ مؤقت الوصفة", "ابدا مؤقت الوصفة"]),
            (.timerStatus, ["recipe timer status", "حالة مؤقت الوصفة"]),
            (.cancelTimer, ["cancel recipe timer", "ألغ مؤقت الوصفة", "الغ مؤقت الوصفة"]),
            (.forget, ["forget recipe", "stop recipe", "انس الوصفة", "أوقف الوصفة", "اوقف الوصفة"])
        ]
        return commands.first { $0.1.contains(text) }?.0
    }
}

/// Volatile adapter over LocalRecipeSession; no persistence, generated recipe,
/// background alarm, external action or food/handling completion authority.
public struct LocalRecipeCompanion: Sendable {
    public struct Selection: Equatable, Sendable {
        public let id: UUID
        public let revision: UUID
        public let sha256: String
        public let generation: UInt64
    }
    public struct Response: Equatable, Sendable {
        public let id: UUID
        public let selection: Selection
        public let parts: [String]
        public let issuedAt: Double
    }
    public static let responseLifetime: Double = 60
    public private(set) var selection: Selection?
    public private(set) var session: LocalRecipeSession?
    public private(set) var enabled = false
    public private(set) var response: Response?
    public init() {}

    @discardableResult public mutating func select(_ recipe: LocalRecipeReference,
        sha256: String, generation: UInt64, origin: CompanionCommandOrigin) -> Selection? {
        guard origin == .trustedInterface else { return nil }
        clear()
        guard sha256.utf8.count == 64, sha256.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else { return nil }
        let value = Selection(id: UUID(), revision: UUID(), sha256: sha256, generation: generation)
        selection = value; session = LocalRecipeSession(recipe: recipe)
        return value
    }
    @discardableResult public mutating func enable(_ selected: Selection,
        generation: UInt64, origin: CompanionCommandOrigin) -> Bool {
        guard origin == .trustedInterface, selection == selected,
              selected.generation == generation, session != nil else { return false }
        enabled = true; return true
    }
    public mutating func retireResponse() { response = nil }
    public mutating func cancelTimer() { response = nil; session?.cancelTimer() }
    public mutating func tick(uptime: Double) { session?.tick(uptime: uptime) }
    public mutating func clear() { self = Self() }

    /// All commands use the exact selected revision and original session owner.
    /// Caller-controlled `readerControl` is only for the explicit helper buttons,
    /// not a model/tool argument or permission granted to microphone input.
    @discardableResult public mutating func execute(_ command: LocalRecipeCommand,
        selection selected: Selection, generation: UInt64, origin: CompanionCommandOrigin,
        uptime: Double, arabic: Bool = false, readerControl: Bool = false) -> Response? {
        guard origin == .trustedInterface, selection == selected,
              selected.generation == generation, enabled || readerControl,
              uptime.isFinite, uptime >= 0, var current = session else { return nil }
        response = nil
        if command == .forget { clear(); return nil }
        current.tick(uptime: uptime)
        func t(_ en: String, _ ar: String) -> String { arabic ? ar : en }
        var parts: [String] = []
        var shouldRead = false
        switch command {
        case .readStep: shouldRead = true
        case .nextStep, .previousStep:
            if current.move(by: command == .nextStep ? 1 : -1) { shouldRead = true }
            else { parts = [t("That is already the first or last source step. No cooking completion is recorded.", "هذه أول خطوة أو آخر خطوة في المصدر. لم يتم تسجيل إتمام الطهي.")] }
        case .startTimer:
            let started = current.startTimer(uptime: uptime)
            parts = [started
                ? t("Source timer started for \(current.step.timerSeconds ?? 0) seconds. No background alarm; this does not check food safety.", "بدأ مؤقت المصدر لمدة \(current.step.timerSeconds ?? 0) ثانية. لا يوجد تنبيه في الخلفية ولا تحقق من سلامة الطعام.")
                : t("Timer not started: it is already running, this source step has no duration, or the clock is unavailable.", "لم يبدأ المؤقت: هو جار بالفعل، أو لا توجد مدة لهذه الخطوة، أو الساعة غير متاحة.")]
        case .timerStatus:
            switch current.timerState {
            case .running: parts = [t("Timer reading when requested: \(current.remainingSeconds ?? 0) seconds remaining. This is not a food-readiness check.", "قراءة المؤقت عند الطلب: تبقى \(current.remainingSeconds ?? 0) ثانية. هذا ليس تحققاً من نضج الطعام.")]
            case .elapsed: parts = [t("Timer elapsed. This does not establish that food is ready.", "انتهت مدة المؤقت. هذا لا يؤكد أن الطعام جاهز.")]
            case .idle: parts = [t("No recipe timer has been started.", "لم يبدأ مؤقت للوصفة.")]
            case .cancelled: parts = [t("Recipe timer cancelled. No alarm will occur.", "تم إلغاء مؤقت الوصفة. لن يصدر تنبيه.")]
            case .invalidClock: parts = [t("Recipe timer unavailable after a clock discontinuity. Start it again explicitly.", "المؤقت غير متاح بعد تغير الساعة. ابدأه مجدداً صراحةً.")]
            }
        case .cancelTimer:
            current.cancelTimer()
            parts = [t("Recipe timer cancelled. No alarm will occur.", "تم إلغاء مؤقت الوصفة. لن يصدر تنبيه.")]
        case .forget: break
        }
        if shouldRead {
            let prefix = t("Selected recipe step \(current.stepIndex + 1), unverified source text: «", "خطوة الوصفة المختارة \(current.stepIndex + 1)، نص مصدر غير مؤكد: «")
            guard let plan = BoundedReferenceChunkPlan.make(text: current.step.text, prefix: prefix,
                maximumUTF8Bytes: 4000, phraseWordLimit: 30) else { session = current; return nil }
            parts = plan.map(\.attributed)
        }
        session = current
        guard !parts.isEmpty else { return nil }
        let value = Response(id: UUID(), selection: selected, parts: parts, issuedAt: uptime)
        response = value; return value
    }
    public func validates(_ candidate: Response, generation: UInt64, uptime: Double) -> Bool {
        candidate == response && candidate.selection == selection && session != nil &&
        candidate.selection.generation == generation && uptime.isFinite &&
        uptime >= candidate.issuedAt && uptime - candidate.issuedAt < Self.responseLifetime
    }
}
