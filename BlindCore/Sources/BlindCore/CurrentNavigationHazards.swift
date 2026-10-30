import Foundation

/// Ownership adapter for existing phone hazard results. Observing is NOT a
/// clearance verdict or full-footprint floor support. No points are reclassified.
public struct CurrentNavigationHazards: Sendable {
    public struct Receipt: Equatable, Sendable {
        public let sessionID: UUID
        public let capturedAt: Double
        public let detection: Detection
        public let estimatedFloorHeight: Double?
        public var fullFootprintSupportKnown: Bool { false }
        public var authorizesPhysicalGuidance: Bool { false }
    }
    public enum Unknown: String, Sendable { case inactive, wrongSession, missing, stale, trackingLost, invalid, outOfOrder }
    public enum State: Equatable, Sendable {
        case unknown(Unknown)
        case hazard(Receipt)
        case observing(Receipt)
        public var permitsFurtherIndependentChecks: Bool {
            if case .observing = self { return true }; return false
        }
    }
    private var sessionID: UUID?
    private var latest: Receipt?
    private var highWater = -Double.infinity
    private var reason: Unknown = .inactive
    public init() {}
    public mutating func begin(sessionID: UUID) {
        self.sessionID = sessionID; latest = nil; highWater = -.infinity; reason = .missing
    }
    public mutating func invalidate() { latest = nil; reason = .missing }
    public mutating func stop() { self = Self() }
    @discardableResult public mutating func consume(sessionID: UUID, capturedAt: Double,
        receivedAt: Double, trackingNormal: Bool, detection: Detection,
        estimatedFloorHeight: Double?) -> State {
        guard self.sessionID == sessionID else { return .unknown(.wrongSession) }
        // Delayed duplicate callbacks cannot replace or extend a newer receipt.
        guard capturedAt.isFinite, capturedAt >= 0, receivedAt.isFinite, receivedAt >= 0 else {
            latest = nil; reason = .invalid; return .unknown(reason)
        }
        guard trackingNormal else { latest = nil; reason = .trackingLost; return .unknown(reason) }
        guard capturedAt > highWater else { return .unknown(.outOfOrder) }
        guard FrameTimestampPolicy.isFresh(capturedAt: capturedAt, receivedAt: receivedAt) else {
            latest = nil; reason = .stale; return .unknown(reason)
        }
        highWater = capturedAt
        guard detection.coverage.isFinite, (0...1).contains(detection.coverage),
              detection.distance.map({ $0.isFinite && $0 >= 0 }) ?? true,
              estimatedFloorHeight.map({ $0.isFinite }) ?? true else {
            latest = nil; reason = .invalid; return .unknown(reason)
        }
        latest = Receipt(sessionID: sessionID, capturedAt: capturedAt, detection: detection,
                         estimatedFloorHeight: estimatedFloorHeight)
        return state(sessionID: sessionID, now: receivedAt)
    }
    public func state(sessionID: UUID, now: Double) -> State {
        guard self.sessionID == sessionID else { return .unknown(.wrongSession) }
        guard let latest else { return .unknown(reason) }
        guard FrameTimestampPolicy.isFresh(capturedAt: latest.capturedAt, receivedAt: now) else { return .unknown(.stale) }
        return latest.detection.hazard == .observing ? .observing(latest) : .hazard(latest)
    }
    public func isCurrent(_ receipt: Receipt, sessionID: UUID, now: Double) -> Bool {
        switch state(sessionID: sessionID, now: now) {
        case .observing(let current), .hazard(let current): return current == receipt
        case .unknown: return false
        }
    }
}
