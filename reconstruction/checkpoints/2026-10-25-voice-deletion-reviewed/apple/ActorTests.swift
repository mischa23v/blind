#if VOICE_ENROLLMENT_TESTING
import XCTest
import Foundation

final class VoiceEnrollmentActorTests: XCTestCase {
    func testProtectionAttributeDecodingRejectsWeakMissingAndUnknown() {
        XCTAssertTrue(VoiceEnrollmentFileProtection.isComplete(FileProtectionType.complete))
        XCTAssertTrue(VoiceEnrollmentFileProtection.isComplete(FileProtectionType.complete.rawValue))
        XCTAssertTrue(VoiceEnrollmentFileProtection.isComplete(FileProtectionType.complete.rawValue as NSString))
        XCTAssertFalse(VoiceEnrollmentFileProtection.isComplete(nil))
        XCTAssertFalse(VoiceEnrollmentFileProtection.isComplete(FileProtectionType.none))
        XCTAssertFalse(VoiceEnrollmentFileProtection.isComplete(FileProtectionType.completeUnlessOpen))
        XCTAssertFalse(VoiceEnrollmentFileProtection.isComplete(FileProtectionType.completeUntilFirstUserAuthentication.rawValue))
        XCTAssertFalse(VoiceEnrollmentFileProtection.isComplete("unknown-protection"))
        XCTAssertFalse(VoiceEnrollmentFileProtection.isComplete(42))
    }
    private func fixture() throws -> (URL, VoiceEnrollmentBinding, VoiceEnrollmentConsent, VoiceEnrollmentRecord) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("voice-probe-" + UUID().uuidString)
        // The actor creates its dedicated child; this outer fixture is test-owned only.
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        let binding = try VoiceEnrollmentBinding(modelSHA256: String(repeating: "a", count: 64),
            embeddingDimensions: 3, captureRoute: "synthetic-only", preprocessingRevision: "fixture-v1")
        let consent = try VoiceEnrollmentConsent(explicitLocalConsent: true, now: Date(timeIntervalSince1970: 1))
        var draft = VoiceEnrollmentDraft()
        let ticket = try draft.begin(consent: consent, binding: binding)
        try draft.append(.init(sourceTurnID: UUID(), purpose: .template, vector: [1, 2, 3]), binding: binding, ticket: ticket)
        return (directory, binding, consent, try draft.finish(ticket: ticket))
    }
    private func expectRejection(_ operation: () async throws -> Void,
                                 file: StaticString = #filePath, line: UInt = #line) async {
        do { try await operation(); XCTFail("Expected rejection", file: file, line: line) }
        catch { /* Counts only: never print synthetic/private record contents. */ }
    }
    func testSaveLoadRecreateDeleteAndOrphanCleanup() async throws {
        let (root, binding, consent, record) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent("enrollment", isDirectory: true)
        let store = try ProtectedVoiceEnrollmentStore(testDirectory: directory)
        let ticket = await store.beginHelperSetup(consent: consent)
        try await store.save(record, ticket: ticket)
        let loaded = try await store.load(matching: binding)
        XCTAssertEqual(loaded?.enrollmentVersion, record.enrollmentVersion)
        XCTAssertEqual(loaded?.mayIdentifyWearer, false)
        // Previous store is quiescent: only one owner performs operations at a time.
        let recreated = try ProtectedVoiceEnrollmentStore(testDirectory: directory)
        let afterRestart = try await recreated.load(matching: binding)
        XCTAssertEqual(afterRestart?.enrollmentVersion, record.enrollmentVersion)
        try Data([8]).write(to: directory.appendingPathComponent(".orphan-atomic"))
        let nested = directory.appendingPathComponent("orphan-folder", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: false)
        try Data([9]).write(to: nested.appendingPathComponent("bytes"))
        try await recreated.delete()
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
        let deleted = try await recreated.load(matching: binding)
        XCTAssertNil(deleted)
        try await recreated.delete() // Repeated delete is successful, not a resurrection.
        let next = try ProtectedVoiceEnrollmentStore(testDirectory: directory)
        let afterDeleteRestart = try await next.load(matching: binding)
        XCTAssertNil(afterDeleteRestart)
    }
    func testFailedEraseRestartFenceRequiresRetryAndRejectsLateSave() async throws {
        let (root, binding, consent, record) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent("enrollment", isDirectory: true)
        let store = try ProtectedVoiceEnrollmentStore(testDirectory: directory, failBeforeErase: true)
        let oldTicket = await store.beginHelperSetup(consent: consent)
        try await store.save(record, ticket: oldTicket)
        await expectRejection { try await store.delete() }
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("enrollment-v1.json").path))
        XCTAssertTrue(try VoiceEnrollmentDeletionFence(directory: directory).isPending)
        let withheld = try await store.load(matching: binding)
        XCTAssertNil(withheld)
        await expectRejection { try await store.save(record, ticket: oldTicket) }
        let recreated = try ProtectedVoiceEnrollmentStore(testDirectory: directory)
        let restartWithheld = try await recreated.load(matching: binding)
        XCTAssertNil(restartWithheld)
        let newTicket = await recreated.beginHelperSetup(consent: consent)
        await expectRejection { try await recreated.save(record, ticket: newTicket) }
        try await recreated.delete()
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
        await expectRejection { try await recreated.save(record, ticket: newTicket) }
        let retryTicket = await recreated.beginHelperSetup(consent: consent)
        try await recreated.save(record, ticket: retryTicket)
        let replacement = try await recreated.load(matching: binding)
        XCTAssertEqual(replacement?.enrollmentVersion, record.enrollmentVersion)
        XCTAssertEqual(replacement?.mayIdentifyWearer, false)
        try await recreated.delete()
    }
}
#endif
