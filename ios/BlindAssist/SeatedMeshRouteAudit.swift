#if DEBUG && BLIND_MESH_CANDIDATE_DIAGNOSTICS
import Foundation
import SceneKit
import simd
import BlindRoomMesh

/// Independent source-surface collision diagnostic, never physical clearance.
/// The only collision implementation is the shared Apple oracle and its controls.
@MainActor
enum SeatedMeshRouteAudit {
    enum Failure: Error { case invalid, incomplete, budget, retired }
    enum Role: String, Hashable { case floor, obstacle, unavailable }
    struct Origin: Equatable { let anchorID: String; let role: Role }
    struct Anchor {
        let id: String, local: [Double], transform: [Double], triangles: [Int32]
        let roles: [MeshTriangleSupport]?
    }
    struct Request: Equatable {
        let id: UUID
        let start: [Float], goal: [Float]
        let radius: Float, height: Float, margin: Float
        var valid: Bool {
            [start,goal].allSatisfy { $0.count == 3 && $0.allSatisfy(\.isFinite) }
                && radius.isFinite && height.isFinite && margin.isFinite
                && (0.1...2).contains(radius) && (0.5...3).contains(height)
                && (0...0.5).contains(margin) && radius+margin <= 2 && height+margin <= 3
        }
    }
    struct Progress {let segment:Int;let envelope:String}
    struct Segment { let name: String; let from: SIMD3<Float>, to: SIMD3<Float> }
    struct Hit {
        let segment: String
        let initial: SavedRoomRouteCollisionOracle.Contacts
        let swept: SavedRoomRouteCollisionOracle.Contacts
        let terminal: SavedRoomRouteCollisionOracle.Contacts
        var blocked: Bool { initial.hasObstacleContact || swept.hasObstacleContact || terminal.hasObstacleContact }
        var obstacleIDs: Set<UUID> { initial.obstacleSurfaceIDs.union(swept.obstacleSurfaceIDs).union(terminal.obstacleSurfaceIDs) }
        var floorIDs: Set<UUID> { initial.floorSurfaceIDs.union(swept.floorSurfaceIDs).union(terminal.floorSurfaceIDs) }
    }
    struct Receipt {
        let session: String, generation: Int, revision: UInt64
        let request: Request, identities: [UUID:Origin]
        let raw: [Hit], margin: [Hit], complete: Bool
        let supportVerified = false, physicalAuthority = false, containedStartVerified = false
        var text: String {
            "Same-source independent collision algorithm: raw body contact segments \(raw.filter(\.blocked).count)/\(raw.count); explicit margin contact segments \(margin.filter(\.blocked).count)/\(margin.count). Native complete=\(complete), source revision \(revision). Unavailable-role groups \(identities.values.filter {$0.role == .unavailable}.count). No-hit is NOT clear space. Same sensor evidence, not an independent observation. Floor contacts, support, occlusion, missing volumes and contained starts remain unverified. Not walking guidance."
        }
        /// Full bounded contact sets remain in this receipt. UI summaries explicitly
        /// disclose both row and per-kind identity truncation; nothing is erased.
        var detailLines:[String] {
            var lines=[String]()
            for (label,hits) in [("raw",raw),("margin",margin)] {
                var rows=[(Bool,String)]()
                for hit in hits {
                    for (phase,contacts) in [("initial",hit.initial),("swept",hit.swept),("terminal",hit.terminal)] {
                        func describe(_ ids:Set<UUID>)->String {
                            let values=ids.map {id -> String in
                                guard let origin=identities[id] else {return "UNRESOLVED query identity"}
                                return "\(origin.anchorID):\(origin.role.rawValue)"
                            }.sorted()
                            return values.prefix(8).joined(separator:",") + (values.count>8 ? " [first8of\(values.count); full set retained]" : "")
                        }
                        rows.append((contacts.hasObstacleContact,"\(label) \(hit.segment) \(phase): obstacle=[\(describe(contacts.obstacleSurfaceIDs))]; floor=[\(describe(contacts.floorSurfaceIDs))]; solid bounds=\(contacts.furnitureBoundIDs.count) (none inferred)."))
                    }
                }
                // Show obstacle-bearing rows first while retaining every phase in
                // structured storage. A floor row never establishes support.
                let ordered=rows.enumerated().sorted {a,b in a.element.0 == b.element.0 ? a.offset < b.offset : a.element.0 && !b.element.0}
                lines.append("\(label): showing first\(min(24,rows.count))of\(rows.count) phase rows; full bounded receipt retained.")
                lines += ordered.prefix(24).map {$0.element.1}
            }
            return lines
        }
    }

    struct Geometry {
        let vertices: [Double], triangles: [Int32], floor: [Bool], ids: [UUID]
        let origins: [UUID:Origin]
    }
    // Diagnostic admission bounds, not measured iPhone timing/performance claims.
    static let maxSegments=64, maxAnchors=64, maxVertexValues=90_000, maxIndices=90_000
    static func prepare(_ anchors: [Anchor]) throws -> Geometry {
        guard !anchors.isEmpty, anchors.count <= maxAnchors,
              anchors.reduce(0,{$0+$1.local.count}) <= maxVertexValues,
              anchors.reduce(0,{$0+$1.triangles.count}) <= maxIndices,
              Set(anchors.map(\.id)).count == anchors.count else { throw Failure.budget }
        var vertices=[Double](), triangles=[Int32](), floor=[Bool](), ids=[UUID](), origins=[UUID:Origin]()
        for anchor in anchors {
            guard !anchor.id.isEmpty, anchor.id.utf8.count <= 128,
                  !anchor.local.isEmpty, !anchor.triangles.isEmpty, anchor.triangles.count % 3 == 0,
                  anchor.roles == nil || anchor.roles?.count == anchor.triangles.count/3,
                  let positions=SeatedMeshProjection.worldVertices(local:anchor.local,transform:anchor.transform),
                  anchor.triangles.allSatisfy({$0 >= 0 && Int($0) < positions.count}) else { throw Failure.invalid }
            let offset=Int32(vertices.count/3)
            // Exactly one original transform; preserve Y, every triangle and role.
            vertices += positions.flatMap { [Double($0.x),Double($0.y),Double($0.z)] }
            triangles += anchor.triangles.map { $0+offset }
            var roleIDs=[Role:UUID]()
            for index in 0..<(anchor.triangles.count/3) {
                let role: Role
                if let roles=anchor.roles { role = roles[index] == .floor ? .floor : .obstacle }
                else { role = .unavailable }
                let id: UUID
                if let existing=roleIDs[role] { id=existing }
                else { id=UUID();roleIDs[role]=id;origins[id]=Origin(anchorID:anchor.id,role:role) }
                ids.append(id);floor.append(role == .floor)
            }
        }
        return Geometry(vertices:vertices,triangles:triangles,floor:floor,ids:ids,origins:origins)
    }
    static func segments(request: Request, projectedStart: [Float], projectedGoal: [Float],
                         points: [[Float]], complete: Bool) throws -> [Segment] {
        guard request.valid,!points.isEmpty,points.count <= maxSegments-4 else { throw Failure.invalid }
        func vector(_ p:[Float]) throws -> SIMD3<Float> {
            guard p.count == 3,p.allSatisfy(\.isFinite) else {throw Failure.invalid}
            return SIMD3(p[0],p[1],p[2])
        }
        let start=try vector(request.start),goal=try vector(request.goal),ps=try vector(projectedStart),pg=try vector(projectedGoal)
        let path=try points.map(vector)
        var result=[Segment(name:"requested-start-to-projection",from:start,to:ps),
                    Segment(name:"projection-to-detour-start",from:ps,to:path[0])]
        if path.count>1 {for i in 1..<path.count {result.append(Segment(name:"detour-\(i)",from:path[i-1],to:path[i]))}}
        // Even a zero-length route still receives actual initial/terminal overlaps.
        if complete {
            result += [Segment(name:"detour-end-to-projection",from:path.last!,to:pg),
                       Segment(name:"projection-to-requested-goal",from:pg,to:goal)]
        }
        guard result.count <= maxSegments else {throw Failure.budget}
        return result
    }
    static func run(source: MeshSourceGeometrySnapshot, route: MeshCandidateRoute, request: Request,
                    isCurrent: @escaping () -> Bool, progress: ((Progress) async -> Void)? = nil) async throws -> Receipt {
        guard isCurrent(), request.valid,
              source.sessionID == route.sessionID, source.generation == route.generation, source.revision == route.revision,
              source.sourceDeliveryComplete,source.unknownCoverage.isEmpty,
              route.sourceDeliveryComplete,route.unknownCoverage.isEmpty,
              route.endpointPolicy == .requireSuppliedXZOverPolygon,
              let admission=route.endpointAdmission,
              admission.start.requested == request.start,admission.goal.requested == request.goal,
              admission.start.projected == route.projectedStart,admission.goal.projected == route.projectedGoal,
              admission.start.found,admission.goal.found,admission.start.isOverPolygon,admission.goal.isOverPolygon
        else {throw Failure.invalid}
        let geometry=try prepare(source.anchors.map {Anchor(id:$0.anchorID,local:$0.localVertices,transform:$0.columnMajorTransform,triangles:$0.triangleIndices,roles:$0.normalizedSupportRoles)})
        let chain=try segments(request:request,projectedStart:route.projectedStart,projectedGoal:route.projectedGoal,points:route.points,complete:route.complete)
        let hits=try await query(geometry:geometry,segments:chain,request:request,isCurrent:isCurrent,progress:progress)
        guard isCurrent() else {throw Failure.retired}
        return Receipt(session:source.sessionID,generation:source.generation,revision:source.revision,request:request,
                       identities:geometry.origins,raw:hits.0,margin:hits.1,complete:route.complete)
    }
    /// Explicit authored fixture seam uses the SAME oracle and controls; it cannot
    /// construct a native route/source or grant a source-bound Receipt.
    static func query(geometry: Geometry, segments: [Segment], request: Request,
                      isCurrent: @escaping () -> Bool, progress: ((Progress) async -> Void)? = nil) async throws -> ([Hit],[Hit]) {
        guard request.valid,!segments.isEmpty,segments.count <= maxSegments else {throw Failure.budget}
        let started=ProcessInfo.processInfo.systemUptime
        func check() throws {
            guard !Task.isCancelled,isCurrent() else {throw Failure.retired}
            guard ProcessInfo.processInfo.systemUptime-started <= 5 else {throw Failure.budget}
        }
        await Task.yield();try check()
        // No invented solid bounds from a triangle shell. Mandatory backend
        // controls can throw; that is unavailable, never an empty contact list.
        let oracle=try SavedRoomRouteCollisionOracle(vertices:geometry.vertices,triangles:geometry.triangles,
            floorSupport:geometry.floor,triangleFeatureIDs:geometry.ids,furnitureBoxes:[])
        var raw=[Hit](),margin=[Hit]()
        for (index,segment) in segments.enumerated() {
            await Task.yield();try check()
            let a=try oracle.sweep(from:segment.from,to:segment.to,radius:request.radius,height:request.height)
            raw.append(Hit(segment:segment.name,initial:a.initial,swept:a.swept,terminal:a.terminal))
            await progress?(Progress(segment:index,envelope:"raw"))
            await Task.yield();try check()
            let b=try oracle.sweep(from:segment.from,to:segment.to,radius:request.radius+request.margin,height:request.height+request.margin)
            margin.append(Hit(segment:segment.name,initial:b.initial,swept:b.swept,terminal:b.terminal))
            await progress?(Progress(segment:index,envelope:"margin"))
        }
        try check();return(raw,margin)
        // Each native call is synchronous and cannot be preempted; cancellation
        // is between calls. Caller retains exclusive ownership until task drains.
    }
}
#endif
