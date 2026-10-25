import ARKit
import BlindCore
import Foundation
import Metal

/// Extraction only. Reuses ARKit's actual pose/depth/anchors, never requests a second capture.
/// Call on the utility observation queue, not the hazard/main callback. No camera image is copied.
enum NativeARObservationAdapter {
    /// Default-on only for supported hardware within the app's existing permitted foreground
    /// camera session. No new camera/session or UI is created. Device cost remains unmeasured.
    static func configureObservedGeometry(_ configuration: ARWorldTrackingConfiguration) {
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            configuration.sceneReconstruction = .meshWithClassification
        } else if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
        }
        // Unsupported devices retain absent mesh/classification rather than synthetic geometry.
    }
    struct Context: Sendable {
        let sessionID: UUID
        let frameID: String
        let mapTarget: SpatialMapBinding?
        let receivedAt: Double
        let receivedDate: Date
    }
    static func transform(_ matrix: simd_float4x4) -> NativeCameraTransform {
        NativeCameraTransform(columns: (0..<4).flatMap { column in (0..<4).map { row in Double(matrix[column][row]) } })
    }
    static func capture(_ frame: ARFrame, context: Context) throws -> NativeObservationRecord {
        let tracking: NativeObservationRecord.Tracking
        let reason: String?
        switch frame.camera.trackingState {
        case .normal: tracking = .normal; reason = nil
        case .notAvailable: tracking = .unavailable; reason = nil
        case .limited(let limitation): tracking = .limited; reason = String(describing: limitation)
        }
        let k = frame.camera.intrinsics, size = frame.camera.imageResolution
        var omitted: [String] = []
        let depth: NativeDepthObservation?
        do { depth = try frame.sceneDepth.map { try sampleDepth($0) } }
        catch { depth = nil; omitted.append("sceneDepthUnreadable") }
        if frame.sceneDepth == nil { omitted.append("sceneDepthNotDelivered") }
        if depth?.confidenceAvailable == false { omitted.append("depthConfidenceUnavailable") }
        // Cap inspection before filtering/sorting: a large world-map anchor list must not
        // create unbounded observation work. Unexamined surface count remains unknown.
        let anchorSnapshot = frame.anchors
        let inspectionTruncated = anchorSnapshot.count > 128
        let anchors = anchorSnapshot.prefix(128).filter { $0 is ARPlaneAnchor || $0 is ARMeshAnchor }
            .sorted { $0.identifier.uuidString < $1.identifier.uuidString }
        if inspectionTruncated { omitted.append("anchorInspectionBudgetTruncated") }
        var surfaces: [NativeSurfaceObservation] = []
        var remainingVertices = 2048
        for anchor in anchors.prefix(32) {
            guard remainingVertices > 0 else { omitted.append("surfaceVertexBudgetTruncated"); break }
            let before = surfaces.count
            if let plane = anchor as? ARPlaneAnchor {
                if let sample = try? samplePlane(plane, maximumVertices: remainingVertices), (try? sample.validate()) != nil { surfaces.append(sample) }
                else if !omitted.contains("planeGeometryUnreadable") { omitted.append("planeGeometryUnreadable") }
            }
            else if let mesh = anchor as? ARMeshAnchor {
                if let sample = try? sampleMesh(mesh, maximumVertices: remainingVertices) {
                    surfaces.append(sample)
                    if mesh.geometry.classification != nil, sample.triangleClassifications == nil,
                       !omitted.contains("meshClassificationUnreadable") { omitted.append("meshClassificationUnreadable") }
                }
                else if !omitted.contains("meshGeometryUnreadable") { omitted.append("meshGeometryUnreadable") }
            }
            if surfaces.count > before { remainingVertices -= surfaces.last!.vertices.count }
        }
        if anchors.count > 32 { omitted.append("surfaceBudgetTruncated") }
        if !anchors.contains(where: { $0 is ARMeshAnchor }) { omitted.append(inspectionTruncated ? "meshOutsideInspectedAnchorsUnknown" : "meshNotDelivered") }
        if !anchors.contains(where: { $0 is ARPlaneAnchor }) { omitted.append(inspectionTruncated ? "planesOutsideInspectedAnchorsUnknown" : "planesNotDelivered") }
        let record = NativeObservationRecord(sessionID: context.sessionID, coordinateFrameID: context.frameID,
            producer: .arkit, sourceID: "ARFrame:\(context.sessionID.uuidString):\(frame.timestamp)", mapTarget: context.mapTarget,
            capturedAt: frame.timestamp, receivedAt: context.receivedAt,
            observedAt: context.receivedDate.addingTimeInterval(frame.timestamp - context.receivedAt), tracking: tracking,
            trackingReason: reason, cameraConvention: .arKitRightUpBack, cameraToSessionWorld: transform(frame.camera.transform),
            intrinsics: NativeCameraIntrinsics(width: Int(size.width), height: Int(size.height),
                fx: Double(k.columns.0.x), fy: Double(k.columns.1.y), cx: Double(k.columns.2.x), cy: Double(k.columns.2.y)),
            depth: depth, surfaces: surfaces, originalSurfaceCount: inspectionTruncated ? nil : anchors.count, omitted: omitted)
        try record.validate()
        return record
    }
    private static func sampleDepth(_ depth: ARDepthData) throws -> NativeDepthObservation {
        let buffer = depth.depthMap
        let width = CVPixelBufferGetWidth(buffer), height = CVPixelBufferGetHeight(buffer)
        guard width > 0, height > 0, width <= 16384, height <= 16384,
              CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_DepthFloat32,
              CVPixelBufferGetBytesPerRow(buffer) >= width * MemoryLayout<Float>.size,
              CVPixelBufferGetBytesPerRow(buffer) <= 131072,
              CVPixelBufferGetDataSize(buffer) >= CVPixelBufferGetBytesPerRow(buffer) * height,
              CVPixelBufferLockBaseAddress(buffer, .readOnly) == kCVReturnSuccess else { throw NativeObservationError.invalidDepth }
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { throw NativeObservationError.invalidDepth }
        var confidence: CVPixelBuffer?
        var confidenceBase: UnsafeMutableRawPointer?
        if let proposed = depth.confidenceMap,
           CVPixelBufferGetPixelFormatType(proposed) == kCVPixelFormatType_OneComponent8,
           CVPixelBufferGetWidth(proposed) == width, CVPixelBufferGetHeight(proposed) == height,
           CVPixelBufferGetBytesPerRow(proposed) >= width, CVPixelBufferGetBytesPerRow(proposed) <= 131072,
           CVPixelBufferGetDataSize(proposed) >= CVPixelBufferGetBytesPerRow(proposed) * height,
           CVPixelBufferLockBaseAddress(proposed, .readOnly) == kCVReturnSuccess {
            confidence = proposed; confidenceBase = CVPixelBufferGetBaseAddress(proposed)
        }
        defer { if let confidence { CVPixelBufferUnlockBaseAddress(confidence, .readOnly) } }
        // Bounded sparse retained geometry. Existing full-rate hazard sampling stays unchanged.
        var step = 8
        while ((width + step - 1) / step) * ((height + step - 1) / step) > 1024 { step += 1 }
        var pixels: [NativeDepthPixel] = []; var sampled = 0; var invalid = 0
        for row in stride(from: 0, to: height, by: step) {
            let values = base.advanced(by: row * CVPixelBufferGetBytesPerRow(buffer)).assumingMemoryBound(to: Float.self)
            let levels = confidenceBase.map { $0.advanced(by: row * CVPixelBufferGetBytesPerRow(confidence!)).assumingMemoryBound(to: UInt8.self) }
            for column in stride(from: 0, to: width, by: step) {
                sampled += 1
                let metres = Double(values[column]), level = levels.map { $0[column] }
                guard metres.isFinite, metres > 0, metres <= 100, level.map({ $0 <= 2 }) ?? true else { invalid += 1; continue }
                pixels.append(NativeDepthPixel(column: column, row: row, metres: metres, confidence: level))
            }
        }
        return NativeDepthObservation(source: .arkitSceneDepth, width: width, height: height, samplingStride: step,
            sampledPixelCount: sampled, invalidPixelCount: invalid, confidenceAvailable: confidenceBase != nil, pixels: pixels)
    }
    private static func samplePlane(_ anchor: ARPlaneAnchor, maximumVertices: Int) throws -> NativeSurfaceObservation {
        let boundary = anchor.geometry.boundaryVertices
        let count = boundary.count
        guard (0...1_000_000).contains(count) else { throw NativeObservationError.invalidSurface }
        let vertices = (0..<min(count, maximumVertices)).map { index -> Point3 in
            let p = boundary[index]; return Point3(Double(p.x), Double(p.y), Double(p.z))
        }
        // A horizontal/floor-classified plane is observed support candidate geometry only.
        // It has no durable floor identity, contact height, body calibration or coverage proof.
        return NativeSurfaceObservation(sourceID: anchor.identifier.uuidString, kind: .arkitPlane,
            localToSessionWorld: transform(anchor.transform), vertices: vertices,
            classification: String(describing: anchor.classification), horizontal: anchor.alignment == .horizontal,
            originalVertexCount: count, truncated: count > vertices.count)
    }
    private static func sampleMesh(_ anchor: ARMeshAnchor, maximumVertices: Int) throws -> NativeSurfaceObservation {
        let geometry = anchor.geometry, source = geometry.vertices, faces = geometry.faces
        guard source.format == .float3, source.componentsPerVector == 3,
              source.offset >= 0, source.offset <= source.buffer.length, (12...4096).contains(source.stride), (0...16_000_000).contains(source.count),
              faces.indexCountPerPrimitive == 3, faces.bytesPerIndex == 2 || faces.bytesPerIndex == 4,
              source.count == 0 || source.offset + (source.count - 1) * source.stride + 12 <= source.buffer.length,
              (0...16_000_000).contains(faces.count), faces.count * 3 * faces.bytesPerIndex <= faces.buffer.length else { throw NativeObservationError.invalidSurface }
        var vertices: [Point3] = [], indices: [Int] = [], remap: [Int: Int] = [:]
        // Classification is a documented ARGeometrySource, not the sample-only
        // classificationOf(faceWithIndex:) extension. Honor its own offset/stride/count.
        let classification: ARGeometrySource?
        if let source = geometry.classification, source.format == .uchar, source.componentsPerVector == 1,
           source.count == faces.count, (0...16_000_000).contains(source.count),
           source.offset >= 0, source.offset <= source.buffer.length, (1...4096).contains(source.stride),
           source.count == 0 || source.offset + (source.count - 1) * source.stride + 1 <= source.buffer.length {
            classification = source
        } else { classification = nil }
        var classes: [String]? = classification == nil ? nil : []
        for face in 0..<min(faces.count, min(512, maximumVertices / 3)) {
            var triangle: [Int] = []
            for corner in 0..<3 {
                let indexPointer = faces.buffer.contents().advanced(by: (face * 3 + corner) * faces.bytesPerIndex)
                let index = faces.bytesPerIndex == 2 ? Int(indexPointer.loadUnaligned(as: UInt16.self)) : Int(indexPointer.loadUnaligned(as: UInt32.self))
                guard (0..<source.count).contains(index) else { throw NativeObservationError.invalidSurface }
                if let mapped = remap[index] { triangle.append(mapped); continue }
                let pointer = source.buffer.contents().advanced(by: source.offset + index * source.stride)
                let p = Point3(Double(pointer.loadUnaligned(as: Float.self)),
                    Double(pointer.advanced(by: 4).loadUnaligned(as: Float.self)), Double(pointer.advanced(by: 8).loadUnaligned(as: Float.self)))
                guard p.isFinite else { throw NativeObservationError.invalidSurface }
                remap[index] = vertices.count; triangle.append(vertices.count); vertices.append(p)
            }
            indices.append(contentsOf: triangle)
            if let classification {
                let address = classification.buffer.contents().advanced(by: classification.offset + face * classification.stride)
                let raw = Int(address.load(as: UInt8.self))
                classes?.append(ARMeshClassification(rawValue: raw).map { String(describing: $0) } ?? "unknown(raw:\(raw))")
            }
        }
        return NativeSurfaceObservation(sourceID: anchor.identifier.uuidString, kind: .arkitMesh,
            localToSessionWorld: transform(anchor.transform), vertices: vertices, triangleIndices: indices, triangleClassifications: classes,
            originalVertexCount: source.count, originalTriangleCount: faces.count,
            truncated: vertices.count != source.count || indices.count / 3 != faces.count)
    }
}
