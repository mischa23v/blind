import Foundation

/// Raw observed geometry is useful history even when motion/localization evidence is absent.
/// This module has deliberately no conversion to SpatialLocalizationCapture or output leases.
public enum NativeObservationError: Error, Equatable {
    case invalidMetadata, invalidPose, invalidIntrinsics, invalidDepth, invalidSurface
    case outOfOrder, duplicate, invalidArchive, sizeLimit
}

/// Full optical transform. Never reduce a tilted camera to a gravity-aligned yaw transform.
public struct NativeCameraTransform: Codable, Equatable, Sendable {
    /// Column-major camera-to-session-world matrix, in metres.
    public let columns: [Double]
    public init(columns: [Double]) { self.columns = columns }
    public static let identity = NativeCameraTransform(columns: [1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1])
    public var valid: Bool {
        guard columns.count == 16, columns.allSatisfy(\.isFinite),
              abs(columns[3]) < 0.00001, abs(columns[7]) < 0.00001,
              abs(columns[11]) < 0.00001, abs(columns[15] - 1) < 0.00001 else { return false }
        for a in 0..<3 {
            for b in a..<3 {
                let dot = (0..<3).reduce(0.0) { $0 + columns[a * 4 + $1] * columns[b * 4 + $1] }
                guard abs(dot - (a == b ? 1 : 0)) < 0.001 else { return false }
            }
        }
        let c = columns
        let determinant = c[0] * (c[5]*c[10] - c[9]*c[6]) - c[4] * (c[1]*c[10] - c[9]*c[2]) + c[8] * (c[1]*c[6] - c[5]*c[2])
        return abs(determinant - 1) < 0.001
    }
    public func applying(to p: Point3) throws -> Point3 {
        guard valid, p.isFinite else { throw NativeObservationError.invalidPose }
        let c = columns
        let result = Point3(c[0]*p.x+c[4]*p.y+c[8]*p.z+c[12],
                            c[1]*p.x+c[5]*p.y+c[9]*p.z+c[13],
                            c[2]*p.x+c[6]*p.y+c[10]*p.z+c[14])
        guard result.isFinite else { throw NativeObservationError.invalidPose }
        return result
    }
    /// ARKitScenes official trajectories contain world-to-camera extrinsics. Invert once.
    public func inverted() throws -> NativeCameraTransform {
        guard valid else { throw NativeObservationError.invalidPose }
        let c = columns
        return NativeCameraTransform(columns: [c[0],c[4],c[8],0, c[1],c[5],c[9],0, c[2],c[6],c[10],0,
            -(c[0]*c[12]+c[1]*c[13]+c[2]*c[14]),
            -(c[4]*c[12]+c[5]*c[13]+c[6]*c[14]),
            -(c[8]*c[12]+c[9]*c[13]+c[10]*c[14]),1])
    }
}

public struct NativeCameraIntrinsics: Codable, Equatable, Sendable {
    public let width, height: Int
    public let fx, fy, cx, cy: Double
    public init(width: Int, height: Int, fx: Double, fy: Double, cx: Double, cy: Double) {
        self.width = width; self.height = height; self.fx = fx; self.fy = fy; self.cx = cx; self.cy = cy
    }
    public var valid: Bool {
        (1...16384).contains(width) && (1...16384).contains(height) &&
        [fx,fy,cx,cy].allSatisfy(\.isFinite) && fx > 0 && fy > 0 && cx >= 0 && cy >= 0 && cx < Double(width) && cy < Double(height)
    }
    public func scaled(width: Int, height: Int) throws -> NativeCameraIntrinsics {
        guard valid, (1...16384).contains(width), (1...16384).contains(height) else { throw NativeObservationError.invalidIntrinsics }
        let sx = Double(width) / Double(self.width), sy = Double(height) / Double(self.height)
        return NativeCameraIntrinsics(width: width, height: height, fx: fx*sx, fy: fy*sy, cx: cx*sx, cy: cy*sy)
    }
}

public enum NativeCameraConvention: String, Codable, Sendable {
    case arKitRightUpBack
    /// Official ARKitScenes pinhole loader's +Z-forward, +Y-down convention.
    case pinholeRightDownForward
}

public struct NativeDepthPixel: Codable, Equatable, Sendable {
    public let column, row: Int
    public let metres: Double
    /// ARConfidenceLevel ordinal (0/1/2), never a variance or position error bound.
    public let confidence: UInt8?
    public init(column: Int, row: Int, metres: Double, confidence: UInt8?) {
        self.column = column; self.row = row; self.metres = metres; self.confidence = confidence
    }
}

/// Sampled raster only, not a dense reconstruction, visibility volume, or free-space map.
public struct NativeDepthObservation: Codable, Equatable, Sendable {
    public enum Source: String, Codable, Sendable { case arkitSceneDepth, arkitScenesAppleDepth }
    public let source: Source
    public let width, height, samplingStride, sampledPixelCount, invalidPixelCount: Int
    public let confidenceAvailable: Bool
    public let pixels: [NativeDepthPixel]
    public init(source: Source, width: Int, height: Int, samplingStride: Int, sampledPixelCount: Int,
                invalidPixelCount: Int, confidenceAvailable: Bool, pixels: [NativeDepthPixel]) {
        self.source = source; self.width = width; self.height = height; self.samplingStride = samplingStride
        self.sampledPixelCount = sampledPixelCount; self.invalidPixelCount = invalidPixelCount
        self.confidenceAvailable = confidenceAvailable; self.pixels = pixels
    }
    public func validate() throws {
        guard (1...16384).contains(width), (1...16384).contains(height), (1...16384).contains(samplingStride),
              sampledPixelCount >= 0, invalidPixelCount >= 0,
              sampledPixelCount == pixels.count + invalidPixelCount, sampledPixelCount <= 4096,
              pixels.allSatisfy({ (0..<width).contains($0.column) && (0..<height).contains($0.row) &&
                  $0.column % samplingStride == 0 && $0.row % samplingStride == 0 &&
                  $0.metres.isFinite && $0.metres > 0 && $0.metres <= 100 &&
                  (confidenceAvailable ? ($0.confidence.map { $0 <= 2 } ?? false) : $0.confidence == nil) }),
              Set(pixels.map { $0.row * width + $0.column }).count == pixels.count else { throw NativeObservationError.invalidDepth }
    }
    public func worldPoints(intrinsics: NativeCameraIntrinsics, cameraToWorld: NativeCameraTransform,
                            convention: NativeCameraConvention) throws -> [Point3] {
        try validate()
        let k = try intrinsics.scaled(width: width, height: height)
        return try pixels.map { pixel in
            // Reuse the app's existing documented ARKit depth projection.
            guard let ar = DepthProjection(fx: k.fx, fy: k.fy, cx: k.cx, cy: k.cy)
                .cameraPoint(column: Double(pixel.column), row: Double(pixel.row), depth: pixel.metres) else { throw NativeObservationError.invalidDepth }
            let point = convention == .arKitRightUpBack ? ar : Point3(ar.x, -ar.y, -ar.z)
            return try cameraToWorld.applying(to: point)
        }
    }
}

/// Anchor-local vertices with their actual transform. Bounds/planes do not establish clearance.
public struct NativeSurfaceObservation: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case arkitPlane, arkitMesh, roomPlanSurface, roomPlanObject }
    public let sourceID: String
    public let kind: Kind
    public let localToSessionWorld: NativeCameraTransform
    public let vertices: [Point3]
    /// Flat triangle indices for mesh samples only. Plane polygon vertices preserve their order.
    public let triangleIndices: [Int]
    public let classification: String?
    public let triangleClassifications: [String]?
    public let horizontal: Bool?
    public let originalVertexCount, originalTriangleCount: Int
    public let truncated: Bool
    public init(sourceID: String, kind: Kind, localToSessionWorld: NativeCameraTransform, vertices: [Point3],
                triangleIndices: [Int] = [], classification: String? = nil, triangleClassifications: [String]? = nil, horizontal: Bool? = nil,
                originalVertexCount: Int, originalTriangleCount: Int = 0, truncated: Bool = false) {
        self.sourceID = sourceID; self.kind = kind; self.localToSessionWorld = localToSessionWorld; self.vertices = vertices
        self.triangleIndices = triangleIndices; self.classification = classification; self.triangleClassifications = triangleClassifications; self.horizontal = horizontal
        self.originalVertexCount = originalVertexCount; self.originalTriangleCount = originalTriangleCount; self.truncated = truncated
    }
    public func validate() throws {
        guard NativeObservationRecord.validID(sourceID), localToSessionWorld.valid, vertices.count <= 2048,
              vertices.allSatisfy(\.isFinite), triangleIndices.count <= 3072, triangleIndices.count % 3 == 0,
              triangleIndices.allSatisfy({ vertices.indices.contains($0) }), originalVertexCount >= vertices.count,
              originalTriangleCount >= triangleIndices.count / 3, classification.map({ NativeObservationRecord.validID($0) }) ?? true,
              triangleClassifications.map({ $0.count == triangleIndices.count / 3 && $0.allSatisfy(NativeObservationRecord.validID) }) ?? true,
              truncated || (originalVertexCount == vertices.count && originalTriangleCount == triangleIndices.count / 3) else { throw NativeObservationError.invalidSurface }
    }
}

public struct NativeObservationRecord: Codable, Equatable, Sendable {
    public enum Producer: String, Codable, Sendable { case arkit, arkitScenesRecorded }
    public enum Tracking: String, Codable, Sendable { case normal, limited, unavailable, notRecorded }
    public let schemaVersion: Int
    public let id: UUID
    public let sessionID: UUID
    public let coordinateFrameID: String
    public let producer: Producer
    public let sourceID: String
    /// A destination map is ownership metadata ONLY. Points remain in coordinateFrameID.
    /// Nil when the existing mapper/database has no registered binding.
    public let mapTarget: SpatialMapBinding?
    public let capturedAt: Double
    /// Original pose timestamp; recorded nearest-neighbor association is not interpolation.
    public let poseCapturedAt: Double
    public let poseSourceID: String?
    /// Nil for recorded replay. Do not compare a dataset clock to process uptime.
    public let receivedAt: Double?
    public let observedAt: Date?
    public let tracking: Tracking
    public let trackingReason: String?
    public let cameraConvention: NativeCameraConvention
    public let cameraToSessionWorld: NativeCameraTransform
    public let intrinsics: NativeCameraIntrinsics
    public let depth: NativeDepthObservation?
    public let surfaces: [NativeSurfaceObservation]
    /// Nil when anchor inspection itself was capped; unexamined anchors are unknown.
    public let originalSurfaceCount: Int?
    public let omitted: [String]
    public init(id: UUID = UUID(), sessionID: UUID, coordinateFrameID: String, producer: Producer, sourceID: String,
                mapTarget: SpatialMapBinding? = nil, capturedAt: Double, poseCapturedAt: Double? = nil, poseSourceID: String? = nil, receivedAt: Double?, observedAt: Date?,
                tracking: Tracking, trackingReason: String? = nil, cameraConvention: NativeCameraConvention,
                cameraToSessionWorld: NativeCameraTransform, intrinsics: NativeCameraIntrinsics,
                depth: NativeDepthObservation?, surfaces: [NativeSurfaceObservation] = [], originalSurfaceCount: Int? = 0,
                omitted: [String] = []) {
        schemaVersion = 1; self.id = id; self.sessionID = sessionID; self.coordinateFrameID = coordinateFrameID
        self.producer = producer; self.sourceID = sourceID; self.mapTarget = mapTarget; self.capturedAt = capturedAt
        self.poseCapturedAt = poseCapturedAt ?? capturedAt; self.poseSourceID = poseSourceID
        self.receivedAt = receivedAt; self.observedAt = observedAt; self.tracking = tracking; self.trackingReason = trackingReason
        self.cameraConvention = cameraConvention; self.cameraToSessionWorld = cameraToSessionWorld
        self.intrinsics = intrinsics; self.depth = depth; self.surfaces = surfaces; self.originalSurfaceCount = originalSurfaceCount
        self.omitted = omitted
    }
    /// These are not measurements supplied by ARFrame or this dataset. Never fill with zero.
    public var unavailableEvidence: [String] {
        ["bodyToCameraCalibration", "floorIdentity", "poseCovariance", "completeCorridorCoverage", "mapAlignment", "targetMeasurementAssociation"]
    }
    public var isHistoryOnly: Bool { true }
    public static func validID(_ value: String) -> Bool {
        !value.isEmpty && value.count <= 256 && value == value.trimmingCharacters(in: .whitespacesAndNewlines) &&
        !value.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) }
    }
    public func validate() throws {
        guard schemaVersion == 1, Self.validID(coordinateFrameID), Self.validID(sourceID),
              capturedAt.isFinite, capturedAt >= 0, poseCapturedAt.isFinite, poseCapturedAt >= 0,
              abs(poseCapturedAt - capturedAt) <= 0.01, poseSourceID.map(Self.validID) ?? true, observedAt.map({ $0.timeIntervalSince1970.isFinite && $0.timeIntervalSince1970 >= 0 }) ?? true,
              trackingReason.map(Self.validID) ?? true, omitted.count <= 16, omitted.allSatisfy(Self.validID),
              surfaces.count <= 32, originalSurfaceCount.map({ $0 >= surfaces.count }) ?? true else { throw NativeObservationError.invalidMetadata }
        if producer == .arkit {
            guard cameraConvention == .arKitRightUpBack, poseCapturedAt == capturedAt, let receivedAt, receivedAt.isFinite, receivedAt >= capturedAt,
                  receivedAt - capturedAt <= 1, observedAt != nil, tracking != .notRecorded else { throw NativeObservationError.invalidMetadata }
        } else {
            guard cameraConvention == .pinholeRightDownForward, receivedAt == nil, observedAt == nil, tracking == .notRecorded,
                  mapTarget == nil else { throw NativeObservationError.invalidMetadata }
        }
        if let target = mapTarget {
            guard Self.validID(target.mapID), Self.validID(target.frameID), Self.validID(target.revision),
                  target.frameID != coordinateFrameID else { throw NativeObservationError.invalidMetadata }
        }
        guard cameraToSessionWorld.valid else { throw NativeObservationError.invalidPose }
        guard intrinsics.valid else { throw NativeObservationError.invalidIntrinsics }
        if let depth {
            guard (producer == .arkit && depth.source == .arkitSceneDepth) ||
                  (producer == .arkitScenesRecorded && depth.source == .arkitScenesAppleDepth) else { throw NativeObservationError.invalidDepth }
            try depth.validate()
        }
        try surfaces.forEach { try $0.validate() }
    }
}

/// One immutable record encoded once. Encoded bytes are cached for quota accounting and
/// incremental persistence; neither the ring nor existing records are re-encoded per frame.
public struct NativeObservationEncodedRecord: Equatable, Sendable {
    public let record: NativeObservationRecord
    public let payload: Data
    public var id: UUID { record.id }
    public var sessionID: UUID { record.sessionID }
    public var capturedAt: Double { record.capturedAt }
    public var encodedBytes: Int { payload.count }
    public init(_ record: NativeObservationRecord) throws {
        try record.validate()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(record)
        guard !data.isEmpty, data.count <= NativeObservationHistory.maximumBytes else { throw NativeObservationError.sizeLimit }
        self.record = record; payload = data
    }
    public init(payload: Data) throws {
        guard !payload.isEmpty, payload.count <= NativeObservationHistory.maximumBytes else { throw NativeObservationError.sizeLimit }
        let record = try JSONDecoder().decode(NativeObservationRecord.self, from: payload)
        try record.validate(); self.record = record; self.payload = payload
    }
}

/// Bounded volatile recent history. Durability is separately reported by the pipeline.
/// This is not a SLAM map/database, inventory, or present-tense observation authority.
public struct NativeObservationHistory: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public private(set) var encodedRecords: [NativeObservationEncodedRecord]
    public var records: [NativeObservationRecord] { encodedRecords.map(\.record) }
    public private(set) var payloadByteCount: Int
    public private(set) var evictedRecordCount: Int
    public static let maximumRecords = 64
    public static let maximumBytes = 2 * 1024 * 1024
    public static let maximumEvictionCount = 1_000_000_000
    public init() { schemaVersion = 1; encodedRecords = []; payloadByteCount = 0; evictedRecordCount = 0 }
    public init(records: [NativeObservationEncodedRecord], evictedRecordCount: Int) throws {
        guard records.count <= Self.maximumRecords, (0...Self.maximumEvictionCount).contains(evictedRecordCount),
              Set(records.map(\.id)).count == records.count else { throw NativeObservationError.invalidArchive }
        var newest: [UUID: Double] = [:], bytes = 0
        for entry in records {
            guard newest[entry.sessionID].map({ entry.capturedAt > $0 }) ?? true else { throw NativeObservationError.outOfOrder }
            newest[entry.sessionID] = entry.capturedAt
            bytes += entry.encodedBytes
            guard bytes <= Self.maximumBytes else { throw NativeObservationError.sizeLimit }
        }
        schemaVersion = 1; encodedRecords = records; payloadByteCount = bytes; self.evictedRecordCount = evictedRecordCount
    }
    private enum CodingKeys: String, CodingKey { case schemaVersion, records, evictedRecordCount }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        guard try values.decode(Int.self, forKey: .schemaVersion) == 1 else { throw NativeObservationError.invalidArchive }
        let records = try values.decode([NativeObservationRecord].self, forKey: .records)
        guard records.count <= Self.maximumRecords else { throw NativeObservationError.sizeLimit }
        try self.init(records: records.map(NativeObservationEncodedRecord.init), evictedRecordCount: values.decode(Int.self, forKey: .evictedRecordCount))
    }
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(schemaVersion, forKey: .schemaVersion); try values.encode(records, forKey: .records)
        try values.encode(evictedRecordCount, forKey: .evictedRecordCount)
    }
    /// Compatibility/export only. The live sink never serializes a whole archive per append.
    public init(data: Data) throws {
        guard !data.isEmpty, data.count <= Self.maximumBytes + 8192 else { throw NativeObservationError.sizeLimit }
        self = try JSONDecoder().decode(Self.self, from: data)
    }
    public func encoded() throws -> Data { let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]; return try encoder.encode(self) }
    @discardableResult public mutating func append(_ record: NativeObservationRecord) throws -> NativeObservationEncodedRecord {
        let entry = try NativeObservationEncodedRecord(record); try append(entry); return entry
    }
    public mutating func append(_ entry: NativeObservationEncodedRecord) throws {
        guard !encodedRecords.contains(where: { $0.id == entry.id }) else { throw NativeObservationError.duplicate }
        guard encodedRecords.last(where: { $0.sessionID == entry.sessionID }).map({ entry.capturedAt > $0.capturedAt }) ?? true else { throw NativeObservationError.outOfOrder }
        var next = self; next.encodedRecords.append(entry); next.payloadByteCount += entry.encodedBytes
        while next.encodedRecords.count > Self.maximumRecords || next.payloadByteCount > Self.maximumBytes {
            guard next.evictedRecordCount < Self.maximumEvictionCount else { throw NativeObservationError.invalidArchive }
            next.payloadByteCount -= next.encodedRecords.removeFirst().encodedBytes; next.evictedRecordCount += 1
        }
        self = next
    }
}
