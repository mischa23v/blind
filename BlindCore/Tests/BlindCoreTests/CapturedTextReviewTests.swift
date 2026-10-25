import XCTest
@testable import BlindCore

final class CapturedTextReviewTests: XCTestCase {
    let fixtures = CapturedTextReferenceFixtures()
    func installed(arabic: Bool = false) -> CapturedTextReference {
        var v = CapturedTextReference(); let selected = fixtures.selection(&v)
        let text = (1...70).map { arabic ? "كلمة\($0)" : "word\($0)" }.joined(separator: " ")
        XCTAssertTrue(v.install(fixtures.source(selected, text: text), for: selected, now: 100.1, arabic: arabic))
        return v
    }
    func context(_ v: CapturedTextReference, now: Double = 100.2) -> CapturedTextReference.Context {
        .init(selection: v.selection!, source: v.source?.identity, cameraEpoch: v.selection!.cameraEpoch,
              generation: v.selection!.generation, requestID: v.selection!.requestID, now: now)
    }
    @discardableResult func complete(_ v: inout CapturedTextReference) -> CapturedTextReference.Phrase {
        let p = v.next(context(v))!; XCTAssertTrue(v.begin(p, context: context(v)))
        XCTAssertTrue(v.finish(id: p.id, text: p.text, outcome: .completed, context: context(v)))
        return p
    }
    func testUnstartedAdmissionCannotBeRepeatedAsHeard() {
        var v = installed(); let p = v.next(context(v))!; XCTAssertTrue(v.begin(p, context: context(v)))
        XCTAssertNil(v.lastSpokenPart)
        XCTAssertFalse(v.review(.repeatPart, requestID: UUID(), context: context(v)))
        XCTAssertEqual(v.pending, p); XCTAssertNil(v.lastSpokenPart)
        XCTAssertFalse(v.started(id: UUID(), text: p.text, context: context(v)))
        XCTAssertFalse(v.started(id: p.id, text: p.text + " changed", context: context(v)))
        XCTAssertNil(v.lastSpokenPart)
    }
    func testInterruptedStartedPhraseRehearsWithNewIdentityAndNoAutoResume() {
        var v = installed(); let p = v.next(context(v))!; XCTAssertTrue(v.begin(p, context: context(v)))
        XCTAssertTrue(v.started(id: p.id, text: p.text, context: context(v)))
        XCTAssertFalse(v.finish(id: p.id, text: p.text, outcome: .interrupted, context: context(v)))
        XCTAssertNil(v.next(context(v))); XCTAssertEqual(v.completed, 0)
        let oldContext = context(v)
        let prior = v.playbackReceipt!, source = v.source!.identity, selection = v.selection!
        XCTAssertTrue(v.review(.repeatPart, requestID: UUID(), context: context(v)))
        XCTAssertEqual(v.source!.identity, source); XCTAssertNotEqual(v.selection!.id, selection.id)
        XCTAssertNotEqual(v.selection!.requestID, prior.requestID)
        let replay = v.next(context(v))!; XCTAssertEqual(replay.text, p.text); XCTAssertNotEqual(replay.id, p.id)
        XCTAssertTrue(v.begin(replay, context: context(v)))
        XCTAssertFalse(v.started(id: p.id, text: p.text, context: oldContext))
        XCTAssertFalse(v.finish(id: p.id, text: p.text, outcome: .completed, context: oldContext))
        XCTAssertFalse(v.withdrawn)
        XCTAssertFalse(v.finish(id: p.id, text: p.text, outcome: .completed, context: context(v)))
        XCTAssertEqual(v.completed, 0)
        XCTAssertTrue(v.finish(id: replay.id, text: replay.text, outcome: .completed, context: context(v)))
        XCTAssertEqual(v.playbackReceipt!.outcome, .completed); XCTAssertEqual(prior.outcome, .cancelled)
    }
    func testNoOnsetFallsBackToCompletedNotQueuedNext() {
        var v = installed(); let first = complete(&v)
        let queued = v.next(context(v))!; XCTAssertTrue(v.begin(queued, context: context(v)))
        XCTAssertTrue(v.review(.repeatPart, requestID: UUID(), context: context(v)))
        XCTAssertEqual(v.next(context(v))!.originalSlice, first.originalSlice)
        XCTAssertNotEqual(v.next(context(v))!.originalSlice, queued.originalSlice)
    }
    func testCompletedSourceCanRepeatNavigateAndRereadAfterLongWait() {
        for arabic in [false,true] {
            var v = installed(arabic: arabic); let original = v.phrases.map(\.originalSlice)
            while v.next(context(v)) != nil { complete(&v) }
            let receipt = v.playbackReceipt!; XCTAssertEqual(receipt.outcome, .completed)
            XCTAssertTrue(v.review(.previousPart, requestID: UUID(), context: context(v, now: 9000)))
            var now = context(v, now: 9000)
            let p = v.next(now)!; XCTAssertEqual(p.originalSlice, original[original.count-2])
            XCTAssertTrue(v.begin(p, context: now)); XCTAssertTrue(v.finish(id: p.id, text: p.text, outcome: .completed, context: now))
            XCTAssertTrue(v.review(.nextPart, requestID: UUID(), context: now))
            now = context(v, now: 9000)
            XCTAssertEqual(v.next(now)!.originalSlice, original.last)
            XCTAssertTrue(v.review(.readAgain, requestID: UUID(), context: now))
            XCTAssertEqual(v.phrases.map(\.originalSlice), original)
            XCTAssertEqual(v.completed, 0); XCTAssertEqual(receipt.completedPhraseCount, original.count)
            XCTAssertTrue(v.phrases.allSatisfy { CompanionReferenceReading.wordCount($0.text) <= 30 })
        }
    }
    func testRepeatedCommandsBeforeStartDoNotWalkThroughUnheardParts() {
        var v = installed(); _ = complete(&v)
        XCTAssertFalse(v.review(.previousPart, requestID: UUID(), context: context(v)))
        XCTAssertTrue(v.review(.nextPart, requestID: UUID(), context: context(v)))
        let p = v.next(context(v))!
        XCTAssertTrue(v.review(.nextPart, requestID: UUID(), context: context(v)))
        XCTAssertEqual(v.next(context(v))!.originalSlice, p.originalSlice)
        XCTAssertNotEqual(v.next(context(v))!.id, p.id)
    }
    func testHazardPrivacySessionSourceAndRequestCannotBeRevivedByReview() {
        for mode in 0..<7 {
            var v = installed(); _ = complete(&v)
            let c = context(v)
            let bad = CapturedTextReference.Context(selection: c.selection, source: mode == 0 ? nil : c.source,
                cameraEpoch: mode == 1 ? UUID() : c.cameraEpoch, generation: mode == 2 ? 44 : c.generation,
                requestID: mode == 3 ? UUID() : c.requestID, now: c.now, foreground: mode != 4,
                hazard: mode == 5, privateAudioHeld: mode == 6)
            XCTAssertFalse(v.review(.readAgain, requestID: UUID(), context: bad))
            XCTAssertFalse(v.review(.readAgain, requestID: UUID(), context: c)); XCTAssertNil(v.next(c))
            v.clear(); XCTAssertNil(v.source); XCTAssertNil(v.lastSpokenPart); XCTAssertTrue(v.phrases.isEmpty)
        }
    }
    func testForgetAndReplacementRemoveOldCursorAndCallbackOwnership() {
        var v = installed(); let old = complete(&v); v.clear()
        let selected = fixtures.selection(&v)
        XCTAssertTrue(v.install(fixtures.source(selected,text:"Replacement page."), for: selected, now: 100.1))
        XCTAssertNil(v.lastSpokenPart)
        XCTAssertFalse(v.review(.repeatPart, requestID: UUID(), context: context(v)))
        let p = v.next(context(v))!; XCTAssertTrue(v.begin(p, context: context(v)))
        XCTAssertFalse(v.started(id: old.id, text: old.text, context: context(v)))
        XCTAssertFalse(v.finish(id: old.id, text: old.text, outcome: .completed, context: context(v)))
        XCTAssertEqual(v.completed,0)
    }
}
