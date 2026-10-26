import Foundation

public struct Point3: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var z: Double
    public init(_ x: Double, _ y: Double, _ z: Double) { self.x = x; self.y = y; self.z = z }
    public var isFinite: Bool { x.isFinite && y.isFinite && z.isFinite }
    public func distance(to other: Point3) -> Double {
        sqrt(pow(x - other.x, 2) + pow(y - other.y, 2) + pow(z - other.z, 2))
    }
}

/// Optical image coordinates have Y down and Z forward; ARKit camera coordinates
/// have Y up and look along -Z. Intrinsics must be scaled to depth resolution.
public struct DepthProjection: Sendable {
    public var fx, fy, cx, cy: Double
    public init(fx: Double, fy: Double, cx: Double, cy: Double) {
        self.fx = fx; self.fy = fy; self.cx = cx; self.cy = cy
    }
    public func cameraPoint(column: Double, row: Double, depth: Double) -> Point3? {
        guard depth.isFinite, depth > 0, fx.isFinite, fy.isFinite, fx > 0, fy > 0,
              cx.isFinite, cy.isFinite else { return nil }
        return Point3((column - cx) * depth / fx, -(row - cy) * depth / fy, -depth)
    }
}

public struct DepthSample: Sendable {
    public var position: Point3
    public var confidence: UInt8
    public init(_ position: Point3, confidence: UInt8 = 2) {
        self.position = position; self.confidence = confidence
    }
}

public struct Observation: Sendable {
    public var timestamp: Double
    public var camera: Point3
    /// Horizontal unit direction in the gravity-aligned world coordinate system.
    public var forward: Point3
    public var samples: [DepthSample]
    public var trackingNormal: Bool
    public init(timestamp: Double, camera: Point3, forward: Point3,
                samples: [DepthSample], trackingNormal: Bool = true) {
        self.timestamp = timestamp; self.camera = camera; self.forward = forward
        self.samples = samples; self.trackingNormal = trackingNormal
    }
    public func coordinates(_ p: Point3) -> (ahead: Double, side: Double) {
        let dx = p.x - camera.x, dz = p.z - camera.z
        return (dx * forward.x + dz * forward.z, -dx * forward.z + dz * forward.x)
    }
}
