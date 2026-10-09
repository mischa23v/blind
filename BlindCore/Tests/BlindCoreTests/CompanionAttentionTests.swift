import XCTest
@testable import BlindCore

/// OFF-01–OFF-08 and the decision steps of OUT-01 in research/ASSISTANT_TEST_PLAN.md.
final class CompanionAttentionTests: XCTestCase {
    private func item(_ key: String, _ kind: InformationCandidate.Kind, words: Int = 6, at time: Double = 0,
                      ttl: Double = 30, category: String? = nil, requested: Bool = false, goal: Bool = false,
                      room: String? = nil, offer: CompanionOffer.Kind? = nil, revision: String = "1") -> InformationCandidate {
        InformationCandidate(key: key, kind: kind, text: key, words: words, revision: revision, createdAt: time,
                             expiresAt: time + ttl, category: category, requested: requested, goalRelevant: goal,
                             room: room, offerKind: offer)
    }
    private func roomOffer(_ room: String, at time: Double = 0) -> InformationCandidate {
        item("room:\(room):offer", .offer, words: 7, at: time, ttl: 8, room: room, offer: .describeRoom)
    }
    private func reasons(_ decisions: [CompanionDecision]) -> [CompanionReason] { decisions.map(\.reason) }

    // OFF-01: first visit gets one short offer; silence declines it for the session.
    func testFirstVisitOffersOnceAndSilenceDeclines() {
        var engine = CompanionAttention(), settings = CompanionSettings()
        XCTAssertEqual(engine.enterRoom("kitchen", established: true), .firstVisit)
        let first = engine.decide([roomOffer("kitchen")], moment: CompanionMoment(now: 0, activity: .stationary), settings: settings)
        guard case .offer(let offer, .offered) = first.first else { return XCTFail("expected an offer, got \(first)") }
        XCTAssertEqual(offer.kind, .describeRoom)
        XCTAssertEqual(offer.subject, "kitchen")
        // No answer before the offer expires counts as no.
        let later = engine.decide([roomOffer("kitchen", at: 20)], moment: CompanionMoment(now: 20, activity: .stationary), settings: settings)
        XCTAssertNil(engine.pendingOffer)
        XCTAssertEqual(reasons(later), [.declined])
        settings.firstVisitRooms = .never
        var fresh = CompanionAttention()
        XCTAssertEqual(reasons(fresh.decide([roomOffer("hall")], moment: CompanionMoment(now: 0), settings: settings)), [.never])
    }

    func testAcceptedOfferBecomesARequestedDescription() {
        var engine = CompanionAttention()
        engine.enterRoom("study", established: true)
        _ = engine.decide([roomOffer("study")], moment: CompanionMoment(now: 0, activity: .stationary), settings: CompanionSettings())
        XCTAssertEqual(engine.answerOffer(.yes)?.subject, "study")
        let description = item("room:study:description", .roomDescription, words: 60, at: 2, requested: true, room: "study")
        XCTAssertEqual(reasons(engine.decide([description], moment: CompanionMoment(now: 2), settings: CompanionSettings())), [.requested])
        // Described once: a later unsolicited description of the same room is familiar.
        engine.enterRoom("study", established: true)
        XCTAssertEqual(reasons(engine.decide([roomOffer("study", at: 40)], moment: CompanionMoment(now: 40), settings: CompanionSettings())), [.familiarRoom])
    }

    // OFF-02: familiar room is silent; a relevant change is said briefly.
    func testFamiliarRoomIsSilentButRelevantChangeIsSaid() {
        var memory = CompanionMemory(); memory.rooms["bedroom"] = RoomRecord(); memory.rooms["bedroom"]?.visits = 40
        var engine = CompanionAttention(memory: memory)
        XCTAssertEqual(engine.enterRoom("bedroom", established: true), .familiar)
        let decisions = engine.decide([roomOffer("bedroom"),
                                       item("bedroom:chair:moved", .change, at: 0, category: "objects", room: "bedroom")],
                                      moment: CompanionMoment(now: 0, activity: .stationary), settings: CompanionSettings())
        XCTAssertEqual(reasons(decisions), [.change, .familiarRoom])
    }

    // OFF-03: uncertain identity is asked about, not assumed; the answer is user-stated only.
    func testUncertainRoomIsAskedAndNotCountedAsVisit() {
        var engine = CompanionAttention()
        XCTAssertEqual(engine.enterRoom("bedroom", established: false), .unconfirmed)
        XCTAssertNil(engine.currentRoom)
        XCTAssertNil(engine.memory.rooms["bedroom"])
        let ask = item("identity:bedroom", .offer, words: 4, room: "bedroom", offer: .confirmRoom)
        // Asked even while a goal is in progress, because directions depend on it.
        let decisions = engine.decide([ask], moment: CompanionMoment(now: 0, goalActive: true, activity: .moving), settings: CompanionSettings())
        guard case .offer(let offer, _) = decisions.first else { return XCTFail("expected a question") }
        XCTAssertEqual(offer.kind, .confirmRoom)
        XCTAssertNotNil(engine.answerOffer(.yes))
        engine.userConfirmedRoom("bedroom")
        XCTAssertEqual(engine.memory.rooms["bedroom"]?.confirmedByUser, true)
        XCTAssertEqual(engine.memory.rooms["bedroom"]?.visits, 0, "a confirmed name is not an established visit or pose")
    }

    // OFF-04: repeated declines become a reviewable hint; an explicit request still works; removal restores offers.
    func testRepeatedDeclinesBecomeRemovableHint() {
        var engine = CompanionAttention(), time = 0.0
        for room in ["hall", "office", "garage"] {
            engine.enterRoom(room, established: true)
            _ = engine.decide([roomOffer(room, at: time)], moment: CompanionMoment(now: time, activity: .stationary), settings: CompanionSettings())
            XCTAssertNil(engine.answerOffer(.no))
            time += 30
        }
        XCTAssertEqual(engine.memory.hints.map(\.id), ["describeRoom:*"])
        engine.enterRoom("attic", established: true)
        XCTAssertEqual(reasons(engine.decide([roomOffer("attic", at: time)], moment: CompanionMoment(now: time), settings: CompanionSettings())), [.declined])
        let asked = item("room:attic:description", .roomDescription, words: 40, at: time, requested: true, room: "attic")
        XCTAssertEqual(reasons(engine.decide([asked], moment: CompanionMoment(now: time), settings: CompanionSettings())), [.requested])
        engine.memory.removeHint(id: "describeRoom:*")
        engine.enterRoom("cellar", established: true)
        guard case .offer = engine.decide([roomOffer("cellar", at: time + 30)], moment: CompanionMoment(now: time + 30), settings: CompanionSettings()).first
        else { return XCTFail("offers return after the hint is removed") }
    }

    func testOneDeclineIsNotAHabitAndIdentityQuestionsNeverBecomeHints() {
        var engine = CompanionAttention()
        engine.enterRoom("hall", established: true)
        _ = engine.decide([roomOffer("hall")], moment: CompanionMoment(now: 0), settings: CompanionSettings())
        engine.answerOffer(.no)
        for time in [10.0, 40, 70, 100] {
            _ = engine.decide([item("identity:\(time)", .offer, words: 4, at: time, room: "bedroom", offer: .confirmRoom)],
                              moment: CompanionMoment(now: time), settings: CompanionSettings())
            engine.answerOffer(.no)
        }
        XCTAssertTrue(engine.memory.hints.isEmpty)
    }

    // OFF-05: goal information comes before the room offer and skips the frequency gap.
    func testGoalInformationPrecedesDescription() {
        var engine = CompanionAttention()
        engine.enterRoom("cafe", established: true)
        let seat = item("cafe:seat", .goal, words: 12, goal: true)
        let decisions = engine.decide([roomOffer("cafe"), seat], moment: CompanionMoment(now: 0, goalActive: true, activity: .moving),
                                      settings: CompanionSettings())
        XCTAssertEqual(reasons(decisions), [.goal, .speechBusy])
        // Still walking toward the seat: the offer waits rather than interrupting the goal.
        XCTAssertEqual(reasons(engine.decide([roomOffer("cafe", at: 12)], moment: CompanionMoment(now: 12, goalActive: true, activity: .moving),
                                             settings: CompanionSettings())), [.goalInProgress])
        // Seated and waiting for coffee: now the first-visit offer is the right moment.
        guard case .offer = engine.decide([roomOffer("cafe", at: 20)], moment: CompanionMoment(now: 20, activity: .stationary),
                                          settings: CompanionSettings()).first else { return XCTFail("expected the offer once seated") }
    }

    // OFF-06: a hazard interrupts an offer; the offer is cleared without counting as a decline.
    func testHazardInterruptsOfferAndQuietMode() {
        var engine = CompanionAttention(), settings = CompanionSettings()
        engine.enterRoom("lounge", established: true)
        _ = engine.decide([roomOffer("lounge")], moment: CompanionMoment(now: 0), settings: settings)
        XCTAssertNotNil(engine.pendingOffer)
        settings.quiet = true; settings.wordsPerMinute = 1
        let decisions = engine.decide([item("box", .hazard, words: 5, at: 1, ttl: 1), item("lounge:art", .discovery, at: 1)],
                                      moment: CompanionMoment(now: 1, speaking: .information), settings: settings)
        XCTAssertEqual(reasons(decisions), [.hazard, .quiet])
        XCTAssertNil(engine.pendingOffer)
        XCTAssertTrue(engine.memory.declineCounts.isEmpty)
        XCTAssertEqual(reasons(engine.decide([item("lounge:art", .discovery, at: 30)], moment: CompanionMoment(now: 30), settings: settings)), [.quiet])
        XCTAssertEqual(reasons(engine.decide([item("stale", .hazard, at: 0, ttl: 0.5)], moment: CompanionMoment(now: 31), settings: settings)), [.expired])
    }

    // OFF-07: a routine suggestion is offered at most once and is not offered while en route.
    func testRoutineSuggestionOfferedOnce() {
        var engine = CompanionAttention()
        let outfit = item("routine:outfit:morning", .offer, words: 6, ttl: 20, offer: .suggestion)
        XCTAssertEqual(reasons(engine.decide([outfit], moment: CompanionMoment(now: 0, goalActive: true, activity: .moving),
                                             settings: CompanionSettings())), [.goalInProgress])
        guard case .offer = engine.decide([outfit], moment: CompanionMoment(now: 1, activity: .stationary), settings: CompanionSettings()).first
        else { return XCTFail("expected one suggestion") }
        engine.answerOffer(.no)
        XCTAssertEqual(reasons(engine.decide([outfit], moment: CompanionMoment(now: 15), settings: CompanionSettings())), [.declined])
    }

    // OFF-08: a requested item location is answered even when its category is muted.
    func testRequestedItemAnsweredDespiteMutedCategory() {
        var preferences = AssistantPreferences(); preferences.setMode("muted", for: "objects")
        let settings = CompanionSettings(preferences: preferences)
        var engine = CompanionAttention()
        let unsolicited = item("braille-book:seen", .discovery, category: "objects")
        let asked = item("braille-book:where", .answer, words: 14, category: "objects", requested: true)
        XCTAssertEqual(reasons(engine.decide([unsolicited], moment: CompanionMoment(now: 0), settings: settings)), [.muted])
        XCTAssertEqual(reasons(engine.decide([asked], moment: CompanionMoment(now: 1), settings: settings)), [.requested])
        // Asking again repeats it.
        XCTAssertEqual(reasons(engine.decide([asked], moment: CompanionMoment(now: 2), settings: settings)), [.requested])
    }

    func testBudgetAndFrequencyApplyToOrdinaryInformationOnly() {
        var engine = CompanionAttention()
        let settings = CompanionSettings(minimumGap: 10, wordsPerMinute: 20)
        XCTAssertEqual(reasons(engine.decide([item("a", .social, words: 15, at: 0)], moment: CompanionMoment(now: 0), settings: settings)), [.information])
        XCTAssertEqual(reasons(engine.decide([item("b", .social, words: 4, at: 5)], moment: CompanionMoment(now: 5), settings: settings)), [.tooSoon])
        XCTAssertEqual(reasons(engine.decide([item("c", .social, words: 10, at: 12)], moment: CompanionMoment(now: 12), settings: settings)), [.budget])
        XCTAssertEqual(reasons(engine.decide([item("a", .social, words: 15, at: 70)], moment: CompanionMoment(now: 70), settings: settings)), [.alreadySaid])
        XCTAssertEqual(reasons(engine.decide([item("a", .social, words: 15, at: 71, revision: "2")], moment: CompanionMoment(now: 71), settings: settings)), [.information])
        // Mobility is not limited by the ordinary budget, but the same cue is not repeated.
        let turn = item("route:turn-left", .mobility, words: 30, at: 72)
        XCTAssertEqual(reasons(engine.decide([turn], moment: CompanionMoment(now: 72, speaking: .information), settings: settings)), [.mobility])
        XCTAssertEqual(reasons(engine.decide([turn], moment: CompanionMoment(now: 73), settings: settings)), [.alreadySaid])
        XCTAssertEqual(reasons(engine.decide([item("route:door", .mobility, at: 74)], moment: CompanionMoment(now: 74, speaking: .danger), settings: settings)), [.speechBusy])
    }

    // OUT-01 decision steps: familiar home is silent while goals move; the cafe is described when seated.
    func testFamilyCafeOutingDecisionSteps() {
        var memory = CompanionMemory()
        for room in ["bedroom", "hallway", "front-door"] { memory.rooms[room] = RoomRecord(); memory.rooms[room]?.visits = 100 }
        var engine = CompanionAttention(memory: memory)
        let settings = CompanionSettings(wordsPerMinute: 400)
        let walking = { (t: Double) in CompanionMoment(now: t, goalActive: true, activity: .moving) }
        // 1–3: bedroom to closet to front door; familiar rooms give no tour, route cues do.
        engine.enterRoom("bedroom", established: true)
        XCTAssertEqual(reasons(engine.decide([roomOffer("bedroom"), item("closet:route", .mobility, at: 0)], moment: walking(0), settings: settings)),
                       [.mobility, .familiarRoom])
        XCTAssertEqual(reasons(engine.decide([roomOffer("bedroom", at: 3)], moment: walking(3), settings: settings)), [.familiarRoom])
        XCTAssertEqual(reasons(engine.decide([item("outfit:options", .answer, words: 50, at: 5, requested: true)],
                                             moment: CompanionMoment(now: 5, goalActive: true, activity: .stationary), settings: settings)), [.requested])
        engine.enterRoom("hallway", established: true)
        XCTAssertEqual(reasons(engine.decide([item("hall:shoes", .hazard, words: 4, at: 20, ttl: 1), roomOffer("hallway", at: 20)],
                                             moment: walking(20), settings: settings)), [.hazard, .familiarRoom])
        // 4–5: steps outside and the cafe door are mobility, not narration.
        XCTAssertEqual(reasons(engine.decide([item("porch:steps", .mobility, at: 30)], moment: walking(30), settings: settings)), [.mobility])
        engine.enterRoom("cafe", established: true)
        XCTAssertEqual(reasons(engine.decide([item("cafe:door", .mobility, at: 400), roomOffer("cafe", at: 400)], moment: walking(400), settings: settings)),
                       [.mobility, .speechBusy])
        // 6: seated, waiting for coffee — the new place is offered.
        guard case .offer = engine.decide([roomOffer("cafe", at: 420)], moment: CompanionMoment(now: 420, activity: .stationary), settings: settings).first
        else { return XCTFail("expected the cafe offer when seated") }
        XCTAssertNotNil(engine.answerOffer(.yes))
        // 7: talking with family — quiet; a hazard still gets through.
        var quiet = settings; quiet.quiet = true
        XCTAssertEqual(reasons(engine.decide([item("cafe:music", .discovery, at: 450), item("chair:behind", .hazard, at: 450, ttl: 1)],
                                             moment: CompanionMoment(now: 450, activity: .stationary), settings: quiet)), [.hazard, .quiet])
        XCTAssertEqual(reasons(engine.decide([item("cafe:music", .discovery, at: 460)], moment: CompanionMoment(now: 460), settings: quiet)), [.quiet])
        // 8–9: bathroom question is answered even in quiet mode; route back is mobility.
        XCTAssertEqual(reasons(engine.decide([item("bathroom:where", .answer, words: 25, at: 470, requested: true)],
                                             moment: CompanionMoment(now: 470), settings: quiet)), [.requested])
        XCTAssertEqual(reasons(engine.decide([item("table:route", .mobility, at: 500)], moment: walking(500), settings: quiet)), [.mobility])
        // 11–12: home again — familiar rooms stay silent while heading to the bedroom.
        engine.enterRoom("bedroom", established: true)
        XCTAssertEqual(reasons(engine.decide([roomOffer("bedroom", at: 900)], moment: walking(900), settings: settings)), [.familiarRoom])
    }

    // FR-19 scenarios from the independent review.
    func testDescribeModeOnRequestCategoryOfferFirstAndInvalidInputs() {
        var engine = CompanionAttention()
        engine.enterRoom("den", established: true)
        let description = item("room:den:description", .roomDescription, words: 30, room: "den")
        XCTAssertEqual(reasons(engine.decide([description], moment: CompanionMoment(now: 0), settings: CompanionSettings())), [.offerFirst])
        XCTAssertEqual(reasons(engine.decide([description], moment: CompanionMoment(now: 1),
                                             settings: CompanionSettings(firstVisitRooms: .describe))), [.firstVisit])
        var preferences = AssistantPreferences(); preferences.setMode("onRequest", for: "decor")
        XCTAssertEqual(reasons(engine.decide([item("den:art", .discovery, at: 20, category: "decor")], moment: CompanionMoment(now: 20),
                                             settings: CompanionSettings(preferences: preferences))), [.onRequestOnly])
        XCTAssertEqual(reasons(engine.decide([item("", .discovery, at: 30), item("zero", .discovery, words: 0, at: 30),
                                              item("no-room", .roomDescription, at: 30)],
                                             moment: CompanionMoment(now: 30), settings: CompanionSettings())), [.invalid, .invalid, .invalid])
    }

    func testItemDirectionsOfferAndSilenceIsNotAHabit() {
        var engine = CompanionAttention()
        var time = 0.0
        for _ in 0..<3 {
            let offer = item("item:braille-book:\(time)", .offer, words: 8, at: time, offer: .itemDirections)
            guard case .offer(let made, _) = engine.decide([offer], moment: CompanionMoment(now: time), settings: CompanionSettings()).first
            else { return XCTFail("expected an item offer") }
            XCTAssertEqual(made.kind, .itemDirections)
            XCTAssertEqual(made.expiresAt, time + 8, "the answer window starts when the offer is spoken")
            engine.answerOffer(.silence)
            time += 30
        }
        XCTAssertTrue(engine.memory.hints.isEmpty, "silence is not a preference")
        XCTAssertTrue(engine.memory.declineCounts.isEmpty)
    }

    func testRoomChangeWithdrawsOfferWithoutDecline() {
        var engine = CompanionAttention()
        engine.enterRoom("hall", established: true)
        _ = engine.decide([roomOffer("hall")], moment: CompanionMoment(now: 0), settings: CompanionSettings())
        XCTAssertNotNil(engine.pendingOffer)
        engine.enterRoom("kitchen", established: true)
        XCTAssertNil(engine.pendingOffer)
        XCTAssertTrue(engine.memory.declineCounts.isEmpty)
        // Not declined this session either: coming back can offer again while it is still a first visit.
        XCTAssertEqual(engine.memory.rooms["hall"]?.visits, 1)
    }

    func testDoorwayFlickerAndBriefTrackingLossDoNotInflateVisits() {
        var engine = CompanionAttention()
        XCTAssertNil(engine.observeRoom("bedroom", established: true, now: 0))
        XCTAssertEqual(engine.observeRoom("bedroom", established: true, now: 2.5), .firstVisit)
        // Flicker into the hall for under the settle time, then back.
        for (time, room) in [(3.0, "hall"), (3.4, "bedroom"), (3.8, "hall"), (4.1, "bedroom")] {
            XCTAssertNil(engine.observeRoom(room, established: true, now: time))
        }
        XCTAssertNil(engine.memory.rooms["hall"])
        XCTAssertEqual(engine.memory.rooms["bedroom"]?.visits, 1)
        // Tracking blip, then the same room again: the visit continues.
        XCTAssertNil(engine.observeRoom(nil, established: false, now: 5))
        XCTAssertNil(engine.currentRoom)
        XCTAssertNil(engine.observeRoom("bedroom", established: true, now: 6))
        XCTAssertEqual(engine.observeRoom("bedroom", established: true, now: 8.5), .firstVisit)
        XCTAssertEqual(engine.memory.rooms["bedroom"]?.visits, 1)
    }

    func testRestoredHintSuppressesOffersAndOfferWordsUseBudget() throws {
        var engine = CompanionAttention(), time = 0.0
        for room in ["a", "b", "c"] {
            engine.enterRoom(room, established: true)
            _ = engine.decide([roomOffer(room, at: time)], moment: CompanionMoment(now: time), settings: CompanionSettings())
            engine.answerOffer(.no); time += 30
        }
        let restored = try JSONDecoder().decode(CompanionMemory.self, from: JSONEncoder().encode(engine.memory))
        var next = CompanionAttention(memory: restored)
        next.enterRoom("d", established: true)
        XCTAssertEqual(reasons(next.decide([roomOffer("d")], moment: CompanionMoment(now: 0), settings: CompanionSettings())), [.declined])
        // A 7-word offer leaves 3 words of a 10-word minute.
        var tight = CompanionAttention()
        tight.enterRoom("e", established: true)
        let settings = CompanionSettings(minimumGap: 0, wordsPerMinute: 10)
        guard case .offer = tight.decide([roomOffer("e")], moment: CompanionMoment(now: 0), settings: settings).first
        else { return XCTFail("expected the offer") }
        tight.answerOffer(.yes)
        XCTAssertEqual(reasons(tight.decide([item("e:art", .discovery, words: 4, at: 1)], moment: CompanionMoment(now: 1), settings: settings)), [.budget])
        // A clock that goes backwards grants no new allowance.
        XCTAssertEqual(reasons(tight.decide([item("e:lamp", .discovery, words: 1, at: 0.5)], moment: CompanionMoment(now: 0.5), settings: settings)), [.budget])
    }

    func testReleaseAllowsAnUnspokenItemAgain() {
        var engine = CompanionAttention()
        let note = item("hall:coat", .discovery, at: 0)
        XCTAssertEqual(reasons(engine.decide([note], moment: CompanionMoment(now: 0), settings: CompanionSettings())), [.information])
        engine.release("hall:coat")
        XCTAssertEqual(reasons(engine.decide([item("hall:coat", .discovery, at: 20)], moment: CompanionMoment(now: 20), settings: CompanionSettings())), [.information])
    }

    // Guide-style word limits: fewer words the faster the person walks toward a goal.
    func testGuidanceWordsShrinkWithWalkingSpeed() {
        XCTAssertEqual(AttentionPolicy.guidanceWords(speed: 1.3, goalActive: true, standardLimit: 55), 3)
        XCTAssertEqual(AttentionPolicy.guidanceWords(speed: 0.8, goalActive: true, standardLimit: 55), 6)
        XCTAssertEqual(AttentionPolicy.guidanceWords(speed: 0.3, goalActive: true, standardLimit: 55), 12)
        XCTAssertEqual(AttentionPolicy.guidanceWords(speed: 0.05, goalActive: true, standardLimit: 55), 55)
        XCTAssertEqual(AttentionPolicy.guidanceWords(speed: 1.3, goalActive: false, standardLimit: 55), 55)
        XCTAssertEqual(AttentionPolicy.guidanceWords(speed: .nan, goalActive: true, standardLimit: 25), 25)
        XCTAssertEqual(AttentionPolicy.guidanceWords(speed: 0.3, goalActive: true, standardLimit: 8), 8)
    }

    func testMemoryRoundTripKeepsRoomsAndHintsButNoSessionState() throws {
        var engine = CompanionAttention()
        for (index, room) in ["a", "b", "c"].enumerated() {
            let time = Double(index) * 30
            engine.enterRoom(room, established: true)
            _ = engine.decide([roomOffer(room, at: time)], moment: CompanionMoment(now: time), settings: CompanionSettings())
            engine.answerOffer(.silence)
        }
        let data = try JSONEncoder().encode(engine.memory)
        let restored = try JSONDecoder().decode(CompanionMemory.self, from: data)
        XCTAssertEqual(restored, engine.memory)
        var next = CompanionAttention(memory: restored)
        XCTAssertNil(next.currentRoom)
        XCTAssertNil(next.pendingOffer)
        XCTAssertEqual(next.enterRoom("a", established: true), .familiar)
    }
}
