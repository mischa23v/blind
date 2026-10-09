import Foundation

public struct SensorMeasurement: Equatable, Sendable {
    public static let characteristicUUID = "594A0004-B5A3-4F7D-8F16-A962EAF724A0"
    public var role: WearableRole
    public var sensor: UInt8
    public var uptimeMS: UInt32
    public var sequence: UInt8
    public var rangesMM: [UInt16]
    public var receivedAt: Double
    public func isFresh(at now: Double) -> Bool { now.isFinite && now >= receivedAt && now - receivedAt <= 0.3 }
    /// Receipt time supports stale-data rejection, not cross-device SLAM synchronization.
    public var validZones: Int { rangesMM.filter { $0 != UInt16.max }.count }
}

public struct MeasurementAssembler: Sendable {
    private struct Partial: Sendable {
        var sample: SensorMeasurement
        var parts = Set<UInt8>()
        var startedAt: Double
    }
    private var partials: [UInt8: Partial] = [:]
    private var completed: [UInt8: UInt32] = [:]
    public init() {}
    public mutating func accept(_ data: Data, role: WearableRole, at now: Double) -> SensorMeasurement? {
        let bytes = Array(data)
        guard now.isFinite, bytes.count == 20, bytes[0] == 2, bytes[1] == role.rawValue else { return nil }
        let sensor = bytes[2], part = bytes[3], count = Int(bytes[9])
        let expected = role == .belt && (2...9).contains(sensor) ? 16 : 1
        guard sensor <= (role == .belt ? 11 : 0), count == expected, Int(part) < (count + 4) / 5 else { return nil }
        let time = (0..<4).reduce(UInt32(0)) { $0 | UInt32(bytes[4+$1]) << ($1*8) }
        if let previous = completed[sensor] {
            let elapsed = time &- previous
            guard elapsed > 0, elapsed < 0x80000000 else { return nil }
        }
        if let old = partials[sensor], now < old.startedAt || now - old.startedAt > 0.25 {
            // Reject the entire timed-out frame, including fragments arriving after expiration.
            completed[sensor] = old.sample.uptimeMS; partials.removeValue(forKey: sensor)
            guard time != old.sample.uptimeMS else { return nil }
        }
        if let old = partials[sensor], old.sample.uptimeMS != time {
            let elapsed = time &- old.sample.uptimeMS
            guard elapsed > 0, elapsed < 0x80000000 else { return nil }
            partials.removeValue(forKey: sensor)
        }
        var value = partials[sensor] ?? Partial(sample: SensorMeasurement(role: role, sensor: sensor, uptimeMS: time,
            sequence: bytes[8], rangesMM: Array(repeating: .max, count: count), receivedAt: now), startedAt: now)
        guard value.sample.sequence == bytes[8], !value.parts.contains(part) else { return nil }
        for i in 0..<5 {
            let range = UInt16(bytes[10+i*2]) | UInt16(bytes[11+i*2]) << 8
            let index = Int(part) * 5 + i
            if index < count { value.sample.rangesMM[index] = range }
            else if range != .max { return nil }
        }
        value.parts.insert(part); partials[sensor] = value
        guard value.parts.count == (count + 4) / 5 else { return nil }
        completed[sensor] = time; partials.removeValue(forKey: sensor)
        return value.sample
    }
}
