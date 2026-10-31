import Foundation
import CryptoKit
import RoomPlan
import ModelIO
import simd
import BlindCore
import BlindRoomMesh

/// Owned, historical Apple-export geometry. No live ARSession, registration,
/// floor-support lease, sensor freshness, speech or physical-output capability.
struct SavedRoomRouteMeshSnapshot: Sendable {
    enum Kind: String, Sendable { case floor, wall, door, window, opening, furniture }
    struct Feature: Sendable {
        let id: UUID
        let kind: Kind
        let parentID: UUID?
        let category: String
        let transform: [Double] // original column-major feature-to-saved-world
        let dimensions: [Double]
        let polygonCorners: [[Double]] // original local plane, not generated
        let capturedDoorOpen: Bool?
    }
    let sourceSHA256: String
    let capturedRoomID: UUID
    let features: [Feature]
    // The raw Apple export remains available unchanged for audit/rendering.
    // Routing uses its non-floor triangles plus the original semantic floor
    // polygon tessellated by pinned Mapbox earcut, never the exported slab's added rim.
    let rawExportVertices: [Double]
    let rawExportTriangles: [Int32]
    let rawExportTriangleFeatureIDs: [UUID]
    struct IgnoredDegenerateFace: Encodable, Sendable {
        let rawTriangleIndex: Int
        let featureID: UUID
        let indices: [Int32]
        let localVertices, worldVertices: [[Double]]
    }
    // Triangle-collision normalization only: zero-area line interiors are NOT
    // claimed equivalent to retained area surfaces. Raw geometry stays intact.
    var ignoredDegenerateFaces: [IgnoredDegenerateFace] = []
    let historicalSupportProvenance = "roomplan-original-polygon-earcut-v3.2.4"
    let vertices: [Double] // routing geometry in saved-world XYZ metres
    let triangles: [Int32]
    let floorSupport: [Bool] // exactly one value per triangle
    let triangleFeatureIDs: [UUID]
    let exportedFeatureIDs: Set<UUID>
    let upwardFloorTriangles: Int
    let downwardFloorTriangles: Int
    var physicalAuthority: Bool { false }
    var currentDoorStateKnown: Bool { false }
    var actualWorldCoverageKnown: Bool { false }
}

/// Apple provides exported obstacle tessellation/cutouts and separately the
/// original semantic floor polygon. Preserve the raw export; derive historical
/// route support with released Mapbox earcut CPU tessellation. No guessed floor fill,
/// physical support claim, detailed model replacement or geometry inflation.
/// Call only on a bounded utility worker, never the main/AR/hazard callback.
enum SavedRoomRouteMeshAdapter {
    enum Failure: Error, Equatable {
        case wrongExecutionContext, sourceMismatch, invalidSource, unsupportedGeometry
        case exportFailed, invalidMesh, sourceGeometryMismatch, budgetExceeded
        // Keep failures content-free: private room names/identifiers and file
        // paths must never enter logs. These distinguish previously conflated
        // missingMetadata stages independently of the supported wire encoding.
        case metadataReadFailed, metadataDecodeFailed, metadataEmpty, metadataInvalidEntries
        case meshNodeMissingMetadata, metadataUnknownFeature
        // Content-free native diagnostic stages. No private coordinates or IDs.
        case floorTessellationFailed, floorTessellationIndexOutOfRange
        case floorTessellationWindingMismatch, floorTessellationDegenerateTriangle
    }
    static let maximumSourceBytes = 8 * 1024 * 1024
    static let maximumExportBytes = 32 * 1024 * 1024
    static let maximumMetadataBytes = 1024 * 1024
    static let maximumVertices = 200_000
    static let maximumTriangles = 100_000
    static let maximumNodes = 4_096
    static let maximumDegenerateFaceReceipts = 4_096
    // Numeric comparison ONLY: Float32 exported vertices plus matrix round trips.
    // This is not RoomPlan accuracy, physical uncertainty or collision clearance.
    static func roundoffAllowance(_ scale: Double) -> Double {
        64 * Double(Float.ulpOfOne) * max(1, abs(scale))
    }

    /// RoomPlan's real exporter emits a binary property list even when the
    /// caller's metadata URL ends in .json (native run 40698547633). Preserve
    /// the documented flat node-name -> UUID map; choose its wire decoder from
    /// bytes, never the filename. JSON object input remains explicitly supported.
    /// Other formats, nested maps and invalid UUIDs remain rejected.
    static func decodeMetadata(data: Data) throws -> [String: UUID] {
        guard !data.isEmpty else { throw Failure.metadataEmpty }
        guard data.count <= maximumMetadataBytes else { throw Failure.budgetExceeded }
        let metadata: [String: UUID]
        do {
            if data.starts(with: Data("bplist00".utf8)) {
                metadata = try PropertyListDecoder().decode([String: UUID].self, from: data)
            } else if data.drop(while: { [9, 10, 13, 32].contains($0) }).first == 123 {
                metadata = try JSONDecoder().decode([String: UUID].self, from: data)
            } else {
                throw Failure.metadataDecodeFailed
            }
        } catch { throw Failure.metadataDecodeFailed }
        guard !metadata.isEmpty else { throw Failure.metadataEmpty }
        guard metadata.count <= maximumNodes,
              metadata.keys.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 512 }) else { throw Failure.metadataInvalidEntries }
        return metadata
    }

    static func decode(data: Data, expectedSHA256: String) throws -> SavedRoomRouteMeshSnapshot {
        guard !Thread.isMainThread else { throw Failure.wrongExecutionContext }
        guard !data.isEmpty, data.count <= maximumSourceBytes else { throw Failure.budgetExceeded }
        guard expectedSHA256.count == 64,
              expectedSHA256.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }),
              SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == expectedSHA256
        else { throw Failure.sourceMismatch }
        let room: CapturedRoom
        do { room = try JSONDecoder().decode(CapturedRoom.self, from: data) }
        catch { throw Failure.invalidSource }
        let features = try originalFeatures(room)
        let byID = Dictionary(uniqueKeysWithValues: features.map { ($0.id, $0) })
        let manager = FileManager.default
        var root = manager.temporaryDirectory.appendingPathComponent("BlindRoomRouteMesh-\(UUID().uuidString)", isDirectory: true)
        try manager.createDirectory(at: root, withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700, .protectionKey: FileProtectionType.complete])
        defer { try? manager.removeItem(at: root) }
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try root.setResourceValues(values)
        let meshURL = root.appendingPathComponent("room.usdz")
        let metadataURL = root.appendingPathComponent("metadata.json")
        do {
            // .mesh is Apple's triangle/cutout export. .parametric would retain
            // whole wall primitives. No ModelProvider substitutions are allowed.
            try room.export(to: meshURL, metadataURL: metadataURL, modelProvider: nil, exportOptions: .mesh)
        } catch { throw Failure.exportFailed }
        // These are acceptance bounds, not hard bounds on Apple's internal
        // exporter allocations. No textures are loaded or network URLs resolved.
        for (url, limit, readFailure) in [(meshURL, maximumExportBytes, Failure.exportFailed),
                                         (metadataURL, maximumMetadataBytes, Failure.metadataReadFailed)] {
            let attributes: [FileAttributeKey: Any]
            do { attributes = try manager.attributesOfItem(atPath: url.path) }
            catch { throw readFailure }
            if url == metadataURL, (attributes[.size] as? NSNumber)?.int64Value == 0 {
                throw Failure.metadataEmpty
            }
            guard let bytes = attributes[.size] as? NSNumber, bytes.int64Value > 0,
                  bytes.int64Value <= Int64(limit) else { throw Failure.budgetExceeded }
            try manager.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
        }
        let metadataData: Data
        do { metadataData = try Data(contentsOf: metadataURL) }
        catch { throw Failure.metadataReadFailed }
        let metadata = try decodeMetadata(data: metadataData)

        // Ask the platform to convert indices to triangles and positions to an
        // explicit packed format. Validate the returned buffers before reading.
        let descriptor = MDLVertexDescriptor()
        descriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition,
            format: .float3, offset: 0, bufferIndex: 0)
        descriptor.layouts[0] = MDLVertexBufferLayout(stride: 3 * MemoryLayout<Float>.size)
        var importError: NSError?
        let asset = MDLAsset(url: meshURL, vertexDescriptor: descriptor,
            bufferAllocator: nil, preserveTopology: false, error: &importError)
        guard importError == nil, asset.count > 0, asset.count <= maximumNodes,
              asset.startTime == asset.endTime else { throw Failure.invalidMesh }
        var vertices: [Double] = [], triangles: [Int32] = [], support: [Bool] = [], triangleIDs: [UUID] = []
        var exported = Set<UUID>(), visited = Set<ObjectIdentifier>(), nodeCount = 0
        var upward = 0, downward = 0
        var ignoredDegenerateFaces: [SavedRoomRouteMeshSnapshot.IgnoredDegenerateFace] = []

        func visit(_ node: MDLObject, inheritedID: UUID?, depth: Int) throws {
            guard depth <= 64, visited.insert(ObjectIdentifier(node)).inserted else { throw Failure.invalidMesh }
            nodeCount += 1
            guard nodeCount <= maximumNodes else { throw Failure.budgetExceeded }
            let identity = metadata[node.name] ?? inheritedID
            if let directID = metadata[node.name] {
                guard let feature = byID[directID] else { throw Failure.metadataUnknownFeature }
                try verifyFeatureFrame(MDLTransform.globalTransform(with: node, atTime: asset.startTime), feature: feature)
            }
            if let mesh = node as? MDLMesh {
                guard let id = identity else { throw Failure.meshNodeMissingMetadata }
                guard let feature = byID[id] else { throw Failure.metadataUnknownFeature }
                guard mesh.vertexCount > 0, mesh.vertexCount <= maximumVertices - vertices.count / 3,
                      mesh.vertexDescriptor.attributes.count > 0, mesh.vertexDescriptor.layouts.count > 0,
                      let attribute = mesh.vertexDescriptor.attributes[0] as? MDLVertexAttribute,
                      attribute.name == MDLVertexAttributePosition, attribute.format == .float3,
                      attribute.offset == 0, attribute.bufferIndex == 0,
                      let layout = mesh.vertexDescriptor.layouts[0] as? MDLVertexBufferLayout,
                      layout.stride == 12, !mesh.vertexBuffers.isEmpty,
                      mesh.vertexBuffers[0].length >= mesh.vertexCount * 12,
                      let submeshes = mesh.submeshes as? [MDLSubmesh], !submeshes.isEmpty,
                      submeshes.count <= maximumNodes else { throw Failure.invalidMesh }
                let world = MDLTransform.globalTransform(with: mesh, atTime: asset.startTime)
                // The currently supported exporter subset retains the source
                // frame at each mesh as verified by the same-file reference.
                // Reject extra child transforms rather than assuming inherited
                // metadata also proves the geometry's coordinate frame.
                try verifyFeatureFrame(world, feature: feature)
                let matrixValues = (0..<4).flatMap { column in (0..<4).map { row in Double(world[column][row]) } }
                guard matrixValues.allSatisfy(\.isFinite),
                      abs(matrixValues[3]) <= roundoffAllowance(1),
                      abs(matrixValues[7]) <= roundoffAllowance(1),
                      abs(matrixValues[11]) <= roundoffAllowance(1),
                      abs(matrixValues[15] - 1) <= roundoffAllowance(1) else { throw Failure.invalidMesh }
                let base = Int32(vertices.count / 3)
                let vertexMap = mesh.vertexBuffers[0].map()
                var localVertices: [SIMD3<Double>] = []
                localVertices.reserveCapacity(mesh.vertexCount)
                for index in 0..<mesh.vertexCount {
                    let address = vertexMap.bytes.advanced(by: index * 12)
                    let p = SIMD4<Float>(address.loadUnaligned(as: Float.self),
                        address.advanced(by: 4).loadUnaligned(as: Float.self),
                        address.advanced(by: 8).loadUnaligned(as: Float.self), 1)
                    guard p.x.isFinite, p.y.isFinite, p.z.isFinite else { throw Failure.invalidMesh }
                    let w = world * p
                    guard w.x.isFinite, w.y.isFinite, w.z.isFinite,
                          abs(w.x) <= 10_000, abs(w.y) <= 10_000, abs(w.z) <= 10_000,
                          abs(w.w - 1) <= Float(roundoffAllowance(1)) else { throw Failure.invalidMesh }
                    let value = [Double(w.x), Double(w.y), Double(w.z)]
                    localVertices.append(SIMD3(Double(p.x), Double(p.y), Double(p.z)))
                    // Furniture and architectural surface dimensions have different
                    // contracts. Apple's architectural export adds solid depth and
                    // end extensions absent from its planar source representation.
                    // Do not weaken furniture bounds or numeric roundoff to admit it.
                    if feature.kind == .furniture { try verifySourceBounds(value, feature: feature) }
                    vertices.append(contentsOf: value)
                }
                var emitted = 0
                for submesh in submeshes {
                    guard submesh.geometryType == .triangles, submesh.indexCount > 0,
                          submesh.indexCount % 3 == 0,
                          submesh.indexCount / 3 <= maximumTriangles - triangles.count / 3 else { throw Failure.invalidMesh }
                    let width: Int
                    switch submesh.indexType {
                    case .uInt8: width = 1
                    case .uInt16: width = 2
                    case .uInt32: width = 4
                    default: throw Failure.unsupportedGeometry
                    }
                    guard submesh.indexBuffer.length >= submesh.indexCount * width else { throw Failure.invalidMesh }
                    let indexMap = submesh.indexBuffer.map()
                    var localIndices: [Int32] = []; localIndices.reserveCapacity(submesh.indexCount)
                    for index in 0..<submesh.indexCount {
                        let address = indexMap.bytes.advanced(by: index * width)
                        let value: UInt32
                        switch width {
                        case 1: value = UInt32(address.loadUnaligned(as: UInt8.self))
                        case 2: value = UInt32(address.loadUnaligned(as: UInt16.self))
                        default: value = address.loadUnaligned(as: UInt32.self)
                        }
                        guard value < UInt32(mesh.vertexCount) else { throw Failure.invalidMesh }
                        localIndices.append(base + Int32(value))
                    }
                    for offset in stride(from: 0, to: localIndices.count, by: 3) {
                        let indices = Array(localIndices[offset..<(offset + 3)])
                        let a = point(vertices, indices[0]), b = point(vertices, indices[1]), c = point(vertices, indices[2])
                        let local = indices.map { localVertices[Int($0 - base)] }
                        let ignored = try exactDuplicateTriangleDisposition(local: local, world: [a,b,c])
                        let normal = simd_cross(b - a, c - a)
                        let isFloor = feature.kind == .floor
                        if ignored {
                            guard ignoredDegenerateFaces.count < maximumDegenerateFaceReceipts else { throw Failure.budgetExceeded }
                            ignoredDegenerateFaces.append(.init(rawTriangleIndex: triangles.count / 3,
                                featureID: id, indices: indices,
                                localVertices: local.map { [$0.x,$0.y,$0.z] },
                                worldVertices: [a,b,c].map { [$0.x,$0.y,$0.z] }))
                        } else {
                            emitted += 1
                            if isFloor { if normal.y > 0 { upward += 1 } else if normal.y < 0 { downward += 1 } }
                        }
                        // Preserve raw order, indices, feature identity and positions,
                        // including exact duplicate-position faces, for audit/rendering.
                        triangles.append(contentsOf: indices); support.append(isFloor); triangleIDs.append(id)
                    }
                }
                guard emitted > 0 else { throw Failure.invalidMesh }
                exported.insert(id)
            }
            let children = node.children.objects
            guard children.count <= maximumNodes - nodeCount else { throw Failure.budgetExceeded }
            for child in children { try visit(child, inheritedID: identity, depth: depth + 1) }
        }
        for index in 0..<asset.count { try visit(asset.object(at: index), inheritedID: nil, depth: 0) }
        // An opening/open historical door may be represented by a wall cutout,
        // not a leaf mesh. Closed doors and windows must have blocking geometry.
        let required = features.filter { $0.kind != .opening && !($0.kind == .door && $0.capturedDoorOpen == true) }
        guard !vertices.isEmpty, !triangles.isEmpty, required.allSatisfy({ exported.contains($0.id) }),
              support.count == triangles.count / 3, triangleIDs.count == support.count,
              support.contains(true) else { throw Failure.unsupportedGeometry }
        let routing = try historicalRoutingGeometry(features: features, rawVertices: vertices,
            rawTriangles: triangles, rawTriangleFeatureIDs: triangleIDs,
            ignoredRawTriangleIndices: ignoredDegenerateFaces.map(\.rawTriangleIndex))
        return .init(sourceSHA256: expectedSHA256, capturedRoomID: room.identifier, features: features,
            rawExportVertices: vertices, rawExportTriangles: triangles, rawExportTriangleFeatureIDs: triangleIDs,
            ignoredDegenerateFaces: ignoredDegenerateFaces,
            vertices: routing.vertices, triangles: routing.triangles,
            floorSupport: routing.floorSupport, triangleFeatureIDs: routing.featureIDs,
            exportedFeatureIDs: exported, upwardFloorTriangles: routing.upward, downwardFloorTriangles: 0)
    }

    /// Compare the metadata-bearing feature frame, not a guessed nearest object
    /// or a semantic parent composed a second time. No change to source frames.
    static func verifyFeatureFrame(_ world: simd_float4x4, feature: SavedRoomRouteMeshSnapshot.Feature) throws {
        let values = (0..<4).flatMap { column in (0..<4).map { row in Double(world[column][row]) } }
        guard feature.transform.count == 16, NativeCameraTransform(columns: feature.transform).valid,
              NativeCameraTransform(columns: values).valid else { throw Failure.invalidMesh }
        let scale = (values + feature.transform).map(abs).max() ?? 1
        guard zip(values, feature.transform).allSatisfy({ pair in abs(pair.0 - pair.1) <= roundoffAllowance(scale) }) else {
            throw Failure.sourceGeometryMismatch
        }
    }

    /// Adapt the established exact duplicate-vertex / degenerate-index cleanup
    /// semantics (Open3D 0.19) without epsilon merging. Both SOURCE and WORLD
    /// positions must contain the same exact coincident pair; distinct-collinear
    /// faces and transform-induced collapse remain errors. No thin valid face
    /// is removed. A true result authorizes triangle-list normalization only.
    static func exactDuplicateTriangleDisposition(local: [SIMD3<Double>], world: [SIMD3<Double>]) throws -> Bool {
        guard local.count == 3, world.count == 3,
              (local + world).allSatisfy({ $0.x.isFinite && $0.y.isFinite && $0.z.isFinite }) else { throw Failure.invalidMesh }
        let localNormal = simd_cross(local[1]-local[0],local[2]-local[0])
        let worldNormal = simd_cross(world[1]-world[0],world[2]-world[0])
        guard [localNormal.x,localNormal.y,localNormal.z,worldNormal.x,worldNormal.y,worldNormal.z].allSatisfy(\.isFinite) else {
            throw Failure.invalidMesh
        }
        let pairs = [(0,1),(1,2),(2,0)]
        let localDuplicates = pairs.map { local[$0.0] == local[$0.1] }
        let worldDuplicates = pairs.map { world[$0.0] == world[$0.1] }
        if localDuplicates.contains(true) || worldDuplicates.contains(true) {
            guard localDuplicates == worldDuplicates, localDuplicates.contains(true) else { throw Failure.invalidMesh }
            return true
        }
        guard simd_length_squared(localNormal) > 0, simd_length_squared(worldNormal) > 0 else { throw Failure.invalidMesh }
        return false
    }

    struct HistoricalRoutingGeometry: Sendable {
        var vertices: [Double] = []
        var triangles: [Int32] = []
        var floorSupport: [Bool] = []
        var featureIDs: [UUID] = []
        var upward = 0
    }

    /// Never use the raw slab top, sides or underside as floor support. Preserve
    /// all positive-area non-floor export triangles without translation, scaling
    /// or simplification. Only separately witnessed exact duplicate-position
    /// faces are omitted from this triangle-only representation; raw data and
    /// per-face endpoint receipts remain available and confer no physical authority.
    static func historicalRoutingGeometry(features: [SavedRoomRouteMeshSnapshot.Feature],
        rawVertices: [Double], rawTriangles: [Int32], rawTriangleFeatureIDs: [UUID],
        ignoredRawTriangleIndices: [Int] = []) throws -> HistoricalRoutingGeometry {
        guard rawVertices.count % 3 == 0, rawTriangles.count % 3 == 0,
              rawTriangleFeatureIDs.count == rawTriangles.count / 3,
              rawVertices.count / 3 <= maximumVertices, rawTriangles.count / 3 <= maximumTriangles,
              rawVertices.allSatisfy(\.isFinite),
              rawTriangles.allSatisfy({ $0 >= 0 && Int($0) < rawVertices.count / 3 }) else { throw Failure.invalidMesh }
        guard Set(features.map(\.id)).count == features.count else { throw Failure.invalidSource }
        let byID = Dictionary(uniqueKeysWithValues: features.map { ($0.id, $0) })
        guard ignoredRawTriangleIndices.count <= maximumDegenerateFaceReceipts,
              Set(ignoredRawTriangleIndices).count == ignoredRawTriangleIndices.count,
              ignoredRawTriangleIndices.allSatisfy({ $0 >= 0 && $0 < rawTriangleFeatureIDs.count }) else { throw Failure.invalidMesh }
        let ignored = Set(ignoredRawTriangleIndices)
        var result = HistoricalRoutingGeometry()
        var copiedVertices: [Int32: Int32] = [:]
        var requiredNonFloor = Set<UUID>(), retainedNonFloor = Set<UUID>()
        for face in rawTriangleFeatureIDs.indices {
            let id = rawTriangleFeatureIDs[face]
            guard let feature = byID[id] else { throw Failure.metadataUnknownFeature }
            let indices = Array(rawTriangles[(face * 3)..<(face * 3 + 3)])
            let world = indices.map { point(rawVertices, $0) }
            let duplicate = try exactDuplicateTriangleDisposition(local: world, world: world)
            guard duplicate == ignored.contains(face) else { throw Failure.invalidMesh }
            if feature.kind != .floor { requiredNonFloor.insert(id) }
            guard !duplicate, feature.kind != .floor else { continue }
            retainedNonFloor.insert(id)
            for corner in 0..<3 {
                let source = rawTriangles[face * 3 + corner]
                if let existing = copiedVertices[source] { result.triangles.append(existing) }
                else {
                    let next = Int32(result.vertices.count / 3)
                    copiedVertices[source] = next
                    result.vertices.append(contentsOf: rawVertices[(Int(source) * 3)..<(Int(source) * 3 + 3)])
                    result.triangles.append(next)
                }
            }
            result.floorSupport.append(false); result.featureIDs.append(id)
        }
        guard requiredNonFloor.isSubset(of: retainedNonFloor) else { throw Failure.invalidMesh }
        for floor in features.filter({ $0.kind == .floor }) {
            let flat = try tessellateHistoricalFloor(floor)
            guard flat.vertices.count / 3 <= maximumVertices - result.vertices.count / 3,
                  flat.triangles.count / 3 <= maximumTriangles - result.triangles.count / 3 else { throw Failure.budgetExceeded }
            let base = Int32(result.vertices.count / 3)
            result.vertices.append(contentsOf: flat.vertices)
            result.triangles.append(contentsOf: flat.triangles.map { $0 + base })
            let count = flat.triangles.count / 3
            result.floorSupport.append(contentsOf: repeatElement(true, count: count))
            result.featureIDs.append(contentsOf: repeatElement(floor.id, count: count))
            result.upward += count
        }
        guard result.upward > 0 else { throw Failure.unsupportedGeometry }
        return result
    }

    /// Released Mapbox earcut owns CPU polygon tessellation and returns indices
    /// into the exact source corners. Do not rely on SCNShape's lazy/generated
    /// buffers: the retained native probes returned empty flat geometry. These
    /// checks validate the upstream result, not a second triangulator or live
    /// supporting-floor evidence. Invalid source rings are never repaired.
    static func tessellateHistoricalFloor(_ floor: SavedRoomRouteMeshSnapshot.Feature) throws -> HistoricalRoutingGeometry {
        guard floor.kind == .floor, (3...1024).contains(floor.polygonCorners.count),
              floor.polygonCorners.allSatisfy({ $0.count == 3 && $0.allSatisfy(\.isFinite) }),
              NativeCameraTransform(columns: floor.transform).valid else { throw Failure.invalidSource }
        let points = floor.polygonCorners
        let epsilon = roundoffAllowance((points.flatMap { $0 } + floor.transform).map(abs).max() ?? 1)
        let planeZ = points[0][2]
        guard points.allSatisfy({ abs($0[2] - planeZ) <= epsilon }) else { throw Failure.unsupportedGeometry }
        // Reject ambiguous/non-simple source polygons; never ask the tessellator
        // to repair intersections, duplicate edges or a missing floor region.
        func orient(_ a: [Double], _ b: [Double], _ c: [Double]) -> Double {
            (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])
        }
        func onSegment(_ p: [Double], _ a: [Double], _ b: [Double]) -> Bool {
            orient(a, b, p) == 0 && p[0] >= min(a[0], b[0]) && p[0] <= max(a[0], b[0]) &&
                p[1] >= min(a[1], b[1]) && p[1] <= max(a[1], b[1])
        }
        for i in points.indices {
            let a = points[i], b = points[(i + 1) % points.count]
            guard a[0] != b[0] || a[1] != b[1] else { throw Failure.invalidSource }
            for j in points.indices where j > i && j != (i + 1) % points.count && i != (j + 1) % points.count {
                let c = points[j], d = points[(j + 1) % points.count]
                let abC = orient(a, b, c), abD = orient(a, b, d), cdA = orient(c, d, a), cdB = orient(c, d, b)
                let crossing = ((abC > 0 && abD < 0) || (abC < 0 && abD > 0)) &&
                    ((cdA > 0 && cdB < 0) || (cdA < 0 && cdB > 0))
                guard !crossing && !onSegment(c,a,b) && !onSegment(d,a,b) && !onSegment(a,c,d) && !onSegment(b,c,d) else {
                    throw Failure.invalidSource
                }
            }
        }
        let sourceArea = abs(points.indices.reduce(0.0) { sum, i in
            let next = points[(i + 1) % points.count]
            return sum + points[i][0] * next[1] - next[0] * points[i][1]
        }) / 2
        guard sourceArea.isFinite, sourceArea > 0 else { throw Failure.invalidSource }
        let indices: [Int32]
        do { indices = try HistoricalPolygonTriangulation.indices(xy: points.flatMap { [$0[0], $0[1]] }) }
        catch { throw Failure.floorTessellationFailed }
        guard !indices.isEmpty, indices.count % 3 == 0,
              indices.count / 3 <= maximumTriangles,
              indices.allSatisfy({ $0 >= 0 && Int($0) < points.count }) else {
            throw Failure.floorTessellationIndexOutOfRange
        }
        let transform = NativeCameraTransform(columns: floor.transform)
        var result = HistoricalRoutingGeometry()
        // Preserve the original Double values (decoded from RoomPlan Float32),
        // including a nonzero source plane offset. No generated mesh positions,
        // deduplication, grid quantization or affine transform is inserted here.
        let localPoints = points
        for local in localPoints {
            let world = try transform.applying(to: Point3(local[0], local[1], local[2]))
            let value = [world.x, world.y, world.z]
            try verifySourceBounds(value, feature: floor)
            result.vertices.append(contentsOf: value)
        }
        var area = 0.0
        for offset in stride(from: 0, to: indices.count, by: 3) {
            let face = Array(indices[offset..<(offset + 3)])
            let a = point(result.vertices, face[0]), b = point(result.vertices, face[1]), c = point(result.vertices, face[2])
            let normal = simd_cross(b-a,c-a)
            // Earcut documents CCW XY output for either input winding. The
            // original floor frame must map that front face upward; never flip
            // an imported source frame or output indices to force acceptance.
            guard normal.y > 0, [normal.x,normal.y,normal.z].allSatisfy(\.isFinite) else {
                throw Failure.floorTessellationWindingMismatch
            }
            let local = face.map { localPoints[Int($0)] }
            let localArea = orient(local[0],local[1],local[2]) / 2
            guard localArea > 0 else { throw Failure.floorTessellationDegenerateTriangle }
            area += localArea
            result.triangles.append(contentsOf: face)
        }
        guard abs(area - sourceArea) <= roundoffAllowance(sourceArea) else { throw Failure.sourceGeometryMismatch }
        try verifyHistoricalFloorBoundary(source: points, tessellated: localPoints, triangles: result.triangles, epsilon: epsilon)
        result.upward = result.triangles.count / 3
        result.floorSupport = Array(repeating: true, count: result.upward)
        result.featureIDs = Array(repeating: floor.id, count: result.upward)
        return result
    }

    /// Validate the oriented triangle chain, not just its AABB or summed area.
    /// Oppositely paired interior edges cancel; the remaining directed boundary
    /// must cover the original polygon boundary in both directions. This rejects
    /// concavity bridges and overlapping/missing patches without triangulating.
    static func verifyHistoricalFloorBoundary(source: [[Double]], tessellated: [[Double]],
        triangles: [Int32], epsilon: Double) throws {
        struct Edge { let a, b: SIMD2<Double> }
        struct Entry { let edge: Edge; let firstKey, lastKey: String; var count: Int }
        func point(_ index: Int32) -> SIMD2<Double> {
            let p = tessellated[Int(index)]; return SIMD2(p[0],p[1])
        }
        func key(_ p: SIMD2<Double>) -> String {
            "\(p.x == 0 ? 0 : p.x.bitPattern):\(p.y == 0 ? 0 : p.y.bitPattern)"
        }
        func cross(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double { a.x*b.y-a.y*b.x }
        guard (3...1024).contains(source.count), tessellated.count <= maximumVertices,
              triangles.count / 3 <= maximumTriangles, source.allSatisfy({ $0.count == 3 && $0.allSatisfy(\.isFinite) }),
              tessellated.allSatisfy({ $0.count == 3 && $0.allSatisfy(\.isFinite) }),
              triangles.count % 3 == 0, !triangles.isEmpty,
              triangles.allSatisfy({ $0 >= 0 && Int($0) < tessellated.count }),
              epsilon.isFinite, epsilon >= 0 else { throw Failure.invalidMesh }
        var entries: [String: Entry] = [:]
        for offset in stride(from: 0, to: triangles.count, by: 3) {
            let p = (0..<3).map { point(triangles[offset+$0]) }
            guard cross(p[1]-p[0],p[2]-p[0]) > 0 else { throw Failure.invalidMesh }
            for i in 0..<3 {
                let a = p[i], b = p[(i+1)%3], first = key(a), last = key(b)
                guard first != last else { throw Failure.invalidMesh }
                let id = [first,last].sorted().joined(separator: "|")
                if var entry = entries[id] {
                    guard entry.count == 1, entry.firstKey == last, entry.lastKey == first else { throw Failure.invalidMesh }
                    entry.count = 2; entries[id] = entry
                } else { entries[id] = Entry(edge: Edge(a:a,b:b), firstKey:first,lastKey:last,count:1) }
            }
        }
        let boundary = entries.values.filter { $0.count == 1 }.map(\.edge)
        guard !boundary.isEmpty, boundary.count <= 4096,
              boundary.count * source.count <= 4_194_304 else { throw Failure.budgetExceeded }
        let area = source.indices.reduce(0.0) { sum, i in
            let j = (i+1)%source.count
            return sum + source[i][0]*source[j][1]-source[j][0]*source[i][1]
        }
        guard area != 0, area.isFinite else { throw Failure.invalidSource }
        let expected = source.indices.map { i -> Edge in
            let j = (i+1)%source.count, a = SIMD2(source[i][0],source[i][1]), b = SIMD2(source[j][0],source[j][1])
            return area > 0 ? Edge(a:a,b:b) : Edge(a:b,b:a)
        }
        func covered(_ edge: Edge, by others: [Edge]) -> Bool {
            let vector = edge.b-edge.a, length = simd_length(vector)
            guard length > 0 else { return false }
            let direction = vector/length
            var intervals: [(Double,Double)] = []
            for other in others {
                guard abs(cross(direction,other.a-edge.a)) <= epsilon,
                      abs(cross(direction,other.b-edge.a)) <= epsilon else { continue }
                let start = simd_dot(other.a-edge.a,direction), end = simd_dot(other.b-edge.a,direction)
                // Orientation cannot be reversed to disguise an overlapping or
                // oppositely wound boundary. Zero-length endpoint touches add no coverage.
                guard end > start else { continue }
                let low = max(0,start), high = min(length,end)
                if high > low { intervals.append((low,high)) }
            }
            intervals.sort { $0.0 < $1.0 }
            var reached = 0.0
            for interval in intervals {
                guard interval.0 <= reached + epsilon,
                      interval.0 >= reached - epsilon else { return false }
                reached = max(reached,interval.1)
            }
            return abs(reached-length) <= epsilon
        }
        guard boundary.allSatisfy({ covered($0,by:expected) }),
              expected.allSatisfy({ covered($0,by:boundary) }) else { throw Failure.sourceGeometryMismatch }
    }

    // Internal for the original-public-fixture probe to observe the exact
    // Float32-decoded source fields used by production, not different JSON math.
    static func originalFeatures(_ room: CapturedRoom) throws -> [SavedRoomRouteMeshSnapshot.Feature] {
        typealias Feature = SavedRoomRouteMeshSnapshot.Feature
        let groups: [(SavedRoomRouteMeshSnapshot.Kind, [CapturedRoom.Surface])] = [(.floor, room.floors),
            (.wall, room.walls), (.door, room.doors), (.window, room.windows), (.opening, room.openings)]
        guard room.floors.count == 1, groups.reduce(room.objects.count, { $0 + $1.1.count }) <= 512 else { throw Failure.unsupportedGeometry }
        var result: [Feature] = []
        var corners = 0
        func matrix(_ m: simd_float4x4) -> [Double] { (0..<4).flatMap { c in (0..<4).map { r in Double(m[c][r]) } } }
        func vector(_ p: SIMD3<Float>) -> [Double] { [Double(p.x), Double(p.y), Double(p.z)] }
        for (kind, surfaces) in groups {
            for surface in surfaces {
                guard surface.curve == nil, surface.polygonCorners.count <= 1_024,
                      (surface.polygonCorners.isEmpty || surface.polygonCorners.count >= 3),
                      kind != .floor || surface.polygonCorners.count >= 3 else { throw Failure.unsupportedGeometry }
                corners += surface.polygonCorners.count
                guard corners <= 16_384 else { throw Failure.budgetExceeded }
                let doorOpen: Bool?
                if case .door(let isOpen) = surface.category { doorOpen = isOpen } else { doorOpen = nil }
                result.append(.init(id: surface.identifier, kind: kind, parentID: surface.parentIdentifier,
                    category: kind.rawValue, transform: matrix(surface.transform), dimensions: vector(surface.dimensions),
                    polygonCorners: surface.polygonCorners.map(vector), capturedDoorOpen: doorOpen))
            }
        }
        result += room.objects.map { .init(id: $0.identifier, kind: .furniture, parentID: $0.parentIdentifier,
            category: String(describing: $0.category), transform: matrix($0.transform), dimensions: vector($0.dimensions),
            polygonCorners: [], capturedDoorOpen: nil) }
        guard !result.isEmpty, Set(result.map(\.id)).count == result.count,
              result.allSatisfy({ NativeCameraTransform(columns: $0.transform).valid &&
                  $0.dimensions.allSatisfy({ $0.isFinite && (0...100).contains($0) }) &&
                  $0.polygonCorners.allSatisfy({ $0.allSatisfy({ $0.isFinite && abs($0) <= 100 }) }) &&
                  ($0.kind != .door || $0.capturedDoorOpen != nil) }) else { throw Failure.invalidSource }
        let ids = Set(result.map(\.id))
        guard result.allSatisfy({ $0.parentID.map { ids.contains($0) } ?? true }) else { throw Failure.invalidSource }
        return result
    }

    private static func point(_ v: [Double], _ i: Int32) -> SIMD3<Double> {
        let offset = Int(i) * 3; return SIMD3(v[offset], v[offset + 1], v[offset + 2])
    }
    struct SourceBoundsAssessment: Sendable {
        let localPoint, minimum, maximum: [Double]
        let epsilon: Double
        var firstViolationAxis: Int? {
            (0..<3).first { !(localPoint[$0] >= minimum[$0] - epsilon && localPoint[$0] <= maximum[$0] + epsilon) }
        }
    }
    /// The existing predicate exposed as data for a digest-gated test-only
    /// witness. No tolerance, transform, containment or acceptance is changed.
    static func sourceBoundsAssessment(_ world: [Double], feature: SavedRoomRouteMeshSnapshot.Feature) throws -> SourceBoundsAssessment {
        let t = NativeCameraTransform(columns: feature.transform)
        let local = try t.inverted().applying(to: Point3(world[0], world[1], world[2]))
        let p = [local.x, local.y, local.z]
        let scale = (world + feature.transform + feature.dimensions).map(abs).max() ?? 1
        let epsilon = roundoffAllowance(scale)
        let minimum = (0..<3).map { axis in feature.polygonCorners.map { $0[axis] }.min() ?? (-feature.dimensions[axis] / 2) }
        let maximum = (0..<3).map { axis in feature.polygonCorners.map { $0[axis] }.max() ?? (feature.dimensions[axis] / 2) }
        return .init(localPoint: p, minimum: minimum, maximum: maximum, epsilon: epsilon)
    }
    private static func verifySourceBounds(_ world: [Double], feature: SavedRoomRouteMeshSnapshot.Feature) throws {
        guard try sourceBoundsAssessment(world, feature: feature).firstViolationAxis == nil else {
            throw Failure.sourceGeometryMismatch
        }
    }
}

