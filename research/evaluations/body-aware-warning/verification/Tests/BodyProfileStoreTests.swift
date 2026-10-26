import XCTest
import Foundation
import BlindCore
@testable import NativeBodyProfile

private final class BlockedBodyStorage: SpatialMapStorageIO, @unchecked Sendable {
    let lock = NSLock(), release = DispatchSemaphore(value: 0)
    var bytes: Data?, blockNextWrite = false, failNextDelete = false
    var entered: (() -> Void)?
    var touchedMain = false
    func read(maximumBytes: Int) throws -> Data {
        lock.lock(); defer { lock.unlock() }; touchedMain = touchedMain || Thread.isMainThread
        guard let bytes else { throw CocoaError(.fileNoSuchFile) }; return bytes
    }
    func write(_ data: Data) throws {
        lock.lock(); touchedMain = touchedMain || Thread.isMainThread
        let block = blockNextWrite; blockNextWrite = false; let callback = entered; lock.unlock()
        if block { callback?(); release.wait() }
        lock.lock(); bytes = data; lock.unlock()
    }
    func delete() throws {
        lock.lock(); defer { lock.unlock() }; touchedMain = touchedMain || Thread.isMainThread
        if failNextDelete { failNextDelete = false; throw CocoaError(.fileWriteNoPermission) }
        bytes = nil
    }
    func configureBlock(_ callback: @escaping () -> Void) { lock.lock(); blockNextWrite = true; entered = callback; lock.unlock() }
    func configureDeleteFailure() { lock.lock(); failNextDelete = true; lock.unlock() }
    func snapshot() -> (Data?, Bool) { lock.lock(); defer { lock.unlock() }; return (bytes, touchedMain) }
}
final class BodyProfileStoreTests: XCTestCase {
    @MainActor func load(_ store: BodyProfileStore) async throws -> LocalBodyProfile {
        try await withCheckedThrowingContinuation { continuation in store.load { continuation.resume(with: $0.map { $0! }) } }
    }
    @MainActor func save(_ store: BodyProfileStore, _ value: LocalBodyProfile, replacing: UUID) async throws -> LocalBodyProfile {
        try await withCheckedThrowingContinuation { continuation in store.save(value, replacing: replacing) { continuation.resume(with: $0.map { $0! }) } }
    }
    @MainActor func erase(_ store: BodyProfileStore) async throws {
        let _: LocalBodyProfile? = try await withCheckedThrowingContinuation { continuation in store.erase { continuation.resume(with: $0) } }
    }
    func testLocalStoreRoundTripScopedDeletionAndCorruptFile() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let other = directory.appendingPathComponent("conversation.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("existing trusted memory".utf8).write(to: other)
        let store = await BodyProfileStore(directory: directory.appendingPathComponent("body"))
        let empty = try await load(store)
        XCTAssertNil(empty.input.heightMetres)
        let p = try LocalBodyProfile(input: .init(ageYears: 7, gender: "optional", weightKilograms: 25, heightMetres: 1.2))
        _ = try await save(store, p, replacing: empty.revision)
        let restored = try await load(store); XCTAssertEqual(restored, p)
        try await erase(store)
        let deleted = try await load(store); XCTAssertNil(deleted.input.heightMetres)
        XCTAssertEqual(try String(contentsOf: other, encoding: .utf8), "existing trusted memory")
        _ = try await save(store, p, replacing: deleted.revision)
        let file = directory.appendingPathComponent("body/profile.json")
        try Data("{}".utf8).write(to: file)
        do { _ = try await load(store); XCTFail("Corrupt file accepted") } catch { }
        try Data(repeating: 32, count: 16385).write(to: file)
        do { _ = try await load(store); XCTFail("Oversized file accepted") } catch { }
        try await erase(store); try await erase(store)
    }
    func testBlockedWriteDoesNotBlockMainAndCannotResurrectAfterDelete() async throws {
        let storage = BlockedBodyStorage(), entered = expectation(description: "off-main writer entered")
        let store = await BodyProfileStore(storage: storage), empty = try await load(store)
        let value = try LocalBodyProfile(input: .init(heightMetres: 1.2))
        storage.configureBlock { entered.fulfill() }
        let retiredWrite = expectation(description: "obsolete write withheld"), deleted = expectation(description: "ordered delete completed")
        await MainActor.run { store.save(value, replacing: empty.revision) { result in
            if case .success = result { XCTFail("Superseded save reported success") }; retiredWrite.fulfill()
        } }
        await fulfillment(of: [entered], timeout: 2)
        // Runs while the worker is blocked. This is also a main responsiveness witness.
        await MainActor.run { store.erase { result in
            if case .failure(let e) = result { XCTFail("Delete failed: \(e)") }; deleted.fulfill()
        } }
        storage.release.signal()
        await fulfillment(of: [retiredWrite, deleted], timeout: 3)
        XCTAssertNil(storage.snapshot().0); XCTAssertFalse(storage.snapshot().1)
        do { _ = try await save(store, value, replacing: empty.revision); XCTFail("Stale revision accepted") } catch { }
        XCTAssertNil(storage.snapshot().0)
    }
    func testRejectedStaleWriterDoesNotCancelAdmittedCurrentWriter() async throws {
        let storage = BlockedBodyStorage(), entered = expectation(description: "current write blocked")
        let store = await BodyProfileStore(storage: storage), a = try await load(store)
        let b = try LocalBodyProfile(input: .init(heightMetres: 1.2))
        _ = try await save(store, b, replacing: a.revision)
        let c = try LocalBodyProfile(input: .init(heightMetres: 1.3))
        storage.configureBlock { entered.fulfill() }
        let finished = expectation(description: "current save remains admitted")
        await MainActor.run { store.save(c, replacing: b.revision) { result in
            if case .failure(let e) = result { XCTFail("Stale writer interfered: \(e)") }; finished.fulfill()
        } }
        await fulfillment(of: [entered], timeout: 2)
        do { _ = try await save(store, a, replacing: a.revision); XCTFail("Stale writer accepted") } catch { }
        storage.release.signal()
        await fulfillment(of: [finished], timeout: 3)
        XCTAssertEqual(try LocalBodyProfile.decodeLocal(XCTUnwrap(storage.snapshot().0)), c)
    }
    func testReopeningReadWaitsForBlockedSaveWithoutRollingItBack() async throws {
        let storage = BlockedBodyStorage(), entered = expectation(description: "save blocked before reopening")
        let store = await BodyProfileStore(storage: storage), a = try await load(store)
        let b = try LocalBodyProfile(input: .init(heightMetres: 1.2))
        _ = try await save(store, b, replacing: a.revision)
        let c = try LocalBodyProfile(input: .init(heightMetres: 1.3))
        storage.configureBlock { entered.fulfill() }
        let saved = expectation(description: "save survives reopening"), reopened = expectation(description: "reopened view receives committed latest profile")
        await MainActor.run { store.save(c, replacing: b.revision) { result in
            if case .failure(let e) = result { XCTFail("Read cancelled write: \(e)") }; saved.fulfill()
        } }
        await fulfillment(of: [entered], timeout: 2)
        await MainActor.run { store.load { result in
            switch result {
            case .success(let value): XCTAssertEqual(value, c)
            case .failure(let e): XCTFail("Reopening failed: \(e)")
            }
            reopened.fulfill()
        } }
        storage.release.signal()
        await fulfillment(of: [saved, reopened], timeout: 3)
        XCTAssertEqual(try LocalBodyProfile.decodeLocal(XCTUnwrap(storage.snapshot().0)), c)
    }
    func testWaitingReadsCoalesceAndCannotCrossDeletionBarrier() async throws {
        let storage = BlockedBodyStorage(), entered = expectation(description: "writer blocked")
        let store = await BodyProfileStore(storage: storage), a = try await load(store)
        let b = try LocalBodyProfile(input: .init(heightMetres: 1.2))
        storage.configureBlock { entered.fulfill() }
        let saved = expectation(description: "obsolete save rejected"), firstRead = expectation(description: "old waiting read superseded")
        let lastRead = expectation(description: "latest read after delete"), deleted = expectation(description: "deletion receipt")
        await MainActor.run { store.save(b, replacing: a.revision) { result in
            if case .success = result { XCTFail("Obsolete write accepted") }; saved.fulfill()
        } }
        await fulfillment(of: [entered], timeout: 2)
        await MainActor.run {
            store.load { result in
                if case .success = result { XCTFail("Old waiting read accepted") }; firstRead.fulfill()
            }
            store.load { result in
                switch result {
                case .success(let p): XCTAssertNil(p?.input.heightMetres)
                case .failure(let e): XCTFail("Read after deletion failed: \(e)")
                }
                lastRead.fulfill()
            }
            store.erase { result in
                if case .failure(let e) = result { XCTFail("Delete failed: \(e)") }; deleted.fulfill()
            }
        }
        storage.release.signal()
        await fulfillment(of: [saved, firstRead, lastRead, deleted], timeout: 3)
        XCTAssertNil(storage.snapshot().0)
    }
    func testFailedDeleteDoesNotPermitNewSaveUntilDeletionRetry() async throws {
        let storage = BlockedBodyStorage(), store = await BodyProfileStore(storage: storage)
        let original = try await load(store), value = try LocalBodyProfile(input: .init(heightMetres: 1.2))
        _ = try await save(store, value, replacing: original.revision)
        storage.configureDeleteFailure()
        do { try await erase(store); XCTFail("Failed delete reported success") } catch { }
        do { _ = try await save(store, original, replacing: value.revision); XCTFail("Save bypassed failed delete") } catch { }
        try await erase(store); XCTAssertNil(storage.snapshot().0)
    }
    func testSourceGeometryHookRetiresBothOwnersWithoutChangingTrustedIdentity() throws {
        let path = ProcessInfo.processInfo.environment["BODY_PROFILE_STAGE"]!
        let source = try String(contentsOfFile: path + "/ios/BlindAssist/DashboardView.swift", encoding: .utf8)
        let start = try XCTUnwrap(source.range(of: "BodyProfileSettingsView("))
        let end = try XCTUnwrap(source.range(of: ".accessibilityIdentifier(\"body-profile-settings\")", range: start.upperBound..<source.endIndex))
        let hook = String(source[start.lowerBound..<end.upperBound])
        XCTAssertTrue(hook.contains("model.invalidateNativeLocalizationMount(slipped: false)"))
        XCTAssertTrue(hook.contains("model.fixedBodyMount = false"))
        XCTAssertTrue(hook.contains("model.journeys.breakTracking()"))
        XCTAssertTrue(hook.contains("model.indoor.invalidatePosition()"))
        XCTAssertFalse(hook.contains("preferredName")); XCTAssertFalse(hook.contains("assistantAudience"))
    }
    func testRuntimeSubscriptionStartupSaveAndDeletionAreRevisionOwned() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = await BodyProfileStore(directory: directory)
        let events = await MainActor.run { ProfileEvents() }
        await MainActor.run { store.onProfileChanged = { events.values.append($0) } }
        let empty = try await load(store)
        let startupRevision = await MainActor.run { events.values.last??.revision }
        XCTAssertEqual(startupRevision, empty.revision)
        let next = try LocalBodyProfile(input: .init(heightMetres: 1.2))
        _ = try await save(store, next, replacing: empty.revision)
        let revisions = await MainActor.run { events.values.map { $0?.revision } }
        XCTAssertEqual(revisions.suffix(2), [nil, next.revision])
        try await erase(store)
        let deleted = await MainActor.run { events.values.last! }
        XCTAssertNil(deleted)
    }

    func testSupersededWriteCannotRepublishDeletedRuntimeGeometry() async throws {
        let storage = BlockedBodyStorage(), entered = expectation(description: "old profile write blocked")
        let store = await BodyProfileStore(storage: storage), initial = try await load(store)
        let events = await MainActor.run { ProfileEvents() }
        await MainActor.run { store.onProfileChanged = { events.values.append($0) } }
        let oldProfile = try LocalBodyProfile(input: .init(heightMetres: 1.2))
        storage.configureBlock { entered.fulfill() }
        let oldFinished = expectation(description: "old profile rejected"), deleted = expectation(description: "new delete settled")
        await MainActor.run { store.save(oldProfile, replacing: initial.revision) { result in
            if case .success = result { XCTFail("Stale mutation republished") }; oldFinished.fulfill()
        } }
        await fulfillment(of: [entered], timeout: 2)
        await MainActor.run { store.erase { result in
            if case .failure = result { XCTFail("Delete failed") }; deleted.fulfill()
        } }
        storage.release.signal()
        await fulfillment(of: [oldFinished,deleted], timeout: 3)
        let published = await MainActor.run { events.values }
        XCTAssertFalse(published.isEmpty)
        XCTAssertTrue(published.allSatisfy { $0 == nil }, "An old generation resurrected geometry after mutation withdrawal")
    }

}

@MainActor private final class ProfileEvents { var values: [LocalBodyProfile?] = [] }
