import Foundation

/// Selects saved ARKit maps to try. Scores are search priorities, not calibrated
/// probabilities or proof of room identity. Only the native saved-frame recovery
/// adapter can establish a coordinate frame after an attempt.
public struct RoomRecoveryCandidate: Equatable, Sendable {
    public let placeID: String
    public let roomID: String
    public let appearanceScore: Double?
    public let appearanceObservedAt: Double?
    public let distanceMetres: Double?
    public let isPreviousRoom: Bool
    public let isAdjacentRoom: Bool
    public init(placeID: String, roomID: String, appearanceScore: Double? = nil,
                appearanceObservedAt: Double? = nil, distanceMetres: Double? = nil,
                isPreviousRoom: Bool = false, isAdjacentRoom: Bool = false) {
        self.placeID = placeID; self.roomID = roomID
        self.appearanceScore = appearanceScore; self.appearanceObservedAt = appearanceObservedAt
        self.distanceMetres = distanceMetres; self.isPreviousRoom = isPreviousRoom
        self.isAdjacentRoom = isAdjacentRoom
    }
}

/// Small lifecycle adapter around existing ARKit map recovery. Never resets its
/// budget merely because another video frame or an appearance clue arrives.
/// A terminal episode stays terminal until explicit lifecycle reset/retry.
public struct RoomRecoveryCoordinator: Sendable {
    public struct Attempt: Equatable, Sendable {
        public let id: UUID
        public let placeID: String
        public let roomID: String
        public let startedAt: Double
    }
    public enum State: Equatable, Sendable {
        case waiting
        case trying(Attempt)
        case recovered(String)
        case exhausted
    }
    public private(set) var state: State = .waiting
    public private(set) var attempts = 0
    private var attempted: Set<String> = []
    private var episodeStartedAt: Double?
    private var nextAllowedAt = -Double.infinity
    private var lastNow: Double?
    private var exhaustionReported = false
    public let maximumAttempts: Int
    public let attemptTimeout: Double
    public let episodeTimeout: Double
    public let backoff: Double

    public init(maximumAttempts: Int = 3, attemptTimeout: Double = 20,
                episodeTimeout: Double = 90, backoff: Double = 3) {
        self.maximumAttempts = max(1, min(5, maximumAttempts))
        self.attemptTimeout = attemptTimeout.isFinite ? max(1, min(30, attemptTimeout)) : 20
        self.episodeTimeout = episodeTimeout.isFinite ? max(1, min(120, episodeTimeout)) : 90
        self.backoff = backoff.isFinite ? max(1, min(10, backoff)) : 3
    }

    /// Call on foreground ticks with eligible, currently existing map records.
    /// The caller must not include deleted maps or maps with corrupt provenance.
    /// Returns at most one attempt; a retry uses a different place in this episode.
    public mutating func next(candidates: [RoomRecoveryCandidate], now: Double,
                              allowNewAttempt: Bool = true) -> Attempt? {
        guard validTime(now) else { exhaust(); return nil }
        switch state {
        case .exhausted, .recovered: return nil
        default: break
        }
        if episodeStartedAt == nil { episodeStartedAt = now }
        guard let began = episodeStartedAt, now - began < episodeTimeout else { exhaust(); return nil }
        if case .trying(let current) = state {
            // A removed map cannot finish through a later callback.
            if !candidates.contains(where: { $0.placeID == current.placeID }) || now - current.startedAt >= attemptTimeout {
                state = .waiting; nextAllowedAt = now + backoff
            } else { return nil }
        }
        guard attempts < maximumAttempts else { exhaust(); return nil }
        // Requested reading/conversation wins. Deferral does not extend episode deadlines.
        guard allowNewAttempt else { return nil }
        guard now >= nextAllowedAt else { return nil }
        let ranked = Self.rank(candidates, now: now).filter { !attempted.contains($0.placeID) }
        guard let candidate = ranked.first else { return nil }
        let attempt = Attempt(id: UUID(), placeID: candidate.placeID,
                              roomID: candidate.roomID, startedAt: now)
        attempted.insert(candidate.placeID); attempts += 1; state = .trying(attempt)
        return attempt
    }

    /// Called only after the existing native adapter confirmed the SAME saved
    /// world-map descriptor, session and anchor. It does not authorize movement.
    @discardableResult public mutating func recovered(attemptID: UUID, placeID: String,
        frameVerified: Bool, now: Double) -> Bool {
        guard validTime(now), frameVerified, case .trying(let attempt) = state,
              attempt.id == attemptID, attempt.placeID == placeID,
              now - attempt.startedAt < attemptTimeout,
              let began = episodeStartedAt, now - began < episodeTimeout else { return false }
        state = .recovered(placeID); return true
    }

    public mutating func failed(attemptID: UUID, now: Double) {
        guard validTime(now) else { exhaust(); return }
        guard case .trying(let attempt) = state, attempt.id == attemptID else { return }
        state = .waiting; nextAllowedAt = now + backoff
        if attempts >= maximumAttempts { exhaust() }
    }

    /// One useful uncertainty notice, not a prompt on every frame. Normal visual
    /// and conversational assistance may continue while spatial recovery is unavailable.
    public mutating func takeExhaustionNotice() -> Bool {
        guard state == .exhausted, !exhaustionReported else { return false }
        exhaustionReported = true; return true
    }

    /// Explicit foreground session restart, user retry, or deliberately started
    /// new recovery episode. Never invoke per frame or per model response.
    public mutating func reset() {
        state = .waiting; attempts = 0; attempted.removeAll()
        episodeStartedAt = nil; nextAllowedAt = -.infinity; lastNow = nil
        exhaustionReported = false
    }

    /// Appearance outranks coarse GPS; adjacency and previous room are only
    /// tie-breaking priors. Similar rooms may both be tried but neither is declared
    /// identified by ranking. No usable clue means no blind map reset.
    public static func rank(_ candidates: [RoomRecoveryCandidate], now: Double) -> [RoomRecoveryCandidate] {
        guard now.isFinite else { return [] }
        var best: [String: (RoomRecoveryCandidate, Double)] = [:]
        for candidate in candidates.prefix(128) {
            guard !candidate.placeID.isEmpty, !candidate.roomID.isEmpty,
                  candidate.placeID.utf8.count <= 256, candidate.roomID.utf8.count <= 256 else { continue }
            var score = 0.0
            if let appearance = candidate.appearanceScore, let at = candidate.appearanceObservedAt,
               appearance.isFinite, (0.5...1).contains(appearance), at.isFinite, at <= now, now - at <= 5 {
                score += 10 + appearance
            }
            if let distance = candidate.distanceMetres, distance.isFinite, (0...150).contains(distance) {
                score += 1 + (150 - distance) / 150
            }
            // A semantic previous room or adjacency alone is not enough to restart
            // tracking: only use these priors once appearance/location supports a try.
            guard score > 0 else { continue }
            if candidate.isPreviousRoom { score += 0.2 }
            if candidate.isAdjacentRoom { score += 0.1 }
            if best[candidate.placeID].map({ $0.1 >= score }) != true {
                best[candidate.placeID] = (candidate, score)
            }
        }
        return best.values.sorted {
            $0.1 != $1.1 ? $0.1 > $1.1 : $0.0.placeID < $1.0.placeID
        }.map(\.0)
    }

    private mutating func validTime(_ now: Double) -> Bool {
        guard now.isFinite, lastNow.map({ now >= $0 }) ?? true else { return false }
        lastNow = now; return true
    }
    private mutating func exhaust() { state = .exhausted }
}
