import BlindCore
import Foundation

/// Shared arithmetic for the hazard-observation lane, not point lookup, mapping
/// authority, tracking quality or evidence of physical clearance. Native callers
/// retain pixel-buffer ownership/locking, row strides and SIMD world transforms.
public enum NativeDepthObservationPolicy {
    public static let pixelStride = 2
    public static let requiredConfidence: UInt8 = 2
    public static let depthRange = 0.15...5.0
    public static let minimumHorizontalOpticalLength: Float = 0.25

    /// ARFrame intrinsics are Float. Keep the original Float-to-Double conversion
    /// before resolution scaling; recorded adapters must enter through this seam.
    @inlinable public static func projection(fx: Float, fy: Float, cx: Float, cy: Float,
                                  depthWidth: Int, depthHeight: Int,
                                  imageWidth: Double, imageHeight: Double) -> DepthProjection {
        let sx = Double(depthWidth) / imageWidth, sy = Double(depthHeight) / imageHeight
        return DepthProjection(fx: Double(fx) * sx, fy: Double(fy) * sy,
                               cx: Double(cx) * sx, cy: Double(cy) * sy)
    }

    /// Native depth buffers are Float metres. Confidence one is deliberately not
    /// accepted here even though the separate point-lookup lane may accept it.
    @inlinable public static func acceptedDepth(_ depth: Float, confidence: UInt8) -> Double? {
        let value = Double(depth)
        guard confidence == requiredConfidence, depthRange.contains(value) else { return nil }
        return value
    }

    /// Optical components are Float, matching ARKit. An unusable heading means
    /// no Observation, never an accepted zero-vector frame.
    @inlinable public static func horizontalForward(opticalX: Float, opticalZ: Float) -> Point3? {
        let horizontalLength = hypot(opticalX, opticalZ)
        guard horizontalLength > minimumHorizontalOpticalLength else { return nil }
        return Point3(Double(opticalX / horizontalLength), 0, Double(opticalZ / horizontalLength))
    }
}
