import Foundation

/// FUTURE measured registration contract. No production implementation is supplied.
/// Validators must resolve provenance, camera-to-body calibration, source-to-map
/// registration, timestamp/pose uncertainty, actual pedestrian mode and exact node
/// association. A user label, mapTarget, pose proximity or camera yaw is insufficient.
public protocol RecordedRouteAssociationValidator {
    func validate(sample: RecordedRouteSample, association: RecordedRouteNodeAssociation) -> RecordedRouteAssociationValidation
}
public enum RecordedRouteAssociationValidation { case unavailable, rejected, independentlyValidated }

/// Historical association, not live localization. Never carries clearance forward.
public struct RecordedRouteNodeAssociation: Sendable {
    public let observationID: UUID
    public let binding: SpatialMapBinding
    public let nodeID: String
    public let evidenceID, calibrationRevision, registrationRevision: String
    public init(observationID: UUID, binding: SpatialMapBinding, nodeID: String,
                evidenceID: String, calibrationRevision: String, registrationRevision: String) {
        self.observationID = observationID; self.binding = binding; self.nodeID = nodeID
        self.evidenceID = evidenceID; self.calibrationRevision = calibrationRevision; self.registrationRevision = registrationRevision
    }
}
public enum RecordedRoutePlaybackError: Error, Equatable {
    case missingHistory, discontinuousHistory, missingMeasuredAssociation, unsupportedTransition, staleAssociation, unauthorized
}

/// Typed consumer seam for a later measured mapper. Current unregistered/native
/// camera history remains preview-only; no synthetic registration fallback exists.
/// The existing route owner still exclusively issues/revalidates route tickets.
public enum RecordedRoutePlayback {
    public static func prepare(history: RecordedRouteHistory, returningTo reference: UUID? = nil,
                               associations: [RecordedRouteNodeAssociation], validator: any RecordedRouteAssociationValidator,
                               owner: inout SpatialRouteOwner, goal: UUID, origin: CompanionCommandOrigin) throws {
        guard CommandAuthority.permits(.startReturn, from: origin), owner.goalRevision == goal else {
            throw RecordedRoutePlaybackError.unauthorized
        }
        owner.cancelRoute() // A failed retrace cannot leave a preceding shortest route active.
        let preview = try history.preview(returningTo: reference)
        guard preview.reverseSamples.count >= 2 else { throw RecordedRoutePlaybackError.missingHistory }
        guard preview.reachesRequestedReference else { throw RecordedRoutePlaybackError.discontinuousHistory }
        guard associations.count == preview.reverseSamples.count,
              Set(associations.map(\.observationID)).count == associations.count else { throw RecordedRoutePlaybackError.missingMeasuredAssociation }
        let byID = Dictionary(uniqueKeysWithValues: associations.map { ($0.observationID, $0) })
        var binding: SpatialMapBinding?, nodes: [String] = []
        for sample in preview.reverseSamples {
            guard let association = byID[sample.observationID],
                  [association.nodeID, association.evidenceID, association.calibrationRevision, association.registrationRevision]
                    .allSatisfy(NativeObservationRecord.validID),
                  validator.validate(sample: sample, association: association) == .independentlyValidated else {
                throw RecordedRoutePlaybackError.missingMeasuredAssociation
            }
            guard sample.mapTarget.map({ $0 == association.binding }) ?? true else { throw RecordedRoutePlaybackError.staleAssociation }
            if let binding, binding != association.binding { throw RecordedRoutePlaybackError.unsupportedTransition }
            binding = association.binding
            // Multiple camera samples at one measured node may collapse; no skipped
            // unassociated points, cross-floor interpolation or shortcut substitution.
            if nodes.last != association.nodeID { nodes.append(association.nodeID) }
        }
        guard let binding else { throw RecordedRoutePlaybackError.missingMeasuredAssociation }
        try owner.planRecordedNodes(nodes, binding: binding, goal: goal)
    }
}

public enum RecordedRouteReturnCommand {
    public static func matches(_ text: String) -> Bool {
        guard !text.contains(where: { "\"“”«»".contains($0) }) else { return false }
        let value = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            .split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        return ["retrace my steps", "retrace my route", "return the same way", "replay my route",
                "take me back the same way", "ارجعني من نفس الطريق"].contains(value)
    }
}
