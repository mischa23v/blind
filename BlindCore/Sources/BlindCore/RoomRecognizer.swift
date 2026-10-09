import Foundation

/// A saved home or venue near the phone's coarse location (O09 / FR-12). The caller computes
/// `distanceMetres` from CoreLocation. Distance only narrows which saved maps to try; it never
/// establishes a place, and two nearby homes stay separate identities.
public struct PlaceCandidate: Equatable, Sendable {
    public let placeID: String
    public let name: String
    public let distanceMetres: Double?
    public init(placeID: String, name: String, distanceMetres: Double? = nil) {
        self.placeID = placeID; self.name = name; self.distanceMetres = distanceMetres
    }
}

/// One independent clue about which saved room the phone is in.
public enum RoomEvidence: Equatable, Sendable {
    /// ARKit relocalised in a saved map whose room polygon contains the current pose.
    case worldMapMatched(roomID: String)
    /// 0...1 from Vision feature-print comparison against the room's saved pictures; higher is closer.
    case imageSimilarity(roomID: String, score: Double)
    /// 0...1 share of the room's saved distinctive items currently seen.
    case furnitureSignature(roomID: String, overlap: Double)
    /// The person was established in `fromRoomID` and walked across a mapped connection (door)
    /// leading to `toRoomID`; the caller checks the map's connection list and tracked movement.
    /// One supporting clue for `toRoomID`; walked movement never establishes a room alone.
    case movedThrough(fromRoomID: String, toRoomID: String)
    /// 0...1 agreement between LiDAR measurements now (room width/length, distances to walls and
    /// large furniture) and the room's saved dimensions.
    case layoutMatch(roomID: String, score: Double)
    /// The person answered "yes, this is my <room>". A semantic identity, not a measured pose.
    case userConfirmed(roomID: String)
}

public enum RoomDecision: Equatable, Sendable {
    /// Clues agree. `basis` names what supported it and any conflicting clue that was set aside.
    case established(roomID: String, basis: [String])
    /// One plausible room: ask "Is this your <room>?".
    case ask(roomID: String)
    /// Several close candidates, best first: ask which one it is.
    case askWhich([String])
    /// Nothing usable. Unresolved, which does not mean the place is new.
    case unknown
}

/// Combines independent clues the way a sighted person does (building, look of the room,
/// furniture placement, room size, the door just walked through) and treats a room as
/// established only when they agree. Clues without a world-map match never jump rooms on one
/// frame, and a failed match stays unknown rather than "new place".
/// Room identity is not arrival, heading or clearance; callers still need pose for those.
public struct RoomRecognizer: Sendable {
    /// Image similarity at or above this counts as one supporting clue.
    public static let strongImage = 0.8
    /// Furniture overlap at or above this counts as one supporting clue.
    public static let strongFurniture = 0.6
    /// LiDAR layout agreement at or above this counts as one supporting clue.
    public static let strongLayout = 0.75
    /// Image similarity below this is too weak to suggest a room at all.
    public static let weakImage = 0.5
    /// Furniture overlap below this is too weak to suggest a room at all.
    public static let weakFurniture = 0.3
    /// Layout agreement below this is too weak to suggest a room at all.
    public static let weakLayout = 0.5
    /// Ranking weight of one movement through a mapped door, on the same 0...1 scale as the scored clues.
    public static let movementScore = 1.0
    /// Rooms whose combined clue scores (image + furniture + layout + movement, 0...4) are within
    /// this margin of the leader are treated as close competitors.
    public static let competitorMargin = 0.1
    /// A gap longer than this between calls, or time moving backwards, restarts the stability count.
    public static let stableGapSeconds = 5.0
    /// Upper bound on the rooms named in one "which room is this?" question.
    public static let maxAskWhich = 3

    static let worldMapBasis = "worldMap"
    static let userBasis = "user"
    static let imageBasis = "imageSimilarity"
    static let furnitureBasis = "furnitureSignature"
    static let layoutBasis = "layoutMatch"
    static let movementBasis = "movedThrough"

    /// Consecutive calls an appearance-only decision must hold before it is returned as established.
    public let stableDecisions: Int
    private var pendingRoom: String?
    private var pendingCount = 0
    private var lastTime: Double?

    public init(stableDecisions: Int = 2) { self.stableDecisions = max(1, stableDecisions) }

    /// Candidates within `radiusMetres`, nearest first. Candidates without a usable distance are
    /// kept last in their original order, because location narrows the search and never rules a
    /// place in or out by itself.
    public static func nearbyPlaces(_ candidates: [PlaceCandidate], radiusMetres: Double = 150) -> [PlaceCandidate] {
        let limit = radiusMetres.isNaN ? 0 : max(0, radiusMetres)
        var measured: [(offset: Int, distance: Double, place: PlaceCandidate)] = []
        var unmeasured: [PlaceCandidate] = []
        for (offset, place) in candidates.enumerated() where !place.placeID.isEmpty {
            if let distance = place.distanceMetres, distance.isFinite, distance >= 0 {
                if distance <= limit { measured.append((offset: offset, distance: distance, place: place)) }
            } else {
                unmeasured.append(place)
            }
        }
        measured.sort { lhs, rhs in
            lhs.distance != rhs.distance ? lhs.distance < rhs.distance : lhs.offset < rhs.offset
        }
        return measured.map { $0.place } + unmeasured
    }

    /// Decide from the clues gathered for one moment. Precedence: the person's own confirmation,
    /// then a geometric world-map match, then two or more agreeing independent clues (image,
    /// furniture, layout, movement) held for `stableDecisions` consecutive calls. One clue asks.
    /// Conflicting strong clues are listed in `basis`.
    public mutating func decide(_ evidence: [RoomEvidence], at time: Double) -> RoomDecision {
        guard time.isFinite else { clearPending(); lastTime = nil; return .unknown }
        let continuous: Bool
        if let last = lastTime { continuous = time >= last && time - last <= Self.stableGapSeconds } else { continuous = false }
        lastTime = time
        if !continuous { clearPending() }

        let summary = Summary(evidence)
        if let user = summary.users.last {
            clearPending()
            var basis = [Self.userBasis]
            basis += summary.mapRooms.filter { $0 != user }.map { "conflict:\(Self.worldMapBasis):\($0)" }
            basis += summary.clueConflicts(excluding: user)
            return .established(roomID: user, basis: basis)
        }
        if summary.mapRooms.count > 1 {
            clearPending()
            return .askWhich(Array(summary.mapRooms.prefix(Self.maxAskWhich)))
        }
        if let mapped = summary.mapRooms.first {
            clearPending()
            var basis = [Self.worldMapBasis]
            basis += summary.clues[mapped]?.strongKinds ?? []
            basis += summary.clueConflicts(excluding: mapped)
            return .established(roomID: mapped, basis: basis)
        }
        return appearanceDecision(summary)
    }

    /// Forget the stability count, for example after a restart or venue change.
    public mutating func reset() { clearPending(); lastTime = nil }

    private mutating func appearanceDecision(_ summary: Summary) -> RoomDecision {
        let ranked = summary.clues.sorted { lhs, rhs in
            lhs.value.score != rhs.value.score ? lhs.value.score > rhs.value.score : lhs.key < rhs.key
        }
        guard let top = ranked.first else { clearPending(); return .unknown }
        // A close score, or any strong clue for another room, is a real competitor.
        let competitors = ranked.dropFirst().filter { entry in
            top.value.score - entry.value.score <= Self.competitorMargin || !entry.value.strongKinds.isEmpty
        }
        if !competitors.isEmpty {
            clearPending()
            let names = [top.key] + competitors.map { $0.key }
            return .askWhich(Array(names.prefix(Self.maxAskWhich)))
        }
        let kinds = top.value.strongKinds
        guard kinds.count >= 2 else { clearPending(); return .ask(roomID: top.key) }
        if pendingRoom == top.key {
            pendingCount = min(pendingCount + 1, stableDecisions)
        } else {
            pendingRoom = top.key; pendingCount = 1
        }
        guard pendingCount >= stableDecisions else { return .ask(roomID: top.key) }
        return .established(roomID: top.key, basis: kinds)
    }

    private mutating func clearPending() { pendingRoom = nil; pendingCount = 0 }
}

private struct RoomClues {
    var image: Double?
    var furniture: Double?
    var layout: Double?
    var moved = false
    /// Each kind counts once however many frames support it, so clues stay independent.
    var strongKinds: [String] {
        var kinds: [String] = []
        if let image, image >= RoomRecognizer.strongImage { kinds.append(RoomRecognizer.imageBasis) }
        if let furniture, furniture >= RoomRecognizer.strongFurniture { kinds.append(RoomRecognizer.furnitureBasis) }
        if let layout, layout >= RoomRecognizer.strongLayout { kinds.append(RoomRecognizer.layoutBasis) }
        if moved { kinds.append(RoomRecognizer.movementBasis) }
        return kinds
    }
    var score: Double {
        (image ?? 0) + (furniture ?? 0) + (layout ?? 0) + (moved ? RoomRecognizer.movementScore : 0)
    }
}

private struct Summary {
    var users: [String] = []
    var mapRooms: [String] = []
    var clues: [String: RoomClues] = [:]

    init(_ evidence: [RoomEvidence]) {
        for item in evidence {
            switch item {
            case .userConfirmed(let roomID):
                if !roomID.isEmpty { users.append(roomID) }
            case .worldMapMatched(let roomID):
                if !roomID.isEmpty, !mapRooms.contains(roomID) { mapRooms.append(roomID) }
            case .imageSimilarity(let roomID, let score):
                guard Summary.usable(roomID, score, floor: RoomRecognizer.weakImage) else { continue }
                var entry = clues[roomID] ?? RoomClues()
                entry.image = max(entry.image ?? 0, score)
                clues[roomID] = entry
            case .furnitureSignature(let roomID, let overlap):
                guard Summary.usable(roomID, overlap, floor: RoomRecognizer.weakFurniture) else { continue }
                var entry = clues[roomID] ?? RoomClues()
                entry.furniture = max(entry.furniture ?? 0, overlap)
                clues[roomID] = entry
            case .layoutMatch(let roomID, let score):
                guard Summary.usable(roomID, score, floor: RoomRecognizer.weakLayout) else { continue }
                var entry = clues[roomID] ?? RoomClues()
                entry.layout = max(entry.layout ?? 0, score)
                clues[roomID] = entry
            case .movedThrough(let fromRoomID, let toRoomID):
                guard !fromRoomID.isEmpty, !toRoomID.isEmpty, fromRoomID != toRoomID else { continue }
                var entry = clues[toRoomID] ?? RoomClues()
                entry.moved = true
                clues[toRoomID] = entry
            }
        }
    }

    static func usable(_ roomID: String, _ value: Double, floor: Double) -> Bool {
        !roomID.isEmpty && value.isFinite && value >= floor && value <= 1
    }

    /// Strong clues pointing at other rooms, in a stable order.
    func clueConflicts(excluding roomID: String) -> [String] {
        clues.keys.sorted().filter { $0 != roomID }.flatMap { other in
            (clues[other]?.strongKinds ?? []).map { "conflict:\($0):\(other)" }
        }
    }
}
