import Foundation

/// Coarse familiar-room change detection (FR-05 / V08, first version).
/// In a familiar room the assistant stays quiet unless something relevant changed, the way a
/// sighted companion notices a newcomer or a chair in the usual path rather than every object.
/// A claim of change needs comparable coverage, so snapshots are compared only within the same
/// room and coarse view sector, and a change must persist for several consecutive snapshots
/// before it is reported. Absence from view is never described as someone leaving, and a
/// missing sign is not reported at all, because occlusion and viewpoint explain both.
/// This is not the hazard path: urgent obstacles come from the sensor hazard detector and never
/// wait for this confirmation. The phrases here carry no distance or direction; the sensors
/// supply position.

/// One coarse summary of what the camera currently sees from a known room and heading bucket.
public struct SceneSnapshot: Equatable, Sendable {
    public var room: String
    /// Coarse heading bucket supplied by the caller, e.g. 0...7 for eight 45° sectors.
    public var viewSector: Int
    public var peopleCount: Int
    /// Readable sign text as recognised; normalised by the detector.
    public var texts: [String]
    public var obstacleInUsualPath: Bool
    /// Phone monotonic seconds.
    public var at: Double
    public init(room: String, viewSector: Int, peopleCount: Int, texts: [String] = [],
                obstacleInUsualPath: Bool = false, at: Double) {
        self.room = room; self.viewSector = viewSector; self.peopleCount = peopleCount
        self.texts = texts; self.obstacleInUsualPath = obstacleInUsualPath; self.at = at
    }
}

public enum DetectedChange: Equatable, Sendable {
    case peopleArrived(Int)
    case peopleNoLongerInView(Int)
    /// Display text with whitespace collapsed; the comparison itself uses normalised text.
    case newText(String)
    case obstacleInUsualPath
}

public struct SceneChangeDetector: Sendable {
    public static let maximumTextsPerSnapshot = 32
    public static let minimumTextLength = 3
    public static let displayTextLimit = 80
    static let occurrenceLimit = 512

    /// Consecutive comparable snapshots a change must persist for before it is reported.
    public let confirmations: Int
    /// A longer gap between snapshots of the same view starts a fresh streak; earlier frames
    /// are too old to count as consecutive evidence.
    public let maximumGap: Double

    private struct Streak: Sendable { var value: Int; var count: Int }
    private struct TextStreak: Sendable { var display: String; var count: Int }
    private struct ViewKey: Hashable, Sendable { let room: String; let sector: Int }
    private struct Baseline: Sendable {
        var people: Int
        var texts: Set<String>
        var obstacle: Bool
        var lastAt: Double
        var pendingPeople: Streak?
        var pendingTexts: [String: TextStreak] = [:]
        /// Consecutive snapshots whose obstacle state differs from the baseline.
        var pendingObstacle = 0
    }

    private var baselines: [ViewKey: Baseline] = [:]
    /// How many times each change key has been confirmed, so a genuine recurrence (an obstacle
    /// that was cleared and later returns) gets a new revision while a re-proposed candidate
    /// for the same occurrence keeps its revision.
    private var occurrences: [String: Int] = [:]

    public init(confirmations: Int = 3, maximumGap: Double = 5) {
        self.confirmations = max(1, confirmations)
        self.maximumGap = maximumGap.isFinite && maximumGap > 0 ? maximumGap : 5
    }

    /// Returns confirmed changes for this snapshot's view, each reported once.
    /// The first snapshot of a (room, viewSector) only learns the baseline.
    /// Invalid snapshots (empty room, negative count, non-finite time) are ignored entirely.
    public mutating func observe(_ snapshot: SceneSnapshot) -> [DetectedChange] {
        let room = snapshot.room.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !room.isEmpty, snapshot.peopleCount >= 0, snapshot.at.isFinite else { return [] }
        let key = ViewKey(room: room, sector: snapshot.viewSector)
        let texts = Self.readableTexts(snapshot.texts)

        guard var baseline = baselines[key] else {
            baselines[key] = Baseline(people: snapshot.peopleCount, texts: Set(texts.keys),
                                      obstacle: snapshot.obstacleInUsualPath, lastAt: snapshot.at)
            return []
        }
        // Time going backwards or a long gap breaks the streak; this frame starts a new one.
        if snapshot.at < baseline.lastAt || snapshot.at - baseline.lastAt > maximumGap {
            baseline.pendingPeople = nil; baseline.pendingTexts = [:]; baseline.pendingObstacle = 0
        }
        baseline.lastAt = snapshot.at
        var changes: [DetectedChange] = []

        // Obstacle in the usual path. Only its appearance is reported; a confirmed absence
        // quietly resets the baseline so a later return can be noticed. Absence is never
        // described as a clear path.
        if snapshot.obstacleInUsualPath != baseline.obstacle {
            baseline.pendingObstacle += 1
            if baseline.pendingObstacle >= confirmations {
                baseline.obstacle = snapshot.obstacleInUsualPath
                baseline.pendingObstacle = 0
                if baseline.obstacle { changes.append(.obstacleInUsualPath) }
            }
        } else {
            baseline.pendingObstacle = 0
        }

        // People: the same new count must persist; a fluctuating count restarts the streak.
        if snapshot.peopleCount == baseline.people {
            baseline.pendingPeople = nil
        } else {
            var streak = baseline.pendingPeople ?? Streak(value: snapshot.peopleCount, count: 0)
            if streak.value != snapshot.peopleCount { streak = Streak(value: snapshot.peopleCount, count: 0) }
            streak.count += 1
            if streak.count >= confirmations {
                let difference = snapshot.peopleCount - baseline.people
                changes.append(difference > 0 ? .peopleArrived(difference) : .peopleNoLongerInView(-difference))
                baseline.people = snapshot.peopleCount
                baseline.pendingPeople = nil
            } else {
                baseline.pendingPeople = streak
            }
        }

        // Signs: only additions are reported. A sign missing from this frame is not evidence
        // that it was removed, so it stays in the baseline.
        var pending: [String: TextStreak] = [:]
        var confirmedTexts: [(normalized: String, display: String)] = []
        for (normalized, display) in texts where !baseline.texts.contains(normalized) {
            let count = (baseline.pendingTexts[normalized]?.count ?? 0) + 1
            if count >= confirmations {
                confirmedTexts.append((normalized: normalized, display: display))
            } else {
                pending[normalized] = TextStreak(display: display, count: count)
            }
        }
        baseline.pendingTexts = pending
        for item in confirmedTexts.sorted(by: { $0.normalized < $1.normalized }) {
            baseline.texts.insert(item.normalized)
            changes.append(.newText(item.display))
        }

        baselines[key] = baseline
        for change in changes {
            let changeKey = Self.key(for: change, room: room)
            if occurrences.count >= Self.occurrenceLimit { occurrences.removeAll(keepingCapacity: true) }
            occurrences[changeKey, default: 0] += 1
        }
        return changes
    }

    /// Forgets every learned view of a room, e.g. after the person removes it from memory.
    public mutating func forgetRoom(_ room: String) {
        let id = room.trimmingCharacters(in: .whitespacesAndNewlines)
        baselines = baselines.filter { $0.key.room != id }
    }

    /// Speech candidates for confirmed changes. People and signs are ordinary change items;
    /// an obstacle in the usual path is goal-relevant. Expires ten seconds after `at`.
    public func candidates(for changes: [DetectedChange], room: String, at: Double, arabic: Bool) -> [InformationCandidate] {
        let room = room.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !room.isEmpty, at.isFinite else { return [] }
        return changes.compactMap { (change: DetectedChange) -> InformationCandidate? in
            let key = Self.key(for: change, room: room)
            let text = Self.phrase(for: change, arabic: arabic)
            let words = text.split(whereSeparator: { $0.isWhitespace }).count
            guard words > 0 else { return nil }
            let revision = "\(Self.detail(for: change))#\(occurrences[key] ?? 1)"
            let category: String?
            switch change {
            case .peopleArrived, .peopleNoLongerInView: category = "social"
            case .newText: category = "signs"
            case .obstacleInUsualPath: category = nil
            }
            var goalRelevant = false
            if case .obstacleInUsualPath = change { goalRelevant = true }
            return InformationCandidate(key: key, kind: .change, text: text, words: words, revision: revision,
                                        createdAt: at, expiresAt: at + 10, category: category,
                                        goalRelevant: goalRelevant, room: room)
        }
    }

    // MARK: - Helpers

    /// Case, width, diacritic and Arabic letter-form folding with collapsed whitespace.
    static func normalize(_ text: String) -> String {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                                  locale: Locale(identifier: "en_US_POSIX"))
        return SpatialClaimGuard.normalizeArabic(folded)
            .split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    static func display(_ text: String) -> String {
        String(text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ").prefix(displayTextLimit))
    }

    /// Normalised text to display text, ignoring short fragments and duplicates.
    static func readableTexts(_ texts: [String]) -> [String: String] {
        var result: [String: String] = [:]
        for raw in texts.prefix(maximumTextsPerSnapshot) {
            let normalized = normalize(raw)
            guard normalized.count >= minimumTextLength, result[normalized] == nil else { continue }
            result[normalized] = display(raw)
        }
        return result
    }

    static func kindName(for change: DetectedChange) -> String {
        switch change {
        case .peopleArrived: return "peopleArrived"
        case .peopleNoLongerInView: return "peopleNoLongerInView"
        case .newText: return "newText"
        case .obstacleInUsualPath: return "obstacleInUsualPath"
        }
    }

    static func detail(for change: DetectedChange) -> String {
        switch change {
        case .peopleArrived(let count), .peopleNoLongerInView(let count): return String(count)
        case .newText(let text): return normalize(text)
        case .obstacleInUsualPath: return "usualPath"
        }
    }

    /// Stable key "change:<room>:<kind>:<detail>".
    static func key(for change: DetectedChange, room: String) -> String {
        "change:\(room):\(kindName(for: change)):\(detail(for: change))"
    }

    static func phrase(for change: DetectedChange, arabic: Bool) -> String {
        switch change {
        case .peopleArrived(let count):
            if count <= 1 { return arabic ? "يوجد شخص جديد هنا." : "Someone new is here." }
            return arabic ? "عدد الأشخاص الجدد هنا: \(count)." : "\(count) new people are here."
        case .peopleNoLongerInView(let count):
            if count <= 1 { return arabic ? "شخص واحد لم يعد في مجال الرؤية." : "One person is no longer in view." }
            return arabic ? "عدد الأشخاص الذين لم يعودوا في مجال الرؤية: \(count)." : "\(count) people are no longer in view."
        case .newText(let text):
            return arabic ? "لافتة جديدة: «\(text)»." : "New sign: \(text)."
        case .obstacleInUsualPath:
            return arabic ? "يوجد شيء في مسارك المعتاد." : "Something is in your usual path."
        }
    }
}
