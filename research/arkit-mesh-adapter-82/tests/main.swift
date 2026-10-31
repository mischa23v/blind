import Foundation
import MeshBufferDecoder81
@testable import MeshSnapshot82

var checks = 0
func check(_ value: @autoclosure () -> Bool, _ label: String) {
    precondition(value(), label); checks += 1
}
let context = MeshSnapshot82.Context(sessionID: UUID(), generation: 4, revision: 9, receiptUptime: 123)
let id = UUID()
let identity: [Float] = [1,0,0,0, 0,1,0,0, 0,0,1,0, 2,3,4,1]
func descriptor(_ count: Int, _ offset: Int, _ stride: Int, _ length: Int,
                _ format: MeshBufferDecoder.Format) -> MeshSnapshot82.Descriptor {
    .init(count: count, offset: offset, stride: stride, bufferLength: length, format: format)
}
let vd = descriptor(3, 1, 16, 45, .float3)
let ind = descriptor(3, 1, 3, 9, .uint16)
let cd = descriptor(1, 2, 2, 3, .uint8)
func plan(_ v: MeshSnapshot82.Descriptor = vd, _ i: MeshSnapshot82.Descriptor = ind,
          _ c: MeshSnapshot82.Descriptor? = cd,
          _ limits: MeshBufferDecoder.Limits = .init(),
          _ ctx: MeshSnapshot82.Context = context) throws -> MeshSnapshot82.Plan {
    try MeshSnapshot82.preflight(context: ctx, vertices: v, indices: i, classification: c, limits: limits)
}
func rejected(_ label: String, _ body: () throws -> MeshSnapshot82.Plan) {
    do { _ = try body(); preconditionFailure(label) } catch { checks += 1 }
}
let p = try plan()
check(p.vertexBytes == 45 && p.indexBytes == 9 && p.classificationBytes == 3, "padded unaligned spans")
check(context.captureUptime == nil && context.receiptUptime == 123, "receipt is not capture")
var v = [UInt8](repeating: 0, count: 45)
func put(_ word: UInt32, _ offset: Int, _ bytes: inout [UInt8]) {
    for n in 0..<4 { bytes[offset+n] = UInt8(truncatingIfNeeded: word >> (n*8)) }
}
for n in 0..<3 { for a in 0..<3 { put(Float(n+a).bitPattern, 1+n*16+a*4, &v) } }
var i: [UInt8] = [0,0,0,0,1,0,0,2,0]
let owned = MeshSnapshot82.Owned(context: context, anchorID: id, plan: p,
    vertexBytes: v, indexBytes: i, classificationBytes: [0,0,2], transform: identity)
v[1] = 255; i[1] = 255
switch MeshSnapshot82.decode(.owned(owned)) {
case .revision(let ctx, let anchor, let mesh):
    check(ctx.generation == 4 && ctx.sessionID == context.sessionID && anchor == id, "owner metadata")
    check(mesh.revision == 9, "revision preserved")
    check(mesh.localVertices == [0,1,2,1,2,3,2,3,4], "owned local values not transformed")
    check(mesh.anchorTransform == identity, "transform preserved once for downstream")
    check(mesh.triangleIndices == [0,1,2], "indices not mutated or truncated")
    check(mesh.classifications == [2], "classification offset")
    check(!mesh.physicalAuthority && !mesh.coverageKnown, "no geometry authority")
case .unknownGap: preconditionFailure("valid synthetic snapshot")
}
_ = try plan(vd, ind, cd, .init(vertices: 3, faces: 1, inputBytes: 57, decodedBytes: 112)); checks += 1
rejected("input budget before copying") { try plan(vd, ind, cd, .init(inputBytes: 56)) }
rejected("decoded budget before copying") { try plan(vd, ind, cd, .init(decodedBytes: 111)) }
rejected("vertex cap") { try plan(vd, ind, cd, .init(vertices: 2)) }
rejected("negative offset") { try plan(descriptor(3,-1,16,45,.float3)) }
rejected("short stride") { try plan(descriptor(3,1,11,45,.float3)) }
rejected("short buffer") { try plan(descriptor(3,1,16,44,.float3)) }
rejected("overflow") { try plan(descriptor(3,Int.max,16,Int.max,.float3)) }
rejected("overflow stride") { try plan(descriptor(3,1,Int.max,Int.max,.float3)) }
rejected("empty geometry") { try plan(descriptor(0,0,12,0,.float3)) }
rejected("partial face") { try plan(vd, descriptor(2,0,2,4,.uint16)) }
rejected("bad format") { try plan(descriptor(3,1,16,45,.uint8)) }
rejected("bad index format") { try plan(vd, descriptor(3,1,3,9,.uint8)) }
rejected("bad classification format") { try plan(vd, ind, descriptor(1,2,2,3,.uint16)) }
rejected("classification wrong count") { try plan(vd, ind, descriptor(2,2,2,5,.uint8)) }
rejected("classification span") { try plan(vd, ind, descriptor(1,2,2,2,.uint8)) }
for (generation, revision, time) in [(UInt64(0),UInt64(1),1.0), (1,0,1), (1,1,Double.nan), (1,1,-1)] {
    rejected("invalid owner context") { try plan(vd, ind, cd, .init(), .init(sessionID: UUID(), generation: generation, revision: revision, receiptUptime: time)) }
}
let packed32 = try plan(vd, descriptor(3,0,4,12,.uint32), nil)
let wide = MeshSnapshot82.Owned(context: context, anchorID: id, plan: packed32,
    vertexBytes: owned.vertices.bytes, indexBytes: [0,0,0,0,1,0,0,0,2,0,0,0], classificationBytes: nil, transform: identity)
if case .revision(_, _, let mesh) = MeshSnapshot82.decode(.owned(wide)) {
    check(mesh.triangleIndices == [0,1,2], "packed UInt32 element layout")
} else { preconditionFailure("UInt32 layout") }
let unknownClass = MeshSnapshot82.Owned(context: context, anchorID: id, plan: p,
    vertexBytes: owned.vertices.bytes, indexBytes: owned.indices.bytes, classificationBytes: [0,0,255], transform: identity)
if case .revision(_, _, let mesh) = MeshSnapshot82.decode(.owned(unknownClass)) {
    check(mesh.classifications == [nil] && mesh.classificationDiagnostics == [.unknown(face: 0, value: 255)], "unknown label not floor")
} else { preconditionFailure("unknown classification is diagnostic") }
let noClasses = try plan(vd, ind, nil)
let absent = MeshSnapshot82.Owned(context: context, anchorID: id, plan: noClasses,
    vertexBytes: owned.vertices.bytes, indexBytes: owned.indices.bytes, classificationBytes: nil, transform: identity)
if case .revision(_, _, let mesh) = MeshSnapshot82.decode(.owned(absent)) {
    check(mesh.classificationDiagnostics == [.missing], "missing classes retained")
} else { preconditionFailure("missing optional classification") }
for (bytes, transform) in [(i, identity), (owned.indices.bytes, [Float](repeating: 0, count: 16))] {
    let bad = MeshSnapshot82.Owned(context: context, anchorID: id, plan: p,
        vertexBytes: owned.vertices.bytes, indexBytes: bytes, classificationBytes: [0,0,2], transform: transform)
    if case .unknownGap(let gap) = MeshSnapshot82.decode(.owned(bad)) {
        check(gap.context.revision == 9 && gap.anchorID == id && !gap.physicalAuthority, "malformed revision is explicit gap")
    } else { preconditionFailure("malformed revision escaped") }
}
let gap = MeshSnapshot82.Gap(context: context, anchorID: id, reason: .budget)
let decoded = MeshSnapshot82.decode(.unknownGap(gap))
if case .unknownGap(let result) = decoded { check(result.reason == .budget, "copy refusal survives decode") }
else { preconditionFailure("gap became mesh") }
check(!decoded.physicalAuthority && !decoded.coverageKnown, "gap never clearance")
print("RESULT: \(checks) stage82 synthetic descriptor/snapshot checks passed; no ARKit execution")
