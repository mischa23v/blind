#if DEBUG
import Foundation

/// Developer diagnostics, not user history or an evidence source for the assistant.
/// No network, media, sensor access, model calls, or release-build implementation.
public final class DebugSessionLog: @unchecked Sendable {
    public static let launchArgument = "--blind-debug-session-log"
    public static let shared: DebugSessionLog? = {
        guard ProcessInfo.processInfo.arguments.contains(launchArgument),
              let directory = defaultDirectory else { return nil }
        return DebugSessionLog(directory: directory, enabled: true)
    }()

    public struct SessionToken: Equatable, Sendable {
        fileprivate let id: UUID
    }

    public enum Kind: String, Codable, Sendable {
        case sessionStarted, userInput, modelRequest, modelResponseChunk, modelResponse
        case toolCall, toolResult, outputGate
        case speechRequested, speechStarted, speechCompleted, speechInterrupted, speechRejected
        case unavailable, sessionEnded
    }

    public enum Source: String, Codable, Sendable {
        case userTyped, unverifiedMicrophone, verifiedCommand, onDeviceModel
        case toolRuntime, outputGate, speechEngine, appLifecycle, recorder
    }

    /// Supply IDs from the actual originating operation, never the latest global request.
    /// A UUID does not imply authoritative speaker identity, valid evidence, or audible delivery.
    public struct Correlation: Codable, Sendable {
        public let request: String
        public let toolCall: String
        public let utterance: String
        public init(requestID: UUID? = nil, toolCallID: UUID? = nil, utteranceID: UUID? = nil) {
            request = requestID?.uuidString ?? "unbound"
            toolCall = toolCallID?.uuidString ?? "unbound"
            utterance = utteranceID?.uuidString ?? "unbound"
        }
    }

    /// Only already-existing, non-secret textual diagnostic values. Do not generate
    /// extra observations, serialize media/embeddings, or request hidden reasoning.
    /// Text is exact within the byte bound unless explicitly marked redacted/truncated.
    public struct Detail: Sendable {
        public var text: String?
        public var label: String?
        public init(text: String? = nil, label: String? = nil) {
            self.text = text
            self.label = label
        }
    }

    public enum StopReason: String, Codable, Sendable {
        case completed, sessionLimit, retentionLimit, writeError, privacyCleared, purgeFailed
    }

    public struct Metrics: Codable, Sendable {
        public fileprivate(set) var admitted = 0
        public fileprivate(set) var written = 0
        public fileprivate(set) var dropped = 0
        public fileprivate(set) var staleCallbacks = 0
        public fileprivate(set) var truncatedFields = 0
        public fileprivate(set) var redactedFields = 0
        public fileprivate(set) var writeErrors = 0
        public fileprivate(set) var priorUncleanSessions = 0
        public fileprivate(set) var stopReason: StopReason?
    }

    struct Limits: Sendable {
        var sessionBytes = 8 * 1024 * 1024
        var retainedBytes = 32 * 1024 * 1024
        var pendingEvents = 128
        var retainedFiles = 512
        var textBytes = 8 * 1024
        var labelBytes = 128
        var recordBytes = 64 * 1024
        var terminalReserve = 4 * 1024
    }

    private struct TextField: Codable, Sendable {
        let value: String
        let truncated: Bool
        let redacted: Bool
    }

    private struct Record: Codable, Sendable {
        let schema = 1
        let session: UUID
        let event: UUID
        var sequence: UInt64
        let monotonicNanoseconds: UInt64
        let kind: Kind
        let source: Source
        let correlation: Correlation
        let text: TextField?
        let label: TextField?
        var metrics: Metrics?
    }

    public let sessionToken: SessionToken
    private let directory: URL
    private let limits: Limits
    private let queue = DispatchQueue(label: "BlindAssist.DebugSessionLog", qos: .utility)
    private let lock = NSLock()
    // The lock protects admission, counters, and the privacy fence only. No file IO
    // or encoding occurs while held; queued snapshots have bounded retained text.
    private var accepting: Bool
    private var purged = false
    private var purgeSucceeded: Bool?
    private var pending = 0
    private var metrics = Metrics()
    // Writer-queue-only state.
    private var handle: FileHandle?
    private var marker: URL?
    private var sessionBytes = 0
    private var retainedBytes = 0
    private var sequence: UInt64 = 0
    private var finalized = false
    private let write: @Sendable (FileHandle, Data) throws -> Void

    // Internal injection supports isolated XCTest without a global launch opt-in.
    // Production callers use the once-per-process immutable `shared` instance.
    init(directory: URL, enabled: Bool, limits: Limits = Limits(),
         write: @escaping @Sendable (FileHandle, Data) throws -> Void = { try $0.write(contentsOf: $1) }) {
        precondition(limits.terminalReserve >= 2048 && limits.sessionBytes > limits.terminalReserve)
        precondition(limits.retainedBytes >= limits.sessionBytes && limits.pendingEvents > 0)
        precondition((1...8192).contains(limits.textBytes) && (1...128).contains(limits.labelBytes))
        precondition(limits.recordBytes >= 2048 && limits.recordBytes <= 65536)
        self.directory = directory
        self.limits = limits
        self.accepting = enabled
        self.write = write
        self.sessionToken = SessionToken(id: UUID())
        if enabled {
            queue.async {
                self.open()
                self.finalize()
            }
        }
    }

    /// Disabled/stale/full fast path does not evaluate `detail` or serialize anything.
    /// Keep the closure cheap: read existing values only, never call a sensor/model.
    @discardableResult
    public func record(_ kind: Kind, source: Source, session: SessionToken,
                       correlation: Correlation = Correlation(),
                       detail: () -> Detail = { Detail() }) -> UUID? {
        lock.lock()
        guard accepting, !purged else { lock.unlock(); return nil }
        guard session == sessionToken else {
            metrics.staleCallbacks += 1
            metrics.dropped += 1
            lock.unlock()
            return nil
        }
        guard kind != .sessionStarted, kind != .sessionEnded, pending < limits.pendingEvents else {
            metrics.dropped += 1
            lock.unlock()
            return nil
        }
        pending += 1
        metrics.admitted += 1
        lock.unlock()

        let admittedAt = DispatchTime.now().uptimeNanoseconds
        let value = detail()
        let text = bounded(value.text, maximum: limits.textBytes)
        let label = bounded(value.label, maximum: limits.labelBytes)
        let event = UUID()
        let record = Record(session: session.id, event: event, sequence: 0,
                            monotonicNanoseconds: admittedAt,
                            kind: kind, source: source, correlation: correlation,
                            text: text, label: label, metrics: nil)
        lock.lock()
        metrics.truncatedFields += [text, label].compactMap { $0 }.filter(\.truncated).count
        metrics.redactedFields += [text, label].compactMap { $0 }.filter(\.redacted).count
        lock.unlock()
        queue.async {
            self.append(record)
            self.lock.lock()
            self.pending -= 1
            let shouldFinish = self.pending == 0 && !self.accepting
            self.lock.unlock()
            if shouldFinish { self.finalize() }
        }
        return event
    }

    public func snapshot() -> Metrics {
        lock.lock()
        defer { lock.unlock() }
        return metrics
    }

    /// An explicit clean lifecycle end. iOS termination is not guaranteed to run it.
    public func finish(session: SessionToken) {
        lock.lock()
        guard session == sessionToken, !purged, accepting else { lock.unlock(); return }
        accepting = false
        if metrics.stopReason == nil { metrics.stopReason = .completed }
        lock.unlock()
        queue.async { self.finalize() }
    }

    /// Fences callbacks immediately; deletion completes asynchronously. No restart
    /// API exists. A new process with an explicit launch opt-in is required.
    public func purge(completion: @escaping @Sendable (Bool) -> Void = { _ in }) {
        lock.lock()
        guard !purged || purgeSucceeded == false else {
            let succeeded = purgeSucceeded == true
            lock.unlock()
            completion(succeeded)
            return
        }
        accepting = false
        purged = true
        purgeSucceeded = nil
        metrics.stopReason = .privacyCleared
        lock.unlock()
        queue.async {
            self.finalized = true
            var success = true
            if let handle = self.handle {
                do { try handle.close() } catch { self.noteWriteError(); success = false }
            }
            self.handle = nil
            do { try Self.removeOwnedFiles(in: self.directory) } catch {
                self.noteWriteError()
                success = false
            }
            self.lock.lock()
            self.metrics.stopReason = success ? .privacyCleared : .purgeFailed
            self.purgeSucceeded = success
            self.lock.unlock()
            completion(success)
        }
    }

    /// Privacy clearing must remove prior logs even when this launch did not opt in.
    /// Referencing `shared` here also resolves the launch latch before the purge.
    public static func purgeForPrivacyClear(completion: @escaping @Sendable (Bool) -> Void = { _ in }) {
        if let recorder = shared { recorder.purge(completion: completion); return }
        guard let directory = defaultDirectory else { completion(false); return }
        DispatchQueue.global(qos: .utility).async {
            do { try removeOwnedFiles(in: directory); completion(true) }
            catch { completion(false) }
        }
    }

    // Test-only synchronization; production/hazard/audio paths never wait for IO.
    func drainForTesting() { queue.sync {} }

    private static var defaultDirectory: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("BlindDebugSessions", isDirectory: true)
    }

    private func open() {
        lock.lock()
        let cancelled = purged
        lock.unlock()
        guard !cancelled else { return }
        do {
            let manager = FileManager.default
            if manager.fileExists(atPath: directory.path) { try Self.rejectSymlink(directory) }
            var attributes: [FileAttributeKey: Any] = [.posixPermissions: 0o700]
            #if os(iOS)
            attributes[.protectionKey] = FileProtectionType.complete
            #endif
            try manager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: attributes)
            #if os(iOS) || os(macOS)
            var url = directory
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try url.setResourceValues(values)
            #endif
            var enumerationError: Error?
            guard let files = manager.enumerator(at: directory,
                includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey],
                options: [.skipsSubdirectoryDescendants],
                errorHandler: { _, error in enumerationError = error; return false }) else {
                throw LogError.invalidDirectory
            }
            // Stream metadata with a file-count bound, including zero-byte markers.
            // Count every regular file, not just recognized logs; never silently evict.
            var fileCount = 0
            for case let file as URL in files {
                fileCount += 1
                guard fileCount <= limits.retainedFiles - 2 else { stop(.retentionLimit); return }
                try Self.rejectSymlink(file)
                let values = try file.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
                guard values.isRegularFile == true else { throw LogError.invalidDirectory }
                let size = values.fileSize ?? 0
                guard size >= 0, size <= limits.retainedBytes - retainedBytes else {
                    stop(.retentionLimit); return
                }
                retainedBytes += size
                if Self.isOwned(file), file.pathExtension == "open" {
                    lock.lock(); metrics.priorUncleanSessions += 1; lock.unlock()
                }
            }
            if let enumerationError { throw enumerationError }
            guard retainedBytes <= limits.retainedBytes - limits.terminalReserve - 1024 else {
                stop(.retentionLimit); return
            }
            let basename = sessionToken.id.uuidString
            let markerURL = directory.appendingPathComponent(basename + ".open")
            let logURL = directory.appendingPathComponent(basename + ".jsonl")
            var fileAttributes: [FileAttributeKey: Any] = [.posixPermissions: 0o600]
            #if os(iOS)
            fileAttributes[.protectionKey] = FileProtectionType.complete
            #endif
            guard !manager.fileExists(atPath: logURL.path), !manager.fileExists(atPath: markerURL.path),
                  manager.createFile(atPath: markerURL.path, contents: Data(), attributes: fileAttributes),
                  manager.createFile(atPath: logURL.path, contents: Data(), attributes: fileAttributes) else {
                throw LogError.creationFailed
            }
            marker = markerURL
            handle = try FileHandle(forWritingTo: logURL)
            append(control(.sessionStarted))
        } catch { noteWriteError() }
    }

    private func append(_ candidate: Record) {
        lock.lock()
        let mayWrite = !purged && (metrics.stopReason == nil || metrics.stopReason == .completed)
        lock.unlock()
        guard mayWrite, !finalized, let handle else {
            if candidate.kind != .sessionStarted { lock.lock(); metrics.dropped += 1; lock.unlock() }
            return
        }
        do {
            var record = candidate
            record.sequence = sequence
            record.metrics = snapshot()
            let data = try encoded(record)
            guard data.count <= limits.recordBytes else {
                lock.lock(); metrics.dropped += 1; lock.unlock(); return
            }
            guard data.count <= limits.sessionBytes - limits.terminalReserve - sessionBytes else {
                lock.lock(); metrics.dropped += 1; lock.unlock(); stop(.sessionLimit); return
            }
            guard data.count <= limits.retainedBytes - limits.terminalReserve - retainedBytes else {
                lock.lock(); metrics.dropped += 1; lock.unlock(); stop(.retentionLimit); return
            }
            try write(handle, data)
            sequence += 1
            sessionBytes += data.count
            retainedBytes += data.count
            lock.lock(); metrics.written += 1; lock.unlock()
        } catch { noteWriteError() }
    }

    private func stop(_ reason: StopReason) {
        lock.lock()
        accepting = false
        if metrics.stopReason == nil { metrics.stopReason = reason }
        lock.unlock()
    }

    private func noteWriteError() {
        lock.lock()
        accepting = false
        metrics.writeErrors += 1
        metrics.stopReason = .writeError
        lock.unlock()
        // Preserve the .open marker. Partial write/close is an unclean session.
    }

    private func finalize() {
        lock.lock()
        let ready = pending == 0 && !purged && !accepting
        let failed = metrics.writeErrors > 0
        lock.unlock()
        guard ready, !finalized else { return }
        finalized = true
        guard let handle else { return }
        defer { self.handle = nil }
        do {
            if !failed {
                var record = control(.sessionEnded)
                record.metrics = snapshot()
                let data = try encoded(record)
                guard data.count <= limits.terminalReserve,
                      data.count <= limits.sessionBytes - sessionBytes,
                      data.count <= limits.retainedBytes - retainedBytes else {
                    throw LogError.terminalTooLarge
                }
                try write(handle, data)
                try handle.synchronize()
            }
            try handle.close()
            if !failed, let marker { try FileManager.default.removeItem(at: marker) }
        } catch {
            noteWriteError()
            try? handle.close()
        }
    }

    private func control(_ kind: Kind) -> Record {
        Record(session: sessionToken.id, event: UUID(), sequence: sequence,
               monotonicNanoseconds: DispatchTime.now().uptimeNanoseconds,
               kind: kind, source: .recorder, correlation: Correlation(),
               text: nil, label: nil, metrics: snapshot())
    }

    private func encoded(_ record: Record) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var data = try encoder.encode(record)
        data.append(0x0A)
        return data
    }

    private func bounded(_ value: String?, maximum: Int) -> TextField? {
        guard let value else { return nil }
        // Read only maximum + 1 UTF-8 bytes; do not scan an unbounded caller value.
        let bytes = Array(value.utf8.prefix(maximum + 1))
        let truncated = bytes.count > maximum
        var end = min(bytes.count, maximum)
        while end > 0 && String(bytes: bytes.prefix(end), encoding: .utf8) == nil { end -= 1 }
        let result = String(bytes: bytes.prefix(end), encoding: .utf8) ?? ""
        let lower = result.lowercased()
        // Defense in depth, not a complete secret detector. Callers MUST exclude
        // credential, biometric, raw-media, and hidden-reasoning fields by design.
        let forbidden = ["password", "passwd", "authorization", "bearer ", "api_key", "apikey",
                         "api-key", "client_secret", "access_token", "refresh_token", "private key",
                         "-----begin", "sk-", "data:image", "data:audio", "image_url", "base64",
                         "embedding", "biometric", "<think>", "chain_of_thought"]
        let redacted = forbidden.contains(where: lower.contains)
        return TextField(value: redacted ? String("[sensitive content omitted]".prefix(maximum)) : result,
                         truncated: truncated, redacted: redacted)
    }

    private static func rejectSymlink(_ url: URL) throws {
        let values = try url.resourceValues(forKeys: [.isSymbolicLinkKey])
        guard values.isSymbolicLink != true else { throw LogError.invalidDirectory }
    }

    private static func isOwned(_ url: URL) -> Bool {
        ["jsonl", "open"].contains(url.pathExtension)
            && UUID(uuidString: url.deletingPathExtension().lastPathComponent) != nil
    }

    private static func removeOwnedFiles(in directory: URL) throws {
        let manager = FileManager.default
        guard manager.fileExists(atPath: directory.path) else { return }
        try rejectSymlink(directory)
        for file in try manager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isSymbolicLinkKey]) {
            guard isOwned(file) else { continue }
            try rejectSymlink(file)
            try manager.removeItem(at: file)
        }
    }

    private enum LogError: Error {
        case invalidDirectory, creationFailed, terminalTooLarge
    }
}
#endif
