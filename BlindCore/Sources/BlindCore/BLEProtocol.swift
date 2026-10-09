import Foundation

public enum WearableRole: UInt8, Codable, Sendable { case belt = 1, wrist = 2 }

public struct WearablePacket: Equatable, Sendable {
    public static let serviceUUID = "594A0001-B5A3-4F7D-8F16-A962EAF724A0"
    public static let telemetryUUID = "594A0002-B5A3-4F7D-8F16-A962EAF724A0"
    public static let commandUUID = "594A0003-B5A3-4F7D-8F16-A962EAF724A0"
    public static let length = 20
    public var role: WearableRole
    public var flags: UInt8
    public var sequence: UInt8
    /// Eight clockwise sectors starting at the front. 65535 means UNKNOWN.
    public var distancesMM: [UInt16]
    public var hasFault: Bool { flags & 1 != 0 }
    public var isCalibrated: Bool { flags & 16 != 0 }
    public var hazard: Hazard {
        if flags & 2 != 0 { return .drop }
        if flags & 8 != 0 { return .overhead }
        if flags & 4 != 0 { return .obstacle }
        if hasFault { return .uncertain }
        return isCalibrated ? .observing : .needsCalibration
    }
    public init(role: WearableRole, flags: UInt8, sequence: UInt8, distancesMM: [UInt16]) {
        precondition(distancesMM.count == 8)
        self.role = role; self.flags = flags; self.sequence = sequence; self.distancesMM = distancesMM
    }
    public init?(data: Data) {
        let bytes = Array(data)
        guard bytes.count == Self.length, bytes[0] == 1, let role = WearableRole(rawValue: bytes[1]),
              bytes[2] & 0xC0 == 0,
              bytes[2] & 32 == 0 || bytes[2] & 4 != 0 else { return nil }
        self.role = role; flags = bytes[2]; sequence = bytes[3]
        distancesMM = stride(from: 4, to: 20, by: 2).map { UInt16(bytes[$0]) | UInt16(bytes[$0 + 1]) << 8 }
    }
    public var data: Data {
        var result = [UInt8(1), role.rawValue, flags, sequence]
        for distance in distancesMM { result += [UInt8(distance & 255), UInt8(distance >> 8)] }
        return Data(result)
    }
    public var detection: Detection {
        // v1 reports body ranges, not the location/range of downward or overhead returns.
        if hazard == .drop || hazard == .overhead || flags & 32 != 0 { return Detection(hazard, sector: 0) }
        let measured = distancesMM.enumerated().filter { $0.element != UInt16.max }
        let nearest = measured.min { $0.element < $1.element }
        return Detection(hazard, distance: nearest.map { Double($0.element) / 1000 },
                         sector: nearest?.offset ?? 0)
    }
}

public enum WearableCommand {
    /// Version, command, sector, intensity, duration in 10 ms units, reserved.
    public static func haptic(sector: Int, intensity: UInt8 = 170, durationMS: Int = 200) -> Data {
        Data([1, 1, UInt8(clamping: min(7, max(0, sector))), intensity,
              UInt8(clamping: min(50, max(1, durationMS / 10))), 0])
    }
    public static let calibrate = Data([1, 2, 0, 0, 0, 0])
    public static let identify = Data([1, 3, 0, 100, 20, 0])
}

public struct PacketFreshness: Sendable {
    private var lastSequence: UInt8?
    public private(set) var lastReceived: Double?
    public init() {}
    public mutating func accept(_ packet: WearablePacket, at timestamp: Double) -> Bool {
        guard timestamp.isFinite else { return false }
        if let lastReceived, timestamp < lastReceived { return false }
        if let sequence = lastSequence {
            let delta = packet.sequence &- sequence
            if delta == 0 || delta > 127 { return false }
        }
        lastSequence = packet.sequence; lastReceived = timestamp; return true
    }
    public func isFresh(at timestamp: Double) -> Bool {
        guard let lastReceived else { return false }
        return timestamp.isFinite && timestamp >= lastReceived && timestamp - lastReceived <= 0.8
    }
}
