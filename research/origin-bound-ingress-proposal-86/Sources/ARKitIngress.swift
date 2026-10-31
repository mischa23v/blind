#if os(iOS) && canImport(ARKit)
import ARKit
import MeshBufferDecoder81
import MeshSnapshot82

@available(iOS 13.4, *)
public extension OriginBoundMeshIngress86 {
    /// Integration seam only, NOT an installed ARSession delegate or app activation.
    /// Owning callback queue, immutable native producer identity and buffer validity
    /// must already be established. A lease alone proves NONE of those conditions.
    /// Not safe to wire into the existing reused-ARSession callback owner.
    @discardableResult func ingest(_ anchor: ARMeshAnchor, lease: ProducerLease, receiptUptime: Double,
                                   limits: MeshBufferDecoder.Limits = .init()) -> Bool {
        ingest(lease: lease, anchorID: anchor.identifier, receiptUptime: receiptUptime) { context in
            // Clamp caller-selected limits to this owner's aggregate per-job ceiling.
            let bounded = MeshBufferDecoder.Limits(vertices: min(limits.vertices, 200_000),
                faces: min(limits.faces, 100_000), inputBytes: min(limits.inputBytes, 16_000_000),
                decodedBytes: min(limits.decodedBytes, 8_000_000))
            return ARKitMeshAdapter82.capture(anchor, context: context, limits: bounded)
        }
    }
}
#endif
