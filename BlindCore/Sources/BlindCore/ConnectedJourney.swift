import Foundation

/// Durable context is knowledge, not the person's current location.
public struct JourneyContext: Codable, Equatable, Sendable {
    public let worldID: String
    public let placeID: String
    public let buildingID: String
    public let floorID: String
    public let roomID: String?
}

public struct JourneyEndpoint: Codable, Equatable, Hashable, Sendable {
    public let binding: SpatialMapBinding
    public let floorID: String
    public let nodeID: String
    public let roomID: String?
    public init(binding: SpatialMapBinding, floorID: String, nodeID: String, roomID: String? = nil) {
        self.binding = binding; self.floorID = floorID; self.nodeID = nodeID; self.roomID = roomID
    }
}

/// Exact endpoint/digest ownership. This does not store a live pose, session clock,
/// heading, clearance or a route that may be replayed after process/camera restart.
public struct JourneyReference: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case journeyStart, savedReference, mappedDestination }
    public let id: UUID
    public let kind: Kind
    public let endpoint: JourneyEndpoint
    public let context: JourneyContext
    public let artifactSHA256: String
    public let recordedAt: Date
    /// Observation provenance only. A saved capture ID cannot reauthorize a pose.
    public let historicalCaptureID: UUID?
}

public struct JourneyGoal: Codable, Equatable, Sendable {
    public enum Purpose: String, Codable, Sendable { case destination, returnToReference, returnToStart }
    public enum Status: String, Codable, Sendable { case active, paused, arrived, cancelled }
    public let revision: UUID
    public let target: JourneyReference
    public let purpose: Purpose
    public var status: Status
}

public struct JourneyEvent: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case started, referenceSaved, goalChanged, reachedNode, portalEndpointsAssociated, arrived, cancelled
    }
    public let sequence: UInt64
    public let kind: Kind
    public let recordedAt: Date
    public let endpoint: JourneyEndpoint?
    public let goalRevision: UUID?
    public let portalID: String?
    public let historicalCaptureID: UUID?
    public let portalDepartureCaptureID: UUID?
    public let portalDepartureRecordedAt: Date?
}

/// Bounded Foundation JSON payload. Private, local-only and excluded from backup
/// by the platform store. It is not a new database or a replacement for GRDB.
public struct ConnectedJourneySnapshot: Codable, Equatable, Sendable {
    public static let maximumEvents = 256
    public static let maximumReferences = 64
    public static let maximumBytes = 512_000
    public let schemaVersion: Int
    public let id: UUID
    public var start: JourneyReference?
    public var references: [JourneyReference]
    public var preferredReferenceID: UUID?
    public var goal: JourneyGoal?
    public var returnClarificationPending: Bool
    public var events: [JourneyEvent]
    public var nextSequence: UInt64
    public var droppedEventCount: UInt64
    public init(id: UUID = UUID()) {
        schemaVersion = 1; self.id = id; references = []; events = []
        returnClarificationPending = false; nextSequence = 0; droppedEventCount = 0
    }
    public init(data: Data) throws {
        guard !data.isEmpty, data.count <= Self.maximumBytes else { throw ConnectedJourneyError.invalidHistory }
        self = try JSONDecoder().decode(Self.self, from: data)
        try validate()
    }
    public func encoded() throws -> Data {
        try validate()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(self)
        guard data.count <= Self.maximumBytes else { throw ConnectedJourneyError.invalidHistory }
        return data
    }
    public func validate() throws {
        guard schemaVersion == 1, references.count <= Self.maximumReferences,
              events.count <= Self.maximumEvents, Set(references.map(\.id)).count == references.count,
              preferredReferenceID.map({ id in references.contains { $0.id == id } }) ?? true,
              start.map({ $0.kind == .journeyStart }) ?? true,
              references.allSatisfy({ $0.kind == .savedReference }),
              events.allSatisfy({ event in
                  event.recordedAt.timeIntervalSince1970.isFinite && event.sequence < nextSequence &&
                  (event.kind != .portalEndpointsAssociated ||
                    (event.portalID.map(Self.validID) == true && event.historicalCaptureID != nil &&
                     event.portalDepartureCaptureID != nil && event.portalDepartureRecordedAt?.timeIntervalSince1970.isFinite == true))
              }),
              zip(events, events.dropFirst()).allSatisfy({ $0.sequence < $1.sequence }) else {
            throw ConnectedJourneyError.invalidHistory
        }
        if let goal {
            switch goal.purpose {
            case .destination:
                guard goal.target.kind == .mappedDestination else { throw ConnectedJourneyError.invalidHistory }
            case .returnToStart:
                guard goal.target.kind == .journeyStart, start == goal.target else { throw ConnectedJourneyError.invalidHistory }
            case .returnToReference:
                guard goal.target.kind == .savedReference, references.contains(goal.target) else { throw ConnectedJourneyError.invalidHistory }
            }
        }
        for reference in references + [start, goal?.target].compactMap({ $0 }) {
            let e = reference.endpoint, c = reference.context
            guard reference.recordedAt.timeIntervalSince1970.isFinite,
                  reference.artifactSHA256.utf8.count == 64,
                  reference.artifactSHA256.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }),
                  [e.binding.mapID, e.binding.frameID, e.binding.revision, e.floorID, e.nodeID,
                   c.worldID, c.placeID, c.buildingID, c.floorID].allSatisfy(Self.validID),
                  e.roomID.map(Self.validID) ?? true,
                  e.floorID == c.floorID, e.roomID == c.roomID,
                  reference.kind == .mappedDestination || reference.historicalCaptureID != nil else {
                throw ConnectedJourneyError.invalidHistory
            }
        }
    }
    mutating func append(_ kind: JourneyEvent.Kind, at: Date, endpoint: JourneyEndpoint? = nil,
                         portalID: String? = nil, captureID: UUID? = nil,
                         portalDepartureCaptureID: UUID? = nil, portalDepartureRecordedAt: Date? = nil) throws {
        guard nextSequence < UInt64.max, at.timeIntervalSince1970.isFinite else { throw ConnectedJourneyError.invalidHistory }
        events.append(.init(sequence: nextSequence, kind: kind, recordedAt: at, endpoint: endpoint,
                            goalRevision: goal?.revision, portalID: portalID, historicalCaptureID: captureID,
                            portalDepartureCaptureID: portalDepartureCaptureID, portalDepartureRecordedAt: portalDepartureRecordedAt))
        nextSequence += 1
        if events.count > Self.maximumEvents {
            events.removeFirst(events.count - Self.maximumEvents)
            guard droppedEventCount < UInt64.max else { throw ConnectedJourneyError.invalidHistory }
            droppedEventCount += 1
        }
    }
    private static func validID(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && value.utf8.count <= 200
    }
}

public enum ConnectedJourneyError: Error, Equatable {
    case invalidHistory, invalidCatalog, unavailableMap, unavailableReference, incompletePortal
    case unauthorized, noReference, noGoal, noPlan, wrongLeg, awaitingLocalization, notAtEndpoint
    case clarificationNotDelivered, staleClarification, persistenceRequired, historyFull
}

/// Deliberately bounded phrase recognition, not an LLM routing decision. Matching
/// text never supplies command authority; all actions still check input provenance.
public enum JourneyReturnCommand {
    public static func matches(_ text: String) -> Bool {
        let normalized = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            .split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        return ["take me back", "go back", "return to my start", "ارجعني", "رجعني", "خذني للخلف", "ارجعني للبداية"].contains(normalized)
    }
}
