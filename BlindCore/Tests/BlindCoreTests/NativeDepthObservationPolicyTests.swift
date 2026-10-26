import XCTest
#if canImport(simd)
import simd
#endif
@testable import BlindCore

final class NativeDepthObservationPolicyTests: XCTestCase {
    func testDepthMatchesOriginalNativeExpressionIncludingBoundariesAndNonfinite() {
        let depths: [Float] = [0, -1, Float(0.15).nextDown, 0.15, Float(0.15).nextUp, 1, Float(5).nextDown, 5, Float(5).nextUp, .infinity, -.infinity, .nan]
        for depth in depths { for confidence: UInt8 in [0, 1, 2, 3, 255] {
            let value = Double(depth)
            let expected: Double? = confidence == 2 && (0.15...5).contains(value) ? value : nil
            XCTAssertEqual(NativeDepthObservationPolicy.acceptedDepth(depth, confidence: confidence), expected)
        } }
        XCTAssertEqual(NativeDepthObservationPolicy.pixelStride, 2)
    }
    func testHeadingMatchesOriginalFloatArithmeticAndRejectsVerticalBoundary() {
        let xs: [Float] = [0, Float(0.25).nextDown, 0.25, Float(0.25).nextUp, -0.5, 0.70710677]
        for x in xs { for z: Float in [0, 0.3, -0.75] {
            let length = hypot(x, z)
            let expected = length > 0.25 ? Point3(Double(x / length), 0, Double(z / length)) : nil
            XCTAssertEqual(NativeDepthObservationPolicy.horizontalForward(opticalX: x, opticalZ: z), expected)
        } }
        XCTAssertNil(NativeDepthObservationPolicy.horizontalForward(opticalX: .nan, opticalZ: 0))
        XCTAssertNil(NativeDepthObservationPolicy.horizontalForward(opticalX: 0, opticalZ: 0.25))
    }
    func testProjectionRetainsFloatIntrinsicsThenDoubleResolutionScaling() {
        let fx: Float = 213.956, fy: Float = 214.045, cx: Float = 126.71, cy: Float = 92.9443
        let shared = NativeDepthObservationPolicy.projection(fx: fx, fy: fy, cx: cx, cy: cy,
            depthWidth: 256, depthHeight: 192, imageWidth: 1920, imageHeight: 1440)
        let old = DepthProjection(fx: Double(fx) * (256.0 / 1920), fy: Double(fy) * (192.0 / 1440),
            cx: Double(cx) * (256.0 / 1920), cy: Double(cy) * (192.0 / 1440))
        for row in [0.0, 96, 190] { for column in [0.0, 128, 254] { for depth in [0.15, 1, 5] {
            XCTAssertEqual(shared.cameraPoint(column: column, row: row, depth: depth),
                           old.cameraPoint(column: column, row: row, depth: depth))
        } } }
    }
    func testInvalidIntrinsicsRemainRejectedByExistingDepthProjection() {
        for fx: Float in [0, -1, .nan, .infinity] {
            let projection = NativeDepthObservationPolicy.projection(fx: fx, fy: 1, cx: 0, cy: 0,
                depthWidth: 256, depthHeight: 192, imageWidth: 256, imageHeight: 192)
            XCTAssertNil(projection.cameraPoint(column: 0, row: 0, depth: 1))
        }
    }
    #if canImport(simd)
    /// Apple-SDK numerical bound, not a physical coordinate-validation claim.
    /// Portable replay sums Float columns; native retains simd matrix multiply.
    func testPortableColumnSumWithinExplicitNativeSIMDTolerance() {
        let matrix = simd_float4x4(columns: (
            SIMD4<Float>(0.8, 0.6, 0, 0), SIMD4<Float>(-0.6, 0.8, 0, 0),
            SIMD4<Float>(0, 0, 1, 0), SIMD4<Float>(12.3, -4.5, 6.7, 1)))
        for x: Float in [-5, -0.1, 0, 0.1, 5] { for y: Float in [-5, 0, 5] { for z: Float in [-5, -0.15] {
            let native = matrix * SIMD4<Float>(x, y, z, 1)
            let portable = matrix.columns.0 * x + matrix.columns.1 * y + matrix.columns.2 * z + matrix.columns.3
            for index in 0..<3 {
                let tolerance = Float(2e-6) * max(1, abs(native[index]))
                XCTAssertLessThanOrEqual(abs(native[index] - portable[index]), tolerance)
            }
        } } }
    }
    #endif

}
