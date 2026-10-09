import ARKit
import BlindCore

enum DepthSampler {
    static func unavailableReason(from frame: ARFrame) -> MonitoringReason {
        guard case .normal = frame.camera.trackingState else { return .trackingUnavailable }
        let forward = -frame.camera.transform.columns.2
        if hypot(forward.x, forward.z) <= 0.25 { return .cameraOrientation }
        return .depthUnavailable
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
