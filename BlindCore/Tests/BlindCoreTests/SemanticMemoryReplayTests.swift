import XCTest
@testable import BlindCore

/// Executes production retrieval, tool sanitization and context construction.
/// Inputs are authored fixtures or optional external annotations, never model answers.
final class SemanticMemoryReplayTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private struct Fixture: Decodable {
        let sourceHashes: [String: String]
        let scenarios: [Scenario]
    }
    private struct Scenario: Decodable {
        struct Place: Decodable { let id, name, kind: String; let parentID: String? }
        struct Entity: Decodable {
            let id, category, description, placeID, state, sourceID: String
            let ageMS: Double
        }
        struct Goal: Decodable { let description: String }
        let id, question: String
        let places: [Place]
        let entities: [Entity]
        let goal: Goal
    }
    private func fixture() throws -> Fixture {
        try JSONDecoder().decode(Fixture.self, from: SemanticMemoryReplayFixture.data)
    }
    private func scenario(_ id: String) throws -> Scenario {
        try XCTUnwrap(fixture().scenarios.first { $0.id == id })
    }
    /// Supply the original category, not nouns inferred from a scene caption.
    /// The source enum simulates an adapter input; no detector executes in this test.
    private func observed(_ scenarios: [Scenario]) -> ObservedObjectMemory {
        var memory = ObservedObjectMemory()
        for scenario in scenarios {
            for entity in scenario.entities {
                let room = scenario.places.first { $0.id == entity.placeID }
                let floor = scenario.places.first { $0.id == room?.parentID }
                let building = scenario.places.first { $0.id == floor?.parentID }
                memory.observe(category: entity.category, source: .onDeviceDetector,
                    sourceObservationID: entity.sourceID, frameID: "authored-fixture-only",
                    roomID: room?.id, roomName: room?.name, placeID: building?.id, placeName: building?.name,
                    floorID: floor?.id, floorName: floor?.name,
                    at: now.addingTimeInterval(-entity.ageMS / 1000), now: now)
            }
        }
        return memory
    }
    private func evidenceText(_ result: CompanionToolResult) -> String {
        result.evidence.map(\.text).joined(separator: "\n")
    }
    private func historical(_ result: CompanionToolResult, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(result.evidence.allSatisfy { $0.kind == .historicalMemory || $0.kind == .userReport }, file: file, line: line)
        XCTAssertTrue(result.evidence.allSatisfy { !$0.isCurrent(at: now) && $0.expiresAt == nil }, file: file, line: line)
        XCTAssertTrue(result.summary.contains("do not prove absence"), file: file, line: line)
    }
    private func context(_ scenario: Scenario, name: String = "ليان") throws -> CompanionModelContext {
        try CompanionModelContext(preferredName: name, audience: .childWithGuardian,
            currentGoal: scenario.goal.description, goalRevision: "fixture:" + scenario.id,
            parentGoal: "Get ready for school", proposedStep: "Review the recorded inventory, not a completed action")
    }
    private func plan(_ context: CompanionModelContext, latest: String, result: CompanionToolResult,
                      reduced: Bool = false, extra: [ContextWindowPolicy.Field] = []) throws -> ContextWindowPolicy.PromptPlan {
        // Tool output is JSON data, exactly as production's Tool adapter encodes it.
        let json = String(decoding: try JSONEncoder().encode(result), as: UTF8.self)
        return try ContextWindowPolicy.makePrompt(latest: latest, instructions: context.instructions(for: .conversation),
            mandatoryFields: context.mandatoryFields,
            fields: [.init("savedMemoryToolResultNotLiveObservations", [json])] + context.optionalFields + extra,
            reduced: reduced)
    }

    func testFixturesRetainOriginalSourcesAndCategoriesRatherThanInventedInventory() throws {
        let input = try fixture()
        XCTAssertEqual(input.scenarios.map(\.id), ["enter", "bedroom", "bathroom-arrival", "goal-change"])
        XCTAssertEqual(input.scenarios.reduce(0) { $0 + $1.entities.count }, 13)
        XCTAssertEqual(input.sourceHashes.count, 3)
        XCTAssertTrue(input.sourceHashes.values.allSatisfy { $0.count == 64 })
        let home = try scenario("enter")
        XCTAssertEqual(Set(home.entities.map(\.category)), ["person", "seat", "furniture", "art", "aquarium"])
        XCTAssertFalse(home.entities.contains { $0.category == "sofa" || $0.category == "coffee table" })
        XCTAssertEqual(observed([home]).sightings.count, home.entities.count)
    }

    func testFurnishedHouseSameCategoryEnglishArabicFramingAndMixedQueries() throws {
        let home = try scenario("enter"), memory = observed([home])
        let aquarium = try XCTUnwrap(memory.sightings.first { $0.category == "aquarium" })
        let queries = ["aquarium", "Where is my aquarium?", "What do you remember about the aquarium?",
                       "Can you please tell me about my aquarium?", "AQUARIUM!", "أين aquarium؟", "وين aquarium", "my aquarium في البيت"]
        for query in queries {
            let result = CompanionMemoryRetrieval.read(query: query, now: now, observed: memory)
            XCTAssertEqual(result.evidence.map(\.id), ["seen:" + aquarium.id], query)
            XCTAssertEqual(result.evidence.first?.observedAt, aquarium.observedAt, query)
            XCTAssertEqual(result.evidence.first?.source, "on-device detector candidate history", query)
            XCTAssertTrue(evidenceText(result).contains("Living room"), query)
            XCTAssertTrue(evidenceText(result).contains("Current presence and ownership are unconfirmed"), query)
            historical(result)
        }
    }

    func testLexicalLimitsDoNotManufactureSynonymsTranslationsOrCaptionNouns() throws {
        let memory = observed([try scenario("enter"), try scenario("goal-change")])
        // Known limitations, not successful semantic understanding. Generic source
        // labels cannot be silently upgraded using nouns from authored captions.
        for query in ["fish tank", "حوض الأسماك", "sofa", "couch", "laptop", "computer", "coffee table", "aquariums", "aquariumish"] {
            let result = CompanionMemoryRetrieval.read(query: query, now: now, observed: memory)
            XCTAssertTrue(result.evidence.isEmpty, query)
            historical(result)
        }
    }

    func testAuthoredCaptionsStayAttributedHistorySeparateFromCategoryCandidates() throws {
        let home = try scenario("enter")
        let original = try XCTUnwrap(home.entities.first { $0.id == "aquarium" })
        let report = CompanionEvidence(id: "authored:" + original.id, kind: .historicalMemory,
            text: original.description, source: "authored fictional fixture, not live perception")
        let result = CompanionMemoryRetrieval.read(query: "fish", now: now, reports: [report], observed: observed([home]))
        XCTAssertEqual(result.evidence, [report])
        XCTAssertNil(result.evidence.first?.observedAt, "The authored caption has no real capture wall-clock date")
        let built = try plan(context(home), latest: "What do you remember about fish?", result: result)
        let encoded = try XCTUnwrap(built.context["savedMemoryToolResultNotLiveObservations"]?.first)
        XCTAssertEqual(try JSONDecoder().decode(CompanionToolResult.self, from: Data(encoded.utf8)), result)
        historical(result)
    }

    func testArabicSavedItemQueriesUseOriginalArabicRecordNotAssumedTranslation() {
        let item = RememberedItem(id: "arabic-user-record", name: "حقيبة", roomName: "غرفة النوم", savedAt: now)
        for query in ["أين الحقيبة؟", "وين حقيبة", "تذكر الحقيبة", "Where is الحقيبة?", "حَقِيبَة"] {
            let result = CompanionMemoryRetrieval.read(query: query, now: now, savedItems: [item])
            XCTAssertEqual(result.evidence.map(\.id), ["item:arabic-user-record"], query)
            XCTAssertTrue(evidenceText(result).contains("غرفة النوم"), query)
            historical(result)
        }
        XCTAssertTrue(CompanionMemoryRetrieval.read(query: "backpack", now: now, savedItems: [item]).evidence.isEmpty)
    }

    func testChangedSavedItemAndNegativeReportRetainTimeSourceAndHistory() throws {
        var items = ItemMemory()
        let first = try XCTUnwrap(items.remember(name: "my coat", roomName: "Bedroom", at: now.addingTimeInterval(-86_400)))
        let correction = CompanionEvidence(id: "correction", kind: .userReport,
            text: "I did not leave my coat in the Bedroom today.", source: "original user conversation record")
        let second = try XCTUnwrap(items.remember(name: "my coat", roomName: "Hallway", at: now.addingTimeInterval(-60)))
        XCTAssertEqual(first.id, second.id)
        let result = CompanionMemoryRetrieval.read(query: "Where is my coat?", now: now, reports: [correction], savedItems: items.items)
        XCTAssertEqual(result.evidence.count, 2)
        XCTAssertEqual(result.evidence.first, correction)
        XCTAssertNil(result.evidence.first?.observedAt, "Production conversation records can be undated")
        XCTAssertEqual(result.evidence.last?.observedAt, second.savedAt)
        XCTAssertTrue(result.evidence.last!.text.contains("Hallway"))
        XCTAssertFalse(result.evidence.last!.text.contains("Bedroom"))
        XCTAssertTrue(result.evidence.last!.text.contains("Current location is unconfirmed"))
        historical(result)
    }

    func testStaleRestartedInventoryCannotBecomePresenceMissingnessOrOwnership() throws {
        var memory = observed([try scenario("enter")])
        memory.expire(at: now.addingTimeInterval(86_400))
        memory.invalidateGeometry()
        memory = try JSONDecoder().decode(ObservedObjectMemory.self, from: JSONEncoder().encode(memory))
        XCTAssertTrue(memory.sightings.allSatisfy { !$0.isActive && !$0.geometryValid && $0.confirmedInstanceID == nil })
        let future = now.addingTimeInterval(30 * 86_400)
        for query in ["my aquarium", "person", "seat", "furniture"] {
            let result = CompanionMemoryRetrieval.read(query: query, now: future, observed: memory)
            XCTAssertEqual(result.evidence.count, 1, query)
            XCTAssertTrue(evidenceText(result).contains("Historical candidate"))
            XCTAssertTrue(evidenceText(result).contains("Current presence and ownership are unconfirmed"))
            XCTAssertFalse(evidenceText(result).contains("Maya"))
            XCTAssertFalse(evidenceText(result).contains("Omar"))
            historical(result)
        }
        let missing = CompanionMemoryRetrieval.read(query: "coat", now: future, observed: memory)
        XCTAssertTrue(missing.evidence.isEmpty)
        XCTAssertTrue(missing.summary.contains("Empty or partial results do not prove absence"))
    }

    func testChangedRoomsRetainAlternativeLocationsWithoutAssumingOneObjectMoved() throws {
        let memory = observed([try scenario("enter"), try scenario("bedroom")])
        let result = CompanionMemoryRetrieval.read(query: "furniture", now: now, observed: memory)
        XCTAssertEqual(result.evidence.count, 1)
        XCTAssertTrue(evidenceText(result).contains("Other recorded locations exist"))
        XCTAssertTrue(evidenceText(result).contains("do not assume one item or a unique location"))
        historical(result)
    }

    func testSameDisplayNamesDifferentPlaceFloorRoomOrFrameStayAmbiguous() throws {
        for changed in ["place", "floor", "room", "frame"] {
            var memory = ObservedObjectMemory()
            for version in [0, 1] {
                func identity(_ field: String) -> String { field + ((field == changed && version == 1) ? "-other" : "-same") }
                XCTAssertNotNil(memory.observe(category: "cup", source: .onDeviceDetector,
                    sourceObservationID: "fixture-\(version)", frameID: identity("frame"),
                    roomID: identity("room"), roomName: "Bedroom", placeID: identity("place"), placeName: "Home",
                    floorID: identity("floor"), floorName: "Ground", position: Point3(123.456, 0, 789.123),
                    at: now.addingTimeInterval(Double(version - 1)), now: now))
            }
            let result = CompanionMemoryRetrieval.read(query: "my cup", now: now, observed: memory)
            XCTAssertEqual(result.evidence.count, 1, changed)
            XCTAssertTrue(evidenceText(result).contains("Other recorded locations exist"), changed)
            XCTAssertFalse(evidenceText(result).contains("123.456"), changed)
            XCTAssertFalse(evidenceText(result).contains("789.123"), changed)
            XCTAssertFalse(evidenceText(result).contains("frame-other"), "Frame identity is checked, not exposed as physical guidance")
            historical(result)
        }
    }

    func testSameScopeRepeatedFramesDoNotInventDifferentLocationsOrObjectCount() {
        var memory = ObservedObjectMemory()
        for index in 0..<5 {
            memory.observe(category: "cup", source: .onDeviceDetector, sourceObservationID: "detection-\(index)",
                frameID: "one-coordinate-frame", roomID: "bedroom", roomName: "Bedroom", placeID: "home", placeName: "Home",
                floorID: "ground", floorName: "Ground", at: now.addingTimeInterval(Double(index - 5)), now: now)
        }
        let result = CompanionMemoryRetrieval.read(query: "cup", now: now, observed: memory)
        XCTAssertEqual(result.evidence.count, 1)
        XCTAssertFalse(evidenceText(result).contains("Other recorded locations exist"))
        XCTAssertFalse(evidenceText(result).contains("5 cups"))
        XCTAssertTrue(evidenceText(result).contains("ownership are unconfirmed"))
    }

    func testPublishedAuthoredMapProvidesSavedRoomInventoryButNoLiveGeometry() throws {
        struct MapInput: Decodable {
            struct Room: Decodable { let name: String }
            let id, name, provenance, localization, sourceURL, createdAt: String
            let rooms: [Room]
        }
        let url = try XCTUnwrap(Bundle.module.url(forResource: "oas-apartment.blindplace", withExtension: "json", subdirectory: "Fixtures"))
        let map = try JSONDecoder().decode(MapInput.self, from: Data(contentsOf: url))
        XCTAssertEqual(map.provenance, "authored")
        XCTAssertEqual(map.localization, "preview-only")
        XCTAssertTrue(map.sourceURL.contains("e54861c1099964607efd86b07e858f309e3fe45f"))
        let date = try XCTUnwrap(ISO8601DateFormatter().date(from: map.createdAt))
        let saved = CompanionPlaceMemory(id: map.id, name: map.name, roomNames: map.rooms.map(\.name), recordedAt: date)
        for query in ["bedroom", "What do you remember about the Bedroom?", "أين Bedroom؟", "room inventory"] {
            let result = CompanionMemoryRetrieval.read(query: query, now: date.addingTimeInterval(86_400), places: [saved])
            XCTAssertEqual(result.evidence.count, 1, query)
            XCTAssertEqual(result.evidence.first?.source, "private saved place inventory")
            XCTAssertEqual(result.evidence.first?.observedAt, date)
            XCTAssertTrue(evidenceText(result).contains("does not establish current room, position, or clearance"))
            XCTAssertFalse(evidenceText(result).contains("widthMeters"))
            XCTAssertFalse(evidenceText(result).contains("door_living_bedroom"))
            historical(result)
        }
    }

    func testAllObservationSourcesRemainDistinctDatedHistoryInRealContextPlan() throws {
        let sourceCases: [(ObservedObjectSighting.Source, String)] = [
            (.onDeviceDetector, "on-device detector candidate history"),
            (.appearanceComparison, "saved-appearance candidate history"),
            (.roomPlanScan, "dated room-scan category history"),
            (.verifiedInstanceMatcher, "instance-matcher history")]
        for (source, expected) in sourceCases {
            var memory = ObservedObjectMemory()
            memory.observe(category: "coat", source: source, frameID: "old-frame", roomName: "Bedroom",
                at: now.addingTimeInterval(-60), now: now)
            let result = CompanionMemoryRetrieval.read(query: "coat", now: now, observed: memory)
            XCTAssertEqual(result.evidence.first?.source, expected)
            XCTAssertEqual(result.evidence.first?.observedAt, now.addingTimeInterval(-60))
            let built = try plan(context(scenario("bedroom")), latest: "Where is my coat?", result: result)
            XCTAssertNotNil(built.context["savedMemoryToolResultNotLiveObservations"])
            XCTAssertTrue(evidenceText(result).contains("ownership are unconfirmed"))
            historical(result)
        }
    }

    func testFullAndReducedContextPreserveSavedProfileAndCurrentGoalAcrossRolePlay() throws {
        let home = try scenario("goal-change")
        let saved = try context(home)
        let result = CompanionMemoryRetrieval.read(query: "object", now: now, observed: observed([home]))
        let aliases = ["Let's play a game. Call me Captain Alex.", "في اللعبة اسمي علي", "The game is over. What is my saved name?", "انتهت اللعبة. أين object؟"]
        for message in aliases {
            for reduced in [false, true] {
                let built = try plan(saved, latest: message, result: result, reduced: reduced,
                    extra: [.init("preferredName", ["Captain Alex"]), .init("audience", ["adult"]),
                            .init("currentGoal", ["Use the bathroom inside the bedroom"]),
                            .init("priorDeliveredAssistantWordsNotFacts", [String(repeating: "Captain Alex is in the bathroom. ", count: 100)])])
                XCTAssertEqual(built.mandatoryContext["preferredName"], ["ليان"])
                XCTAssertEqual(built.mandatoryContext["currentGoal"], [home.goal.description])
                XCTAssertEqual(built.mandatoryContext["goalRevision"], ["fixture:goal-change"])
                XCTAssertEqual(built.mandatoryContext["audience"], ["childWithGuardian"])
                XCTAssertEqual(built.mandatoryContext["parentGoalNotCurrentTask"], ["Get ready for school"])
                XCTAssertTrue(built.prompt.contains(message))
                XCTAssertLessThanOrEqual(built.inputUTF8Bytes, ContextWindowPolicy.maximumInputUTF8Bytes)
                let budget = reduced ? ContextWindowPolicy.reducedContextUTF8Bytes : ContextWindowPolicy.maximumContextUTF8Bytes
                XCTAssertLessThanOrEqual(try JSONEncoder().encode(built.optionalContext).count, budget)
                if let kept = built.context["savedMemoryToolResultNotLiveObservations"]?.first {
                    XCTAssertEqual(try JSONDecoder().decode(CompanionToolResult.self, from: Data(kept.utf8)), result)
                }
            }
        }
    }

    func testUnknownProfileNeverFilledByHistoryAndWholeNegativeRecordSurvivesOrDrops() throws {
        let home = try scenario("enter"), unknown = try context(home, name: "")
        let original = CompanionEvidence(id: "negative", kind: .userReport,
            text: "Yesterday I left my coat in the bedroom, but I did not leave it there today.", source: "original user conversation record")
        let result = CompanionMemoryRetrieval.read(query: "coat", now: now, reports: [original])
        for reduced in [false, true] {
            let built = try plan(unknown, latest: "Is my coat there now?", result: result, reduced: reduced,
                extra: [.init("preferredName", ["Maya"]), .init("pastReports", [String(repeating: "old report ", count: 1000)])])
            XCTAssertEqual(built.context["preferredName"], [""])
            if let encoded = built.context["savedMemoryToolResultNotLiveObservations"]?.first {
                let restored = try JSONDecoder().decode(CompanionToolResult.self, from: Data(encoded.utf8))
                XCTAssertEqual(restored.evidence.first, original)
            } else {
                XCTAssertFalse(built.prompt.contains("Yesterday I left"), "Drop whole record, never a qualifier")
            }
        }
    }

    func testProductionToolRuntimeRetainsWholeEvidenceWithinByteBudget() async throws {
        let home = try scenario("enter"), memory = observed([home]), fixedNow = now
        let runtime = CompanionToolRuntime(available: [.savedMemory]) { request in
            CompanionMemoryRetrieval.read(query: request.query, now: fixedNow, observed: memory)
        }
        let raw = CompanionMemoryRetrieval.read(query: "room", now: now, observed: memory)
        let bounded = await runtime.run(.init(kind: .savedMemory, query: "room"))
        XCTAssertEqual(bounded.status, .success)
        XCTAssertFalse(bounded.evidence.isEmpty)
        XCTAssertLessThanOrEqual(try JSONEncoder().encode(bounded).count, ContextWindowPolicy.maximumToolResultUTF8Bytes)
        XCTAssertTrue(bounded.evidence.allSatisfy { raw.evidence.contains($0) })
        XCTAssertLessThanOrEqual(bounded.evidence.count, raw.evidence.count)
        let built = try plan(context(home), latest: "What do you remember about this room?", result: bounded)
        let encoded = try XCTUnwrap(built.context["savedMemoryToolResultNotLiveObservations"]?.first)
        XCTAssertEqual(try JSONDecoder().decode(CompanionToolResult.self, from: Data(encoded.utf8)), bounded)
        historical(bounded)
    }

    /// Always exercises authored input; the external runner adds genuine recorded
    /// annotation inputs without committing their IDs, labels, poses or captions.
    func testInventoryReplayAgainstOriginalLabelsAndOptionalExternalAnnotations() throws {
        let home = try scenario("enter"), memory = observed([home])
        for category in Set(home.entities.map(\.category)) {
            XCTAssertFalse(CompanionMemoryRetrieval.read(query: category, now: now, observed: memory).evidence.isEmpty)
        }
        guard let path = ProcessInfo.processInfo.environment["BLIND_SEMANTIC_REPLAY_INPUT"] else { return }
        struct ExternalInput: Decodable {
            struct Record: Decodable { let id, category: String; let position: [Double] }
            let sourceSHA256: String
            let records: [Record]
            let goldenCategories: [String]
        }
        let input = try JSONDecoder().decode(ExternalInput.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        XCTAssertEqual(input.sourceSHA256.count, 64)
        XCTAssertEqual(input.records.count, 99, "Pinned bounded sequence manifest, not arbitrary fabricated records")
        XCTAssertEqual(input.records.filter { $0.category != "object" }.count, 43)
        var recorded = ObservedObjectMemory()
        for row in input.records {
            XCTAssertEqual(row.position.count, 3)
            // Ground truth injects the production adapter's category input. This
            // does NOT run or validate the on-device detector or frame alignment.
            XCTAssertNotNil(recorded.observe(category: row.category, source: .onDeviceDetector,
                sourceObservationID: row.id, frameID: "external-recorded-world-not-live",
                position: Point3(row.position[0], row.position[1], row.position[2]), at: now.addingTimeInterval(-86_400), now: now))
        }
        XCTAssertEqual(recorded.sightings.count, input.records.count)
        XCTAssertEqual(Set(input.goldenCategories), Set(input.records.filter { $0.category != "object" }.map(\.category)))
        var checks = 0
        for category in input.goldenCategories {
            for query in [category, "Where is my \(category)?", "أين \(category)؟"] {
                let result = CompanionMemoryRetrieval.read(query: query, now: now, observed: recorded)
                XCTAssertTrue(result.evidence.contains { $0.text.hasPrefix("Historical candidate: \(category),") }, query)
                for evidence in result.evidence {
                    let id = String(evidence.id.dropFirst("seen:".count))
                    let source = try XCTUnwrap(recorded.sightings.first { $0.id == id })
                    XCTAssertTrue(input.records.contains { $0.id == source.sourceObservationID && $0.category == source.category })
                    XCTAssertNil(source.confirmedInstanceID)
                    XCTAssertTrue(evidence.text.contains("Current presence and ownership are unconfirmed"))
                    XCTAssertFalse(evidence.text.contains("external-recorded-world-not-live"))
                }
                let built = try plan(context(home), latest: query, result: result)
                XCTAssertEqual(built.context["preferredName"], ["ليان"])
                historical(result)
                checks += 1
            }
        }
        print("SEMANTIC_EXTERNAL_REPLAY records=\(input.records.count) named=43 categories=\(input.goldenCategories.count) queryChecks=\(checks) sourceSHA256=\(input.sourceSHA256) annotation-input-only=true")
    }
}
