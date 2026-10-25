import Foundation

public enum VoiceEnrollmentError: Error { case invalidBinding, consentRequired, invalidSample, staleSession, duplicateSample, capacity, noSamples, invalidRecord }

/// Resource and storage contracts only. None of these values are speaker thresholds.
public struct VoiceEnrollmentBinding: Codable, Equatable, Sendable {
    public let modelSHA256: String
    public let embeddingDimensions: Int
    public let captureRoute: String
    public let preprocessingRevision: String
    public init(modelSHA256: String, embeddingDimensions: Int, captureRoute: String, preprocessingRevision: String) throws {
        self.modelSHA256 = modelSHA256; self.embeddingDimensions = embeddingDimensions
        self.captureRoute = captureRoute; self.preprocessingRevision = preprocessingRevision
        try validate()
    }
    public func validate() throws {
        guard modelSHA256.count == 64, modelSHA256.allSatisfy({ "0123456789abcdef".contains($0) }),
              (1...4096).contains(embeddingDimensions),
              !captureRoute.isEmpty, captureRoute.utf8.count <= 256,
              !preprocessingRevision.isEmpty, preprocessingRevision.utf8.count <= 128 else {
            throw VoiceEnrollmentError.invalidBinding
        }
    }
}

/// Issued only by the trusted helper UI after explicit local consent (guardian for a child).
/// A Boolean here is not authentication; ASR/model output must never call this setup API.
public struct VoiceEnrollmentConsent: Sendable {
    public let setupID: UUID
    public let grantedAt: Date
    public init(explicitLocalConsent: Bool, now: Date) throws {
        guard explicitLocalConsent, now.timeIntervalSince1970.isFinite else { throw VoiceEnrollmentError.consentRequired }
        setupID = UUID(); grantedAt = now
    }
}

public struct VoiceEnrollmentSample: Codable, Equatable, Sendable {
    public enum Purpose: String, Codable, Sendable { case template, heldOut }
    /// CapturedVoiceTurn.id, NOT CapturedVoiceTurn.capture (the engine capture session).
    /// Multiple utterances from one continuous capture have distinct source turn IDs.
    public let sourceTurnID: UUID
    public let purpose: Purpose
    public let vector: [Float]
    public init(sourceTurnID: UUID, purpose: Purpose, vector: [Float]) {
        self.sourceTurnID = sourceTurnID; self.purpose = purpose; self.vector = vector
    }
    public func validate(binding: VoiceEnrollmentBinding) throws {
        guard vector.count == binding.embeddingDimensions, vector.allSatisfy({ $0.isFinite }),
              vector.contains(where: { $0 != 0 }) else { throw VoiceEnrollmentError.invalidSample }
    }
}

/// Private biometric data. Never log, export, back up, send to a model or upload this record.
/// A held-out label merely separates samples; it does not assert real independent speech.
public struct VoiceEnrollmentRecord: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let enrollmentVersion: UUID
    public let consentSetupID: UUID
    public let consentedAt: Date
    public let binding: VoiceEnrollmentBinding
    public let samples: [VoiceEnrollmentSample]
    public var calibrationStatus: String { "unavailable: target-device validation not performed" }
    public var mayIdentifyWearer: Bool { false }
    public func validate() throws {
        try binding.validate()
        guard schemaVersion == 1, consentedAt.timeIntervalSince1970.isFinite,
              (1...12).contains(samples.count), samples.contains(where: { $0.purpose == .template }),
              Set(samples.map(\.sourceTurnID)).count == samples.count else { throw VoiceEnrollmentError.invalidRecord }
        for sample in samples { try sample.validate(binding: binding) }
    }
}

/// Transient, one-profile setup. Cancel on mute, end, route change, lock, consent withdrawal or deletion.
/// No PCM/text is retained. Re-enrollment creates a new version and invalidates old evidence externally.
public struct VoiceEnrollmentDraft: Sendable {
    private var consent: VoiceEnrollmentConsent?
    private var binding: VoiceEnrollmentBinding?
    private var ticket = UUID()
    private var samples: [VoiceEnrollmentSample] = []
    public init() {}
    public mutating func begin(consent: VoiceEnrollmentConsent, binding: VoiceEnrollmentBinding) throws -> UUID {
        try binding.validate(); cancel(); self.consent = consent; self.binding = binding; return ticket
    }
    public mutating func cancel() { consent = nil; binding = nil; samples.removeAll(keepingCapacity: false); ticket = UUID() }
    public mutating func append(_ sample: VoiceEnrollmentSample, binding observed: VoiceEnrollmentBinding, ticket supplied: UUID) throws {
        guard supplied == ticket, consent != nil, let binding, binding == observed else { throw VoiceEnrollmentError.staleSession }
        guard samples.count < 12 else { throw VoiceEnrollmentError.capacity }
        guard !samples.contains(where: { $0.sourceTurnID == sample.sourceTurnID }) else { throw VoiceEnrollmentError.duplicateSample }
        try sample.validate(binding: binding); samples.append(sample)
    }
    public mutating func finish(ticket supplied: UUID) throws -> VoiceEnrollmentRecord {
        guard supplied == ticket, let consent, let binding else { throw VoiceEnrollmentError.staleSession }
        guard samples.contains(where: { $0.purpose == .template }) else { throw VoiceEnrollmentError.noSamples }
        let record = VoiceEnrollmentRecord(schemaVersion: 1, enrollmentVersion: UUID(), consentSetupID: consent.setupID,
            consentedAt: consent.grantedAt, binding: binding, samples: samples)
        try record.validate(); cancel(); return record
    }
}

/// Ephemeral save authority, issued by the trusted helper setup, not microphone evidence.
/// Not Codable: a persisted enrollment record cannot restore permission to save itself.
public struct VoiceEnrollmentSaveTicket: Equatable, Sendable {
    fileprivate let generation: UUID
    fileprivate let consentSetupID: UUID
}

/// The protected store owns exactly one coordinator and never suspends between check and write.
/// Delete invalidates before attempting disk cleanup, including when cleanup throws.
/// Only a new explicit helper setup may select a new generation after deletion.
public struct VoiceEnrollmentStoreGeneration: Sendable {
    private var generation = UUID()
    private var selectedConsentSetupID: UUID?
    public private(set) var canLoad = true
    public init() {}
    public mutating func beginHelperSetup(consent: VoiceEnrollmentConsent) -> VoiceEnrollmentSaveTicket {
        invalidate()
        selectedConsentSetupID = consent.setupID
        return VoiceEnrollmentSaveTicket(generation: generation, consentSetupID: consent.setupID)
    }
    public mutating func invalidate() {
        generation = UUID(); selectedConsentSetupID = nil
    }
    public mutating func delete(removing: () throws -> Void) rethrows {
        invalidate()
        canLoad = false // Retire read eligibility before filesystem work, even if it fails.
        try removing()
        canLoad = true // Confirmed erase permits reading again; no old file should remain.
    }
    /// Call only after a new selected save both commits and passes protection verification.
    public mutating func didCommitVerifiedReplacement() { canLoad = true }
    public func validateSave(_ record: VoiceEnrollmentRecord, ticket: VoiceEnrollmentSaveTicket) throws {
        guard ticket.generation == generation,
              selectedConsentSetupID == ticket.consentSetupID,
              record.consentSetupID == ticket.consentSetupID else { throw VoiceEnrollmentError.staleSession }
    }
}

/// Actual-byte bound shared by the iOS loader and synthetic Foundation file tests.
/// The caller must open a regular non-symlink file before invoking this helper.
public enum VoiceEnrollmentBoundedRead {
    public static func read(from handle: FileHandle, maximumBytes: Int = 1_048_576) throws -> Data {
        guard (1...1_048_576).contains(maximumBytes) else { throw VoiceEnrollmentError.capacity }
        var data = Data()
        while data.count <= maximumBytes {
            let chunk = try handle.read(upToCount: maximumBytes + 1 - data.count) ?? Data()
            if chunk.isEmpty { break }
            data.append(chunk)
        }
        guard data.count <= maximumBytes else { throw VoiceEnrollmentError.capacity }
        return data
    }
}

/// Write-ahead deletion intent; contains no biometric bytes or identity metadata.
/// The host secures/excludes its directory before use and verifies marker protection.
/// One serialized store owns this directory. This is not a multi-process lock.
public struct VoiceEnrollmentDeletionFence: Sendable {
    public let marker: URL
    public init(directory: URL) {
        marker = directory.appendingPathComponent("deletion-pending-v1", isDirectory: false)
    }
    public var isPending: Bool {
        get throws {
            do {
                _ = try FileManager.default.attributesOfItem(atPath: marker.path)
                return true // Any marker type/content blocks; never decode untrusted contents.
            } catch {
                let failure = error as NSError
                if failure.domain == NSCocoaErrorDomain &&
                    (failure.code == NSFileNoSuchFileError || failure.code == NSFileReadNoSuchFileError) {
                    return false
                }
                throw error // Inaccessible/unknown is not evidence of absence.
            }
        }
    }
    /// Erase all dedicated-container contents except the active intent marker.
    /// Includes hidden atomic-write remnants; enumeration/removal failures propagate.
    /// Caller serializes this operation with all writers to the dedicated directory.
    public func removeOtherChildren() throws {
        let manager = FileManager.default
        let directory = marker.deletingLastPathComponent()
        func remainingChildren() throws -> [URL] {
            try manager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil,
                                            options: []).filter { $0.lastPathComponent != marker.lastPathComponent }
        }
        for child in try remainingChildren() {
            try manager.removeItem(at: child)
        }
        guard try remainingChildren().isEmpty else { throw VoiceEnrollmentError.invalidRecord }
    }
    /// If marker creation/verification fails, deletion was NOT durably admitted.
    /// If erase or marker cleanup fails, propagate failure and keep reads fenced.
    public func delete(verifyMarker: (URL) throws -> Void, removing: () throws -> Void) throws {
        var options: Data.WritingOptions = [.atomic]
        #if os(iOS)
        options.insert(.completeFileProtection)
        #endif
        try Data([1]).write(to: marker, options: options)
        try verifyMarker(marker)
        try removing()
        try FileManager.default.removeItem(at: marker)
    }
}
