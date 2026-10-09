import Foundation

public struct SceneObservation: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case text, people, object, range }
    public var id: String
    public var kind: Kind
    public var text: String
    public var confidence: Double
    public var capturedAt: Double
    public var direction: String?
    public init(id: String, kind: Kind, text: String, confidence: Double, capturedAt: Double, direction: String? = nil) {
        self.id = id; self.kind = kind; self.text = text; self.confidence = confidence
        self.capturedAt = capturedAt; self.direction = direction
    }
}

/// Only selected, fresh evidence enters the language layer. Times are phone monotonic seconds.
public struct SceneContext: Codable, Sendable {
    public let version: Int
    public let language: String
    public let detail: String
    public let motion: String
    public let monitoring: String
    public let requested: Bool
    public let observations: [SceneObservation]
    public init(observations: [SceneObservation], at now: Double, arabic: Bool,
                detail: DetailLevel, stationary: Bool, hazard: Hazard, requested: Bool) {
        version = 1; language = arabic ? "ar" : "en"; self.detail = detail.rawValue
        motion = stationary ? "stationary" : "moving"; monitoring = hazard.rawValue; self.requested = requested
        let budget = detail == .minimal ? 1 : detail == .balanced ? 3 : 5
        let eligible = now.isFinite && hazard == .observing
        let ranking: [SceneObservation.Kind: Int] = [.range: 0, .text: 1, .people: 2, .object: 3]
        var seen = Set<String>()
        var rangeCount = 0
        self.observations = eligible ? Array(observations.filter {
            !$0.id.isEmpty && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            $0.capturedAt.isFinite && now >= $0.capturedAt && now - $0.capturedAt <= ($0.kind == .range ? 0.8 : 3) &&
            $0.confidence.isFinite && $0.confidence >= ($0.kind == .object ? 0.7 : 0.6) && $0.confidence <= 1 &&
            seen.insert($0.id).inserted
        }.filter { observation in
            guard observation.kind == .range else { return true }
            rangeCount += 1; return rangeCount <= 2 // Leave room for camera evidence at larger detail budgets.
        }.sorted {
            if ranking[$0.kind] == ranking[$1.kind] { return $0.confidence > $1.confidence }
            return ranking[$0.kind, default: 9] < ranking[$1.kind, default: 9]
        }.prefix(budget)).map {
            var value = $0; value.text = String(value.text.prefix(detail == .detailed ? 240 : 120)); return value
        } : []
    }
    public var fallback: String {
        observations.map { item in
            switch item.kind {
            case .text: return language == "ar" ? "نص مقروء: «\(item.text)»." : "Text reads: ‘\(item.text)’."
            case .people: return language == "ar" ? "أشخاص مرصودون: \(item.text)." : "People observed: \(item.text)."
            case .object: return language == "ar" ? "تصنيف محتمل للمشهد: \(item.text)." : "Possible scene category: \(item.text)."
            case .range: return item.text
            }
        }.joined(separator: " ")
    }
    public func json() throws -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return String(decoding: try encoder.encode(self), as: UTF8.self)
    }
    /// The local LLM may select evidence IDs; it cannot invent the words spoken as observations.
    public func rendering(ids: [String]) -> String {
        let known = Dictionary(uniqueKeysWithValues: observations.map { ($0.id, $0) })
        var seen = Set<String>()
        let selected = ids.compactMap { seen.insert($0).inserted ? known[$0] : nil }
        guard !selected.isEmpty else { return fallback }
        // Preserve the deterministic priority order even if the model suggests a different one.
        let allowed = Set(selected.map(\.id))
        return SceneContext(version: version, language: language, detail: detail, motion: motion,
                            monitoring: monitoring, requested: requested, observations: observations.filter { allowed.contains($0.id) }).fallback
    }
    private init(version: Int, language: String, detail: String, motion: String, monitoring: String,
                 requested: Bool, observations: [SceneObservation]) {
        self.version = version; self.language = language; self.detail = detail; self.motion = motion
        self.monitoring = monitoring; self.requested = requested; self.observations = observations
    }
}

public enum SceneDelivery {
    public static func allowed(capturedAt: Double, now: Double, origin: Point3, current: Point3?,
                               currentFrameAt: Double, hazard: Hazard, tracking: Bool,
                               originForward: Point3, currentForward: Point3?) -> Bool {
        guard capturedAt.isFinite, now.isFinite, currentFrameAt.isFinite, origin.isFinite,
              let current, current.isFinite, tracking, hazard == .observing,
              let currentForward, originForward.isFinite, currentForward.isFinite else { return false }
        let firstLength = hypot(originForward.x, originForward.z), lastLength = hypot(currentForward.x, currentForward.z)
        guard firstLength > 0.9, firstLength < 1.1, lastLength > 0.9, lastLength < 1.1,
              (originForward.x * currentForward.x + originForward.z * currentForward.z) / (firstLength * lastLength) >= cos(.pi / 6) else { return false }
        return now >= capturedAt && now - capturedAt <= 12 && now >= currentFrameAt &&
            now - currentFrameAt <= 0.5 && origin.distance(to: current) <= 0.5
    }
}
