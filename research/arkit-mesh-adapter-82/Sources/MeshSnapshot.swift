import Foundation
import MeshBufferDecoder81

/// Metadata supplied by the serialized session owner, never inferred from mesh geometry.
public enum MeshSnapshot82 {
    public struct Context: Sendable {
        public let sessionID: UUID
        public let generation: UInt64
        public let revision: UInt64
        public let receiptUptime: Double
        /// Anchor callbacks do not establish a sensor capture timestamp.
        public var captureUptime: Double? { nil }
        public init(sessionID: UUID, generation: UInt64, revision: UInt64, receiptUptime: Double) {
            self.sessionID = sessionID; self.generation = generation
            self.revision = revision; self.receiptUptime = receiptUptime
        }
    }
    public enum Failure: Error, Equatable, Sendable {
        case invalidContext, invalidDescriptor, unsupportedFormat, inaccessibleBuffer, overflow, budget
        case decoding(MeshBufferDecoder.Failure)
    }
    public struct Descriptor: Sendable {
        public let count: Int, offset: Int, stride: Int, bufferLength: Int
        public let format: MeshBufferDecoder.Format
        public init(count: Int, offset: Int, stride: Int, bufferLength: Int, format: MeshBufferDecoder.Format) {
            self.count = count; self.offset = offset; self.stride = stride
            self.bufferLength = bufferLength; self.format = format
        }
    }
    public struct Plan: Sendable {
        public let vertices: Descriptor, indices: Descriptor, classification: Descriptor?
        public let vertexBytes: Int, indexBytes: Int, classificationBytes: Int
        public let limits: MeshBufferDecoder.Limits
        fileprivate init(vertices: Descriptor, indices: Descriptor, classification: Descriptor?,
                         vertexBytes: Int, indexBytes: Int, classificationBytes: Int, limits: MeshBufferDecoder.Limits) {
            self.vertices = vertices; self.indices = indices; self.classification = classification
            self.vertexBytes = vertexBytes; self.indexBytes = indexBytes
            self.classificationBytes = classificationBytes; self.limits = limits
        }
    }
    public struct Owned: Sendable {
        public let context: Context, anchorID: UUID
        public let vertices: MeshBufferDecoder.Buffer, indices: MeshBufferDecoder.Buffer
        public let classification: MeshBufferDecoder.Buffer?
        public let transform: [Float]
        fileprivate let limits: MeshBufferDecoder.Limits
        // Only this module may issue a snapshot; there is no public forged-snapshot initializer.
        init(context: Context, anchorID: UUID, plan: Plan, vertexBytes: [UInt8], indexBytes: [UInt8],
             classificationBytes: [UInt8]?, transform: [Float]) {
            self.context = context; self.anchorID = anchorID; self.transform = transform; limits = plan.limits
            func buffer(_ bytes: [UInt8], _ d: Descriptor) -> MeshBufferDecoder.Buffer {
                .init(bytes: bytes, count: d.count, offset: d.offset, stride: d.stride, format: d.format)
            }
            vertices = buffer(vertexBytes, plan.vertices); indices = buffer(indexBytes, plan.indices)
            if let d = plan.classification, let b = classificationBytes { classification = buffer(b, d) }
            else { classification = nil }
        }
    }
    public struct Gap: Sendable {
        public let context: Context, anchorID: UUID, reason: Failure
        public var coverageKnown: Bool { false }
        public var physicalAuthority: Bool { false }
        public init(context: Context, anchorID: UUID, reason: Failure) {
            self.context = context; self.anchorID = anchorID; self.reason = reason
        }
    }
    public enum Capture: Sendable { case owned(Owned), unknownGap(Gap) }
    public enum Decoded: Sendable {
        case revision(context: Context, anchorID: UUID, mesh: MeshBufferDecoder.ValidatedRevision)
        case unknownGap(Gap)
        public var physicalAuthority: Bool { false }
        public var coverageKnown: Bool { false }
    }
    private static func add(_ a: Int, _ b: Int) throws -> Int {
        let (n, overflow) = a.addingReportingOverflow(b)
        guard !overflow else { throw Failure.overflow }; return n
    }
    private static func mul(_ a: Int, _ b: Int) throws -> Int {
        let (n, overflow) = a.multipliedReportingOverflow(by: b)
        guard !overflow else { throw Failure.overflow }; return n
    }
    private static func span(_ d: Descriptor, width: Int) throws -> Int {
        guard d.count > 0, d.offset >= 0, d.stride >= width, d.bufferLength >= 0 else {
            throw Failure.invalidDescriptor
        }
        let end = try add(add(d.offset, mul(d.count - 1, d.stride)), width)
        guard end <= d.bufferLength else { throw Failure.invalidDescriptor }; return end
    }
    /// No buffer read or allocation. All descriptors, including optional classification,
    /// must pass before any byte copying starts. Reject whole malformed revisions, not prefixes.
    public static func preflight(context: Context, vertices: Descriptor, indices: Descriptor,
                                 classification: Descriptor?, limits: MeshBufferDecoder.Limits = .init()) throws -> Plan {
        guard context.generation > 0, context.revision > 0,
              context.receiptUptime.isFinite, context.receiptUptime >= 0 else { throw Failure.invalidContext }
        guard limits.vertices > 0, limits.faces > 0, limits.inputBytes >= 0, limits.decodedBytes >= 0 else {
            throw Failure.budget
        }
        guard vertices.format == .float3, indices.format == .uint16 || indices.format == .uint32 else {
            throw Failure.unsupportedFormat
        }
        guard vertices.count > 0, indices.count > 0, indices.count % 3 == 0 else { throw Failure.invalidDescriptor }
        let faces = indices.count / 3
        guard vertices.count <= limits.vertices, faces <= limits.faces else { throw Failure.budget }
        let v = try span(vertices, width: 12), i = try span(indices, width: indices.format == .uint16 ? 2 : 4)
        var c = 0
        if let d = classification {
            guard d.format == .uint8, d.count == faces else { throw Failure.invalidDescriptor }
            c = try span(d, width: 1)
        }
        let total = try add(add(v, i), c)
        let decoded = try add(add(mul(vertices.count, 12), mul(indices.count, 4)), mul(faces, 64))
        guard total <= limits.inputBytes, decoded <= limits.decodedBytes else { throw Failure.budget }
        return Plan(vertices: vertices, indices: indices, classification: classification,
                    vertexBytes: v, indexBytes: i, classificationBytes: c, limits: limits)
    }
    /// May run off callback after ownership transfer; accepts only owned value buffers.
    public static func decode(_ captured: Capture) -> Decoded {
        switch captured {
        case .unknownGap(let gap): return .unknownGap(gap)
        case .owned(let owned):
            do {
                let mesh = try MeshBufferDecoder.decode(revision: owned.context.revision, vertices: owned.vertices,
                    indices: owned.indices, transform: owned.transform, classification: owned.classification,
                    limits: owned.limits)
                return .revision(context: owned.context, anchorID: owned.anchorID, mesh: mesh)
            } catch {
                let failure = (error as? MeshBufferDecoder.Failure).map(Failure.decoding) ?? .invalidDescriptor
                return .unknownGap(.init(context: owned.context, anchorID: owned.anchorID, reason: failure))
            }
        }
    }
}
