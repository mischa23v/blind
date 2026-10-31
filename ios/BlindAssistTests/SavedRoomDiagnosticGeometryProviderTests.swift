import XCTest
import CryptoKit
import BlindCore
@testable import BlindAssist

/// Real provider/PlaceStore ownership with synthetic geometry loader outputs.
/// No AR session, hardware localization or RoomPlan measurement accuracy is claimed.
@MainActor final class SavedRoomDiagnosticGeometryProviderTests: XCTestCase {
    private func fixture(count: Int = 3) throws -> (URL, PlaceStore, [SavedPlace]) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("SavedRoomGeometry-\(UUID().uuidString)")
        let directory = root.appendingPathComponent("Places")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = Data("{}".utf8)
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let places = try (0..<count).map { index -> SavedPlace in
            let id = UUID()
            let frame = SavedWorldFrame(placeID: id.uuidString, revision: UUID().uuidString,
                worldMapSHA256: String(repeating: "a", count: 64), roomCaptureSHA256: digest,
                originAnchorID: UUID().uuidString, capturedAt: Date(timeIntervalSince1970: 1))
            let place = SavedPlace(id: id, name: "Fixture \(index)", createdAt: frame.capturedAt, objects: [], worldFrame: frame)
            try JSONEncoder().encode(place).write(to: directory.appendingPathComponent("\(id).json"))
            try data.write(to: directory.appendingPathComponent("\(id).room.json"))
            return place
        }
        let store = PlaceStore(directory: directory)
        XCTAssertEqual(store.places.count, count)
        XCTAssertNotNil(store.memory)
        return (root, store, places)
    }
    nonisolated private static func geometry(_ frame: SavedWorldFrame) throws -> SavedRoomDiagnosticGeometry {
        try .init(frame: frame, capturedRoomID: UUID(), story: 0,
            sourceCounts: .init(floors: 0, walls: 1, doors: 0, windows: 0, openings: 0, furniture: 0),
            features: [.init(id: UUID(), kind: .wall, category: "wall", transform: .identity, dimensions: Point3(4,3,0))])
    }
    private final class Loader: @unchecked Sendable {
        private let lock = NSLock()
        private var active = 0, maximumActive = 0
        private var frames: [SavedWorldFrame] = []
        let released = DispatchSemaphore(value: 0)
        var counts: (calls: Int, maximumActive: Int) {
            lock.lock(); defer { lock.unlock() }; return (frames.count, maximumActive)
        }
        var seen: [SavedWorldFrame] { lock.lock(); defer { lock.unlock() }; return frames }
        func load(_ source: SavedRoomDiagnosticGeometrySource) -> Result<SavedRoomDiagnosticGeometry, SavedRoomDiagnosticGeometryDecoder.Failure> {
            lock.lock(); active += 1; maximumActive = max(maximumActive, active); frames.append(source.frame); lock.unlock()
            defer { lock.lock(); active -= 1; lock.unlock() }
            guard released.wait(timeout: .now() + 5) == .success else { return .failure(.unavailable) }
            do { return .success(try SavedRoomDiagnosticGeometryProviderTests.geometry(source.frame)) }
            catch { return .failure(.invalidGeometry) }
        }
    }
    private func waitUntil(_ condition: @MainActor () -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
        let deadline = ProcessInfo.processInfo.systemUptime + 5
        while !condition(), ProcessInfo.processInfo.systemUptime < deadline {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTAssertTrue(condition(), file: file, line: line)
    }
    func testActualPlaceSourceBindsDescriptorMemoryOwnerAndDeletionAdmission() throws {
        let (root, store, places) = try fixture(count: 1)
        defer { try? FileManager.default.removeItem(at: root) }
        let frame = try XCTUnwrap(places[0].worldFrame)
        let source = try XCTUnwrap(store.diagnosticGeometrySource(for: frame))
        XCTAssertTrue(store.ownsDiagnosticGeometrySource(source))
        let (otherRoot, other, _) = try fixture(count: 0)
        defer { try? FileManager.default.removeItem(at: otherRoot) }
        XCTAssertFalse(other.ownsDiagnosticGeometrySource(source))
        let mismatched = SavedWorldFrame(placeID: frame.placeID, revision: UUID().uuidString,
            worldMapSHA256: frame.worldMapSHA256, roomCaptureSHA256: frame.roomCaptureSHA256,
            originAnchorID: frame.originAnchorID, capturedAt: frame.capturedAt)
        XCTAssertNil(store.diagnosticGeometrySource(for: mismatched))
        store.retireDiagnosticGeometry(for: places[0]) // Before any asynchronous private-history erase.
        XCTAssertFalse(store.ownsDiagnosticGeometrySource(source))
        XCTAssertNil(store.diagnosticGeometrySource(for: frame))
        XCTAssertTrue(store.places.contains { $0.id == places[0].id })
    }
    func testRapidSelectionsKeepOneWorkerAndOnlyLatestPendingRoom() async throws {
        let (root, store, places) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let loader = Loader(), provider = SavedRoomDiagnosticGeometryProvider(places: store, loader: { loader.load($0) })
        provider.select(places[0].worldFrame)
        await waitUntil { loader.counts.calls == 1 }
        provider.select(places[1].worldFrame); provider.select(places[2].worldFrame)
        XCTAssertNil(provider.geometry); XCTAssertEqual(loader.counts.calls, 1)
        loader.released.signal()
        await waitUntil { loader.counts.calls == 2 }
        XCTAssertEqual(loader.seen, [places[0].worldFrame!, places[2].worldFrame!])
        loader.released.signal()
        await waitUntil { !provider.hasPendingWork }
        XCTAssertEqual(provider.status, .ready)
        XCTAssertEqual(provider.geometry?.frame, places[2].worldFrame)
        XCTAssertEqual(loader.counts.maximumActive, 1)
    }
    func testDeletionDuringDecodeCannotPublishAndNewReadStaysBlocked() async throws {
        let (root, store, places) = try fixture(count: 1)
        defer { try? FileManager.default.removeItem(at: root) }
        let loader = Loader(), provider = SavedRoomDiagnosticGeometryProvider(places: store, loader: { loader.load($0) })
        provider.select(places[0].worldFrame)
        await waitUntil { loader.counts.calls == 1 }
        store.retireDiagnosticGeometry(for: places[0])
        loader.released.signal()
        await waitUntil { !provider.hasPendingWork }
        XCTAssertEqual(provider.status, .unavailable); XCTAssertNil(provider.geometry)
        provider.reload()
        XCTAssertEqual(loader.counts.calls, 1); XCTAssertNil(provider.geometry)
    }
    func testCancelAndSameDescriptorRefreshDoNotResurrectOrDuplicateWork() async throws {
        let (root, store, places) = try fixture(count: 1)
        defer { try? FileManager.default.removeItem(at: root) }
        let loader = Loader(), provider = SavedRoomDiagnosticGeometryProvider(places: store, loader: { loader.load($0) })
        provider.select(places[0].worldFrame)
        await waitUntil { loader.counts.calls == 1 }
        for _ in 0..<20 { provider.select(places[0].worldFrame) }
        provider.cancel(); loader.released.signal()
        await waitUntil { !provider.hasPendingWork }
        XCTAssertEqual(loader.counts.calls, 1); XCTAssertEqual(provider.status, .idle); XCTAssertNil(provider.geometry)
    }
    func testReadyCacheIsWithdrawnOnPlaceDeletionRefresh() async throws {
        let (root, store, places) = try fixture(count: 1)
        defer { try? FileManager.default.removeItem(at: root) }
        let provider = SavedRoomDiagnosticGeometryProvider(places: store, loader: { source in
            do { return .success(try Self.geometry(source.frame)) } catch { return .failure(.invalidGeometry) }
        })
        provider.select(places[0].worldFrame)
        await waitUntil { !provider.hasPendingWork }
        XCTAssertEqual(provider.status, .ready)
        store.delete(places[0]); provider.select(places[0].worldFrame)
        XCTAssertEqual(provider.status, .unavailable); XCTAssertNil(provider.geometry)
    }
    func testDecoderRejectsWrongHashMalformedOriginalAndOversize() throws {
        let (root, store, places) = try fixture(count: 1)
        defer { try? FileManager.default.removeItem(at: root) }
        let frame = try XCTUnwrap(places[0].worldFrame)
        XCTAssertThrowsError(try SavedRoomDiagnosticGeometryDecoder.decode(Data("wrong".utf8), frame: frame)) {
            XCTAssertEqual($0 as? SavedRoomDiagnosticGeometryDecoder.Failure, .sourceMismatch)
        }
        XCTAssertThrowsError(try SavedRoomDiagnosticGeometryDecoder.decode(Data("{}".utf8), frame: frame)) {
            XCTAssertEqual($0 as? SavedRoomDiagnosticGeometryDecoder.Failure, .invalidGeometry)
        }
        XCTAssertThrowsError(try SavedRoomDiagnosticGeometryDecoder.decode(
            Data(count: SavedRoomDiagnosticGeometryDecoder.maximumSourceBytes + 1), frame: frame)) {
            XCTAssertEqual($0 as? SavedRoomDiagnosticGeometryDecoder.Failure, .unsupported)
        }
        let source = try XCTUnwrap(store.diagnosticGeometrySource(for: frame))
        try XCTUnwrap(store.memory).deleteRoom(frame.placeID)
        guard case .failure(.unavailable) = SavedRoomDiagnosticGeometryDecoder.load(source) else { return XCTFail("Deleted source admitted") }
    }
    func testInjectedWrongFrameAndUnsupportedResultsNeverBecomeReady() async throws {
        let (root, store, places) = try fixture(count: 2)
        defer { try? FileManager.default.removeItem(at: root) }
        let other = try Self.geometry(try XCTUnwrap(places[1].worldFrame))
        let provider = SavedRoomDiagnosticGeometryProvider(places: store, loader: { _ in .success(other) })
        provider.select(places[0].worldFrame)
        await waitUntil { !provider.hasPendingWork }
        XCTAssertNil(provider.geometry); XCTAssertEqual(provider.status, .unavailable)
        let unsupported = SavedRoomDiagnosticGeometryProvider(places: store, loader: { _ in .failure(.unsupported) })
        unsupported.select(places[0].worldFrame)
        await waitUntil { !unsupported.hasPendingWork }
        XCTAssertNil(unsupported.geometry); XCTAssertEqual(unsupported.status, .unsupported)
    }
    private final class ReferenceLoader: @unchecked Sendable {
        private let lock = NSLock()
        private var calls = 0, active = 0, maximumActive = 0
        private var frames: [SavedWorldFrame] = []
        let release = DispatchSemaphore(value: 0)
        var counts: (calls: Int, active: Int, maximumActive: Int) {
            lock.lock(); defer { lock.unlock() }; return (calls, active, maximumActive)
        }
        var seen: [SavedWorldFrame] { lock.lock(); defer { lock.unlock() }; return frames }
        func load(_ source: SavedRoomDiagnosticGeometrySource, _ worldURL: URL) -> Result<SpatialMapInstallation, SavedRoomDiagnosticGeometryDecoder.Failure> {
            lock.lock(); calls += 1; active += 1; maximumActive = max(maximumActive, active); frames.append(source.frame); lock.unlock()
            defer { lock.lock(); active -= 1; lock.unlock() }
            guard release.wait(timeout: .now() + 5) == .success else { return .failure(.unavailable) }
            do {
                // Explicit scheduling-only test injection. Fake bytes below are
                // NOT valid Apple archives, and the production decoder rejects them.
                return .success(try SpatialMapInstallation.localSavedFrameReference(frame: source.frame,
                    worldMapBytes: Data("authored-world".utf8), roomCaptureBytes: Data("authored-room".utf8),
                    sha256: { SHA256.hash(data: $0).map { String(format: "%02x", $0) }.joined() }))
            } catch { return .failure(.sourceMismatch) }
        }
    }
    private func referenceFixture(_ loader: ReferenceLoader, count: Int = 3) throws -> (URL, PlaceStore, [SavedPlace]) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("SavedReference-\(UUID().uuidString)")
        let directory = root.appendingPathComponent("Places")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let hash: (String) -> String = { SHA256.hash(data: Data($0.utf8)).map { String(format: "%02x", $0) }.joined() }
        let saved = try (0..<count).map { index -> SavedPlace in
            let id = UUID()
            let frame = SavedWorldFrame(placeID: id.uuidString, revision: UUID().uuidString,
                worldMapSHA256: hash("authored-world"), roomCaptureSHA256: hash("authored-room"),
                originAnchorID: UUID().uuidString, capturedAt: Date(timeIntervalSince1970: 1))
            let place = SavedPlace(id: id, name: "Reference fixture \(index)", createdAt: frame.capturedAt, objects: [], worldFrame: frame)
            try JSONEncoder().encode(place).write(to: directory.appendingPathComponent("\(id).json"))
            return place
        }
        let store = PlaceStore(directory: directory, localReferenceLoader: { loader.load($0, $1) })
        XCTAssertEqual(store.places.count, count); XCTAssertNotNil(store.memory)
        return (root, store, saved)
    }
    func testActualReferenceOwnerKeepsOneHeldWorkerAndOnlyLatestPendingSelection() async throws {
        let loader = ReferenceLoader(), (root, store, places) = try referenceFixture(loader)
        defer { try? FileManager.default.removeItem(at: root) }
        let first = UUID(), second = UUID(), latest = UUID()
        store.debugRequestLocalReference(for: places[0], sessionID: first)
        await waitUntil { loader.counts.calls == 1 }
        store.debugRequestLocalReference(for: places[1], sessionID: second)
        store.debugRequestLocalReference(for: places[2], sessionID: latest)
        XCTAssertTrue(store.debugHasPendingLocalReferenceWork); XCTAssertEqual(loader.counts.calls, 1)
        XCTAssertNil(store.nativeSavedFrameReferenceContext(sessionID: first))
        loader.release.signal()
        await waitUntil { loader.counts.calls == 2 }
        XCTAssertEqual(loader.seen, [places[0].worldFrame!, places[2].worldFrame!])
        XCTAssertNil(store.nativeSavedFrameReferenceContext(sessionID: latest))
        loader.release.signal(); await waitUntil { !store.debugHasPendingLocalReferenceWork }
        XCTAssertEqual(store.nativeSavedFrameReferenceContext(sessionID: latest)?.revision.savedWorldFrame, places[2].worldFrame)
        XCTAssertNil(store.nativeSavedFrameReferenceContext(sessionID: first))
        XCTAssertNil(store.nativeSavedFrameReferenceContext(sessionID: second))
        XCTAssertEqual(loader.counts.maximumActive, 1)
        XCTAssertNil(store.cameraWorldFrameAssociation(sessionID: latest, capturedAt: 0, now: 0))
    }
    func testActualReferenceResetKeepsWorkerLeaseAndCannotPublishHeldCompletion() async throws {
        let loader = ReferenceLoader(), (root, store, places) = try referenceFixture(loader, count: 1)
        defer { try? FileManager.default.removeItem(at: root) }
        let old = UUID(), next = UUID()
        store.debugRequestLocalReference(for: places[0], sessionID: old)
        await waitUntil { loader.counts.calls == 1 }
        store.invalidateWorldMapRecovery()
        XCTAssertTrue(store.debugHasPendingLocalReferenceWork)
        XCTAssertNil(store.nativeSavedFrameReferenceContext(sessionID: old))
        store.debugRequestLocalReference(for: places[0], sessionID: next)
        XCTAssertEqual(loader.counts.calls, 1)
        loader.release.signal(); await waitUntil { loader.counts.calls == 2 }
        XCTAssertNil(store.nativeSavedFrameReferenceContext(sessionID: old))
        XCTAssertNil(store.nativeSavedFrameReferenceContext(sessionID: next))
        loader.release.signal(); await waitUntil { !store.debugHasPendingLocalReferenceWork }
        XCTAssertNotNil(store.nativeSavedFrameReferenceContext(sessionID: next))
        XCTAssertEqual(loader.counts.maximumActive, 1)
    }
    func testActualReferenceDeletionAndMemoryReplacementRejectHeldPublication() async throws {
        for replaceMemory in [false, true] {
            let loader = ReferenceLoader(), (root, store, places) = try referenceFixture(loader, count: 1)
            let (otherRoot, other, _) = try fixture(count: 0)
            defer { try? FileManager.default.removeItem(at: root); try? FileManager.default.removeItem(at: otherRoot) }
            let session = UUID()
            store.debugRequestLocalReference(for: places[0], sessionID: session)
            await waitUntil { loader.counts.calls == 1 }
            if replaceMemory { store.debugReplaceLocalReferenceMemory(other.memory) }
            else { store.retireDiagnosticGeometry(for: places[0]) }
            XCTAssertTrue(store.debugHasPendingLocalReferenceWork)
            loader.release.signal(); await waitUntil { !store.debugHasPendingLocalReferenceWork }
            XCTAssertNil(store.nativeSavedFrameReferenceContext(sessionID: session))
            XCTAssertNil(store.cameraWorldFrameAssociation(sessionID: session, capturedAt: 0, now: 0))
            XCTAssertEqual(loader.counts.maximumActive, 1)
        }
    }

}
