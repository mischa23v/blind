#if (DEBUG && BLIND_MESH_CANDIDATE_DIAGNOSTICS) || BLIND_COLLISION_ORACLE_TESTS
import Foundation
import SceneKit
import simd

/// Shared independent Apple diagnostic kernel. App compilation is DEBUG + explicit
/// diagnostic flag only; tests compile this same source with their dedicated flag.
/// Not a planner, sensor, support verifier or physical-output owner.
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
/// https://developer.apple.com/documentation/scenekit/scnrenderer/update(attime:)
/// https://developer.apple.com/documentation/scenekit/scnphysicsbody/collisionbitmask
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

    /// Opt-in authored-fixture diagnostics only; never private scene capture.
    struct ContactDetail: Equatable, Sendable {
        let featureID: UUID
        let kind: String
        let point, normal: [Double]
        let penetrationDistance: Double
    }

    struct Contacts: Equatable, Sendable {
        var details: [ContactDetail] = []
        var obstacleSurfaceIDs = Set<UUID>()
        var floorSurfaceIDs = Set<UUID>()
        var furnitureBoundIDs = Set<UUID>()
        var hasObstacleContact: Bool { !obstacleSurfaceIDs.isEmpty || !furnitureBoundIDs.isEmpty }
        mutating func formUnion(_ other: Contacts) {
            obstacleSurfaceIDs.formUnion(other.obstacleSurfaceIDs)
            floorSurfaceIDs.formUnion(other.floorSurfaceIDs)
            furnitureBoundIDs.formUnion(other.furnitureBoundIDs)
            details.append(contentsOf: other.details)
        }
    }

    struct SweepResult: Sendable {
        let initial: Contacts
        let swept: Contacts
        let terminal: Contacts
        let detailShape: [String: Double]?
        /// Whole-footprint support is deliberately NOT inferred from floor contact
        /// or from absence of a non-floor collision. Holes remain unverified here.
        let fullFootprintSupportVerified = false
        let physicalAuthority = false
        var all: Contacts { var value = initial; value.formUnion(swept); value.formUnion(terminal); return value }
    }

    private enum Kind: Equatable { case obstacleSurface, floorSurface, furnitureBound }
    private struct Identity { let id: UUID; let kind: Kind }
    private struct Group: Hashable { let id: UUID; let floor: Bool }
    private let scene = SCNScene()
    // Retain the renderer for the entire query world's lifetime. No view, camera,
    // display link, render target, AR session or asynchronous render loop exists.
    private var renderer: SCNRenderer?
    private var simulationTick = 0
    private static let physicsTimeStep: TimeInterval = 1.0 / 60.0
    private let configuration: BackendConfiguration
    private let queryMode: QueryMode
    private var identities: [ObjectIdentifier: Identity] = [:]
    private let sourceMask = 1
    private let probeMask = 2
    private var floorMask: Int { queryMode == .separated ? 4 : sourceMask }
    private var allSourceMask: Int { sourceMask | floorMask }
    private var queryMasks: [Int] { queryMode == .separated ? [sourceMask, floorMask] : [sourceMask] }

    /// Array limits match the existing mesh package; no triangles are truncated.
    /// Geometry stays uninflated. Caller-supplied query radius/height already carry
    /// the declared body/margin variant. Physics collision margin is exactly zero.
    convenience init(vertices: [Double], triangles: [Int32], floorSupport: [Bool],
                     triangleFeatureIDs: [UUID], furnitureBoxes: [FurnitureBox] = []) throws {
        try self.init(vertices: vertices, triangles: triangles, floorSupport: floorSupport,
                      triangleFeatureIDs: triangleFeatureIDs, furnitureBoxes: furnitureBoxes,
                      configuration: .candidate, queryMode: .separated, checkBackend: true)
    }

    private init(vertices: [Double], triangles: [Int32], floorSupport: [Bool],
                 triangleFeatureIDs: [UUID], furnitureBoxes: [FurnitureBox],
                 configuration: BackendConfiguration, queryMode: QueryMode, checkBackend: Bool) throws {
        self.configuration = configuration
        self.queryMode = queryMode
        guard !vertices.isEmpty, vertices.count % 3 == 0, vertices.count <= 600_000,
              !triangles.isEmpty, triangles.count % 3 == 0, triangles.count <= 300_000,
              floorSupport.count == triangles.count / 3, triangleFeatureIDs.count == floorSupport.count,
              vertices.allSatisfy({ $0.isFinite && abs($0) <= 10_000 && Float($0).isFinite }),
              triangles.allSatisfy({ $0 >= 0 && Int($0) < vertices.count / 3 }),
              Set(triangleFeatureIDs).count <= 512, furnitureBoxes.count <= 512,
              Set(furnitureBoxes.map(\.featureID)).count == furnitureBoxes.count else { throw Failure.invalidGeometry }
        scene.physicsWorld.gravity = SCNVector3Zero
        scene.isPaused = false
        // All bodies are static/kinematic: enabling physics cannot integrate a
        // dynamic actor or change supplied geometry. Zero speed previously left
        // startup ambiguous. Every diagnostic cell uses this same unpaused world.
        scene.physicsWorld.speed = 1
        scene.physicsWorld.timeStep = Self.physicsTimeStep
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
        if configuration.usesRenderer {
            let retained = SCNRenderer(device: nil, options: nil)
            retained.scene = scene
            retained.isPlaying = true
            renderer = retained
            retained.update(atTime: 0)
        }
        synchronizePhysics()
        if checkBackend { try Self.verifyBackend(configuration: configuration, queryMode: queryMode) }
    }

    private func add(shape: SCNPhysicsShape, id: UUID, kind: Kind, transform: simd_float4x4) {
        let node = SCNNode()
        node.simdTransform = transform
        let body = SCNPhysicsBody(type: .static, shape: shape)
        body.categoryBitMask = kind == .floorSurface ? floorMask : sourceMask
        // Leave SceneKit's documented all-category collision mask unchanged in
        // the candidate. The query's source-category filter remains explicit.
        // Probe-only masking is retained solely as a diagnostic comparison cell.
        if configuration.restrictsSourceMask { body.collisionBitMask = probeMask }
        body.contactTestBitMask = probeMask
        node.physicsBody = body
        scene.rootNode.addChildNode(node)
        identities[ObjectIdentifier(node)] = Identity(id: id, kind: kind)
        body.resetTransform()
    }

    private func synchronizePhysics() {
        // Synchronous, fixed clock, no sleeps or retry-until-contact loop. Apple
        // documents update(atTime:) as updating scene state without drawing.
        // This is a startup candidate, NOT proof the backend is ready: all
        // positive and negative controls below must still pass on this runtime.
        SCNTransaction.flush()
        if let renderer {
            simulationTick += 1
            renderer.update(atTime: TimeInterval(simulationTick) * Self.physicsTimeStep)
        }
        scene.physicsWorld.updateCollisionPairs()
    }

    /// Feet/base-centre positions in the original saved world. Continuous sweep of
    /// a full cylinder, plus explicit initial AND terminal overlap queries.
    func sweep(from: SIMD3<Float>, to: SIMD3<Float>, radius: Float, height: Float, recordDetails: Bool = false) throws -> SweepResult {
        guard Self.valid(from), Self.valid(to), radius.isFinite, height.isFinite,
              (0.1...2).contains(radius), (0.5...3).contains(height) else { throw Failure.invalidQuery }
        let geometry = SCNCylinder(radius: CGFloat(radius), height: CGFloat(height))
        let shape = SCNPhysicsShape(geometry: geometry, options: [.collisionMargin: 0.0])
        let initial = try overlap(at: from, height: height, shape: shape, recordDetails: recordDetails)
        let start = Self.centreTransform(from, height: height), end = Self.centreTransform(to, height: height)
        synchronizePhysics()
        // Query both categories with the identical cylinder/transforms, then
        // union every contact. No floor triangles or obstacle bounds are omitted,
        // and a floor hit never becomes proof of whole-footprint support.
        var swept = Contacts()
        for mask in queryMasks {
            let raw = scene.physicsWorld.convexSweepTest(with: shape, from: SCNMatrix4(start), to: SCNMatrix4(end),
                options: [.collisionBitMask: mask, .searchMode: SCNPhysicsWorld.TestSearchMode.all,
                          .backfaceCulling: false])
            swept.formUnion(try contacts(raw, recordDetails: recordDetails))
        }
        let terminal = try overlap(at: to, height: height, shape: shape, recordDetails: recordDetails)
        return SweepResult(initial: initial, swept: swept, terminal: terminal,
            detailShape: recordDetails ? ["radius": Double(geometry.radius), "height": Double(geometry.height),
                "radialSegmentCount": Double(geometry.radialSegmentCount),
                "heightSegmentCount": Double(geometry.heightSegmentCount), "collisionMargin": 0] : nil)
    }

    private func overlap(at foot: SIMD3<Float>, height: Float, shape: SCNPhysicsShape, recordDetails: Bool = false) throws -> Contacts {
        let node = SCNNode()
        node.simdTransform = Self.centreTransform(foot, height: height)
        let body = SCNPhysicsBody(type: .kinematic, shape: shape)
        body.categoryBitMask = probeMask; body.collisionBitMask = allSourceMask; body.contactTestBitMask = allSourceMask
        node.physicsBody = body
        scene.rootNode.addChildNode(node)
        body.resetTransform()
        synchronizePhysics()
        defer { node.removeFromParentNode(); synchronizePhysics() }
        var result = Contacts()
        for mask in queryMasks {
            result.formUnion(try contacts(scene.physicsWorld.contactTest(with: body, options: [.collisionBitMask: mask]), recordDetails: recordDetails))
        }
        return result
    }

    private func contacts(_ raw: [SCNPhysicsContact], recordDetails: Bool = false) throws -> Contacts {
        // Bound each native category response; overflow fails, never truncates.
        if recordDetails && raw.count > 32 { throw Failure.backendUnavailable("contact detail count exceeded") }
        var result = Contacts()
        for contact in raw {
            var recognized = false
            for node in [contact.nodeA, contact.nodeB] {
                guard let identity = identities[ObjectIdentifier(node)] else { continue }
                recognized = true
                if recordDetails {
                    let p = contact.contactPoint, n = contact.contactNormal
                    let point = [Double(p.x), Double(p.y), Double(p.z)]
                    let normal = [Double(n.x), Double(n.y), Double(n.z)]
                    let penetration = Double(contact.penetrationDistance)
                    guard (point + normal + [penetration]).allSatisfy(\.isFinite) else {
                        throw Failure.backendUnavailable("nonfinite contact detail")
                    }
                    let kind: String
                    switch identity.kind {
                    case .obstacleSurface: kind = "obstacle-surface"
                    case .floorSurface: kind = "floor-surface"
                    case .furnitureBound: kind = "furniture-bound"
                    }
                    result.details.append(.init(featureID: identity.id, kind: kind,
                        point: point, normal: normal, penetrationDistance: penetration))
                }
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

    private enum QueryMode: String { case combined, separated }

    private enum BackendConfiguration: String, CaseIterable {
        case restrictedNoRenderer = "restricted-no-renderer"
        case defaultNoRenderer = "default-no-renderer"
        case restrictedOffscreenRenderer = "restricted-offscreen-renderer"
        case defaultOffscreenRenderer = "default-offscreen-renderer"
        static let candidate = BackendConfiguration.defaultOffscreenRenderer
        var restrictsSourceMask: Bool {
            self == .restrictedNoRenderer || self == .restrictedOffscreenRenderer
        }
        var usesRenderer: Bool {
            self == .restrictedOffscreenRenderer || self == .defaultOffscreenRenderer
        }
    }

    enum ControlName: String, CaseIterable, Encodable, Hashable {
        case thinWallForward, thinWallReverse, wallInitialOverlap, wallTerminalOverlap
        case containedSolid, overheadTallForward, overheadTallReverse, overheadShort, clear, floor
    }

    /// Only the fixed authored controls below can create this witness. No saved
    /// room, device pose, private geometry, arbitrary errors or camera input is
    /// accepted by the diagnostic entry point. Keep the collector allowlist in
    /// sync if this versioned schema ever changes.
    struct ContactWitness: Encodable {
        let obstacleSurfaceIDs, floorSurfaceIDs, furnitureBoundIDs: [String]
        fileprivate init(_ contacts: Contacts) {
            obstacleSurfaceIDs = contacts.obstacleSurfaceIDs.map(\.uuidString).sorted()
            floorSurfaceIDs = contacts.floorSurfaceIDs.map(\.uuidString).sorted()
            furnitureBoundIDs = contacts.furnitureBoundIDs.map(\.uuidString).sorted()
        }
    }
    struct QueryWitness: Encodable {
        let name: ControlName
        let passed: Bool
        let errorCode: String
        let initial, swept, terminal: ContactWitness
        fileprivate static func failed(_ name: ControlName, error: Error) -> QueryWitness {
            let code: String
            switch error {
            case Failure.invalidGeometry: code = "invalidGeometry"
            case Failure.invalidQuery: code = "invalidQuery"
            case Failure.invalidFurnitureBox: code = "invalidFurnitureBox"
            case Failure.backendUnavailable("unassociated physics contact"): code = "unassociatedContact"
            default: code = "unexpectedError"
            }
            let empty = ContactWitness(Contacts())
            return QueryWitness(name: name, passed: false, errorCode: code,
                                initial: empty, swept: empty, terminal: empty)
        }
    }
    struct BackendCellWitness: Encodable {
        let configurationID, sourceCollisionMask, rendererMode: String
        let physicsSpeed = 1
        let timeStepSeconds = 1.0 / 60.0
        let gravity = [0, 0, 0]
        let sourceCategoryMask = 1, probeCategoryMask = 2, queryCollisionMask = 1
        let backendReady: Bool
        let failedControls: [ControlName]
        let queries: [QueryWitness]
    }
    struct BackendMatrixWitness: Encodable {
        let schemaVersion = 1
        let evidenceKind = "synthetic-collision-backend-matrix"
        let physicalAuthority = false
        let fullFootprintSupportVerified = false
        let cells: [BackendCellWitness]
    }

    /// Four cells, ten queries per cell, once each; not a fallback search or a
    /// retry policy. All cells are unpaused. Thus this isolates mask/renderer
    /// effects at speed 1, not the independent causal effect of old speed 0.
    static func backendDiagnosticMatrix() -> BackendMatrixWitness {
        BackendMatrixWitness(cells: BackendConfiguration.allCases.map { diagnoseBackend(configuration: $0) })
    }

    /// Mandatory on every external oracle creation. A failed control always
    /// throws, including a positive control whose raw hit arrays are empty.
    /// No alternate matrix cell can substitute for the selected candidate.
    private static func verifyBackend(configuration: BackendConfiguration, queryMode: QueryMode) throws {
        let original = backendQueries(configuration: configuration, queryMode: queryMode)
        let mixed = mixedSceneQueries(layout: .wallAndFloor, queryMode: queryMode)
        let failedNames = Set((original + mixed).filter { !$0.passed }.map(\.name))
        let failures = ControlName.allCases.filter { failedNames.contains($0) }
        guard failures.isEmpty else {
            throw Failure.backendUnavailable("backend controls failed: " +
                failures.map(\.rawValue).joined(separator: ","))
        }
    }

    private static let controlWall = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private static let controlSolid = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    private static let controlOverhead = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    private static let controlFloor = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!

    private static func diagnoseBackend(configuration: BackendConfiguration) -> BackendCellWitness {
        // Version-one bootstrap witness deliberately retains the original
        // combined query mode; the separate mixed-scene witness diagnoses the
        // candidate query split. Do not rewrite historical factorial meaning.
        let queries = backendQueries(configuration: configuration, queryMode: .combined)
        let failures = queries.filter { !$0.passed }.map(\.name)
        return BackendCellWitness(configurationID: configuration.rawValue,
            sourceCollisionMask: configuration.restrictsSourceMask ? "probe-only" : "platform-default-all",
            rendererMode: configuration.usesRenderer ? "retained-offscreen-update" : "none",
            backendReady: failures.isEmpty, failedControls: failures, queries: queries)
    }

    private static func backendQueries(configuration: BackendConfiguration, queryMode: QueryMode) -> [QueryWitness] {
        let queries: [QueryWitness]
        do {
            let wall = controlWall, solid = controlSolid, overhead = controlOverhead, floor = controlFloor
            let vertices: [Double] = [0,0,-1, 0,3,-1, 0,3,1, 0,0,1,
                                     4,0,-1, 4,3,-1, 4,3,1, 4,0,1,
                                     9,1.4,-1, 11,1.4,-1, 11,1.4,1, 9,1.4,1,
                                     19,0,-1, 21,0,-1, 21,0,1, 19,0,1]
            let triangles: [Int32] = [0,1,2, 0,2,3, 4,5,6, 4,6,7, 8,9,10, 8,10,11, 12,13,14, 12,14,15]
            let oracle = try SavedRoomRouteCollisionOracle(vertices: vertices, triangles: triangles,
                floorSupport: [false,false,false,false,false,false,true,true],
                triangleFeatureIDs: [wall,wall,solid,solid,overhead,overhead,floor,floor],
                furnitureBoxes: [.init(featureID: solid, dimensions: [2,3,2],
                    transform: [1,0,0,0, 0,1,0,0, 0,0,1,0, 5,1.5,0,1])],
                configuration: configuration, queryMode: queryMode, checkBackend: false)
            // Do not short-circuit on a failed wall or thrown query: the witness
            // must still record containment, height, clear and floor controls.
            queries = ControlName.allCases.map { name in
                do { return try runControl(name, oracle: oracle) }
                catch { return QueryWitness.failed(name, error: error) }
            }
        } catch {
            queries = ControlName.allCases.map { QueryWitness.failed($0, error: error) }
        }
        return queries
    }

    private enum MixedLayout: String { case wallOnly = "wall-only", wallAndFloor = "wall-and-floor" }
    static let mixedControlNames: [ControlName] = [.thinWallForward, .thinWallReverse,
        .wallInitialOverlap, .wallTerminalOverlap, .clear, .floor]
    private static let mixedWall = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
    private static let mixedFloor = UUID(uuidString: "10000000-0000-0000-0000-000000000002")!

    struct MixedCellWitness: Encodable {
        let configurationID, layout, queryMode: String
        let rendererMode = "retained-offscreen-update"
        let physicsSpeed = 1
        let timeStepSeconds = 1.0 / 60.0
        let gravity = [0, 0, 0]
        let obstacleCategoryMask = 1, probeCategoryMask = 2
        let floorCategoryMask: Int
        let queryCollisionMasks: [Int]
        let backendReady: Bool
        let failedControls: [ControlName]
        let queries: [QueryWitness]
    }
    struct MixedSceneWitness: Encodable {
        let schemaVersion = 1
        let evidenceKind = "synthetic-collision-mixed-scene"
        let physicalAuthority = false
        let fullFootprintSupportVerified = false
        let cells: [MixedCellWitness]
    }

    /// Compare the unchanged failing wall+floor geometry with a wall-only
    /// diagnostic control; then compare combined versus separated category
    /// queries. Only the mixed layout can validate the candidate, never removal
    /// of the floor, lifting/shrinking the cylinder, or a passing negative alone.
    static func mixedSceneDiagnosticMatrix() -> MixedSceneWitness {
        let configurations: [(MixedLayout, QueryMode)] = [(.wallOnly, .combined), (.wallAndFloor, .combined),
            (.wallOnly, .separated), (.wallAndFloor, .separated)]
        return MixedSceneWitness(cells: configurations.map { layout, mode in
            let queries = mixedSceneQueries(layout: layout, queryMode: mode)
            let failures = queries.filter { !$0.passed }.map(\.name)
            return MixedCellWitness(configurationID: layout.rawValue + "-" + mode.rawValue,
                layout: layout.rawValue, queryMode: mode.rawValue,
                floorCategoryMask: mode == .separated ? 4 : 1,
                queryCollisionMasks: mode == .separated ? [1, 4] : [1],
                backendReady: failures.isEmpty, failedControls: failures, queries: queries)
        })
    }

    private static func mixedSceneQueries(layout: MixedLayout, queryMode: QueryMode) -> [QueryWitness] {
        do {
            // Identical vertices, triangle ordering and IDs to wallAndFloor() in
            // the original failed native test. Wall-only is a diagnostic control,
            // NOT a geometry-reduced candidate or an alternative readiness gate.
            let includeFloor = layout == .wallAndFloor
            let oracle = try SavedRoomRouteCollisionOracle(
                vertices: [0,0,-2, 0,3,-2, 0,3,2, 0,0,2,
                           -3,0,-3, 3,0,-3, 3,0,3, -3,0,3],
                triangles: includeFloor ? [0,1,2, 0,2,3, 4,5,6, 4,6,7] : [0,1,2, 0,2,3],
                floorSupport: includeFloor ? [false,false,true,true] : [false,false],
                triangleFeatureIDs: includeFloor ? [mixedWall,mixedWall,mixedFloor,mixedFloor] : [mixedWall,mixedWall],
                furnitureBoxes: [], configuration: .candidate, queryMode: queryMode, checkBackend: false)
            return mixedControlNames.map { name in
                do { return try runMixedControl(name, oracle: oracle, layout: layout) }
                catch { return QueryWitness.failed(name, error: error) }
            }
        } catch { return mixedControlNames.map { QueryWitness.failed($0, error: error) } }
    }

    private static func runMixedControl(_ name: ControlName, oracle: SavedRoomRouteCollisionOracle,
                                        layout: MixedLayout) throws -> QueryWitness {
        let from: SIMD3<Float>, to: SIMD3<Float>
        switch name {
        case .thinWallForward: from = SIMD3(-1,0,0); to = SIMD3(1,0,0)
        case .thinWallReverse: from = SIMD3(1,0,0); to = SIMD3(-1,0,0)
        case .wallInitialOverlap: from = SIMD3(0,0,0); to = SIMD3(1,0,0)
        case .wallTerminalOverlap: from = SIMD3(-1,0,0); to = SIMD3(0,0,0)
        case .clear: from = SIMD3(-1,0,3); to = SIMD3(1,0,3)
        case .floor: from = SIMD3(2,-0.1,0); to = from
        default: throw Failure.invalidQuery
        }
        let result = try oracle.sweep(from: from, to: to, radius: 0.2, height: 1.6)
        let all = result.all
        let validFloor = layout == .wallOnly ? all.floorSurfaceIDs.isEmpty : all.floorSurfaceIDs.isSubset(of: [mixedFloor])
        let expected: Bool
        switch name {
        case .thinWallForward, .thinWallReverse:
            expected = result.initial.obstacleSurfaceIDs.isEmpty && result.terminal.obstacleSurfaceIDs.isEmpty &&
                result.swept.obstacleSurfaceIDs == [mixedWall]
        case .wallInitialOverlap:
            expected = result.initial.obstacleSurfaceIDs == [mixedWall] && result.terminal.obstacleSurfaceIDs.isEmpty &&
                all.obstacleSurfaceIDs == [mixedWall]
        case .wallTerminalOverlap:
            expected = result.terminal.obstacleSurfaceIDs == [mixedWall] && result.initial.obstacleSurfaceIDs.isEmpty &&
                all.obstacleSurfaceIDs == [mixedWall]
        case .clear: expected = !all.hasObstacleContact
        case .floor:
            expected = layout == .wallOnly ? all == Contacts() :
                result.initial.floorSurfaceIDs == [mixedFloor] && result.terminal.floorSurfaceIDs == [mixedFloor] &&
                all.floorSurfaceIDs == [mixedFloor] && !all.hasObstacleContact
        default: throw Failure.invalidQuery
        }
        return QueryWitness(name: name, passed: expected && validFloor && all.furnitureBoundIDs.isEmpty, errorCode: "none",
            initial: ContactWitness(result.initial), swept: ContactWitness(result.swept), terminal: ContactWitness(result.terminal))
    }

    private static func runControl(_ name: ControlName, oracle: SavedRoomRouteCollisionOracle) throws -> QueryWitness {
        let from: SIMD3<Float>, to: SIMD3<Float>, height: Float
        switch name {
        case .thinWallForward: from = SIMD3(-1,0,0); to = SIMD3(1,0,0); height = 1.6
        case .thinWallReverse: from = SIMD3(1,0,0); to = SIMD3(-1,0,0); height = 1.6
        case .wallInitialOverlap: from = SIMD3(0,0,0); to = SIMD3(1,0,0); height = 1.6
        case .wallTerminalOverlap: from = SIMD3(-1,0,0); to = SIMD3(0,0,0); height = 1.6
        case .containedSolid: from = SIMD3(5,0.5,0); to = from; height = 1
        case .overheadTallForward: from = SIMD3(8,0,0); to = SIMD3(12,0,0); height = 1.6
        case .overheadTallReverse: from = SIMD3(12,0,0); to = SIMD3(8,0,0); height = 1.6
        case .overheadShort: from = SIMD3(8,0,0); to = SIMD3(12,0,0); height = 1
        case .clear: from = SIMD3(-2,0,4); to = SIMD3(2,0,4); height = 1.6
        case .floor: from = SIMD3(20,-0.1,0); to = from; height = 1.6
        }
        let result = try oracle.sweep(from: from, to: to, radius: 0.2, height: height)
        let empty = Contacts()
        let all = result.all
        let passed: Bool
        switch name {
        case .thinWallForward, .thinWallReverse:
            passed = result.initial == empty && result.terminal == empty &&
                result.swept.obstacleSurfaceIDs == [controlWall] &&
                all.floorSurfaceIDs.isEmpty && all.furnitureBoundIDs.isEmpty
        case .wallInitialOverlap:
            passed = result.initial.obstacleSurfaceIDs == [controlWall] && result.terminal == empty &&
                all.obstacleSurfaceIDs == [controlWall] && all.floorSurfaceIDs.isEmpty && all.furnitureBoundIDs.isEmpty
        case .wallTerminalOverlap:
            passed = result.terminal.obstacleSurfaceIDs == [controlWall] && result.initial == empty &&
                all.obstacleSurfaceIDs == [controlWall] && all.floorSurfaceIDs.isEmpty && all.furnitureBoundIDs.isEmpty
        case .containedSolid:
            passed = result.initial.furnitureBoundIDs == [controlSolid] &&
                result.terminal.furnitureBoundIDs == [controlSolid] && all.furnitureBoundIDs == [controlSolid] &&
                all.obstacleSurfaceIDs.isEmpty && all.floorSurfaceIDs.isEmpty
        case .overheadTallForward, .overheadTallReverse:
            passed = result.initial == empty && result.terminal == empty &&
                result.swept.obstacleSurfaceIDs == [controlOverhead] &&
                all.floorSurfaceIDs.isEmpty && all.furnitureBoundIDs.isEmpty
        case .overheadShort, .clear:
            passed = all == empty
        case .floor:
            passed = result.initial.floorSurfaceIDs == [controlFloor] &&
                result.terminal.floorSurfaceIDs == [controlFloor] && all.floorSurfaceIDs == [controlFloor] &&
                !all.hasObstacleContact
        }
        return QueryWitness(name: name, passed: passed, errorCode: "none",
            initial: ContactWitness(result.initial), swept: ContactWitness(result.swept), terminal: ContactWitness(result.terminal))
    }
}

#endif
