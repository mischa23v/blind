import Foundation

/// Main-queue-owned revision tokens for asynchronous readers/writers. Deleting a record or ending
/// a session invalidates already queued work without preventing a later explicit enrollment.
public struct WorkRevision: Sendable {
    public struct Token: Equatable, Sendable {
        fileprivate let session: UUID
        fileprivate let record: UUID?
        fileprivate let key: String
    }
    private var session = UUID()
    private var records: [String: UUID] = [:]
    public init() {}
    public func token(for key: String) -> Token { Token(session: session, record: records[key], key: key) }
    public func accepts(_ token: Token) -> Bool { token.session == session && token.record == records[token.key] }
    public mutating func invalidate(_ key: String) { records[key] = UUID() }
    public mutating func invalidateAll() { session = UUID(); records.removeAll() }
}
