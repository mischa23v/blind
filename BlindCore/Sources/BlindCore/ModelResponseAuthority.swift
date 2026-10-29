import Foundation

/// Request ownership/provenance, not a semantic classifier or navigation readiness.
/// A physical/dedicated request cannot be fulfilled by a model, even with "yes".
/// A valid route never promotes model prose into code-owned physical guidance.
/// Language admission remains bounded by the existing domain/evidence guards.
public struct ModelResponseAuthority: Sendable {
    public struct Binding: Equatable, Sendable {
        public let requestID: UUID
        public let sessionGeneration: UInt64
        public let goalRevision: String
        public init(requestID: UUID, sessionGeneration: UInt64, goalRevision: String) {
            self.requestID = requestID; self.sessionGeneration = sessionGeneration
            self.goalRevision = goalRevision
        }
    }
    public enum Owner: Equatable, Sendable { case conversation, physicalRequest, dedicatedRequest }
    public enum Producer: Equatable, Sendable { case conversation, sceneDescription }
    public struct Lease: Sendable {
        public let id: UUID
        public let binding: Binding
        public let producer: Producer
        public let text: String
        public let reports: [String]
        public let evidence: [CompanionEvidence]
        public let createdAt: Double
        public let expiresAt: Double
        fileprivate let ownerID: UUID
        fileprivate init(binding: Binding, producer: Producer, text: String, reports: [String],
                         evidence: [CompanionEvidence], createdAt: Double, expiresAt: Double, ownerID: UUID) {
            id = UUID(); self.binding = binding; self.producer = producer; self.text = text
            self.reports = reports; self.evidence = evidence; self.createdAt = createdAt
            self.expiresAt = expiresAt; self.ownerID = ownerID
        }
    }
    private struct Request: Sendable {
        let id: UUID
        let binding: Binding
        let owner: Owner
        let producer: Producer
        let startedAt: Double
    }
    private var request: Request?
    public var owner: Owner? { request?.owner }
    public init() {}

    /// Called for the original request before inference. Missing geometry does
    /// not change physical ownership into conversation. A new chat turn is a
    /// separate owner; it need not erase a retained navigation goal.
    public mutating func begin(question: String, binding: Binding, producer: Producer = .conversation,
                               at startedAt: Double = ProcessInfo.processInfo.systemUptime) {
        guard startedAt.isFinite, startedAt >= 0 else { request = nil; return }
        let owner: Owner = ConversationDomainPolicy.requiresPhysicalVerification(for: question) ? .physicalRequest
            : ConversationDomainPolicy.allowsModelResponse(to: question) ? .conversation : .dedicatedRequest
        request = Request(id: UUID(), binding: binding, owner: owner, producer: producer, startedAt: startedAt)
    }
    public mutating func invalidate() { request = nil }
    /// Ambient interruptions retire ordinary chat without canceling a separate
    /// scene request or changing the sensor/navigation request identity.
    public mutating func invalidateConversation() {
        if request?.producer == .conversation { request = nil }
    }

    /// Scene callers must already have applied VisualGrounding and their capture
    /// gates. This lease cannot establish camera facts, geometry or clearance.
    public func admit(_ text: String, producer: Producer = .conversation, binding: Binding,
                      reports: [String] = [], evidence: [CompanionEvidence] = [],
                      createdAt: Double, now: Double, date: Date = Date()) -> Lease? {
        guard let request, request.owner == .conversation, request.binding == binding, request.producer == producer,
              createdAt.isFinite, now.isFinite, createdAt >= 0, now >= createdAt,
              now >= request.startedAt,
              now - min(createdAt, request.startedAt) < lifetime(producer),
              Self.allows(text, producer: producer, reports: reports, evidence: evidence, date: date) else { return nil }
        // Partial/final/display/queue admissions share the original request's
        // deadline. Re-admitting identical text later cannot renew that deadline.
        let originalStart = min(createdAt, request.startedAt)
        return Lease(binding: binding, producer: producer, text: text, reports: reports, evidence: evidence,
                     createdAt: originalStart, expiresAt: originalStart + lifetime(producer), ownerID: request.id)
    }
    /// Repetition reuses the exact original lease. No deadline or ownership can
    /// be refreshed by copying text, reclassifying it, or borrowing a route ticket.
    public func permits(_ lease: Lease, text: String, binding: Binding, now: Double, date: Date = Date()) -> Bool {
        guard let request, request.owner == .conversation, request.id == lease.ownerID,
              request.binding == binding, lease.binding == binding, request.producer == lease.producer,
              lease.text.utf8.elementsEqual(text.utf8), now.isFinite,
              now >= request.startedAt, now >= lease.createdAt, now < lease.expiresAt else { return false }
        return Self.allows(text, producer: lease.producer, reports: lease.reports, evidence: lease.evidence, date: date)
    }
    private func lifetime(_ producer: Producer) -> Double { producer == .conversation ? 30 : 6 }
    private static func allows(_ text: String, producer: Producer, reports: [String], evidence: [CompanionEvidence], date: Date) -> Bool {
        guard !text.isEmpty, text.unicodeScalars.count <= 2000,
              !SpatialClaimGuard.containsSpatialClaim(text) else { return false }
        return producer == .sceneDescription || CompanionEvidenceGuard.allows(text, reports: reports, evidence: evidence, now: date)
    }
}
