import XCTest
import BlindCore
@testable import SearchAreaReplay

/// Full production forget/control adapters; native purge/storage are explicit
/// substituted collaborators. No real photo database or deletion latency claim.
final class SearchAreaPrivacyTests: XCTestCase {
    private func scope(_ id: String) -> CompanionMemoryScope {
        CompanionMemoryScope(map: SpatialMapBinding(mapID: "map-" + id, frameID: "frame", revision: "1"),
            placeID: "home-" + id, floorID: "floor", roomID: "room")!
    }
    private func seeded(_ scope: CompanionMemoryScope? = nil) -> SearchAreaReplay {
        let c = SearchAreaReplay()
        if let scope { c.companionWorkingState.transitionMemoryScope(scope) }
        c.receiveCompanionUtterance("Find my fridge"); c.receiveCompanionUtterance("kitchen")
        return c
    }
    func testForgetCommandWithoutSavedItemStillRetiresMatchingRawClue() throws {
        let c = seeded(); XCTAssertTrue(c.items.items.isEmpty)
        XCTAssertNotNil(c.companionWorkingState.searchAreaClue.clue)
        c.receiveCompanionUtterance("forget my fridge")
        XCTAssertNil(c.companionWorkingState.searchAreaClue.clue)
        XCTAssertEqual(c.currentReply, "I've cleared that search clue. There is no saved item with that name.")
        XCTAssertTrue(c.modelInputs.isEmpty)
        c.receiveCompanionUtterance("Where is my fridge?")
        XCTAssertFalse(c.currentReply.contains("kitchen"))
        let pending = SearchAreaReplay(); pending.receiveCompanionUtterance("Find my fridge")
        XCTAssertNotNil(pending.companionWorkingState.searchAreaClue.question)
        pending.receiveCompanionUtterance("forget my fridge")
        XCTAssertNil(pending.companionWorkingState.searchAreaClue.question)
        XCTAssertNil(pending.companionWorkingState.searchAreaClue.clue)
        XCTAssertEqual(pending.currentReply, "No saved fridge to forget.", "Pending question is not an accepted clue")
    }
    func testSavedItemDeletionRetiresMatchingClueBeforeNativePurgeCompletes() throws {
        let c = seeded(scope("A"))
        let item = try XCTUnwrap(c.items.remember(name: "fridge", at: Date(), scope: scope("A")))
        var completed: Bool?
        c.forgetItem(item) { completed = $0 }
        XCTAssertNil(c.companionWorkingState.searchAreaClue.clue)
        XCTAssertNil(completed); XCTAssertTrue(c.items.items.contains(item))
        c.nativeObservations.finish(false)
        XCTAssertEqual(completed, false)
        XCTAssertNil(c.companionWorkingState.searchAreaClue.clue, "Failed purge must not resurrect a private clue")
    }
    func testSuccessfulSavedItemDeletionUsesRealCommitAdapterAndKeepsOtherClues() throws {
        let c = seeded(scope("A")), clue = c.companionWorkingState.searchAreaClue.clue
        let item = try XCTUnwrap(c.items.remember(name: "cup", at: Date(), scope: scope("A")))
        var completed: Bool?
        c.forgetItem(item) { completed = $0 }
        XCTAssertEqual(c.companionWorkingState.searchAreaClue.clue, clue)
        c.nativeObservations.finish(true)
        XCTAssertEqual(completed, true); XCTAssertFalse(c.items.items.contains(item))
        XCTAssertEqual(c.companionWorkingState.searchAreaClue.clue, clue)
        XCTAssertEqual(c.itemAppearance.forgotten, [item.key])
        XCTAssertEqual(c.removedObservationCategories, ["cup"])
    }
    func testSameNamedSavedItemInDifferentScopeDoesNotEraseCurrentClue() throws {
        let c = seeded(scope("A")), clue = c.companionWorkingState.searchAreaClue.clue
        let elsewhere = try XCTUnwrap(c.items.remember(name: "fridge", at: Date(), scope: scope("B")))
        c.forgetItem(elsewhere)
        XCTAssertEqual(c.companionWorkingState.searchAreaClue.clue, clue)
        c.nativeObservations.finish(true)
        XCTAssertEqual(c.companionWorkingState.searchAreaClue.clue, clue)
    }
    func testOtherNoSavedItemForgetCommandKeepsMatchingGoalClue() {
        let c = seeded(), clue = c.companionWorkingState.searchAreaClue.clue, goal = c.companionWorkingState.goal
        c.receiveCompanionUtterance("forget my cup")
        XCTAssertEqual(c.companionWorkingState.searchAreaClue.clue, clue)
        XCTAssertEqual(c.companionWorkingState.goal, goal)
        c.receiveCompanionUtterance("Where is my fridge?")
        XCTAssertTrue(c.currentReply.contains("kitchen"))
    }
    func testLocationReportDeletionRetiresOnlyMatchingTargetAndScopeClue() throws {
        for (target, reportScope, shouldRetire) in [("fridge", scope("A"), true), ("cup", scope("A"), false), ("fridge", scope("B"), false)] {
            let c = seeded(scope("A")), clue = try XCTUnwrap(c.companionWorkingState.searchAreaClue.clue)
            _ = try XCTUnwrap(c.companionWorkingState.factBook.record(object: target, place: "in the pantry", tense: .earlier,
                hedged: true, at: Date(), scope: reportScope, sourceID: "location-source"))
            XCTAssertTrue(c.companionWorkingState.removeLocationReport(sourceID: "location-source"))
            XCTAssertEqual(c.companionWorkingState.searchAreaClue.clue == nil, shouldRetire)
            if !shouldRetire { XCTAssertEqual(c.companionWorkingState.searchAreaClue.clue, clue) }
            XCTAssertTrue(c.companionWorkingState.factBook.facts.isEmpty)
        }
    }
    func testAllConversationResetClearsClueAndGoal() {
        let c = seeded(); c.clearAssistantConversation()
        XCTAssertEqual(c.capturedTextPurgeCalls, 1, "Conversation privacy deletion invokes captured-reader retirement")
        XCTAssertNil(c.companionWorkingState.searchAreaClue.clue)
        XCTAssertNil(c.companionWorkingState.searchAreaClue.question)
        XCTAssertTrue(c.companionWorkingState.goal.isEmpty)
        XCTAssertTrue(c.companionWorkingState.reports.isEmpty)
        c.receiveCompanionUtterance("kitchen")
        XCTAssertEqual(c.modelInputs, ["kitchen"])
    }
    func testQuietAndDirectStopDescriptionsPreserveGoalAndAcceptedClue() throws {
        for direct in [false, true] {
            let c = seeded(), clue = try XCTUnwrap(c.companionWorkingState.searchAreaClue.clue), goal = c.companionWorkingState.goal
            if direct { c.stopDescriptions() } else { c.receiveCompanionUtterance("quiet") }
            XCTAssertFalse(c.ambientDescriptions)
            XCTAssertEqual(c.companionWorkingState.goal, goal)
            XCTAssertEqual(c.companionWorkingState.searchAreaClue.clue, clue)
            c.receiveCompanionUtterance("Where is my fridge?")
            XCTAssertTrue(c.currentReply.contains("kitchen")); XCTAssertEqual(c.companionWorkingState.goal, goal)
        }
    }
    func testDelayedPurgeCannotEraseNewGoalClue() throws {
        let c = seeded()
        let item = try XCTUnwrap(c.items.remember(name: "fridge", at: Date()))
        var completed: Bool?
        c.forgetItem(item) { completed = $0 }
        XCTAssertNil(c.companionWorkingState.searchAreaClue.clue)
        c.receiveCompanionUtterance("Find my cup"); c.receiveCompanionUtterance("pantry")
        let newer = try XCTUnwrap(c.companionWorkingState.searchAreaClue.clue)
        c.nativeObservations.finish(true)
        XCTAssertEqual(completed, true)
        XCTAssertEqual(c.companionWorkingState.searchAreaClue.clue, newer)
        XCTAssertEqual(c.companionWorkingState.focusObject, "cup")
    }

    func testExactPlaceIDRetirementDoesNotInferFromRoomOrRawClueWords() throws {
        // This is the actual state helper, not the native saved-place deletion
        // workflow. Separate source checks verify its synchronous adapter call.
        let cases: [(CompanionMemoryScope?, String, Bool)] = [
            (scope("A"), "home-A", true), (scope("A"), "home-B", false),
            (scope("A"), "room", false), (scope("A"), "kitchen", false),
            (scope("A"), "home", false), (nil, "home-A", false)
        ]
        for (bound, deleting, retired) in cases {
            let c = seeded(bound), clue = try XCTUnwrap(c.companionWorkingState.searchAreaClue.clue)
            let goal = c.companionWorkingState.goal
            c.companionWorkingState.retireSearchClue(placeID: deleting)
            XCTAssertEqual(c.companionWorkingState.searchAreaClue.clue == nil, retired, deleting)
            if !retired { XCTAssertEqual(c.companionWorkingState.searchAreaClue.clue, clue) }
            XCTAssertEqual(c.companionWorkingState.goal, goal)
        }
    }

}
