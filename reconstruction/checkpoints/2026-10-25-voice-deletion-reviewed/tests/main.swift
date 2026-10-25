import Foundation
var checks = 0
func check(_ value: Bool) { precondition(value); checks += 1 }
func rejects(_ work: () throws -> Void) { do { try work(); fatalError("Expected rejection") } catch { checks += 1 } }
let binding = try VoiceEnrollmentBinding(modelSHA256: String(repeating: "a", count: 64), embeddingDimensions: 3, captureRoute: "synthetic-route", preprocessingRevision: "synthetic-16k-mono-v1")
let other = try VoiceEnrollmentBinding(modelSHA256: String(repeating: "b", count: 64), embeddingDimensions: 3, captureRoute: "synthetic-route", preprocessingRevision: "synthetic-16k-mono-v1")
rejects { _ = try VoiceEnrollmentConsent(explicitLocalConsent: false, now: Date()) }
rejects { _ = try VoiceEnrollmentBinding(modelSHA256: "bad", embeddingDimensions: 3, captureRoute: "x", preprocessingRevision: "v1") }
let consent = try VoiceEnrollmentConsent(explicitLocalConsent: true, now: Date(timeIntervalSince1970: 1))
var draft = VoiceEnrollmentDraft()
let ticket = try draft.begin(consent: consent, binding: binding)
rejects { _ = try draft.finish(ticket: ticket) }
let sample = VoiceEnrollmentSample(sourceTurnID: UUID(), purpose: .template, vector: [0.1, 0.2, 0.3])
rejects { try draft.append(sample, binding: other, ticket: ticket) }
let routeChange = try VoiceEnrollmentBinding(modelSHA256: binding.modelSHA256, embeddingDimensions: 3, captureRoute: "other-route", preprocessingRevision: binding.preprocessingRevision)
let processingChange = try VoiceEnrollmentBinding(modelSHA256: binding.modelSHA256, embeddingDimensions: 3, captureRoute: binding.captureRoute, preprocessingRevision: "v2")
rejects { try draft.append(sample, binding: routeChange, ticket: ticket) }
rejects { try draft.append(sample, binding: processingChange, ticket: ticket) }
rejects { try draft.append(sample, binding: binding, ticket: UUID()) }
rejects { try draft.append(.init(sourceTurnID: UUID(), purpose: .template, vector: [.nan, 1, 2]), binding: binding, ticket: ticket) }
rejects { try draft.append(.init(sourceTurnID: UUID(), purpose: .template, vector: [0, 0, 0]), binding: binding, ticket: ticket) }
rejects { try draft.append(.init(sourceTurnID: UUID(), purpose: .template, vector: [1, 2]), binding: binding, ticket: ticket) }
try draft.append(sample, binding: binding, ticket: ticket)
rejects { try draft.append(sample, binding: binding, ticket: ticket) }
// Simulate distinct utterances within the same engine capture session. The enrollment
// key is each source turn ID; the shared engine capture ID must never be used as it.
let sameCapture = UUID()
let firstTurn = (id: sample.sourceTurnID, capture: sameCapture)
let nextTurn = (id: UUID(), capture: sameCapture)
check(firstTurn.capture == nextTurn.capture && firstTurn.id != nextTurn.id)
try draft.append(.init(sourceTurnID: nextTurn.id, purpose: .heldOut, vector: [0.3, 0.2, 0.1]), binding: binding, ticket: ticket)
rejects { try draft.append(.init(sourceTurnID: nextTurn.id, purpose: .template, vector: [0.4, 0.2, 0.1]), binding: binding, ticket: ticket) }
let record = try draft.finish(ticket: ticket)
check(record.samples.count == 2)
check(record.mayIdentifyWearer == false)
check(record.calibrationStatus.hasPrefix("unavailable"))
rejects { _ = try draft.finish(ticket: ticket) }
let encoded = try JSONEncoder().encode(record)
let decoded = try JSONDecoder().decode(VoiceEnrollmentRecord.self, from: encoded)
try decoded.validate(); check(decoded == record)
var json = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
json["schemaVersion"] = 99
let corrupt = try JSONSerialization.data(withJSONObject: json)
rejects { try JSONDecoder().decode(VoiceEnrollmentRecord.self, from: corrupt).validate() }
let next = try draft.begin(consent: consent, binding: binding)
for _ in 0..<12 { try draft.append(.init(sourceTurnID: UUID(), purpose: .template, vector: [1, 2, 3]), binding: binding, ticket: next) }
rejects { try draft.append(.init(sourceTurnID: UUID(), purpose: .template, vector: [1, 2, 3]), binding: binding, ticket: next) }
draft.cancel()
rejects { _ = try draft.finish(ticket: next) }
let heldOnly = try draft.begin(consent: consent, binding: binding)
try draft.append(.init(sourceTurnID: UUID(), purpose: .heldOut, vector: [1, 2, 3]), binding: binding, ticket: heldOnly)
rejects { _ = try draft.finish(ticket: heldOnly) }
// Actual production generation coordinator: a delayed async result cannot save after
// deletion/cancellation, even when it still holds a valid, otherwise unchanged record.
var storeGeneration = VoiceEnrollmentStoreGeneration()
let saveTicket = storeGeneration.beginHelperSetup(consent: consent)
try storeGeneration.validateSave(record, ticket: saveTicket); checks += 1
var storedProfileExists = true
storeGeneration.delete { storedProfileExists = false }
check(!storedProfileExists)
rejects { try storeGeneration.validateSave(record, ticket: saveTicket) }
let replacementConsent = try VoiceEnrollmentConsent(explicitLocalConsent: true, now: Date(timeIntervalSince1970: 2))
let newSaveTicket = storeGeneration.beginHelperSetup(consent: replacementConsent)
rejects { try storeGeneration.validateSave(record, ticket: saveTicket) }
rejects { try storeGeneration.validateSave(record, ticket: newSaveTicket) }
// Selection rotates generations even for the same consent ID, invalidating old work.
let reusedConsentTicket = storeGeneration.beginHelperSetup(consent: consent)
try storeGeneration.validateSave(record, ticket: reusedConsentTicket); checks += 1
rejects { try storeGeneration.validateSave(record, ticket: saveTicket) }
rejects { try storeGeneration.delete { throw VoiceEnrollmentError.invalidRecord } }
check(!storeGeneration.canLoad)
rejects { try storeGeneration.validateSave(record, ticket: reusedConsentTicket) }
_ = storeGeneration.beginHelperSetup(consent: consent)
check(!storeGeneration.canLoad) // Setup alone must not revive the failed-delete disk record.
storeGeneration.delete {} // A successful retry confirms erase.
check(storeGeneration.canLoad)
rejects { try storeGeneration.delete { throw VoiceEnrollmentError.invalidRecord } }
_ = storeGeneration.beginHelperSetup(consent: consent)
check(!storeGeneration.canLoad)
storeGeneration.didCommitVerifiedReplacement()
check(storeGeneration.canLoad)
// Small synthetic file bytes only, never enrollment/audio/private input.
let fixture = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
defer { try? FileManager.default.removeItem(at: fixture) }
try Data(repeating: 65, count: 64).write(to: fixture)
let exactHandle = try FileHandle(forReadingFrom: fixture)
let exactBytes = try VoiceEnrollmentBoundedRead.read(from: exactHandle, maximumBytes: 64)
try exactHandle.close(); check(exactBytes.count == 64)
try Data(repeating: 65, count: 65).write(to: fixture)
let overflowHandle = try FileHandle(forReadingFrom: fixture)
rejects { _ = try VoiceEnrollmentBoundedRead.read(from: overflowHandle, maximumBytes: 64) }
try overflowHandle.close()
try Data().write(to: fixture)
let emptyHandle = try FileHandle(forReadingFrom: fixture)
let emptyBytes = try VoiceEnrollmentBoundedRead.read(from: emptyHandle, maximumBytes: 64)
try emptyHandle.close(); check(emptyBytes.isEmpty)
// Durable fence tests execute the production Foundation transaction with tiny synthetic
// files. Re-instantiation models process loss of all RAM state, not Apple device behavior.
let fenceDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at: fenceDirectory, withIntermediateDirectories: false)
defer { try? FileManager.default.removeItem(at: fenceDirectory) }
let syntheticProfile = fenceDirectory.appendingPathComponent("profile")
try Data([7]).write(to: syntheticProfile)
let fence = VoiceEnrollmentDeletionFence(directory: fenceDirectory)
check(try !fence.isPending)
var removalCalled = false
rejects {
    try fence.delete(verifyMarker: { _ in throw VoiceEnrollmentError.invalidRecord }) {
        removalCalled = true
    }
}
check(!removalCalled)
check(try VoiceEnrollmentDeletionFence(directory: fenceDirectory).isPending)
rejects { try fence.delete(verifyMarker: { _ in }) { throw VoiceEnrollmentError.invalidRecord } }
check(FileManager.default.fileExists(atPath: syntheticProfile.path))
let restartedFence = VoiceEnrollmentDeletionFence(directory: fenceDirectory)
check(try restartedFence.isPending)
var restartedGeneration = VoiceEnrollmentStoreGeneration()
_ = restartedGeneration.beginHelperSetup(consent: consent)
check(try restartedGeneration.canLoad && restartedFence.isPending) // Disk fence overrides RAM.
try restartedFence.delete(verifyMarker: { _ in }) {
    check(try restartedFence.isPending) // Intent precedes deletion.
    try FileManager.default.removeItem(at: syntheticProfile)
}
check(!FileManager.default.fileExists(atPath: syntheticProfile.path))
check(try !VoiceEnrollmentDeletionFence(directory: fenceDirectory).isPending)
// Repeated delete succeeds with caller-confirmed already absent profile.
try fence.delete(verifyMarker: { _ in }, removing: {})
check(try !fence.isPending)
// Missing parent forces marker-write failure: do NOT call erase or claim durable intent.
let unavailable = VoiceEnrollmentDeletionFence(directory: fenceDirectory.appendingPathComponent("absent"))
removalCalled = false
rejects { try unavailable.delete(verifyMarker: { _ in }) { removalCalled = true } }
check(!removalCalled)
// Real filesystem denial during marker cleanup must propagate, then remain pending.
// Fixture is owned by this unprivileged test process; restore its mode before retry.
rejects {
    try fence.delete(verifyMarker: { _ in }) {
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: fenceDirectory.path)
    }
}
try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: fenceDirectory.path)
check(try VoiceEnrollmentDeletionFence(directory: fenceDirectory).isPending)
try fence.delete(verifyMarker: { _ in }, removing: {})
check(try !fence.isPending)
// Inaccessible lookup must throw, not treat an unknown marker as absent.
try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: fenceDirectory.path)
rejects { _ = try fence.isPending }
try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: fenceDirectory.path)
// Production whole-container cleanup includes hidden atomic-write remnants and folders.
let orphan = fenceDirectory.appendingPathComponent(".atomic-orphan")
let nested = fenceDirectory.appendingPathComponent("orphan-folder")
try Data([7]).write(to: syntheticProfile)
try Data([8]).write(to: orphan)
try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: false)
try Data([9]).write(to: nested.appendingPathComponent("bytes"))
try fence.delete(verifyMarker: { _ in }) {
    try fence.removeOtherChildren()
    check(try fence.isPending)
}
check(try FileManager.default.contentsOfDirectory(atPath: fenceDirectory.path).isEmpty)
// Cleanup permission denial leaves both marker and synthetic orphan across recreation.
try Data([8]).write(to: orphan)
rejects {
    try fence.delete(verifyMarker: { _ in }) {
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: fenceDirectory.path)
        try fence.removeOtherChildren()
    }
}
try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: fenceDirectory.path)
check(FileManager.default.fileExists(atPath: orphan.path))
check(try VoiceEnrollmentDeletionFence(directory: fenceDirectory).isPending)
try fence.delete(verifyMarker: { _ in }) { try fence.removeOtherChildren() }
check(try FileManager.default.contentsOfDirectory(atPath: fenceDirectory.path).isEmpty)
// Enumeration failure also retains intent, rather than assuming an empty directory.
rejects {
    try fence.delete(verifyMarker: { _ in }) {
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: fenceDirectory.path)
        try fence.removeOtherChildren()
    }
}
try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: fenceDirectory.path)
check(try VoiceEnrollmentDeletionFence(directory: fenceDirectory).isPending)
try fence.delete(verifyMarker: { _ in }) { try fence.removeOtherChildren() }
check(try FileManager.default.contentsOfDirectory(atPath: fenceDirectory.path).isEmpty)
// Empty and dangling-link markers are still deletion intent, never absence.
try Data().write(to: fence.marker)
check(try VoiceEnrollmentDeletionFence(directory: fenceDirectory).isPending)
try FileManager.default.removeItem(at: fence.marker)
try FileManager.default.createSymbolicLink(at: fence.marker,
    withDestinationURL: fenceDirectory.appendingPathComponent("nonexistent-target"))
check(try VoiceEnrollmentDeletionFence(directory: fenceDirectory).isPending)
try FileManager.default.removeItem(at: fence.marker)
// Unexpected marker replacement still blocks a new instance, irrespective of content.
rejects {
    try fence.delete(verifyMarker: { _ in }) {
        try FileManager.default.removeItem(at: fence.marker)
        try FileManager.default.createDirectory(at: fence.marker, withIntermediateDirectories: false)
        try Data([1]).write(to: fence.marker.appendingPathComponent("unexpected"))
        // removeItem recursively removes directories, so throw to preserve unexpected state.
        throw VoiceEnrollmentError.invalidRecord
    }
}
check(try VoiceEnrollmentDeletionFence(directory: fenceDirectory).isPending)
print("PASS \(checks) synthetic enrollment contract checks; no audio, identity accuracy or Apple storage test")
