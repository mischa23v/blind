import Foundation
import BlindCore

/// Bounded native consumer of the existing urgent sensor loop. No camera, SQL,
/// model, speech/beacon sink, map registration or physical release is owned here.
@MainActor final class ObservedSceneRuntime {
    private final class Worker: @unchecked Sendable {
        var scene = ObservedSceneAccumulator()
        init(session: UUID) { scene.begin(sessionID: session) }
    }
    private let queue = DispatchQueue(label: "blind.observed-scene", qos: .utility)
    private let clock: () -> Double
    private var worker: Worker?
    private var session: UUID?
    private var epoch = UUID()
    private var workID: UUID?
    private var lastOffered = -Double.infinity
    private var minimumCapture = -Double.infinity
    private var intent: ObservedSceneAccumulator.Intent = .lookAhead
    private var goalRevision = UUID()
    private var ownerGoalRevision: String?
    private var bodyRevision = UUID()
    private(set) var snapshot: ObservedSceneSnapshot?
    private(set) var plan: ObservedScenePlan?
    private(set) var liveStatus = "unavailable"
    var onChange: (() -> Void)?
    init(clock: @escaping () -> Double = { ProcessInfo.processInfo.systemUptime }) { self.clock = clock }
    func begin(session: UUID, capturedAfter: Double? = nil) {
        self.session = session; epoch = UUID(); worker = Worker(session: session)
        intent = .lookAhead; goalRevision = UUID(); lastOffered = -.infinity
        minimumCapture = capturedAfter.flatMap { $0.isFinite ? $0 : nil } ?? -.infinity
        snapshot = nil; plan = nil; liveStatus = "waitingForObservation"; onChange?()
        // An old in-flight job retains the one worker slot until it really exits.
    }
    func stop() {
        session = nil; worker = nil; epoch = UUID(); snapshot = nil; plan = nil; liveStatus = "stopped"; onChange?()
    }
    func trackingLost(at capturedAt: Double? = nil) {
        guard let session else { return }
        epoch = UUID(); worker = Worker(session: session); snapshot = nil; plan = nil
        // Preserve requested intent, but never revive the former return origin.
        let loss = capturedAt ?? clock()
        if loss.isFinite { minimumCapture = max(minimumCapture, lastOffered, loss) }
        liveStatus = "trackingUnavailable"; onChange?()
    }
    func setIntent(_ intent: ObservedSceneAccumulator.Intent) {
        self.intent = intent; goalRevision = UUID(); plan = nil; liveStatus = "waitingForObservation"; onChange?()
    }
    /// A trusted goal/subtask replacement retires the previous return request,
    /// including work already queued for its older owner.
    func bindGoalRevision(_ revision: String) {
        guard ownerGoalRevision != revision else { return }
        ownerGoalRevision = revision; setIntent(.lookAhead)
    }
    /// Body/profile changes invalidate a queued plan without discarding the
    /// observed map or silently restarting the owned return breadcrumb path.
    func invalidateBody() {
        bodyRevision = UUID(); plan = nil; liveStatus = "waitingForBodyObservation"; onChange?()
    }
    func suspendLive(at capturedAt: Double? = nil) {
        epoch = UUID(); plan = nil; liveStatus = "depthUnavailable"
        let loss = capturedAt ?? clock()
        if loss.isFinite { minimumCapture = max(minimumCapture, lastOffered, loss) }
        onChange?()
    }
    func revalidate(now: Double) {
        guard let captured = snapshot?.capturedAt else { return }
        if !now.isFinite || now < captured || now - captured > 0.5 { plan = nil; liveStatus = "expired"; onChange?() }
    }
    func offer(_ observation: Observation, session: UUID, floor: Double?,
               body: BodyEnvelope?, now: Double, hazard: Hazard = .uncertain) {
        guard self.session == session, let worker, workID == nil,
              observation.timestamp > minimumCapture,
              observation.timestamp - lastOffered >= 0.1 else { return }
        // Validate before updating cadence; a rejected future/NaN timestamp must
        // never poison lastOffered and prevent later valid captures recovering.
        guard observation.timestamp.isFinite, observation.timestamp >= 0, now.isFinite,
              now >= observation.timestamp, now - observation.timestamp <= 0.5 else {
            plan = nil; liveStatus = "stale"; onChange?(); return
        }
        lastOffered = observation.timestamp
        let id = UUID(), generation = epoch, intent = intent, goal = goalRevision, bodyVersion = bodyRevision
        workID = id
        queue.async { [weak self] in
            worker.scene.setIntent(intent, revision: goal)
            let snapshot = worker.scene.observe(observation, sessionID: session, now: now, hazard: hazard)
            let plan = body.flatMap { worker.scene.planCurrent(floor: floor, body: $0, now: now) }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.workID == id else { return }
                self.workID = nil
                guard self.epoch == generation, self.session == session, self.goalRevision == goal, self.bodyRevision == bodyVersion else { return }
                self.snapshot = snapshot; self.plan = plan
                self.liveStatus = snapshot.status == .observing
                    ? (body == nil ? "bodyEnvelopeUnavailable" : plan?.local.state.rawValue ?? snapshot.returnState.rawValue) : snapshot.status.rawValue
                self.revalidate(now: self.clock()); self.onChange?()
            }
        }
    }
}
