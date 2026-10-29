import Foundation
import XCTest
@testable import BlindRoomMesh
@testable import MeshSnapshot82
import MeshCandidateIngress83
@testable import LiveMeshClassifiedBench

/// Opt-in delivery recovery over actual owned buffers/dependencies. These
/// synthetic schedules are not ARKit callback ordering or physical clearance.
final class AnchorDeliveryRecoveryTests: XCTestCase {
    private let identity: [Double] = [1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1]
    private let vertices: [Double] = [-3,0,-3,-3,0,3,3,0,3,3,0,-3]
    private let triangles: [Int32] = [0,1,2,0,2,3]
    private final class Box<T> {
        private let lock = NSLock(); private var value: T?
        func put(_ v: T) { lock.lock(); value=v; lock.unlock() }
        func get() -> T? { lock.lock(); defer { lock.unlock() }; return value }
    }
    private func runtime() throws -> RoomMeshCandidateRuntime {
        try .init(sessionID: "A", generation: 1, supportPolicy: .classifiedFloorOnly,
            endpointPolicy: .requireSuppliedXZOverPolygon, deliveryRecoveryPolicy: .latestValidatedAnchorRevision)
    }
    private func event(_ id: String = "floor", revision: Int = 1, time: Double = 1,
                       transform: [Double]? = nil, removed: Bool = false, complete: Bool = true,
                       roles: [MeshTriangleSupport] = [.floor,.floor]) -> MeshAnchorEvent {
        .init(sessionID: "A", generation: 1, anchorID: id, revision: revision, timestamp: time,
            vertices: removed ? [] : vertices, triangles: removed ? [] : triangles,
            columnMajorTransform: removed ? [] : (transform ?? identity), complete: complete && !removed,
            removed: removed, triangleSupport: removed ? nil : roles)
    }
    @discardableResult private func note(_ owner: RoomMeshCandidateRuntime, _ id: String,
        revision: Int, time: Double, removed: Bool = false) -> Bool {
        owner.noteAnchorRevision(sessionID: "A", generation: 1, anchorID: id,
            revision: revision, receiptUptime: time, removed: removed)
    }
    private func issue(_ owner: RoomMeshCandidateRuntime, _ id: String, revision: Int,
        time: Double, _ issue: MeshAnchorDeliveryIssue = .copyBudget) {
        owner.markAnchorDeliveryIssue(sessionID: "A", generation: 1, anchorID: id,
            revision: revision, receiptUptime: time, issue: issue)
    }
    private func settle(_ queue: DispatchQueue? = nil) {
        queue?.sync {}; RoomMeshCandidateRuntime.worker.sync {}
    }
    private func source(_ owner: RoomMeshCandidateRuntime, limits: MeshSourceSnapshotLimits = .init()) throws
        -> Result<MeshSourceGeometrySnapshot, MeshSourceSnapshotError> {
        settle()
        let done=expectation(description: "recovery snapshot"), box=Box<Result<MeshSourceGeometrySnapshot,MeshSourceSnapshotError>>()
        owner.requestSourceSnapshot(limits: limits) { box.put($0); done.fulfill() }
        wait(for: [done], timeout: 10); RoomMeshCandidateRuntime.sourceSnapshotDeliveryWorker.sync {}
        return try XCTUnwrap(box.get())
    }
    private func source(_ owner: LiveMeshBenchIngress) throws -> MeshSourceGeometrySnapshot {
        settle()
        let done=expectation(description: "bench recovery snapshot"), box=Box<Result<MeshCandidateIngress83.SourceSnapshot,MeshCandidateIngress83.SourceSnapshotFailure>>()
        owner.requestSourceSnapshot(generation: owner.generation) { box.put($0); done.fulfill() }
        wait(for: [done], timeout: 10); RoomMeshCandidateRuntime.sourceSnapshotDeliveryWorker.sync {}
        return try XCTUnwrap(box.get()).get().geometry
    }
    private func query(_ owner: LiveMeshBenchIngress) throws
        -> Result<MeshCandidateIngress83.Candidate,MeshCandidateIngress83.Failure> {
        settle()
        let done=expectation(description: "strict recovered candidate"), box=Box<Result<MeshCandidateIngress83.Candidate,MeshCandidateIngress83.Failure>>()
        owner.request(generation: owner.generation, start: [-2,0,0], goal: [2,0,0],
            body: try .init(radius: 0.225, height: 1.75)) { box.put($0); done.fulfill() }
        wait(for: [done], timeout: 10); return try XCTUnwrap(box.get())
    }
    private func drain(_ owner: RoomMeshCandidateRuntime) {
        let done=expectation(description: "runtime recovery drain"); owner.stopAndDiscard { done.fulfill() }; wait(for: [done], timeout: 10)
    }
    private func drain(_ owner: LiveMeshBenchIngress) {
        let done=expectation(description: "bench recovery drain"); owner.stopAndDiscard { done.fulfill() }; wait(for: [done], timeout: 10)
    }
    private func block(_ queue: DispatchQueue) -> DispatchSemaphore {
        let entered=DispatchSemaphore(value: 0), release=DispatchSemaphore(value: 0)
        queue.async { entered.signal(); release.wait() }
        XCTAssertEqual(entered.wait(timeout: .now()+10), .success); return release
    }
    private func capture(_ context: MeshSnapshot82.Context, id: UUID, labels: [UInt8]? = [2,2],
                         x: Float = 0) -> MeshSnapshot82.Capture {
        let values=vertices.map(Float.init)
        let bytes=values.flatMap { v in (0..<4).map { UInt8(truncatingIfNeeded: v.bitPattern >> ($0*8)) } }
        let indices:[UInt8]=[0,0,1,0,2,0,0,0,2,0,3,0]
        let cd=labels.map { MeshSnapshot82.Descriptor(count: $0.count, offset: 0, stride: 1, bufferLength: $0.count, format: .uint8) }
        let plan=try! MeshSnapshot82.preflight(context: context,
            vertices: .init(count: 4, offset: 0, stride: 12, bufferLength: bytes.count, format: .float3),
            indices: .init(count: 6, offset: 0, stride: 2, bufferLength: indices.count, format: .uint16), classification: cd)
        var transform=identity.map(Float.init); transform[12]=x
        return .owned(.init(context: context, anchorID: id, plan: plan, vertexBytes: bytes,
            indexBytes: indices, classificationBytes: labels, transform: transform))
    }
    private func bench(_ queue: DispatchQueue) throws -> LiveMeshBenchIngress {
        try .init(deliveryRecoveryPolicy: .latestValidatedAnchorRevision, decodeQueue: queue)
    }
    func test01LatestOwnedReplacementRecoversOnlyLogicalDelivery() throws {
        let queue=DispatchQueue(label: "recovery.one"), owner=try bench(queue), id=UUID(); defer { drain(owner) }
        XCTAssertTrue(owner.observe(anchorID: id, generation: owner.generation, receiptUptime: 1) {
            .unknownGap(.init(context: $0, anchorID: id, reason: .budget))
        }); settle(queue)
        XCTAssertTrue(owner.observe(anchorID: id, generation: owner.generation, receiptUptime: 2) { capture($0,id:id) }); settle(queue)
        let snapshot=try source(owner), candidate=try query(owner).get()
        XCTAssertTrue(snapshot.sourceDeliveryComplete); XCTAssertTrue(snapshot.unknownCoverage.isEmpty)
        XCTAssertEqual(snapshot.anchorDelivery.first?.requiredRevision, 2)
        XCTAssertEqual(snapshot.anchorDelivery.first?.installedRevision, 2)
        XCTAssertNil(snapshot.anchorDelivery.first?.issue); XCTAssertNil(snapshot.captureUptime)
        XCTAssertTrue(candidate.route.complete); XCTAssertEqual(candidate.route.endpointPolicy, .requireSuppliedXZOverPolygon)
        XCTAssertFalse(candidate.physicalAuthority); XCTAssertFalse(candidate.coverageKnown)
        XCTAssertFalse(snapshot.authorizesPhysicalGuidance); XCTAssertFalse(snapshot.actualWorldCoverageKnown)
    }
    func test02ReplacementCannotClearAnotherAnchorsOmission() throws {
        let queue=DispatchQueue(label: "recovery.two"), owner=try bench(queue), a=UUID(), b=UUID(); defer { drain(owner) }
        for (id,time) in [(a,1.0),(b,2.0)] {
            XCTAssertTrue(owner.observe(anchorID:id,generation:owner.generation,receiptUptime:time) {
                .unknownGap(.init(context:$0,anchorID:id,reason:.budget))
            }); settle(queue)
        }
        XCTAssertTrue(owner.observe(anchorID:a,generation:owner.generation,receiptUptime:3) {capture($0,id:a)}); settle(queue)
        let snapshot=try source(owner)
        XCTAssertFalse(snapshot.sourceDeliveryComplete)
        XCTAssertNotNil(snapshot.anchorDelivery.first(where:{$0.anchorID==b.uuidString})?.issue)
        guard case .failure(.unavailable)=try query(owner) else {return XCTFail("Missing B must withhold the otherwise routable A preview")}
    }
    func test03BusyCopyRequiresNewerObservationAndDoesNotInvokeRejectedCapture() throws {
        let queue=DispatchQueue(label:"recovery.copy"), owner=try bench(queue), id=UUID()
        let release=block(queue); defer {release.signal();drain(owner)}
        XCTAssertTrue(owner.observe(anchorID:id,generation:owner.generation,receiptUptime:1) {capture($0,id:id)})
        var copied=false
        XCTAssertFalse(owner.observe(anchorID:id,generation:owner.generation,receiptUptime:2) {copied=true;return capture($0,id:id)})
        XCTAssertFalse(copied);release.signal();settle(queue)
        XCTAssertTrue(owner.observe(anchorID:id,generation:owner.generation,receiptUptime:3) {capture($0,id:id)});settle(queue)
        let snapshot=try source(owner)
        XCTAssertTrue(snapshot.sourceDeliveryComplete);XCTAssertEqual(snapshot.anchorDelivery.first?.installedRevision,3)
    }
    func test04PendingLatestRevisionQuarantinesOldTileAndLateCompletion() throws {
        let owner=try runtime();defer{drain(owner)}
        XCTAssertTrue(owner.offer(event()));let original=try source(owner).get()
        XCTAssertTrue(note(owner,"floor",revision:2,time:2));XCTAssertFalse(owner.isCurrent(original))
        owner.finishDelivery(event(),lifecycle:0,status:"accepted",capacityLost:false)
        let pending=try source(owner).get()
        XCTAssertTrue(pending.anchors.isEmpty)
        XCTAssertEqual(pending.records.first?.hasRetainedGeometry,true)
        XCTAssertEqual(pending.records.first?.includedInSnapshot,false)
        XCTAssertEqual(pending.anchorDelivery.first?.requiredRevision,2)
        var moved=identity;moved[12]=10
        XCTAssertTrue(owner.offer(event(revision:3,time:3,transform:moved)))
        let replacement=try source(owner).get()
        XCTAssertEqual(replacement.anchors.first?.columnMajorTransform,moved)
        XCTAssertTrue(replacement.sourceDeliveryComplete);XCTAssertFalse(owner.isCurrent(pending))
    }
    func test05RefusedRemovalImmediatelyWithholdsAnotherRoutableFloor() throws {
        let queue=DispatchQueue(label:"recovery.removal"),owner=try bench(queue),a=UUID(),b=UUID();defer{drain(owner)}
        XCTAssertTrue(owner.observe(anchorID:b,generation:owner.generation,receiptUptime:1){capture($0,id:b)});settle(queue)
        let release=block(RoomMeshCandidateRuntime.worker);defer{release.signal()}
        XCTAssertTrue(owner.observe(anchorID:a,generation:owner.generation,receiptUptime:2){capture($0,id:a)});queue.sync{}
        for n in 0..<7 {
            let id=UUID()
            XCTAssertTrue(owner.observe(anchorID:id,generation:owner.generation,receiptUptime:Double(n+3)){capture($0,id:id)});queue.sync{}
        }
        XCTAssertFalse(owner.remove(anchorID:a,generation:owner.generation,receiptUptime:10)) // full existing native mailbox
        release.signal();settle(queue)
        let snapshot=try source(owner)
        XCTAssertFalse(snapshot.anchors.contains(where:{$0.anchorID==a.uuidString}))
        XCTAssertTrue(snapshot.anchors.contains(where:{$0.anchorID==b.uuidString}))
        XCTAssertTrue(snapshot.unknownCoverage.contains("removed:"+a.uuidString))
        XCTAssertEqual(snapshot.anchorDelivery.first(where:{$0.anchorID==a.uuidString})?.removed,true)
        guard case .failure(.unavailable)=try query(owner) else{return XCTFail("Retained B must not hide a refused removal")}
    }
    func test06MissingClassesReplaceOldFloorWithoutPromotingNonfloor() throws {
        let queue=DispatchQueue(label:"recovery.classes"),owner=try bench(queue),id=UUID();defer{drain(owner)}
        for (time,labels) in [(1.0,Optional([UInt8(2),2])),(2.0,nil),(3.0,Optional([UInt8(4),4])),(4.0,Optional([UInt8(2),2]))] {
            XCTAssertTrue(owner.observe(anchorID:id,generation:owner.generation,receiptUptime:time){capture($0,id:id,labels:labels)});settle(queue)
            let snapshot=try source(owner)
            if time==2 {
                XCTAssertFalse(snapshot.sourceDeliveryComplete)
                XCTAssertEqual(snapshot.anchors.first?.normalizedSupportRoles,[.obstacle,.obstacle])
                XCTAssertEqual(snapshot.anchorDelivery.first?.issue,.classificationUnavailable)
            } else if time==3 {
                XCTAssertTrue(snapshot.sourceDeliveryComplete)
                XCTAssertEqual(snapshot.anchors.first?.normalizedSupportRoles,[.obstacle,.obstacle])
                guard case .failure(.runtime(.nativeFailure))=try query(owner) else{return XCTFail("Known furniture is not support")}
            }
        }
        XCTAssertTrue(try source(owner).sourceDeliveryComplete)
        XCTAssertTrue(try query(owner).get().route.complete)
    }
    func test07RejectedProjectedGeometryRecoversOnlyAfterValidNewerInstall() throws {
        let owner=try runtime();defer{drain(owner)}
        XCTAssertTrue(owner.offer(event()));_ = try source(owner).get()
        var invalid=identity;invalid[12]=1e300
        XCTAssertTrue(owner.offer(event(revision:2,time:2,transform:invalid)))
        let failed=try source(owner).get()
        XCTAssertTrue(failed.anchors.isEmpty);XCTAssertFalse(failed.sourceDeliveryComplete)
        XCTAssertEqual(failed.anchorDelivery.first?.issue,.sourceRejected)
        XCTAssertFalse(owner.offer(event(revision:2,time:2))) // same failed version cannot be re-labelled as a new observation
        let rotated:[Double]=[0,0,-1,0,0,1,0,0,1,0,0,0,10,2,20,1]
        XCTAssertTrue(owner.offer(event(revision:3,time:3,transform:rotated)))
        let fixed=try source(owner).get()
        XCTAssertTrue(fixed.sourceDeliveryComplete);XCTAssertEqual(fixed.anchors.first?.localVertices,vertices)
        XCTAssertEqual(fixed.anchors.first?.columnMajorTransform,rotated)
    }
    func test08GoodReplacementCannotClearGlobalClockTrackingOrContextFailure() throws {
        for failure in 0..<3 {
            let owner=try runtime();defer{drain(owner)}
            XCTAssertTrue(owner.offer(event()));_ = try source(owner).get()
            if failure==0 {owner.invalidate()}
            else if failure==1 {XCTAssertFalse(note(owner,"floor",revision:2,time:0))}
            else {
                XCTAssertTrue(note(owner,"floor",revision:2,time:2))
                owner.finishDelivery(event(),lifecycle:0,status:"accepted",capacityLost:true) // superseded loss remains global
            }
            XCTAssertTrue(owner.offer(event(revision:3,time:3)))
            let snapshot=try source(owner).get()
            XCTAssertFalse(snapshot.sourceDeliveryComplete);XCTAssertTrue(snapshot.anchors.isEmpty)
            XCTAssertTrue(snapshot.unknownCoverage.contains("ingress-or-lifecycle-gap"))
        }
        let queue=DispatchQueue(label:"recovery.context"),owner=try bench(queue),id=UUID();defer{drain(owner)}
        XCTAssertTrue(owner.observe(anchorID:id,generation:owner.generation,receiptUptime:1) {
            .unknownGap(.init(context:$0,anchorID:UUID(),reason:.budget))
        });settle(queue)
        XCTAssertTrue(owner.observe(anchorID:id,generation:owner.generation,receiptUptime:2){capture($0,id:id)});settle(queue)
        XCTAssertFalse(try source(owner).sourceDeliveryComplete)
    }
    func test09MetadataCapPreservesTombstonesAndCallerRecordLimit() throws {
        let owner=try runtime();defer{drain(owner)}
        XCTAssertTrue(owner.offer(event("id0")));_ = try source(owner).get()
        XCTAssertTrue(note(owner,"id0",revision:2,time:2,removed:true))
        for n in 1..<256 {XCTAssertTrue(note(owner,"id\(n)",revision:1,time:1,removed:true))}
        guard case .failure(.budget)=try source(owner,limits:.init(records:1)) else{return XCTFail("Metadata-only identities count against caller cap")}
        XCTAssertFalse(note(owner,"overflow",revision:1,time:1))
        for revision in 3...8 {XCTAssertTrue(owner.offer(event("id0",revision:revision,time:Double(revision))))}
        let snapshot=try source(owner).get()
        XCTAssertEqual(snapshot.anchorDelivery.count,256)
        XCTAssertFalse(snapshot.anchorDelivery.contains(where:{$0.anchorID=="overflow"}))
        XCTAssertTrue(snapshot.unknownCoverage.contains("removed:id0"))
        XCTAssertTrue(snapshot.unknownCoverage.contains("ingress-or-lifecycle-gap"))
        XCTAssertFalse(snapshot.sourceDeliveryComplete)
    }
    func test10QueuedQueryAndSnapshotCannotPublishBeforeNewerUpdate() throws {
        let owner=try runtime();defer{drain(owner)}
        XCTAssertTrue(owner.offer(event()));_ = try source(owner).get()
        let release=block(RoomMeshCandidateRuntime.worker);defer{release.signal()}
        let routeDone=expectation(description:"retired query"),sourceDone=expectation(description:"retired snapshot")
        owner.request(start:[-2,0,0],goal:[2,0,0],body:try .init(radius:0.225,height:1.75)) {result in
            guard case .failure(.stale)=result else{routeDone.fulfill();return XCTFail("Old native query admitted")};routeDone.fulfill()
        }
        owner.requestSourceSnapshot {result in
            guard case .failure(.stale)=result else{sourceDone.fulfill();return XCTFail("Old source snapshot admitted")};sourceDone.fulfill()
        }
        XCTAssertTrue(note(owner,"floor",revision:2,time:2));release.signal()
        wait(for:[routeDone,sourceDone],timeout:10);RoomMeshCandidateRuntime.sourceSnapshotDeliveryWorker.sync{}
        XCTAssertTrue(owner.offer(event(revision:2,time:2,roles:[.floor,.obstacle])))
        let snapshot=try source(owner).get()
        XCTAssertEqual(snapshot.anchors.first?.triangleIndices,triangles)
        XCTAssertEqual(snapshot.anchors.first?.normalizedSupportRoles,[.floor,.obstacle])
    }
    func test11LifecycleABAAndSameRevisionLateCommitCannotResolveFailures() throws {
        let owner=try runtime();defer{drain(owner)}
        XCTAssertTrue(owner.offer(event()));_ = try source(owner).get()
        try owner.reset(sessionID:"B",generation:1);try owner.reset(sessionID:"A",generation:1)
        XCTAssertTrue(note(owner,"floor",revision:1,time:1))
        XCTAssertTrue(owner.offer(event("other")));settle()
        owner.finishDelivery(event(),lifecycle:0,status:"accepted",capacityLost:false) // old A/1 lifecycle
        let newEpoch=try source(owner).get()
        XCTAssertNil(newEpoch.anchorDelivery.first(where:{$0.anchorID=="floor"})?.installedRevision)
        XCTAssertEqual(newEpoch.anchorDelivery.first(where:{$0.anchorID=="floor"})?.issue,.pending)
        let fresh=try runtime();defer{drain(fresh)}
        XCTAssertTrue(note(fresh,"floor",revision:1,time:1))
        issue(fresh,"floor",revision:1,time:1,.bufferValidation)
        fresh.finishDelivery(event(),lifecycle:0,status:"accepted",capacityLost:false) // older copy was queued before failure
        XCTAssertFalse(fresh.offer(event()))
        XCTAssertTrue(fresh.offer(event("other")));let failed=try source(fresh).get()
        XCTAssertNil(failed.anchorDelivery.first(where:{$0.anchorID=="floor"})?.installedRevision)
        XCTAssertEqual(failed.anchorDelivery.first(where:{$0.anchorID=="floor"})?.unresolvedThroughRevision,1)
        XCTAssertTrue(fresh.offer(event(revision:2,time:2)))
        let recovered=try source(fresh).get();XCTAssertTrue(recovered.sourceDeliveryComplete)
        XCTAssertFalse(fresh.offer(event(revision:1,time:1))) // stale cannot replace or poison latest
        XCTAssertTrue(try source(fresh).get().sourceDeliveryComplete)
        XCTAssertTrue(fresh.offer(event(revision:2,time:2))) // exact duplicate is not a new loss
        XCTAssertTrue(try source(fresh).get().sourceDeliveryComplete)
        var conflict=identity;conflict[12]=1
        XCTAssertTrue(fresh.offer(event(revision:2,time:2,transform:conflict)))
        let conflicted=try source(fresh).get()
        XCTAssertFalse(conflicted.anchors.contains(where:{$0.anchorID=="floor"}))
        XCTAssertEqual(conflicted.anchorDelivery.first(where:{$0.anchorID=="floor"})?.issue,.conflictingRevision)
        XCTAssertTrue(fresh.offer(event(revision:3,time:3)))
        XCTAssertTrue(try source(fresh).get().sourceDeliveryComplete)
        XCTAssertFalse(note(fresh,"floor",revision:4,time:3)) // newer revision cannot reuse a receipt time
        XCTAssertFalse(try source(fresh).get().sourceDeliveryComplete)
    }
    func test12AllRemovalsRemainUnknownEvenAfterSameUUIDReappears() throws {
        let owner=try runtime();defer{drain(owner)}
        for id in ["one","two"] {XCTAssertTrue(owner.offer(event(id)))}
        _ = try source(owner).get()
        for id in ["one","two"] {XCTAssertTrue(owner.offer(event(id,revision:2,time:2,removed:true)))}
        let empty=try source(owner).get()
        XCTAssertTrue(empty.anchors.isEmpty);XCTAssertEqual(empty.anchorDelivery.filter(\.removed).count,2)
        XCTAssertFalse(empty.sourceDeliveryComplete);XCTAssertFalse(empty.actualWorldCoverageKnown)
        XCTAssertTrue(owner.offer(event("one",revision:3,time:3)))
        let reappeared=try source(owner).get()
        XCTAssertEqual(reappeared.anchors.count,1);XCTAssertTrue(reappeared.unknownCoverage.contains("removed:one"))
        XCTAssertFalse(reappeared.sourceDeliveryComplete)
    }
    func test13MailboxRefusalNeedsExactNewerReplacementNotUnrelatedDrain() throws {
        let owner=try runtime();defer{drain(owner)}
        XCTAssertTrue(owner.offer(event()));_ = try source(owner).get()
        let release=block(RoomMeshCandidateRuntime.worker);defer{release.signal()}
        for revision in 1...8 {XCTAssertTrue(owner.offer(event("other",revision:revision,time:Double(revision))))}
        XCTAssertFalse(owner.offer(event(revision:2,time:2)))
        release.signal();settle()
        let pending=try source(owner).get()
        XCTAssertFalse(pending.anchors.contains(where:{$0.anchorID=="floor"}))
        XCTAssertEqual(pending.anchorDelivery.first(where:{$0.anchorID=="floor"})?.issue,.mailboxBusy)
        XCTAssertTrue(owner.offer(event("other",revision:9,time:9)))
        XCTAssertFalse(try source(owner).get().sourceDeliveryComplete)
        XCTAssertTrue(owner.offer(event(revision:3,time:3)))
        XCTAssertTrue(try source(owner).get().sourceDeliveryComplete)
    }
    func test14SnapshotBudgetsAndDeliveryDrainRemainBoundedAfterRecovery() throws {
        let owner=try runtime()
        XCTAssertTrue(note(owner,"floor",revision:1,time:1));issue(owner,"floor",revision:1,time:1)
        XCTAssertTrue(owner.offer(event(revision:2,time:2)));let snapshot=try source(owner).get()
        guard case .failure(.budget)=try source(owner,limits:.init(payloadBytes:snapshot.logicalPayloadBytes-1)) else{drain(owner);return XCTFail("Recovery metadata must stay in payload budget")}
        let release=block(RoomMeshCandidateRuntime.sourceSnapshotDeliveryWorker);defer{release.signal()}
        let delivered=expectation(description:"retired recovered payload"),refused=expectation(description:"one source payload"),done=expectation(description:"recovery discard")
        owner.requestSourceSnapshot {result in
            guard case .failure(.stale)=result else{delivered.fulfill();return XCTFail("Stopped recovered payload leaked")};delivered.fulfill()
        }
        settle()
        owner.requestSourceSnapshot {result in
            guard case .failure(.unavailable)=result else{refused.fulfill();return XCTFail("Second source payload admitted")};refused.fulfill()
        }
        wait(for:[refused],timeout:10)
        let discarded=DispatchSemaphore(value:0)
        owner.stopAndDiscard {discarded.signal();done.fulfill()}
        XCTAssertEqual(discarded.wait(timeout:.now()),.timedOut);XCTAssertFalse(owner.isCurrent(snapshot))
        release.signal();wait(for:[delivered,done],timeout:10)
    }
}
