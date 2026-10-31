import Foundation
import BlindCore

/// Candidate-only owner routing. Connected journey is the sole physical owner;
/// registered preview is explicitly distinct and cannot receive journey pairs.
/// No fallback from a selected but unavailable journey to a preview is permitted.
@MainActor final class NativeLocalizationRouter {
    enum Selection: Equatable { case none, connectedJourney, registeredPreview, localSavedFrameReference }
    private(set) var selection: Selection = .none
    private var selectionEpoch = UUID()
    private let journey: ConnectedJourneyRuntime
    private let previewContext: () -> NativeLocalizationRouteContext?
    private let savedFrameContext: () -> NativeLocalizationRouteContext?
    private let withholdPreview: (UUID, SpatialMapArtifactIdentity) -> Void
    private let issuer = NativeLocalizationIssuer()
    var candidate: NativeLocalizationCandidate? { issuer.candidate }
    var reason: NativeLocalizationNotReady { issuer.reason }
    init(journey: ConnectedJourneyRuntime,
         previewContext: @escaping () -> NativeLocalizationRouteContext?,
         withholdPreview: @escaping (UUID, SpatialMapArtifactIdentity) -> Void,
         savedFrameContext: @escaping () -> NativeLocalizationRouteContext? = { nil }) {
        self.journey = journey; self.previewContext = previewContext; self.withholdPreview = withholdPreview
        self.savedFrameContext = savedFrameContext
        issuer.retireRegisteredOutput = { [weak self] owner in self?.withdraw(owner) }
    }
    func select(_ next: Selection) {
        guard selection != next else { return }
        // Explicit outgoing selection transition retires only its exact evidence;
        // delayed callbacks after this transition cannot mutate either new owner.
        withholdSelectedContext()
        issuer.invalidate(.ownerChanged)
        selection = next; selectionEpoch = UUID()
    }
    private var context: NativeLocalizationRouteContext? {
        switch selection {
        case .none: return nil
        case .connectedJourney: return journey.nativeLocalizationContext
        case .registeredPreview: return previewContext()
        case .localSavedFrameReference:
            guard let value = savedFrameContext(), value.scope == .localSavedFrameReference,
                  value.goalRevision == nil, value.revision.floorLevels.isEmpty,
                  value.revision.savedWorldFrame != nil else { return nil }
            return value
        }
    }
    /// Explicit current observation/lifecycle loss, not an asynchronous completion.
    /// Needed even when no earlier candidate exists. Context is read from the
    /// currently selected actual owner; no inactive-preview fallback is possible.
    private func withholdSelectedContext() {
        guard let context else { return }
        switch selection {
        case .none, .localSavedFrameReference: return
        case .connectedJourney:
            guard let goal = context.goalRevision else { return }
            _ = journey.withholdNativeEvidence(session: context.sessionID, artifact: context.artifact, goalRevision: goal)
        case .registeredPreview:
            withholdPreview(context.sessionID, context.artifact)
        }
    }
    private func matchesSelection(_ owner: NativeLocalizationOwner, context: NativeLocalizationRouteContext) -> Bool {
        let kind: NativeLocalizationSelection.Kind
        switch selection {
        case .none: return false
        case .connectedJourney: kind = .connectedJourney
        case .registeredPreview: kind = .registeredPreview
        case .localSavedFrameReference: kind = .localSavedFrameReference
        }
        return owner.selection.kind == kind && owner.selection.epoch == selectionEpoch &&
            owner.selection.goalRevision == context.goalRevision &&
            owner.registeredSession == context.sessionID && owner.artifact == context.artifact
    }
    private func withdraw(_ owner: NativeLocalizationOwner) {
        guard let context, matchesSelection(owner, context: context) else { return }
        switch selection {
        case .none, .localSavedFrameReference: return
        case .connectedJourney:
            guard let goal = owner.selection.goalRevision else { return }
            _ = journey.withholdNativeEvidence(session: owner.registeredSession,
                artifact: owner.artifact, goalRevision: goal)
        case .registeredPreview:
            withholdPreview(owner.registeredSession, owner.artifact)
        }
    }
    func currentOwner(arSession: UUID, calibrationRevision: String, mountRevision: UUID) -> NativeLocalizationOwner? {
        guard let context, let saved = context.revision.savedWorldFrame else { return nil }
        let kind: NativeLocalizationSelection.Kind
        switch selection {
        case .none: return nil
        case .connectedJourney: kind = .connectedJourney
        case .registeredPreview: kind = .registeredPreview
        case .localSavedFrameReference: kind = .localSavedFrameReference
        }
        guard (kind == .localSavedFrameReference) == (context.scope == .localSavedFrameReference) else { return nil }
        return .init(arSession: arSession, registeredSession: context.sessionID,
            artifact: context.artifact, descriptor: saved, calibrationRevision: calibrationRevision,
            mountRevision: mountRevision, selection: .init(kind: kind, epoch: selectionEpoch, goalRevision: context.goalRevision))
    }
    func offer(arSession: UUID, calibrationRevision: String, mountRevision: UUID,
               capturedAt: Double, cameraToWorld: [Double], trackingNormal: Bool,
               association: SavedWorldFrameCameraAssociation?, now: Double) {
        guard selection != .none else { issuer.invalidate(.noSelectedOwner); return }
        guard let context else { issuer.invalidate(.noConfiguredSession); return }
        // Calibration/support/error provider is absent. Withdraw even if this
        // first candidate fails saved-frame or tracking admission below.
        withholdSelectedContext()
        guard context.revision.savedWorldFrame != nil else { issuer.invalidate(.importedFrameNeedsMeasuredRegistration); return }
        guard let owner = currentOwner(arSession: arSession, calibrationRevision: calibrationRevision, mountRevision: mountRevision) else {
            issuer.invalidate(.noInstallation); return
        }
        // A recent descriptor alone cannot authorize a different or rejected frame.
        // The normal owner supplies the exact ARFrame timestamp receipt; stable map
        // creation time is historical metadata and is deliberately not age-gated.
        guard let association else { issuer.invalidate(.noRecoveredWorldFrame); return }
        issuer.offer(.init(owner: owner, capturedAt: capturedAt, cameraToWorld: cameraToWorld,
            trackingNormal: trackingNormal, association: association),
            installed: context.revision, recovered: association.frame, now: now)
    }
    func watchdog(arSession: UUID, calibrationRevision: String, mountRevision: UUID,
                  association: SavedWorldFrameCameraAssociation?, now: Double) {
        // Re-read from the current recovery owner, never a copied asynchronous result.
        // Nil covers deletion/map replacement, tracking loss, restart and expiry.
        if let candidate, candidate.association != association {
            invalidate(.noRecoveredWorldFrame); return
        }
        issuer.watchdog(currentOwner: currentOwner(arSession: arSession,
            calibrationRevision: calibrationRevision, mountRevision: mountRevision), now: now)
    }
    func invalidate(_ reason: NativeLocalizationNotReady) {
        withholdSelectedContext(); issuer.invalidate(reason)
    }
    /// Bench-only result retains destination ownership for inspection. It is never
    /// routed to either accept method. The caller cannot provide a replacement owner.
    func prepareForBench(_ measurements: NativeLocalizationMeasurements, arSession: UUID,
        calibrationRevision: String, mountRevision: UUID,
        validator: any NativeLocalizationEvidenceValidator, now: Double) throws -> NativeLocalizationBenchPair {
        guard let owner = currentOwner(arSession: arSession, calibrationRevision: calibrationRevision, mountRevision: mountRevision) else {
            throw NativeLocalizationNotReady.noConfiguredSession
        }
        return try issuer.prepareForBench(measurements, currentOwner: owner, validator: validator, now: now)
    }
}
