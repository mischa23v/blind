#if os(iOS)
import Foundation
import Darwin

/// iOS-only source proposal, not Apple-compiled/device-verified in this checkpoint.
/// Complete protection deliberately makes enrollment unavailable while locked.
/// Caller must drop in-memory records and invalidate voice evidence on lock/delete.
public actor ProtectedVoiceEnrollmentStore {
    private let fm = FileManager.default
    private var generation = VoiceEnrollmentStoreGeneration()
    private let directory: URL
    private let file: URL
    private let deletionFence: VoiceEnrollmentDeletionFence
    public init() throws {
        let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                 appropriateFor: nil, create: true)
        directory = support.appendingPathComponent("PrivateVoiceEnrollment", isDirectory: true)
        deletionFence = VoiceEnrollmentDeletionFence(directory: directory)
        file = directory.appendingPathComponent("enrollment-v1.json", isDirectory: false)
    }
    private func secure(_ url: URL) throws {
        let info = try url.resourceValues(forKeys: [.isSymbolicLinkKey])
        guard info.isSymbolicLink != true else { throw VoiceEnrollmentError.invalidRecord }
        try fm.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
        var mutable = url
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try mutable.setResourceValues(values)
        let checked = try mutable.resourceValues(forKeys: [.isExcludedFromBackupKey])
        let attributes = try fm.attributesOfItem(atPath: url.path)
        guard checked.isExcludedFromBackup == true,
              attributes[.protectionKey] as? FileProtectionType == .complete else { throw VoiceEnrollmentError.invalidRecord }
    }
    /// Called at the start of explicit trusted helper setup, before async extraction.
    /// Never call this from a late worker completion or automatically to retry a stale save.
    public func beginHelperSetup(consent: VoiceEnrollmentConsent) -> VoiceEnrollmentSaveTicket {
        generation.beginHelperSetup(consent: consent)
    }
    public func cancelSetup() { generation.invalidate() }
    public func save(_ record: VoiceEnrollmentRecord, ticket: VoiceEnrollmentSaveTicket) throws {
        // Actor serialization is insufficient without this selected-generation check.
        // This method has no await: deletion cannot interleave after validation and before write.
        try generation.validateSave(record, ticket: ticket)
        try record.validate()
        // A fresh setup cannot bypass an unfinished deletion, including after restart.
        guard try !deletionFence.isPending else { throw VoiceEnrollmentError.invalidRecord }
        try fm.createDirectory(at: directory, withIntermediateDirectories: false,
                               attributes: [.protectionKey: FileProtectionType.complete])
        // Secure/exclude the container before writing biometric bytes, including atomic temp files.
        try secure(directory)
        let data = try JSONEncoder().encode(record)
        guard data.count <= 1_048_576 else { throw VoiceEnrollmentError.capacity }
        // A failed atomic write has not established a committed replacement. Do not remove
        // the destination in its error path: that may still be the prior good enrollment.
        // Propagate the write failure unchanged; no new record is returned as saved.
        try data.write(to: file, options: [.atomic, .completeFileProtection])
        do {
            // Only a successful write enters post-commit verification/cleanup.
            // Atomic replacement may reset backup flags; reapply and verify after every save.
            try secure(file)
            generation.didCommitVerifiedReplacement()
        } catch {
            // The replacement committed but its security properties could not be verified.
            // Fail closed by removing that replacement. This does not restore the old record.
            // Surface cleanup failure rather than pretending the data was deleted.
            if fm.fileExists(atPath: file.path) { try fm.removeItem(at: file) }
            throw error
        }
    }
    public func load(matching binding: VoiceEnrollmentBinding) throws -> VoiceEnrollmentRecord? {
        // Check durable intent before reading any profile, including in a new actor.
        guard generation.canLoad else { return nil }
        guard try !deletionFence.isPending else { return nil }
        guard fm.fileExists(atPath: file.path) else { return nil }
        try secure(directory); try secure(file)
        // Metadata size is not a read bound: the path can grow or be replaced after stat.
        // Open the final component without following symlinks and inspect the descriptor.
        // O_NONBLOCK prevents opening a substituted FIFO from blocking before fstat.
        let fd = file.path.withCString { Darwin.open($0, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC) }
        guard fd >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? handle.close() }
        var status = stat()
        guard Darwin.fstat(fd, &status) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        guard (status.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG) else { throw VoiceEnrollmentError.invalidRecord }
        // Bound actual bytes even if the opened file grows after fstat; handle short reads.
        let data = try VoiceEnrollmentBoundedRead.read(from: handle)
        let record = try JSONDecoder().decode(VoiceEnrollmentRecord.self, from: data)
        try record.validate()
        guard record.binding == binding else { return nil }
        return record
    }
    /// Removes the local record, not a secure-erasure guarantee for flash storage.
    /// No audio/history/user identity is stored here. Host must clear any RAM copies too.
    public func delete() throws {
        // Invalidate even if removal fails. A queued old save must not resurrect the profile.
        let manager = fm, fence = deletionFence
        // Retain the protected container: the marker must outlive failed record removal.
        // Preparation failures still invalidate old saves and in-process reads.
        try generation.delete {
            try manager.createDirectory(at: directory, withIntermediateDirectories: false,
                                        attributes: [.protectionKey: FileProtectionType.complete])
            try secure(directory)
            try fence.delete(verifyMarker: { try secure($0) }) {
                // The dedicated container can hold orphan atomic-write files as well
                // as the selected record. No surviving sibling may count as deleted.
                try fence.removeOtherChildren()
            }
        }
    }
}
#endif
