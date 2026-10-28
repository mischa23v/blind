import Foundation
import SceneKit
import simd

/// Test-only, independently queried Apple physics shapes. Not a planner, sensor,
/// support verifier or physical-output owner. The app target must not include it.
///
/// Static concave shapes retain the exported triangle surfaces. Original RoomPlan
/// furniture bounds are separate solid SCNBox shapes so a contained start is not
/// incorrectly cleared by a triangle-shell query. Their contacts stay separate:
/// a box bound is not a claim that legs, recesses or object interiors were scanned.
/// SceneKit is deprecated but remains a platform implementation on the iOS 17+
/// test deployment target; no new collision algorithm or third-party dependency.
/// Apple API references (reviewed 2026-10-28; native execution still required):
/// https://developer.apple.com/documentation/scenekit/scnphysicsworld/convexsweeptest(with:from:to:options:)
/// https://developer.apple.com/documentation/scenekit/scnphysicsworld/contacttest(with:options:)
/// https://developer.apple.com/documentation/scenekit/scnphysicsworld/updatecollisionpairs()
/// https://developer.apple.com/documentation/scenekit/scnphysicsshape/init(geometry:options:)
/// https://developer.apple.com/documentation/scenekit/scnphysicsshape/shapetype/concavepolyhedron
@MainActor
final class SavedRoomRouteCollisionOracle {
    enum Failure: Error, Equatable {
        case invalidGeometry, invalidQuery, invalidFurnitureBox
        case backendUnavailable(String)
    }

    struct FurnitureBox: Sendable {
        let featureID: UUID
        let dimensions: [Double]
        /// Original feature-to-saved-world column-major rigid transform.
        let transform: [Double]
    }

    struct Contacts: Equatable, Sendable {
        var obstacleSurfaceIDs = Set<UUID>()
        var floorSurfaceIDs = Set<UUID>()
        var furnitureBoundIDs = Set<UUID>()
        var hasObstacleContact: Bool { !obstacleSurfaceIDs.isEmpty || !furnitureBoundIDs.isEmpty }
        mutating func formUnion(_ other: Contacts) {
            obstacleSurfaceIDs.formUnion(other.obstacleSurfaceIDs)
            floorSurfaceIDs.formUnion(other.floorSurfaceIDs)
            furnitureBoundIDs.formUnion(other.furnitureBoundIDs)
        }
    }

    struct SweepResult: Sendable {
        let initial: Contacts
        let swept: Contacts
        let terminal: Contacts
        /// Whole-footprint support is deliberately NOT inferred from floor contact
        /// or from absence of a non-floor collision. Holes remain unverified here.
        let fullFootprintSupportVerified = false
        let physicalAuthority = false
        var all: Contacts { var value = initial; value.formUnion(swept); value.formUnion(terminal); return value }
    }

    private enum Kind { case obstacleSurface, floorSurface, furnitureBound }
    private struct Identity { let id: UUID; let kind: Kind }
    private struct Group: Hashable { let id: UUID; let floor: Bool }
    private let scene = SCNScene()
    private var identities: [ObjectIdentifier: Identity] = [:]
    private let sourceMask = 1
    private let probeMask = 2

    /// Array limits match the existing mesh package; no triangles are truncated.
    /// Geometry stays uninflated. Caller-supplied query radius/height already carry
    /// the declared body/margin variant. Physics collision margin is exactly zero.
    convenience init(vertices: [Double], triangles: [Int32], floorSupport: [Bool],
                     triangleFeatureIDs: [UUID], furnitureBoxes: [FurnitureBox] = []) throws {
        try self.init(vertices: vertices, triangles: triangles, floorSupport: floorSupport,
                      triangleFeatureIDs: triangleFeatureIDs, furnitureBoxes: furnitureBoxes,
                      checkBackend: true)
    }

    private init(vertices: [Double], triangles: [Int32], floorSupport: [Bool],
                 triangleFeatureIDs: [UUID], furnitureBoxes: [FurnitureBox], checkBackend: Bool) throws {
        guard !vertices.isEmpty, vertices.count % 3 == 0, vertices.count <= 600_000,
              !triangles.isEmpty, triangles.count % 3 == 0, triangles.count <= 300_000,
              floorSupport.count == triangles.count / 3, triangleFeatureIDs.count == floorSupport.count,
              vertices.allSatisfy({ $0.isFinite && abs($0) <= 10_000 && Float($0).isFinite }),
              triangles.allSatisfy({ $0 >= 0 && Int($0) < vertices.count / 3 }),
              Set(triangleFeatureIDs).count <= 512, furnitureBoxes.count <= 512,
              Set(furnitureBoxes.map(\.featureID)).count == furnitureBoxes.count else { throw Failure.invalidGeometry }
        scene.physicsWorld.gravity = SCNVector3Zero
        // There is no dynamic actor, render loop, AR session or gravity integration.
        // Queries follow explicit resetTransform/updateCollisionPairs calls below.
        scene.physicsWorld.speed = 0
        let positions = vertices.map(Float.init)
        // Reject an exported triangle that collapses at the physics API's Float32
        // boundary; do not silently drop it and interpret the gap as clear space.
        for offset in stride(from: 0, to: triangles.count, by: 3) {
            func point(_ index: Int32) -> SIMD3<Float> {
                let i = Int(index) * 3
                return SIMD3(positions[i], positions[i + 1], positions[i + 2])
            }
            let a = point(triangles[offset]), b = point(triangles[offset + 1]), c = point(triangles[offset + 2])
            let cross = simd_cross(b - a, c - a)
            guard [cross.x, cross.y, cross.z].allSatisfy(\.isFinite), simd_length_squared(cross) > 0 else { throw Failure.invalidGeometry }
        }
        let data = positions.withUnsafeBufferPointer { Data(buffer: $0) }
        let source = SCNGeometrySource(data: data, semantic: .vertex, vectorCount: positions.count / 3,
            usesFloatComponents: true, componentsPerVector: 3, bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0, dataStride: 3 * MemoryLayout<Float>.size)
        var groups: [Group: [Int32]] = [:]
        var featureKinds: [UUID: Bool] = [:]
        for triangle in floorSupport.indices {
            let id = triangleFeatureIDs[triangle], floor = floorSupport[triangle]
            if let previous = featureKinds[id], previous != floor { throw Failure.invalidGeometry }
            featureKinds[id] = floor
            groups[Group(id: id, floor: floor), default: []].append(contentsOf: triangles[(triangle * 3)..<(triangle * 3 + 3)])
        }
        for group in groups.keys.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            let indices = groups[group]!
            let indexData = indices.withUnsafeBufferPointer { Data(buffer: $0) }
            let element = SCNGeometryElement(data: indexData, primitiveType: .triangles,
                primitiveCount: indices.count / 3, bytesPerIndex: MemoryLayout<Int32>.size)
            let geometry = SCNGeometry(sources: [source], elements: [element])
            let shape = SCNPhysicsShape(geometry: geometry, options: [
                .type: SCNPhysicsShape.ShapeType.concavePolyhedron, .collisionMargin: 0.0])
            add(shape: shape, id: group.id, kind: group.floor ? .floorSurface : .obstacleSurface,
                transform: matrix_identity_float4x4)
        }
        for box in furnitureBoxes {
            guard featureKinds[box.featureID] == false else { throw Failure.invalidFurnitureBox }
            let transform = try Self.rigidTransform(box.transform)
            guard box.dimensions.count == 3,
                  box.dimensions.allSatisfy({ $0.isFinite && $0 > 0 && $0 <= 100 }) else { throw Failure.invalidFurnitureBox }
            let geometry = SCNBox(width: CGFloat(box.dimensions[0]), height: CGFloat(box.dimensions[1]),
                                  length: CGFloat(box.dimensions[2]), chamferRadius: 0)
            // SCNBox has an idealized solid physics shape; no convex-hull repair.
            let shape = SCNPhysicsShape(geometry: geometry, options: [.collisionMargin: 0.0])
            add(shape: shape, id: box.featureID, kind: .furnitureBound, transform: transform)
        }
        scene.physicsWorld.updateCollisionPairs()
        if checkBackend { try Self.verifyBackend() }
    }

    private func add(shape: SCNPhysicsShape, id: UUID, kind: Kind, transform: simd_float4x4) {
        let node = SCNNode()
        node.simdTransform = transform
        let body = SCNPhysicsBody(type: .static, shape: shape)
        body.categoryBitMask = sourceMask; body.collisionBitMask = probeMask; body.contactTestBitMask = probeMask
        node.physicsBody = body
        scene.rootNode.addChildNode(node)
        identities[ObjectIdentifier(node)] = Identity(id: id, kind: kind)
        body.resetTransform()
    }

    /// Feet/base-centre positions in the original saved world. Continuous sweep of
    /// a full cylinder, plus explicit initial AND terminal overlap queries.
    func sweep(from: SIMD3<Float>, to: SIMD3<Float>, radius: Float, height: Float) throws -> SweepResult {
        guard Self.valid(from), Self.valid(to), radius.isFinite, height.isFinite,
              (0.1...2).contains(radius), (0.5...3).contains(height) else { throw Failure.invalidQuery }
        let geometry = SCNCylinder(radius: CGFloat(radius), height: CGFloat(height))
        let shape = SCNPhysicsShape(geometry: geometry, options: [.collisionMargin: 0.0])
        let initial = try overlap(at: from, height: height, shape: shape)
        let start = Self.centreTransform(from, height: height), end = Self.centreTransform(to, height: height)
        scene.physicsWorld.updateCollisionPairs()
        let raw = scene.physicsWorld.convexSweepTest(with: shape, from: SCNMatrix4(start), to: SCNMatrix4(end),
            options: [.collisionBitMask: sourceMask, .searchMode: SCNPhysicsWorld.TestSearchMode.all,
                      .backfaceCulling: false])
        let swept = try contacts(raw)
        let terminal = try overlap(at: to, height: height, shape: shape)
        return SweepResult(initial: initial, swept: swept, terminal: terminal)
    }

    private func overlap(at foot: SIMD3<Float>, height: Float, shape: SCNPhysicsShape) throws -> Contacts {
        let node = SCNNode()
        node.simdTransform = Self.centreTransform(foot, height: height)
        let body = SCNPhysicsBody(type: .kinematic, shape: shape)
        body.categoryBitMask = probeMask; body.collisionBitMask = sourceMask; body.contactTestBitMask = sourceMask
        node.physicsBody = body
        scene.rootNode.addChildNode(node)
        body.resetTransform()
        scene.physicsWorld.updateCollisionPairs()
        defer { node.removeFromParentNode(); scene.physicsWorld.updateCollisionPairs() }
        return try contacts(scene.physicsWorld.contactTest(with: body, options: [.collisionBitMask: sourceMask]))
    }

    private func contacts(_ raw: [SCNPhysicsContact]) throws -> Contacts {
        var result = Contacts()
        for contact in raw {
            var recognized = false
            for node in [contact.nodeA, contact.nodeB] {
                guard let identity = identities[ObjectIdentifier(node)] else { continue }
                recognized = true
                switch identity.kind {
                case .obstacleSurface: result.obstacleSurfaceIDs.insert(identity.id)
                case .floorSurface: result.floorSurfaceIDs.insert(identity.id)
                case .furnitureBound: result.furnitureBoundIDs.insert(identity.id)
                }
            }
            guard recognized else { throw Failure.backendUnavailable("unassociated physics contact") }
        }
        return result
    }

    private static func valid(_ value: SIMD3<Float>) -> Bool {
        [value.x, value.y, value.z].allSatisfy { $0.isFinite && abs($0) <= 10_000 }
    }
    private static func centreTransform(_ foot: SIMD3<Float>, height: Float) -> simd_float4x4 {
        var transform = matrix_identity_float4x4
        transform.columns.3 = SIMD4(foot.x, foot.y + height / 2, foot.z, 1)
        return transform
    }
    private static func rigidTransform(_ values: [Double]) throws -> simd_float4x4 {
        guard values.count == 16, values.allSatisfy({ $0.isFinite && abs($0) <= 10_000 }),
              values[3] == 0, values[7] == 0, values[11] == 0, values[15] == 1 else { throw Failure.invalidFurnitureBox }
        var c: [SIMD4<Float>] = []
        c.reserveCapacity(4)
        for column in 0..<4 {
            let base: Int = column * 4
            let x: Float = Float(values[base])
            let y: Float = Float(values[base + 1])
            let z: Float = Float(values[base + 2])
            let w: Float = Float(values[base + 3])
            let vector = SIMD4<Float>(x, y, z, w)
            c.append(vector)
        }
        let m = simd_float4x4(columns: (c[0], c[1], c[2], c[3]))
        let r0 = SIMD3<Float>(c[0].x, c[0].y, c[0].z)
        let r1 = SIMD3<Float>(c[1].x, c[1].y, c[1].z)
        let r2 = SIMD3<Float>(c[2].x, c[2].y, c[2].z)
        let rotation = simd_float3x3(columns: (r0, r1, r2))
        // Match the existing mesh package's Float32 rigid-transform tolerance;
        // this is numerical validation, not a measured spatial error allowance.
        for a in 0..<3 { for b in 0..<3 {
            guard abs(simd_dot(rotation[a], rotation[b]) - (a == b ? 1 : 0)) <= 1e-5 else { throw Failure.invalidFurnitureBox }
        } }
        guard abs(simd_determinant(rotation) - 1) <= 1e-5 else { throw Failure.invalidFurnitureBox }
        return m
    }

    /// Mandatory on every external oracle creation. A headless/uninitialized
    /// physics engine, failed thin-plane sweep or failed contained-solid query
    /// throws; an empty hit array must never silently certify this backend.
    private static func verifyBackend() throws {
        let wall = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let solid = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let overhead = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        let floor = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!
        let vertices: [Double] = [0,0,-1, 0,3,-1, 0,3,1, 0,0,1,
                                 4,0,-1, 4,3,-1, 4,3,1, 4,0,1,
                                 9,1.4,-1, 11,1.4,-1, 11,1.4,1, 9,1.4,1,
                                 19,0,-1, 21,0,-1, 21,0,1, 19,0,1]
        let triangles: [Int32] = [0,1,2, 0,2,3, 4,5,6, 4,6,7, 8,9,10, 8,10,11, 12,13,14, 12,14,15]
        let oracle = try SavedRoomRouteCollisionOracle(vertices: vertices, triangles: triangles,
            floorSupport: [false,false,false,false,false,false,true,true],
            triangleFeatureIDs: [wall,wall,solid,solid,overhead,overhead,floor,floor],
            furnitureBoxes: [.init(featureID: solid, dimensions: [2,3,2],
                transform: [1,0,0,0, 0,1,0,0, 0,0,1,0, 5,1.5,0,1])], checkBackend: false)
        let cross = try oracle.sweep(from: SIMD3(-1,0,0), to: SIMD3(1,0,0), radius: 0.2, height: 1.6)
        let reverse = try oracle.sweep(from: SIMD3(1,0,0), to: SIMD3(-1,0,0), radius: 0.2, height: 1.6)
        guard cross.swept.obstacleSurfaceIDs.contains(wall), reverse.swept.obstacleSurfaceIDs.contains(wall)
        else { throw Failure.backendUnavailable("bidirectional thin-plane continuous sweep") }
        let contained = try oracle.sweep(from: SIMD3(5,0.5,0), to: SIMD3(5,0.5,0), radius: 0.2, height: 1)
        guard contained.initial.furnitureBoundIDs.contains(solid), contained.initial.obstacleSurfaceIDs.isEmpty
        else { throw Failure.backendUnavailable("contained-cylinder initial overlap distinct from shell") }
        let high = try oracle.sweep(from: SIMD3(8,0,0), to: SIMD3(12,0,0), radius: 0.2, height: 1.6)
        let reverseHigh = try oracle.sweep(from: SIMD3(12,0,0), to: SIMD3(8,0,0), radius: 0.2, height: 1.6)
        let low = try oracle.sweep(from: SIMD3(8,0,0), to: SIMD3(12,0,0), radius: 0.2, height: 1)
        guard high.all.obstacleSurfaceIDs.contains(overhead), reverseHigh.all.obstacleSurfaceIDs.contains(overhead),
              !low.all.hasObstacleContact else { throw Failure.backendUnavailable("bidirectional height-sensitive overhead sweep") }
        let clear = try oracle.sweep(from: SIMD3(-2,0,4), to: SIMD3(2,0,4), radius: 0.2, height: 1.6)
        guard !clear.all.hasObstacleContact else { throw Failure.backendUnavailable("negative sweep control") }
        let ground = try oracle.sweep(from: SIMD3(20,-0.1,0), to: SIMD3(20,-0.1,0), radius: 0.2, height: 1.6)
        guard ground.all.floorSurfaceIDs.contains(floor), !ground.all.hasObstacleContact else { throw Failure.backendUnavailable("separate floor contact") }
    }
}
