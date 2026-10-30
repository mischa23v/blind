#if DEBUG && BLIND_MESH_CANDIDATE_DIAGNOSTICS
import XCTest
import BlindCore
import BlindRoomMesh
@testable import MeshSnapshot82
@testable import BlindAssist

final class NormalOwnerMeshConnectionTests: XCTestCase {
    private final class Clock {var now:Double=10}
    @MainActor private final class Cleanup {
        let owner:MeshCandidateDiagnostics
        let expectation=XCTestExpectation(description:"native and operation drain")
        var requested=false,acknowledged=false
        init(_ owner:MeshCandidateDiagnostics) {self.owner=owner;expectation.assertForOverFulfill=true}
        func start() {
            guard !requested else{return};requested=true
            owner.discard {self.acknowledged=true;self.expectation.fulfill()}
        }
    }
    @MainActor private func fixture(advancingClock:Bool=false) -> (MeshCandidateDiagnostics,Clock,DispatchQueue,UUID,UUID,Cleanup) {
        let time=Clock(),queue=DispatchQueue(label:"normal.mesh.fixture.decode")
        let owner=MeshCandidateDiagnostics(clock:{
            if advancingClock {time.now += 0.000001} // Synthetic monotonic receipt clock, not forged capture time.
            return time.now
        },decodeQueue:queue)
        XCTAssertTrue(owner.canYieldCamera) // Never-used owner has no retained native state.
        owner.setEnabled(true)
        XCTAssertFalse(owner.canYieldCamera)
        let cleanup=Cleanup(owner),drained=cleanup.expectation
        addTeardownBlock { [self] in
            await MainActor.run {cleanup.start()}
            // Sole wait on this standalone expectation. Method-body checks use
            // distinct state predicates, never rewait an XCTest expectation.
            await fulfillment(of:[drained],timeout:10)
        }
        return (owner,time,queue,UUID(),UUID(),cleanup)
    }
    @MainActor private func awaitDrain(_ cleanup:Cleanup) async -> Bool {
        cleanup.start()
        let observed=XCTNSPredicateExpectation(predicate:NSPredicate {_,_ in cleanup.acknowledged},object:nil)
        await fulfillment(of:[observed],timeout:10)
        if cleanup.acknowledged {XCTAssertTrue(cleanup.owner.canYieldCamera)}
        return cleanup.acknowledged
    }
    private func frame(_ session:UUID,_ time:Double) -> MeshCandidateDiagnostics.Frame {
        .init(session:session,id:UUID(),capturedAt:time)
    }
    private func request(_ frame:MeshCandidateDiagnostics.Frame) -> MeshCandidateDiagnostics.Request {
        .init(id:UUID(),frame:frame,goalRevision:UUID(),profileRevision:UUID(),mountRevision:UUID(),
            sceneRevision:UUID(),sceneCapturedAt:frame.capturedAt,start:[-1,0,0],goal:[1,0,0],radius:0.2,height:1.4,margin:0.05)
    }
    @MainActor private func ownedFloor(_ owner:MeshCandidateDiagnostics,_ id:UUID, table:Bool=false) -> Bool {
        // Real82 preflight+owned buffers, consumed by real83/75. No fabricated
        // ARFrame, validated source, native route, collision receipt or authority.
        let floats:[Float]=[-3,0,-3,-3,0,3,3,0,3,3,0,-3] + (table ? [-0.2,0.8,-0.3,-0.2,0.8,0.3,0.2,0.8,0.3,0.2,0.8,-0.3] : [])
        let bytes=floats.flatMap {v in (0..<4).map {UInt8(truncatingIfNeeded:v.bitPattern >> ($0*8))}}
        let indices:[UInt8]=[0,0,1,0,2,0,0,0,2,0,3,0] + (table ? [4,0,5,0,6,0,4,0,6,0,7,0] : [])
        let roles:[UInt8]=table ? [2,2,5,5] : [2,2]
        return owner.ingestOwnedForTesting(id:id) {context in
            do {
                let plan=try MeshSnapshot82.preflight(context:context,
                    vertices:.init(count:floats.count/3,offset:0,stride:12,bufferLength:bytes.count,format:.float3),
                    indices:.init(count:indices.count/2,offset:0,stride:2,bufferLength:indices.count,format:.uint16),
                    classification:.init(count:roles.count,offset:0,stride:1,bufferLength:roles.count,format:.uint8))
                return .owned(.init(context:context,anchorID:id,plan:plan,vertexBytes:bytes,indexBytes:indices,
                    classificationBytes:roles,transform:[1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1]))
            } catch {return .unknownGap(.init(context:context,anchorID:id,reason:.invalidDescriptor))}
        }
    }
    @MainActor func testIncompleteInventoryAndAggregateBoundsNeverBecomeEmptyClearSource() async throws {
        let (owner,time,decode,session,id,cleanup)=fixture(),f=frame(session,10)
        XCTAssertTrue(owner.admitInventory([(id,.init(vertices:4,triangles:2))],frame:f,now:time.now))
        decode.sync {} // Only the independent decoder; no native/XCTest wait here.
        owner.check(request(f),stillCurrent:{true})
        XCTAssertNil(owner.request);XCTAssertNil(owner.audit);XCTAssertTrue(owner.status.contains("incomplete"))
        time.now=10.01
        let huge=UUID()
        XCTAssertFalse(owner.admitInventory([(id,.init(vertices:4,triangles:2)),(huge,.init(vertices:30_000,triangles:2))],
            frame:frame(session,time.now),now:time.now))
        XCTAssertTrue(owner.status.contains("Aggregate"));XCTAssertTrue(owner.routePoints.isEmpty)
        guard await awaitDrain(cleanup) else{return}
    }
    @MainActor func testReorderedFutureWrongSessionAndExpiredFrameCannotIssueQuery() async throws {
        for kind in ["reordered","future","session","expired"] {
            let (owner,time,decode,session,id,cleanup)=fixture()
            XCTAssertTrue(owner.admitInventory([(id,.init(vertices:4,triangles:2))],frame:frame(session,10),now:10))
            decode.sync {}
            let f=frame(kind == "session" ? UUID():session,kind == "future" ? 11:kind == "reordered" ? 9.9:10.01)
            time.now=kind == "expired" ? 11:10.02
            if kind == "expired" {
                XCTAssertTrue(owner.displayStatus.contains("expired"))
                XCTAssertTrue(owner.displayPoints.isEmpty)
                XCTAssertNotNil(owner.latestFrame) // Pure getter did not mutate/emit.
            }
            XCTAssertFalse(owner.admitInventory([(id,.init(vertices:4,triangles:2))],frame:f,now:time.now),kind)
            owner.check(request(f),stillCurrent:{true})
            XCTAssertNil(owner.audit);XCTAssertTrue(owner.routePoints.isEmpty)
            guard await awaitDrain(cleanup) else{return}
        }
    }
    @MainActor func testActualFullSourceStrictQueryAndAuditKeepFrozenRequestAcrossOrdinaryFrames() async throws {
        let (owner,time,decode,session,id,cleanup)=fixture()
        XCTAssertTrue(owner.admitInventory([(id,.init(vertices:8,triangles:4))],frame:frame(session,10),now:10));decode.sync {}
        time.now=10.001;XCTAssertTrue(ownedFloor(owner,id,table:true));decode.sync {}
        let captured=try XCTUnwrap(owner.latestFrame),frozen=request(captured)
        owner.check(frozen,stillCurrent:{true})
        time.now=10.1
        XCTAssertTrue(owner.admitInventory([(id,.init(vertices:8,triangles:4))],frame:frame(session,time.now),now:time.now))
        let completed=XCTNSPredicateExpectation(predicate:NSPredicate {_,_ in owner.audit != nil},object:nil)
        await fulfillment(of:[completed],timeout:10)
        let audit=try XCTUnwrap(owner.audit)
        XCTAssertEqual(owner.request?.frame,captured);XCTAssertEqual(audit.request.start,frozen.start)
        XCTAssertEqual(audit.request.goal,frozen.goal);XCTAssertFalse(audit.raw.isEmpty)
        XCTAssertEqual(audit.raw.count,audit.margin.count)
        XCTAssertFalse(audit.supportVerified);XCTAssertFalse(audit.physicalAuthority)
        XCTAssertTrue(audit.identities.values.contains {$0.anchorID == id.uuidString && $0.role == .floor})
        XCTAssertTrue(audit.identities.values.contains {$0.anchorID == id.uuidString && $0.role == .obstacle})
        XCTAssertFalse(owner.routePoints.isEmpty);XCTAssertTrue(owner.status.contains("No physical relocation"))
        time.now=10.105
        XCTAssertTrue(owner.admitInventory([],frame:frame(session,time.now),now:time.now))
        XCTAssertNil(owner.audit);XCTAssertTrue(owner.routePoints.isEmpty) // Omission is not removal/free space.
        decode.sync {}
        time.now=10.108
        XCTAssertTrue(owner.admitInventory([(id,.init(vertices:8,triangles:4))],frame:frame(session,time.now),now:time.now))
        time.now=10.11;owner.observe(.updated,anchorID:id,receiptUptime:time.now)
        XCTAssertNil(owner.audit);XCTAssertTrue(owner.routePoints.isEmpty)
        decode.sync {}
        // Same-ID invalid replacement cannot resurrect earlier floor geometry.
        time.now=10.12
        XCTAssertTrue(owner.ingestOwnedForTesting(id:id) {context in .unknownGap(.init(context:context,anchorID:id,reason:.invalidDescriptor))})
        decode.sync {}
        XCTAssertTrue(owner.admitInventory([(id,.init(vertices:8,triangles:4))],frame:frame(session,10.12),now:10.12))
        owner.check(request(try XCTUnwrap(owner.latestFrame)),stillCurrent:{true})
        let refused=XCTNSPredicateExpectation(predicate:NSPredicate {_,_ in owner.status.contains("Source refused")},object:nil)
        await fulfillment(of:[refused],timeout:10)
        XCTAssertNil(owner.audit);XCTAssertTrue(owner.routePoints.isEmpty)
        time.now=10.2;owner.observe(.removed,anchorID:id,receiptUptime:time.now)
        time.now=10.3
        XCTAssertTrue(owner.admitInventory([(id,.init(vertices:8,triangles:4))],frame:frame(session,time.now),now:time.now))
        decode.sync {};time.now=10.301
        XCTAssertTrue(ownedFloor(owner,id,table:true)) // Same UUID tombstone must be recopied, never resurrected.
        decode.sync {}
        let restored=XCTestExpectation(description:"real restored source after same-ID removal");restored.assertForOverFulfill=true
        var restoredComplete=false
        owner.requestSourceForTesting {result in
            DispatchQueue.main.async {
                if case .success(let source)=result {
                    restoredComplete=source.geometry.sourceDeliveryComplete && source.geometry.unknownCoverage.isEmpty
                        && source.geometry.anchors.map(\.anchorID) == [id.uuidString]
                }
                restored.fulfill()
            }
        }
        await fulfillment(of:[restored],timeout:10);XCTAssertTrue(restoredComplete)
        XCTAssertNil(owner.audit) // Source recovery alone does not revive a retired route.
        guard await awaitDrain(cleanup) else{return}
    }
    @MainActor func testThirtyTwoSequentialAnchorCopiesPreserveHistoricalAgeAndFreshFrameLease() async throws {
        let (owner,time,decode,session,_,cleanup)=fixture(advancingClock:true)
        let ids=(0..<32).map {_ in UUID()}
        let inventory=ids.map {($0,MeshCandidateDiagnostics.Size(vertices:4,triangles:2))}
        XCTAssertTrue(owner.admitInventory(inventory,frame:frame(session,10),now:time.now));decode.sync {}
        // Same production one-whole-copy cadence, while ordinary frame leases
        // advance. No assumption that every old surface was newly observed.
        for (index,id) in ids.enumerated() {
            time.now=10+Double(index+1)/15
            XCTAssertTrue(owner.admitInventory(inventory,frame:frame(session,time.now),now:time.now))
            XCTAssertTrue(ownedFloor(owner,id));decode.sync {}
        }
        let captured=try XCTUnwrap(owner.latestFrame)
        XCTAssertGreaterThan(captured.capturedAt-10,2)
        let source=XCTestExpectation(description:"real complete32 source");source.assertForOverFulfill=true
        var anchorCount=0,complete=false,oldest:Double?,captureAgesUnknown=false
        owner.requestSourceForTesting { result in
            DispatchQueue.main.async {
                if case .success(let snapshot)=result {
                    anchorCount=snapshot.geometry.anchors.count
                    complete=snapshot.geometry.sourceDeliveryComplete && snapshot.geometry.unknownCoverage.isEmpty
                    oldest=snapshot.geometry.records.filter {$0.hasRetainedGeometry}.map(\.receiptUptime).min()
                    captureAgesUnknown=snapshot.geometry.records.allSatisfy {$0.captureUptime == nil}
                }
                source.fulfill()
            }
        }
        await fulfillment(of:[source],timeout:10)
        XCTAssertEqual(anchorCount,32);XCTAssertTrue(complete)
        XCTAssertGreaterThan(time.now - (try XCTUnwrap(oldest)),1.9)
        XCTAssertTrue(captureAgesUnknown)
        XCTAssertEqual(owner.latestFrame,captured) // Snapshot did not rebind the capture.
        XCTAssertNil(owner.audit) // Complete delivery alone never mints support/clearance.
        guard await awaitDrain(cleanup) else{return}
    }
    @MainActor func testActualAuditGoalRetirementAndStopWaitForOperationDisposal() async throws {
        for action in ["goal","source","stop"] {
            let (owner,time,decode,session,id,cleanup)=fixture()
            XCTAssertTrue(owner.admitInventory([(id,.init(vertices:4,triangles:2))],frame:frame(session,10),now:10));decode.sync {}
            time.now=10.001;XCTAssertTrue(ownedFloor(owner,id));decode.sync {}
            var current=true,holding=true,didHold=false,held:CheckedContinuation<Void,Never>?
            let progress=XCTestExpectation(description:"real oracle progress");progress.assertForOverFulfill=true
            owner.auditProgressForTesting={_ in
                guard holding,!didHold else{return};didHold=true
                await withCheckedContinuation {held=$0;progress.fulfill()}
            }
            owner.check(request(try XCTUnwrap(owner.latestFrame)),stillCurrent:{current})
            await fulfillment(of:[progress],timeout:10)
            guard let release=held else {holding=false;owner.stop();XCTFail("No actual oracle progress");return}
            if action == "goal" {current=false;owner.revalidate()}
            else if action == "source" {time.now=10.01;owner.observe(.updated,anchorID:id,receiptUptime:time.now)}
            else {owner.stop()}
            XCTAssertNil(owner.audit);XCTAssertTrue(owner.routePoints.isEmpty)
            cleanup.start() // Terminal discard while real oracle progress is held.
            let nativeACK=XCTNSPredicateExpectation(predicate:NSPredicate {_,_ in owner.nativeDiscardAcknowledgedForTesting},object:nil)
            await fulfillment(of:[nativeACK],timeout:10)
            XCTAssertFalse(cleanup.acknowledged,"Native ACK alone must not release held collision ownership")
            XCTAssertFalse(owner.canYieldCamera,"Disabled/stopped is not an exclusive-camera handoff permission")
            holding=false;release.resume();owner.auditProgressForTesting=nil
            let retired=XCTNSPredicateExpectation(predicate:NSPredicate {_,_ in owner.status.contains("audit unavailable")},object:nil)
            await fulfillment(of:[retired],timeout:10)
            XCTAssertNil(owner.audit);XCTAssertTrue(owner.routePoints.isEmpty)
            guard await awaitDrain(cleanup) else{return} // Before allocating the next native owner.
            // The standalone teardown expectation awaits full native+operation
            // drain once, even after a failed body assertion; no invented ACK.
        }
    }
}
#endif
