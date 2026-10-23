import XCTest
@testable import BlindCore

/// Scripted journeys through production Core APIs, not a replacement controller.
/// Each explicit mutation below models a caller action. These tests do NOT prove
/// NavigationModel dispatch, Foundation Models, speech, room recognition or device
/// localization. The app's separate CompanionWorkingState parent-goal hierarchy
/// is covered by hosted state tests, not silently reimplemented in this fixture.
final class CompanionJourneyAcceptanceTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_000_000)

    func testSchoolPreparationKeepsReportedCoatHistoryAndDestinationThroughConversation() throws {
        var dialogue = AssistantDialogue()
        var facts = CompanionFactBook()
        var saved = ItemMemory()

        // First input is a user report, not an observation of a hanger or room.
        let report = "I left my coat on the hanger in my bedroom."
        dialogue.record(role: "user", text: report)
        guard case .report(let object?, let place, let tense, let hedged)? = CompanionUtterance.parse(report) else {
            return XCTFail("The explicit coat report must parse")
        }
        XCTAssertEqual(object, "coat")
        XCTAssertEqual(place, "on the hanger in my bedroom")
        let fact = try XCTUnwrap(facts.record(object: object, place: place, tense: tense, hedged: hedged, at: date))
        XCTAssertTrue(fact.acknowledgement(arabic: false).contains("You last had your coat"))

        // A separate explicit saved-item action supplies the room. No parser is
        // assumed to infer a room ID, a hanger relationship, position or colour.
        XCTAssertNotNil(saved.remember(name: "my coat", roomID: "private-bedroom", roomName: "bedroom", at: date))
        let destination = try XCTUnwrap(AssistantControl.explicitGoal("My goal is school"))
        dialogue.record(role: "user", text: "My goal is school")
        dialogue.setGoal(destination)
        let schoolRevision = dialogue.goalRevision
        XCTAssertEqual(dialogue.goal, "school")

        // An intermediate, externally established room only changes attention.
        // Authored room IDs here are policy inputs, not physical localization proof.
        var attention = CompanionAttention()
        attention.enterRoom("hallway", established: true)
        let roomOffer = InformationCandidate(key: "hallway:offer", kind: .offer,
            text: "Would you like a room description?", words: 7,
            createdAt: 10, expiresAt: 18, room: "hallway", offerKind: .describeRoom)
        XCTAssertEqual(attention.decide([roomOffer],
            moment: CompanionMoment(now: 10, goalActive: !dialogue.goal.isEmpty, activity: .moving),
            settings: CompanionSettings()).map(\.reason), [.goalInProgress])

        // Knowing the room and the user's report does not establish coat colour.
        let colorQuestion = "What color is my coat?"
        dialogue.record(role: "user", text: colorQuestion)
        XCTAssertEqual(ConversationDomainPolicy.requiredInspection(for: colorQuestion), .clothingColor)
        XCTAssertFalse(ConversationDomainPolicy.allowsModelResponse(to: colorQuestion))
        XCTAssertNil(saved.find("coat")?.description)
        XCTAssertEqual(ClothingColor.evaluate([]), .insufficientPixels)

        let interruption = "Why do leaves change color?"
        XCTAssertEqual(ConversationIntent.classify(interruption), .conversation)
        XCTAssertNil(ConversationIntent.explicitTaskGoal(interruption))
        XCTAssertNil(CompanionUtterance.parse(interruption))
        dialogue.record(role: "user", text: interruption)
        XCTAssertEqual(dialogue.goal, "school")
        XCTAssertEqual(dialogue.goalRevision, schoolRevision)
        XCTAssertEqual(attention.currentRoom, "hallway")

        // Persistence retains attributed history, never a currently measured pose.
        let restoredDialogue = try JSONDecoder().decode(AssistantDialogue.self, from: JSONEncoder().encode(dialogue))
        let restoredFacts = try JSONDecoder().decode(CompanionFactBook.self, from: JSONEncoder().encode(facts))
        let restoredSaved = try JSONDecoder().decode(ItemMemory.self, from: JSONEncoder().encode(saved))
        XCTAssertEqual(restoredDialogue.goal, "school")
        XCTAssertEqual(restoredDialogue.goalRevision, schoolRevision)
        XCTAssertTrue(restoredDialogue.relevantUserReports(for: "Where did I leave my coat?").contains { $0.text == report })
        let later = date.addingTimeInterval(600)
        let recalledFact = try XCTUnwrap(restoredFacts.latest(for: "my coat"))
        XCTAssertEqual(recalledFact.recall(now: later, arabic: false),
            "You told me 10 minutes ago you last had your coat on the hanger in my bedroom. I don't know where it is now.")
        let item = try XCTUnwrap(restoredSaved.find("coat"))
        XCTAssertEqual(item.roomName, "bedroom")
        XCTAssertNil(item.position)
        XCTAssertNil(item.frameID)
        XCTAssertNil(item.description)
        XCTAssertEqual(ItemMemory.answer(for: item, asked: "coat", now: later,
            sameFrame: false, measuredRelation: nil, arabic: false),
            "Your coat was saved in the bedroom 10 minutes ago. Its current position is not confirmed.")
    }

    func testInterruptedCoatSearchResumesOnceButBackpackSwitchRetiresItAndKeepsHistory() throws {
        var dialogue = AssistantDialogue()
        let report = "I left my coat on the hanger in my bedroom."
        dialogue.record(role: "user", text: report)
        let coatRequest = "Help me find my coat"
        XCTAssertEqual(CompanionUtterance.parse(coatRequest), .find(object: "coat"))
        dialogue.setGoal(try XCTUnwrap(ConversationIntent.explicitTaskGoal(coatRequest)))
        let coatRevision = dialogue.goalRevision
        var coatSearch = ObjectSearch(target: "coat", now: 100)
        coatSearch.attempted(now: 101, found: nil)
        coatSearch.hintTried = true
        var interrupted = InterruptedObjectSearch()
        interrupted.capture(search: coatSearch, goalRevision: coatRevision, generation: 7, now: 102)

        // Acoustic onset precedes the final transcript. Nil capture after the
        // cancelled live search must not lose or refresh the original receipt.
        let question = "What do butterflies eat?"
        XCTAssertEqual(ConversationIntent.classify(question), .conversation)
        XCTAssertNil(CompanionUtterance.parse(question))
        dialogue.record(role: "user", text: question)
        interrupted.capture(search: nil, goalRevision: dialogue.goalRevision, generation: 7, now: 104)
        let resumed = try XCTUnwrap(interrupted.restore(goalRevision: dialogue.goalRevision, generation: 7, now: 106))
        XCTAssertEqual(resumed, coatSearch)
        XCTAssertEqual(resumed.startedAt, 100)
        XCTAssertEqual(resumed.attempts, 1)
        XCTAssertTrue(resumed.hintTried)
        XCTAssertEqual(dialogue.goalRevision, coatRevision)
        XCTAssertNil(interrupted.restore(goalRevision: dialogue.goalRevision, generation: 7, now: 107))

        interrupted.capture(search: resumed, goalRevision: dialogue.goalRevision, generation: 7, now: 108)
        let replacement = "Help me find my backpack"
        XCTAssertEqual(CompanionUtterance.parse(replacement), .find(object: "backpack"))
        dialogue.record(role: "user", text: replacement)
        dialogue.setGoal(try XCTUnwrap(ConversationIntent.explicitTaskGoal(replacement)))
        XCTAssertNotEqual(dialogue.goalRevision, coatRevision)
        XCTAssertEqual(dialogue.goal, replacement)
        XCTAssertNil(interrupted.restore(goalRevision: dialogue.goalRevision, generation: 7, now: 109))
        XCTAssertFalse(interrupted.hasPending)
        XCTAssertTrue(dialogue.relevantUserReports(for: "Where did I leave my coat?").contains { $0.text == report })

        // A new explicit backpack search is distinct, not a resurrection of coat.
        var backpack = ObjectSearch(target: "backpack", now: 109)
        backpack.attempted(now: 110, found: nil)
        interrupted.capture(search: backpack, goalRevision: dialogue.goalRevision, generation: 7, now: 111)
        XCTAssertEqual(ConversationIntent.classify("Cancel the task"), .taskControl(.cancel))
        interrupted.cancel()
        dialogue.setGoal("")
        XCTAssertNil(interrupted.restore(goalRevision: dialogue.goalRevision, generation: 7, now: 112))
        XCTAssertEqual(dialogue.goal, "")
    }

    func testBackpackSearchTimeoutMeansNotLocatedAndDoesNotErasePriorObservation() throws {
        var observations = ObservedObjectMemory()
        XCTAssertNotNil(observations.observe(category: "backpack", source: .onDeviceDetector,
            frameID: "old-session", roomID: "bedroom", roomName: "bedroom", at: date, now: date))
        let later = date.addingTimeInterval(600)
        observations.expire(at: later)

        var search = ObjectSearch(target: "backpack", now: 100)
        XCTAssertEqual(search.attempted(now: 101, found: nil), .searching)
        XCTAssertEqual(search.attempted(now: 120, found: nil), .notLocated)
        XCTAssertFalse(search.active)
        XCTAssertEqual(ObjectSearch.notLocated(target: "backpack", arabic: false),
            "I haven't located your backpack in what the camera saw. That doesn't mean it isn't nearby.")
        let record = SearchRecord(target: "backpack", located: false, at: later)
        XCTAssertTrue(record.matches("my backpack"))
        XCTAssertFalse(record.located)
        XCTAssertEqual(record.sentence(now: later.addingTimeInterval(120), arabic: false),
            "I looked 2 minutes ago and didn't locate your backpack.")

        let history = observations.recall(category: "my backpack", at: later)
        XCTAssertEqual(history.status, .history)
        XCTAssertEqual(history.sightings.count, 1)
        XCTAssertEqual(history.sightings.first?.observedAt, date)
        XCTAssertNil(history.relation)
        XCTAssertEqual(ObservedObjectMemory.answer(for: history, asked: "my backpack", now: later, arabic: false),
            "I last noticed a backpack in the bedroom 10 minutes ago. Its current location is unconfirmed.")
        let unknown = observations.recall(category: "coat", at: later)
        XCTAssertEqual(unknown.status, .notFound)
        XCTAssertEqual(ObservedObjectMemory.answer(for: unknown, asked: "coat", now: later, arabic: false),
            "I have no saved observation of that category. That does not mean it is absent.")
    }

    func testCompetingCoatRoomHistoryRemainsAmbiguousAfterRestartAndUnsuccessfulSearch() throws {
        var observations = ObservedObjectMemory()
        XCTAssertNotNil(observations.observe(category: "coat", source: .onDeviceDetector,
            frameID: "session-a", roomID: "bedroom", roomName: "bedroom", at: date, now: date))
        let second = date.addingTimeInterval(60)
        XCTAssertNotNil(observations.observe(category: "coat", source: .onDeviceDetector,
            frameID: "session-a", roomID: "hallway", roomName: "hallway", at: second, now: second))
        let restored = try JSONDecoder().decode(ObservedObjectMemory.self, from: JSONEncoder().encode(observations))
        let later = date.addingTimeInterval(600)
        var currentSearch = ObjectSearch(target: "coat", now: 100)
        XCTAssertEqual(currentSearch.attempted(now: 120, found: nil), .notLocated)
        let history = restored.recall(category: "my coat", at: later)
        XCTAssertEqual(history.status, .ambiguous)
        XCTAssertEqual(Set(history.sightings.compactMap(\.roomID)), Set(["bedroom", "hallway"]))
        XCTAssertTrue(history.sightings.allSatisfy { !$0.isActive && $0.confirmedInstanceID == nil && $0.position == nil })
        XCTAssertNil(history.relation)
        let answer = ObservedObjectMemory.answer(for: history, asked: "my coat", now: later, arabic: false)
        XCTAssertTrue(answer.contains("I have other possible sightings. Which room?"))
        XCTAssertFalse(answer.contains("your coat"), "Category detections do not establish ownership")
        XCTAssertFalse(answer.contains("two coats"), "Alternative observations do not establish object count")
        XCTAssertFalse(answer.contains("meters"))
        XCTAssertFalse(answer.contains("metres"))
    }

    func testMappedExitSurvivesNoCameraDetectionAndCupboardDoorIsNotRoomConnection() throws {
        let authored = IndoorMap(name: "Synthetic exit semantics", nodes: [
            MapNode(id: "start", name: "Start", level: "floor", position: Point3(0, 0, 0)),
            MapNode(id: "end", name: "End", level: "floor", position: Point3(0, 0, -4))
        ], edges: [MapEdge(from: "start", to: "end", distance: 4)])
        var package = try PlacePackage.draft(map: authored, author: "Test fixture", license: "Test data only")
        package.routeMap = nil
        package.localization = "preview-only"
        var cupboard = RoomFeature(id: "cupboard-door", kind: "furniture", category: "storage", confidence: "high",
            corners: [Point3(1, 0, 0), Point3(2, 0, 0), Point3(2, 2, 0), Point3(1, 2, 0)])
        cupboard.label = "Cupboard door"
        package.rooms = [
            .init(id: "hall", name: "Hall", floorID: "floor", kind: "corridor", description: "",
                  layout: RoomLayout(name: "Hall", features: [cupboard])),
            .init(id: "outside", name: "Building exit", floorID: "floor", kind: "exit", description: "")
        ]
        package.connections = [.init(id: "functional-exit", fromRoomID: "hall", toRoomID: "outside",
            kind: "door", state: "mapped", source: "Authored test connection; current opening and path are unknown")]
        let restored = try PlacePackage.decode(package.encoded())
        XCTAssertEqual(restored.rooms.first { $0.id == "outside" }?.kind, "exit")
        XCTAssertEqual(restored.connections.first?.toRoomID, "outside")
        XCTAssertEqual(restored.connections.first?.state, "mapped")
        XCTAssertEqual(restored.rooms.first { $0.id == "hall" }?.layout?.features.first?.kind, "furniture")
        XCTAssertNil(restored.routeMap, "A functional mapped exit is not a current walkable route")
        XCTAssertEqual(restored.localization, "preview-only")

        // No image/current detection is supplied. It neither removes the authored
        // exit nor changes its mapped state into absence, open or clear-path proof.
        let cameraHistory = ObservedObjectMemory()
        let unseen = cameraHistory.recall(category: "door", at: date)
        XCTAssertEqual(unseen.status, .notFound)
        XCTAssertTrue(ObservedObjectMemory.answer(for: unseen, asked: "door", now: date, arabic: false)
            .contains("That does not mean it is absent."))
        XCTAssertEqual(restored.connections.count, 1)
        var invalid = restored
        invalid.connections[0].toRoomID = "cupboard-door"
        XCTAssertThrowsError(try invalid.validate(), "Furniture names cannot become connected exit rooms")
    }
}
