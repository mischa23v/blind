import XCTest
@testable import BlindCore

final class RoomRecognizerTests: XCTestCase {
    func testNearbyPlacesFiltersSortsAndKeepsUnmeasuredLast() {
        let home = PlaceCandidate(placeID: "home", name: "Home", distanceMetres: 20)
        let neighbour = PlaceCandidate(placeID: "neighbour", name: "Neighbour", distanceMetres: 100)
        let aunt = PlaceCandidate(placeID: "aunt", name: "Aunt", distanceMetres: 500)
        let cousin = PlaceCandidate(placeID: "cousin", name: "Cousin", distanceMetres: nil)
        let unreadable = PlaceCandidate(placeID: "school", name: "School", distanceMetres: .nan)
        let unnamed = PlaceCandidate(placeID: "", name: "Blank", distanceMetres: 5)
        let all = [aunt, cousin, neighbour, unreadable, home, unnamed]
        // Compare IDs: a NaN distance never equals itself, so whole candidates cannot be compared.
        XCTAssertEqual(RoomRecognizer.nearbyPlaces(all).map(\.placeID), [home, neighbour, cousin, unreadable].map(\.placeID))
        XCTAssertEqual(RoomRecognizer.nearbyPlaces(all, radiusMetres: 50).map(\.placeID), [home, cousin, unreadable].map(\.placeID))
        XCTAssertEqual(RoomRecognizer.nearbyPlaces([]), [])
    }

    func testWorldMapAloneEstablishes() {
        var recognizer = RoomRecognizer()
        XCTAssertEqual(recognizer.decide([.worldMapMatched(roomID: "bedroom")], at: 0),
                       .established(roomID: "bedroom", basis: ["worldMap"]))
    }

    func testTwoWorldMapRoomsAskWhich() {
        var recognizer = RoomRecognizer()
        XCTAssertEqual(recognizer.decide([.worldMapMatched(roomID: "bedroom"), .worldMapMatched(roomID: "closet")], at: 0),
                       .askWhich(["bedroom", "closet"]))
    }

    func testTwoAppearanceCluesEstablishOnlyAfterStableCalls() {
        var recognizer = RoomRecognizer()
        let bedroom: [RoomEvidence] = [.imageSimilarity(roomID: "bedroom", score: 0.9),
                                       .furnitureSignature(roomID: "bedroom", overlap: 0.7)]
        XCTAssertEqual(recognizer.decide(bedroom, at: 0), .ask(roomID: "bedroom"))
        XCTAssertEqual(recognizer.decide(bedroom, at: 1),
                       .established(roomID: "bedroom", basis: ["imageSimilarity", "furnitureSignature"]))
        // One lucky kitchen frame does not switch rooms.
        let kitchen: [RoomEvidence] = [.imageSimilarity(roomID: "kitchen", score: 0.95),
                                       .furnitureSignature(roomID: "kitchen", overlap: 0.8)]
        XCTAssertEqual(recognizer.decide(kitchen, at: 2), .ask(roomID: "kitchen"))
        XCTAssertEqual(recognizer.decide(kitchen, at: 3),
                       .established(roomID: "kitchen", basis: ["imageSimilarity", "furnitureSignature"]))
    }

    func testLongGapRestartsStabilityCount() {
        var recognizer = RoomRecognizer()
        let bedroom: [RoomEvidence] = [.imageSimilarity(roomID: "bedroom", score: 0.9),
                                       .furnitureSignature(roomID: "bedroom", overlap: 0.7)]
        XCTAssertEqual(recognizer.decide(bedroom, at: 0), .ask(roomID: "bedroom"))
        XCTAssertEqual(recognizer.decide(bedroom, at: 10), .ask(roomID: "bedroom"))
        XCTAssertEqual(recognizer.decide(bedroom, at: 11),
                       .established(roomID: "bedroom", basis: ["imageSimilarity", "furnitureSignature"]))
        XCTAssertEqual(recognizer.decide(bedroom, at: 5), .ask(roomID: "bedroom"))
    }

    func testOneClueOrWeakerScoresAsk() {
        var recognizer = RoomRecognizer()
        let strongImageOnly: [RoomEvidence] = [.imageSimilarity(roomID: "bedroom", score: 0.9)]
        XCTAssertEqual(recognizer.decide(strongImageOnly, at: 0), .ask(roomID: "bedroom"))
        XCTAssertEqual(recognizer.decide(strongImageOnly, at: 1), .ask(roomID: "bedroom"))
        XCTAssertEqual(recognizer.decide(strongImageOnly, at: 2), .ask(roomID: "bedroom"))
        let weakPair: [RoomEvidence] = [.imageSimilarity(roomID: "bedroom", score: 0.6),
                                        .furnitureSignature(roomID: "bedroom", overlap: 0.4)]
        XCTAssertEqual(recognizer.decide(weakPair, at: 3), .ask(roomID: "bedroom"))
        XCTAssertEqual(recognizer.decide(weakPair, at: 4), .ask(roomID: "bedroom"))
        XCTAssertEqual(recognizer.decide([.layoutMatch(roomID: "bedroom", score: 0.6)], at: 5), .ask(roomID: "bedroom"))
    }

    func testCloseCompetitorsAskWhich() {
        var recognizer = RoomRecognizer()
        XCTAssertEqual(recognizer.decide([.imageSimilarity(roomID: "guest-room", score: 0.8),
                                          .imageSimilarity(roomID: "bedroom", score: 0.85)], at: 0),
                       .askWhich(["bedroom", "guest-room"]))
        XCTAssertEqual(recognizer.decide([.imageSimilarity(roomID: "bedroom", score: 0.6),
                                          .imageSimilarity(roomID: "guest-room", score: 0.55)], at: 1),
                       .askWhich(["bedroom", "guest-room"]))
    }

    func testWeakOrMissingEvidenceIsUnknown() {
        var recognizer = RoomRecognizer()
        XCTAssertEqual(recognizer.decide([], at: 0), .unknown)
        XCTAssertEqual(recognizer.decide([.imageSimilarity(roomID: "bedroom", score: 0.3)], at: 1), .unknown)
        XCTAssertEqual(recognizer.decide([.furnitureSignature(roomID: "bedroom", overlap: 0.1)], at: 2), .unknown)
        XCTAssertEqual(recognizer.decide([.layoutMatch(roomID: "bedroom", score: 0.4)], at: 3), .unknown)
        XCTAssertEqual(recognizer.decide([.imageSimilarity(roomID: "bedroom", score: .nan)], at: 4), .unknown)
        XCTAssertEqual(recognizer.decide([.imageSimilarity(roomID: "bedroom", score: 1.5)], at: 5), .unknown)
        XCTAssertEqual(recognizer.decide([.imageSimilarity(roomID: "", score: 0.9)], at: 6), .unknown)
        XCTAssertEqual(recognizer.decide([.movedThrough(fromRoomID: "bedroom", toRoomID: "bedroom")], at: 7), .unknown)
        XCTAssertEqual(recognizer.decide([.worldMapMatched(roomID: "bedroom")], at: .nan), .unknown)
    }

    func testUserConfirmationEstablishes() {
        var recognizer = RoomRecognizer()
        XCTAssertEqual(recognizer.decide([.userConfirmed(roomID: "bedroom")], at: 0),
                       .established(roomID: "bedroom", basis: ["user"]))
        XCTAssertEqual(recognizer.decide([.userConfirmed(roomID: "bedroom"), .worldMapMatched(roomID: "kitchen")], at: 1),
                       .established(roomID: "bedroom", basis: ["user", "conflict:worldMap:kitchen"]))
    }

    func testConflictPrefersWorldMapAndNotesConflict() {
        var recognizer = RoomRecognizer()
        // A lone map match against a strong clue for another room is doubt: ask.
        XCTAssertEqual(recognizer.decide([.worldMapMatched(roomID: "bedroom"),
                                          .imageSimilarity(roomID: "kitchen", score: 0.9)], at: 0),
                       .askWhich(["bedroom", "kitchen"]))
        XCTAssertEqual(recognizer.decide([.worldMapMatched(roomID: "bedroom"),
                                          .furnitureSignature(roomID: "bedroom", overlap: 0.7),
                                          .imageSimilarity(roomID: "kitchen", score: 0.9)], at: 1),
                       .established(roomID: "bedroom",
                                    basis: ["worldMap", "furnitureSignature", "conflict:imageSimilarity:kitchen"]))
    }

    func testMovementAndImageEstablishAfterStableCalls() {
        var recognizer = RoomRecognizer()
        let evidence: [RoomEvidence] = [.movedThrough(fromRoomID: "hallway", toRoomID: "bedroom"),
                                        .imageSimilarity(roomID: "bedroom", score: 0.85)]
        XCTAssertEqual(recognizer.decide(evidence, at: 0), .ask(roomID: "bedroom"))
        XCTAssertEqual(recognizer.decide(evidence, at: 1),
                       .established(roomID: "bedroom", basis: ["imageSimilarity", "movedThrough"]))
    }

    func testLayoutAndFurnitureEstablishAfterStableCalls() {
        var recognizer = RoomRecognizer()
        let evidence: [RoomEvidence] = [.layoutMatch(roomID: "bedroom", score: 0.8),
                                        .furnitureSignature(roomID: "bedroom", overlap: 0.7)]
        XCTAssertEqual(recognizer.decide(evidence, at: 0), .ask(roomID: "bedroom"))
        XCTAssertEqual(recognizer.decide(evidence, at: 1),
                       .established(roomID: "bedroom", basis: ["furnitureSignature", "layoutMatch"]))
    }

    func testMovementAloneAsks() {
        var recognizer = RoomRecognizer()
        let evidence: [RoomEvidence] = [.movedThrough(fromRoomID: "hallway", toRoomID: "bedroom")]
        XCTAssertEqual(recognizer.decide(evidence, at: 0), .ask(roomID: "bedroom"))
        XCTAssertEqual(recognizer.decide(evidence, at: 1), .ask(roomID: "bedroom"))
        XCTAssertEqual(recognizer.decide(evidence, at: 2), .ask(roomID: "bedroom"))
    }

    func testMovementIntoOneRoomWhileImageSaysAnotherAsksWhich() {
        var recognizer = RoomRecognizer()
        let evidence: [RoomEvidence] = [.movedThrough(fromRoomID: "hallway", toRoomID: "bathroom"),
                                        .imageSimilarity(roomID: "bedroom", score: 0.9)]
        XCTAssertEqual(recognizer.decide(evidence, at: 0), .askWhich(["bathroom", "bedroom"]))
        XCTAssertEqual(recognizer.decide(evidence, at: 1), .askWhich(["bathroom", "bedroom"]))
    }
}
