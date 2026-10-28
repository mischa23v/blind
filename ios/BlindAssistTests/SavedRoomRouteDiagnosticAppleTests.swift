import Foundation
import CryptoKit
import XCTest
import simd
import BlindCore
import BlindRoomMesh
@testable import BlindAssist

/// Original Apple rooms + actual classified Recast + nonphysical waypoint sink +
/// independent native model collision queries. Not a live controller/device trial.
@MainActor final class SavedRoomRouteDiagnosticAppleTests: XCTestCase {
    private let protocolDigest = "ee8f183ca4d7b6fd9aabecf2f7cd8d39bc472ce071873bceafe4c557f65f8123"
    private let width28Digest = "c52792a1213a1b3969e97a6201d43bac2426a444f3f39e8b906a5feb0e0f701d"
    private struct Profile: Decodable {
        let id: String
        let width, depth, height, margin: Double
        var radius: Double { hypot(width, depth) / 2 }
        var effectiveRadius: Float { Float(radius + margin) }
        var effectiveHeight: Float { Float(height + margin) }
    }
    private struct Pair: Decodable {
        let id, room: String
        let start: [Double]?
        let startFeatureFootCenter: UUID?
        let goal: [Double]
    }
    private struct ProtocolInput: Decodable {
        let schema: Int
        let frozenBeforeNativeExecution, physicalAuthority, sourceGeometryExpanded: Bool
        let supportPolicy: String
        let fixtures: [String: String]
        let profiles: [Profile]
        let pairs: [Pair]
    }
    private struct ProfileAddendum: Decodable {
        let schema: Int
        let baseProtocolSHA256: String
        let preregisteredBeforeFirstNativeExecution, physicalAuthority: Bool
        let profiles: [Profile]
    }
    private final class ResultBox: @unchecked Sendable {
        private let lock = NSLock()
        private var stored: Result<MeshCandidateRoute, MeshCandidateError>?
        func put(_ result: Result<MeshCandidateRoute, MeshCandidateError>) { lock.lock(); stored = result; lock.unlock() }
        func get() -> Result<MeshCandidateRoute, MeshCandidateError>? { lock.lock(); defer { lock.unlock() }; return stored }
    }
    /// Candidate waypoint receipts only. No SpatialRouteTicket is fabricated, no
    /// body heading is guessed, and no speech/haptic/movement callback exists.
    private struct WaypointSink {
        private(set) var delivered: [RoomMeshPreview] = []
        mutating func deliver(_ route: MeshCandidateRoute, owner: RoomMeshCandidateRuntime,
                              context: RoomPreviewContext, source: String) throws -> Bool {
            guard owner.isCurrent(route), route.complete else { return false }
            let preview = try RoomMeshPreview(context: context, sourceID: source, points: route.points,
                projectedStart: route.projectedStart, projectedGoal: route.projectedGoal,
                complete: route.complete, nativeStatus: route.nativeStatus,
                unknownCoverage: route.unknownCoverage + ["historical-room-only", "body-pose-and-current-coverage-unknown"],
                sourceDeliveryComplete: route.sourceDeliveryComplete)
            guard owner.isCurrent(route), !preview.physicalAuthority else { return false }
            delivered.append(preview); return true
        }
        mutating func retire() { delivered.removeAll() }
    }
    private func sha(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    private func loadProtocol() throws -> ProtocolInput {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "PROTOCOL", withExtension: "json", subdirectory: "RoomRouteDiagnostic"))
        let data = try Data(contentsOf: url)
        XCTAssertEqual(sha(data), protocolDigest, "Do not alter endpoints/profiles after observing results")
        let input = try JSONDecoder().decode(ProtocolInput.self, from: data)
        XCTAssertEqual(input.schema, 1); XCTAssertTrue(input.frozenBeforeNativeExecution)
        XCTAssertFalse(input.physicalAuthority); XCTAssertFalse(input.sourceGeometryExpanded)
        XCTAssertEqual(input.supportPolicy, "classifiedFloorOnly")
        XCTAssertEqual(input.pairs.count, 6); XCTAssertEqual(input.profiles.count, 2)
        return input
    }
    private func mesh(room: String, digest: String) async throws -> SavedRoomRouteMeshSnapshot {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "\(room).capturedRoom", withExtension: "json", subdirectory: "RoomPlanApple"))
        let bytes = try Data(contentsOf: url)
        XCTAssertEqual(sha(bytes), digest)
        return try await Task.detached(priority: .utility) {
            try SavedRoomRouteMeshAdapter.decode(data: bytes, expectedSHA256: digest)
        }.value
    }
    private func point(_ local: [Double], floor: SavedRoomRouteMeshSnapshot.Feature) throws -> SIMD3<Float> {
        guard local.count == 3, local.allSatisfy(\.isFinite), floor.kind == .floor, floor.transform.count == 16 else { throw BenchFailure.invalidProtocol }
        let t = floor.transform
        var coordinates: [Float] = []
        for row in 0..<3 {
            let x: Double = t[row] * local[0]
            let y: Double = t[4 + row] * local[1]
            let z: Double = t[8 + row] * local[2]
            let component: Double = ((x + y) + z) + t[12 + row]
            coordinates.append(Float(component))
        }
        return SIMD3<Float>(coordinates[0], coordinates[1], coordinates[2])
    }
    private func start(_ pair: Pair, floor: SavedRoomRouteMeshSnapshot.Feature, mesh: SavedRoomRouteMeshSnapshot) throws -> SIMD3<Float> {
        if let local = pair.start { guard pair.startFeatureFootCenter == nil else { throw BenchFailure.invalidProtocol }; return try point(local, floor: floor) }
        let id = try XCTUnwrap(pair.startFeatureFootCenter)
        let feature = try XCTUnwrap(mesh.features.first { $0.id == id && $0.kind == .furniture })
        // Explicit fixture construction: source furniture's horizontal centre,
        // projected onto the ORIGINAL source floor plane, not Detour or camera.
        let t = floor.transform, d = (0..<3).map { feature.transform[12 + $0] - t[12 + $0] }
        let localX = (0..<3).reduce(0.0) { $0 + t[$1] * d[$1] }
        let localY = (0..<3).reduce(0.0) { $0 + t[4 + $1] * d[$1] }
        return try point([localX, localY, 0], floor: floor)
    }
    private enum BenchFailure: Error { case invalidProtocol, queryTimedOut }
    private func query(_ owner: RoomMeshCandidateRuntime, from: SIMD3<Float>, to: SIMD3<Float>, profile: Profile) async throws -> Result<MeshCandidateRoute, MeshCandidateError> {
        let done = expectation(description: "actual classified Detour query"), box = ResultBox()
        owner.request(start: [from.x,from.y,from.z], goal: [to.x,to.y,to.z],
            body: try .init(radius: profile.effectiveRadius, height: profile.effectiveHeight)) { box.put($0); done.fulfill() }
        await fulfillment(of: [done], timeout: 15)
        guard let result = box.get() else { throw BenchFailure.queryTimedOut }
        return result
    }
    private func discard(_ owner: RoomMeshCandidateRuntime) async {
        let done = expectation(description: "candidate owner terminal discard")
        owner.stopAndDiscard { done.fulfill() }; await fulfillment(of: [done], timeout: 15)
    }
    private func array(_ point: SIMD3<Float>) -> [Float] { [point.x,point.y,point.z] }
    private func vector(_ point: [Float]) throws -> SIMD3<Float> {
        guard point.count == 3, point.allSatisfy(\.isFinite) else { throw BenchFailure.invalidProtocol }
        return SIMD3(point[0],point[1],point[2])
    }
    private struct ScoredSegment {
        let kind: String
        let from, to: SIMD3<Float>
    }
    /// Stitch ONLY the exact requested/projected/native endpoints. This is not
    /// route repair: every association edge stays named and independently scored.
    private func scoredSegments(start: SIMD3<Float>, projectedStart: SIMD3<Float>,
                                points: [SIMD3<Float>], projectedGoal: SIMD3<Float>,
                                goal: SIMD3<Float>, complete: Bool) throws -> [ScoredSegment] {
        guard let first=points.first, let last=points.last,
              ([start,projectedStart,projectedGoal,goal]+points).allSatisfy({
                  [$0.x,$0.y,$0.z].allSatisfy(\.isFinite)
              }) else { throw BenchFailure.invalidProtocol }
        var segments=[ScoredSegment(kind:"requested-start-to-projection",from:start,to:projectedStart)]
        if first != projectedStart {
            segments.append(ScoredSegment(kind:"projection-to-detour-start",from:projectedStart,to:first))
        }
        if points.count>1 { for index in 1..<points.count {
            segments.append(ScoredSegment(kind:"detour-segment-\(index)",from:points[index-1],to:points[index]))
        } }
        if complete {
            if last != projectedGoal {
                segments.append(ScoredSegment(kind:"detour-end-to-projection",from:last,to:projectedGoal))
            }
            segments.append(ScoredSegment(kind:"projection-to-requested-goal",from:projectedGoal,to:goal))
        }
        var endpoint=start
        for segment in segments {
            guard segment.from == endpoint else { throw BenchFailure.invalidProtocol }
            endpoint=segment.to
        }
        guard endpoint == (complete ? goal : last) else { throw BenchFailure.invalidProtocol }
        return segments
    }
    func testScoredChainRetainsBothNativeEndpointDiscrepanciesAndNeverBridgesPartialGoal() throws {
        // Synthetic chain bookkeeping control only, not an Apple geometry pass.
        let requestedStart=SIMD3<Float>(0,0,0), projectedStart=SIMD3<Float>(1,0,0)
        let points=[SIMD3<Float>(1,0.1,0),SIMD3<Float>(2,0.1,0)]
        let projectedGoal=SIMD3<Float>(2,0,0), requestedGoal=SIMD3<Float>(3,0,0)
        let complete=try scoredSegments(start:requestedStart,projectedStart:projectedStart,
            points:points,projectedGoal:projectedGoal,goal:requestedGoal,complete:true)
        XCTAssertEqual(complete.map(\.kind),["requested-start-to-projection","projection-to-detour-start",
            "detour-segment-1","detour-end-to-projection","projection-to-requested-goal"])
        XCTAssertEqual(complete.first?.from,requestedStart); XCTAssertEqual(complete.last?.to,requestedGoal)
        for index in 1..<complete.count { XCTAssertEqual(complete[index-1].to,complete[index].from) }
        let partial=try scoredSegments(start:requestedStart,projectedStart:projectedStart,
            points:points,projectedGoal:projectedGoal,goal:requestedGoal,complete:false)
        XCTAssertEqual(partial.map(\.kind),["requested-start-to-projection","projection-to-detour-start","detour-segment-1"])
        XCTAssertEqual(partial.last?.to,points.last)
        XCTAssertThrowsError(try scoredSegments(start:requestedStart,projectedStart:projectedStart,
            points:[],projectedGoal:projectedGoal,goal:requestedGoal,complete:true))
    }
    private func attachment(_ results: [[String: Any]], errors: [String], label: String) throws {
        let data = try JSONSerialization.data(withJSONObject: ["schema":1,"protocolSHA256":protocolDigest,
            "profileAddendumSHA256":label == "width28-addendum" ? width28Digest : "none", "schedule":label,
            "physicalAuthority":false,"currentCoverageKnown":false,"fullFootprintSupportVerified":false,
            "scope":"candidate waypoint replay; not controller/device arrival", "outcomes":results,"errors":errors], options: [.prettyPrinted,.sortedKeys])
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "APPLE_ROOM_ROUTE_\(label)_OUTCOMES.json"; attachment.lifetime = .keepAlways; add(attachment)
    }

    func testPredeclaredApplePathsWaypointSinkAndIndependentFullBodySweeps() async throws {
        let input = try loadProtocol()
        try await execute(input: input, profiles: input.profiles, expectedCount: 12, label: "original-baseline")
    }
    func testSeparatelyPreregistered28cmWidthDoesNotReplaceBaseline() async throws {
        let input = try loadProtocol()
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "PROFILE_28CM_ADDENDUM", withExtension: "json", subdirectory: "RoomRouteDiagnostic"))
        let bytes = try Data(contentsOf: url)
        XCTAssertEqual(sha(bytes),width28Digest)
        let addendum = try JSONDecoder().decode(ProfileAddendum.self,from:bytes)
        XCTAssertEqual(addendum.schema,1); XCTAssertEqual(addendum.baseProtocolSHA256,protocolDigest)
        XCTAssertTrue(addendum.preregisteredBeforeFirstNativeExecution); XCTAssertFalse(addendum.physicalAuthority)
        XCTAssertEqual(addendum.profiles.count,1)
        let profile = try XCTUnwrap(addendum.profiles.first)
        XCTAssertEqual(profile.width,0.28); XCTAssertEqual(profile.depth,0.20)
        XCTAssertEqual(profile.height,1.20); XCTAssertEqual(profile.margin,0.15)
        try await execute(input: input, profiles: addendum.profiles, expectedCount: 6, label: "width28-addendum")
    }
    private func execute(input: ProtocolInput, profiles: [Profile], expectedCount: Int, label: String) async throws {
        var results: [[String: Any]] = [], errors: [String] = []
        var completedCandidates = 0, conflictingCompleteCandidates = 0
        var terminalReportWritten = false
        defer {
            if !terminalReportWritten {
                // A timeout/throw is not a vanishing denominator or a passing
                // subset. Preserve the prefix plus explicit unexecuted schedules.
                let completed = Set(results.compactMap { record -> String? in
                    guard let pair = record["pair"] as? String, let profile = record["profile"] as? String else { return nil }
                    return pair+":"+profile
                })
                for pair in input.pairs { for profile in profiles where !completed.contains(pair.id+":"+profile.id) {
                    results.append(["pair":pair.id,"profile":profile.id,"outcome":"not-run-after-aborted-stage"])
                } }
                errors.append("Stage threw before terminal reporting; unexecuted schedules are not passes")
                try? attachment(results,errors:errors,label:label)
            }
        }
        for room in input.fixtures.keys.sorted() {
            let digest = try XCTUnwrap(input.fixtures[room])
            let snapshot: SavedRoomRouteMeshSnapshot
            do { snapshot = try await mesh(room: room, digest: digest) }
            catch {
                for pair in input.pairs where pair.room == room { for profile in profiles {
                    results.append(["pair":pair.id,"profile":profile.id,"outcome":"unsupported-geometry","error":String(describing:error)])
                } }
                errors.append("\(room): \(error)"); continue
            }
            let floor = try XCTUnwrap(snapshot.features.first { $0.kind == .floor })
            guard snapshot.upwardFloorTriangles > 0 else { throw BenchFailure.invalidProtocol }
            let boxes = snapshot.features.filter { $0.kind == .furniture }.map {
                SavedRoomRouteCollisionOracle.FurnitureBox(featureID: $0.id, dimensions: $0.dimensions, transform: $0.transform)
            }
            let oracle: SavedRoomRouteCollisionOracle
            do { oracle = try .init(vertices: snapshot.vertices, triangles: snapshot.triangles,
                floorSupport: snapshot.floorSupport, triangleFeatureIDs: snapshot.triangleFeatureIDs, furnitureBoxes: boxes) }
            catch {
                for pair in input.pairs where pair.room == room { for profile in profiles {
                    results.append(["pair":pair.id,"profile":profile.id,"outcome":"collision-backend-unavailable","error":String(describing:error)])
                } }
                errors.append("\(room) collision backend unavailable: \(error)"); continue
            }
            let owner = try RoomMeshCandidateRuntime(sessionID: "apple-fixture-\(UUID().uuidString)", supportPolicy: .classifiedFloorOnly)
            // A throwing fixture still terminally fences this owner. Successful
            // paths additionally await acknowledgement below; an abort does not
            // claim that a still-running native job was already released.
            defer { owner.stopAndDiscard {} }
            // A fixture runtime's session ID is ownership only, never an ARSession.
            let session = "apple-fixture-\(room)"
            try owner.reset(sessionID: session, generation: 1)
            let identity: [Double] = [1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1]
            let accepted = owner.offer(.init(sessionID: session, generation: 1, anchorID: digest, revision: 1,
                timestamp: 0, vertices: snapshot.vertices, triangles: snapshot.triangles, columnMajorTransform: identity,
                complete: true, triangleSupport: snapshot.floorSupport.map { $0 ? .floor : .obstacle }))
            XCTAssertTrue(accepted)
            var sink = WaypointSink()
            let context = try RoomPreviewContext(placeID: "original-apple-fixture", floorID: floor.id.uuidString,
                roomID: room, frameID: "original-CapturedRoom:\(digest)",
                poseProvenance: "declared fixture floor query; not camera/body localization",
                supportProvenance: "original historical floor polygon; current full-footprint support unknown")
            for pair in input.pairs where pair.room == room { for profile in profiles {
                let a = try start(pair, floor: floor, mesh: snapshot), b = try point(pair.goal, floor: floor)
                // Planner receives only original RoomPlan mesh and declared inputs.
                // Oracle results never select, repair or re-query a route.
                let candidate = try await query(owner, from: a, to: b, profile: profile)
                let initialBody = try oracle.sweep(from: a, to: a, radius: Float(profile.radius), height: Float(profile.height))
                let initialMargin = try oracle.sweep(from: a, to: a, radius: profile.effectiveRadius, height: profile.effectiveHeight)
                let invalidStart = initialBody.all.hasObstacleContact || initialMargin.all.hasObstacleContact
                var record: [String: Any] = ["pair":pair.id,"profile":profile.id,"sourceSHA256":digest,
                    "requestedStart":array(a),"requestedGoal":array(b),"rawRadius":profile.radius,"rawHeight":profile.height,
                    "effectiveRadius":profile.effectiveRadius,"effectiveHeight":profile.effectiveHeight,
                    "initialBodyContact":initialBody.all.hasObstacleContact,"initialMarginContact":initialMargin.all.hasObstacleContact,
                    "initialFurnitureBoundIDs":initialMargin.all.furnitureBoundIDs.map(\.uuidString).sorted(),
                    "fullFootprintSupportVerified":false,"physicalAuthority":false]
                switch candidate {
                case .failure(let error):
                    record["outcome"] = invalidStart ? "invalid-start-contact" : "native-query-failure"
                    record["nativeError"] = String(describing:error); record["waypointSinkDelivered"] = false
                case .success(let route):
                    let delivered = try sink.deliver(route, owner: owner, context: context, source: digest+":"+pair.id+":"+profile.id)
                    record["waypointSinkDelivered"] = delivered
                    record["nativeComplete"] = route.complete; record["nativeStatus"] = route.nativeStatus
                    record["routePoints"] = route.points; record["projectedStart"] = route.projectedStart; record["projectedGoal"] = route.projectedGoal
                    let ps = try vector(route.projectedStart), pg = try vector(route.projectedGoal)
                    record["startProjectionMetres"] = simd_distance(a,ps); record["goalProjectionMetres"] = simd_distance(b,pg)
                    var bodyContact = initialBody.all.hasObstacleContact, marginContact = initialMargin.all.hasObstacleContact
                    var floorIDs = initialMargin.all.floorSurfaceIDs, surfaceIDs = initialMargin.all.obstacleSurfaceIDs, boundIDs = initialMargin.all.furnitureBoundIDs
                    // Complete exact chain, including any Detour endpoint
                    // clamping discrepancy. Never silently bridge unscored space.
                    let points = try route.points.map(vector)
                    let segments = try scoredSegments(start:a,projectedStart:ps,points:points,
                        projectedGoal:pg,goal:b,complete:route.complete)
                    record["scoredChainContinuous"] = true
                    record["scoredChainIncludesRequestedGoal"] = route.complete
                    record["sourceFloorSupportAlongScoredChain"] = "unverified-full-footprint"
                    var segmentRecords: [[String:Any]] = []
                    for segment in segments {
                        let name=segment.kind, from=segment.from, to=segment.to
                        let body = try oracle.sweep(from:from,to:to,radius:Float(profile.radius),height:Float(profile.height))
                        let margin = try oracle.sweep(from:from,to:to,radius:profile.effectiveRadius,height:profile.effectiveHeight)
                        bodyContact = bodyContact || body.all.hasObstacleContact; marginContact = marginContact || margin.all.hasObstacleContact
                        floorIDs.formUnion(margin.all.floorSurfaceIDs); surfaceIDs.formUnion(margin.all.obstacleSurfaceIDs); boundIDs.formUnion(margin.all.furnitureBoundIDs)
                        segmentRecords.append(["kind":name,"from":array(from),"to":array(to),
                            "bodyContact":body.all.hasObstacleContact,"marginContact":margin.all.hasObstacleContact,
                            "floorContactIDs":margin.all.floorSurfaceIDs.map(\.uuidString).sorted(),
                            "fullFootprintSupportVerified":false,"sourceFloorSupport":"unverified-full-footprint"])
                        // Floor contact is reported separately, not promoted to
                        // positive footprint/continuous support or physical arrival.
                        XCTAssertFalse(body.fullFootprintSupportVerified)
                        XCTAssertFalse(margin.fullFootprintSupportVerified)
                    }
                    record["segments"] = segmentRecords; record["bodyContact"] = bodyContact; record["marginContact"] = marginContact
                    record["floorContactIDs"] = floorIDs.map(\.uuidString).sorted(); record["obstacleSurfaceIDs"] = surfaceIDs.map(\.uuidString).sorted(); record["furnitureBoundIDs"] = boundIDs.map(\.uuidString).sorted()
                    record["outcome"] = invalidStart ? "invalid-start-contact" : (!route.complete ? "partial-route" : (bodyContact || marginContact ? "candidate-contact" : "candidate-model-route-no-contact"))
                    if route.complete { completedCandidates += 1; if bodyContact || marginContact { conflictingCompleteCandidates += 1 } }
                    if pair.id == "hall-missing-floor" { XCTAssertFalse(route.complete, "Original concave floor gap cannot become a completed route") }
                    if delivered {
                        let preview = try XCTUnwrap(sink.delivered.last)
                        XCTAssertEqual(preview.points, route.points); XCTAssertFalse(preview.physicalAuthority)
                        XCTAssertEqual(preview.state, .withheldUnknownCoverage)
                    }
                    owner.invalidate(); sink.retire()
                    XCTAssertFalse(try sink.deliver(route, owner:owner, context:context, source:digest))
                    XCTAssertTrue(sink.delivered.isEmpty)
                }
                results.append(record)
            } }
            await discard(owner)
        }
        try attachment(results,errors:errors,label:label) // preserve outcomes BEFORE assertions
        terminalReportWritten = true
        XCTAssertEqual(results.count,expectedCount,"All frozen schedules must be accounted for, including unsupported/stopped cases")
        XCTAssertTrue(errors.isEmpty, errors.joined(separator:"; "))
        XCTAssertGreaterThan(completedCandidates,0,"No complete candidate route was exercised; no-path is not success")
        XCTAssertEqual(conflictingCompleteCandidates,0,"Original-model body/margin contact is a failed candidate, not a successful stop")
    }
}
