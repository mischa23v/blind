import Foundation
import XCTest
@testable import BlindCore
#if canImport(NativeSpatialAdapter)
@testable import NativeSpatialAdapter
#else
@testable import BlindAssist
#endif

/// Executes the complete staged IndoorNavigator controller (only its Combine
/// import removed). PlatformTestStubs explicitly exclude Apple UI/diagnostic/
/// community/IndoorSituation behavior from these assertions.
final class IndoorNavigatorAsyncTests: XCTestCase {
    typealias F = SpatialIntegrationFixture
    func complete(_ action: (@escaping IndoorNavigator.MapCompletion) throws -> Void) throws {
        let done = expectation(description: "actual navigator completion")
        var result: Result<Void, Error>?
        try action { result = $0; done.fulfill() }
        wait(for: [done], timeout: 10); try XCTUnwrap(result).get()
    }
    func ready(_ storage: ControlledSpatialStorage) throws -> IndoorNavigator {
        let nav = IndoorNavigator(storage: URL(fileURLWithPath: "/unused-synthetic-path"), storageIO: storage, sha256: F.sha256)
        try complete { nav.loadImportedMap(try F.installation().encoded(), completion: $0) }
        try nav.configureRegisteredNavigation(body: F.body, limits: F.limits)
        try nav.plan(from: "start", to: "end", goalRevision: UUID())
        let now = ProcessInfo.processInfo.systemUptime
        let capture = SpatialLocalizationCapture(sessionID: try XCTUnwrap(nav.registeredSessionID),
            binding: try F.installation().binding, floorID: "floor", position: Point3(1, 1.3, 3), bodyYaw: -.pi / 2,
            source: .alignedMapPose, headingSource: .bodyAligned, trackingNormal: true,
            positionUncertainty: 0.1, headingUncertainty: 0.1, capturedAt: now)
        try nav.acceptRegisteredCapture(capture, support: F.support(capture), now: now)
        XCTAssertNotNil(nav.next(camera: .init(0, 0, 0), forward: .init(0, 0, -1)))
        return nav
    }
    func testActualControllerRetiresPoseAndOutputBeforeBlockedImportThenPreservesNewTaskCaption() throws {
        let storage = ControlledSpatialStorage(), nav = try ready(storage), original = try F.installation()
        let next = try F.installation(map: F.map(revision: "r2"), prior: original).encoded()
        let entered = expectation(description: "writer blocked"), release = storage.blockNextWrite(entered), done = expectation(description: "import complete")
        var retired = 0; nav.onSpatialOutputRetired = { retired += 1 }
        nav.loadImportedMap(next) { result in
            if case .failure(let error) = result { XCTFail("Unexpected: \(error)") }; done.fulfill()
        }
        XCTAssertTrue(nav.mapIOPending); XCTAssertNil(nav.exportURL); XCTAssertFalse(nav.isAligned); XCTAssertEqual(retired, 1)
        XCTAssertFalse(nav.hasActiveRoute)
        wait(for: [entered], timeout: 5)
        nav.cancelRoute(); let currentCaption = nav.message
        release.signal(); wait(for: [done], timeout: 5)
        XCTAssertEqual(nav.map?.packageRevision, "r2"); XCTAssertFalse(nav.mapIOPending)
        XCTAssertEqual(nav.message, currentCaption); XCTAssertFalse(nav.hasActiveRoute); XCTAssertFalse(nav.isAligned)
    }
    func testDelayedPrivacyPurgeCannotDeleteNewerImportOrOverwriteItsStatus() throws {
        let storage = ControlledSpatialStorage(), nav = try ready(storage)
        var purge: ((Bool) -> Void)?
        nav.clearObservationHistory = { purge = $0 }
        let deleted = expectation(description: "old delete superseded")
        nav.deleteMap { result in
            if case .success = result { XCTFail("Unfinished privacy purge claimed deletion") }; deleted.fulfill()
        }
        XCTAssertNotNil(purge); XCTAssertFalse(nav.isAligned); XCTAssertTrue(nav.mapIOPending)
        try complete { nav.loadImportedMap(try F.installation().encoded(), completion: $0) }
        let status = nav.message, bytes = storage.bytes
        purge?(false)
        wait(for: [deleted], timeout: 5)
        XCTAssertEqual(storage.bytes, bytes); XCTAssertEqual(nav.message, status)
        XCTAssertNotNil(nav.map); XCTAssertFalse(nav.mapIOPending)
    }
    func testPrivacyPurgePrecedesActualDeleteAndFailureKeepsMapUnavailable() throws {
        let storage = ControlledSpatialStorage(), nav = try ready(storage)
        var purge: ((Bool) -> Void)?; nav.clearObservationHistory = { purge = $0 }
        let done = expectation(description: "delete failure")
        nav.deleteMap { result in if case .success = result { XCTFail("Delete failed but reported success") }; done.fulfill() }
        XCTAssertFalse(storage.log.contains("delete")); XCTAssertFalse(nav.isAligned)
        storage.failDeletes(true); purge?(true)
        wait(for: [done], timeout: 5)
        XCTAssertEqual(storage.log.last, "delete"); XCTAssertNotNil(storage.bytes)
        XCTAssertNil(nav.exportURL); XCTAssertFalse(nav.isAligned); XCTAssertFalse(nav.mapIOPending)
        XCTAssertNil(nav.registeredObservationMapTarget); XCTAssertFalse(nav.canRemoveStoredKeepOutZones)
        XCTAssertThrowsError(try nav.configureRegisteredNavigation(body: F.body, limits: F.limits))
        nav.clearObservationHistory = { $0(true) }; storage.failDeletes(false)
        try complete { nav.deleteMap(completion: $0) }
        XCTAssertNil(storage.bytes); XCTAssertNil(nav.map)
        XCTAssertEqual(nav.message, "Route map deleted.")
    }
    func testActualControllerAsyncFileImportRejectsOversizedInputWithoutMainRead() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("map.json")
        try Data().write(to: file); let handle = try FileHandle(forWritingTo: file)
        try handle.truncate(atOffset: 2_000_000_000); try handle.close()
        let storage = ControlledSpatialStorage(), nav = try ready(storage), old = storage.bytes
        XCTAssertThrowsError(try complete { nav.importMapFile(file, completion: $0) })
        XCTAssertEqual(storage.bytes, old); XCTAssertFalse(nav.isAligned); XCTAssertNil(nav.exportURL)
    }
    func testDelayedCommunityCacheCompletionCannotResurrectDeletedMap() throws {
        let storage = ControlledSpatialStorage(), nav = try ready(storage)
        var preview = F.map(); preview.packageID = nil; preview.packageRevision = nil
        let package = try PlacePackage.draft(map: preview, author: "Synthetic fixture", license: "Test only")
        let intent = nav.beginCommunityImport(package)
        XCTAssertFalse(nav.isAligned); XCTAssertFalse(nav.hasActiveRoute); XCTAssertTrue(nav.mapIOPending)
        try complete { nav.deleteMap(completion: $0) }
        let status = nav.message
        XCTAssertThrowsError(try complete { nav.completeCommunityImport(package, intent: intent, completion: $0) })
        nav.failCommunityImport(intent)
        XCTAssertNil(nav.map); XCTAssertNil(storage.bytes); XCTAssertEqual(nav.message, status)
    }
    func testDelayedCommunityCacheCompletionCannotOverwriteNewImport() throws {
        let storage = ControlledSpatialStorage(), nav = try ready(storage)
        var preview = F.map(); preview.packageID = nil; preview.packageRevision = nil
        let package = try PlacePackage.draft(map: preview, author: "Synthetic fixture", license: "Test only")
        let intent = nav.beginCommunityImport(package)
        let replacement = try F.installation(map: F.map(revision: "r2"), prior: F.installation())
        try complete { nav.loadImportedMap(try replacement.encoded(), completion: $0) }
        let bytes = storage.bytes, status = nav.message
        XCTAssertThrowsError(try complete { nav.completeCommunityImport(package, intent: intent, completion: $0) })
        XCTAssertEqual(nav.map?.packageRevision, "r2"); XCTAssertEqual(storage.bytes, bytes); XCTAssertEqual(nav.message, status)
    }

    func testPublicPlanAttemptDuringBlockedSaveRetiresOldReplanContinuation() throws {
        let storage = ControlledSpatialStorage()
        let nav = IndoorNavigator(storage: URL(fileURLWithPath: "/unused-synthetic-path"), storageIO: storage, sha256: F.sha256)
        var map = F.map()
        map.nodes.append(.init(id: "detour", name: "Synthetic detour", level: "ground", position: .init(1, 0, 4)))
        map.edges += [.init(from: "start", to: "detour", distance: 1), .init(from: "detour", to: "middle", distance: 3)]
        try complete { nav.loadImportedMap(try F.installation(map: map).encoded(), completion: $0) }
        try nav.configureRegisteredNavigation(body: F.body, limits: F.limits)
        try nav.plan(from: "start", to: "end")
        let entered = expectation(description: "blocked-leg save entered"), release = storage.blockNextWrite(entered)
        let done = expectation(description: "save completed but route not resurrected")
        nav.blockNextLeg { result in if case .failure(let error) = result { XCTFail("Unexpected: \(error)") }; done.fulfill() }
        wait(for: [entered], timeout: 5)
        XCTAssertThrowsError(try nav.plan(from: "middle", to: "end"))
        release.signal(); wait(for: [done], timeout: 5)
        XCTAssertTrue(nav.route.isEmpty); XCTAssertFalse(nav.hasActiveRoute)
        XCTAssertNotNil(nav.map); XCTAssertFalse(nav.mapIOPending)
    }

    func testActualInitializerRestoresBoundedMapAsynchronouslyAndKeepsPoseUnknown() throws {
        let storage = ControlledSpatialStorage(try F.installation().encoded())
        let restored = expectation(description: "initializer restore completed")
        let nav = IndoorNavigator(storage: URL(fileURLWithPath: "/unused-synthetic-path"), storageIO: storage,
                                  sha256: F.sha256, restoreCompletion: { result in
            if case .failure(let error) = result { XCTFail("Unexpected: \(error)") }; restored.fulfill()
        })
        XCTAssertTrue(nav.mapIOPending); XCTAssertNil(nav.map)
        wait(for: [restored], timeout: 5)
        XCTAssertNotNil(nav.map); XCTAssertFalse(nav.isAligned); XCTAssertFalse(nav.hasActiveRoute)
        XCTAssertEqual(storage.readCaps, [SpatialMapInstallation.maximumEnvelopeBytes])
    }
    func testDelayedMissingStartupFileCannotOverwriteNewerTaskCaption() throws {
        let storage = ControlledSpatialStorage(), entered = expectation(description: "restore read blocked")
        let release = storage.blockNextRead(entered), done = expectation(description: "restore resolved")
        let nav = IndoorNavigator(storage: URL(fileURLWithPath: "/unused-synthetic-path"), storageIO: storage,
                                  sha256: F.sha256, restoreCompletion: { result in
            if case .success = result { XCTFail("Missing file became success") }; done.fulfill()
        })
        wait(for: [entered], timeout: 5)
        nav.cancelRoute(); let caption = nav.message
        release.signal(); wait(for: [done], timeout: 5)
        XCTAssertEqual(nav.message, caption); XCTAssertFalse(nav.mapIOPending); XCTAssertNil(nav.map)
    }

    func testPendingOrFailedReplacementCannotTagObservationsWithRetainedOldMap() throws {
        let storage = ControlledSpatialStorage(), nav = try ready(storage), original = try F.installation()
        XCTAssertEqual(nav.registeredObservationMapTarget, original.binding)
        let entered = expectation(description: "replacement write blocked"), release = storage.blockNextWrite(entered)
        let done = expectation(description: "replacement failed")
        storage.failWrites(true)
        nav.loadImportedMap(try F.installation(map: F.map(revision: "r2"), prior: original).encoded()) { result in
            if case .success = result { XCTFail("Failed write became success") }; done.fulfill()
        }
        XCTAssertNil(nav.registeredObservationMapTarget)
        wait(for: [entered], timeout: 5); release.signal(); wait(for: [done], timeout: 5)
        XCTAssertNil(nav.registeredObservationMapTarget); XCTAssertFalse(nav.isAligned)
        XCTAssertEqual(nav.map?.packageRevision, "r1") // retained preview metadata is not a live observation target
        try complete { nav.loadImportedMap(try original.encoded(), completion: $0) }
        XCTAssertEqual(nav.registeredObservationMapTarget, original.binding)
        XCTAssertFalse(nav.isAligned) // durable selection recovery is not localization
    }
    func testFailedPrivacyPurgeCannotDowngradeRetainedRegisteredMapThroughPreviewEdits() throws {
        let storage = ControlledSpatialStorage(), nav = try ready(storage), originalBytes = storage.bytes
        nav.clearObservationHistory = { $0(false) }
        XCTAssertThrowsError(try complete { nav.deleteMap(completion: $0) })
        XCTAssertNotNil(nav.map); XCTAssertFalse(nav.canRemoveStoredKeepOutZones)
        XCTAssertNil(nav.registeredObservationMapTarget); XCTAssertNil(nav.exportURL)
        XCTAssertThrowsError(try complete { nav.removeKeepOutZone(id: "nonexistent-synthetic-zone", completion: $0) })
        XCTAssertThrowsError(try complete { nav.addKeepOutZone(landmarkID: "start", halfSize: 0.5, completion: $0) })
        XCTAssertEqual(storage.bytes, originalBytes)
        XCTAssertFalse(storage.log.contains("delete"))
        nav.clearObservationHistory = { $0(true) }
        try complete { nav.deleteMap(completion: $0) }
        XCTAssertNil(nav.map); XCTAssertNil(storage.bytes); XCTAssertNil(nav.registeredObservationMapTarget)
        let installed = try F.installation()
        try complete { nav.loadImportedMap(try installed.encoded(), completion: $0) }
        XCTAssertEqual(nav.registeredObservationMapTarget, installed.binding)
        XCTAssertFalse(nav.canRemoveStoredKeepOutZones); XCTAssertFalse(nav.isAligned)
    }

}

extension IndoorNavigatorAsyncTests {
    func testJourneyHooksWithdrawSynchronouslyAndPublishAfterCurrentCAS() throws {
        let storage = ControlledSpatialStorage(), nav = try ready(storage), original = try F.installation()
        let next = try F.installation(map:F.map(revision:"r2"),prior:original)
        let entered = expectation(description:"journey replacement blocked"), release = storage.blockNextWrite(entered)
        let done = expectation(description:"journey replacement done")
        var withdrawals:[UUID] = [], publications:[(UUID,SpatialMapInstallation?,SpatialMapBinding?,Bool)] = []
        nav.onJourneyMapOwnershipWithdrawn = { withdrawals.append($0) }
        nav.onJourneyMapPublished = { publications.append(($0,$1,$2,$3)) }
        nav.loadImportedMap(try next.encoded()) { result in if case .failure(let error) = result { XCTFail("\(error)") }; done.fulfill() }
        XCTAssertEqual(withdrawals,[nav.revision]); XCTAssertNil(nav.registeredJourneyInstallation); XCTAssertTrue(publications.isEmpty)
        wait(for:[entered],timeout:5); release.signal(); wait(for:[done],timeout:5)
        XCTAssertEqual(publications.count,1); XCTAssertEqual(publications.first?.0,nav.revision)
        XCTAssertEqual(publications.first?.1?.binding,next.binding); XCTAssertNil(publications.first?.2); XCTAssertEqual(publications.first?.3,false)
        XCTAssertEqual(nav.registeredJourneyInstallation?.binding,next.binding)
    }
    func testJourneyHooksDoNotConfuseLegacyPreviewWithDeletedMapOrPublishStaleDelete() throws {
        let storage = ControlledSpatialStorage(), nav = try ready(storage)
        var purge:((Bool)->Void)?; nav.clearObservationHistory = { purge = $0 }
        var publications:[(UUID,SpatialMapInstallation?,SpatialMapBinding?,Bool)] = []
        nav.onJourneyMapPublished = { publications.append(($0,$1,$2,$3)) }
        let stale = expectation(description:"superseded delete")
        nav.deleteMap { result in if case .success = result { XCTFail("stale delete succeeded") }; stale.fulfill() }
        var preview = F.map(); preview.packageID = nil; preview.packageRevision = nil
        try complete { nav.loadImportedMap(try JSONEncoder().encode(preview),completion:$0) }
        XCTAssertEqual(publications.count,1); XCTAssertNil(publications[0].1); XCTAssertNil(publications[0].2); XCTAssertFalse(publications[0].3)
        XCTAssertNil(nav.registeredJourneyInstallation)
        purge?(true); wait(for:[stale],timeout:5)
        XCTAssertEqual(publications.count,1)
    }
    func testJourneyDeletionPublishesOnlyRemovedBindingWithoutGeometry() throws {
        let storage = ControlledSpatialStorage(), nav = try ready(storage), binding = try F.installation().binding
        var publication:(UUID,SpatialMapInstallation?,SpatialMapBinding?,Bool)?
        nav.onJourneyMapPublished = { publication = ($0,$1,$2,$3) }
        try complete { nav.deleteMap(completion:$0) }
        XCTAssertEqual(publication?.0,nav.revision); XCTAssertNil(publication?.1)
        XCTAssertEqual(publication?.2,binding); XCTAssertEqual(publication?.3,true)
        XCTAssertNil(nav.registeredJourneyInstallation)
    }
}
