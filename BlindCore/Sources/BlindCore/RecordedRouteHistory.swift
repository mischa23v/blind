import Foundation

/// Private camera-path history, not body-ground-truth, clearance or a route issuer.
/// Source coordinates are NEVER reinterpreted in the optional destination map.
public struct RecordedRouteSample: Codable, Equatable, Sendable {
    public let observationID, sessionID: UUID
    public let sourceFrameID, sourceID: String
    public let producer: NativeObservationRecord.Producer
    public let capturedAt, poseCapturedAt: Double
    public let poseSourceID: String?
    public let observedAt: Date?
    public let cameraPosition: Point3
    public let cameraToSourceFrame: NativeCameraTransform
    public let cameraConvention: NativeCameraConvention
    /// Camera velocity does not establish walking versus vehicle travel.
    public let transportMode: RecordedRouteTransportMode
    public let mapTarget: SpatialMapBinding?
    public let tracking: NativeObservationRecord.Tracking
    public let boundaryBefore: RecordedRouteBoundary?
}

public enum RecordedRouteTransportMode: String, Codable, Sendable { case unknown }

public enum RecordedRouteBoundary: String, Codable, Sendable {
    case beginning, trackingLost, samplingGap, frameChanged, sessionChanged, poseJump
    case mapOwnershipChanged, interrupted, restarted, capacityReached, retentionLoss, durabilityLoss
}

/// An unverified transition is deliberately a gap, not an invented portal/floor.
/// Actual registered portal endpoint associations remain in ConnectedJourneySnapshot.
public struct RecordedRoutePreview: Equatable, Sendable {
    public let reverseSamples: [RecordedRouteSample]
    public let gaps: [RecordedRouteBoundary]
    public let reachesRequestedReference: Bool
    public var permitsPhysicalGuidance: Bool { false }
    public init(reverseSamples: [RecordedRouteSample], gaps: [RecordedRouteBoundary], reachesRequestedReference: Bool) {
        self.reverseSamples = reverseSamples; self.gaps = gaps; self.reachesRequestedReference = reachesRequestedReference
    }
}

public enum RecordedRouteError: Error, Equatable { case invalidArchive, invalidReference, capacityReached, duplicate, outOfOrder }

public struct RecordedRouteHistory: Codable, Equatable, Sendable {
    public static let maximumSamples = 20_000
    public static let maximumBytes = 20_000_000
    public let schemaVersion: Int
    public let id: UUID
    public private(set) var samples: [RecordedRouteSample]
    public private(set) var pendingBoundary: RecordedRouteBoundary?
    public private(set) var capacityExceeded: Bool
    public init(id: UUID = UUID()) {
        schemaVersion = 1; self.id = id; samples = []; pendingBoundary = .beginning; capacityExceeded = false
    }
    public mutating func interrupt(_ reason: RecordedRouteBoundary = .interrupted) { pendingBoundary = reason }
    /// Append every admitted observation, not planned nodes or fabricated interpolation.
    /// A finite sampling gap remains explicit even when endpoints are close together.
    public mutating func observe(_ observation: NativeObservationRecord) throws {
        try observation.validate()
        guard samples.count < Self.maximumSamples else {
            capacityExceeded = true; pendingBoundary = .capacityReached; throw RecordedRouteError.capacityReached
        }
        guard !samples.contains(where: { $0.observationID == observation.id }) else { throw RecordedRouteError.duplicate }
        samples.append(try RecordedRouteSample.capture(observation, previous: samples.last, pendingBoundary: &pendingBoundary))
        pendingBoundary = nil
    }
    /// Reference is an actual observed sample: start, entrance or meeting point may be
    /// labelled by a separate UI, but a label never invents coordinates or recognition.
    public func preview(returningTo reference: UUID? = nil) throws -> RecordedRoutePreview {
        guard !samples.isEmpty else { throw RecordedRouteError.invalidReference }
        let index: Int
        if let reference {
            guard let found = samples.firstIndex(where: { $0.observationID == reference }) else { throw RecordedRouteError.invalidReference }
            index = found
        } else { index = 0 }
        let selected = Array(samples[index...])
        var gaps = selected.dropFirst().compactMap(\.boundaryBefore)
        if let pendingBoundary { gaps.append(pendingBoundary) }
        return .init(reverseSamples: selected.reversed(), gaps: gaps,
            reachesRequestedReference: gaps.isEmpty && !capacityExceeded)
    }
    public func encoded() throws -> Data {
        try validate()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(self)
        guard data.count <= Self.maximumBytes else { throw RecordedRouteError.invalidArchive }; return data
    }
    public init(id: UUID, archivedSamples: [RecordedRouteSample]) throws {
        schemaVersion = 1; self.id = id; samples = archivedSamples; pendingBoundary = .restarted; capacityExceeded = false
        try validate()
    }
    private enum CodingKeys: String, CodingKey { case schemaVersion, id, samples, pendingBoundary, capacityExceeded }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decode(Int.self, forKey: .schemaVersion)
        id = try values.decode(UUID.self, forKey: .id)
        samples = try values.decode([RecordedRouteSample].self, forKey: .samples)
        _ = try values.decodeIfPresent(RecordedRouteBoundary.self, forKey: .pendingBoundary)
        pendingBoundary = .restarted
        capacityExceeded = try values.decode(Bool.self, forKey: .capacityExceeded)
        try validate()
    }
    public init(data: Data) throws {
        guard !data.isEmpty, data.count <= Self.maximumBytes else { throw RecordedRouteError.invalidArchive }
        self = try JSONDecoder().decode(Self.self, from: data); try validate()
        // A restored path is history. No pre-restart continuity or live location survives.
        pendingBoundary = .restarted
    }
    private func validate() throws {
        guard schemaVersion == 1, samples.count <= Self.maximumSamples,
              Set(samples.map(\.observationID)).count == samples.count else { throw RecordedRouteError.invalidArchive }
        for (index, sample) in samples.enumerated() {
            guard sample.cameraPosition.isFinite, sample.cameraToSourceFrame.valid,
                  (try? sample.cameraToSourceFrame.applying(to: Point3(0, 0, 0))) == sample.cameraPosition, sample.capturedAt.isFinite, sample.capturedAt >= 0,
                  sample.poseCapturedAt.isFinite, abs(sample.poseCapturedAt - sample.capturedAt) <= 0.01,
                  [sample.sourceID, sample.sourceFrameID].allSatisfy(NativeObservationRecord.validID),
                  sample.poseSourceID.map(NativeObservationRecord.validID) ?? true,
                  sample.observedAt.map({ $0.timeIntervalSince1970.isFinite && $0.timeIntervalSince1970 >= 0 }) ?? true else { throw RecordedRouteError.invalidArchive }
            if let binding = sample.mapTarget {
                guard [binding.mapID, binding.frameID, binding.revision].allSatisfy(NativeObservationRecord.validID), binding.frameID != sample.sourceFrameID else { throw RecordedRouteError.invalidArchive }
            }
            if sample.producer == .arkitScenesRecorded {
                guard sample.mapTarget == nil, sample.observedAt == nil, sample.tracking == .notRecorded, sample.cameraConvention == .pinholeRightDownForward else { throw RecordedRouteError.invalidArchive }
            } else if sample.tracking == .notRecorded || sample.observedAt == nil || sample.cameraConvention != .arKitRightUpBack { throw RecordedRouteError.invalidArchive }
            if index == 0 { guard sample.boundaryBefore != nil else { throw RecordedRouteError.invalidArchive }; continue }
            let last = samples[index - 1]
            if sample.boundaryBefore == nil {
                let elapsed = sample.capturedAt - last.capturedAt
                guard sample.sessionID == last.sessionID, sample.sourceFrameID == last.sourceFrameID,
                      sample.producer == last.producer, sample.mapTarget == last.mapTarget,
                      elapsed > 0, elapsed <= 0.5,
                      sample.cameraPosition.distance(to: last.cameraPosition) <= 3 * elapsed,
                      sample.tracking != .limited, sample.tracking != .unavailable,
                      last.tracking != .limited, last.tracking != .unavailable else { throw RecordedRouteError.invalidArchive }
            }
        }
    }
}

public struct RecordedRouteSampler: Sendable {
    public private(set) var lastSample: RecordedRouteSample?
    private var pendingBoundary: RecordedRouteBoundary? = .beginning
    public init() {}
    public mutating func interrupt(_ reason: RecordedRouteBoundary = .interrupted) { pendingBoundary = reason }
    public mutating func restart() { lastSample = nil; pendingBoundary = .restarted }
    public mutating func observe(_ observation: NativeObservationRecord) throws -> RecordedRouteSample {
        let sample = try RecordedRouteSample.capture(observation, previous: lastSample, pendingBoundary: &pendingBoundary)
        lastSample = sample; pendingBoundary = nil; return sample
    }
}
extension RecordedRouteSample {
    fileprivate static func capture(_ observation: NativeObservationRecord, previous: RecordedRouteSample?,
                                    pendingBoundary: inout RecordedRouteBoundary?) throws -> RecordedRouteSample {
        try observation.validate()
        guard previous?.observationID != observation.id else { throw RecordedRouteError.duplicate }
        let position = try observation.cameraToSessionWorld.applying(to: Point3(0, 0, 0))
        var boundary = pendingBoundary
        if let last = previous {
            if last.sessionID != observation.sessionID { boundary = .sessionChanged }
            else if last.sourceFrameID != observation.coordinateFrameID || last.producer != observation.producer { boundary = .frameChanged }
            else {
                guard observation.capturedAt > last.capturedAt else {
                    pendingBoundary = .trackingLost; throw RecordedRouteError.outOfOrder
                }
                let elapsed = observation.capturedAt - last.capturedAt
                if elapsed > 0.5 { boundary = .samplingGap }
                else if position.distance(to: last.cameraPosition) > 3 * elapsed { boundary = .poseJump }
                else if last.mapTarget != observation.mapTarget { boundary = .mapOwnershipChanged }
                if last.tracking == .limited || last.tracking == .unavailable { boundary = .trackingLost }
            }
        }
        if observation.tracking == .limited || observation.tracking == .unavailable { boundary = .trackingLost }
        return .init(observationID: observation.id, sessionID: observation.sessionID,
            sourceFrameID: observation.coordinateFrameID, sourceID: observation.sourceID, producer: observation.producer,
            capturedAt: observation.capturedAt, poseCapturedAt: observation.poseCapturedAt,
            poseSourceID: observation.poseSourceID, observedAt: observation.observedAt, cameraPosition: position,
            cameraToSourceFrame: observation.cameraToSessionWorld, cameraConvention: observation.cameraConvention, transportMode: .unknown,
            mapTarget: observation.mapTarget, tracking: observation.tracking, boundaryBefore: boundary)

    }
    public func markingBoundary(_ boundary: RecordedRouteBoundary) -> RecordedRouteSample {
        .init(observationID: observationID, sessionID: sessionID, sourceFrameID: sourceFrameID, sourceID: sourceID,
            producer: producer, capturedAt: capturedAt, poseCapturedAt: poseCapturedAt, poseSourceID: poseSourceID,
            observedAt: observedAt, cameraPosition: cameraPosition, cameraToSourceFrame: cameraToSourceFrame,
            cameraConvention: cameraConvention, transportMode: transportMode, mapTarget: mapTarget,
            tracking: tracking, boundaryBefore: boundary)
    }
    public func encoded() throws -> Data {
        try validate(); let data = try JSONEncoder().encode(self)
        guard data.count <= 4096 else { throw RecordedRouteError.invalidArchive }; return data
    }
    public init(payload: Data) throws {
        guard !payload.isEmpty, payload.count <= 4096 else { throw RecordedRouteError.invalidArchive }
        self = try JSONDecoder().decode(Self.self, from: payload); try validate()
    }
    public func validate() throws {
        guard cameraToSourceFrame.valid, cameraPosition.isFinite,
              try cameraToSourceFrame.applying(to: Point3(0,0,0)) == cameraPosition,
              capturedAt.isFinite, capturedAt >= 0, poseCapturedAt.isFinite, poseCapturedAt >= 0,
              abs(poseCapturedAt-capturedAt) <= 0.01,
              [sourceFrameID,sourceID].allSatisfy(NativeObservationRecord.validID),
              poseSourceID.map(NativeObservationRecord.validID) ?? true,
              observedAt.map({ $0.timeIntervalSince1970.isFinite && $0.timeIntervalSince1970 >= 0 }) ?? true else { throw RecordedRouteError.invalidArchive }
        if let mapTarget {
            guard [mapTarget.mapID,mapTarget.frameID,mapTarget.revision].allSatisfy(NativeObservationRecord.validID), mapTarget.frameID != sourceFrameID else { throw RecordedRouteError.invalidArchive }
        }
        if producer == .arkitScenesRecorded {
            guard cameraConvention == .pinholeRightDownForward, tracking == .notRecorded, observedAt == nil, mapTarget == nil else { throw RecordedRouteError.invalidArchive }
        } else {
            guard cameraConvention == .arKitRightUpBack, tracking != .notRecorded, observedAt != nil else { throw RecordedRouteError.invalidArchive }
        }
    }
}
