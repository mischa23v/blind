import ARKit
import Foundation
import Metal
import MeshBufferDecoder81

/// Isolated extraction candidate. NOT wired into the app or a session delegate.
@available(iOS 13.4, *)
public enum ARKitMeshAdapter82 {
    /// Invoke synchronously on the serialized owning anchor callback while the producer's
    /// buffers are valid. Do not enqueue an ARMeshAnchor, MTLBuffer, or raw pointer.
    /// Caller must prioritize hazards and bound aggregate callback/queue work BEFORE entry.
    public static func capture(_ anchor: ARMeshAnchor, context: MeshSnapshot82.Context,
                               limits: MeshBufferDecoder.Limits = .init()) -> MeshSnapshot82.Capture {
        let id = anchor.identifier
        do {
            let geometry = anchor.geometry, vertices = geometry.vertices, faces = geometry.faces
            guard vertices.format == .float3, vertices.componentsPerVector == 3,
                  faces.primitiveType == .triangle, faces.indexCountPerPrimitive == 3,
                  faces.bytesPerIndex == 2 || faces.bytesPerIndex == 4 else {
                throw MeshSnapshot82.Failure.unsupportedFormat
            }
            let (indexCount, overflow) = faces.count.multipliedReportingOverflow(by: 3)
            guard !overflow else { throw MeshSnapshot82.Failure.overflow }
            let vd = MeshSnapshot82.Descriptor(count: vertices.count, offset: vertices.offset,
                stride: vertices.stride, bufferLength: vertices.buffer.length, format: .float3)
            // ARGeometryElement has packed scalar indices, not ARGeometrySource offset/stride.
            let fd = MeshSnapshot82.Descriptor(count: indexCount, offset: 0, stride: faces.bytesPerIndex,
                bufferLength: faces.buffer.length, format: faces.bytesPerIndex == 2 ? .uint16 : .uint32)
            let classes = geometry.classification
            var cd: MeshSnapshot82.Descriptor?
            if let c = classes {
                guard c.format == .uchar, c.componentsPerVector == 1 else {
                    throw MeshSnapshot82.Failure.unsupportedFormat
                }
                cd = .init(count: c.count, offset: c.offset, stride: c.stride,
                           bufferLength: c.buffer.length, format: .uint8)
            }
            let plan = try MeshSnapshot82.preflight(context: context, vertices: vd, indices: fd,
                                                    classification: cd, limits: limits)
            // iOS shared buffers are CPU-accessible. Reject private/memoryless rather than
            // touching contents or inventing a GPU readback/synchronization contract.
            guard vertices.buffer.storageMode == .shared, faces.buffer.storageMode == .shared,
                  classes == nil || classes!.buffer.storageMode == .shared else {
                throw MeshSnapshot82.Failure.inaccessibleBuffer
            }
            func copy(_ buffer: any MTLBuffer, _ length: Int) -> [UInt8] {
                Array(UnsafeRawBufferPointer(start: buffer.contents(), count: length))
            }
            // Copy the bounded referenced prefix, retaining offsets and padding; never truncate faces.
            let v = copy(vertices.buffer, plan.vertexBytes), i = copy(faces.buffer, plan.indexBytes)
            let c = classes.map { copy($0.buffer, plan.classificationBytes) }
            let matrix = anchor.transform
            let transform = (0..<4).flatMap { column in (0..<4).map { row in matrix[column][row] } }
            return .owned(.init(context: context, anchorID: id, plan: plan,
                                vertexBytes: v, indexBytes: i, classificationBytes: c, transform: transform))
        } catch {
            return .unknownGap(.init(context: context, anchorID: id,
                reason: (error as? MeshSnapshot82.Failure) ?? .invalidDescriptor))
        }
    }
}
