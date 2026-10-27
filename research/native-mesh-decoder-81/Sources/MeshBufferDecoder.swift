// Fresh candidate adapter. Owned snapshots only; no Metal pointer access or runtime wiring.
public enum MeshBufferDecoder {
    public enum Format: Sendable { case float3, uint16, uint32, uint8 }
    public struct Buffer: Sendable {
        public let bytes: [UInt8]
        public let count: Int
        public let offset: Int
        public let stride: Int
        public let format: Format
        public init(bytes: [UInt8], count: Int, offset: Int, stride: Int, format: Format) {
            self.bytes = bytes; self.count = count; self.offset = offset
            self.stride = stride; self.format = format
        }
    }
    public struct Limits: Sendable {
        public let vertices: Int, faces: Int, inputBytes: Int, decodedBytes: Int
        public init(vertices: Int = 200_000, faces: Int = 100_000,
                    inputBytes: Int = 16_000_000, decodedBytes: Int = 8_000_000) {
            self.vertices = vertices; self.faces = faces
            self.inputBytes = inputBytes; self.decodedBytes = decodedBytes
        }
    }
    public enum Failure: Error, Equatable {
        case invalidLimits, invalidRevision, invalidDescriptor, overflow, budget
        case nonFiniteVertex, invalidIndex, invalidTransform
    }
    public enum ClassificationDiagnostic: Equatable, Sendable {
        case missing, malformed, unknown(face: Int, value: UInt8)
    }
    // The initializer is file-private; no external public client can forge a result.
    public struct ValidatedRevision: Sendable {
        public let revision: UInt64
        public let localVertices: [Float] // xyz packed, NEVER world coordinates
        public let triangleIndices: [UInt32]
        public let anchorTransform: [Float] // unmodified column-major 4x4; downstream applies once
        public let classifications: [UInt8?] // 0...7 label values, not support/clearance evidence
        public let classificationDiagnostics: [ClassificationDiagnostic]
        public var physicalAuthority: Bool { false }
        public var coverageKnown: Bool { false }
        fileprivate init(revision: UInt64, localVertices: [Float], triangleIndices: [UInt32],
                         anchorTransform: [Float], classifications: [UInt8?],
                         classificationDiagnostics: [ClassificationDiagnostic]) {
            self.revision = revision; self.localVertices = localVertices
            self.triangleIndices = triangleIndices; self.anchorTransform = anchorTransform
            self.classifications = classifications; self.classificationDiagnostics = classificationDiagnostics
        }
    }
    private static func add(_ a: Int, _ b: Int) throws -> Int {
        let (v, overflow) = a.addingReportingOverflow(b)
        guard !overflow else { throw Failure.overflow }; return v
    }
    private static func multiply(_ a: Int, _ b: Int) throws -> Int {
        let (v, overflow) = a.multipliedReportingOverflow(by: b)
        guard !overflow else { throw Failure.overflow }; return v
    }
    private static func validate(_ b: Buffer, width: Int) throws {
        guard b.count > 0, b.offset >= 0, b.stride >= width else { throw Failure.invalidDescriptor }
        let last = try add(b.offset, multiply(b.count - 1, b.stride))
        guard try add(last, width) <= b.bytes.count else { throw Failure.invalidDescriptor }
    }
    private static func word(_ bytes: [UInt8], _ i: Int, _ width: Int) -> UInt32 {
        var value: UInt32 = 0
        for n in 0..<width { value |= UInt32(bytes[i + n]) << (8 * n) }
        return value
    }
    private static func rigid(_ m: [Float]) -> Bool {
        guard m.count == 16, m.allSatisfy({ $0.isFinite }),
              m[3] == 0, m[7] == 0, m[11] == 0, m[15] == 1 else { return false }
        // Numerical rotation tolerance only; not a sensor uncertainty/physical safety budget.
        let d = m.map(Double.init), tolerance = 1e-5
        for a in 0..<3 {
            for b in 0..<3 {
                var dot = 0.0
                for row in 0..<3 { dot += d[a * 4 + row] * d[b * 4 + row] }
                if abs(dot - (a == b ? 1 : 0)) > tolerance { return false }
            }
        }
        let determinant = d[0] * (d[5] * d[10] - d[9] * d[6])
            - d[4] * (d[1] * d[10] - d[9] * d[2])
            + d[8] * (d[1] * d[6] - d[5] * d[2])
        return abs(determinant - 1) <= tolerance
    }
    /// Complete owned revision or throw; no prefix geometry escapes on any failure.
    /// Little-endian snapshot contract. Index count is scalar count (three per triangle).
    public static func decode(revision: UInt64, vertices: Buffer, indices: Buffer,
                              transform: [Float], classification: Buffer? = nil,
                              limits: Limits = Limits()) throws -> ValidatedRevision {
        guard limits.vertices > 0, limits.faces > 0, limits.inputBytes >= 0,
              limits.decodedBytes >= 0 else { throw Failure.invalidLimits }
        guard revision > 0 else { throw Failure.invalidRevision }
        guard vertices.format == .float3, indices.format == .uint16 || indices.format == .uint32,
              indices.count > 0, indices.count % 3 == 0 else { throw Failure.invalidDescriptor }
        guard vertices.count > 0, vertices.count <= limits.vertices,
              indices.count / 3 <= limits.faces else { throw Failure.budget }
        let faceCount = indices.count / 3
        let inputBytes = try add(add(vertices.bytes.count, indices.bytes.count), classification?.bytes.count ?? 0)
        // Conservative logical allocation accounting, not a hard RSS/allocator cap:
        // Float xyz + UInt32 indices + Optional<UInt8> + worst-case enum diagnostic per face.
        let decodedBytes = try add(add(multiply(vertices.count, 12), multiply(indices.count, 4)),
                                   multiply(faceCount, 64))
        guard inputBytes <= limits.inputBytes, decodedBytes <= limits.decodedBytes else { throw Failure.budget }
        let indexWidth = indices.format == .uint16 ? 2 : 4
        try validate(vertices, width: 12); try validate(indices, width: indexWidth)
        guard rigid(transform) else { throw Failure.invalidTransform }
        var positions: [Float] = []; positions.reserveCapacity(try multiply(vertices.count, 3))
        for vertex in 0..<vertices.count {
            let start = vertices.offset + vertex * vertices.stride // checked by validate
            for axis in 0..<3 {
                let value = Float(bitPattern: word(vertices.bytes, start + axis * 4, 4))
                guard value.isFinite else { throw Failure.nonFiniteVertex }
                positions.append(value)
            }
        }
        var triangles: [UInt32] = []; triangles.reserveCapacity(indices.count)
        for index in 0..<indices.count {
            let value = word(indices.bytes, indices.offset + index * indices.stride, indexWidth)
            guard UInt64(value) < UInt64(vertices.count) else { throw Failure.invalidIndex }
            triangles.append(value)
        }
        var labels = [UInt8?](repeating: nil, count: faceCount)
        var diagnostics: [ClassificationDiagnostic] = []
        if let c = classification {
            if c.format != .uint8 || c.count != faceCount || (try? validate(c, width: 1)) == nil {
                diagnostics.append(.malformed)
            } else {
                for face in 0..<faceCount {
                    let value = c.bytes[c.offset + face * c.stride]
                    if value <= 7 { labels[face] = value }
                    else { diagnostics.append(.unknown(face: face, value: value)) }
                }
            }
        } else { diagnostics.append(.missing) }
        return ValidatedRevision(revision: revision, localVertices: positions, triangleIndices: triangles,
                                 anchorTransform: transform, classifications: labels,
                                 classificationDiagnostics: diagnostics)
    }
}
