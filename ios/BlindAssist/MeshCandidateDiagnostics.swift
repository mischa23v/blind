#if DEBUG && BLIND_MESH_CANDIDATE_DIAGNOSTICS
import Foundation
import ARKit
import BlindCore
import BlindRoomMesh
import MeshCandidateIngress83
import MeshSnapshot82
import MeshBufferDecoder81

/// Explicit, nonphysical normal-camera diagnostic. Reuses 82/83/75 and the
/// shared SceneKit collider, not a new mapper. No ARSession/delegate takeover.
/// Full *observed-anchor delivery* is not world coverage or footprint support.
final class MeshCandidateDiagnostics {
    enum Event: Hashable { case added, updated, removed }
    struct Size: Equatable { let vertices: Int; let triangles: Int }
    struct Frame: Equatable {
        let session: UUID, id: UUID
        let capturedAt: Double
    }
    struct Request {
        let id: UUID, frame: Frame, goalRevision: UUID, profileRevision: UUID, mountRevision: UUID
        let sceneRevision: UUID, sceneCapturedAt: Double
        let start: [Float], goal: [Float]
        let radius: Float, height: Float, margin: Float
    }
    // Declared admission ceilings, NOT measured phone latency guarantees. Whole
    // anchors rejected, never prefixes. Includes retained missing-anchor sizes.
    static let maxAnchors = 32, maxVertices = 30_000, maxTriangles = 30_000
    private let limits = MeshBufferDecoder.Limits(vertices: 30_000, faces: 30_000,
        inputBytes: 1_500_000, decodedBytes: 1_500_000)
    private let sourceLimits = MeshSourceSnapshotLimits(anchors: 32, records: 128,
        vertices: 30_000, triangles: 30_000, payloadBytes: 2_000_000)
    private let clock: () -> Double
    private let decodeQueue: DispatchQueue
    private func requireMain() { dispatchPrecondition(condition: .onQueue(.main)) }
    private(set) var enabled = false
    private(set) var counts: [Event: UInt64] = [:]
    private(set) var refusedCopies: UInt64 = 0
    private(set) var epoch = UUID()
    private(set) var status = "Full observed-anchor diagnostic off. No physical authority."
    private(set) var routePoints = [[Float]]()
    private(set) var audit: SeatedMeshRouteAudit.Receipt?
    private(set) var request: Request?
    private(set) var latestFrame: Frame?
    // Pure read-time views: never emit objectWillChange during SwiftUI body.
    var displayStatus: String {
        requireMain()
        if terminal {return canYieldCamera ? "Full-mesh owner released. Restart app for another full-mesh diagnostic; normal camera is unaffected." : "Releasing full-mesh native/source/collision ownership; not yet acknowledged."}
        guard enabled,!stopped else{return status}
        guard let frame=latestFrame,clock() >= frame.capturedAt,clock()-frame.capturedAt <= 0.5 else {
            return "Unavailable: current tracked frame lease expired; old result withheld."
        }
        if let request,!eligible(request,epoch:epoch,current:outputCurrent ?? {false}) {
            return "Retired frozen request; old result withheld."
        }
        return status
    }
    var displayPoints: [[Float]] {
        requireMain()
        guard let request,eligible(request,epoch:epoch,current:outputCurrent ?? {false}) else{return []}
        return routePoints
    }
    var canYieldCamera: Bool {requireMain();return owner == nil && !pending && drain == nil}
    var canEnable: Bool {requireMain();return !terminal}
    var isReleasing: Bool {requireMain();return drain != nil}
    var onChange: (() -> Void)?
    private var owner: MeshCandidateIngress83?
    private var terminal = false, stopped = true, pending = false, nativeDrained = false
    private var drain: (() -> Void)?
    private var seen = Set<UUID>(), dirty = Set<UUID>(), present = Set<UUID>(), missing = Set<UUID>()
    private var sizes = [UUID: Size]()
    private var cursor = 0
    private var outputCurrent: (() -> Bool)?
    // Only synthetic tests provide this hook; after real oracle work, never a
    // replacement collision answer. Nil in the app.
    var nativeDiscardAcknowledgedForTesting: Bool { requireMain();return nativeDrained }
    var auditProgressForTesting: ((SeatedMeshRouteAudit.Progress) async -> Void)?

    init(clock: @escaping () -> Double = { ProcessInfo.processInfo.systemUptime },
         decodeQueue: DispatchQueue = DispatchQueue(label: "blind.normal-mesh.decode", qos: .utility)) {
        self.clock=clock; self.decodeQueue=decodeQueue
    }
    private func tell(_ value: String) { status=value; onChange?() }
    private func retire() { request=nil; audit=nil; routePoints=[]; outputCurrent=nil }
    func setEnabled(_ value: Bool) {
        requireMain(); guard !terminal else { return }
        enabled=value
        if value { beginEpoch() } else { stop() }
    }
    func beginEpoch() {
        requireMain(); guard enabled,!terminal else { return }
        epoch=UUID(); retire(); latestFrame=nil; seen=[]; dirty=[]; present=[]; missing=[]; sizes=[:]; cursor=0
        counts=[:]; refusedCopies=0
        do {
            if let owner { try owner.reset() }
            else { owner=try MeshCandidateIngress83(maxAnchors:Self.maxAnchors,maxCopies:1,
                supportPolicy:.classifiedFloorOnly,endpointPolicy:.requireSuppliedXZOverPolygon,
                deliveryRecoveryPolicy:.latestValidatedAnchorRevision,decodeQueue:decodeQueue) }
            stopped=false
            tell("Waiting for fresh tracked normal-owner mesh. Unknown support; not guidance.")
        } catch { stop() }
    }
    private func gap(_ id: UUID, at: Double) {
        _ = owner?.ingest(anchorID:id,receiptUptime:at) { context in
            .unknownGap(.init(context:context,anchorID:id,reason:.budget))
        }
    }
    func observe(_ event: Event, anchorID: UUID, receiptUptime: Double) {
        requireMain(); guard enabled,!terminal,!stopped else { return }
        counts[event,default:0] = counts[event,default:0] == .max ? .max : counts[event,default:0]+1
        retire() // Even malformed/omitted/newer replacement retires earlier output.
        guard seen.contains(anchorID) || seen.count < Self.maxAnchors else { refuse("Anchor/tombstone budget exceeded");return }
        seen.insert(anchorID)
        switch event {
        case .added,.updated:
            dirty.insert(anchorID);gap(anchorID,at:receiptUptime)
        case .removed:
            sizes.removeValue(forKey:anchorID);dirty.remove(anchorID);present.remove(anchorID);missing.remove(anchorID)
            _ = owner?.remove(anchorID:anchorID,receiptUptime:receiptUptime)
        }
        tell("Observed geometry revision changed. Reacquiring complete bounded anchors; support unknown.")
    }
    private func refuse(_ reason: String) {
        refusedCopies = refusedCopies == .max ? .max : refusedCopies+1
        stop();tell("UNAVAILABLE: \(reason). No subset accepted as complete. Re-enable to start a new diagnostic epoch.")
    }
    /// Synchronous owning callback only, called AFTER urgent depth/hazard work.
    /// No ARFrame/ARMeshAnchor/MTLBuffer crosses a queue or is stored in this owner.
    func observe(frame: ARFrame, session: UUID, now: Double) {
        requireMain(); guard enabled,!stopped,!terminal else { return }
        guard case .normal = frame.camera.trackingState else { stop();return }
        guard frame.anchors.count <= 128 else { refuse("Frame inventory inspection budget exceeded");return }
        let anchors=frame.anchors.compactMap { $0 as? ARMeshAnchor }
        let metadata=anchors.map { ($0.identifier,Size(vertices:$0.geometry.vertices.count,triangles:$0.geometry.faces.count)) }
        guard admitInventory(metadata,frame:.init(session:session,id:UUID(),capturedAt:frame.timestamp),now:now) else {return}
        let candidates=anchors.filter { dirty.contains($0.identifier) }
        guard !candidates.isEmpty else {return}
        let selected=candidates[cursor % candidates.count];cursor=(cursor+1) % Self.maxAnchors
        // Exact existing 82 native-buffer preflight/copy and 83 owned decode.
        // One whole copy maximum; rejected slot remains dirty for a later frame.
        if owner?.ingest(selected,receiptUptime:clock(),limits:limits) == true {
            dirty.remove(selected.identifier)
        }
    }
    /// Copy admission alone does not prove that the bounded native mailbox
    /// installed it. Retry only explicit failed delivery from a later actual frame.
    /// Pending rows are left alone; old bytes are never replayed as a new revision.
    private func refreshFailedDeliveries() {
        guard let owner else{return}
        for row in owner.anchorDeliveryReceipts {
            guard let id=UUID(uuidString:row.anchorID),present.contains(id),
                  let issue=row.issue,issue != .pending,issue != .removed else{continue}
            dirty.insert(id)
        }
    }
    /// Synthetic inspection only. This observes real native installation, not
    /// decoder completion, and grants no source/collision/physical authority.
    func hasInstalledOwnedAnchorForTesting(_ id:UUID) -> Bool {
        requireMain()
        guard enabled,!stopped,!terminal,present.contains(id),!dirty.contains(id),!missing.contains(id),let owner else{return false}
        return owner.anchorDeliveryReceipts.contains {
            $0.anchorID == id.uuidString && $0.issue == nil && $0.installedRevision == $0.requiredRevision
        }
    }
    /// Pure copied metadata seam shared by real capture and synthetic fixtures.
    /// Timestamp is a frame lease, NOT the capture time of all retained mesh faces.
    @discardableResult func admitInventory(_ entries: [(UUID,Size)], frame: Frame, now: Double) -> Bool {
        requireMain();guard enabled,!stopped,!terminal else{return false}
        guard frame.capturedAt.isFinite,now.isFinite,frame.capturedAt <= now,now-frame.capturedAt <= 0.5,
              latestFrame == nil || (latestFrame!.session == frame.session && frame.capturedAt > latestFrame!.capturedAt),
              entries.count <= Self.maxAnchors,Set(entries.map(\.0)).count == entries.count else {
            refuse("Invalid, stale, reordered or different-session inventory");return false
        }
        let ids=Set(entries.map(\.0)),newIDs=ids.subtracting(seen)
        guard seen.union(ids).count <= Self.maxAnchors else {refuse("Anchor/tombstone budget exceeded");return false}
        var proposed=sizes
        for (id,size) in entries {
            guard size.vertices > 0,size.vertices <= Self.maxVertices,size.triangles > 0,size.triangles <= Self.maxTriangles else {
                refuse("Whole anchor geometry budget/shape refused");return false
            }
            proposed[id]=size
        }
        guard proposed.values.reduce(0,{$0+$1.vertices}) <= Self.maxVertices,
              proposed.values.reduce(0,{$0+$1.triangles}) <= Self.maxTriangles else {
            refuse("Aggregate retained geometry budget exceeded");return false
        }
        let vanished=present.subtracting(ids).subtracting(missing)
        let resized=Set(entries.filter { sizes[$0.0] != nil && sizes[$0.0] != $0.1 }.map(\.0))
        // A removed tombstone may reappear with the same UUID. It still needs
        // a new full copy/revision; seen identity alone is never installed geometry.
        let appeared=ids.subtracting(present)
        let invalidated=newIDs.union(appeared).union(vanished).union(resized)
        for id in invalidated { dirty.insert(id);gap(id,at:clock()) }
        if !invalidated.isEmpty {retire()}
        missing.formUnion(vanished);missing.subtract(ids)
        seen.formUnion(ids);present=ids;sizes=proposed;latestFrame=frame
        refreshFailedDeliveries()
        revalidate()
        return true
    }
    /// Used only by synthetic tests with real owned82 buffers and the same83 owner.
    /// Does not issue/fabricate a validated source or route.
    @discardableResult func ingestOwnedForTesting(id: UUID, capture: (MeshSnapshot82.Context)->MeshSnapshot82.Capture) -> Bool {
        requireMain();guard enabled,!stopped,present.contains(id),dirty.contains(id) else{return false}
        let accepted=owner?.ingest(anchorID:id,receiptUptime:clock(),capture:capture) == true
        if accepted {dirty.remove(id)}
        return accepted
    }
    /// Synthetic fixture inspection of the actual owned83 snapshot, never a
    /// fabricated geometry result or a new source authority.
    func requestSourceForTesting(_ completion:@escaping (Result<MeshCandidateIngress83.SourceSnapshot,MeshCandidateIngress83.SourceSnapshotFailure>)->Void) {
        requireMain()
        guard let owner,enabled,!stopped,!terminal,dirty.isEmpty,missing.isEmpty else {completion(.failure(.unavailable));return}
        owner.requestSourceSnapshot(limits:sourceLimits,completion:completion)
    }
    func revalidate() {
        requireMain()
        guard !stopped else{return}
        guard let frame=latestFrame,clock() >= frame.capturedAt,clock()-frame.capturedAt <= 0.5 else {stop();return}
        if let request,clock()-request.frame.capturedAt > 8 || outputCurrent?() == false {
            retire();tell("Frozen diagnostic retired by age or intent/body/session change.")
        }
    }
    private func eligible(_ value: Request, epoch: UUID, current: () -> Bool) -> Bool {
        requireMain()
        guard enabled,!stopped,!terminal,self.epoch == epoch,request?.id == value.id,
              latestFrame?.session == value.frame.session,let latestFrame,
              clock() >= latestFrame.capturedAt,clock()-latestFrame.capturedAt <= 0.5,
              clock() >= value.frame.capturedAt,clock()-value.frame.capturedAt <= 8,
              dirty.isEmpty,missing.isEmpty,!present.isEmpty,current() else{return false}
        return true
    }
    private func sourceMatches(_ source: MeshCandidateIngress83.SourceSnapshot, owner: MeshCandidateIngress83) -> Bool {
        owner.isCurrent(source) && source.geometry.sourceDeliveryComplete && source.geometry.unknownCoverage.isEmpty
            && Set(source.geometry.anchors.map(\.anchorID)) == Set(present.map(\.uuidString))
    }
    /// Actual current LocalPlanner endpoints, frozen explicitly by the developer.
    /// This is a look-ahead start (not wearer foot), no implicit camera connector.
    func retireRequestedPreview() {
        requireMain();retire();tell("Previous preview retired. A fresh plan/body/source is required for another request.")
    }
    func check(_ value: Request, stillCurrent: @escaping () -> Bool) {
        requireMain()
        MainActor.assumeIsolated { checkOnMain(value,stillCurrent:stillCurrent) }
    }
    @MainActor private func checkOnMain(_ value:Request,stillCurrent:@escaping ()->Bool) {
        requireMain();retire()
        guard !pending,let owner,let frame=latestFrame,frame == value.frame,
              clock() >= frame.capturedAt,clock()-frame.capturedAt <= 0.5,
              value.sceneCapturedAt.isFinite,clock() >= value.sceneCapturedAt,clock()-value.sceneCapturedAt <= 0.5,
              let body=try? MeshCandidateBody(radius:value.radius,height:value.height) else {tell("Unavailable: fresh source/plan/body or idle slot missing.");return}
        let auditRequest=SeatedMeshRouteAudit.Request(id:value.id,start:value.start,goal:value.goal,
            radius:value.radius,height:value.height,margin:value.margin)
        guard auditRequest.valid else {tell("Unavailable: body/margin or endpoints invalid; no smaller fallback.");return}
        retire();request=value;outputCurrent=stillCurrent
        let token=epoch
        guard eligible(value,epoch:token,current:stillCurrent) else {retire();tell("Unavailable: incomplete inventory or retired frame/goal/body.");return}
        pending=true;tell("Strict native look-ahead query pending. Frozen historical diagnostic; no physical guidance.")
        owner.requestSourceSnapshot(limits:sourceLimits) { [self] result in
            DispatchQueue.main.async {
                guard self.eligible(value,epoch:token,current:stillCurrent),case .success(let source)=result,
                      self.sourceMatches(source,owner:owner) else {self.finish("Source refused/incomplete/retired");return}
                owner.request(start:value.start,goal:value.goal,body:body,expectedSource:source) { [self] result in
                    DispatchQueue.main.async {
                                guard self.eligible(value,epoch:token,current:stillCurrent),case .success(let candidate)=result,
                              owner.isCurrent(candidate) else {self.finish("Native query refused/retired");return}
                        owner.requestSourceSnapshot(limits:self.sourceLimits) { [self] result in
                            DispatchQueue.main.async {
                                                guard self.eligible(value,epoch:token,current:stillCurrent),case .success(let source)=result,
                                      self.sourceMatches(source,owner:owner),owner.isCurrent(candidate),source.geometry.revision == candidate.route.revision else {self.finish("Post-query original source refused/retired");return}
                                self.startAudit(source:source,candidate:candidate,auditRequest:auditRequest,
                                    value:value,token:token,current:stillCurrent,owner:owner)
                            }
                        }
                    }
                }
            }
        }
    }
    private final class AuditWork {
        var source: MeshCandidateIngress83.SourceSnapshot?
        var candidate: MeshCandidateIngress83.Candidate?
        init(source: MeshCandidateIngress83.SourceSnapshot,candidate: MeshCandidateIngress83.Candidate) {
            self.source=source;self.candidate=candidate
        }
        func clear() {source=nil;candidate=nil}
    }
    private func startAudit(source:MeshCandidateIngress83.SourceSnapshot,candidate:MeshCandidateIngress83.Candidate,
        auditRequest:SeatedMeshRouteAudit.Request,value:Request,token:UUID,current:@escaping ()->Bool,owner:MeshCandidateIngress83) {
        let work=AuditWork(source:source,candidate:candidate)
        Task { @MainActor [self,work] in
            let stillCurrent = { [weak self,work] in
                guard let self,let source=work.source,let candidate=work.candidate else{return false}
                return self.eligible(value,epoch:token,current:current) && owner.isCurrent(source) && owner.isCurrent(candidate)
            }
            let result=await runAudit(work:work,request:auditRequest,current:stillCurrent)
            let valid=stillCurrent()
            let oldestReceipt=work.source?.geometry.records.filter { $0.hasRetainedGeometry }.map(\.receiptUptime).min()
            let history=oldestReceipt.map { "Oldest retained anchor receipt age at audit completion \(max(0,clock()-$0))s (not sensor capture age)." } ?? "Retained anchor receipt age unavailable."
            let points=work.candidate?.route.points ?? []
            let start=work.candidate?.route.projectedStart ?? [],goal=work.candidate?.route.projectedGoal ?? []
            work.clear() // Scope containing source/native-route locals returned before clearing.
            if valid,case .success(let receipt)=result {
                audit=receipt;routePoints=points
                finish("New Detour route between frozen LocalPlanner endpoints (not its original intermediate polyline or wearer connector). Historical look-ahead at \(value.frame.capturedAt), frame \(value.frame.id). Requested start \(value.start), native associated start \(start); requested goal \(value.goal), native associated goal \(goal). No physical relocation inferred. \(history) Actual surface capture age is unavailable; a tracked frame or remembered ARFrame anchor does not refresh geometry into current clearance/support. \(receipt.text)",retain:true)
            } else {finish("Collision audit unavailable/retired; not clear space")}
        }
    }
    @MainActor private func runAudit(work:AuditWork,request:SeatedMeshRouteAudit.Request,
        current:@escaping ()->Bool) async -> Result<SeatedMeshRouteAudit.Receipt,Error> {
        guard let source=work.source,let candidate=work.candidate else{return .failure(SeatedMeshRouteAudit.Failure.retired)}
        do {return .success(try await SeatedMeshRouteAudit.run(source:source.geometry,route:candidate.route,
            request:request,isCurrent:current,progress:auditProgressForTesting))} catch {return .failure(error)}
    }
    private func finish(_ message:String,retain:Bool=false) {
        requireMain();if !retain {retire()};pending=false;tell(message)
        // Main-queue barrier: source callback / Task closure exits before ACK.
        DispatchQueue.main.async { [self] in finishDrain() }
    }
    func stop() { requireMain();stopped=true;epoch=UUID();retire();latestFrame=nil;owner?.stop();tell("Normal-owner mesh diagnostic stopped; support unknown.") }
    func scanStarted() {beginEpoch();stop()}
    func discard(completion: @escaping () -> Void) {
        requireMain();guard drain == nil else {return} // Sole camera owner supplies one acknowledgement waiter.
        stop();terminal=true;enabled=false;drain=completion
        if let owner {owner.stopAndDiscard { [self] in DispatchQueue.main.async {nativeDrained=true;finishDrain()} }}
        else {nativeDrained=true;finishDrain()}
    }
    private func finishDrain() {
        guard nativeDrained,!pending,let callback=drain else{return}
        owner=nil;drain=nil;callback() // Includes real native, source/query and collider return.
    }
}
#endif
