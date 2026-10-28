import Foundation

/// Typed local archive events; no image/audio/free-text payloads or output authority.
public enum NavigationTestArchiveEvent: Codable, Equatable, Sendable {
    case plan(NavigationTestRecording.Plan)
    case sample(NavigationTestRecording.Entry)
    case marker(NavigationTestRecording.Marker)
    case ended(status: NavigationTestRecording.Status, at: Double)

    public static let maximumBytes = 262_144
    public func encoded() throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(self)
        guard !data.isEmpty, data.count <= Self.maximumBytes else { throw NavigationTestRecording.Failure.invalidInput }
        return data
    }
    public init(payload: Data) throws {
        guard !payload.isEmpty, payload.count <= Self.maximumBytes else { throw NavigationTestRecording.Failure.invalidInput }
        self = try JSONDecoder().decode(Self.self, from: payload)
        // Full sequence/geometry validation belongs to NavigationTestRecording.restored.
    }
}
