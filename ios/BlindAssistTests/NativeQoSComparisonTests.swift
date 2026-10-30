#if DEBUG && BLIND_QOS_COMPARISON && canImport(Darwin)
import Foundation
import XCTest
import BlindRoomMesh

/// Explicit diagnostic lane. Not app acceptance, a benchmark guarantee, or physical guidance.
final class NativeQoSComparisonTests: XCTestCase {
    private final class Box<T>: @unchecked Sendable {
        private let lock=NSLock(); private var value:T?
        func put(_ v:T) { lock.lock(); value=v; lock.unlock() }
        func get()->T? { lock.lock(); defer {lock.unlock()}; return value }
    }
    private func completion(_ description:String)->XCTestExpectation {
        let value=XCTestExpectation(description:description)
        value.assertForOverFulfill=true
        return value
    }
    private func wait(_ done:XCTestExpectation, seconds:Double, phase:String, arm:Int) async -> Bool {
        let result=await XCTWaiter().fulfillment(of:[done],timeout:seconds)
        let passed=result == .completed
        print("NATIVE_QOS_DEADLINE arm=\(arm) phase=\(phase) budget_s=\(seconds) met=\(passed) physical_authority=false")
        if !passed { XCTFail("QoS diagnostic arm \(arm) \(phase) missed original \(seconds)s deadline") }
        return passed
    }
    private func report(_ owner:RoomMeshCandidateRuntime,arm:Int,label:String,elapsed:Double,normalDrain:Bool,lateAck:Bool) {
        let rows=owner.diagnosticStageReceipts
        func pair(_ a:RoomMeshCandidateRuntime.DiagnosticStage,_ b:RoomMeshCandidateRuntime.DiagnosticStage)->String {
            guard let x=rows.first(where:{$0.stage == a}),let y=rows.first(where:{$0.stage == b}),y.elapsedMilliseconds>=x.elapsedMilliseconds else{return "wall_ms=-1,cpu_us=-1,pair_valid=false"}
            let wall=y.elapsedMilliseconds-x.elapsedMilliseconds
            guard let xt=x.workerThreadID,let yt=y.workerThreadID,xt==yt,let xc=x.workerCPUTimeMicroseconds,let yc=y.workerCPUTimeMicroseconds,yc>=xc else{return "wall_ms=\(wall),cpu_us=-1,pair_valid=false"}
            return "wall_ms=\(wall),cpu_us=\(yc-xc),pair_valid=true"
        }
        let stages=rows.map{"\($0.stage.rawValue):\($0.elapsedMilliseconds)"}.joined(separator:";")
        print("NATIVE_QOS_ARM arm=\(arm) requested=\(label) effective_raw=\(owner.syntheticComparisonEffectiveQoS.map(String.init) ?? "unavailable") elapsed_ms=\(Int(elapsed*1000)) normal_drain=\(normalDrain) late_ack=\(lateAck) worker=[\(pair(.workerStarted,.workerFinished))] build=[\(pair(.nativeBuildBegin,.nativeBuildEnd))] route=[\(pair(.routeBegin,.routeEnd))] stages=\(stages) physical_authority=false")
    }
    func testIsolatedUtilityUserInitiatedABBA() async throws {
        // No warmup. Identical fresh-owner geometry for every arm; first sample stays in results.
        let body=try MeshCandidateBody(radius:0.3,height:1.7)
        let order=[false,true,true,false]
        let processStart=ProcessInfo.processInfo.systemUptime
        for (arm,high) in order.enumerated() {
            let began=ProcessInfo.processInfo.systemUptime
            let owner=try RoomMeshCandidateRuntime(sessionID:"qos-synthetic",supportPolicy:.classifiedFloorOnly,
                endpointPolicy:.requireSuppliedXZOverPolygon,captureSyntheticTestTiming:true)
            try owner.configureSyntheticComparisonQoS(userInitiated:high)
            let offered=owner.offer(.init(sessionID:"qos-synthetic",generation:0,anchorID:"floor",revision:1,timestamp:0,
                vertices:[-3,0,-3,-3,0,3,3,0,3,3,0,-3],triangles:[0,1,2,0,2,3],
                columnMajorTransform:[1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1],complete:true,triangleSupport:[.floor,.floor]))
            XCTAssertTrue(offered)
            let sourceDone=completion("source \(arm)")
            let source=Box<Result<MeshSourceGeometrySnapshot,MeshSourceSnapshotError>>()
            let sourceAt=ProcessInfo.processInfo.systemUptime
            let sourceCallback=Box<Double>()
            owner.requestSourceSnapshot { value in
                sourceCallback.put(ProcessInfo.processInfo.systemUptime-sourceAt);source.put(value);sourceDone.fulfill()
            }
            let sourceTimely=await wait(sourceDone,seconds:10,phase:"source",arm:arm)
            var sourceOK=false
            if sourceTimely,case .success(let snapshot)?=source.get() {sourceOK=owner.isCurrent(snapshot)}
            if sourceTimely {XCTAssertTrue(sourceOK,"Source failed or became stale")}
            if sourceOK {
                let queryDone=completion("query \(arm)")
                let query=Box<Result<MeshCandidateRoute,MeshCandidateError>>()
                owner.request(start:[-1,0,0],goal:[1,0,0],body:body) {value in query.put(value);queryDone.fulfill()}
                let queryTimely=await wait(queryDone,seconds:10,phase:"query",arm:arm)
                if queryTimely {
                    switch query.get() {
                    case .success(let route):
                        XCTAssertTrue(route.complete);XCTAssertTrue(owner.isCurrent(route))
                        XCTAssertFalse(route.authorizesPhysicalGuidance);XCTAssertFalse(route.actualWorldCoverageKnown)
                        XCTAssertNotNil(route.endpointAdmission)
                        XCTAssertEqual(route.endpointPolicy,.requireSuppliedXZOverPolygon)
                    default:XCTFail("Native refusal/missing result is not a successful diagnostic arm")
                    }
                }
            }
            // Separate expectations avoid re-waiting on an XCTest expectation that timed out.
            // All are standalone, not registered-but-unwaited XCTestCase expectations.
            let drain=completion("normal drain \(arm)")
            let late=completion("late drain observation \(arm)")
            owner.stopAndDiscard {drain.fulfill();late.fulfill()}
            let drained=await wait(drain,seconds:10,phase:"normal_drain",arm:arm)
            var acknowledged=drained
            if !drained {
                acknowledged=await XCTWaiter().fulfillment(of:[late],timeout:45) == .completed
                // Original failure remains. This is observation only, never recovery-to-pass.
                print("NATIVE_QOS_LATE_DRAIN arm=\(arm) observation_s=45 acknowledged=\(acknowledged) original_failure_preserved=true")
            }
            print("NATIVE_QOS_SOURCE arm=\(arm) callback_ms=\(sourceCallback.get().map{Int($0*1000)} ?? -1) process_offset_ms=\(Int((began-processStart)*1000))")
            report(owner,arm:arm,label:high ? "userInitiated":"utility",elapsed:ProcessInfo.processInfo.systemUptime-began,normalDrain:drained,lateAck:!drained && acknowledged)
            guard acknowledged else {
                XCTFail("No acknowledged native drain; remaining comparison arms ABORTED")
                return
            }
        }
    }
}
#endif
