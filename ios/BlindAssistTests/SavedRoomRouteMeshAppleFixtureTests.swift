import XCTest
import CryptoKit
import CoreFoundation
import RoomPlan
import ModelIO
import simd
@testable import BlindAssist

/// Executes Apple's real RoomPlan mesh export and Model I/O importer over the
/// unchanged official fixtures. No synthetic CapturedRoom, supplied mesh or AR
/// registration. Numerical tolerances concern Float32 export arithmetic only.
@MainActor final class SavedRoomRouteMeshAppleFixtureTests: XCTestCase {
    private enum Fixture: String, CaseIterable, Sendable {
        case hallway = "Hallway2", bedroom = "Bedroom3"
        var digest: String {
            self == .hallway ? "f4cf3460fd9e746a86fe6538e2b1980e22e18207a2d3c7ea3f7679f58c8c6f4d" :
                "44df7bd5f4d1961bf13344916384dcfa20d42c7ef8dc58b0e13d1c2f7c6a4d2e"
        }
    }
    private struct RawCategory: Decodable { let isOpen: Bool? }
    private struct RawFeature: Decodable {
        let identifier: UUID
        let parentIdentifier: UUID?
        let dimensions, transform: [Double]
        let polygonCorners: [[Double]]?
        let category: [String: RawCategory]
    }
    private struct RawRoom: Decodable {
        let floors, walls, doors, windows, openings, objects: [RawFeature]
        var all: [RawFeature] { floors + walls + doors + windows + openings + objects }
    }
    private func bytes(_ fixture: Fixture) throws -> Data {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "\(fixture.rawValue).capturedRoom",
            withExtension: "json", subdirectory: "RoomPlanApple"))
        let data = try Data(contentsOf: url)
        guard SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == fixture.digest else {
            XCTFail("Only unchanged original public Apple fixture bytes are allowed")
            throw SavedRoomRouteMeshAdapter.Failure.sourceMismatch
        }
        return data
    }
    private func snapshot(_ fixture: Fixture) async throws -> (SavedRoomRouteMeshSnapshot, RawRoom) {
        let data = try bytes(fixture), expected = fixture.digest
        let mesh = try await Task.detached(priority: .utility) {
            try SavedRoomRouteMeshAdapter.decode(data: data, expectedSHA256: expected)
        }.value
        return (mesh, try JSONDecoder().decode(RawRoom.self, from: data))
    }
    private func vertex(_ mesh: SavedRoomRouteMeshSnapshot, _ index: Int32) -> SIMD3<Double> {
        let i = Int(index) * 3
        return SIMD3(mesh.vertices[i], mesh.vertices[i + 1], mesh.vertices[i + 2])
    }
    private func triangle(_ mesh: SavedRoomRouteMeshSnapshot, _ index: Int) -> [SIMD3<Double>] {
        (0..<3).map { vertex(mesh, mesh.triangles[index * 3 + $0]) }
    }
    // Independent multiplication from original JSON, not adapter helpers.
    private func world(_ local: [Double], _ source: RawFeature) -> SIMD3<Double> {
        let t = source.transform
        let p = (0..<3).map { r in t[r] * local[0] + t[4 + r] * local[1] + t[8 + r] * local[2] + t[12 + r] }
        return SIMD3(p[0], p[1], p[2])
    }
    private func localXY(_ world: SIMD3<Double>, _ source: RawFeature) -> SIMD2<Double> {
        let t = source.transform, x = world.x - source.transform[12], y = world.y - source.transform[13], z = world.z - source.transform[14]
        return SIMD2(t[0] * x + t[1] * y + t[2] * z, t[4] * x + t[5] * y + t[6] * z)
    }
    private func cross(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double { a.x * b.y - a.y * b.x }
    private func contains(_ p: SIMD2<Double>, triangle: [SIMD2<Double>]) -> Bool {
        guard cross(triangle[1] - triangle[0], triangle[2] - triangle[0]) != 0 else { return false }
        let a = cross(triangle[1] - triangle[0], p - triangle[0])
        let b = cross(triangle[2] - triangle[1], p - triangle[1])
        let c = cross(triangle[0] - triangle[2], p - triangle[2])
        return (a >= 0 && b >= 0 && c >= 0) || (a <= 0 && b <= 0 && c <= 0)
    }
    private struct BoundaryEdge { let a, b: SIMD3<Double> }
    /// Export may legitimately omit collinear source vertices. Compare complete
    /// boundary segments instead of requiring identical tessellation topology.
    /// Coincident exported Float32 vertices have identical copied Double bits;
    /// coordinate keys also work when Model I/O duplicates vertices per face.
    private func boundary(_ mesh: SavedRoomRouteMeshSnapshot, indices: [Int]) throws -> [BoundaryEdge] {
        var edges: [String: (edge: BoundaryEdge, count: Int)] = [:]
        func key(_ p: SIMD3<Double>) -> String { "\(p.x == 0 ? 0 : p.x.bitPattern):\(p.y == 0 ? 0 : p.y.bitPattern):\(p.z == 0 ? 0 : p.z.bitPattern)" }
        for index in indices {
            let points = triangle(mesh,index)
            guard simd_cross(points[1]-points[0],points[2]-points[0]).y > 0 else { continue }
            for i in 0..<3 {
                let a = points[i], b = points[(i+1)%3]
                let id = [key(a),key(b)].sorted().joined(separator:"|")
                if let previous = edges[id] { edges[id] = (previous.edge, previous.count+1) }
                else { edges[id] = (BoundaryEdge(a:a,b:b),1) }
            }
        }
        XCTAssertTrue(edges.values.allSatisfy { $0.count <= 2 },"Nonmanifold/overlapping upward floor mesh")
        return edges.values.filter { $0.count == 1 }.map(\.edge)
    }
    private func distance(_ point: SIMD3<Double>, edge: BoundaryEdge) -> Double {
        let segment = edge.b-edge.a, squaredLength = simd_length_squared(segment)
        guard squaredLength > 0 else { return simd_length(point-edge.a) }
        let fraction = max(0,min(1,simd_dot(point-edge.a,segment)/squaredLength))
        return simd_length(point-(edge.a+fraction*segment))
    }

    private struct MetadataEntry: Encodable, Sendable {
        let key, keySHA256, valueKind: String
        let uuidValue, knownFeature: Bool
        let uuid: String?
    }
    private struct ExportNode: Encodable, Sendable {
        let index, depth: Int
        let name, nameSHA256: String
        let isMesh, directMappingPresent, inheritedMappingPresent, knownFeature: Bool
        let parentIndex: Int?
        let directUUID, inheritedUUID, resolvedUUID: String?
        let vertexCount, submeshCount: Int?
    }
    private struct ExportInventory: Encodable, Sendable {
        let fixtureID, sourceSHA256: String
        var metadataByteCount = 0
        var metadataFormat = "unread"
        var metadataRootKind = "unread"
        var metadataEntryCount = 0
        var metadataEntriesTruncated = false
        var metadataEntries: [MetadataEntry] = []
        var nodeCount = 0
        var nodesTruncated = false
        var nodes: [ExportNode] = []
        var meshCount = 0
        var unmatchedMeshCount = 0
        var unknownFeatureMeshCount = 0
        var adapterFailure: String?
        var inventoryFailure: String?
        var geometryProbe: SourceBoundsProbe?
        var geometryProbeFailure: String?
    }
    private struct SourceBoundsProbe: Encodable, Sendable {
        let sourceEncoding = "capturedRoomFloat32"
        let nodeIndex, vertexIndex, vertexCount, axis: Int
        let featureID, featureKind, side: String
        let lower, upper, epsilon, residual: Double
        let meshLocalPoint, worldPoint, sourceLocalPoint, sourceDimensions: [Double]
        let sourceLocalMinimum, sourceLocalMaximum, sourceWorldMinimum, sourceWorldMaximum: [Double]
        let exportedWorldMinimum, exportedWorldMaximum: [Double]
        let exportedSourceLocalMinimum, exportedSourceLocalMaximum, assetUpAxis: [Double]
        let sourceTransform, meshLocalTransform, meshGlobalTransform, parentGlobalTransform, rootGlobalTransform: [Double]
    }
    private struct InventoryAttachment: Encodable {
        let schema = "blind.saved-room-route-mesh-metadata-inventory.v1"
        let physicalAuthority = false
        let fixtures: [ExportInventory]
    }
    private struct SameExportRecord: Encodable, Sendable {
        let fixtureID, sourceSHA256, assetAttachmentName, metadataAttachmentName: String
        let assetSHA256, metadataSHA256, metadataFormat: String
        let assetByteCount, metadataByteCount: Int
    }
    private struct SameExportAssets: Sendable {
        let record: SameExportRecord
        let asset, metadata: Data
    }
    private struct InventoryCapture: Sendable {
        let inventory: ExportInventory
        let sameExport: SameExportAssets?
    }
    private struct SameExportManifest: Encodable {
        let schema = "blind.saved-room-route-same-export.v1"
        let physicalAuthority = false
        let exportRole = "diagnostic-export"
        let productionAdapterExport = "separate-unretained"
        let testIdentifier = "SavedRoomRouteMeshAppleFixtureTests/testOriginalAppleSameExportForOpenUSDComparison"
        let inventoryAttachmentName = "APPLE_ROOM_ROUTE_MESH_METADATA_INVENTORY.json"
        let inventorySHA256: String
        let fixtures: [SameExportRecord]
    }
    private nonisolated static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    private nonisolated static func safeExportName(_ value: String) -> String {
        // No paths, URLs, control characters or unbounded exporter text in CI.
        let bytes = value.utf8
        guard (1...128).contains(bytes.count), bytes.allSatisfy({
            (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) ||
                [32, 45, 46, 95].contains($0)
        }) else { return "<redacted>" }
        return value
    }
    private nonisolated static func jsonKind(_ value: Any) -> String {
        if value is [String: Any] { return "object" }
        if value is [Any] { return "array" }
        if value is NSNull { return "null" }
        if value is String { return "string" }
        if let number = value as? NSNumber {
            return CFGetTypeID(number) == CFBooleanGetTypeID() ? "boolean" : "number"
        }
        return "null"
    }
    private nonisolated static func failureCode(_ error: Error) -> String {
        guard let failure = error as? SavedRoomRouteMeshAdapter.Failure else { return "unclassifiedError" }
        return String(describing: failure)
    }
    private nonisolated static func boundedSameExportData(at url: URL, limit: Int) throws -> Data {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular,
              let size = attributes[.size] as? NSNumber, size.int64Value > 0,
              size.int64Value <= Int64(limit) else { throw SavedRoomRouteMeshAdapter.Failure.budgetExceeded }
        let data = try Data(contentsOf: url)
        guard data.count == size.intValue, data.count <= limit else { throw SavedRoomRouteMeshAdapter.Failure.budgetExceeded }
        return data
    }

    /// One first-failing mesh, not a geometry dump. Uses the unchanged production
    /// predicate and records its entire mesh bounds to distinguish a frame error
    /// from exporter thickness. Never used to accept or modify geometry.
    private nonisolated static func sourceBoundsProbe(mesh: MDLMesh, nodeIndex: Int,
        feature: SavedRoomRouteMeshSnapshot.Feature, sceneRoot: MDLObject, parent: MDLObject?,
        asset: MDLAsset, examinedVertices: inout Int) throws -> SourceBoundsProbe? {
        typealias Adapter = SavedRoomRouteMeshAdapter
        guard nodeIndex < 128, mesh.vertexCount > 0,
              mesh.vertexCount <= Adapter.maximumVertices - examinedVertices else { throw Adapter.Failure.budgetExceeded }
        guard mesh.vertexDescriptor.attributes.count > 0, mesh.vertexDescriptor.layouts.count > 0,
              let attribute = mesh.vertexDescriptor.attributes[0] as? MDLVertexAttribute,
              attribute.name == MDLVertexAttributePosition, attribute.format == .float3,
              attribute.offset == 0, attribute.bufferIndex == 0,
              let layout = mesh.vertexDescriptor.layouts[0] as? MDLVertexBufferLayout,
              layout.stride == 12, !mesh.vertexBuffers.isEmpty,
              mesh.vertexBuffers[0].length >= mesh.vertexCount * 12 else { throw Adapter.Failure.invalidMesh }
        func matrix(_ value: simd_float4x4) throws -> [Double] {
            let values = (0..<4).flatMap { column in (0..<4).map { row in Double(value[column][row]) } }
            guard values.allSatisfy({ $0.isFinite && abs($0) <= 10_000 }) else { throw Adapter.Failure.invalidMesh }
            return values
        }
        let transform = MDLTransform.globalTransform(with: mesh, atTime: asset.startTime)
        let global = try matrix(transform)
        let local = try matrix(mesh.transform?.matrix ?? matrix_identity_float4x4)
        let parentGlobal = try matrix(parent.map { MDLTransform.globalTransform(with: $0, atTime: asset.startTime) } ?? matrix_identity_float4x4)
        let rootGlobal = try matrix(MDLTransform.globalTransform(with: sceneRoot, atTime: asset.startTime))
        let up = [Double(asset.upAxis.x), Double(asset.upAxis.y), Double(asset.upAxis.z)]
        guard up.allSatisfy({ $0.isFinite && abs($0) <= 10_000 }) else { throw Adapter.Failure.invalidMesh }
        var worldMinimum = [Double](repeating: .infinity, count: 3), worldMaximum = [Double](repeating: -.infinity, count: 3)
        var sourceMinimum = worldMinimum, sourceMaximum = worldMaximum
        var first: (index: Int, mesh: [Double], world: [Double], assessment: Adapter.SourceBoundsAssessment)?
        let map = mesh.vertexBuffers[0].map()
        for index in 0..<mesh.vertexCount {
            let address = map.bytes.advanced(by: index * 12)
            let point = SIMD4<Float>(address.loadUnaligned(as: Float.self),
                address.advanced(by: 4).loadUnaligned(as: Float.self),
                address.advanced(by: 8).loadUnaligned(as: Float.self), 1)
            guard point.x.isFinite, point.y.isFinite, point.z.isFinite,
                  abs(point.x) <= 10_000, abs(point.y) <= 10_000, abs(point.z) <= 10_000 else { throw Adapter.Failure.invalidMesh }
            let world = transform * point
            guard world.x.isFinite, world.y.isFinite, world.z.isFinite,
                  abs(world.x) <= 10_000, abs(world.y) <= 10_000, abs(world.z) <= 10_000,
                  abs(world.w - 1) <= Float(Adapter.roundoffAllowance(1)) else { throw Adapter.Failure.invalidMesh }
            let value = [Double(world.x), Double(world.y), Double(world.z)]
            let assessment = try Adapter.sourceBoundsAssessment(value, feature: feature)
            guard assessment.localPoint.allSatisfy({ $0.isFinite && abs($0) <= 10_000 }) else { throw Adapter.Failure.invalidMesh }
            for axis in 0..<3 {
                worldMinimum[axis] = min(worldMinimum[axis], value[axis]); worldMaximum[axis] = max(worldMaximum[axis], value[axis])
                sourceMinimum[axis] = min(sourceMinimum[axis], assessment.localPoint[axis]); sourceMaximum[axis] = max(sourceMaximum[axis], assessment.localPoint[axis])
            }
            if first == nil, assessment.firstViolationAxis != nil {
                first = (index, [Double(point.x), Double(point.y), Double(point.z)], value, assessment)
            }
        }
        examinedVertices += mesh.vertexCount
        guard let first, let axis = first.assessment.firstViolationAxis else { return nil }
        let bounds = first.assessment
        let sourcePoints: [[Double]]
        if !feature.polygonCorners.isEmpty { sourcePoints = feature.polygonCorners }
        else { sourcePoints = (0..<8).map { mask in (0..<3).map { (mask & (1 << $0)) == 0 ? bounds.minimum[$0] : bounds.maximum[$0] } } }
        let t = feature.transform
        let originalWorld = sourcePoints.map { p in
            (0..<3).map { r in t[r] * p[0] + t[4 + r] * p[1] + t[8 + r] * p[2] + t[12 + r] }
        }
        let below = bounds.localPoint[axis] < bounds.minimum[axis] - bounds.epsilon
        return .init(nodeIndex: nodeIndex, vertexIndex: first.index, vertexCount: mesh.vertexCount, axis: axis,
            featureID: feature.id.uuidString, featureKind: feature.kind.rawValue,
            side: below ? "belowMinimum" : "aboveMaximum", lower: bounds.minimum[axis], upper: bounds.maximum[axis],
            epsilon: bounds.epsilon, residual: below ? bounds.minimum[axis] - bounds.localPoint[axis] : bounds.localPoint[axis] - bounds.maximum[axis],
            meshLocalPoint: first.mesh, worldPoint: first.world, sourceLocalPoint: bounds.localPoint, sourceDimensions: feature.dimensions,
            sourceLocalMinimum: bounds.minimum, sourceLocalMaximum: bounds.maximum,
            sourceWorldMinimum: (0..<3).map { axis in originalWorld.map { $0[axis] }.min()! },
            sourceWorldMaximum: (0..<3).map { axis in originalWorld.map { $0[axis] }.max()! },
            exportedWorldMinimum: worldMinimum, exportedWorldMaximum: worldMaximum,
            exportedSourceLocalMinimum: sourceMinimum, exportedSourceLocalMaximum: sourceMaximum, assetUpAxis: up,
            sourceTransform: feature.transform, meshLocalTransform: local, meshGlobalTransform: global,
            parentGlobalTransform: parentGlobal, rootGlobalTransform: rootGlobal)
    }

    /// Test-only observation of the unchanged exporter/importer, never a parser
    /// fallback or geometry matcher. It deliberately proceeds to node inventory
    /// after a metadata decode failure, without accepting any of that geometry.
    private nonisolated static func exportInventory(data: Data, fixtureID: String,
        expectedSHA256: String, retainSameExport: Bool = false) -> InventoryCapture {
        typealias Adapter = SavedRoomRouteMeshAdapter
        var result = ExportInventory(fixtureID: fixtureID, sourceSHA256: expectedSHA256)
        var sameExport: SameExportAssets?
        let publicFixtures = [
            "Hallway2": "f4cf3460fd9e746a86fe6538e2b1980e22e18207a2d3c7ea3f7679f58c8c6f4d",
            "Bedroom3": "44df7bd5f4d1961bf13344916384dcfa20d42c7ef8dc58b0e13d1c2f7c6a4d2e"
        ]
        // Assertion alone would continue on mismatch and could export private
        // replacement bytes. This admission guard precedes every decode/export.
        guard publicFixtures[fixtureID] == expectedSHA256,
              !data.isEmpty, data.count <= Adapter.maximumSourceBytes,
              digest(data) == expectedSHA256 else {
            result.inventoryFailure = "sourceMismatch"
            return .init(inventory: result, sameExport: nil)
        }
        guard !Thread.isMainThread else {
            result.inventoryFailure = "wrongExecutionContext"
            return .init(inventory: result, sameExport: nil)
        }
        do { _ = try Adapter.decode(data: data, expectedSHA256: expectedSHA256) }
        catch { result.adapterFailure = failureCode(error) }
        do {
            let raw = try JSONDecoder().decode(RawRoom.self, from: data)
            let knownIDs = Set(raw.all.map(\.identifier))
            func publicID(_ id: UUID?) -> String? {
                guard let id, knownIDs.contains(id) else { return nil }
                return id.uuidString
            }
            let room = try JSONDecoder().decode(CapturedRoom.self, from: data)
            let sourceFeatures = Dictionary(uniqueKeysWithValues: try Adapter.originalFeatures(room).map { ($0.id, $0) })
            let manager = FileManager.default
            var root = manager.temporaryDirectory.appendingPathComponent("BlindPublicAppleMeshInventory-\(UUID().uuidString)", isDirectory: true)
            try manager.createDirectory(at: root, withIntermediateDirectories: false,
                attributes: [.posixPermissions: 0o700, .protectionKey: FileProtectionType.complete])
            defer { try? manager.removeItem(at: root) }
            var resourceValues = URLResourceValues(); resourceValues.isExcludedFromBackup = true
            try root.setResourceValues(resourceValues)
            let meshURL = root.appendingPathComponent("room.usdz")
            let metadataURL = root.appendingPathComponent("metadata.json")
            do { try room.export(to: meshURL, metadataURL: metadataURL, modelProvider: nil, exportOptions: .mesh) }
            catch { throw Adapter.Failure.exportFailed }
            // Retain only the comparison test's exact diagnostic export #2.
            // The ordinary JSON-only inventory test does not read/attach assets.
            let retainedAsset: Data?, retainedMetadata: Data?
            if retainSameExport {
                retainedAsset = try boundedSameExportData(at: meshURL, limit: 4 * 1024 * 1024)
                retainedMetadata = try boundedSameExportData(at: metadataURL, limit: 64 * 1024)
            } else { retainedAsset = nil; retainedMetadata = nil }
            defer {
                if let retainedAsset, let retainedMetadata {
                    do {
                        // This defer runs before the earlier directory-removal
                        // defer, including when the Model I/O diagnostic fails.
                        guard try boundedSameExportData(at: meshURL, limit: 4 * 1024 * 1024) == retainedAsset,
                              try boundedSameExportData(at: metadataURL, limit: 64 * 1024) == retainedMetadata else {
                            throw Adapter.Failure.sourceMismatch
                        }
                        let record = SameExportRecord(fixtureID: fixtureID, sourceSHA256: expectedSHA256,
                            assetAttachmentName: "APPLE_ROOM_ROUTE_\(fixtureID)_SAME_EXPORT.usdz",
                            metadataAttachmentName: "APPLE_ROOM_ROUTE_\(fixtureID)_SAME_EXPORT_METADATA.bin",
                            assetSHA256: digest(retainedAsset), metadataSHA256: digest(retainedMetadata),
                            metadataFormat: result.metadataFormat, assetByteCount: retainedAsset.count,
                            metadataByteCount: retainedMetadata.count)
                        sameExport = .init(record: record, asset: retainedAsset, metadata: retainedMetadata)
                    } catch {
                        sameExport = nil
                        result.inventoryFailure = failureCode(error)
                    }
                }
            }
            var metadata: [String: UUID] = [:]
            do {
                let attributes = try manager.attributesOfItem(atPath: metadataURL.path)
                guard let size = attributes[.size] as? NSNumber, size.int64Value >= 0,
                      size.int64Value <= Int64(Adapter.maximumMetadataBytes) else { throw Adapter.Failure.budgetExceeded }
                let bytes: Data
                if let retainedMetadata { bytes = retainedMetadata }
                else { bytes = try Data(contentsOf: metadataURL) }
                guard bytes.count <= Adapter.maximumMetadataBytes else { throw Adapter.Failure.budgetExceeded }
                result.metadataByteCount = bytes.count
                result.metadataFormat = "unknown"
                if bytes.starts(with: Data("bplist00".utf8)) { result.metadataFormat = "binaryPlist" }
                else if let prefix = String(data: Data(bytes.prefix(256)), encoding: .utf8) {
                    let header = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
                    if header.hasPrefix("<plist ") || header.hasPrefix("<plist>") ||
                        (header.hasPrefix("<?xml ") && header.contains("<plist")) {
                        result.metadataFormat = "xmlPlist"
                    }
                }
                do {
                    let object: Any
                    if result.metadataFormat == "binaryPlist" {
                        object = try PropertyListSerialization.propertyList(from: bytes, options: [], format: nil)
                    } else {
                        object = try JSONSerialization.jsonObject(with: bytes, options: [.fragmentsAllowed])
                        result.metadataFormat = "json"
                    }
                    result.metadataRootKind = jsonKind(object)
                    if let entries = object as? [String: Any] {
                        result.metadataEntryCount = min(entries.count, Adapter.maximumNodes)
                        result.metadataEntriesTruncated = result.metadataEntryCount > 64
                        result.metadataEntries = entries.keys.sorted().prefix(64).map { key in
                            let value = entries[key]!
                            let id = (value as? String).flatMap(UUID.init(uuidString:))
                            return MetadataEntry(key: safeExportName(key), keySHA256: digest(Data(key.utf8)),
                                valueKind: jsonKind(value), uuidValue: id != nil,
                                knownFeature: publicID(id) != nil, uuid: publicID(id))
                        }
                        if entries.count > Adapter.maximumNodes { result.inventoryFailure = "budgetExceeded" }
                    }
                } catch {
                    result.metadataRootKind = result.metadataFormat == "binaryPlist" ? "invalidPropertyList" : "invalidJSON"
                    result.inventoryFailure = "metadataDecodeFailed"
                }
                do { metadata = try Adapter.decodeMetadata(data: bytes) }
                catch { result.inventoryFailure = result.inventoryFailure ?? failureCode(error) }
            } catch {
                result.inventoryFailure = (error as? Adapter.Failure).map { String(describing: $0) } ?? "metadataReadFailed"
            }

            let attributes = try manager.attributesOfItem(atPath: meshURL.path)
            guard let size = attributes[.size] as? NSNumber, size.int64Value > 0,
                  size.int64Value <= Int64(Adapter.maximumExportBytes) else { throw Adapter.Failure.budgetExceeded }
            let descriptor = MDLVertexDescriptor()
            descriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition,
                format: .float3, offset: 0, bufferIndex: 0)
            descriptor.layouts[0] = MDLVertexBufferLayout(stride: 3 * MemoryLayout<Float>.size)
            var importError: NSError?
            let asset = MDLAsset(url: meshURL, vertexDescriptor: descriptor,
                bufferAllocator: nil, preserveTopology: false, error: &importError)
            guard importError == nil, asset.count > 0, asset.count <= Adapter.maximumNodes,
                  asset.startTime == asset.endTime else { throw Adapter.Failure.invalidMesh }
            var visited = Set<ObjectIdentifier>()
            var geometryExaminedVertices = 0
            func visit(_ node: MDLObject, parentIndex: Int?, inheritedID: UUID?, depth: Int,
                       sceneRoot: MDLObject, parent: MDLObject?) throws {
                guard depth <= 64, visited.insert(ObjectIdentifier(node)).inserted else { throw Adapter.Failure.invalidMesh }
                guard result.nodeCount < Adapter.maximumNodes else { throw Adapter.Failure.budgetExceeded }
                let index = result.nodeCount
                result.nodeCount += 1
                result.nodesTruncated = result.nodeCount > 128
                let directID = metadata[node.name], identity = directID ?? inheritedID
                let mesh = node as? MDLMesh
                let isMesh = mesh != nil
                let vertexCount = mesh.map { min($0.vertexCount, Adapter.maximumVertices) }
                let submeshCount = mesh.map { min($0.submeshes?.count ?? 0, Adapter.maximumNodes) }
                if let mesh, mesh.vertexCount > Adapter.maximumVertices || (mesh.submeshes?.count ?? 0) > Adapter.maximumNodes {
                    result.inventoryFailure = result.inventoryFailure ?? "budgetExceeded"
                }
                if isMesh {
                    result.meshCount += 1
                    if identity == nil { result.unmatchedMeshCount += 1 }
                    else if publicID(identity) == nil { result.unknownFeatureMeshCount += 1 }
                }
                if result.adapterFailure == "sourceGeometryMismatch", result.geometryProbe == nil,
                   result.geometryProbeFailure == nil, let mesh, let identity, let feature = sourceFeatures[identity] {
                    do {
                        result.geometryProbe = try sourceBoundsProbe(mesh: mesh, nodeIndex: index, feature: feature,
                            sceneRoot: sceneRoot, parent: parent, asset: asset, examinedVertices: &geometryExaminedVertices)
                    } catch { result.geometryProbeFailure = failureCode(error) }
                }
                if result.nodes.count < 128 {
                    result.nodes.append(ExportNode(index: index, depth: depth, name: safeExportName(node.name),
                        nameSHA256: digest(Data(node.name.utf8)), isMesh: isMesh,
                        directMappingPresent: directID != nil, inheritedMappingPresent: inheritedID != nil,
                        knownFeature: publicID(identity) != nil, parentIndex: parentIndex,
                        directUUID: publicID(directID), inheritedUUID: publicID(inheritedID), resolvedUUID: publicID(identity),
                        vertexCount: vertexCount, submeshCount: submeshCount))
                }
                let children = node.children.objects
                guard children.count <= Adapter.maximumNodes - result.nodeCount else { throw Adapter.Failure.budgetExceeded }
                for child in children {
                    try visit(child, parentIndex: index, inheritedID: identity, depth: depth + 1, sceneRoot: sceneRoot, parent: node)
                }
            }
            for index in 0..<asset.count {
                let root = asset.object(at: index)
                try visit(root, parentIndex: nil, inheritedID: nil, depth: 0, sceneRoot: root, parent: nil)
            }
        } catch { result.inventoryFailure = result.inventoryFailure ?? failureCode(error) }
        return .init(inventory: result, sameExport: sameExport)
    }

    func testOriginalAppleExportMetadataAndNodeInventory() async throws {
        var reports: [ExportInventory] = []
        for fixture in Fixture.allCases {
            let data = try bytes(fixture), fixtureID = fixture.rawValue, expected = fixture.digest
            let capture = await Task.detached(priority: .utility) {
                Self.exportInventory(data: data, fixtureID: fixtureID, expectedSHA256: expected)
            }.value
            reports.append(capture.inventory)
        }
        let data = try JSONEncoder().encode(InventoryAttachment(fixtures: reports))
        guard data.count <= 131_072 else { throw SavedRoomRouteMeshAdapter.Failure.budgetExceeded }
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "APPLE_ROOM_ROUTE_MESH_METADATA_INVENTORY.json"
        attachment.lifetime = .keepAlways
        add(attachment)
        for report in reports {
            XCTAssertNil(report.inventoryFailure, "\(report.fixtureID): inventory must complete without relaxing bounds")
            XCTAssertTrue(["binaryPlist", "json"].contains(report.metadataFormat))
            XCTAssertEqual(report.metadataRootKind, "object")
            XCTAssertGreaterThan(report.metadataEntryCount, 0)
            XCTAssertGreaterThan(report.meshCount, 0)
            XCTAssertEqual(report.unmatchedMeshCount, 0, "Every real mesh must resolve through an exact metadata name or ancestor")
            XCTAssertEqual(report.unknownFeatureMeshCount, 0, "Resolved mesh UUIDs must belong to the unchanged original room")
            XCTAssertNil(report.geometryProbeFailure)
            if report.adapterFailure == "sourceGeometryMismatch" {
                XCTAssertNotNil(report.geometryProbe, "Retain the first public-source bounds violation before proposing a repair")
            }
            XCTAssertNil(report.adapterFailure, "\(report.fixtureID): inspect retained metadata/node inventory; no guessed matching")
        }
    }

    /// Separate allowlisted test so binary attachments cannot widen the existing
    /// JSON-only collector. These are inputs for an independent reader, not proof
    /// that the production adapter or physical route succeeds.
    func testOriginalAppleSameExportForOpenUSDComparison() async throws {
        var captures: [InventoryCapture] = []
        for fixture in Fixture.allCases {
            let data = try bytes(fixture), fixtureID = fixture.rawValue, expected = fixture.digest
            captures.append(await Task.detached(priority: .utility) {
                Self.exportInventory(data: data, fixtureID: fixtureID, expectedSHA256: expected, retainSameExport: true)
            }.value)
        }
        let reports = captures.map(\.inventory)
        let inventoryData = try JSONEncoder().encode(InventoryAttachment(fixtures: reports))
        guard inventoryData.count <= 131_072 else { throw SavedRoomRouteMeshAdapter.Failure.budgetExceeded }
        let inventory = XCTAttachment(data: inventoryData, uniformTypeIdentifier: "public.json")
        inventory.name = "APPLE_ROOM_ROUTE_MESH_METADATA_INVENTORY.json"; inventory.lifetime = .keepAlways
        add(inventory)
        let exports = captures.compactMap(\.sameExport)
        guard exports.count == Fixture.allCases.count else {
            XCTFail("Both exact original public exports must be retained within the comparison caps")
            return
        }
        let manifestData = try JSONEncoder().encode(SameExportManifest(inventorySHA256: Self.digest(inventoryData),
            fixtures: exports.map(\.record)))
        guard manifestData.count <= 16_384 else { throw SavedRoomRouteMeshAdapter.Failure.budgetExceeded }
        let manifest = XCTAttachment(data: manifestData, uniformTypeIdentifier: "public.json")
        manifest.name = "APPLE_ROOM_ROUTE_SAME_EXPORT_MANIFEST.json"; manifest.lifetime = .keepAlways
        add(manifest)
        for export in exports {
            let asset = XCTAttachment(data: export.asset, uniformTypeIdentifier: "public.data")
            asset.name = export.record.assetAttachmentName; asset.lifetime = .keepAlways; add(asset)
            let metadata = XCTAttachment(data: export.metadata, uniformTypeIdentifier: "public.data")
            metadata.name = export.record.metadataAttachmentName; metadata.lifetime = .keepAlways; add(metadata)
        }
        for report in reports {
            XCTAssertNil(report.inventoryFailure)
            XCTAssertNil(report.geometryProbeFailure)
            XCTAssertEqual(report.unmatchedMeshCount, 0)
            XCTAssertEqual(report.unknownFeatureMeshCount, 0)
            if report.adapterFailure == "sourceGeometryMismatch" { XCTAssertNotNil(report.geometryProbe) }
            // Adapter failure is retained in the bound inventory, not converted
            // into success by this asset-capture test's pass/fail result.
        }
    }

    func testMetadataInventoryRejectsChangedPublicFixtureBeforeExport() async throws {
        var changed = try bytes(.bedroom)
        changed.append(0x0a) // Still valid JSON, but no longer the admitted original.
        let data = changed, expected = Fixture.bedroom.digest
        let capture = await Task.detached(priority: .utility) {
            Self.exportInventory(data: data, fixtureID: "Bedroom3", expectedSHA256: expected, retainSameExport: true)
        }.value
        let report = capture.inventory
        XCTAssertEqual(report.inventoryFailure, "sourceMismatch")
        XCTAssertNil(report.adapterFailure)
        XCTAssertEqual(report.metadataByteCount, 0)
        XCTAssertEqual(report.metadataFormat, "unread")
        XCTAssertEqual(report.metadataRootKind, "unread")
        XCTAssertTrue(report.metadataEntries.isEmpty)
        XCTAssertEqual(report.nodeCount, 0)
        XCTAssertTrue(report.nodes.isEmpty)
        XCTAssertNil(report.geometryProbe)
        XCTAssertNil(report.geometryProbeFailure)
        XCTAssertNil(capture.sameExport)
    }

    func testSameExportReadRejectsEmptyOversizeAndNonRegularFiles() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("BlindSameExportReadTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("bounded.bin")
        let exact = Data([1, 2, 3, 4])
        try exact.write(to: url)
        XCTAssertEqual(try Self.boundedSameExportData(at: url, limit: 4), exact)
        for value in [Data(), Data([1, 2, 3, 4, 5])] {
            try value.write(to: url)
            XCTAssertThrowsError(try Self.boundedSameExportData(at: url, limit: 4)) {
                XCTAssertEqual($0 as? SavedRoomRouteMeshAdapter.Failure, .budgetExceeded)
            }
        }
        XCTAssertThrowsError(try Self.boundedSameExportData(at: root, limit: 4)) {
            XCTAssertEqual($0 as? SavedRoomRouteMeshAdapter.Failure, .budgetExceeded)
        }
    }

    func testSourceBoundsProbeRetainsZeroDepthAndExactRoundoffPredicate() throws {
        let feature = SavedRoomRouteMeshSnapshot.Feature(id: UUID(), kind: .wall, parentID: nil, category: "wall",
            transform: [1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1], dimensions: [2,2,0], polygonCorners: [], capturedDoorOpen: nil)
        let onPlane = try SavedRoomRouteMeshAdapter.sourceBoundsAssessment([0,0,0], feature: feature)
        XCTAssertNil(onPlane.firstViolationAxis)
        XCTAssertEqual(onPlane.minimum, [-1,-1,0]); XCTAssertEqual(onPlane.maximum, [1,1,0])
        let boundary = try SavedRoomRouteMeshAdapter.sourceBoundsAssessment([0,0,onPlane.epsilon], feature: feature)
        XCTAssertNil(boundary.firstViolationAxis)
        let outside = try SavedRoomRouteMeshAdapter.sourceBoundsAssessment([0,0,onPlane.epsilon.nextUp], feature: feature)
        XCTAssertEqual(outside.firstViolationAxis, 2)
        for depth in [-0.05, 0.05] {
            let thickness = try SavedRoomRouteMeshAdapter.sourceBoundsAssessment([0,0,depth], feature: feature)
            XCTAssertEqual(thickness.firstViolationAxis, 2, "The diagnostic must not silently approve exporter thickness")
            XCTAssertEqual(thickness.localPoint[2], depth)
            XCTAssertEqual(thickness.epsilon, onPlane.epsilon)
        }
        let multiple = try SavedRoomRouteMeshAdapter.sourceBoundsAssessment([2,2,0.05], feature: feature)
        XCTAssertEqual(multiple.firstViolationAxis, 0, "Retain production's first-axis ordering")
    }

    func testFlatMetadataDecoderPreservesPublicUUIDsForBinaryPlistAndJSON() throws {
        for fixture in Fixture.allCases {
            let raw = try JSONDecoder().decode(RawRoom.self, from: bytes(fixture))
            // Synthetic serialization of public fixture UUIDs tests decoding,
            // not actual exporter node association (the inventory tests that).
            let expected = Dictionary(uniqueKeysWithValues: raw.all.enumerated().map {
                ("PublicFeature_\($0.offset)", $0.element.identifier)
            })
            let encoder = PropertyListEncoder(); encoder.outputFormat = .binary
            let binary = try encoder.encode(expected)
            XCTAssertTrue(binary.starts(with: Data("bplist00".utf8)))
            XCTAssertEqual(try SavedRoomRouteMeshAdapter.decodeMetadata(data: binary), expected)
            let json = Data(" \n\t\r".utf8) + (try JSONEncoder().encode(expected))
            XCTAssertEqual(try SavedRoomRouteMeshAdapter.decodeMetadata(data: json), expected)
        }
    }

    func testFlatMetadataDecoderRejectsMalformedWrongShapeAndUnsupportedFormats() throws {
        typealias Adapter = SavedRoomRouteMeshAdapter
        let id = "00000000-0000-0000-0000-000000000001"
        func binary(_ value: Any) throws -> Data {
            try PropertyListSerialization.data(fromPropertyList: value, format: .binary, options: 0)
        }
        func rejects(_ data: Data, _ expected: Adapter.Failure, line: UInt = #line) {
            XCTAssertThrowsError(try Adapter.decodeMetadata(data: data), line: line) {
                XCTAssertEqual($0 as? Adapter.Failure, expected, line: line)
            }
        }
        rejects(Data(), .metadataEmpty)
        rejects(Data("bplist00".utf8), .metadataDecodeFailed)
        rejects(Data("not a metadata file".utf8), .metadataDecodeFailed)
        rejects(try binary([id]), .metadataDecodeFailed)
        rejects(try binary(["Floor0": ["identifier": id]]), .metadataDecodeFailed)
        rejects(try binary(["Floor0": "not-a-uuid"]), .metadataDecodeFailed)
        rejects(try binary(["Floor0": 1]), .metadataDecodeFailed)
        rejects(try binary([:] as [String: String]), .metadataEmpty)
        rejects(try binary(["": id]), .metadataInvalidEntries)
        rejects(try binary([String(repeating: "é", count: 257): id]), .metadataInvalidEntries)
        let xml = try PropertyListSerialization.data(fromPropertyList: ["Floor0": id], format: .xml, options: 0)
        rejects(xml, .metadataDecodeFailed) // Not observed/accepted by this narrow repair.
        rejects(Data("[]".utf8), .metadataDecodeFailed)
        rejects(Data("{\"Floor0\":{\"identifier\":\"\(id)\"}}".utf8), .metadataDecodeFailed)
        rejects(Data("{\"Floor0\":\"not-a-uuid\"}".utf8), .metadataDecodeFailed)
        rejects(Data("{}".utf8), .metadataEmpty)
        rejects(Data(repeating: 0, count: Adapter.maximumMetadataBytes + 1), .budgetExceeded)
        let tooMany = Dictionary(uniqueKeysWithValues: (0...Adapter.maximumNodes).map { ("Node\($0)", id) })
        rejects(try binary(tooMany), .metadataInvalidEntries)
        let boundaryName = String(repeating: "é", count: 256) // Exactly 512 UTF-8 bytes.
        XCTAssertEqual(try Adapter.decodeMetadata(data: binary([boundaryName: id])), [boundaryName: UUID(uuidString: id)!])
    }

    func testOriginalAppleExportInventoryPreservesFeatureIdentityAndHistoricalDoorState() async throws {
        for fixture in Fixture.allCases {
            let (mesh, raw) = try await snapshot(fixture)
            XCTAssertEqual(mesh.sourceSHA256, fixture.digest)
            XCTAssertEqual(Set(mesh.features.map(\.id)), Set(raw.all.map(\.identifier)))
            XCTAssertEqual(mesh.floorSupport.count * 3, mesh.triangles.count)
            XCTAssertEqual(mesh.triangleFeatureIDs.count, mesh.floorSupport.count)
            XCTAssertFalse(mesh.physicalAuthority)
            XCTAssertFalse(mesh.currentDoorStateKnown)
            XCTAssertFalse(mesh.actualWorldCoverageKnown)
            XCTAssertFalse(mesh.vertices.isEmpty)
            XCTAssertGreaterThan(mesh.upwardFloorTriangles, 0, "Export must provide upward floor support; no silent winding repair")
            let floorIDs = Set(raw.floors.map(\.identifier))
            for index in mesh.floorSupport.indices {
                XCTAssertEqual(mesh.floorSupport[index], floorIDs.contains(mesh.triangleFeatureIDs[index]))
            }
            let originals = Dictionary(uniqueKeysWithValues: raw.all.map { ($0.identifier, $0) })
            for feature in mesh.features {
                let source = try XCTUnwrap(originals[feature.id])
                XCTAssertEqual(feature.parentID, source.parentIdentifier)
                XCTAssertEqual(feature.transform.count, 16)
                for (actual, expected) in zip(feature.transform, source.transform) {
                    XCTAssertEqual(actual, expected, accuracy: Double(Float.ulpOfOne) * max(1, abs(expected)))
                }
                for (actual, expected) in zip(feature.dimensions, source.dimensions) {
                    XCTAssertEqual(actual, expected, accuracy: Double(Float.ulpOfOne) * max(1, abs(expected)))
                }
                XCTAssertEqual(feature.polygonCorners.count,source.polygonCorners?.count ?? 0)
                for (actual,expected) in zip(feature.polygonCorners,source.polygonCorners ?? []) {
                    XCTAssertEqual(actual.count,expected.count)
                    for (component,original) in zip(actual,expected) {
                        XCTAssertEqual(component,original,accuracy:Double(Float.ulpOfOne)*max(1,abs(original)))
                    }
                }
                XCTAssertEqual(feature.capturedDoorOpen, source.category["door"]?.isOpen)
                if feature.kind == .door, feature.capturedDoorOpen == false {
                    XCTAssertTrue(mesh.exportedFeatureIDs.contains(feature.id), "Closed captured door needs actual blocking geometry")
                }
            }
            XCTAssertEqual(raw.doors.filter { $0.category["door"]?.isOpen == false }.count, fixture == .hallway ? 4 : 2)
            XCTAssertEqual(raw.doors.filter { $0.category["door"]?.isOpen == true }.count, fixture == .hallway ? 2 : 0)
            if fixture == .bedroom {
                XCTAssertEqual(Set(mesh.features.filter { $0.kind == .furniture }.map(\.category)), ["bed", "table", "chair"])
                for object in raw.objects {
                    let indices = mesh.triangleFeatureIDs.indices.filter { mesh.triangleFeatureIDs[$0] == object.identifier }
                    XCTAssertFalse(indices.isEmpty)
                    XCTAssertTrue(indices.allSatisfy { !mesh.floorSupport[$0] }, "Furniture top faces never become original floor")
                }
            }
        }
    }

    func testRealFloorTriangulationPreservesOriginalConcavityAreaAndWorldCorners() async throws {
        for fixture in Fixture.allCases {
            let (mesh, raw) = try await snapshot(fixture)
            let floor = try XCTUnwrap(raw.floors.first), polygon = try XCTUnwrap(floor.polygonCorners)
            XCTAssertEqual(polygon.count, fixture == .hallway ? 8 : 4)
            let indices = mesh.triangleFeatureIDs.indices.filter { mesh.triangleFeatureIDs[$0] == floor.identifier }
            var area = 0.0
            for index in indices {
                let points = triangle(mesh, index)
                if simd_cross(points[1] - points[0], points[2] - points[0]).y <= 0 { continue }
                let local = points.map { localXY($0, floor) }
                area += abs(cross(local[1] - local[0], local[2] - local[0])) / 2
            }
            let sourceArea = abs(polygon.indices.reduce(0.0) { total, i in
                let j = (i + 1) % polygon.count
                return total + polygon[i][0] * polygon[j][1] - polygon[j][0] * polygon[i][1]
            }) / 2
            XCTAssertEqual(area, sourceArea, accuracy: 64 * Double(Float.ulpOfOne) * max(1, sourceArea),
                "Upward floor triangles must cover exactly the original polygon, not its bounding rectangle")
            let exportedBoundary = try boundary(mesh,indices:indices)
            XCTAssertFalse(exportedBoundary.isEmpty)
            let originalPoints = polygon.map { world($0,floor) }
            let originalBoundary = polygon.indices.map { BoundaryEdge(a:originalPoints[$0],b:originalPoints[($0+1)%polygon.count]) }
            // Both directions matter: original corners/edges cannot disappear,
            // and an invented edge or unsupported hole cannot appear. Midpoints
            // plus endpoints cover any collinear edge subdivisions in this input.
            for (source,target) in [(originalBoundary,exportedBoundary),(exportedBoundary,originalBoundary)] {
                for edge in source {
                    for expected in [edge.a,(edge.a+edge.b)/2,edge.b] {
                        let nearest = target.map { distance(expected,edge:$0) }.min() ?? .infinity
                        let scale = max(1,max(abs(expected.x),max(abs(expected.y),abs(expected.z))))
                        XCTAssertLessThanOrEqual(nearest,64*Double(Float.ulpOfOne)*scale,
                            "Original floor boundary must be preserved; collinear tessellation vertices need not be identical")
                    }
                }
            }
            if fixture == .hallway {
                // Fixed original-source witness: within floor bounds but outside
                // its concave upper indentation. Never move this after results.
                let unsupported = SIMD2<Double>(0, 0.5)
                XCTAssertFalse(indices.contains { index in
                    contains(unsupported, triangle: triangle(mesh, index).map { localXY($0, floor) })
                }, "Concave missing floor must not be filled by a rectangle or naive fan")
            }
        }
    }

    func testAppleWallMeshHasRealDoorAndWindowCutoutsWithClosedDoorBarrierSeparate() async throws {
        for fixture in Fixture.allCases {
            let (mesh, raw) = try await snapshot(fixture)
            for opening in raw.doors + raw.windows + raw.openings {
                let parentID = try XCTUnwrap(opening.parentIdentifier)
                let wall = try XCTUnwrap(raw.walls.first { $0.identifier == parentID })
                let center = world([0, 0, 0], opening)
                let wallPoint = localXY(center, wall)
                let wallTriangles = mesh.triangleFeatureIDs.indices.filter { mesh.triangleFeatureIDs[$0] == parentID }
                XCTAssertFalse(wallTriangles.isEmpty)
                XCTAssertFalse(wallTriangles.contains { index in
                    contains(wallPoint, triangle: triangle(mesh, index).map { localXY($0, wall) })
                }, "Whole-wall quads must not conceal the actual Apple cutout")
                if opening.category["door"]?.isOpen == false {
                    let leafTriangles = mesh.triangleFeatureIDs.indices.filter { mesh.triangleFeatureIDs[$0] == opening.identifier }
                    XCTAssertFalse(leafTriangles.isEmpty)
                    XCTAssertTrue(leafTriangles.contains { index in
                        contains(SIMD2<Double>(0, 0), triangle: triangle(mesh, index).map { localXY($0, opening) })
                    }, "Wall cutout is separate from the original closed-door obstacle")
                }
            }
        }
    }

    func testWrongOriginalRoomDigestFailsBeforeExport() async throws {
        let data = try bytes(.bedroom), wrong = Fixture.hallway.digest
        let result = await Task.detached(priority: .utility) { () -> SavedRoomRouteMeshAdapter.Failure? in
            do { _ = try SavedRoomRouteMeshAdapter.decode(data: data, expectedSHA256: wrong); return nil }
            catch { return error as? SavedRoomRouteMeshAdapter.Failure }
        }.value
        XCTAssertEqual(result, .sourceMismatch)
    }
}

