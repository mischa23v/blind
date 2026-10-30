import Foundation

/// Scalar-only capture; no image or ARFrame. Session is the exclusive bench owner.
public struct MeshBenchCameraCapture: Equatable, Sendable {
    public let session: UUID, frame: UUID, snapshot: UUID
    public let capturedAt: Double
    public let columnMajorCameraToWorld: [Double]
    public init(session: UUID, frame: UUID, snapshot: UUID = UUID(), capturedAt: Double, columnMajorCameraToWorld: [Double]) {
        self.session = session; self.frame = frame; self.snapshot = snapshot; self.capturedAt = capturedAt
        self.columnMajorCameraToWorld = columnMajorCameraToWorld
    }
}
/// Separate latest-cache and explicit diagnostic-snapshot identities. A routine
/// frame never substitutes for or retires a frozen request. Historical lifetime
/// is bounded to eight seconds, NOT a physical-guidance freshness allowance.
final class MeshBenchCameraSnapshot {
    private let lock = NSLock()
    private var latest: MeshBenchCameraCapture?, frozen: MeshBenchCameraCapture?
    func observe(_ value: MeshBenchCameraCapture?) {
        lock.lock(); defer { lock.unlock() }
        if latest?.session != value?.session { frozen = nil }
        latest = value
    }
    func freeze(at now: Double) -> MeshBenchCameraCapture? {
        lock.lock(); defer { lock.unlock() }
        frozen = nil
        guard let latest, valid(latest, now: now, age: 0.5) else { return nil }
        frozen = .init(session: latest.session, frame: latest.frame, capturedAt: latest.capturedAt, columnMajorCameraToWorld: latest.columnMajorCameraToWorld)
        return frozen
    }
    func canAdmit(_ value: MeshBenchCameraCapture, at now: Double) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return frozen == value && latest?.session == value.session && valid(value, now: now, age: 0.5)
    }
    func isCurrent(_ value: MeshBenchCameraCapture, at now: Double) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return frozen == value && latest?.session == value.session && valid(value, now: now, age: 8)
    }
    func retire() { lock.lock(); frozen = nil; lock.unlock() }
    private func valid(_ value: MeshBenchCameraCapture, now: Double, age: Double) -> Bool {
        now.isFinite && value.capturedAt.isFinite && value.capturedAt >= 0 &&
        now >= value.capturedAt && now - value.capturedAt <= age &&
        value.columnMajorCameraToWorld.count == 16 && value.columnMajorCameraToWorld.allSatisfy(\.isFinite)
    }
}
