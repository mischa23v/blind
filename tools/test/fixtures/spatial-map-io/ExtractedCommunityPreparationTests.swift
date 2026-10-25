import Foundation
import XCTest
@testable import BlindCore
@testable import NativeSpatialAdapter

final class HeldCommunityInstall: @unchecked Sendable {
    let entered: XCTestExpectation
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?
    init(_ entered: XCTestExpectation) { self.entered = entered }
    func install(_ package: PlacePackage) async throws {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock(); self.continuation = continuation; lock.unlock(); entered.fulfill()
        }
    }
    func finish(_ result: Result<Void, Error>) {
        lock.lock(); let next = continuation; continuation = nil; lock.unlock(); next?.resume(with: result)
    }
}
final class ExtractedCommunityPreparationTests: XCTestCase {
    typealias F = SpatialIntegrationFixture
    override func tearDown() { CommunityCacheTestHooks.set(nil) }
    func package() throws -> PlacePackage {
        var map = F.map(); map.packageID = nil; map.packageRevision = nil
        return try PlacePackage.draft(map: map, author: "Synthetic fixture", license: "Test only")
    }
    func navigator(_ storage: ControlledSpatialStorage) throws -> IndoorNavigator {
        let nav = IndoorNavigator(storage: URL(fileURLWithPath: "/unused-synthetic-path"), storageIO: storage, sha256: F.sha256)
        let done = expectation(description: "setup"); let bytes = try F.installation().encoded()
        nav.loadImportedMap(bytes) { result in if case .failure(let error) = result { XCTFail("Unexpected: \(error)") }; done.fulfill() }
        wait(for: [done], timeout: 5); return nav
    }
    func testExactViewDeferredCleanupReleasesBusyAfterDeleteSupersedesCache() throws {
        let storage = ControlledSpatialStorage(), nav = try navigator(storage), view = CommunityPreparationHarness(indoor: nav)
        let entered = expectation(description: "cache await is actually suspended"), gate = HeldCommunityInstall(entered)
        CommunityCacheTestHooks.set { package in try await gate.install(package) }
        let idle = expectation(description: "owned view busy state released")
        view.onIdle = { idle.fulfill() }; view.start(try package())
        wait(for: [entered], timeout: 5); XCTAssertTrue(view.busy)
        let deleted = expectation(description: "delete")
        nav.deleteMap { result in if case .failure(let error) = result { XCTFail("Unexpected: \(error)") }; deleted.fulfill() }
        wait(for: [deleted], timeout: 5); let status = nav.message
        gate.finish(.success(())); wait(for: [idle], timeout: 5)
        XCTAssertFalse(view.busy); XCTAssertNil(storage.bytes); XCTAssertNil(nav.map); XCTAssertEqual(nav.message, status)
    }
    func testExactViewFailureCleanupDoesNotOverwriteNewerMapStatus() throws {
        let storage = ControlledSpatialStorage(), nav = try navigator(storage), view = CommunityPreparationHarness(indoor: nav)
        let entered = expectation(description: "cache suspended"), gate = HeldCommunityInstall(entered)
        CommunityCacheTestHooks.set { package in try await gate.install(package) }
        let idle = expectation(description: "busy released")
        view.onIdle = { idle.fulfill() }; view.start(try package())
        wait(for: [entered], timeout: 5)
        let next = try F.installation(map: F.map(revision: "r2"), prior: F.installation()).encoded()
        let imported = expectation(description: "new map installed")
        nav.loadImportedMap(next) { result in if case .failure(let error) = result { XCTFail("Unexpected: \(error)") }; imported.fulfill() }
        wait(for: [imported], timeout: 5); let status = nav.message
        gate.finish(.failure(CocoaError(.fileWriteUnknown))); wait(for: [idle], timeout: 5)
        XCTAssertEqual(nav.map?.packageRevision, "r2"); XCTAssertEqual(nav.message, status); XCTAssertEqual(view.error, "")
        XCTAssertFalse(view.busy)
    }
    func testExactViewOwnerSpecificFinishCannotClearNewerPreparation() throws {
        let storage = ControlledSpatialStorage(), nav = try navigator(storage), view = CommunityPreparationHarness(indoor: nav)
        let old = view.claim(), current = view.claim()
        XCTAssertFalse(view.finish(old)); XCTAssertTrue(view.busy)
        XCTAssertTrue(view.finish(current)); XCTAssertFalse(view.busy)
    }
}
