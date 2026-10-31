#if DEBUG && os(iOS) && canImport(ARKit)
import ARKit
import AVFoundation
import Foundation
import UIKit
import MeshSnapshot82
import MeshBufferDecoder81
import MeshCandidateIngress83
import BlindRoomMesh

/// STAGED ONLY: not an app hook. The caller must first stop the normal camera,
/// recovery/watchdog, RoomPlan and every source that can restart this same session.
/// That handoff is NOT implemented here and is NOT inferred from an ARSession flag.
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
    /// No caller exists in the app. A future explicit warning/confirmation/handoff
    /// must precede this. This proposal does not authorize device activation.
    public func activateForSeatedBench() throws {
        dispatchPrecondition(condition: .onQueue(.main))
        guard state == .prepared else { throw Failure.alreadyStarted }
        guard session.delegate === producer, session.delegateQueue === producerQueue else { throw Failure.wrongOwner }
        guard UIApplication.shared.applicationState == .active,
              AVCaptureDevice.authorizationStatus(for: .video) == .authorized,
              ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) else { throw Failure.unavailable }
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        configuration.sceneReconstruction = ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification)
            ? .meshWithClassification : .mesh
        // Depth/mesh output is diagnostic only. No floor rectangle or free space is invented.
        lifecycle = .capturing
        producerQueue.async { [producer] in producer.begin() }
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    /// Explicit supplied session-local test points only. Result delivery remains on
    /// main and rechecks native ownership as well as83's generation/revision token.
    public func requestPreview(start: [Float], goal: [Float], body: MeshCandidateBody,
        completion: @escaping (Result<MeshCandidateIngress83.Candidate, MeshCandidateIngress83.Failure>) -> Void) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard lifecycle == .capturing, session.delegate === producer, session.delegateQueue === producerQueue else {
            stop(); completion(.failure(.unavailable)); return
        }
        producer.ingress.request(generation: producer.ingress.generation, start: start, goal: goal, body: body) { [weak self] result in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.lifecycle == .capturing,
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
        guard lifecycle == .capturing, session.delegate === producer, session.delegateQueue === producerQueue else { return false }
        return producer.ingress.isCurrent(candidate, generation: producer.ingress.generation)
    }
    public func stop() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard state != .draining else { return }
        if case .stopped = state { return }
        lifecycle = .draining
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
        producer.ingress.stop()
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
            expectedSession = session; self.queue = queue; ingress = try LiveMeshBenchIngress()
            super.init()
        }
        func begin() {
            dispatchPrecondition(condition: .onQueue(queue))
            guard !begun, !ended else { return }
            begun = true; beganAt = ProcessInfo.processInfo.systemUptime
            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(deadline: .now() + 0.25, repeating: 0.25)
            timer.setEventHandler { [weak self] in
                guard let self, !self.ended else { return }
                let now = ProcessInfo.processInfo.systemUptime
                if !self.sawNormalTracking, now - self.beganAt > 10 { self.failClosed() }
                else if let last = self.lastFrameReceipt {
                    if now - last > 0.5 { self.failClosed() }
                } else if now - self.beganAt > 10 { self.failClosed() }
            }
            watchdog = timer; timer.resume()
        }
        func end() {
            dispatchPrecondition(condition: .onQueue(queue))
            ended = true; watchdog?.cancel(); watchdog = nil; ingress.stop()
        }
        private func accepts(_ session: ARSession) -> Bool {
            dispatchPrecondition(condition: .onQueue(queue))
            guard begun, !ended, session === expectedSession else { return false }
            guard session.delegate === self, session.delegateQueue === queue else { failClosed(); return false }
            return true
        }
        private func failClosed() {
            guard !ended else { return }
            end(); requestStop?()
        }
        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            guard accepts(session) else { return }
            let now = ProcessInfo.processInfo.systemUptime
            guard frame.timestamp.isFinite, frame.timestamp >= beganAt,
                  now >= frame.timestamp, now - frame.timestamp <= 0.5,
                  lastFrameCapture.map({ frame.timestamp > $0 }) ?? true else { failClosed(); return }
            lastFrameReceipt = now; lastFrameCapture = frame.timestamp
            if case .normal = frame.camera.trackingState { sawNormalTracking = true }
            else if sawNormalTracking { failClosed() }
            // No image/ARFrame escapes this callback and no camera pose becomes body pose.
        }
        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) { observe(session, anchors: anchors) }
        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) { observe(session, anchors: anchors) }
        private func observe(_ session: ARSession, anchors: [ARAnchor]) {
            guard accepts(session) else { return }
            guard anchors.count <= 128 else { failClosed(); return }
            if sawNormalTracking, !frameIsCurrent() { failClosed(); return }
            //83's one outstanding slot does not bound sum work if it drains while
            //this callback loops. Copy at most ONE revision per callback. Rotate
            //selection to avoid always choosing the first anchor in a stable order.
            //These native references never escape this synchronous callback scope.
            let meshes = anchors.compactMap { $0 as? ARMeshAnchor }
            func offer(_ anchor: ARMeshAnchor, copyAllowed: Bool) {
                let id = anchor.identifier
                let normal = sawNormalTracking
                _ = ingress.observe(anchorID: id, generation: ingress.generation,
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
            _ = callbackBudget.deliver(count: meshes.count) { index, copyAllowed in offer(meshes[index], copyAllowed: copyAllowed) }
        }
        private func frameIsCurrent() -> Bool {
            let now = ProcessInfo.processInfo.systemUptime
            guard let captured = lastFrameCapture, let received = lastFrameReceipt,
                  now >= captured, now - captured <= 0.5,
                  now >= received, now - received <= 0.5 else { return false }
            return true
        }
        func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
            guard accepts(session) else { return }
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
