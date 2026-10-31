#if DEBUG && BLIND_MESH_CANDIDATE_DIAGNOSTICS
import ARKit
import Combine
import SceneKit
import UIKit
import simd
import LiveMeshClassifiedBench
import MeshCandidateIngress83
import BlindRoomMesh
import BlindCore

/// Internal injection seam for synthetic hosted integration tests. Production is
/// the existing exclusive AR owner; tests still use actual ingress/native routes.
protocol SeatedMeshDiagnosticBackend: AnyObject {
    var state: LiveMeshBenchSession.State { get }
    var hasCurrentTrackedSession: Bool { get }
    func prepareSavedWorld(_ seed:LiveMeshBenchSession.SavedWorldSeed) throws
    func activateForSeatedBench() throws
    func stop()
    func reacquireTrackedFrameAnchors()
    func requestStatus(completion: @escaping (String) -> Void)
    func requestSourceSnapshot(completion: @escaping (Result<MeshCandidateIngress83.SourceSnapshot, MeshCandidateIngress83.SourceSnapshotFailure>) -> Void)
    func isCurrent(_ source: MeshCandidateIngress83.SourceSnapshot) -> Bool
    func isCurrent(_ candidate: MeshCandidateIngress83.Candidate) -> Bool
    func isCurrent(_ capture: LiveMeshBenchSession.CameraCapture) -> Bool
    func freezeCameraCapture() -> LiveMeshBenchSession.CameraCapture?
    func retireCameraCapture()
    // Only the SAME exclusive owner may supply its restored-world recovery. A
    // normal-owner association cannot survive this bench's resetTracking handoff.
    func savedFrameAssociation(for capture: LiveMeshBenchSession.CameraCapture, now: Double) -> SavedWorldFrameCameraAssociation?
    func isCurrent(_ association: SavedWorldFrameCameraAssociation,
                   capture: LiveMeshBenchSession.CameraCapture, now: Double) -> Bool
    func requestPreview(start: [Float], goal: [Float], body: MeshCandidateBody,
        capture: LiveMeshBenchSession.CameraCapture?, expectedSource: MeshCandidateIngress83.SourceSnapshot?,
        completion: @escaping (Result<MeshCandidateIngress83.Candidate, MeshCandidateIngress83.Failure>) -> Void)
}
extension SeatedMeshDiagnosticBackend {
    func prepareSavedWorld(_ seed:LiveMeshBenchSession.SavedWorldSeed) throws {throw LiveMeshBenchSession.Failure.unavailable}
    func savedFrameAssociation(for capture: LiveMeshBenchSession.CameraCapture, now: Double) -> SavedWorldFrameCameraAssociation? { nil }
    func isCurrent(_ association: SavedWorldFrameCameraAssociation,
                   capture: LiveMeshBenchSession.CameraCapture, now: Double) -> Bool { false }
}
// A verified optional seed is installed only before activation. Without that seed,
// this owner still creates a new unregistered world; no default identity alignment.
extension LiveMeshBenchSession: SeatedMeshDiagnosticBackend {}

/// Helper display owner only. No model context, persistence, speech, haptics or
/// mobility ticket is produced here. Camera pose is deliberately not a body pose.
final class SeatedMeshDiagnosticController: ObservableObject {
    @Published private(set) var scene: SCNScene?
    @Published private(set) var sourceReceipt = "Waiting for a normal tracked frame and admitted source geometry."
    @Published private(set) var producerReceipt = "No bounded refresh requested."
    @Published private(set) var routeReceipt = "WITHHELD — no current source snapshot or supplied test endpoints."
    @Published private(set) var anchorReceipts: [String] = []
    @Published private(set) var routePointReceipts: [String] = []
    @Published private(set) var meshBoundsReceipt = "No source bounds."
    @Published private(set) var stopped = false
    struct SavedWorldRequest {
        let destination: ConnectedJourneyRuntime.DiagnosticDestination
        let source: SavedRoomDiagnosticGeometrySource
        let isCurrent: () -> Bool
    }
    private var savedWorldRequest: SavedWorldRequest?
    private var restorationPending=false
    var hasPendingRestorationForTesting:Bool {restorationPending}
    private var restoreLoader: @Sendable (SavedRoomDiagnosticGeometrySource) -> Result<LiveMeshBenchSession.SavedWorldSeed,Error> = SeatedMeshDiagnosticController.loadSavedWorld
    private final class RestoreWork {
        var source: SavedRoomDiagnosticGeometrySource?
        init(_ source:SavedRoomDiagnosticGeometrySource) {self.source=source}
    }
    private var bench: (any SeatedMeshDiagnosticBackend)?
    private var clock: () -> Double = { ProcessInfo.processInfo.systemUptime }
    private var snapshot: MeshCandidateIngress83.SourceSnapshot?
    private var candidate: MeshCandidateIngress83.Candidate?
    enum MappedGoalRefusal: String { case noDestination, captureRequired, unregisteredSource, wrongFrame, floorUnresolved, retired }
    @Published private(set) var mappedGoalRefusal: MappedGoalRefusal?
    @Published private(set) var hierarchyReceipt = "No mapped goal association. Current world/place/building/floor/room unknown."
    private var destinationProvider: () -> ConnectedJourneyRuntime.DiagnosticDestination? = { nil }
    private var collisionRequest: SeatedMeshRouteAudit.Request?
    private var collisionTask: Task<Void,Never>?
    private var collisionPending=false
    @Published private(set) var collisionAudit: SeatedMeshRouteAudit.Receipt?
    @Published private(set) var collisionReceipt="Independent collision audit not requested. No clearance claim."
    var collisionProgressForTesting: ((SeatedMeshRouteAudit.Progress) async -> Void)?
    var onCollisionDrainedForTesting: (() -> Void)?
    var hasPendingCollisionForTesting: Bool {collisionPending}
    private var epoch = UUID(), previewEpoch = UUID()
    private var previewParameters = ""
    @Published private(set) var footReceipt = "No declared body-foot candidate."
    private var footCandidate: DiagnosticBodyFootCandidate?
    private var cameraCapture: LiveMeshBenchSession.CameraCapture?
    private var footDeclaration: DiagnosticBodyFootCandidate.Declaration?
    private var sourceRequestPending = false, renderPending = false, statusPending = false, routePending = false
    private var hadTrackedSession = false
    private var isTestBackend = false
    private struct RenderRequest {
        let source: MeshCandidateIngress83.SourceSnapshot
        let phase: ((SourcePhaseForTesting) -> Void)?
    }
    private var queuedRender: RenderRequest?
    @Published private(set) var renderReceipt = "Optional visualization not started. Source admission does not depend on it."
    var hasCurrentSourceForTesting: Bool {
        guard !stopped,let snapshot,let bench else {return false}
        return bench.hasCurrentTrackedSession && bench.isCurrent(snapshot)
    }
    var hasPendingRenderForTesting: Bool {renderPending}

    private var timer: Timer?
    private let renderQueue = DispatchQueue(label: "blind.seated-mesh.render", qos: .utility)
    private var onStopped: (() -> Void)?
    private var nativeDrained = false
    var onNativeDrainForTesting: (() -> Void)?
    /// Synthetic fixture metadata only; no source values or authority escape.
    enum SourcePhaseForTesting: String {
        case source_controller_callback, source_refused, render_enqueued, render_begin, render_end
        case display_accepted, display_rejected
    }
    /// The factory freezes one scalar recorder context for this source delivery;
    /// a later source request must not rebind an earlier queued render's clock.
    var sourcePhaseRecorderForTesting: (() -> ((SourcePhaseForTesting) -> Void)?)?

    init(session: ARSession, expectedDelegate: any ARSessionDelegate,
         destinationProvider: @escaping () -> ConnectedJourneyRuntime.DiagnosticDestination? = { nil },
         savedWorldRequest: SavedWorldRequest? = nil, onStopped: @escaping () -> Void) throws {
        dispatchPrecondition(condition: .onQueue(.main))
        self.onStopped = onStopped; self.destinationProvider = destinationProvider;self.savedWorldRequest=savedWorldRequest
        bench = try LiveMeshBenchSession(stoppedSession: session, expectedDelegate: expectedDelegate) { [weak self] restored in
            guard let self else { return }
            self.retireAll()
            self.sourceReceipt = restored ? "Stopped and drained. Normal camera remains off." : "Stopped and drained; camera owner changed. No automatic restoration."
            self.bench = nil; self.nativeDrained = true
            self.onNativeDrainForTesting?()
            self.finishStopIfDrained()
        }
    }
    /// No ARSession, permissions or native-result fabrication. A test backend must
    /// produce its snapshots/routes through the real ingress; this adds no caller
    /// in the normal app and no physical authority.
    init(testBackend: any SeatedMeshDiagnosticBackend, clock: @escaping () -> Double,
         destinationProvider: @escaping () -> ConnectedJourneyRuntime.DiagnosticDestination? = { nil },
         savedWorldRequest: SavedWorldRequest? = nil,
         restoreLoader: @escaping @Sendable (SavedRoomDiagnosticGeometrySource) -> Result<LiveMeshBenchSession.SavedWorldSeed,Error> = SeatedMeshDiagnosticController.loadSavedWorld,
         onStopped: (() -> Void)? = nil) {
        self.bench = testBackend; self.clock = clock;self.onStopped=onStopped;isTestBackend=true;self.destinationProvider=destinationProvider;self.savedWorldRequest=savedWorldRequest;self.restoreLoader=restoreLoader
    }
    /// Test backend calls this ONLY after its real native stop/discard callback.
    /// It does not acknowledge pending source, render, status or route stacks.
    func acknowledgeTestBackendNativeDrainForTesting() {
        precondition(isTestBackend && stopped)
        nativeDrained=true;bench=nil;finishStopIfDrained()
    }
    private func finishStopIfDrained() {
        guard stopped, nativeDrained, !sourceRequestPending, !renderPending, !statusPending, !routePending, !collisionPending, !restorationPending else { return }
        let completion = onStopped; onStopped = nil; completion?()
    }
    /// Run after the current callback stack releases its owned source/render values.
    /// The app holds exclusive ownership until both native and display work drain.
    private func scheduleDisplayDrainCheck() {
        DispatchQueue.main.async { [weak self] in self?.finishStopIfDrained() }
    }
    private func finishRenderDelivery() {
        // This barrier must run on the SAME serial worker, after its source/scene
        // closure returns. Its main acknowledgement is also after the main delivery
        // stack. Neither closure below captures source bytes or SceneKit geometry.
        renderQueue.async { [weak self] in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.renderPending = false
                self.finishStopIfDrained()
                self.startLatestRenderIfPossible()
            }
        }
    }
    /// Native XCTest scheduler fixture only: no source snapshot, camera activation,
    /// geometry, UI publication or route is fabricated. Exercises this controller's
    /// real pending/worker/main/barrier drain using a held synthetic payload closure.
    func enqueueSyntheticDisplayWorkForTesting(work: @escaping () -> Void,
        afterEnqueue: @escaping () -> Void, delivered: @escaping () -> Void) {
        precondition(!renderPending && !stopped)
        renderPending = true
        renderQueue.async { [weak self] in
            work()
            DispatchQueue.main.async { [weak self] in
                defer { self?.finishRenderDelivery() }
                delivered()
            }
            afterEnqueue()
        }
    }
    func activate() throws {
        if let request=savedWorldRequest {
            guard !restorationPending,request.isCurrent(),destinationProvider()==request.destination else{throw LiveMeshBenchSession.Failure.unavailable}
            restorationPending=true;let token=epoch,work=RestoreWork(request.source)
            sourceReceipt="Loading paired local world/room bytes for this selected map. No camera or pose admitted yet."
            Task { @MainActor [weak self,work] in
                guard let self else {work.source=nil;return}
                await self.performSavedWorldRestore(work,epoch:token)
                work.source=nil;self.restorationPending=false
                self.scheduleDisplayDrainCheck()
            }
            return
        }
        try activatePreparedBench()
    }
    private func activatePreparedBench() throws {
        try bench?.activateForSeatedBench()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.tick() }
        tick()
    }
    static func loadSavedWorld(_ source:SavedRoomDiagnosticGeometrySource) -> Result<LiveMeshBenchSession.SavedWorldSeed,Error> {
        Result {
            guard source.memory.writeOwner==source.memoryOwner,
                  try !source.memory.isDeleted(room:source.frame.placeID) else{throw LiveMeshBenchSession.Failure.unavailable}
            let worldURL=source.url.deletingLastPathComponent().appendingPathComponent("\(source.frame.placeID).worldmap")
            let world=try SpatialMapFileStorage.readBounded(worldURL,maximumBytes:LiveMeshBenchSession.SavedWorldSeed.maximumWorldBytes)
            let room=try SpatialMapFileStorage.readBounded(source.url,maximumBytes:LiveMeshBenchSession.SavedWorldSeed.maximumRoomBytes)
            let seed=try LiveMeshBenchSession.SavedWorldSeed.decode(world:world,room:room,frame:source.frame)
            guard source.memory.writeOwner==source.memoryOwner,
                  try !source.memory.isDeleted(room:source.frame.placeID) else{throw LiveMeshBenchSession.Failure.unavailable}
            return seed
        }
    }
    @MainActor private func performSavedWorldRestore(_ work:RestoreWork,epoch token:UUID) async {
        guard let source=work.source else{return}
        let loader=restoreLoader
        let result=await Task.detached(priority:.utility) {loader(source)}.value
        guard !stopped,epoch==token else{return}
        guard let request=savedWorldRequest,request.isCurrent(),destinationProvider()==request.destination,
              request.source.frame==source.frame else {
            stop();sourceReceipt="Selected saved world changed while loading. Camera remains stopped; no stale map installed.";return
        }
        do {
            let seed=try result.get()
            guard seed.frame==request.destination.mapRevision.savedWorldFrame else{throw LiveMeshBenchSession.Failure.unavailable}
            try bench?.prepareSavedWorld(seed)
            try activatePreparedBench()
            sourceReceipt="Paired saved world installed in this exclusive owner. Waiting for its own relocalizing/origin/normal-frame evidence; location still unknown."
        } catch {
            stop();sourceReceipt="Saved world unavailable, corrupt, replaced or not supported. Camera remains stopped; no identity fallback."
        }
        // Seed/result/source locals end in this scope before caller acknowledges
        // loader disposal. Stop cannot release exclusive ownership before that.
    }
    func stop() {
        retireAll()
        sourceReceipt = "Stopping; displayed geometry erased. Waiting for owned work to drain."
        bench?.stop()
    }
    private func retireAll() {
        collisionTask?.cancel();collisionRequest=nil;collisionAudit=nil
        hierarchyReceipt="Mapped association retired; current location unknown.";mappedGoalRefusal=nil
        collisionReceipt="RETIRED — independent collision receipt erased."
        epoch = UUID(); stopped = true;savedWorldRequest=nil
        timer?.invalidate(); timer = nil
        queuedRender=nil;renderReceipt="Optional visualization retired; waiting for active display work to drain."
        footCandidate = nil; cameraCapture = nil; footDeclaration = nil; footReceipt = "Candidate erased."
        snapshot = nil; candidate = nil; scene = nil; anchorReceipts = []; routePointReceipts = []; meshBoundsReceipt = "Source bounds erased."
        routeReceipt = "WITHHELD — diagnostic stopped or session lost."
    }
    func retirePreview() {
        collisionTask?.cancel();collisionRequest=nil;collisionAudit=nil
        hierarchyReceipt="Mapped association retired; current location unknown.";mappedGoalRefusal=nil
        collisionReceipt="RETIRED — independent collision receipt erased."
        bench?.retireCameraCapture()
        footCandidate = nil; cameraCapture = nil; footDeclaration = nil; footReceipt = "Candidate retired; request a new capture-bound preview."
        previewEpoch = UUID(); candidate = nil; routePointReceipts = []
        scene?.rootNode.childNode(withName: "diagnostic-route", recursively: false)?.removeFromParentNode()
        scene?.rootNode.childNode(withName: "diagnostic-foot-candidate", recursively: false)?.removeFromParentNode()
        routeReceipt = "WITHHELD — test endpoints or body parameters changed. Request a new preview."
    }
    func reacquire() {
        guard !stopped else { return }
        retirePreview()
        producerReceipt = "Bounded refresh requested: current-frame anchors only, at most 64 anchors and 8 seconds."
        bench?.reacquireTrackedFrameAnchors()
    }
    private func tick() {
        guard !stopped, let bench else { return }
        if let request=savedWorldRequest,!request.isCurrent() {
            stop();sourceReceipt="Saved map/source ownership changed. Recovery and routes erased; explicit restart required.";return
        }
        guard bench.state == .capturing else { retireAll(); return }
        // Wait for initial tracking, but retire loss after tracking was admitted,
        // independently of whether optional SceneKit visualization ever finished.
        if bench.hasCurrentTrackedSession {hadTrackedSession=true}
        else if hadTrackedSession {retireAll();bench.stop();return}
        if let snapshot, !bench.isCurrent(snapshot) {
            self.snapshot=nil;queuedRender=nil;scene=nil
            meshBoundsReceipt="Retired source bounds erased."
            renderReceipt="RETIRED — previous optional picture erased; waiting for a current source."
            sourceReceipt="RETIRED SOURCE REVISION — waiting for a current immutable source."
        }
        if !mappedGoalIsCurrent() {
            retirePreview();refuseMappedGoal(.retired)
        }
        if cameraCapture != nil && !footIsCurrent() {
            retirePreview();routeReceipt="WITHHELD — frozen diagnostic capture or declared inputs retired. No newer frame was substituted."
        }
        if let candidate,!bench.isCurrent(candidate) {retirePreview();routeReceipt="WITHHELD — route retired by newer source, tracking or ownership."}
        if !statusPending {
            statusPending=true;let token=epoch
            bench.requestStatus { [weak self] text in
                guard let self else {return}
                self.statusPending=false
                defer {self.scheduleDisplayDrainCheck()}
                guard self.epoch == token,!self.stopped else {return}
                self.producerReceipt=text
            }
        }
        // Optional renderer is NOT a source/query admission gate.
        guard snapshot == nil,!sourceRequestPending,!routePending else {return}
        sourceRequestPending=true;let token=epoch
        bench.requestSourceSnapshot { [weak self] result in
            guard let self else {return}
            self.sourceRequestPending=false
            defer {self.scheduleDisplayDrainCheck()}
            let phase=self.sourcePhaseRecorderForTesting?()
            phase?(.source_controller_callback)
            guard self.epoch == token,!self.stopped,self.bench?.hasCurrentTrackedSession == true else {phase?(.source_refused);return}
            switch result {
            case .failure(let failure):
                phase?(.source_refused)
                self.sourceReceipt="Source snapshot withheld: \(failure). No missing area is treated as free."
            case .success(let source):
                guard self.bench?.isCurrent(source) == true else {phase?(.source_refused);return}
                self.hadTrackedSession=true
                self.snapshot=source // Actual immutable source admitted before visualization.
                self.scene=nil;self.meshBoundsReceipt="Optional bounds pending for newly admitted source."
                self.renderReceipt="Optional picture pending for current revision \(source.geometry.revision); any older picture is erased."
                self.publishSourceMetadata(source)
                self.publishMatchedRouteMetadata(source)
                self.queuedRender=RenderRequest(source:source,phase:phase) // bounded latest-only slot
                self.startLatestRenderIfPossible()
            }
        }
    }
    private func publishSourceMetadata(_ source: MeshCandidateIngress83.SourceSnapshot) {
        let g=source.geometry
        let triangles=g.anchors.reduce(0) {$0+$1.triangleIndices.count/3}
        sourceReceipt="CURRENT DELIVERY REVISION — Session \(g.sessionID), generation \(g.generation), revision \(g.revision). \(g.anchors.count) anchors, \(triangles) actual source triangles; metres, ARKit +Y up. Source delivery complete: \(g.sourceDeliveryComplete). Mesh capture time unavailable; physical coverage unknown. Gaps: \(g.unknownCoverage.joined(separator:", ")). Optional visualization is separate."
        anchorReceipts=g.anchorDelivery.map {r in
            "Anchor \(r.anchorID): required \(r.requiredRevision), installed \(r.installedRevision.map(String.init) ?? "none"), unresolved through \(r.unresolvedThroughRevision.map(String.init) ?? "none"), issue \(r.issue?.rawValue ?? "none"), removed \(r.removed). Receipt uptime \(r.receiptUptime); capture time unavailable."
        }
    }
    private func routeMatches(_ source: MeshCandidateIngress83.SourceSnapshot) -> Bool {
        guard let candidate,bench?.isCurrent(source) == true,bench?.isCurrent(candidate) == true else {return false}
        let g=source.geometry,r=candidate.route
        return SeatedMeshProjection.matches(source:.init(session:g.sessionID,generation:g.generation,revision:g.revision),
            route:.init(session:r.sessionID,generation:r.generation,revision:r.revision),sourceCurrent:true,routeCurrent:true)
            && (cameraCapture == nil || footIsCurrent()) && mappedGoalIsCurrent()
    }
    private func publishMatchedRouteMetadata(_ source: MeshCandidateIngress83.SourceSnapshot) {
        guard routeMatches(source),let candidate else {
            routePointReceipts=[]
            routeReceipt="WITHHELD — no current same-source route association. Supplied test endpoints required. No safe-path claim."
            return
        }
        startCollisionAudit(source:source,candidate:candidate)
        routePointReceipts=candidate.route.points.prefix(256).enumerated().map {index,p in
            "Diagnostic point \(index): X \(p[0]), Y \(p[1]), Z \(p[2]) metres."
        }
        routeReceipt="AVAILABLE SOURCE-ONLY DIAGNOSTIC — \(candidate.route.points.count) points; revision \(candidate.route.revision). Strict supplied XZ gate; \(previewParameters). Body location, connectors, current support and obstacle clearance NOT verified. NOT walking guidance. Optional picture may still be pending."
    }
    private func startLatestRenderIfPossible() {
        guard !stopped,!renderPending,let request=queuedRender else {return}
        queuedRender=nil
        guard let snapshot,bench?.isCurrent(request.source) == true,
              snapshot.geometry.sessionID == request.source.geometry.sessionID,
              snapshot.geometry.generation == request.source.geometry.generation,
              snapshot.geometry.revision == request.source.geometry.revision else {return}
        renderPending=true;let token=epoch,source=request.source,phase=request.phase
        renderReceipt="Optional visualization pending. Source/query readiness does not wait for it."
        phase?(.render_enqueued)
        renderQueue.async { [weak self] in
            phase?(.render_begin)
            let rendered=SeatedMeshRenderer.makeScene(source.geometry)
            phase?(.render_end)
            DispatchQueue.main.async { [weak self] in
                guard let self else {return}
                defer {self.finishRenderDelivery()}
                guard self.epoch == token,!self.stopped,self.bench?.hasCurrentTrackedSession == true,
                      self.bench?.isCurrent(source) == true,let current=self.snapshot,
                      current.geometry.sessionID == source.geometry.sessionID,
                      current.geometry.generation == source.geometry.generation,
                      current.geometry.revision == source.geometry.revision else {phase?(.display_rejected);return}
                guard let rendered else {phase?(.display_rejected);self.renderReceipt="Optional visualization unavailable; source admission is unchanged.";return}
                self.scene=rendered.scene;self.meshBoundsReceipt=rendered.bounds
                self.renderReceipt="Optional source picture rendered for revision \(source.geometry.revision). Not physical clearance."
                phase?(.display_accepted)
                // Render consumers never overwrite authoritative snapshot or route metadata.
                if self.routeMatches(source),let candidate=self.candidate,let line=SeatedMeshRenderer.route(candidate.route.points) {
                    self.applyCollisionStyle(line,source:source)
                    rendered.scene.rootNode.addChildNode(line)
                    if let foot=self.footCandidate {
                        let marker=SCNNode(geometry:SCNSphere(radius:0.025));marker.name="diagnostic-foot-candidate"
                        marker.geometry?.firstMaterial?.diffuse.contents=UIColor.systemYellow
                        let p=foot.requestedFoot;marker.position=SCNVector3(Float(p.x),Float(p.y),Float(p.z))
                        rendered.scene.rootNode.addChildNode(marker)
                    }
                }
            }
        }
    }
    private final class CollisionWork {
        var source: MeshCandidateIngress83.SourceSnapshot?
        var candidate: MeshCandidateIngress83.Candidate?
        init(source: MeshCandidateIngress83.SourceSnapshot,candidate: MeshCandidateIngress83.Candidate) {
            self.source=source;self.candidate=candidate
        }
        func clear() {source=nil;candidate=nil}
    }
    @MainActor private func performCollisionAudit(_ work: CollisionWork,request: SeatedMeshRouteAudit.Request,
                                                  epoch: UUID,preview: UUID) async -> Result<SeatedMeshRouteAudit.Receipt,Error> {
        guard let source=work.source,let candidate=work.candidate else {return .failure(SeatedMeshRouteAudit.Failure.retired)}
        let current: () -> Bool = { [weak self] in
            guard let self else {return false}
            return !self.stopped && self.epoch == epoch && self.previewEpoch == preview
                && self.collisionRequest == request && self.bench?.isCurrent(source) == true
                && self.bench?.isCurrent(candidate) == true
                && (self.cameraCapture == nil || self.footIsCurrent()) && self.mappedGoalIsCurrent()
        }
        do {return .success(try await SeatedMeshRouteAudit.run(source:source.geometry,route:candidate.route,request:request,isCurrent:current,progress:collisionProgressForTesting))}
        catch {return .failure(error)}
        // This scope, its source-copy locals and currentness closure end before
        // the caller clears the work box and acknowledges ownership drain.
    }
    private func startCollisionAudit(source: MeshCandidateIngress83.SourceSnapshot, candidate: MeshCandidateIngress83.Candidate) {
        guard !collisionPending, let request=collisionRequest else {
            collisionReceipt = "UNAVAILABLE — no explicit body/margin request or prior audit still draining."; return
        }
        let epoch=self.epoch,preview=self.previewEpoch,work=CollisionWork(source:source,candidate:candidate)
        collisionPending=true
        collisionReceipt="PENDING — original-source body and margin sweeps; no clearance claim."
        collisionTask=Task { @MainActor [weak self,work] in
            guard let self else {work.clear();return}
            defer {
                work.clear();self.collisionPending=false;self.collisionTask=nil
                self.onCollisionDrainedForTesting?()
                self.scheduleDisplayDrainCheck()
            }
            let answer=await self.performCollisionAudit(work,request:request,epoch:epoch,preview:preview)
            let sourceCurrent=work.source.map {self.bench?.isCurrent($0) == true} ?? false
            let routeCurrent=work.candidate.map {self.bench?.isCurrent($0) == true} ?? false
            work.clear() // No raw source or query world retained by final delivery.
            guard !Task.isCancelled,!self.stopped,self.epoch == epoch,self.previewEpoch == preview,
                  self.collisionRequest == request,sourceCurrent,routeCurrent,self.mappedGoalIsCurrent(),
                  self.cameraCapture == nil || self.footIsCurrent() else {
                if !self.stopped,self.epoch == epoch,self.previewEpoch == preview,self.collisionRequest == request {
                    self.collisionAudit=nil;self.collisionReceipt="RETIRED — source or capture changed before audit delivery."
                }
                return
            }
            switch answer {
            case .success(let result):
                self.collisionAudit=result;self.collisionReceipt=result.text
                if let line=self.scene?.rootNode.childNode(withName:"diagnostic-route",recursively:false),let source=self.snapshot {
                    self.applyCollisionStyle(line,source:source)
                }
            case .failure:
                self.collisionAudit=nil
                self.collisionReceipt="UNAVAILABLE — independent collision backend, budget or source check failed. Not clear."
            }
        }
    }
    private func applyCollisionStyle(_ line:SCNNode,source:MeshCandidateIngress83.SourceSnapshot) {
        guard let audit=collisionAudit,audit.request == collisionRequest,
              audit.session == source.geometry.sessionID,audit.generation == source.geometry.generation,
              audit.revision == source.geometry.revision else {return}
        if audit.raw.contains(where:{$0.blocked}) {line.geometry?.firstMaterial?.diffuse.contents=UIColor.systemRed}
        else if audit.margin.contains(where:{$0.blocked}) {line.geometry?.firstMaterial?.diffuse.contents=UIColor.systemOrange}
        // No green/safe styling; absence of surface contact is not clearance.
    }
    private func refuseMappedGoal(_ reason: MappedGoalRefusal) {
        mappedGoalRefusal=reason
        hierarchyReceipt="UNREGISTERED / WITHHELD: \(reason.rawValue). Selected destination is not current room/floor. No inferred transform or physical guidance."
        routeReceipt="WITHHELD — mapped destination: \(reason.rawValue). Local test-coordinate mode remains separate."
    }
    private func mappedGoalIsCurrent() -> Bool {
        guard let mapped=collisionRequest?.mappedGoal else { return true }
        guard destinationProvider() == mapped.destination, let capture=cameraCapture,
              capture.snapshot == mapped.cameraRequest, capture.frame == mapped.cameraFrame,
              capture.session == mapped.association.sessionID,
              capture.capturedAt == mapped.association.capturedAt,
              bench?.isCurrent(capture) == true else { return false }
        return bench?.isCurrent(mapped.association,capture:capture,now:clock()) == true
    }
    private func footIsCurrent() -> Bool {
        guard let footCandidate, let cameraCapture, let footDeclaration,
              bench?.isCurrent(cameraCapture) == true else { return false }
        return footCandidate.isCurrent(capture: Self.coreCapture(cameraCapture), source: footCandidate.source,
            declaration: footDeclaration, now: clock())
    }
    private static func coreCapture(_ c: LiveMeshBenchSession.CameraCapture) -> DiagnosticBodyFootCandidate.Capture {
        .init(session: c.session, frame: c.frame, request: c.snapshot, capturedAt: c.capturedAt,
              cameraToWorld: NativeCameraTransform(columns: c.columnMajorCameraToWorld))
    }
    func requestPreview(startText: String, goalText: String, radiusText: String, heightText: String,
                        declaredMountText: String? = nil, declaredYawText: String? = nil, confirmed: Bool = false, marginText: String? = nil, useMappedDestination: Bool = false) {
        guard !stopped, !routePending, !collisionPending, let bench, let snapshot, bench.isCurrent(snapshot) else {
            routeReceipt = "WITHHELD — no current source snapshot."; return
        }
        retirePreview()
        var proposedFoot: DiagnosticBodyFootCandidate?
        var copiedCamera: LiveMeshBenchSession.CameraCapture?
        if let declaredMountText {
            guard confirmed, let mount = Self.point(declaredMountText), let declaredYawText,
                  let degrees = Double(declaredYawText), degrees.isFinite, (-180...180).contains(degrees),
                  let profile = try? LocalBodyProfile(mount: .init(right: Double(mount[0]), up: Double(mount[1]), forward: Double(mount[2]))),
                  let capture = bench.freezeCameraCapture() else {
                routeReceipt = "WITHHELD — explicitly confirm all mount offsets and session-world body yaw; fresh camera capture required."; return
            }
            let geometry = snapshot.geometry
            let declaration = DiagnosticBodyFootCandidate.Declaration(profile: profile, bodyYaw: degrees * .pi / 180, confirmed: confirmed)
            proposedFoot = DiagnosticBodyFootCandidate(capture: Self.coreCapture(capture),
                source: .init(captureSession: capture.session, session: geometry.sessionID, generation: geometry.generation, revision: geometry.revision),
                declaration: declaration, now: clock())
            guard proposedFoot != nil else { routeReceipt = "WITHHELD — invalid or stale UNVALIDATED body-foot inputs."; return }
            copiedCamera = capture
        }
        var goal=Self.point(goalText)
        var mappedGoal: SeatedMeshRouteAudit.MappedGoal?
        if useMappedDestination {
            guard let destination=destinationProvider() else { refuseMappedGoal(.noDestination);return }
            guard proposedFoot != nil,let capture=copiedCamera else { refuseMappedGoal(.captureRequired);return }
            guard let association=bench.savedFrameAssociation(for:capture,now:clock()),
                  association.sessionID == capture.session,association.capturedAt == capture.capturedAt,
                  bench.isCurrent(association,capture:capture,now:clock()) else { refuseMappedGoal(.unregisteredSource);return }
            let revision=destination.mapRevision
            guard let frame=revision.savedWorldFrame,frame == association.frame,
                  frame.valid,revision.metersPerUnit == 1,
                  revision.binding == destination.reference.endpoint.binding,
                  revision.binding == destination.artifact.binding,
                  revision.binding.frameID == frame.frameID,revision.binding.revision == frame.revision else { refuseMappedGoal(.wrongFrame);return }
            // This slice accepts ONE explicitly bound floor only. Cross-floor
            // transitions/registered imported maps still belong to existing gates.
            guard Set(revision.floorLevels.values) == [destination.reference.endpoint.floorID] else { refuseMappedGoal(.floorUnresolved);return }
            let p=destination.position
            goal=[Float(p.x),Float(p.y),Float(p.z)] // Same restored frame; no guessed alignment.
            let g=snapshot.geometry
            mappedGoal = .init(destination:destination,association:association,
                sourceSession:g.sessionID,sourceGeneration:g.generation,sourceRevision:g.revision,
                cameraRequest:capture.snapshot,cameraFrame:capture.frame)
        }
        guard let start = proposedFoot?.queryPoint ?? Self.point(startText), let goal,
              let radius = Float(radiusText), let height = Float(heightText),
              let body = try? MeshCandidateBody(radius: radius, height: height) else {
            routeReceipt = "WITHHELD — enter finite X Y Z coordinates in metres and valid declared radius/height."; return
        }
        guard snapshot.geometry.sourceDeliveryComplete, snapshot.geometry.unknownCoverage.isEmpty else {
            routeReceipt = "WITHHELD — \(Self.coverageReason(snapshot.geometry)). Inspect anchor receipts and explicitly refresh. Missing source is not free space."; return
        }
        guard let marginText,let margin=Float(marginText) else {routeReceipt="WITHHELD — explicit diagnostic margin required (zero allowed).";return}
        let auditRequest=SeatedMeshRouteAudit.Request(id:UUID(),start:start,goal:goal,radius:radius,height:height,margin:margin,mappedGoal:mappedGoal)
        guard auditRequest.valid else {routeReceipt="WITHHELD — invalid raw/margin envelope.";return}
        collisionRequest=auditRequest
        if let mappedGoal {
            let d=mappedGoal.destination,c=d.reference.context
            hierarchyReceipt="SELECTED DESTINATION context: world \(c.worldID), place \(c.placeID), building \(c.buildingID), floor \(c.floorID), room \(c.roomID ?? "unavailable"). Artifact \(d.artifact.sha256), map/frame/revision \(d.artifact.binding). Same restored camera frame, unmeasured uncertainty. Current room/floor/body/support NOT established. Historical preview only; no physical authority."
        }
        routePending = true; let token = epoch, previewToken = previewEpoch
        footCandidate = proposedFoot; cameraCapture = copiedCamera; footDeclaration = proposedFoot?.declaration
        if let foot = proposedFoot {
            footReceipt = "\(foot.status). Frame \(foot.capture.frame), capture uptime \(foot.capture.capturedAt), source \(foot.source.session)/\(foot.source.generation)/\(foot.source.revision). Camera XYZ \(foot.cameraOrigin). Requested foot XYZ \(foot.requestedFoot). Historical preview lease ≤8 seconds; no current wearer location claim. Native association pending."
        }
        previewParameters = "declared radius \(body.radius)m, height \(body.height)m"
        routeReceipt = "WITHHELD — source-only strict query pending."
        bench.requestPreview(start: start, goal: goal, body: body, capture: copiedCamera, expectedSource: snapshot) { [weak self] result in
            guard let self else { return }
            self.routePending = false
            defer { self.scheduleDisplayDrainCheck() }
            guard self.epoch == token, self.previewEpoch == previewToken, !self.stopped else { return }
            guard self.mappedGoalIsCurrent() else {
                self.retirePreview();self.refuseMappedGoal(.retired);return
            }
            guard self.cameraCapture == nil || self.footIsCurrent() else {
                self.retirePreview(); self.routeReceipt = "WITHHELD — frozen capture explicitly replaced or expired before native delivery."; return
            }
            switch result {
            case .failure(let failure):
                if self.collisionRequest?.mappedGoal != nil {self.retirePreview();self.refuseMappedGoal(.retired)}
                self.routeReceipt = "WITHHELD — strict source query: \(failure). No physical route authority."
            case .success(let candidate):
                guard self.bench?.isCurrent(candidate) == true else {
                    if self.collisionRequest?.mappedGoal != nil {self.retirePreview();self.refuseMappedGoal(.retired)}
                    self.routeReceipt = "WITHHELD — route retired by newer source."; return
                }
                if let foot = self.footCandidate {
                    guard candidate.route.sessionID == foot.source.session,
                          candidate.route.generation == foot.source.generation,
                          let admission = candidate.route.endpointAdmission,
                          let endpoint = foot.associatedEndpoint(requested: admission.start.requested,
                            associated: admission.start.projected, found: admission.start.found, isOverPolygon: admission.start.isOverPolygon),
                          admission.start.projected == candidate.route.projectedStart else {
                        self.retirePreview(); self.routeReceipt = "WITHHELD — native endpoint did not match the requested candidate."; return
                    }
                    self.footReceipt += " Native associated start XYZ \(endpoint.associated); delta Y \(endpoint.deltaY)m; XZ residual \(endpoint.horizontalResidual)m; found \(endpoint.found), over polygon \(endpoint.isOverPolygon). Requested goal \(goal), native associated goal \(candidate.route.projectedGoal). No relocation, support or physical-start claim."
                }
                // A query intentionally advances ingress/runtime revision, retiring
                // the pre-query snapshot. Fetch a fresh matching inspection before
                // displaying the line; never weaken currentness to reuse that token.
                self.candidate = candidate; self.snapshot = nil; self.scene = nil
                self.routeReceipt = "WITHHELD — query complete; awaiting current matching source inspection."
                self.tick()
            }
        }
    }
    private static func coverageReason(_ g: MeshSourceGeometrySnapshot) -> String {
        let scoped = g.unknownCoverage.filter { $0.hasPrefix("delivery:") || $0.hasPrefix("removed:") }
        let global = g.unknownCoverage.filter { !$0.hasPrefix("delivery:") && !$0.hasPrefix("removed:") }
        return "delivery complete=\(g.sourceDeliveryComplete); global/integrity reasons=[\(global.joined(separator: ", "))]; anchor-scoped omissions/removal warnings=[\(scoped.joined(separator: ", "))]. Current policy requires all retained-source delivery complete, even for distant anchors; this does not mean the room is impassable"
    }
    private static func point(_ text: String) -> [Float]? {
        let words = text.split(whereSeparator: { $0.isWhitespace || $0 == "," })
        guard words.count == 3 else { return nil }
        let values = words.compactMap { Float($0) }
        return values.count == 3 && values.allSatisfy(\.isFinite) ? values : nil
    }
    deinit { timer?.invalidate() }
}

/// Original local values transformed once. No ScaleMaster/MuSHRoom export fix,
/// reference-room geometry, floor filling, body pose or screen-to-world guessing.
enum SeatedMeshProjection {
    struct Revision: Equatable { let session: String; let generation: Int; let revision: UInt64 }
    /// Equality is delivery association only. The caller must supply independent
    /// owner currentness checks; neither this nor the result conveys freshness.
    static func matches(source: Revision, route: Revision, sourceCurrent: Bool, routeCurrent: Bool) -> Bool {
        sourceCurrent && routeCurrent && source == route
    }
    static func worldVertices(local: [Double], transform: [Double]) -> [SCNVector3]? {
        guard local.count <= 600_000, local.count % 3 == 0, transform.count == 16,
              local.allSatisfy(\.isFinite), transform.allSatisfy(\.isFinite),
              transform[3] == 0, transform[7] == 0, transform[11] == 0, transform[15] == 1 else { return nil }
        var result: [SCNVector3] = []; result.reserveCapacity(local.count / 3)
        for i in stride(from: 0, to: local.count, by: 3) {
            let x = local[i], y = local[i + 1], z = local[i + 2]
            let p = (0..<3).map { r in Float(transform[r] * x + transform[4 + r] * y + transform[8 + r] * z + transform[12 + r]) }
            guard p.allSatisfy(\.isFinite) else { return nil }
            result.append(SCNVector3(p[0], p[1], p[2]))
        }
        return result
    }
}
private enum SeatedMeshRenderer {
    static func makeScene(_ source: MeshSourceGeometrySnapshot) -> (scene: SCNScene, bounds: String)? {
        guard source.anchors.count <= 64, source.anchors.reduce(0, { $0 + $1.localVertices.count }) <= 600_000,
              source.anchors.reduce(0, { $0 + $1.triangleIndices.count }) <= 300_000 else { return nil }
        let scene = SCNScene()
        var low = SIMD3<Float>(repeating: .infinity), high = SIMD3<Float>(repeating: -.infinity)
        for anchor in source.anchors {
            guard let positions = SeatedMeshProjection.worldVertices(local: anchor.localVertices, transform: anchor.columnMajorTransform),
                  anchor.triangleIndices.count % 3 == 0,
                  anchor.triangleIndices.allSatisfy({ $0 >= 0 && Int($0) < positions.count }),
                  anchor.normalizedSupportRoles.map({ $0.count == anchor.triangleIndices.count / 3 }) ?? true else { return nil }
            for p in positions { low = simd_min(low, SIMD3(p.x,p.y,p.z)); high = simd_max(high, SIMD3(p.x,p.y,p.z)) }
            var roles = [[Int32](), [Int32](), [Int32]()]
            for i in stride(from: 0, to: anchor.triangleIndices.count, by: 3) {
                let role = anchor.normalizedSupportRoles.map { $0[i / 3] == .floor ? 0 : 1 } ?? 2
                roles[role].append(contentsOf: anchor.triangleIndices[i..<(i + 3)])
            }
            let elements = roles.map { SCNGeometryElement(indices: $0, primitiveType: .triangles) }
            let geometry = SCNGeometry(sources: [SCNGeometrySource(vertices: positions)], elements: elements)
            geometry.materials = [UIColor.systemPurple, .systemOrange, .systemGray].map { color in
                let m = SCNMaterial(); m.diffuse.contents = color; m.lightingModel = .constant; m.isDoubleSided = true; m.fillMode = .lines; return m
            }
            let node = SCNNode(geometry: geometry); node.name = anchor.anchorID
            // Positions are already session-world. Node transform remains identity.
            scene.rootNode.addChildNode(node)
        }
        if low.x.isFinite {
            let center = (low + high) * 0.5, size = simd_length(high - low)
            guard center.x.isFinite, center.y.isFinite, center.z.isFinite, size.isFinite else { return nil }
            let camera = SCNNode(); camera.camera = SCNCamera(); camera.camera?.automaticallyAdjustsZRange = true
            let distance = max(size, 0.5)
            let position = SIMD3(center.x, center.y + distance, center.z + distance)
            guard position.x.isFinite, position.y.isFinite, position.z.isFinite else { return nil }
            camera.position = SCNVector3(position.x, position.y, position.z)
            camera.look(at: SCNVector3(center.x,center.y,center.z)); scene.rootNode.addChildNode(camera)
        }
        let bounds = low.x.isFinite
            ? "Source-only session-world bounds (metres): X [\(low.x), \(high.x)], Y [\(low.y), \(high.y)], Z [\(low.z), \(high.z)]. Extent X \(high.x-low.x), Y \(high.y-low.y), Z \(high.z-low.z) metres. Bounds are not free-space extents, passage clearance or user location."
            : "No admitted source vertices. No room dimensions invented."
        return (scene, bounds)
    }
    static func route(_ points: [[Float]]) -> SCNNode? {
        guard (2...4096).contains(points.count), points.allSatisfy({ $0.count == 3 && $0.allSatisfy(\.isFinite) }) else { return nil }
        let vertices = points.map { SCNVector3($0[0],$0[1],$0[2]) }
        let indices = (1..<points.count).flatMap { [Int32($0 - 1),Int32($0)] }
        let geometry = SCNGeometry(sources: [SCNGeometrySource(vertices: vertices)], elements: [SCNGeometryElement(indices: indices, primitiveType: .line)])
        let material = SCNMaterial(); material.diffuse.contents = UIColor.cyan; material.lightingModel = .constant; geometry.materials = [material]
        let node = SCNNode(geometry: geometry); node.name = "diagnostic-route"; return node
    }
}
#endif
