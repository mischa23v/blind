import Foundation
import BlindCore

/// Main-owner candidate bridge only. No production evidence validator or physical
/// release exists. This class cannot authorize motion, invoke speech, or stop the
/// independent hazard channel. History persistence is deliberately not a dependency.
final class NativeLocalizationIssuer {
    private var gate = NativeLocalizationEvidenceGate()
    private(set) var candidate: NativeLocalizationCandidate?
    private(set) var reason: NativeLocalizationNotReady = .noInstallation
    private var deadline: Double?
    /// Route-specific retirement only, never a generic preview-route/goal cancellation.
    var retireRegisteredOutput: ((NativeLocalizationOwner) -> Void)?
    func invalidate(_ why: NativeLocalizationNotReady) {
        precondition(Thread.isMainThread)
        let retiredOwner = candidate?.owner
        gate.withholdCandidate(why); candidate = nil; deadline = nil; reason = why
        if let retiredOwner { retireRegisteredOutput?(retiredOwner) }
    }
    func offer(_ value: NativeLocalizationCandidate, installed: SpatialMapRevision?,
               recovered: SavedWorldFrame?, now: Double) {
        precondition(Thread.isMainThread)
        do {
            try gate.begin(value, installed: installed, recovered: recovered, now: now)
            candidate = value; deadline = value.capturedAt + SavedWorldFrameRecovery.maximumFrameAge
            reason = value.owner.selection.kind == .localSavedFrameReference ? .localReferenceOnly : .missingCalibration
            // Missing calibration is already known: do not leave any older route
            // pose/output alive. The retained candidate is diagnostic only;
            // exact-owner retirement leaves session identity and replay ledger intact.
            retireRegisteredOutput?(value.owner)
            // No call to acceptRegisteredCapture: there is no independently
            // measured camera/body, support-coverage or uncertainty provider.
        } catch let why as NativeLocalizationNotReady { invalidate(why) }
        catch { invalidate(.invalidEvidence) }
    }
    /// Exact owner read on the control owner, never copied from a delayed result.
    func watchdog(currentOwner: NativeLocalizationOwner?, now: Double) {
        precondition(Thread.isMainThread)
        guard let candidate else { return }
        guard currentOwner == candidate.owner else { invalidate(.ownerChanged); return }
        guard now.isFinite, now >= candidate.capturedAt, let deadline, now <= deadline else {
            invalidate(.staleCandidate); return
        }
    }
    /// Explicitly callable bench seam; consumes the original candidate and always
    /// retires output afterward. Even a real future provider needs separate release
    /// review and downstream delivery guards; this function never installs its pair.
    func prepareForBench(_ measurements: NativeLocalizationMeasurements,
                         currentOwner: NativeLocalizationOwner,
                         validator: any NativeLocalizationEvidenceValidator,
                         now: Double) throws -> NativeLocalizationBenchPair {
        precondition(Thread.isMainThread)
        do {
            let pair = try gate.prepareForBench(measurements, currentOwner: currentOwner, validator: validator, now: now)
            invalidate(.physicalReleaseNotApproved)
            return pair
        } catch let why as NativeLocalizationNotReady {
            if why != .supersededCandidate { invalidate(why) }
            throw why
        }
        catch { invalidate(.invalidEvidence); throw error }
    }
}
