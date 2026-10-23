import Foundation

/// Resource ownership is independent of a request's logical lifetime. Vision may
/// ignore cancellation while inside a synchronous native call, so only its exact
/// completion may free the slot. The caller serializes access on the main actor.
public struct ColorInspectionWork: Sendable {
    public enum Owner: Equatable, Sendable {
        case requested(UUID)
        case contextual(UUID)
    }
    public struct Lease: Equatable, Sendable {
        public let id: UUID
        public let owner: Owner
        public let startedAt: Double
    }
    public enum CompletionDisposition: Equatable, Sendable {
        case ignore, unavailable, useResult
    }
    public static let requestedLifetime: Double = 6
    public private(set) var nativeLease: Lease?
    public private(set) var requestedLease: Lease?
    public var isAvailable: Bool { nativeLease == nil }

    public init() {}

    public mutating func begin(owner: Owner, now: Double) -> Lease? {
        guard isAvailable, now.isFinite else { return nil }
        let lease = Lease(id: UUID(), owner: owner, startedAt: now)
        nativeLease = lease
        if case .requested = owner { requestedLease = lease }
        return lease
    }

    public func ownsRequested(_ lease: Lease) -> Bool {
        requestedLease?.id == lease.id && nativeLease?.id == lease.id
    }

    /// Loss of request/session/privacy ownership is silent. A still-owned request
    /// with unusable capture evidence instead needs an honest unavailable answer.
    public func completionDisposition(_ lease: Lease, ownerAllowed: Bool,
                                      captureAllowed: Bool) -> CompletionDisposition {
        guard ownsRequested(lease), ownerAllowed else { return .ignore }
        return captureAllowed ? .useResult : .unavailable
    }

    @discardableResult public mutating func retireRequested(_ lease: Lease) -> Bool {
        guard requestedLease?.id == lease.id else { return false }
        requestedLease = nil
        return true
    }

    public mutating func cancelRequested() { requestedLease = nil }

    /// A timeout ends the user's wait, not the native operation. No replacement
    /// can start until completeNative is called with that exact operation's lease.
    public mutating func expireRequested(now: Double) -> Lease? {
        guard let lease = requestedLease, now.isFinite,
              now >= lease.startedAt,
              now - lease.startedAt >= Self.requestedLifetime else { return nil }
        requestedLease = nil
        return lease
    }

    @discardableResult public mutating func completeNative(_ lease: Lease) -> Bool {
        guard nativeLease?.id == lease.id else { return false }
        nativeLease = nil
        return true
    }
}
