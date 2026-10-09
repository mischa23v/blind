import ARKit
import BlindCore

enum DepthSampler {
    static func unavailableReason(from frame: ARFrame) -> MonitoringReason {
        guard case .normal = frame.camera.trackingState else { return .trackingUnavailable }
        let forward = -frame.camera.transform.columns.2
        if hypot(forward.x, forward.z) <= 0.25 { return .cameraOrientation }
        return .depthUnavailable
    }
    /// World position of the surface at a point of the upright (portrait, .right) camera image,
    /// measured by LiDAR: median of confident depths in a small window. Nil when not measured.
    static func worldPoint(from frame: ARFrame, uprightX: Double, uprightY: Double) -> Point3? {
        guard let depth = frame.sceneDepth, let confidence = depth.confidenceMap,
              (0...1).contains(uprightX), (0...1).contains(uprightY) else { return nil }
        let buffer = depth.depthMap
        guard CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_DepthFloat32,
              CVPixelBufferLockBaseAddress(buffer, .readOnly) == kCVReturnSuccess else { return nil }
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard CVPixelBufferLockBaseAddress(confidence, .readOnly) == kCVReturnSuccess else { return nil }
        defer { CVPixelBufferUnlockBaseAddress(confidence, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer), let confidenceBase = CVPixelBufferGetBaseAddress(confidence) else { return nil }
        let width = CVPixelBufferGetWidth(buffer), height = CVPixelBufferGetHeight(buffer)
        // Portrait (.right) to sensor: sensor x follows upright top→bottom, sensor y follows upright right→left.
        let column = Int((uprightY * Double(width - 1)).rounded()), row = Int(((1 - uprightX) * Double(height - 1)).rounded())
        var values: [Double] = []
        for r in max(0, row - 2)...min(height - 1, row + 2) {
            let depths = base.advanced(by: r * CVPixelBufferGetBytesPerRow(buffer)).assumingMemoryBound(to: Float.self)
            let confidences = confidenceBase.advanced(by: r * CVPixelBufferGetBytesPerRow(confidence)).assumingMemoryBound(to: UInt8.self)
            for c in max(0, column - 2)...min(width - 1, column + 2) where confidences[c] >= 1 {
                let value = Double(depths[c]); if (0.15...8).contains(value) { values.append(value) }
            }
        }
        guard values.count >= 5 else { return nil }
        let median = values.sorted()[values.count / 2]
        let size = frame.camera.imageResolution, intrinsics = frame.camera.intrinsics
        let sx = Double(width) / size.width, sy = Double(height) / size.height
        let projection = DepthProjection(fx: Double(intrinsics.columns.0.x) * sx, fy: Double(intrinsics.columns.1.y) * sy,
                                         cx: Double(intrinsics.columns.2.x) * sx, cy: Double(intrinsics.columns.2.y) * sy)
        guard let camera = projection.cameraPoint(column: Double(column), row: Double(row), depth: median) else { return nil }
        let world = frame.camera.transform * SIMD4<Float>(Float(camera.x), Float(camera.y), Float(camera.z), 1)
        let point = Point3(Double(world.x), Double(world.y), Double(world.z))
        return point.isFinite ? point : nil
    }
    static func observation(from frame: ARFrame) -> Observation? {
        guard let depth = frame.sceneDepth, let confidence = depth.confidenceMap else { return nil }
        let buffer = depth.depthMap
        guard CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_DepthFloat32,
              CVPixelBufferGetPixelFormatType(confidence) == kCVPixelFormatType_OneComponent8 else { return nil }
        let width = CVPixelBufferGetWidth(buffer), height = CVPixelBufferGetHeight(buffer)
        guard width == CVPixelBufferGetWidth(confidence), height == CVPixelBufferGetHeight(confidence),
              CVPixelBufferLockBaseAddress(buffer, .readOnly) == kCVReturnSuccess else { return nil }
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard CVPixelBufferLockBaseAddress(confidence, .readOnly) == kCVReturnSuccess else { return nil }
        defer { CVPixelBufferUnlockBaseAddress(confidence, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer), let confidenceBase = CVPixelBufferGetBaseAddress(confidence) else { return nil }
        let size = frame.camera.imageResolution
        let intrinsics = frame.camera.intrinsics
        let sx = Double(width) / size.width, sy = Double(height) / size.height
        let projection = DepthProjection(fx: Double(intrinsics.columns.0.x) * sx,
                                         fy: Double(intrinsics.columns.1.y) * sy,
                                         cx: Double(intrinsics.columns.2.x) * sx,
                                         cy: Double(intrinsics.columns.2.y) * sy)
        let transform = frame.camera.transform
        let opticalForward = -transform.columns.2
        let horizontalLength = hypot(opticalForward.x, opticalForward.z)
        guard horizontalLength > 0.25 else { return nil }
        let origin = transform.columns.3
        let forward = Point3(Double(opticalForward.x / horizontalLength), 0, Double(opticalForward.z / horizontalLength))
        // Four times the previous sample density, retaining confidence checks.
        // Device latency/thermal measurements are still required at 15 Hz.
        var samples: [DepthSample] = []; samples.reserveCapacity(width * height / 4)
        for row in stride(from: 0, to: height, by: 2) {
            let depths = base.advanced(by: row * CVPixelBufferGetBytesPerRow(buffer)).assumingMemoryBound(to: Float.self)
            let confidences = confidenceBase.advanced(by: row * CVPixelBufferGetBytesPerRow(confidence)).assumingMemoryBound(to: UInt8.self)
            for column in stride(from: 0, to: width, by: 2) {
                let value = Double(depths[column])
                guard confidences[column] == 2, (0.15...5).contains(value),
                      let camera = projection.cameraPoint(column: Double(column), row: Double(row), depth: value) else { continue }
                let world = transform * SIMD4<Float>(Float(camera.x), Float(camera.y), Float(camera.z), 1)
                samples.append(DepthSample(Point3(Double(world.x), Double(world.y), Double(world.z))))
            }
        }
        let normal: Bool
        if case .normal = frame.camera.trackingState { normal = true } else { normal = false }
        return Observation(timestamp: frame.timestamp, camera: Point3(Double(origin.x), Double(origin.y), Double(origin.z)),
                           forward: forward, samples: samples, trackingNormal: normal)
    }
}
