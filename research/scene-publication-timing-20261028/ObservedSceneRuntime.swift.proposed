import Foundation
import BlindCore

/// Bounded native consumer of the existing urgent sensor loop. No camera, SQL,
/// model, speech/beacon sink, map registration or physical release is owned here.
@MainActor final class ObservedSceneRuntime {
    private final class Worker: @unchecked Sendable {
        var scene = ObservedSceneAccumulator()
        init(session: UUID) { scene.begin(sessionID: session) }
    }
    private let queue: DispatchQueue
    private let clock: () -> Double
    private var worker: Worker?
    private var session: UUID?
    private var epoch = UUID()
    private var workID: UUID?
#if DEBUG
    struct DiagnosticWorkTimingSnapshot: Sendable {
        fileprivate let id: UUID
        fileprivate let values: [TimeInterval?]
        func report() -> String {
            func time(_ index: Int) -> String { values[index].map { String($0) } ?? "missing" }
            func delta(_ from: Int, _ to: Int) -> String {
                guard let first = values[from], let last = values[to] else { return "missing" }
                return String(last - first)
            }
            return "OBSERVED_SCENE_WORK_TIMING id=\(id) admitted=\(time(0)) workerStarted=\(time(1)) workerFinished=\(time(2)) mainDelivered=\(time(3)) queueAdmission=\(delta(0,1)) workerWall=\(delta(1,2)) mainHandoff=\(delta(2,3))"
        }
    }
    // Fixed four-slot metadata only. Worker writes are lock-protected; no printing,
    // asynchronous actor hop, image, position, map or body data enters this buffer.
    private final class DiagnosticWorkTiming: @unchecked Sendable {
        enum Phase: Int { case admitted, workerStarted, workerFinished, mainDelivered }
        private let lock = NSLock()
        private var times: [TimeInterval?] = [nil, nil, nil, nil]
        func mark(_ phase: Phase) {
            let now = ProcessInfo.processInfo.systemUptime
            lock.lock(); defer { lock.unlock() }
            if times[phase.rawValue] == nil { times[phase.rawValue] = now }
        }
        func snapshot(id: UUID) -> DiagnosticWorkTimingSnapshot {
            lock.lock(); let values = times; lock.unlock()
            return .init(id: id, values: values)
        }
    }
    // Exact completion of one accepted job, including its main-owner callback.
    // One waiter per job keeps test-only storage bounded; rejected frames have no job.
    @MainActor private final class DiagnosticWorkCompletion {
        enum WaitError: Error { case alreadyWaiting, missingOperation }
        let timing = DiagnosticWorkTiming()
        private var finished = false
        private var waiter: CheckedContinuation<Void, Never>?
        func wait() async throws {
            if finished { return }
            guard waiter == nil else { throw WaitError.alreadyWaiting }
            await withCheckedContinuation { waiter = $0 }
        }
        func finish() {
            guard !finished else { return }
            finished = true
            let pending = waiter; waiter = nil
            pending?.resume()
        }
    }
    private var diagnosticWorkCompletion: (UUID, DiagnosticWorkCompletion)?
    func diagnosticLastWorkTimingForTesting() -> DiagnosticWorkTimingSnapshot? {
        guard let completion = diagnosticWorkCompletion else { return nil }
        return completion.1.timing.snapshot(id: completion.0)
    }
    func waitForCurrentWorkForTesting() async throws {
        guard let id = workID else { return }
        guard let completion = diagnosticWorkCompletion, completion.0 == id else {
            throw DiagnosticWorkCompletion.WaitError.missingOperation
        }
        try await completion.1.wait()
    }
#endif
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
    init(clock: @escaping () -> Double = { ProcessInfo.processInfo.systemUptime },
         queue: DispatchQueue = DispatchQueue(label: "blind.observed-scene", qos: .utility)) {
        self.clock = clock; self.queue = queue
    }
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
    /// Busy frames are intentionally dropped: the accumulator has exactly one owned worker.
    /// The receipt reports admission only, never successful processing or clearance.
    @discardableResult func offer(_ observation: Observation, session: UUID, floor: Double?,
               body: BodyEnvelope?, now: Double, hazard: Hazard = .uncertain) -> Bool {
        guard self.session == session, let worker, workID == nil,
              observation.timestamp > minimumCapture,
              observation.timestamp - lastOffered >= 0.1 else { return false }
        // Validate before updating cadence; a rejected future/NaN timestamp must
        // never poison lastOffered and prevent later valid captures recovering.
        guard observation.timestamp.isFinite, observation.timestamp >= 0, now.isFinite,
              now >= observation.timestamp, now - observation.timestamp <= 0.5 else {
            plan = nil; liveStatus = "stale"; onChange?(); return false
        }
        lastOffered = observation.timestamp
        let id = UUID(), generation = epoch, intent = intent, goal = goalRevision, bodyVersion = bodyRevision
        workID = id
#if DEBUG
        let completion = DiagnosticWorkCompletion()
        let timing = completion.timing
        timing.mark(.admitted)
        diagnosticWorkCompletion = (id, completion)
#endif
        queue.async { [weak self] in
#if DEBUG
            timing.mark(.workerStarted)
#endif
            worker.scene.setIntent(intent, revision: goal)
            let snapshot = worker.scene.observe(observation, sessionID: session, now: now, hazard: hazard)
            let plan = body.flatMap { worker.scene.planCurrent(floor: floor, body: $0, now: now) }
#if DEBUG
            timing.mark(.workerFinished)
#endif
            DispatchQueue.main.async { [weak self] in
#if DEBUG
                timing.mark(.mainDelivered)
                // Captured independently of weak self: stale/rejected/deallocated
                // owner exits still complete the exact admitted operation.
                defer { completion.finish() }
#endif
                guard let self, self.workID == id else { return }
                self.workID = nil
                guard self.epoch == generation, self.session == session, self.goalRevision == goal, self.bodyRevision == bodyVersion else { return }
                self.snapshot = snapshot; self.plan = plan
                self.liveStatus = snapshot.status == .observing
                    ? (body == nil ? "bodyEnvelopeUnavailable" : plan?.local.state.rawValue ?? snapshot.returnState.rawValue) : snapshot.status.rawValue
                self.revalidate(now: self.clock()); self.onChange?()
            }
        }
        return true
    }
}
