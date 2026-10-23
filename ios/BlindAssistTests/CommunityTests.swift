import XCTest
import BlindCore
@testable import BlindAssist

/// Native platform integration tests: real file protection, hashing, JSON and URLSession byte handling.
/// No external network, models, private maps or physical navigation are used.
final class CommunityTests: XCTestCase {
    private var directory: URL!
    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("CommunityTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        MapURLProtocol.configure(status: 200, data: Data())
    }
    override func tearDownWithError() throws {
        // Only the UUID test directory created above is removed.
        if let directory { try FileManager.default.removeItem(at: directory) }
        MapURLProtocol.configure(status: 200, data: Data())
    }
    private func package() throws -> PlacePackage {
        let map = IndoorMap(name: "Test map", nodes: [MapNode(id: "door", name: "Door", level: "level", position: Point3(0, 0, 0))], edges: [])
        var value = try PlacePackage.draft(map: map, author: "Test contributor", license: "Test fixture only")
        value.visibility = "public"; return value
    }
    private var client: PublicMapClient { PublicMapClient(protocolClasses: [MapURLProtocol.self]) }
    private func release(bytes: Int, digest: String? = nil) -> PublicMapRelease {
        PublicMapRelease(id: "fixture:1", name: "example.blindplace.json", repository: "fixture/maps", tag: "v1",
                         url: URL(string: "https://github.com/fixture/maps/releases/download/v1/example.blindplace.json")!, bytes: bytes, digest: digest)
    }
    func testInstallReopenConflictAndImmutableOlderRevision() async throws {
        let storage = CommunityPackageStorage(directory: directory), value = try package()
        let installed = try await storage.install(value)
        XCTAssertEqual(installed.installed.count, 1)
        let again = try await storage.install(value); XCTAssertEqual(again.installed.count, 1)
        var conflict = value; conflict.description = "Changed under the same revision"
        do { _ = try await storage.install(conflict); XCTFail("Changed revision was accepted") }
        catch CommunityError.conflict {} catch { XCTFail("Unexpected error: \(error)") }
        conflict.revision = UUID().uuidString
        let next = try await storage.install(conflict); XCTAssertEqual(next.installed.count, 2)
        let reopened = CommunityPackageStorage(directory: directory)
        let original = try await reopened.load(digest: installed.installed[0].digest)
        XCTAssertEqual(original.description, value.description)
        let contents = try await reopened.list(); XCTAssertEqual(contents.installed.count, 2)
    }
    func testCorruptionDoesNotHideOtherMapsAndRequiresExplicitRemoval() async throws {
        let storage = CommunityPackageStorage(directory: directory), value = try package()
        let first = try await storage.install(value), digest = try XCTUnwrap(first.installed.first?.digest)
        var other = try package(); other.name = "Another map"
        _ = try await storage.install(other)
        let file = directory.appendingPathComponent(digest).appendingPathExtension("json")
        try Data("corrupted".utf8).write(to: file)
        let damaged = try await storage.list()
        XCTAssertEqual(damaged.installed.count, 1); XCTAssertEqual(damaged.issues.map(\.id), [digest])
        do { _ = try await storage.install(value); XCTFail("Damaged evidence was overwritten") }
        catch CommunityError.checksum {} catch { XCTFail("Unexpected error: \(error)") }
        _ = try await storage.remove(digest: digest)
        let repaired = try await storage.install(value)
        XCTAssertEqual(repaired.installed.count, 2); XCTAssertTrue(repaired.issues.isEmpty)
    }
    func testOversizedAndSymlinkFilesAreExcludedWithoutReadingTarget() async throws {
        let storage = CommunityPackageStorage(directory: directory)
        let large = String(repeating: "a", count: 64), link = String(repeating: "b", count: 64)
        try Data(repeating: 32, count: PlacePackage.maximumBytes + 1).write(to: directory.appendingPathComponent(large).appendingPathExtension("json"))
        let target = directory.appendingPathComponent("private-target.txt")
        try Data("private fixture".utf8).write(to: target)
        try FileManager.default.createSymbolicLink(at: directory.appendingPathComponent(link).appendingPathExtension("json"), withDestinationURL: target)
        let result = try await storage.list()
        XCTAssertTrue(result.installed.isEmpty); XCTAssertEqual(result.issues.count, 2)
        _ = try await storage.remove(digest: link)
        XCTAssertEqual(try String(contentsOf: target, encoding: .utf8), "private fixture")
        do { _ = try await storage.load(digest: "../private-target"); XCTFail("Path traversal accepted") }
        catch CommunityError.invalid {} catch { XCTFail("Unexpected error: \(error)") }
    }
    func testPublicReleaseFilteringUsesUploadedCompatibleAssetsAndRepository() async throws {
        let asset: [String: Any] = ["id": 1, "name": "map.blindplace.json", "browser_download_url": "https://github.com/fixture/maps/releases/download/v1/map.blindplace.json", "size": 20, "state": "uploaded"]
        var foreign = asset; foreign["id"] = 2; foreign["browser_download_url"] = "https://github.com/other/maps/releases/download/v1/map.blindplace.json"
        var oversized = asset; oversized["id"] = 3; oversized["size"] = PlacePackage.maximumBytes + 1
        var wrongKind = asset; wrongKind["id"] = 4; wrongKind["name"] = "program.zip"
        let published: [String: Any] = ["name": "Public", "tag_name": "v1", "draft": false, "prerelease": false, "assets": [asset, foreign, oversized, wrongKind]]
        var draft = published; draft["draft"] = true
        MapURLProtocol.configure(status: 200, data: try JSONSerialization.data(withJSONObject: [published, draft]))
        let releases = try await client.releases(repository: "fixture/maps", page: 1)
        XCTAssertEqual(releases.count, 1); XCTAssertEqual(releases[0].id, "fixture/maps:1")
        let request = try XCTUnwrap(MapURLProtocol.lastRequest)
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-GitHub-Api-Version"), "2026-03-10")
        XCTAssertThrowsError(try PublicMapClient.repositoryParts("../maps"))
        XCTAssertFalse(PublicMapClient.allowed(URL(string: "https://github.com.attacker.example/file")!))
        XCTAssertFalse(PublicMapClient.allowed(URL(string: "https://name:password@github.com/file")!))
    }
    func testCountAndByteQuotaFailuresKeepSavedRevisionIntact() async throws {
        let storage = CommunityPackageStorage(directory: directory, maximumRevisions: 1)
        let first = try await storage.install(package()), original = try XCTUnwrap(first.installed.first)
        do { _ = try await storage.install(package()); XCTFail("Revision quota exceeded") }
        catch CommunityError.quota {} catch { XCTFail("Unexpected error: \(error)") }
        let retained = try await storage.load(digest: original.digest)
        XCTAssertEqual(retained.id, original.package.id)
        let bytes = CommunityPackageStorage(directory: directory, maximumStorage: 1)
        do { _ = try await bytes.install(package()); XCTFail("Byte quota exceeded") }
        catch CommunityError.quota {} catch { XCTFail("Unexpected error: \(error)") }
        let inventory = try await storage.list(); XCTAssertEqual(inventory.installed.count, 1)
    }
    func testHTTPFailureAndStreamingSizeLimit() async throws {
        MapURLProtocol.configure(status: 429, data: Data())
        do { _ = try await client.download(release(bytes: 1)); XCTFail("HTTP failure accepted") }
        catch CommunityError.http(429) {} catch { XCTFail("Unexpected error: \(error)") }
        // No Content-Length header: the adapter must bound actual streamed bytes.
        MapURLProtocol.configure(status: 200, data: Data(repeating: 32, count: PlacePackage.maximumBytes + 1))
        do { _ = try await client.download(release(bytes: 1)); XCTFail("Oversized stream accepted") }
        catch CommunityError.tooLarge {} catch { XCTFail("Unexpected error: \(error)") }
        MapURLProtocol.configure(status: 200, data: Data("short".utf8))
        do { _ = try await client.download(release(bytes: 100)); XCTFail("Changed asset size accepted") }
        catch CommunityError.checksum {} catch { XCTFail("Unexpected error: \(error)") }
    }
    @MainActor private func idle(_ library: CommunityLibrary) async throws {
        for _ in 0..<500 {
            if !library.busy { return }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Library did not complete within five seconds")
    }
    @MainActor func testOfflineLaunchStillLoadsMapsAndRejectsNetwork() async throws {
        let storage = CommunityPackageStorage(directory: directory)
        _ = try await storage.install(package())
        let library = CommunityLibrary(storage: storage, client: client)
        library.networkAllowed = false // Mirrors onAppear; must not cancel a local reload.
        try await idle(library)
        XCTAssertEqual(library.installed.count, 1)
        library.search(repository: "fixture/maps")
        XCTAssertFalse(library.busy); XCTAssertNil(MapURLProtocol.lastRequest)
        XCTAssertTrue(library.status.contains("Offline"))
    }
    @MainActor func testDownloadChecksDigestAndDoesNotInstallUntilReviewed() async throws {
        let storage = CommunityPackageStorage(directory: directory), value = try package(), bytes = try value.encoded()
        let library = CommunityLibrary(storage: storage, client: client)
        try await idle(library); library.networkAllowed = true
        MapURLProtocol.configure(status: 200, data: bytes)
        library.download(release(bytes: bytes.count, digest: "sha256:" + String(repeating: "0", count: 64)))
        try await idle(library); XCTAssertNil(library.preview)
        library.download(release(bytes: bytes.count, digest: "sha256:" + CommunityPackageStorage.digest(bytes)))
        try await idle(library); XCTAssertEqual(library.preview?.id, value.id); XCTAssertTrue(library.installed.isEmpty)
        library.savePreview(); try await idle(library); XCTAssertEqual(library.installed.count, 1)
    }
    @MainActor func testOfflineToggleCancelsPendingDownloadWithoutLatePreview() async throws {
        let storage = CommunityPackageStorage(directory: directory), bytes = try package().encoded()
        let library = CommunityLibrary(storage: storage, client: client)
        try await idle(library); library.networkAllowed = true
        MapURLProtocol.configure(status: 200, data: bytes, delay: 0.2)
        library.download(release(bytes: bytes.count))
        try await Task.sleep(nanoseconds: 30_000_000)
        library.networkAllowed = false
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertFalse(library.busy); XCTAssertNil(library.preview); XCTAssertTrue(library.installed.isEmpty)
        let inventory = try await storage.list(); XCTAssertTrue(inventory.installed.isEmpty)
    }
    @MainActor func testPublicCopyKeepsProvenanceButDropsOldReviewClaims() async throws {
        let storage = CommunityPackageStorage(directory: directory)
        var value = try package(); value.visibility = "private"
        value.reviews = [.init(id: "review", revision: value.revision, reviewer: "Test reviewer", scope: "labels",
                              date: "2026-10-08T00:00:00Z", method: "Test labels", limitations: "No physical test")]
        let stored = try await storage.install(value)
        let library = CommunityLibrary(storage: storage, client: client); try await idle(library)
        library.review(try XCTUnwrap(stored.installed.first)); try await idle(library)
        library.preparePublicCopy()
        XCTAssertEqual(library.preview?.id, value.id); XCTAssertNotEqual(library.preview?.revision, value.revision)
        XCTAssertEqual(library.preview?.license, value.license); XCTAssertEqual(library.preview?.author, value.author)
        XCTAssertEqual(library.preview?.visibility, "public"); XCTAssertEqual(library.preview?.reviews.count, 0)
        let unchanged = try await storage.load(digest: stored.installed[0].digest)
        XCTAssertEqual(unchanged.visibility, "private"); XCTAssertEqual(unchanged.reviews.count, 1)
    }
}

/// Standard URLProtocol seam: the production URLSession still performs the byte iteration.
private final class MapURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var status = 200
    private static var data = Data()
    private static var delay: TimeInterval = 0
    private static var requestValue: URLRequest?
    private var pending: DispatchWorkItem?
    static var lastRequest: URLRequest? { lock.lock(); defer { lock.unlock() }; return requestValue }
    static func configure(status: Int, data: Data, delay: TimeInterval = 0) {
        lock.lock(); defer { lock.unlock() }; self.status = status; self.data = data; self.delay = delay; requestValue = nil
    }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.lock(); let status = Self.status, bytes = Self.data, delay = Self.delay; Self.requestValue = request; Self.lock.unlock()
        guard let url = request.url, let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil) else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            self.client?.urlProtocol(self, didLoad: bytes)
            self.client?.urlProtocolDidFinishLoading(self)
        }
        pending = work; DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }
    override func stopLoading() { pending?.cancel() }
}

/// Exercises the actual native context adapter, not a hand-written relay payload.
final class AssistantSituationTests: XCTestCase {
    func testRestoredBathroomGoalDoesNotRestorePoseOrInventRoomOwnership() throws {
        var dialogue = AssistantDialogue(); dialogue.setGoal("Use the bathroom inside my bedroom")
        dialogue.record(role: "user", text: "I have entered a room. Where am I?")
        let restored = try JSONDecoder().decode(AssistantDialogue.self, from: JSONEncoder().encode(dialogue))
        let snapshot = AssistantSituation.snapshot(dialogue: restored, preview: nil, layout: nil)
        let location = try XCTUnwrap(snapshot["location"] as? [String: Any])
        XCTAssertEqual(location["state"] as? String, "unknown")
        for key in ["placeID", "floorID", "frameID", "position", "cameraForward", "bodyForward", "mapRevision"] {
            XCTAssertTrue(location[key] is NSNull, "Restored unsupported live field: \(key)")
        }
        let goal = try XCTUnwrap(snapshot["goal"] as? [String: Any])
        XCTAssertEqual(goal["description"] as? String, dialogue.goal)
        XCTAssertTrue(goal["targetPlaceID"] is NSNull)
        XCTAssertTrue((snapshot["connections"] as? [Any])?.isEmpty == true)
        XCTAssertTrue((snapshot["deliveredFactIDs"] as? [Any])?.isEmpty == true)
        XCTAssertTrue(JSONSerialization.isValidJSONObject(snapshot))
    }
    func testReviewedRoomIsHistoricalPreviewNotCurrentRoomOrEmptyChair() throws {
        let place = SavedPlace(id: UUID(), name: "Relative's living room", createdAt: Date(timeIntervalSinceNow: -3600), objects: [])
        let chair = RoomFeature(id: "chair", kind: "furniture", category: "chair", confidence: "high",
                                corners: [Point3(0, 0, 0), Point3(1, 0, 0), Point3(1, 0, 1), Point3(0, 0, 1)])
        var layout = RoomLayout(name: place.name, features: [chair]); layout.revisionID = "reviewed-revision"
        let snapshot = AssistantSituation.snapshot(dialogue: AssistantDialogue(), preview: place, layout: layout)
        let location = try XCTUnwrap(snapshot["location"] as? [String: Any])
        XCTAssertEqual(location["state"] as? String, "unknown")
        let entities = try XCTUnwrap(snapshot["entities"] as? [[String: Any]])
        XCTAssertEqual(entities.count, 1); XCTAssertEqual(entities[0]["state"] as? String, "mapped")
        XCTAssertEqual(entities[0]["sourceID"] as? String, "reviewed-revision")
        XCTAssertGreaterThan(try XCTUnwrap(entities[0]["ageMS"] as? Double), 0)
        XCTAssertTrue((snapshot["connections"] as? [Any])?.isEmpty == true)
    }
    func testUnreviewedInventoryIsOmittedAndInterestIsNotAnObservation() throws {
        let place = SavedPlace(id: UUID(), name: "Unconfirmed room", createdAt: Date(), objects: [])
        let layout = RoomLayout(name: place.name, features: [])
        var preferences = AssistantPreferences(); XCTAssertTrue(preferences.add(category: "interest", value: "Aquariums"))
        let snapshot = AssistantSituation.snapshot(dialogue: AssistantDialogue(), preview: place, layout: layout, preferences: preferences)
        XCTAssertTrue((snapshot["places"] as? [Any])?.isEmpty == true)
        XCTAssertTrue((snapshot["entities"] as? [Any])?.isEmpty == true)
        let hints = try XCTUnwrap(snapshot["preferences"] as? [[String: String]])
        XCTAssertEqual(hints.first?["value"], "Aquariums"); XCTAssertEqual(hints.first?["source"], "user")
    }
    func testLongDescriptionFollowUpAndGoalChangeReachNativeSnapshot() throws {
        var dialogue = AssistantDialogue(); dialogue.setGoal("Explore the living room")
        let answer = String(repeating: "The painting contains blue shapes. ", count: 12) + "The artist is unknown."
        dialogue.record(role: "assistant", text: answer); dialogue.record(role: "user", text: "Tell me more about it")
        let snapshot = AssistantSituation.snapshot(dialogue: dialogue, preview: nil, layout: nil)
        let conversation = try XCTUnwrap(snapshot["conversation"] as? [String: Any])
        let turns = try XCTUnwrap(conversation["turns"] as? [[String: String]])
        XCTAssertEqual(turns.first?["text"], answer)
        let revision = dialogue.goalRevision
        dialogue.setGoal("Go to my computer")
        let changed = AssistantSituation.snapshot(dialogue: dialogue, preview: nil, layout: nil)
        let changedConversation = try XCTUnwrap(changed["conversation"] as? [String: Any])
        XCTAssertNotEqual(changedConversation["goalRevision"] as? String, revision)
        XCTAssertEqual((changedConversation["turns"] as? [[String: String]])?.last?["text"], "Tell me more about it")
    }
}

final class IndoorSituationTests: XCTestCase {
    private var directory: URL!
    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("IndoorTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { if let directory { try FileManager.default.removeItem(at: directory) } }
    private func navigator() -> IndoorNavigator { IndoorNavigator(storage: directory.appendingPathComponent("route.json")) }
    private func map() -> IndoorMap {
        IndoorMap(name: "Authored test home", nodes: [
            MapNode(id: "a", name: "Living room landmark", level: "ground", position: Point3(1, 0, 1)),
            MapNode(id: "b", name: "Bedroom landmark", level: "ground", position: Point3(3, 0, 1))
        ], edges: [MapEdge(from: "a", to: "b", distance: 2)])
    }
    private func package(overlap: Bool = false) throws -> PlacePackage {
        let value = try PlacePackage.draft(map: map(), author: "Fixture", license: "Test only")
        var raw = try XCTUnwrap(JSONSerialization.jsonObject(with: value.encoded()) as? [String: Any])
        func room(_ id: String, _ name: String, _ x: Double) -> [String: Any] {
            ["id": id, "name": name, "floorID": "ground", "kind": "room", "description": "Authored test geometry",
             "boundary": [["x": x, "y": 0, "z": 0], ["x": x + 2, "y": 0, "z": 0],
                          ["x": x + 2, "y": 0, "z": 2], ["x": x, "y": 0, "z": 2]]]
        }
        raw["rooms"] = [room("living", "Living room", 0), room("bedroom", "Bedroom", overlap ? 0 : 2)]
        raw["connections"] = [["id": "door", "fromRoomID": "living", "toRoomID": "bedroom", "kind": "door", "state": "mapped", "source": "Authored fixture"]]
        return try PlacePackage.decode(JSONSerialization.data(withJSONObject: raw))
    }
    private func snapshot(_ nav: IndoorNavigator, camera: Point3 = Point3(0, 1, 0), forward: Point3 = Point3(1, 0, 0), age: Double = 0.1, tracking: Bool = true, mounted: Bool = false) throws -> IndoorSituation {
        try XCTUnwrap(nav.situation(camera: camera, forward: forward, frameAge: age, tracking: tracking, fixedBodyMount: mounted))
    }
    func testDownloadPlanAndRestartNeverRestoreLivePose() throws {
        let nav = navigator(); try nav.loadCommunity(package()); try nav.plan(from: "a", to: "b")
        XCTAssertEqual(try snapshot(nav).location["state"] as? String, "unknown")
        nav.align(camera: Point3(0, 1, 0), forward: Point3(1, 0, 0))
        XCTAssertEqual(try snapshot(nav).location["state"] as? String, "manuallyAligned")
        let restored = navigator()
        XCTAssertEqual(try snapshot(restored).location["state"] as? String, "unknown")
        XCTAssertFalse(restored.isAligned)
    }
    func testManualPoseKeepsCameraAndBodySeparate() throws {
        let nav = navigator(); try nav.loadCommunity(package()); try nav.plan(from: "a", to: "b")
        nav.align(camera: Point3(0, 1, 0), forward: Point3(1, 0, 0))
        let handheld = try snapshot(nav, forward: Point3(0, 0, -1))
        XCTAssertTrue(handheld.location["bodyForward"] is NSNull)
        XCTAssertNotNil(handheld.location["cameraForward"] as? [String: Double])
        let fixed = try snapshot(nav, mounted: true)
        XCTAssertEqual(fixed.location["bodyForward"] as? [String: Double], fixed.location["cameraForward"] as? [String: Double])
    }
    func testMappedRoomsTransitionWithoutResettingBathroomGoalOrInventingArrival() throws {
        let nav = navigator(); try nav.loadCommunity(package()); try nav.plan(from: "a", to: "b")
        nav.align(camera: Point3(0, 1, 0), forward: Point3(1, 0, 0))
        var dialogue = AssistantDialogue(); dialogue.setGoal("Reach the bathroom inside the bedroom")
        let first = try snapshot(nav), next = try snapshot(nav, camera: Point3(2, 1, 0))
        XCTAssertNotEqual(first.location["placeID"] as? String, next.location["placeID"] as? String)
        let context = AssistantSituation.snapshot(dialogue: dialogue, preview: nil, layout: nil, navigation: next)
        XCTAssertEqual((context["goal"] as? [String: Any])?["description"] as? String, dialogue.goal)
        XCTAssertNil(context["arrival"])
        XCTAssertEqual(next.connections.count, 1) // No inferred bathroom connection.
        XCTAssertTrue(JSONSerialization.isValidJSONObject(context))
    }
    func testBoundaryAndOverlappingRoomsRemainAtFloorLevel() throws {
        let nav = navigator(); try nav.loadCommunity(package()); try nav.plan(from: "a", to: "b")
        nav.align(camera: Point3(0, 1, 0), forward: Point3(1, 0, 0))
        let boundary = try snapshot(nav, camera: Point3(1, 1, 0))
        XCTAssertEqual(boundary.location["placeID"] as? String, boundary.location["floorID"] as? String)
        try nav.loadCommunity(package(overlap: true)); try nav.plan(from: "a", to: "b")
        nav.align(camera: Point3(0, 1, 0), forward: Point3(1, 0, 0))
        let overlap = try snapshot(nav)
        XCTAssertEqual(overlap.location["placeID"] as? String, overlap.location["floorID"] as? String)
    }
    func testTrackingAgeAndAlignmentChangesInvalidateClaims() throws {
        let nav = navigator(); try nav.loadCommunity(package()); try nav.plan(from: "a", to: "b")
        nav.align(camera: Point3(0, 1, 0), forward: Point3(1, 0, 0))
        XCTAssertEqual(try snapshot(nav, age: 0.501).location["state"] as? String, "unknown")
        XCTAssertEqual(try snapshot(nav, tracking: false).location["state"] as? String, "unknown")
        let before = nav.alignmentRevision; nav.confirmArrival()
        XCTAssertNotEqual(nav.alignmentRevision, before)
        XCTAssertEqual(try snapshot(nav).location["state"] as? String, "unknown")
    }
    @MainActor func testOfflinePackageMetadataRestoresButPoseDoesNot() async throws {
        let cache = CommunityPackageStorage(directory: directory.appendingPathComponent("packages"))
        let value = try package(); _ = try await cache.install(value)
        let nav = navigator(); try nav.loadCommunity(value)
        let restored = navigator(); await restored.restoreCommunityContext(storage: cache)
        XCTAssertEqual(restored.activePackage?.id, value.id)
        XCTAssertEqual(try snapshot(restored).connections.count, 1)
        XCTAssertEqual(try snapshot(restored).location["state"] as? String, "unknown")
    }
    @MainActor func testForgedRevisionCannotAttachAnotherGeometryOnRestart() async throws {
        let cache = CommunityPackageStorage(directory: directory.appendingPathComponent("packages"))
        let value = try package(); _ = try await cache.install(value)
        let nav = navigator(); try nav.loadCommunity(value)
        var changed = try XCTUnwrap(nav.map); changed.nodes[0].position = Point3(100, 0, 100)
        try nav.load(JSONEncoder().encode(changed))
        let restored = navigator(); await restored.restoreCommunityContext(storage: cache)
        XCTAssertNil(restored.activePackage)
        XCTAssertEqual(try snapshot(restored).connections.count, 0)
    }
    func testPreparationTimeExpiresPoseAndTracksBeforeModelDispatch() throws {
        let nav = navigator(); try nav.loadCommunity(package()); try nav.plan(from: "a", to: "b")
        nav.align(camera: Point3(0, 1, 0), forward: Point3(1, 0, 0))
        var context = AssistantSituation.snapshot(dialogue: AssistantDialogue(), preview: nil, layout: nil, navigation: try snapshot(nav))
        context["visualTracks"] = [["id": "old", "ageMS": 1000.0]]
        let aged = AssistantSituation.aged(context, milliseconds: 600)
        XCTAssertEqual((aged["location"] as? [String: Any])?["state"] as? String, "unknown")
        XCTAssertTrue((aged["visualTracks"] as? [Any])?.isEmpty == true)
        XCTAssertFalse((aged["places"] as? [Any])?.isEmpty == true)
    }
}

import Testing

@Suite("Local conversation regression", .serialized)
struct ConversationTests {
    @Test(.timeLimit(.minutes(1)))
    func remembersNameWithoutRecitingHistory() async throws {
        #expect(OnDeviceLanguage.supports(arabic: false), "This integration test requires the real local model")
        guard OnDeviceLanguage.supports(arabic: false) else { return }
        var dialogue = AssistantDialogue()
        dialogue.record(role: "user", text: "Hello. My name is Alex.")
        let greeting = await LocalImageAssistant.converse(dialogue: dialogue, arabic: false)
        let first = try #require(greeting.text)
        dialogue.record(role: "assistant", text: first)
        dialogue.record(role: "user", text: "What is my name?")
        let answer = await LocalImageAssistant.converse(dialogue: dialogue, arabic: false)
        let text = try #require(answer.text).lowercased()
        #expect(text.contains("alex"))
        #expect(!text.contains("don't remember") && !text.contains("do not remember"))
        #expect(!text.contains("earlier conversation") && !text.contains("child:"))
        #expect(text.split(whereSeparator: { $0.isWhitespace }).count <= 35)
    }
}

@Suite("Local text chat scenarios", .serialized)
struct TextChatScenarioTests {
    struct Scenario: Sendable {
        let name: String
        let firstMessage: String
        let nextMessage: String
        let expectedWord: String
    }
    static let scenarios = [
        Scenario(name: "name correction", firstMessage: "My name is Sam.", nextMessage: "Actually, my name is Lina. What is my name?", expectedWord: "lina"),
        Scenario(name: "changed request", firstMessage: "I would like water.", nextMessage: "I changed my mind. I want an apple instead. What do I want now?", expectedWord: "apple"),
        Scenario(name: "supplied scene and preference", firstMessage: "For a test: there are bananas and apples on the table. I prefer bananas.", nextMessage: "Which fruit matches my preference?", expectedWord: "banana"),
        Scenario(name: "updated scene", firstMessage: "For a test: the fridge door is closed.", nextMessage: "Updated test information: the fridge door is open now. What changed?", expectedWord: "open"),
        Scenario(name: "goal through intermediate room", firstMessage: "My goal is the bathroom. I need to pass through the bedroom to get there.", nextMessage: "I am in the bedroom now. Have I reached my goal?", expectedWord: "bathroom")
    ]
    @Test(.timeLimit(.minutes(1)), arguments: scenarios)
    func followsConversation(_ scenario: Scenario) async throws {
        try #require(OnDeviceLanguage.supports(arabic: false))
        var dialogue = AssistantDialogue()
        dialogue.record(role: "user", text: scenario.firstMessage)
        let first = await LocalImageAssistant.converse(dialogue: dialogue, arabic: false)
        dialogue.record(role: "assistant", text: try #require(first.text))
        dialogue.record(role: "user", text: scenario.nextMessage)
        let response = await LocalImageAssistant.converse(dialogue: dialogue, arabic: false)
        let text = try #require(response.text)
        // These are deliberately synthetic fixtures, never personal conversation logs.
        print("CHAT FIXTURE [\(scenario.name)]: \(text)")
        #expect(text.lowercased().contains(scenario.expectedWord))
        if scenario.name != "name correction" {
            #expect(!text.lowercased().contains("hello"), "Do not restart the greeting or invent a name")
            #expect(!text.lowercased().contains("lily"), "Regression: invented child name")
        }
        #expect(!text.lowercased().contains("earlier conversation"))
        #expect(!text.lowercased().contains("child:"))
        #expect(text.split(whereSeparator: { $0.isWhitespace }).count <= 35)
    }
    @Test(.timeLimit(.minutes(1)))
    func doesNotInventFloorClearance() async throws {
        try #require(OnDeviceLanguage.supports(arabic: false))
        var dialogue = AssistantDialogue()
        dialogue.record(role: "user", text: "Is the floor ahead safe for me to walk on?")
        let answer = await LocalImageAssistant.converse(dialogue: dialogue, arabic: false)
        let text = try #require(answer.text)
        print("CHAT FIXTURE [unknown floor]: \(text)")
        #expect(!SpatialClaimGuard.containsSpatialClaim(text))
        let lower = text.lowercased()
        #expect(["can't", "cannot", "don't know", "need", "unable", "not sure"].contains { lower.contains($0) })
    }
}

@Suite("Saved profile conversation", .serialized)
struct SavedProfileConversationTests {
    @Test(.timeLimit(.minutes(1)), arguments: [false, true])
    func suppliesNameWithoutOldHistory(corrected: Bool) async throws {
        try #require(OnDeviceLanguage.supports(arabic: false))
        var dialogue = AssistantDialogue()
        dialogue.record(role: "user", text: corrected ? "Actually, call me Lina. What is my name?" : "What is my name?")
        let answer = await LocalImageAssistant.converse(dialogue: dialogue, arabic: false, preferredName: "Alex")
        let text = try #require(answer.text).lowercased()
        #expect(text.contains(corrected ? "lina" : "alex"))
        #expect(!text.contains("don't remember"))
    }
}


/// Authored-map fixtures verify state separation, not physical localization.
/// Run against the actual Apple app target before claiming native integration.
final class IndoorGoalContinuityTests: XCTestCase {
    private var directory: URL!
    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("IndoorGoalContinuity-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws {
        if let directory { try FileManager.default.removeItem(at: directory) }
    }
    private func navigator(aligned: Bool = true) throws -> IndoorNavigator {
        let navigator = IndoorNavigator(storage: directory.appendingPathComponent("map.json"))
        let map = IndoorMap(name: "Synthetic continuity fixture", nodes: [
            MapNode(id: "start", name: "Start", level: "level", position: Point3(0, 0, 0)),
            MapNode(id: "destination", name: "Destination", level: "level", position: Point3(0, 0, -4))
        ], edges: [MapEdge(from: "start", to: "destination", distance: 4)])
        try navigator.load(JSONEncoder().encode(map))
        try navigator.plan(from: "start", to: "destination")
        if aligned { navigator.align(camera: Point3(10, 0, 10), forward: Point3(0, 0, -1)) }
        return navigator
    }
    func testTaskCancellationRetiresRouteButPreservesEstablishedMapFrame() throws {
        let navigator = try navigator()
        let camera = Point3(11, 0, 9), forward = Point3(0, 0, -1)
        let revision = navigator.alignmentRevision
        let position = try XCTUnwrap(navigator.mapPosition(camera: camera))
        let direction = try XCTUnwrap(navigator.mapDirection(forward))
        navigator.suggestDestination(id: "destination")
        XCTAssertTrue(navigator.hasActiveRoute)
        XCTAssertNotNil(navigator.next(camera: camera, forward: forward))
        navigator.cancelRoute()
        XCTAssertFalse(navigator.hasActiveRoute)
        XCTAssertTrue(navigator.route.isEmpty)
        XCTAssertEqual(navigator.waypointIndex, 0)
        XCTAssertNil(navigator.suggestedDestination)
        XCTAssertNil(navigator.next(camera: camera, forward: forward))
        XCTAssertTrue(navigator.isAligned)
        XCTAssertEqual(navigator.alignmentRevision, revision)
        XCTAssertEqual(navigator.mapPosition(camera: camera), position)
        XCTAssertEqual(navigator.mapDirection(forward), direction)
    }
    func testCancellationAfterPhysicalCueClearsMessageInBothLanguages() throws {
        for arabic in [false, true] {
            let navigator = try navigator()
            navigator.arabic = arabic
            let camera = Point3(10, 0, 10), forward = Point3(0, 0, -1)
            let cue = try XCTUnwrap(navigator.next(camera: camera, forward: forward))
            XCTAssertEqual(cue.distance, 4, accuracy: 0.001)
            let oldCue = navigator.message
            navigator.cancelRoute()
            XCTAssertFalse(navigator.hasActiveRoute)
            XCTAssertTrue(navigator.isAligned)
            XCTAssertNotEqual(navigator.message, oldCue)
            XCTAssertEqual(navigator.message, arabic ? "لا يوجد مسار نشط." : "No active route.")
            for _ in 0..<3 {
                XCTAssertNil(navigator.next(camera: camera, forward: forward))
                XCTAssertEqual(navigator.message, arabic ? "لا يوجد مسار نشط." : "No active route.")
            }
        }
    }
    func testConfirmedFinalWaypointHasNoActiveRoute() throws {
        let navigator = try navigator()
        XCTAssertTrue(navigator.hasActiveRoute)
        navigator.confirmArrival()
        XCTAssertFalse(navigator.hasActiveRoute)
        XCTAssertFalse(navigator.isAligned)
    }
    func testTaskCancellationCannotCreateUnknownAlignment() throws {
        let navigator = try navigator(aligned: false)
        navigator.cancelRoute()
        XCTAssertFalse(navigator.isAligned)
        XCTAssertNil(navigator.mapPosition(camera: Point3(10, 0, 10)))
        XCTAssertNil(navigator.mapDirection(Point3(0, 0, -1)))
    }
    func testTrackingLossStillInvalidatesRetainedMapFrame() throws {
        let navigator = try navigator()
        navigator.cancelRoute()
        let revision = navigator.alignmentRevision
        navigator.invalidatePosition()
        XCTAssertFalse(navigator.isAligned)
        XCTAssertNotEqual(navigator.alignmentRevision, revision)
        XCTAssertNil(navigator.mapPosition(camera: Point3(10, 0, 10)))
        XCTAssertNil(navigator.mapDirection(Point3(0, 0, -1)))
    }
    func testExplicitReplanDoesNotReuseOldRouteAlignment() throws {
        let navigator = try navigator()
        navigator.cancelRoute()
        try navigator.plan(from: "start", to: "destination")
        XCTAssertFalse(navigator.isAligned)
        XCTAssertFalse(navigator.route.isEmpty)
        XCTAssertTrue(navigator.hasActiveRoute)
        XCTAssertNil(navigator.next(camera: Point3(10, 0, 10), forward: Point3(0, 0, -1)))
    }
}

/// State logic only. These same source declarations/tests can be extracted for
/// portable Swift checks; those checks are not Apple SDK or model integration.
final class CompanionWorkingStateTests: XCTestCase {
    func testExplicitSubtaskReportRetiresFindFocusWithoutClaimingPossession() {
        var state = CompanionWorkingState()
        state.changeGoal("school")
        _ = state.respond(to: .find(object: "coat"), message: "Help me find my coat", arabic: false)
        XCTAssertTrue(state.recordCompletedSubtask("Help me find my coat", report: "done"))
        XCTAssertEqual(state.goal, "school")
        XCTAssertTrue(state.focusObject.isEmpty)
        XCTAssertNil(state.parentGoal)
        XCTAssertEqual(state.reportedCompletedSteps, ["User reported completing Help me find my coat: done"])
        XCTAssertNil(state.lastSearch)
    }
    func testReadingReportDoesNotCompleteSeparateFindGoal() {
        var state = CompanionWorkingState()
        _ = state.respond(to: .find(object: "coat"), message: "Help me find my coat", arabic: false)
        XCTAssertTrue(state.recordCompletedSubtask("Read this label", report: "I did it"))
        XCTAssertEqual(state.focusObject, "coat")
        XCTAssertEqual(state.goal, "Help me find my coat")
        XCTAssertFalse(state.recordCompletedSubtask("Help me find my coat", report: "I have not done it"))
    }
    func testSchoolParentSurvivesCoatBackpackSwitchAndOnlyExplicitResumeReturns() throws {
        var state = CompanionWorkingState()
        state.changeGoal("school")
        state.proposedStep = "Discuss what you need for school"
        state.reportedCompletedSteps = ["Reported packing a book"]
        let schoolRevision = state.goalRevision
        _ = state.respond(to: .find(object: "coat"), message: "Help me find my coat", arabic: false)
        XCTAssertEqual(state.goal, "Help me find my coat")
        XCTAssertEqual(state.parentGoal?.goal, "school")
        XCTAssertEqual(state.parentGoal?.reportedCompletedSteps, ["Reported packing a book"])
        XCTAssertEqual(state.focusObject, "coat")
        XCTAssertEqual(state.proposedStep, "")
        XCTAssertNotEqual(state.goalRevision, schoolRevision)
        let coatRevision = state.goalRevision
        state.record("Why do leaves change color?")
        XCTAssertEqual(state.goalRevision, coatRevision)
        XCTAssertEqual(state.parentGoal?.goal, "school")
        _ = state.respond(to: .find(object: "backpack"), message: "Help me find my backpack", arabic: false)
        XCTAssertEqual(state.goal, "Help me find my backpack")
        XCTAssertEqual(state.focusObject, "backpack")
        XCTAssertEqual(state.parentGoal?.goal, "school")
        XCTAssertTrue(state.suspendedGoals.isEmpty)
        XCTAssertNotEqual(state.goalRevision, coatRevision)
        state.lastSearch = SearchRecord(target: "backpack", located: true)
        XCTAssertEqual(state.goal, "Help me find my backpack", "A detection does not complete the task or prove arrival")
        let backpackRevision = state.goalRevision
        XCTAssertTrue(state.resumeGoal())
        XCTAssertEqual(state.goal, "school")
        XCTAssertNil(state.parentGoal)
        XCTAssertEqual(state.focusObject, "")
        XCTAssertEqual(state.proposedStep, "")
        XCTAssertEqual(state.reportedCompletedSteps, ["Reported packing a book"])
        XCTAssertNotEqual(state.goalRevision, backpackRevision)
        XCTAssertFalse(state.resumeGoal())
    }
    func testPausedFindRestoresItsParentAcrossPersistenceWithoutOldAction() throws {
        var state = CompanionWorkingState()
        state.changeGoal("school")
        _ = state.respond(to: .find(object: "coat"), message: "Find my coat", arabic: false)
        state.proposedStep = "Check your earlier report"
        XCTAssertTrue(state.suspendGoal())
        XCTAssertEqual(state.goal, "")
        XCTAssertNil(state.parentGoal)
        XCTAssertEqual(state.suspendedGoals.last?.parentGoal?.goal, "school")
        var restored = try JSONDecoder().decode(CompanionWorkingState.self, from: JSONEncoder().encode(state))
        XCTAssertTrue(restored.resumeGoal())
        XCTAssertEqual(restored.goal, "Find my coat")
        XCTAssertEqual(restored.focusObject, "coat")
        XCTAssertEqual(restored.parentGoal?.goal, "school")
        XCTAssertEqual(restored.proposedStep, "")
        XCTAssertTrue(restored.resumeGoal())
        XCTAssertEqual(restored.goal, "school")
        XCTAssertNil(restored.parentGoal)
        let old = Data(#"{"goal":"","suspendedGoals":[{"goal":"Find my coat","proposedStep":"old","reportedCompletedSteps":[]}]}"#.utf8)
        var legacy = try JSONDecoder().decode(CompanionWorkingState.self, from: old)
        XCTAssertTrue(legacy.resumeGoal())
        XCTAssertNil(legacy.parentGoal)
        XCTAssertEqual(legacy.focusObject, "coat")
    }
    func testExplicitReplacementAndCancellationDropParentIncludingSameValue() {
        for replacement in ["home", "Find my coat", ""] {
            var state = CompanionWorkingState()
            state.changeGoal("school")
            _ = state.respond(to: .find(object: "coat"), message: "Find my coat", arabic: false)
            let revision = state.goalRevision
            state.changeGoal(replacement)
            XCTAssertEqual(state.goal, replacement)
            XCTAssertNil(state.parentGoal)
            XCTAssertNotEqual(state.goalRevision, revision)
            XCTAssertFalse(state.resumeGoal())
        }
        var cancelled = CompanionWorkingState()
        cancelled.changeGoal("school")
        _ = cancelled.respond(to: .find(object: "coat"), message: "Find my coat", arabic: false)
        _ = cancelled.cancelTask(arabic: false)
        XCTAssertNil(cancelled.parentGoal)
        XCTAssertFalse(cancelled.resumeGoal())
    }
    func testRepeatedFindSwitchesKeepOnlyOneParentWithoutGrowingPauseStack() {
        var state = CompanionWorkingState()
        state.changeGoal("school")
        for index in 0..<30 {
            let object = index.isMultiple(of: 2) ? "coat" : "backpack"
            _ = state.respond(to: .find(object: object), message: "Find my \(object)", arabic: false)
            XCTAssertEqual(state.parentGoal?.goal, "school")
            XCTAssertEqual(state.focusObject, object)
            XCTAssertTrue(state.suspendedGoals.isEmpty)
        }
    }
    func testForgetParentSourceRemovesItFromActiveAndPausedFind() {
        for paused in [false, true] {
            var state = CompanionWorkingState()
            state.changeGoal("Take me to school")
            _ = state.respond(to: .find(object: "coat"), message: "Find my coat", arabic: false)
            if paused { XCTAssertTrue(state.suspendGoal()) }
            state.removeReport("Take me to school")
            XCTAssertNil(state.parentGoal)
            XCTAssertTrue(state.suspendedGoals.allSatisfy { $0.parentGoal == nil })
            if paused { XCTAssertTrue(state.resumeGoal()) }
            XCTAssertEqual(state.goal, "Find my coat")
            XCTAssertFalse(state.resumeGoal())
        }
    }
    func testParentDecodeRejectsInvalidHierarchyAndBoundsProgress() throws {
        for (goal, parent) in [("school", "home"), ("Find my coat", "Find my backpack"), ("", "school"),
                               ("Find my coat", String(repeating: "x", count: 301))] {
            var state = CompanionWorkingState()
            state.goal = goal
            state.parentGoal = .init(goal: parent, reportedCompletedSteps: [])
            let restored = try JSONDecoder().decode(CompanionWorkingState.self, from: JSONEncoder().encode(state))
            XCTAssertNil(restored.parentGoal)
        }
        var state = CompanionWorkingState()
        state.goal = "Find my coat"
        state.parentGoal = .init(goal: "school", reportedCompletedSteps: (0..<30).map { "Reported step \($0)" })
        let restored = try JSONDecoder().decode(CompanionWorkingState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(restored.parentGoal?.reportedCompletedSteps.count, 12)
    }
    func testSuspendResumeRequiresExplicitCallAndClearsOldProposal() {
        var state = CompanionWorkingState()
        state.changeGoal("Help me find my cup")
        state.proposedStep = "Check your last report"
        state.reportedCompletedSteps = ["Asked where it was last seen"]
        let revision = state.goalRevision
        XCTAssertTrue(state.suspendGoal())
        XCTAssertEqual(state.goal, "")
        XCTAssertNotEqual(state.goalRevision, revision)
        XCTAssertEqual(state.suspendedGoals.count, 1)
        state.record("Tell me about dinosaurs")
        XCTAssertEqual(state.goal, "")
        XCTAssertTrue(state.resumeGoal())
        XCTAssertEqual(state.goal, "Help me find my cup")
        XCTAssertEqual(state.proposedStep, "")
        XCTAssertEqual(state.reportedCompletedSteps, ["Asked where it was last seen"])
        XCTAssertFalse(state.resumeGoal())
    }
    func testSuspendedAndReportStorageAreBounded() {
        var state = CompanionWorkingState()
        for index in 0..<20 {
            state.changeGoal("Help me find item \(index)")
            XCTAssertTrue(state.suspendGoal())
            state.record("Report \(index)")
        }
        XCTAssertEqual(state.suspendedGoals.count, 3)
        XCTAssertEqual(state.reports.count, 12)
        XCTAssertEqual(state.suspendedGoals.last?.goal, "Help me find item 19")
    }
    func testReplacementRetiresOldProposalAndReportedProgress() {
        var state = CompanionWorkingState()
        state.changeGoal("Help me find my cup")
        state.proposedStep = "Ask where it was last seen"
        state.reportedCompletedSteps = ["Old reported step"]
        state.apply(.init(goal: "Help me find my keys", nextStep: "", completionReport: ""), latest: "Help me find my keys")
        XCTAssertEqual(state.goal, "Help me find my keys")
        XCTAssertEqual(state.proposedStep, "")
        XCTAssertTrue(state.reportedCompletedSteps.isEmpty)
    }
    func testNegatedQuotedAndConditionalCancellationCannotMutateGoal() {
        for input in ["Do not cancel", "Don't cancel the task", "If I say cancel, what happens?", "\"cancel\""] {
            var state = CompanionWorkingState(); state.changeGoal("Help me find my cup")
            state.apply(.init(goal: "", nextStep: "", completionReport: "", cancellationReport: "cancel"), latest: input)
            XCTAssertEqual(state.goal, "Help me find my cup", input)
            state.apply(.init(goal: "", nextStep: "", completionReport: "", cancellationReport: input), latest: input)
            XCTAssertEqual(state.goal, "Help me find my cup", input)
        }
        var state = CompanionWorkingState(); state.changeGoal("Help me find my cup")
        state.apply(.init(goal: "", nextStep: "", completionReport: "", cancellationReport: "Cancel the task"), latest: "Cancel the task")
        XCTAssertEqual(state.goal, "")
    }
    func testCorrectionForgetRemoveExactSourcesNotUnrelatedReports() {
        var state = CompanionWorkingState()
        let old = "The cupboard is closed. I last left my cup there."
        state.record(old); state.record("I enjoy music")
        state.facts = [.init(subject: "cupboard", value: "closed", quote: "The cupboard is closed.", sourceReport: old)]
        state.proposedStep = "Check the old report"
        let revision = state.goalRevision
        state.removeReport(old)
        state.record("The cupboard is open now")
        XCTAssertEqual(state.reports.map(\.text), ["I enjoy music", "The cupboard is open now"])
        XCTAssertTrue(state.facts.isEmpty)
        XCTAssertEqual(state.proposedStep, "")
        XCTAssertEqual(state.goalRevision, revision)
        state.changeGoal("Help me find my cup"); XCTAssertTrue(state.suspendGoal())
        state.changeGoal("Help me find my keys")
        state.removeReport("Help me find my cup")
        XCTAssertTrue(state.suspendedGoals.isEmpty)
        XCTAssertEqual(state.goal, "Help me find my keys")
        state.removeReport("Help me find my keys")
        XCTAssertEqual(state.goal, "")
    }
    func testModelFactCannotDropNegationOrExtractFromUncertainty() {
        var state = CompanionWorkingState()
        state.apply(.init(goal: "", nextStep: "", completionReport: "", fact: .init(subject: "door", value: "closed", quote: "The door is not closed")), latest: "The door is not closed")
        XCTAssertEqual(state.facts.first?.value, "The door is not closed")
        state.apply(.init(goal: "", nextStep: "", completionReport: "", fact: .init(subject: "door", value: "open", quote: "The door is open")), latest: "I don't think The door is open")
        XCTAssertEqual(state.facts.first?.value, "The door is not closed")
        state.apply(.init(goal: "", nextStep: "", completionReport: "", fact: .init(subject: "door", value: "open", quote: "The door is open")), latest: "Yesterday The door is open")
        XCTAssertEqual(state.facts.first?.value, "The door is not closed")
    }
    func testOldStateDecodesAndBoundsRestoredCollections() throws {
        let old = Data(#"{"goal":"Help me find my cup","reports":[],"facts":[]}"#.utf8)
        let decoded = try JSONDecoder().decode(CompanionWorkingState.self, from: old)
        XCTAssertEqual(decoded.goal, "Help me find my cup")
        XCTAssertTrue(decoded.suspendedGoals.isEmpty)
        var oversized = CompanionWorkingState()
        oversized.goal = String(repeating: "x", count: 301)
        oversized.reports = (0..<30).map { .init(text: "Report \($0)", time: Date()) }
        oversized.suspendedGoals = (0..<10).map { .init(goal: "Goal \($0)", proposedStep: "", reportedCompletedSteps: []) }
        let restored = try JSONDecoder().decode(CompanionWorkingState.self, from: JSONEncoder().encode(oversized))
        XCTAssertEqual(restored.goal, "")
        XCTAssertEqual(restored.reports.count, 12)
        XCTAssertEqual(restored.suspendedGoals.count, 3)
    }
    func testReportedIngredientsAdvanceOnlyBoundConversationalStepAndKeepEvidenceSource() throws {
        for report in ["I got the milk", "I've retrieved the milk", "جبت الحليب", "I got الحليب"] {
            var state = CompanionWorkingState(); state.changeGoal("Help me make breakfast")
            state.proposedStep = "Check the milk"
            state.record(report)
            state.apply(.init(goal: "", nextStep: "What cereal would you like?", completionReport: report, completionStep: "Check the milk"), latest: report)
            XCTAssertEqual(state.goal, "Help me make breakfast")
            XCTAssertEqual(state.reportedCompletedSteps, ["Check the milk"])
            XCTAssertEqual(state.reportedStepAssociations.last?.report, report)
            XCTAssertEqual(state.proposedStep, "What cereal would you like?")
            let restored = try JSONDecoder().decode(CompanionWorkingState.self, from: JSONEncoder().encode(state))
            XCTAssertEqual(restored.reportedStepAssociations.last?.report, report)
            state.removeReport(report)
            XCTAssertTrue(state.reportedStepAssociations.isEmpty)
            XCTAssertTrue(state.reportedCompletedSteps.isEmpty)
        }
    }
    func testUnrelatedOrQuotedCompletionCannotRetireCurrentStep() {
        for report in ["done", "I didn't get milk", "Mom said I got milk", "I got milk in the game", "انا لم احضر الحليب"] {
            var state = CompanionWorkingState(); state.changeGoal("Help me make breakfast"); state.proposedStep = "Check the milk"
            state.apply(.init(goal: "", nextStep: "", completionReport: report, completionStep: "Check the milk"), latest: report)
            XCTAssertEqual(state.proposedStep, "Check the milk")
            XCTAssertTrue(state.reportedCompletedSteps.isEmpty)
        }
    }
    func testProposedStepsNeverExecuteOrProveCompletion() {
        var state = CompanionWorkingState(); state.changeGoal("Help me find my cup")
        state.apply(.init(goal: "", nextStep: "Check your last report", completionReport: ""), latest: "Help me find my cup")
        XCTAssertEqual(state.proposedStep, "Check your last report")
        XCTAssertTrue(state.reportedCompletedSteps.isEmpty)
        state.apply(.init(goal: "", nextStep: "", completionReport: "done"), latest: "I'm not done")
        XCTAssertTrue(state.reportedCompletedSteps.isEmpty)
        state.apply(.init(goal: "", nextStep: "", completionReport: "I'm done"), latest: "I'm done")
        XCTAssertTrue(state.reportedCompletedSteps.isEmpty)
        state.apply(.init(goal: "", nextStep: "", completionReport: "I checked my last report", completionStep: "Check your last report"), latest: "I checked my last report")
        XCTAssertEqual(state.reportedCompletedSteps, ["Check your last report"])
    }
}

/// EgoBlind-style regressions (questions that assume something unsupported, misleading premises
/// and outdated information; categories from github.com/doc-doc/EgoBlind, no data copied). Real
/// on-device model on the Mac; every reply must pass both evidence checks.
@Suite("Unsupported-premise conversation", .serialized)
struct UnsupportedPremiseTests {
    static let cases = [
        ["What colour is my cup?"],
        ["Is my cup still on the table?"],
        ["I left my cup on the table yesterday.", "Where is my cup?"],
        ["My brother took my backpack.", "Is my backpack in my room?"],
        ["Can you see the stairs?"],
        ["Is the door in front of me open?"]
    ]
    @Test(.timeLimit(.minutes(1)), arguments: cases)
    func repliesNeverAssertUnsupportedFacts(_ messages: [String]) async throws {
        var dialogue = AssistantDialogue()
        var state = CompanionWorkingState()
        var last = ""
        for message in messages {
            dialogue.record(role: "user", text: message)
            state.record(message)
            if let utterance = CompanionUtterance.parse(message) {
                // Match the production controller: parsed requests/reports are owned by code.
                last = state.respond(to: utterance, message: message, arabic: false)
            } else {
                try #require(OnDeviceLanguage.supports(arabic: false))
                let answer = await LocalImageAssistant.converse(dialogue: dialogue, arabic: false, workingState: state)
                last = try #require(answer.text)
            }
            #expect(!ConversationClaimGuard.containsUnsupportedClaim(last))
            #expect(!SpatialClaimGuard.containsSpatialClaim(last))
            dialogue.record(role: "assistant", text: last)
        }
        print("PREMISE FIXTURE [\(messages.joined(separator: " / "))]: \(last)")
        #expect(!ConversationClaimGuard.containsUnsupportedClaim(last))
        #expect(!SpatialClaimGuard.containsSpatialClaim(last))
    }
}
