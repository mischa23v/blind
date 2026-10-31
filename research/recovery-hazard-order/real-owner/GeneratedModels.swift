// Executes extracted production-proposal methods with instrumented adapters.
// Not ARKit, SwiftUI, actual detector accuracy, or native speech validation.
import Foundation
var events: [String] = []
enum Hazard { case obstacle, drop, overhead, observing, uncertain, needsCalibration
 var isUrgent: Bool { self == .obstacle || self == .drop || self == .overhead }
}
enum Reason { case localizing, bodyEnvelope, trackingUnavailable, depthUnavailable }
struct Detection { var hazard: Hazard; var reason: Reason?
 init(_ h: Hazard, reason: Reason? = nil) { hazard=h; self.reason=reason }
}
struct Observation { var trackingNormal: Bool }
enum Tracking { case normal, limited }
struct Camera { var trackingState: Tracking }
struct ARFrame { var timestamp: Double = 1; var observation: Observation?; var noDepthTracking: Tracking = .normal
 var camera: Camera { Camera(trackingState: observation.map { $0.trackingNormal ? .normal : .limited } ?? noDepthTracking) }
}
enum DepthSampler {
 static func observation(from f: ARFrame) -> Observation? { events.append("sample"); return f.observation }
 static func unavailableReason(from f: ARFrame) -> Reason { .depthUnavailable }
 static func cameraToWorld(from f: ARFrame) -> Int { 1 }
}
struct Detector { var next = Detection(.needsCalibration); var floorHeight: Double? = nil
 mutating func process(_ o: Observation) -> Detection { events.append("legacy"); return o.trackingNormal ? next : Detection(.uncertain, reason: .trackingUnavailable) }
 mutating func reset() { events.append("reset"); floorHeight=nil; next=Detection(.needsCalibration) }
 mutating func invalidateRecentEvidence() { events.append("invalidateEvidence") }
}
enum BodyCollisionWarning {
 struct Assessment { var detection: Detection? }
 static var hit = false
 static func assess(_ o: Observation, cameraToWorld: Int, profile: Int?, fixedMount: Bool, now: Double, floorHeight: Double?) -> Assessment {
 events.append("body"); return Assessment(detection: hit && o.trackingNormal && fixedMount && profile != nil ? Detection(.obstacle, reason: .bodyEnvelope) : nil)
 }
 static func combining(_ d: Detection, with a: Assessment) -> Detection { d.hazard.isUrgent ? d : a.detection ?? d }
}
struct Sink { mutating func invalidatePosition() {events.append("positionInvalid")}; mutating func invalidate() { events.append("surveyInvalid") }; mutating func breakTracking() {events.append("trackingBroken")}; mutating func suspendLive(at: Double) {events.append("sceneSuspended")} }
struct Heading { var mountSlipSuspected=false }
@MainActor final class OldModel {
 var bodyWarningAssessment: BodyCollisionWarning.Assessment?
 var detector=Detector(); var recognizedPlace: Int?=1; var indoor=Sink()
 var fixedBodyMount=true; var lastObservation: Observation?=Observation(trackingNormal:true)
 var phoneDetection=Detection(.observing); var survey=Sink(); var journeys=JourneyAdapter()
 var bodyWarningProfile: Int?=1; var mountSlipAnnounced=false; var bodyHeadingEstimator=Heading()
 var publication: Detection?
 func invalidatePerceptionWork(preserveRGBHistoryWork: Bool) {events.append("perceptionInvalid")}
 func invalidateRecognizedRoom() {events.append("roomInvalid")}
 func invalidateReturn() {events.append("returnInvalid")}
 func withObservedScene(_ action: (inout Sink)->Void) {var s=Sink(); action(&s)}
 func publish() { events.append("publish"); publication=phoneDetection }
 func run(_ frame: ARFrame) { processRecoveryHazards(frame, receivedAt: 1) }
    private func processRecoveryHazards(_ frame: ARFrame, receivedAt: Double) {
        bodyWarningAssessment = nil
        // Retire pose-owned state even when the same frame has no usable depth.
        if case .normal = frame.camera.trackingState {} else {
            invalidatePerceptionWork(preserveRGBHistoryWork: true)
            invalidateRecognizedRoom()
            detector.reset(); recognizedPlace = nil; indoor.invalidatePosition(); fixedBodyMount = false
            invalidateReturn()
        }
        if let observation = DepthSampler.observation(from: frame) {
            processDepthHazards(observation, frame: frame, receivedAt: receivedAt)
        } else {
            if lastObservation != nil { invalidatePerceptionWork(preserveRGBHistoryWork: true) }
            invalidateRecognizedRoom()
            detector.invalidateRecentEvidence()
            phoneDetection = Detection(.uncertain, reason: DepthSampler.unavailableReason(from: frame))
        }
        // Recovery never supplies route progress or support, even on a normal frame.
        lastObservation = nil
        withObservedScene { $0.suspendLive(at: frame.timestamp) }
        survey.invalidate()
        journeys.breakTracking()
        invalidateReturn()
        if !phoneDetection.hazard.isUrgent {
            phoneDetection = Detection(.uncertain, reason: .localizing)
        }
        // Must precede recovery acceptance/rejection and optional furniture/history.
        publish()
    }

    private func processDepthHazards(_ observation: Observation, frame: ARFrame, receivedAt: Double) {
        let legacyDetection = detector.process(observation)
        if legacyDetection.hazard.isUrgent {
            // Never delay an existing urgent alert for supplemental geometry work.
            bodyWarningAssessment = nil; phoneDetection = legacyDetection
        } else {
            let bodyAssessment = BodyCollisionWarning.assess(observation,
                cameraToWorld: DepthSampler.cameraToWorld(from: frame), profile: bodyWarningProfile,
                fixedMount: fixedBodyMount && !mountSlipAnnounced && !bodyHeadingEstimator.mountSlipSuspected,
                now: receivedAt, floorHeight: detector.floorHeight)
            bodyWarningAssessment = bodyAssessment
            phoneDetection = BodyCollisionWarning.combining(legacyDetection, with: bodyAssessment)
        }
    }

}
@MainActor final class Model {
 var bodyWarningAssessment: BodyCollisionWarning.Assessment?
 var detector=Detector(); var recognizedPlace: Int?=1; var indoor=Sink()
 var fixedBodyMount=true; var lastObservation: Observation?=Observation(trackingNormal:true)
 var phoneDetection=Detection(.observing); var survey=Sink(); var journeys=JourneyAdapter()
 var bodyWarningProfile: Int?=1; var mountSlipAnnounced=false; var bodyHeadingEstimator=Heading()
 var publication: Detection?
 func invalidatePerceptionWork(preserveRGBHistoryWork: Bool) {events.append("perceptionInvalid")}
 func invalidateRecognizedRoom() {events.append("roomInvalid")}
 func invalidateReturn() {events.append("returnInvalid")}
 func withObservedScene(_ action: (inout Sink)->Void) {var s=Sink(); action(&s)}
 func publish() { events.append("publish"); publication=phoneDetection }
 func run(_ frame: ARFrame) { processRecoveryHazards(frame, receivedAt: 1) }
    private func processRecoveryHazards(_ frame: ARFrame, receivedAt: Double) {
        bodyWarningAssessment = nil
        // Retire pose-owned state even when the same frame has no usable depth.
        if case .normal = frame.camera.trackingState {} else {
            invalidatePerceptionWork(preserveRGBHistoryWork: true)
            invalidateRecognizedRoom()
            detector.reset(); recognizedPlace = nil; indoor.invalidatePosition(); fixedBodyMount = false
            invalidateReturn()
        }
        if let observation = DepthSampler.observation(from: frame) {
            processDepthHazards(observation, frame: frame, receivedAt: receivedAt)
        } else {
            if lastObservation != nil { invalidatePerceptionWork(preserveRGBHistoryWork: true) }
            invalidateRecognizedRoom()
            detector.invalidateRecentEvidence()
            phoneDetection = Detection(.uncertain, reason: DepthSampler.unavailableReason(from: frame))
        }
        // Recovery never supplies route progress or support, even on a normal frame.
        lastObservation = nil
        withObservedScene { $0.suspendLive(at: frame.timestamp) }
        survey.invalidate()
        // Journey authority was withdrawn at recovery entry; do not retire a
        // new clarification or emit camera-restart changes on every normal frame.
        invalidateReturn()
        if !phoneDetection.hazard.isUrgent {
            phoneDetection = Detection(.uncertain, reason: .localizing)
        }
        // Must precede recovery acceptance/rejection and optional furniture/history.
        publish()
    }

    private func processDepthHazards(_ observation: Observation, frame: ARFrame, receivedAt: Double) {
        let legacyDetection = detector.process(observation)
        if legacyDetection.hazard.isUrgent {
            // Never delay an existing urgent alert for supplemental geometry work.
            bodyWarningAssessment = nil; phoneDetection = legacyDetection
        } else {
            let bodyAssessment = BodyCollisionWarning.assess(observation,
                cameraToWorld: DepthSampler.cameraToWorld(from: frame), profile: bodyWarningProfile,
                fixedMount: fixedBodyMount && !mountSlipAnnounced && !bodyHeadingEstimator.mountSlipSuspected,
                now: receivedAt, floorHeight: detector.floorHeight)
            bodyWarningAssessment = bodyAssessment
            phoneDetection = BodyCollisionWarning.combining(legacyDetection, with: bodyAssessment)
        }
    }

}
