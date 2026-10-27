import MeshBufferDecoder81
import Foundation

typealias D = MeshBufferDecoder
var checks = 0
func check(_ name: String, _ condition: @autoclosure () throws -> Bool) rethrows {
    guard try condition() else { fatalError("FAIL: \(name)") }
    checks += 1; print("PASS: \(name)")
}
func bytes(_ values: [Float], offset: Int = 0, stride: Int = 12) -> [UInt8] {
    var result = [UInt8](repeating: 0xAA, count: offset + (values.count / 3 - 1) * stride + 12)
    for i in 0..<values.count {
        let p = offset + (i / 3) * stride + (i % 3) * 4
        for n in 0..<4 { result[p + n] = UInt8(truncatingIfNeeded: values[i].bitPattern >> (8 * n)) }
    }
    return result
}
func indices(_ values: [UInt32], width: Int = 2, offset: Int = 0, stride: Int? = nil) -> D.Buffer {
    let step = stride ?? width
    var result = [UInt8](repeating: 0xBB, count: offset + (values.count - 1) * step + width)
    for i in 0..<values.count {
        for n in 0..<width { result[offset + i * step + n] = UInt8(truncatingIfNeeded: values[i] >> (8 * n)) }
    }
    return D.Buffer(bytes: result, count: values.count, offset: offset, stride: step,
                    format: width == 2 ? .uint16 : .uint32)
}
let xyz: [Float] = [0,0,0, 1,0,0, 0,1,0]
let v = D.Buffer(bytes: bytes(xyz), count: 3, offset: 0, stride: 12, format: .float3)
let ix = indices([0,1,2])
let identity: [Float] = [1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1]
func decode(_ vertices: D.Buffer = v, _ index: D.Buffer = ix, transform: [Float] = identity,
            classification: D.Buffer? = nil, limits: D.Limits = D.Limits(), revision: UInt64 = 1) throws -> D.ValidatedRevision {
    try D.decode(revision: revision, vertices: vertices, indices: index, transform: transform,
                 classification: classification, limits: limits)
}
func rejected(_ name: String, _ expected: D.Failure, _ body: () throws -> D.ValidatedRevision) {
    do { _ = try body(); fatalError("accepted \(name)") }
    catch let error as D.Failure { check(name, error == expected) }
    catch { fatalError("wrong error \(name): \(error)") }
}
let basic = try decode()
check("local float3", basic.localVertices == xyz)
check("uint16 triangles", basic.triangleIndices == [0,1,2])
check("missing classification is diagnostic", basic.classificationDiagnostics == [.missing])
check("no physical authority", !basic.physicalAuthority && !basic.coverageKnown)
check("complete revision identity", basic.revision == 1)
let padded = D.Buffer(bytes: bytes(xyz, offset: 5, stride: 20), count: 3, offset: 5, stride: 20, format: .float3)
try check("unaligned offset and padded stride", try decode(padded).localVertices == xyz)
try check("uint32 padded indices", try decode(v, indices([0,1,2], width: 4, offset: 3, stride: 8)).triangleIndices == [0,1,2])
var transform = identity
transform[0] = 0; transform[1] = 1; transform[4] = -1; transform[5] = 0
transform[12] = 4; transform[13] = -3; transform[14] = 2
let transformed = try decode(transform: transform)
check("transform preserved bit exactly", transformed.anchorTransform.map(\.bitPattern) == transform.map(\.bitPattern))
check("transform not preapplied", transformed.localVertices == xyz)
// Consumer applies exactly once, matching stage75's anchor-local contract; no stage75 import/wiring.
let p = transformed.localVertices
let m = transformed.anchorTransform
check("one downstream transform", m[0]*p[3] + m[4]*p[4] + m[8]*p[5] + m[12] == 4 && m[1]*p[3] + m[5]*p[4] + m[9]*p[5] + m[13] == -2)
let two = indices([0,1,2, 2,1,0])
let classification = D.Buffer(bytes: [99,2,99,99,7], count: 2, offset: 1, stride: 3, format: .uint8)
try check("padded multiface classification", try decode(v, two, classification: classification).classifications == [2,7])
let unknown = D.Buffer(bytes: [255], count: 1, offset: 0, stride: 1, format: .uint8)
let u = try decode(classification: unknown)
check("unknown label diagnostic", u.classificationDiagnostics == [.unknown(face: 0, value: 255)] && u.classifications == [nil])
check("unknown label retains geometry without authority", u.localVertices == xyz && !u.physicalAuthority)
for (name, c) in [
    ("short", D.Buffer(bytes: [], count: 1, offset: 0, stride: 1, format: .uint8)),
    ("wrong count", D.Buffer(bytes: [1,2], count: 2, offset: 0, stride: 1, format: .uint8)),
    ("wrong format", D.Buffer(bytes: [1], count: 1, offset: 0, stride: 1, format: .uint16)),
    ("negative offset", D.Buffer(bytes: [1], count: 1, offset: -1, stride: 1, format: .uint8)),
    ("overflow", D.Buffer(bytes: [1], count: 1, offset: Int.max, stride: 1, format: .uint8))
] {
    let result = try decode(classification: c)
    check("malformed classification \(name)", result.classificationDiagnostics == [.malformed] && result.localVertices == xyz)
}
var highXYZ = [Float](repeating: 0, count: 65_537 * 3)
highXYZ[65_536 * 3] = 42
let high = D.Buffer(bytes: bytes(highXYZ), count: 65_537, offset: 0, stride: 12, format: .float3)
let highResult = try decode(high, indices([0,1,65_536], width: 4))
check("high UInt32 index not truncated", highResult.triangleIndices.last == 65_536 && highResult.localVertices[65_536 * 3] == 42)
let exact = D.Limits(vertices: 3, faces: 1, inputBytes: 42, decodedBytes: 112)
try check("exact inclusive budgets", try decode(limits: exact).triangleIndices.count == 3)
rejected("one byte input over", .budget) { try decode(limits: D.Limits(inputBytes: 41)) }
rejected("one byte decoded over", .budget) { try decode(limits: D.Limits(decodedBytes: 111)) }
rejected("classification counts toward input", .budget) { try decode(classification: unknown, limits: exact) }
rejected("vertex cap", .budget) { try decode(limits: D.Limits(vertices: 2)) }
rejected("face cap", .budget) { try decode(v, two, limits: D.Limits(faces: 1)) }
rejected("invalid limits", .invalidLimits) { try decode(limits: D.Limits(vertices: 0)) }
rejected("zero revision", .invalidRevision) { try decode(revision: 0) }
rejected("out of range index", .invalidIndex) { try decode(v, indices([0,1,3])) }
rejected("UInt32 max index", .invalidIndex) { try decode(v, indices([0,1,UInt32.max], width: 4)) }
rejected("partial triangle", .invalidDescriptor) { try decode(v, indices([0,1])) }
for (name, buffer, error) in [
    ("truncated vertex", D.Buffer(bytes: Array(v.bytes.dropLast()), count: 3, offset: 0, stride: 12, format: .float3), D.Failure.invalidDescriptor),
    ("negative offset", D.Buffer(bytes: v.bytes, count: 3, offset: -1, stride: 12, format: .float3), .invalidDescriptor),
    ("short stride", D.Buffer(bytes: v.bytes, count: 3, offset: 0, stride: 11, format: .float3), .invalidDescriptor),
    ("range overflow", D.Buffer(bytes: v.bytes, count: 3, offset: Int.max, stride: 12, format: .float3), .overflow),
    ("stride overflow", D.Buffer(bytes: v.bytes, count: 3, offset: 0, stride: Int.max, format: .float3), .overflow),
    ("wrong vertex format", D.Buffer(bytes: v.bytes, count: 3, offset: 0, stride: 12, format: .uint32), .invalidDescriptor)
] { rejected(name, error) { try decode(buffer) } }
for (name, buffer, error) in [
    ("truncated indices", D.Buffer(bytes: [0,0,1,0,2], count: 3, offset: 0, stride: 2, format: .uint16), D.Failure.invalidDescriptor),
    ("index offset overflow", D.Buffer(bytes: ix.bytes, count: 3, offset: Int.max, stride: 2, format: .uint16), .overflow),
    ("index short stride", D.Buffer(bytes: ix.bytes, count: 3, offset: 0, stride: 1, format: .uint16), .invalidDescriptor),
    ("index negative count", D.Buffer(bytes: ix.bytes, count: -3, offset: 0, stride: 2, format: .uint16), .invalidDescriptor),
    ("index wrong format", D.Buffer(bytes: ix.bytes, count: 3, offset: 0, stride: 2, format: .uint8), .invalidDescriptor)
] { rejected(name, error) { try decode(v, buffer) } }
rejected("decoded allocation multiplication overflow", .overflow) {
    let huge = D.Buffer(bytes: [], count: Int.max, offset: 0, stride: 12, format: .float3)
    return try decode(huge, limits: D.Limits(vertices: Int.max, faces: Int.max, inputBytes: Int.max, decodedBytes: Int.max))
}
for value in [Float.nan, Float.infinity, -Float.infinity] {
    var bad = xyz; bad[8] = value
    rejected("late nonfinite vertex rejects full revision", .nonFiniteVertex) {
        try decode(D.Buffer(bytes: bytes(bad), count: 3, offset: 0, stride: 12, format: .float3))
    }
}
for (name, slot, value) in [("scale",0,Float(2)),("reflection",0,Float(-1)),("shear",4,Float(0.1)),("projective",3,Float(0.1)),("nonfinite translation",12,Float.nan)] {
    var bad = identity; bad[slot] = value
    rejected("transform \(name)", .invalidTransform) { try decode(transform: bad) }
}
rejected("short transform", .invalidTransform) { try decode(transform: [1]) }
print("RESULT: \(checks) fresh synthetic checks passed; no device/runtime/clearance claim")
