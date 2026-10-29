#if DEBUG && os(iOS) && canImport(ARKit)
import ARKit
import AVFoundation
import Foundation
import UIKit
import MeshSnapshot82
import MeshBufferDecoder81
import MeshCandidateIngress83
import BlindRoomMesh

/// Deliberate helper-only owner. The caller must first stop the normal camera,
/// recovery/watchdog, RoomPlan and every source that can restart this same session.
/// Handoff is enforced by the app owner, never inferred from an ARSession flag.
/// This deliberate seated bench mode has NO phone hazard monitoring or guidance.
public final class LiveMeshBenchSession {
    public enum State: Equatable { case prepared, capturing, draining, stopped(restored: Bool) }
    public enum Failure: Error { case wrongOwner, unavailable, alreadyStarted }
    public static let requiredWarning = "Seated mesh diagnostic only. Phone hazard monitoring is unavailable. Do not walk using this mode."
    private var lifecycle: State = .prepared
    public var state: State {
        dispatchPrecondition(condition: .onQueue(.main)); return lifecycle
    }
    public let phoneMonitoringAvailable = false
    public let authorizesPhysicalGuidance = false
    private let session: ARSession
    private weak var previousDelegate: (any ARSessionDelegate)?
    private let previousQueue: DispatchQueue?
    private let producerQueue: DispatchQueue
    private let producer: Producer
    private var backgroundObserver: NSObjectProtocol?
    private var onStopped: ((Bool) -> Void)?
    private var reacquisitionRequestPending = false

    /// Prepares an already stopped, exclusively handed-off session; it never creates
    /// another ARSession. No run/camera permission request occurs during preparation.
    /// Expected identity prevents silently taking a different owner's session.
    public init(stoppedSession session: ARSession, expectedDelegate: any ARSessionDelegate,
                onStopped: @escaping (Bool) -> Void) throws {
        dispatchPrecondition(condition: .onQueue(.main))
        guard session.delegate === expectedDelegate else { throw Failure.wrongOwner }
        self.session = session; previousDelegate = expectedDelegate; previousQueue = session.delegateQueue
        self.onStopped = onStopped
        let queue = DispatchQueue(label: "blind.mesh-bench.arkit-producer", qos: .userInitiated)
        producerQueue = queue; producer = try Producer(session: session, queue: queue)
        session.pause()
        session.delegateQueue = producerQueue; session.delegate = producer
        producer.requestStop = { [weak self] in DispatchQueue.main.async { self?.stop() } }
        backgroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification,
            object: nil, queue: .main) { [weak self] _ in self?.stop() }
    }
    /// Explicit seated warning/confirmation and exclusive handoff must precede this.
    public func activateForSeatedBench() throws {
        dispatchPrecondition(condition: .onQueue(.main))
        guard state == .prepared else { throw Failure.alreadyStarted }
        guard session.delegate === producer, session.delegateQueue === producerQueue else { throw Failure.wrongOwner }
        guard UIApplication.shared.applicationState == .active,
              AVCaptureDevice.authorizationStatus(for: .video) == .authorized,
              ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) else { throw Failure.unavailable }
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        configuration.sceneReconstruction = .meshWithClassification
        // Depth/mesh output is diagnostic only. No floor rectangle or free space is invented.
        let runStartedAt = ProcessInfo.processInfo.systemUptime
        guard producer.frameLease.begin() else { throw Failure.unavailable }
        producer.armFreshnessWatchdog()
        lifecycle = .capturing
        producerQueue.async { [producer] in producer.begin(runStartedAt: runStartedAt) }
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    /// Explicit supplied session-local test points only. Result delivery remains on
    /// main and rechecks native ownership as well as83's generation/revision token.
    public func requestPreview(start: [Float], goal: [Float], body: MeshCandidateBody,
        completion: @escaping (Result<MeshCandidateIngress83.Candidate, MeshCandidateIngress83.Failure>) -> Void) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard lifecycle == .capturing, producer.frameLease.isCurrent(), session.delegate === producer, session.delegateQueue === producerQueue else {
            stop(); completion(.failure(.unavailable)); return
        }
        producer.ingress.request(generation: producer.ingress.generation, start: start, goal: goal, body: body) { [weak self] result in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.lifecycle == .capturing, self.producer.frameLease.isCurrent(),
                      self.session.delegate === self.producer, self.session.delegateQueue === self.producerQueue else {
                    self?.stop(); completion(.failure(.stale)); return
                }
                if case .success(let candidate) = result, !self.isCurrent(candidate) {
                    completion(.failure(.stale)); return
                }
                completion(result)
            }
        }
    }
    public func isCurrent(_ candidate: MeshCandidateIngress83.Candidate) -> Bool {
        dispatchPrecondition(condition: .onQueue(.main))
        guard lifecycle == .capturing, producer.frameLease.isCurrent(), session.delegate === producer, session.delegateQueue === producerQueue else { return false }
        return producer.ingress.isCurrent(candidate, generation: producer.ingress.generation)
    }
    /// Native source inspection is separate from the strict route request. Neither
    /// a recent camera frame nor an installed revision proves fresh mesh capture.
    public func requestSourceSnapshot(completion: @escaping (Result<MeshCandidateIngress83.SourceSnapshot, MeshCandidateIngress83.SourceSnapshotFailure>) -> Void) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard lifecycle == .capturing, producer.frameLease.isCurrent(),
              session.delegate === producer, session.delegateQueue === producerQueue else {
            completion(.failure(.unavailable)); return
        }
        producer.ingress.requestSourceSnapshot(generation: producer.ingress.generation) { [weak self] result in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.lifecycle == .capturing, self.producer.frameLease.isCurrent(),
                      self.session.delegate === self.producer, self.session.delegateQueue === self.producerQueue else {
                    completion(.failure(.stale)); return
                }
                if case .success(let snapshot) = result, !self.isCurrent(snapshot) {
                    completion(.failure(.stale)); return
                }
                completion(result)
            }
        }
    }
    public var hasCurrentTrackedSession: Bool {
        dispatchPrecondition(condition: .onQueue(.main))
        return lifecycle == .capturing && producer.frameLease.isCurrent() &&
            session.delegate === producer && session.delegateQueue === producerQueue
    }
    public func isCurrent(_ snapshot: MeshCandidateIngress83.SourceSnapshot) -> Bool {
        dispatchPrecondition(condition: .onQueue(.main))
        return lifecycle == .capturing && producer.frameLease.isCurrent() &&
            session.delegate === producer && session.delegateQueue === producerQueue &&
            producer.ingress.isCurrent(snapshot, generation: producer.ingress.generation)
    }
    /// Explicit bounded re-read of CURRENT frame anchors, not a retained old native
    /// buffer or an expectation that unchanged anchors will emit another update.
    public func reacquireTrackedFrameAnchors() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard lifecycle == .capturing, session.delegate === producer, session.delegateQueue === producerQueue else { stop(); return }
        guard !reacquisitionRequestPending else { return }
        reacquisitionRequestPending = true
        let requestedAt = ProcessInfo.processInfo.systemUptime
        producerQueue.async { [weak self, producer] in
            producer.requestReacquisition(at: requestedAt)
            DispatchQueue.main.async { [weak self] in self?.reacquisitionRequestPending = false }
        }
    }
    public func requestStatus(completion: @escaping (String) -> Void) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard lifecycle == .capturing, session.delegate === producer, session.delegateQueue === producerQueue else {
            stop(); completion("Stopped or camera ownership lost. Geometry retired."); return
        }
        producerQueue.async { [producer] in
            let text = producer.diagnosticStatus()
            DispatchQueue.main.async { completion(text) }
        }
    }
    public func stop() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard state != .draining else { return }
        if case .stopped = state { return }
        lifecycle = .draining
        producer.frameLease.stop()
        producer.ingress.stop() // Immediate cross-queue fence before pause or drains.
        let ownsSession = session.delegate === producer && session.delegateQueue === producerQueue
        if ownsSession { session.pause() }
        if let backgroundObserver { NotificationCenter.default.removeObserver(backgroundObserver) }
        backgroundObserver = nil
        // Keep the exact stopped producer installed until drain; no nil-delegate ABA window.
        producerQueue.async { [self] in
            producer.end()
            producer.ingress.stopAndDiscard { [self] in
                // Completion means owned decode/native jobs drained. One additional
                // producer turn fences callbacks queued before the discard completion.
                producerQueue.async { [self] in
                    DispatchQueue.main.async { [self] in
                        let stillOwned = session.delegate === producer && session.delegateQueue === producerQueue
                        if stillOwned {
                            session.delegate = previousDelegate; session.delegateQueue = previousQueue
                        }
                        lifecycle = .stopped(restored: stillOwned)
                        let callback = onStopped; onStopped = nil; callback?(stillOwned)
                        // Never session.run: restoration is not permission to restart monitoring.
                    }
                }
            }
        }
    }
    deinit {
        // A dropped controller must not leave the camera running without a delegate.
        // Own retained references, not self, survive the asynchronous terminal drain.
        let session = session, producer = producer, queue = producerQueue
        let priorDelegate = previousDelegate, priorQueue = previousQueue
        let callback = onStopped
        producer.frameLease.stop(); producer.ingress.stop()
        if let backgroundObserver { NotificationCenter.default.removeObserver(backgroundObserver) }
        DispatchQueue.main.async {
            if session.delegate === producer, session.delegateQueue === queue { session.pause() }
            queue.async {
                producer.end()
                producer.ingress.stopAndDiscard {
                    queue.async {
                        DispatchQueue.main.async {
                            let stillOwned = session.delegate === producer && session.delegateQueue === queue
                            if stillOwned {
                                session.delegate = priorDelegate; session.delegateQueue = priorQueue
                            }
                            callback?(stillOwned)
                        }
                    }
                }
            }
        }
    }
    // Native ownership fixtures use the actual ARSession without activating it.
    var producerQueueForTesting: DispatchQueue { producerQueue }

    private final class Producer: NSObject, ARSessionDelegate {
        let ingress: LiveMeshBenchIngress
        let frameLease = MeshBenchFrameLease()
        private var reacquisition = MeshBenchReacquisition()
        private var reacquisitionRequestedAt: Double?
        private weak var expectedSession: ARSession?
        private let queue: DispatchQueue
        private var begun = false
        private var ended = false
        private var sawNormalTracking = false
        private var lastFrameReceipt: Double?
        private var lastFrameCapture: Double?
        private var beganAt: Double = 0
        private var callbackBudget = MeshBenchCallbackBudget()
        private var watchdog: DispatchSourceTimer?
        var requestStop: (() -> Void)? // Set before activation; never mutated afterward.
        private let limits = MeshBufferDecoder.Limits(vertices: 32_000, faces: 32_000,
            inputBytes: 1_500_000, decodedBytes: 1_500_000)
        init(session: ARSession, queue: DispatchQueue) throws {
            expectedSession = session; self.queue = queue; ingress = try LiveMeshBenchIngress(recoveryPolicy: .latestValidatedAnchorRevision)
            super.init()
        }
        func armFreshnessWatchdog() {
            dispatchPrecondition(condition: .onQueue(.main))
            // Independent of producer/native-copy work. Expiry fences source and
            // route publication immediately even if a callback is still decoding.
            let timer = DispatchSource.makeTimerSource(queue: DispatchQueue(label: "blind.mesh-bench.freshness", qos: .utility))
            timer.schedule(deadline: .now() + 0.1, repeating: 0.1)
            timer.setEventHandler { [weak self] in
                guard let self, self.frameLease.claimRetirementNotification() else { return }
                self.ingress.stop(); self.requestStop?()
            }
            watchdog = timer; timer.resume()
        }
        func begin(runStartedAt: Double) {
            dispatchPrecondition(condition: .onQueue(queue))
            guard !begun, !ended else { return }
            begun = true; beganAt = runStartedAt

        }
        func end() {
            dispatchPrecondition(condition: .onQueue(queue))
            ended = true; frameLease.stop(); reacquisition.cancel(); reacquisitionRequestedAt = nil
            watchdog?.cancel(); watchdog = nil; ingress.stop()
        }
        private func accepts(_ session: ARSession) -> Bool {
            dispatchPrecondition(condition: .onQueue(queue))
            guard begun, !ended, !frameLease.isRetired(), session === expectedSession else { return false }
            guard session.delegate === self, session.delegateQueue === queue else { failClosed(); return false }
            return true
        }
        private func failClosed() {
            guard !ended else { return }
            end(); if frameLease.claimRetirementNotification() { requestStop?() }
        }
        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            guard accepts(session) else { return }
            let now = ProcessInfo.processInfo.systemUptime
            let normal: Bool
            if case .normal = frame.camera.trackingState { normal = true } else { normal = false }
            guard frameLease.observe(capturedAt: frame.timestamp, normal: normal) else { failClosed(); return }
            guard frame.timestamp.isFinite, frame.timestamp >= beganAt,
                  now >= frame.timestamp, now - frame.timestamp <= 0.5,
                  lastFrameCapture.map({ frame.timestamp > $0 }) ?? true else { failClosed(); return }
            lastFrameReceipt = now; lastFrameCapture = frame.timestamp
            let firstNormalFrame = normal && !sawNormalTracking
            if case .normal = frame.camera.trackingState { sawNormalTracking = true }
            else if sawNormalTracking { failClosed() }
            if firstNormalFrame {
                guard frame.anchors.count <= 128 else { failClosed(); return }
                // Establish omissions for every currently tracked mesh before any
                // route can call its delivered subset complete. No buffer copied.
                let meshes = frame.anchors.compactMap { $0 as? ARMeshAnchor }
                guard Set(meshes.map(\.identifier)).count == meshes.count else { failClosed(); return }
                for anchor in meshes { offer(anchor, copyAllowed: false) }
            }
            if normal { reacquire(frame: frame, now: now) }
            // No image/ARFrame escapes this callback and no camera pose becomes body pose.
        }
        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) { observe(session, anchors: anchors) }
        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) { observe(session, anchors: anchors) }
        private func observe(_ session: ARSession, anchors: [ARAnchor]) {
            guard accepts(session) else { return }
            guard anchors.count <= 128 else { failClosed(); return }
            // Pre-establishment callbacks are not adopted into this world epoch.
            // First normal frame inventories all current IDs as unresolved instead.
            guard sawNormalTracking else { return }
            if !frameIsCurrent() { failClosed(); return }
            //83's one outstanding slot does not bound sum work if it drains while
            //this callback loops. Copy at most ONE revision per callback. Rotate
            //selection to avoid always choosing the first anchor in a stable order.
            //These native references never escape this synchronous callback scope.
            let meshes = anchors.compactMap { $0 as? ARMeshAnchor }
            guard Set(meshes.map(\.identifier)).count == meshes.count else { failClosed(); return }
            _ = callbackBudget.deliver(count: meshes.count) { index, copyAllowed in offer(meshes[index], copyAllowed: copyAllowed) }
        }
        @discardableResult private func offer(_ anchor: ARMeshAnchor, copyAllowed: Bool) -> Bool {
            let id = anchor.identifier
            let normal = sawNormalTracking
            return ingress.observe(anchorID: id, generation: ingress.generation,
                receiptUptime: ProcessInfo.processInfo.systemUptime) { context in
                guard normal else { return .unknownGap(.init(context: context, anchorID: id, reason: .invalidContext)) }
                guard copyAllowed else { return .unknownGap(.init(context: context, anchorID: id, reason: .budget)) }
                guard frameIsCurrent() else {
                    failClosed(); return .unknownGap(.init(context: context, anchorID: id, reason: .invalidContext))
                }
                // THE geometry connection: synchronous native82 copy on the
                // exclusive serialized producer, existing83 decode/native worker.
                // Never async-capture an ARMeshAnchor or MTLBuffer.
                return ARKitMeshAdapter82.capture(anchor, context: context, limits: limits)
            }
        }
        func requestReacquisition(at requestedAt: Double) {
            dispatchPrecondition(condition: .onQueue(queue))
            guard begun, !ended, !reacquisition.isActive, reacquisitionRequestedAt == nil else { return }
            reacquisitionRequestedAt = requestedAt
        }
        private func reacquire(frame: ARFrame, now: Double) {
            guard reacquisitionRequestedAt != nil || reacquisition.isActive else { return }
            // Apple ARFrame.anchors is the current frame's tracked/detected anchor
            // list. Retain only IDs between callbacks; native geometry never escapes.
            guard frame.anchors.count <= 128 else { failClosed(); return }
            let meshes = frame.anchors.compactMap { $0 as? ARMeshAnchor }
            guard Set(meshes.map(\.identifier)).count == meshes.count else { failClosed(); return }
            if let requestedAt = reacquisitionRequestedAt {
                reacquisitionRequestedAt = nil
                guard now >= requestedAt, now - requestedAt <= 8 else { return }
                if reacquisition.request(anchorIDs: meshes.map(\.identifier), frameCapturedAt: frame.timestamp, now: now) {
                    // Every requested anchor is an obligation immediately, including
                    // stable anchors not yet visited by the one-copy-per-frame pass.
                    for anchor in meshes { offer(anchor, copyAllowed: false) }
                }
                return // At most one later fresh-frame offer; never a seed-frame burst.
            }
            guard let id = reacquisition.next(presentIDs: Set(meshes.map(\.identifier)), frameCapturedAt: frame.timestamp, now: now),
                  let anchor = meshes.first(where: { $0.identifier == id }) else { return }
            let accepted = offer(anchor, copyAllowed: true)
            reacquisition.recordAdmission(anchorID: id, accepted: accepted, now: ProcessInfo.processInfo.systemUptime)
        }
        func diagnosticStatus() -> String {
            dispatchPrecondition(condition: .onQueue(queue))
            let lease = frameLease.receipt()
            let refresh = reacquisition.receipt(now: ProcessInfo.processInfo.systemUptime)
            let pending = refresh.anchors.filter { $0.reason != .admitted }.map { "\($0.id):\($0.reason.rawValue),attempts=\($0.attempts)" }.joined(separator: "; ")
            return "Frame lease: \(lease.phase); reason: \(String(describing: lease.reason)). Bounded refresh: \(refresh.status); seed count \(refresh.inputAnchorCount), rejection \(String(describing: refresh.rejectionReason)), rejected count \(String(describing: refresh.rejectedCount)); requested \(refresh.requested), admitted \(refresh.admitted), pending \(refresh.pending), exhausted \(refresh.exhausted). Admission is not install or capture freshness. Pending: \(pending)"
        }
        private func frameIsCurrent() -> Bool {
            guard frameLease.isCurrent() else { return false }
            let now = ProcessInfo.processInfo.systemUptime
            guard let captured = lastFrameCapture, let received = lastFrameReceipt,
                  now >= captured, now - captured <= 0.5,
                  now >= received, now - received <= 0.5 else { return false }
            return true
        }
        func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
            guard accepts(session), sawNormalTracking else { return }
            guard anchors.count <= 128 else { failClosed(); return }
            for case let anchor as ARMeshAnchor in anchors {
                _ = ingress.remove(anchorID: anchor.identifier, generation: ingress.generation,
                    receiptUptime: ProcessInfo.processInfo.systemUptime)
            }
        }
        func session(_ session: ARSession, didFailWithError error: Error) { if accepts(session) { failClosed() } }
        func sessionWasInterrupted(_ session: ARSession) { if accepts(session) { failClosed() } }
        func sessionInterruptionEnded(_ session: ARSession) { /* Never restart an interrupted generation. */ }
    }
}
#endif
