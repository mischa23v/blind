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
    func requestPreview(start: [Float], goal: [Float], body: MeshCandidateBody,
        capture: LiveMeshBenchSession.CameraCapture?, expectedSource: MeshCandidateIngress83.SourceSnapshot?,
        completion: @escaping (Result<MeshCandidateIngress83.Candidate, MeshCandidateIngress83.Failure>) -> Void)
}
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
    private var bench: (any SeatedMeshDiagnosticBackend)?
    private var clock: () -> Double = { ProcessInfo.processInfo.systemUptime }
    private var snapshot: MeshCandidateIngress83.SourceSnapshot?
    private var candidate: MeshCandidateIngress83.Candidate?
    private var epoch = UUID(), previewEpoch = UUID()
    private var previewParameters = ""
    @Published private(set) var footReceipt = "No declared body-foot candidate."
    private var footCandidate: DiagnosticBodyFootCandidate?
    private var cameraCapture: LiveMeshBenchSession.CameraCapture?
    private var footDeclaration: DiagnosticBodyFootCandidate.Declaration?
    private var snapshotPending = false, statusPending = false, routePending = false
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
    var onSourcePhaseForTesting: ((SourcePhaseForTesting) -> Void)?

    init(session: ARSession, expectedDelegate: any ARSessionDelegate, onStopped: @escaping () -> Void) throws {
        dispatchPrecondition(condition: .onQueue(.main))
        self.onStopped = onStopped
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
    init(testBackend: any SeatedMeshDiagnosticBackend, clock: @escaping () -> Double) {
        self.bench = testBackend; self.clock = clock
    }
    private func finishStopIfDrained() {
        guard stopped, nativeDrained, !snapshotPending, !statusPending, !routePending else { return }
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
                self.snapshotPending = false
                self.finishStopIfDrained()
            }
        }
    }
    /// Native XCTest scheduler fixture only: no source snapshot, camera activation,
    /// geometry, UI publication or route is fabricated. Exercises this controller's
    /// real pending/worker/main/barrier drain using a held synthetic payload closure.
    func enqueueSyntheticDisplayWorkForTesting(work: @escaping () -> Void,
        afterEnqueue: @escaping () -> Void, delivered: @escaping () -> Void) {
        precondition(!snapshotPending && !stopped)
        snapshotPending = true
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
        try bench?.activateForSeatedBench()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.tick() }
        tick()
    }
    func stop() {
        retireAll()
        sourceReceipt = "Stopping; displayed geometry erased. Waiting for owned work to drain."
        bench?.stop()
    }
    private func retireAll() {
        epoch = UUID(); stopped = true
        timer?.invalidate(); timer = nil
        footCandidate = nil; cameraCapture = nil; footDeclaration = nil; footReceipt = "Candidate erased."
        snapshot = nil; candidate = nil; scene = nil; anchorReceipts = []; routePointReceipts = []; meshBoundsReceipt = "Source bounds erased."
        routeReceipt = "WITHHELD — diagnostic stopped or session lost."
    }
    func retirePreview() {
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
        guard bench.state == .capturing else { retireAll(); return }
        if scene != nil && !bench.hasCurrentTrackedSession { retireAll(); bench.stop(); return }
        if let snapshot, !bench.isCurrent(snapshot) {
            self.snapshot = nil
            sourceReceipt = "RETIRED SOURCE REVISION — wireframe is historical inspection only, not current. Waiting for newer immutable source. " + sourceReceipt
        }
        if cameraCapture != nil && !footIsCurrent() {
            retirePreview(); routeReceipt = "WITHHELD — frozen diagnostic capture or declared inputs retired. No newer frame was substituted."
        }
        if let candidate, !bench.isCurrent(candidate) { retirePreview(); routeReceipt = "WITHHELD — route retired by newer source, tracking or ownership." }
        if !statusPending {
            statusPending = true; let token = epoch
            bench.requestStatus { [weak self] text in
                guard let self else { return }
                self.statusPending = false
                defer { self.scheduleDisplayDrainCheck() }
                guard self.epoch == token, !self.stopped else { return }
                self.producerReceipt = text
            }
        }
        guard snapshot == nil, !snapshotPending, !routePending else { return }
        snapshotPending = true; let token = epoch
        bench.requestSourceSnapshot { [weak self] result in
            guard let self else { return }
            defer { self.scheduleDisplayDrainCheck() }
            self.onSourcePhaseForTesting?(.source_controller_callback)
            guard self.epoch == token, !self.stopped else { self.onSourcePhaseForTesting?(.source_refused); self.snapshotPending = false; return }
            switch result {
            case .failure(let failure):
                self.onSourcePhaseForTesting?(.source_refused)
                self.snapshotPending = false
                self.sourceReceipt = (self.scene == nil ? "" : "RETIRED historical wireframe remains for inspection only. ") + "Source snapshot withheld: \(failure). No missing area is treated as free."
            case .success(let source):
                // One renderer task at a time. Source arrays are owned immutable
                // values; no ARFrame, ARMeshAnchor or Metal buffer enters this queue.
                let phase = self.onSourcePhaseForTesting
                phase?(.render_enqueued)
                self.renderQueue.async { [weak self] in
                    phase?(.render_begin)
                    let rendered = SeatedMeshRenderer.makeScene(source.geometry)
                    phase?(.render_end)
                    DispatchQueue.main.async { [weak self] in
                        guard let self else { return }
                        defer { self.finishRenderDelivery() }
                        guard self.epoch == token, !self.stopped, self.bench?.hasCurrentTrackedSession == true else { phase?(.display_rejected); return }
                        guard let renderResult = rendered else { phase?(.display_rejected); self.sourceReceipt = "Source geometry cannot be rendered within bounds. Whole snapshot withheld."; return }
                        let rendered = renderResult.scene
                        self.meshBoundsReceipt = renderResult.bounds
                        let current = self.bench?.isCurrent(source) == true
                        self.snapshot = current ? source : nil; self.scene = rendered
                        phase?(current ? .display_accepted : .display_rejected)
                        let g = source.geometry
                        let triangles = g.anchors.reduce(0) { $0 + $1.triangleIndices.count / 3 }
                        self.sourceReceipt = (current ? "CURRENT DELIVERY REVISION — " : "RETIRED SOURCE REVISION — historical wireframe only, not current. ") + "Session \(g.sessionID), generation \(g.generation), revision \(g.revision). \(g.anchors.count) anchors, \(triangles) actual source triangles; metres, ARKit +Y up. Source delivery complete: \(g.sourceDeliveryComplete). Mesh capture time unavailable; physical coverage unknown. Gaps: \(g.unknownCoverage.joined(separator: ", "))."
                        self.anchorReceipts = g.anchorDelivery.map { r in
                            "Anchor \(r.anchorID): required \(r.requiredRevision), installed \(r.installedRevision.map(String.init) ?? "none"), unresolved through \(r.unresolvedThroughRevision.map(String.init) ?? "none"), issue \(r.issue?.rawValue ?? "none"), removed \(r.removed). Receipt uptime \(r.receiptUptime); capture time unavailable."
                        }
                        if let candidate = self.candidate,
                           SeatedMeshProjection.matches(source: .init(session: g.sessionID, generation: g.generation, revision: g.revision),
                             route: .init(session: candidate.route.sessionID, generation: candidate.route.generation, revision: candidate.route.revision),
                             sourceCurrent: current, routeCurrent: self.bench?.isCurrent(candidate) == true),
                           self.cameraCapture == nil || self.footIsCurrent(),
                           let line = SeatedMeshRenderer.route(candidate.route.points) {
                            rendered.rootNode.addChildNode(line)
                            if let foot = self.footCandidate {
                                let marker = SCNNode(geometry: SCNSphere(radius: 0.025))
                                marker.name = "diagnostic-foot-candidate"
                                marker.geometry?.firstMaterial?.diffuse.contents = UIColor.systemYellow
                                let p = foot.requestedFoot; marker.position = SCNVector3(Float(p.x),Float(p.y),Float(p.z))
                                rendered.rootNode.addChildNode(marker)
                            }
                            self.routePointReceipts = candidate.route.points.prefix(256).enumerated().map { index, p in
                                "Diagnostic point \(index): X \(p[0]), Y \(p[1]), Z \(p[2]) metres."
                            }
                            self.routeReceipt = "AVAILABLE SOURCE-ONLY DIAGNOSTIC — \(candidate.route.points.count) points; revision \(candidate.route.revision). Strict supplied XZ gate; \(self.previewParameters). Body location, connectors, current support and obstacle clearance NOT verified. NOT walking guidance."
                        } else {
                            self.candidate = nil; self.routePointReceipts = []
                            self.routeReceipt = "WITHHELD — \(current ? Self.coverageReason(g) : "rendered source revision retired during inspection"). Supplied test endpoints required. No safe-path claim."
                        }
                    }
                }
            }
        }
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
                        declaredMountText: String? = nil, declaredYawText: String? = nil, confirmed: Bool = false) {
        guard !stopped, !routePending, let bench, let snapshot, bench.isCurrent(snapshot) else {
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
        guard let start = proposedFoot?.queryPoint ?? Self.point(startText), let goal = Self.point(goalText),
              let radius = Float(radiusText), let height = Float(heightText),
              let body = try? MeshCandidateBody(radius: radius, height: height) else {
            routeReceipt = "WITHHELD — enter finite X Y Z coordinates in metres and valid declared radius/height."; return
        }
        guard snapshot.geometry.sourceDeliveryComplete, snapshot.geometry.unknownCoverage.isEmpty else {
            routeReceipt = "WITHHELD — \(Self.coverageReason(snapshot.geometry)). Inspect anchor receipts and explicitly refresh. Missing source is not free space."; return
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
            guard self.cameraCapture == nil || self.footIsCurrent() else {
                self.retirePreview(); self.routeReceipt = "WITHHELD — frozen capture explicitly replaced or expired before native delivery."; return
            }
            switch result {
            case .failure(let failure): self.routeReceipt = "WITHHELD — strict source query: \(failure). No physical route authority."
            case .success(let candidate):
                guard self.bench?.isCurrent(candidate) == true else {
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
