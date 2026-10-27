#if canImport(ARKit)
import ARKit
import MeshBufferDecoder81
import MeshSnapshot82

@available(iOS 13.4, *)
public extension MeshCandidateIngress83 {
    /// Integration seam only, NOT an installed ARSession delegate or app activation.
    /// Owning callback queue and buffer validity must already be established.
    @discardableResult func ingest(_ anchor: ARMeshAnchor, receiptUptime: Double,
                                   limits: MeshBufferDecoder.Limits = .init()) -> Bool {
        ingest(anchorID: anchor.identifier, receiptUptime: receiptUptime) { context in
            // Clamp caller-selected limits to this owner's aggregate per-job ceiling.
            let bounded = MeshBufferDecoder.Limits(vertices: min(limits.vertices, 200_000),
                faces: min(limits.faces, 100_000), inputBytes: min(limits.inputBytes, 16_000_000),
                decodedBytes: min(limits.decodedBytes, 8_000_000))
            return ARKitMeshAdapter82.capture(anchor, context: context, limits: bounded)
        }
    }
}
#endif
