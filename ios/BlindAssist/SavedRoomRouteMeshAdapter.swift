import Foundation
import CryptoKit
import RoomPlan
import ModelIO
import simd
import BlindCore

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
    let vertices: [Double] // packed saved-world XYZ metres; no second transform
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

/// Apple provides tessellation/cutouts. This adapter copies and classifies that
/// output; it never reconstructs walls, fills floor polygons, replaces furniture
/// with detailed models, repairs winding, registers frames or inflates geometry.
/// Call only on a bounded utility worker, never the main/AR/hazard callback.
enum SavedRoomRouteMeshAdapter {
    enum Failure: Error, Equatable {
        case wrongExecutionContext, sourceMismatch, invalidSource, unsupportedGeometry
        case exportFailed, missingMetadata, invalidMesh, sourceGeometryMismatch, budgetExceeded
    }
    static let maximumSourceBytes = 8 * 1024 * 1024
    static let maximumExportBytes = 32 * 1024 * 1024
    static let maximumMetadataBytes = 1024 * 1024
    static let maximumVertices = 200_000
    static let maximumTriangles = 100_000
    static let maximumNodes = 4_096
    // Numeric comparison ONLY: Float32 exported vertices plus matrix round trips.
    // This is not RoomPlan accuracy, physical uncertainty or collision clearance.
    static func roundoffAllowance(_ scale: Double) -> Double {
        64 * Double(Float.ulpOfOne) * max(1, abs(scale))
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
        for (url, limit) in [(meshURL, maximumExportBytes), (metadataURL, maximumMetadataBytes)] {
            let attributes = try manager.attributesOfItem(atPath: url.path)
            guard let bytes = attributes[.size] as? NSNumber, bytes.int64Value > 0,
                  bytes.int64Value <= Int64(limit) else { throw Failure.budgetExceeded }
            try manager.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
        }
        let metadata: [String: UUID]
        do { metadata = try JSONDecoder().decode([String: UUID].self, from: Data(contentsOf: metadataURL)) }
        catch { throw Failure.missingMetadata }
        guard !metadata.isEmpty, metadata.count <= maximumNodes,
              metadata.keys.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 512 }) else { throw Failure.missingMetadata }

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

        func visit(_ node: MDLObject, inheritedID: UUID?, depth: Int) throws {
            guard depth <= 64, visited.insert(ObjectIdentifier(node)).inserted else { throw Failure.invalidMesh }
            nodeCount += 1
            guard nodeCount <= maximumNodes else { throw Failure.budgetExceeded }
            let identity = metadata[node.name] ?? inheritedID
            if let mesh = node as? MDLMesh {
                guard let id = identity, let feature = byID[id] else { throw Failure.missingMetadata }
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
                let matrixValues = (0..<4).flatMap { column in (0..<4).map { row in Double(world[column][row]) } }
                guard matrixValues.allSatisfy(\.isFinite),
                      abs(matrixValues[3]) <= roundoffAllowance(1),
                      abs(matrixValues[7]) <= roundoffAllowance(1),
                      abs(matrixValues[11]) <= roundoffAllowance(1),
                      abs(matrixValues[15] - 1) <= roundoffAllowance(1) else { throw Failure.invalidMesh }
                let base = Int32(vertices.count / 3)
                let vertexMap = mesh.vertexBuffers[0].map()
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
                    try verifySourceBounds(value, feature: feature)
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
                        let normal = simd_cross(b - a, c - a)
                        guard normal.x.isFinite, normal.y.isFinite, normal.z.isFinite,
                              simd_length_squared(normal) > 0 else { throw Failure.invalidMesh }
                        let isFloor = feature.kind == .floor
                        if isFloor { if normal.y > 0 { upward += 1 } else if normal.y < 0 { downward += 1 } }
                        triangles.append(contentsOf: indices); support.append(isFloor); triangleIDs.append(id); emitted += 1
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
        return .init(sourceSHA256: expectedSHA256, capturedRoomID: room.identifier, features: features,
            vertices: vertices, triangles: triangles, floorSupport: support, triangleFeatureIDs: triangleIDs,
            exportedFeatureIDs: exported, upwardFloorTriangles: upward, downwardFloorTriangles: downward)
    }

    private static func originalFeatures(_ room: CapturedRoom) throws -> [SavedRoomRouteMeshSnapshot.Feature] {
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
    private static func verifySourceBounds(_ world: [Double], feature: SavedRoomRouteMeshSnapshot.Feature) throws {
        let t = NativeCameraTransform(columns: feature.transform)
        let local = try t.inverted().applying(to: Point3(world[0], world[1], world[2]))
        let p = [local.x, local.y, local.z]
        let scale = (world + feature.transform + feature.dimensions).map(abs).max() ?? 1
        let epsilon = roundoffAllowance(scale)
        for axis in 0..<3 {
            let lower = feature.polygonCorners.map { $0[axis] }.min() ?? (-feature.dimensions[axis] / 2)
            let upper = feature.polygonCorners.map { $0[axis] }.max() ?? (feature.dimensions[axis] / 2)
            guard p[axis] >= lower - epsilon, p[axis] <= upper + epsilon else { throw Failure.sourceGeometryMismatch }
        }
    }
}
