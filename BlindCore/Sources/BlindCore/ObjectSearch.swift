import Foundation

/// A live search for one requested object, with an explicit result (2026-10-22). Sensors decide:
/// each attempt is a Vision/detector look at a fresh frame, and a found object's position comes
/// from depth. When the time runs out the result is "not located", which is never spoken as
/// "it isn't here". A generic detector label is "a cup", never "your cup"; only image comparison
/// with the person's saved views establishes identity. Times are phone monotonic seconds.
public struct ObjectSearch: Equatable, Sendable {
    public enum Outcome: Equatable, Sendable {
        case searching
        case found(label: String)
        case notLocated
        case cancelled
    }
    public static let duration = 20.0
    public static let interval = 0.5

    public let target: String
    public let startedAt: Double
    public private(set) var lastAttempt = -Double.infinity
    public private(set) var attempts = 0
    public private(set) var outcome: Outcome = .searching
    /// True once the uncertain model hint has been tried, so it is offered at most once.
    public var hintTried = false

    public init(target: String, now: Double) {
        self.target = target.trimmingCharacters(in: .whitespacesAndNewlines)
        startedAt = now
    }

    public var active: Bool { outcome == .searching }

    /// Whether another sensor look is due. False once the search ended.
    public func due(now: Double) -> Bool {
        active && now.isFinite && now - lastAttempt >= Self.interval
    }

    /// Records one look. A label means the sensors located the object; otherwise the search ends as
    /// "not located" when the time is up.
    @discardableResult
    public mutating func attempted(now: Double, found label: String?) -> Outcome {
        guard active else { return outcome }
        lastAttempt = now; attempts += 1
        if let label, !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { outcome = .found(label: label) }
        else if now - startedAt >= Self.duration { outcome = .notLocated }
        return outcome
    }

    public mutating func cancel() { if active { outcome = .cancelled } }

    public static func started(target: String, arabic: Bool) -> String {
        let name = CompanionNaming.phrase(target, arabic: arabic)
        return arabic ? "أبحث عن \(name). استدر ببطء." : "Looking for \(name). Turn slowly."
    }

    public static func notLocated(target: String, arabic: Bool) -> String {
        let name = CompanionNaming.phrase(target, arabic: arabic)
        return arabic ? "لم أجد \(name) فيما رأته الكاميرا. هذا لا يعني أنه غير موجود."
            : "I haven't located \(name) in what the camera saw. That doesn't mean it isn't nearby."
    }

    /// The camera recognised something matching the target but depth could not measure it
    /// (too far, glass, black). Spoken by code; no distance or direction is invented.
    public static func seenWithoutDepth(label: String, arabic: Bool) -> String {
        arabic ? "أرى \(label) في صورة الكاميرا، لكن لا أستطيع قياس بعده."
            : "I can see \(CompanionNaming.generic(label, arabic: false)) in the camera view, but I can't measure how far it is."
    }

    /// Uncertain hint from the image model, rendered by code. Hazards get no direction (spatial rule).
    public static func hint(target: String, side: String?, arabic: Bool) -> String {
        let name = CompanionNaming.generic(target, arabic: arabic)
        let sides = arabic ? ["left": "على يسار الصورة", "centre": "في وسط الصورة", "right": "على يمين الصورة"]
            : ["left": "on the left of the camera view", "centre": "in the middle of the camera view", "right": "on the right of the camera view"]
        var place = side.flatMap { sides[$0] } ?? ""
        if !place.isEmpty, SpatialClaimGuard.containsSpatialClaim("\(name) \(sides["left"] ?? "")") { place = "" }
        if arabic {
            return "ربما أرى شيئاً يشبه \(name)\(place.isEmpty ? "" : " \(place)"). لست متأكداً؛ سأستمر في التحقق."
        }
        return "I might see something like \(name)\(place.isEmpty ? "" : " \(place)"). I'm not sure; I'll keep checking."
    }
}

/// The last search result, kept so later questions are answered from it, not guessed.
public struct SearchRecord: Codable, Equatable, Sendable {
    public let target: String
    public let key: String
    public let located: Bool
    public let at: Date
    public init(target: String, located: Bool, at: Date = Date()) {
        self.target = target; key = ItemMemory.key(for: target); self.located = located; self.at = at
    }

    public func matches(_ object: String) -> Bool {
        let other = ItemMemory.key(for: object)
        guard !other.isEmpty else { return false }
        let a = key.split(separator: " ").map(String.init), b = other.split(separator: " ").map(String.init)
        return key == other || ItemMemory.containsRun(a, b) || ItemMemory.containsRun(b, a)
    }

    /// "I looked 3 minutes ago and didn't locate your cup." Located results were spoken with their
    /// measurement at the time and are reported only as having been seen then.
    public func sentence(now: Date, arabic: Bool) -> String {
        let elapsed = ItemMemory.relativeTime(from: at, to: now, arabic: arabic)
        if arabic {
            let name = CompanionNaming.phrase(target, arabic: true)
            return located ? "رأت الكاميرا شيئاً يشبه \(name) \(elapsed). قد يكون تحرك." : "بحثت \(elapsed) ولم أجد \(name)."
        }
        return located ? "The camera saw something like \(CompanionNaming.generic(target, arabic: false)) \(elapsed). It may have moved since."
            : "I looked \(elapsed) and didn't locate \(CompanionNaming.phrase(target, arabic: false))."
    }
}
