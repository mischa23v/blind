import XCTest
@testable import BlindCore

/// FR-05 / V08 coarse familiar-room change detection. Synthetic snapshots only: these check the
/// comparison and wording rules, not real camera recognition or localisation.
final class SceneChangeDetectorTests: XCTestCase {
    private func snap(_ people: Int, _ texts: [String] = [], obstacle: Bool = false,
                      room: String = "kitchen", sector: Int = 0, at time: Double) -> SceneSnapshot {
        SceneSnapshot(room: room, viewSector: sector, peopleCount: people, texts: texts,
                      obstacleInUsualPath: obstacle, at: time)
    }

    func testFirstVisitOnlyLearnsTheBaseline() {
        var detector = SceneChangeDetector()
        XCTAssertEqual(detector.observe(snap(2, ["Exit", "Kitchen menu"], obstacle: true, at: 0)), [])
        // The same scene again is not a change.
        XCTAssertEqual(detector.observe(snap(2, ["exit", "KITCHEN  MENU"], obstacle: true, at: 1)), [])
    }

    func testArrivalIsConfirmedOnlyAfterThreeSnapshotsAndReportedOnce() {
        var detector = SceneChangeDetector()
        XCTAssertEqual(detector.observe(snap(0, at: 0)), [])
        XCTAssertEqual(detector.observe(snap(1, at: 1)), [])
        XCTAssertEqual(detector.observe(snap(1, at: 2)), [])
        XCTAssertEqual(detector.observe(snap(1, at: 3)), [.peopleArrived(1)])
        XCTAssertEqual(detector.observe(snap(1, at: 4)), [])
        XCTAssertEqual(detector.observe(snap(1, at: 5)), [])
    }

    func testSingleNoisyFrameNeverSpeaks() {
        var detector = SceneChangeDetector()
        XCTAssertEqual(detector.observe(snap(0, at: 0)), [])
        XCTAssertEqual(detector.observe(snap(1, ["Fire door"], obstacle: true, at: 1)), [])
        for time in 2...6 {
            XCTAssertEqual(detector.observe(snap(0, at: Double(time))), [])
        }
        // A count that keeps changing never settles into a claim either.
        XCTAssertEqual(detector.observe(snap(1, at: 7)), [])
        XCTAssertEqual(detector.observe(snap(2, at: 8)), [])
        XCTAssertEqual(detector.observe(snap(1, at: 9)), [])
    }

    func testLongGapBetweenSnapshotsRestartsTheStreak() {
        var detector = SceneChangeDetector()
        XCTAssertEqual(detector.observe(snap(0, at: 0)), [])
        XCTAssertEqual(detector.observe(snap(1, at: 1)), [])
        XCTAssertEqual(detector.observe(snap(1, at: 2)), [])
        XCTAssertEqual(detector.observe(snap(1, at: 30)), [])
        XCTAssertEqual(detector.observe(snap(1, at: 31)), [])
        XCTAssertEqual(detector.observe(snap(1, at: 32)), [.peopleArrived(1)])
    }

    func testDifferentViewSectorOrRoomIsNotCompared() {
        var detector = SceneChangeDetector()
        XCTAssertEqual(detector.observe(snap(0, sector: 0, at: 0)), [])
        // Turning to another sector shows other people; that is a different view, not an arrival.
        for time in 1...4 {
            XCTAssertEqual(detector.observe(snap(3, ["Pantry"], sector: 4, at: Double(time))), [])
        }
        for time in 5...8 {
            XCTAssertEqual(detector.observe(snap(2, room: "hall", sector: 0, at: Double(time))), [])
        }
        // The original view is unchanged.
        for time in 9...12 {
            XCTAssertEqual(detector.observe(snap(0, sector: 0, at: Double(time))), [])
        }
    }

    func testPeopleNoLongerInViewWording() {
        var detector = SceneChangeDetector()
        XCTAssertEqual(detector.observe(snap(2, at: 0)), [])
        _ = detector.observe(snap(1, at: 1)); _ = detector.observe(snap(1, at: 2))
        let changes = detector.observe(snap(1, at: 3))
        XCTAssertEqual(changes, [.peopleNoLongerInView(1)])
        let english = detector.candidates(for: changes, room: "kitchen", at: 3, arabic: false)
        XCTAssertEqual(english.count, 1)
        XCTAssertEqual(english.first?.text, "One person is no longer in view.")
        XCTAssertEqual(english.first?.key, "change:kitchen:peopleNoLongerInView:1")
        XCTAssertEqual(english.first?.category, "social")
        XCTAssertEqual(english.first?.words, 7)
        XCTAssertFalse(english.first?.text.lowercased().contains("left") ?? true)
        let several = detector.candidates(for: [.peopleNoLongerInView(2)], room: "kitchen", at: 3, arabic: false)
        XCTAssertEqual(several.first?.text, "2 people are no longer in view.")
    }

    func testNewSignIsNormalisedAndReportedOnce() {
        var detector = SceneChangeDetector()
        XCTAssertEqual(detector.observe(snap(0, ["Exit"], at: 0)), [])
        let frame = ["EXIT", "  Café   Menu ", "ok"]
        XCTAssertEqual(detector.observe(snap(0, frame, at: 1)), [])
        XCTAssertEqual(detector.observe(snap(0, frame, at: 2)), [])
        let changes = detector.observe(snap(0, frame, at: 3))
        XCTAssertEqual(changes, [.newText("Café Menu")])
        // Case, spacing and accent variations of a known sign are not new.
        XCTAssertEqual(detector.observe(snap(0, ["cafe menu", "exit"], at: 4)), [])
        XCTAssertEqual(detector.observe(snap(0, ["CAFE MENU"], at: 5)), [])
        XCTAssertEqual(detector.observe(snap(0, ["Cafe  menu"], at: 6)), [])
        // A sign missing from view is not reported as removed.
        XCTAssertEqual(detector.observe(snap(0, at: 7)), [])
        XCTAssertEqual(detector.observe(snap(0, at: 8)), [])
        XCTAssertEqual(detector.observe(snap(0, at: 9)), [])

        let first = detector.candidates(for: changes, room: "kitchen", at: 3, arabic: false)
        let again = detector.candidates(for: changes, room: "kitchen", at: 3, arabic: false)
        XCTAssertEqual(first.first?.text, "New sign: Café Menu.")
        XCTAssertEqual(first.first?.key, "change:kitchen:newText:cafe menu")
        XCTAssertEqual(first.first?.category, "signs")
        XCTAssertEqual(first.first?.kind, .change)
        XCTAssertEqual(first.first?.revision, again.first?.revision)
        XCTAssertTrue(first.first?.revision.contains("cafe menu") ?? false)

        // Delivered once through attention, the same candidate is not said again.
        var attention = CompanionAttention()
        let moment = CompanionMoment(now: 3, activity: .stationary)
        XCTAssertEqual(attention.decide(first, moment: moment, settings: CompanionSettings()).map(\.reason), [.change])
        let later = CompanionMoment(now: 12, activity: .stationary)
        XCTAssertEqual(attention.decide(again, moment: later, settings: CompanionSettings()).map(\.reason), [.alreadySaid])
    }

    func testObstacleCandidateIsGoalRelevantWithoutDistanceOrDirection() {
        var detector = SceneChangeDetector()
        XCTAssertEqual(detector.observe(snap(0, at: 0)), [])
        _ = detector.observe(snap(0, obstacle: true, at: 1)); _ = detector.observe(snap(0, obstacle: true, at: 2))
        let changes = detector.observe(snap(0, obstacle: true, at: 3))
        XCTAssertEqual(changes, [.obstacleInUsualPath])
        XCTAssertEqual(detector.observe(snap(0, obstacle: true, at: 4)), [])

        for arabic in [false, true] {
            guard let item = detector.candidates(for: changes, room: "kitchen", at: 3, arabic: arabic).first else {
                return XCTFail("expected an obstacle candidate")
            }
            XCTAssertTrue(item.goalRelevant)
            XCTAssertNil(item.category)
            XCTAssertEqual(item.kind, .change)
            XCTAssertEqual(item.expiresAt, 13)
            XCTAssertEqual(item.room, "kitchen")
            XCTAssertEqual(item.words, item.text.split(whereSeparator: { $0.isWhitespace }).count)
            XCTAssertNil(item.text.rangeOfCharacter(from: .decimalDigits))
            let lowered = item.text.lowercased()
            for word in ["metre", "meter", "feet", "foot", "step", "left", "right", "ahead", "behind", "clear",
                         "متر", "خطو", "يمين", "يسار", "أمام", "امام", "خلف"] {
                XCTAssertFalse(lowered.contains(word), "\(word) in \(item.text)")
            }
        }
        let english = detector.candidates(for: changes, room: "kitchen", at: 3, arabic: false)
        XCTAssertEqual(english.first?.text, "Something is in your usual path.")

        // Goal-relevant: said while walking toward a goal.
        var attention = CompanionAttention()
        let moment = CompanionMoment(now: 3, goalActive: true, activity: .moving)
        XCTAssertEqual(attention.decide(english, moment: moment, settings: CompanionSettings()).map(\.reason), [.goal])
    }

    func testObstacleThatReturnsLaterGetsANewRevision() {
        var detector = SceneChangeDetector()
        _ = detector.observe(snap(0, at: 0))
        var first: [DetectedChange] = []
        for time in 1...3 { first = detector.observe(snap(0, obstacle: true, at: Double(time))) }
        XCTAssertEqual(first, [.obstacleInUsualPath])
        let firstRevision = detector.candidates(for: first, room: "kitchen", at: 3, arabic: false).first?.revision
        // Its absence settles silently; nothing is said about a clear path.
        for time in 4...6 { XCTAssertEqual(detector.observe(snap(0, at: Double(time))), []) }
        var second: [DetectedChange] = []
        for time in 7...9 { second = detector.observe(snap(0, obstacle: true, at: Double(time))) }
        XCTAssertEqual(second, [.obstacleInUsualPath])
        let secondRevision = detector.candidates(for: second, room: "kitchen", at: 9, arabic: false).first?.revision
        XCTAssertNotNil(firstRevision)
        XCTAssertNotEqual(firstRevision, secondRevision)
    }

    func testArabicPhrasesArePresent() {
        let detector = SceneChangeDetector()
        let changes: [DetectedChange] = [.peopleArrived(1), .peopleArrived(3), .peopleNoLongerInView(1),
                                         .newText("مخرج الطوارئ"), .obstacleInUsualPath]
        let items = detector.candidates(for: changes, room: "kitchen", at: 0, arabic: true)
        XCTAssertEqual(items.count, changes.count)
        XCTAssertEqual(items.map(\.text), ["يوجد شخص جديد هنا.",
                                           "عدد الأشخاص الجدد هنا: 3.",
                                           "شخص واحد لم يعد في مجال الرؤية.",
                                           "لافتة جديدة: «مخرج الطوارئ».",
                                           "يوجد شيء في مسارك المعتاد."])
        for item in items {
            XCTAssertGreaterThan(item.words, 0)
            XCTAssertEqual(item.words, item.text.split(whereSeparator: { $0.isWhitespace }).count)
        }
        let english = detector.candidates(for: [.peopleArrived(1)], room: "kitchen", at: 0, arabic: false)
        XCTAssertEqual(english.first?.text, "Someone new is here.")
    }

    func testInvalidSnapshotsAreIgnored() {
        var detector = SceneChangeDetector()
        XCTAssertEqual(detector.observe(snap(0, room: "  ", at: 0)), [])
        XCTAssertEqual(detector.observe(snap(-1, at: 0)), [])
        XCTAssertEqual(detector.observe(snap(0, at: .nan)), [])
        XCTAssertEqual(detector.candidates(for: [.obstacleInUsualPath], room: "", at: 0, arabic: false), [])
        XCTAssertEqual(detector.candidates(for: [.obstacleInUsualPath], room: "kitchen", at: .infinity, arabic: false), [])
    }
}
