import Foundation
import XCTest
@testable import BlindCore

final class ConnectedJourneyFailureTests: XCTestCase {
    typealias F = ConnectedFixture
    enum Failure: Error { case disk }
    func ambiguous() throws -> ConnectedJourneyCoordinator {
        var value = try F.prepared()
        try F.begin(&value, F.endpoint(F.c,"p"), time: 2)
        try value.saveReference(at: F.endpoint(F.c,"p"), origin: .trustedInterface, now: 2, recordedAt: F.date, persist: { _ in })
        return value
    }
    func testInterruptedUnknownWrongPromptAndWrongDestinationCannotAuthorizeClarification() throws {
        for outcome in [NarrationDelivery.interrupted, .unknown] {
            var value = try ambiguous()
            guard case .clarify(let question) = try value.requestReturn(origin: .trustedInterface, recordedAt: F.date, persist: { _ in }) else { return XCTFail() }
            XCTAssertThrowsError(try F.deliver(&value, question, outcome: outcome, now: 2))
            XCTAssertNil(value.snapshot.goal); XCTAssertTrue(value.snapshot.returnClarificationPending)
        }
        for wrongText in [false, true] {
            var value = try ambiguous(), ledger = SpeechDeliveryLedger()
            guard case .clarify(let question) = try value.requestReturn(origin: .trustedInterface, recordedAt: F.date, persist: { _ in }) else { return XCTFail() }
            let attempt = try XCTUnwrap(ledger.begin(text: wrongText ? "model invented question" : question.text,
                priority: .information, destination: .requested(wrongText ? question.id : UUID()), transport: .synthesized))
            let completion = try XCTUnwrap(ledger.finish(token: attempt.token, outcome: .completed, now: 2))
            XCTAssertThrowsError(try value.recordClarificationDelivery(completion, now: 2))
        }
    }
    func testClarificationIsOneUseAndRejectsUnverifiedSpeechAndStaleNewGoal() throws {
        var value = try ambiguous()
        guard case .clarify(let question) = try value.requestReturn(origin: .trustedInterface, recordedAt: F.date, persist: { _ in }) else { return XCTFail() }
        let receipt = try F.deliver(&value, question, now: 2)
        XCTAssertThrowsError(try value.resolveReturn(.journeyStart, receipt: receipt, origin: .unverifiedMicrophone, now: 2, recordedAt: F.date, persist: { _ in }))
        // Camera frames do not erase a delivered semantic question about fixed anchors.
        try F.observe(&value, F.endpoint(F.c,"p"), time: 2.1)
        try value.resolveReturn(.journeyStart, receipt: receipt, origin: .trustedInterface, now: 2.1, recordedAt: F.date, persist: { _ in })
        XCTAssertThrowsError(try value.resolveReturn(.savedReference, receipt: receipt, origin: .trustedInterface, now: 2.1, recordedAt: F.date, persist: { _ in }))
        guard case .clarify(let later) = try value.requestReturn(origin: .trustedInterface, recordedAt: F.date, persist: { _ in }) else { return XCTFail() }
        let old = try F.deliver(&value, later, now: 2.1)
        try value.setDestination(F.endpoint(F.b,"p"), origin: .trustedInterface, recordedAt: F.date, persist: { _ in })
        XCTAssertThrowsError(try value.resolveReturn(.journeyStart, receipt: old, origin: .trustedInterface, now: 2.1, recordedAt: F.date, persist: { _ in }))
    }
    func testArabicQuestionExactDeliveryAndExpiry() throws {
        var value = try ambiguous()
        guard case .clarify(let question) = try value.requestReturn(origin: .trustedInterface, arabic: true, recordedAt: F.date, persist: { _ in }) else { return XCTFail() }
        XCTAssertEqual(question.text, "هل تريد العودة إلى النقطة المحفوظة أم إلى بداية الرحلة؟")
        let receipt = try F.deliver(&value, question, now: 2)
        XCTAssertThrowsError(try value.resolveReturn(.savedReference, receipt: receipt, origin: .trustedInterface, now: 32.01, recordedAt: F.date, persist: { _ in }))
    }
    func testFailedGoalSaveWithdrawsOldOutputAndPreservesPreviousDurableBytes() throws {
        var value = try F.prepared(), persisted = Data()
        try value.setDestination(F.endpoint(F.c,"p"), origin: .trustedInterface, recordedAt: F.date, persist: { persisted = $0 })
        let previous = persisted
        try value.plan(from: F.endpoint(F.a,"s"), now: 1)
        let ticket = try value.next(now: 1)
        XCTAssertThrowsError(try value.setDestination(F.endpoint(F.b,"p"), origin: .trustedInterface, recordedAt: F.date, persist: { _ in throw Failure.disk }))
        XCTAssertEqual(persisted, previous); XCTAssertNotEqual(try value.snapshot.encoded(), previous)
        XCTAssertEqual(value.snapshot.goal?.target.endpoint, F.endpoint(F.b,"p"))
        XCTAssertFalse(value.permits(ticket, now: 1)); XCTAssertTrue(value.persistenceBlocked)
        XCTAssertThrowsError(try value.plan(from: F.endpoint(F.a,"s"), now: 1))
        try value.flush(persist: { persisted = $0 }); XCTAssertFalse(value.persistenceBlocked)
        XCTAssertEqual(try ConnectedJourneySnapshot(data: persisted).goal?.target.endpoint, F.endpoint(F.b,"p"))
        try value.plan(from: F.endpoint(F.a,"s"), now: 1)
        XCTAssertEqual(value.itinerary.last?.to, F.endpoint(F.b,"p"))
    }
    func testFailedRestrictionWriteBlocksAndCannotBeClearedByJourneyFlush() throws {
        var value = try F.prepared()
        try value.setDestination(F.endpoint(F.a,"p"), origin: .trustedInterface, recordedAt: F.date, persist: { _ in })
        try value.plan(from: F.endpoint(F.a,"s"), now: 1)
        let old = try value.next(now: 1)
        XCTAssertThrowsError(try value.addRestrictions(blocked: [MapConnection("s","m")], zones: [], persistMap: { _ in throw Failure.disk }))
        XCTAssertFalse(value.permits(old, now: 1))
        try value.flush(persist: { _ in })
        XCTAssertThrowsError(try value.next(now: 1))
        XCTAssertThrowsError(try value.beginLocalization(in: F.a))
        XCTAssertThrowsError(try value.plan(from: F.endpoint(F.a,"s"), now: 1))
        try value.retryRestrictionPersistence(persistMap: { _ in })
        XCTAssertThrowsError(try value.plan(from: F.endpoint(F.a,"s"), now: 1)) // Remains blocked after durable save.
    }
    func testFailedCancelThenFlushCannotReviveSupersededGoal() throws {
        var value = try F.prepared()
        try value.setDestination(F.endpoint(F.c,"p"), origin: .trustedInterface, recordedAt: F.date, persist: { _ in })
        XCTAssertThrowsError(try value.cancel(origin: .trustedInterface, recordedAt: F.date, persist: { _ in throw Failure.disk }))
        XCTAssertEqual(value.snapshot.goal?.status, .cancelled)
        try value.flush(persist: { _ in })
        XCTAssertThrowsError(try value.plan(from: F.endpoint(F.a,"s"), now: 1))
        XCTAssertThrowsError(try value.setDestination(.init(binding: F.a, floorID: "wrong-floor", nodeID: "s"), origin: .trustedInterface, recordedAt: F.date, persist: { _ in }))
        XCTAssertThrowsError(try value.flush(persist: { _ in }))
        XCTAssertThrowsError(try value.plan(from: F.endpoint(F.a,"s"), now: 1))
    }
    func testInvalidCommandCannotBeClearedByUnrelatedReferenceWriteOrFlush() throws {
        var value = try F.prepared()
        try value.setDestination(F.endpoint(F.a,"p"), origin: .trustedInterface, recordedAt: F.date, persist: { _ in })
        XCTAssertThrowsError(try value.cancel(origin: .trustedInterface,
            recordedAt: Date(timeIntervalSince1970: .nan), persist: { _ in }))
        try value.saveReference(at: F.endpoint(F.a,"s"), origin: .trustedInterface, now: 1, recordedAt: F.date, persist: { _ in })
        XCTAssertThrowsError(try value.flush(persist: { _ in }))
        XCTAssertThrowsError(try value.plan(from: F.endpoint(F.a,"s"), now: 1))
        try value.cancel(origin: .trustedInterface, recordedAt: F.date, persist: { _ in })
        XCTAssertEqual(value.snapshot.goal?.status, .cancelled)
    }
    func testCatalogReinstallCannotDiscardKnownRestrictionAfterRemoval() throws {
        var value = try F.prepared()
        try value.addRestrictions(blocked: [MapConnection("s","m")], zones: [], persistMap: { _ in })
        try value.replaceCatalog(F.catalog(missing: F.a))
        XCTAssertThrowsError(try value.replaceCatalog(F.catalog()))
        XCTAssertNil(value.currentPose(now: 1))
    }
    func testAlreadyAtGoalCompletesFromFreshEvidenceWithoutInventedLeg() throws {
        var value = try F.prepared()
        try value.setDestination(F.endpoint(F.a,"s"), origin: .trustedInterface, recordedAt: F.date, persist: { _ in })
        try value.plan(from: F.endpoint(F.a,"s"), now: 1)
        XCTAssertTrue(value.itinerary.isEmpty)
        try value.completeAtGoal(now: 1, recordedAt: F.date, persist: { _ in })
        XCTAssertEqual(value.snapshot.goal?.status, .arrived)
    }
    func testOneWayPortalDoesNotCreateReturnPermission() throws {
        let original = try F.catalog(), portal = original.portals[0]
        let oneWay = JourneyPortal(transitionID: portal.transitionID, from: portal.from, to: portal.to,
            source: portal.source, surveyedDistance: portal.surveyedDistance, accessible: true, direction: .fromToOnly)
        let catalog = try ConnectedJourneyCatalog(registry: original.registry, installations: Array(original.installations.values),
            portals: [oneWay, original.portals[1]])
        XCTAssertNoThrow(try catalog.plan(from: F.endpoint(F.a,"s"), to: F.endpoint(F.c,"p"), body: F.body))
        XCTAssertThrowsError(try catalog.plan(from: F.endpoint(F.c,"p"), to: F.endpoint(F.a,"s"), body: F.body))
    }
    func testFailedMapWriteCannotStrandOwnerBySwitchingMapOrCatalog() throws {
        var value = try F.prepared()
        XCTAssertThrowsError(try value.addRestrictions(blocked: [MapConnection("s","m")], zones: [], persistMap: { _ in throw Failure.disk }))
        XCTAssertThrowsError(try value.beginLocalization(in: F.b))
        XCTAssertThrowsError(try value.replaceCatalog(F.catalog()))
        XCTAssertEqual(value.activeBinding, F.a)
        try value.retryRestrictionPersistence(persistMap: { _ in })
        XCTAssertNoThrow(try value.beginLocalization(in: F.b))
    }
    func testHistoryBoundsAndMalformedRestoration() throws {
        var value = try F.prepared()
        for i in 0..<300 {
            try value.setDestination(F.endpoint(F.a, i.isMultiple(of: 2) ? "p" : "m"), origin: .trustedInterface, recordedAt: F.date, persist: { _ in })
        }
        XCTAssertEqual(value.snapshot.events.count, ConnectedJourneySnapshot.maximumEvents)
        XCTAssertEqual(value.snapshot.droppedEventCount, 45)
        XCTAssertEqual(try ConnectedJourneySnapshot(data: value.snapshot.encoded()), value.snapshot)
        XCTAssertThrowsError(try ConnectedJourneySnapshot(data: Data(repeating: 0, count: ConnectedJourneySnapshot.maximumBytes + 1)))
        var malformed = value.snapshot; malformed.nextSequence = 0
        XCTAssertThrowsError(try malformed.encoded())
        for _ in 0..<ConnectedJourneySnapshot.maximumReferences {
            try value.saveReference(at: F.endpoint(F.a,"s"), origin: .trustedInterface, now: 1, recordedAt: F.date, persist: { _ in })
        }
        XCTAssertThrowsError(try value.saveReference(at: F.endpoint(F.a,"s"), origin: .trustedInterface, now: 1, recordedAt: F.date, persist: { _ in }))
    }
    func testQuietHarmlessQuestionHoldAndResumePreserveIntentButDoNotReplayPose() throws {
        var value = try F.prepared()
        try value.setDestination(F.endpoint(F.c,"p"), origin: .trustedInterface, recordedAt: F.date, persist: { _ in })
        try value.plan(from: F.endpoint(F.a,"s"), now: 1)
        let old = try value.next(now: 1), goal = value.snapshot.goal, itinerary = value.itinerary
        try value.setOrdinarySpeechMuted(true, origin: .trustedInterface)
        XCTAssertEqual(value.snapshot.goal, goal); XCTAssertEqual(value.itinerary, itinerary)
        XCTAssertTrue(value.permits(old, now: 1)) // Necessary route output is separate from ordinary quiet.
        var speech = SpeechDeliveryLedger()
        let answer = try XCTUnwrap(speech.begin(text: "A rainbow has many colours.", priority: .information,
                                               destination: .requested(UUID()), transport: .synthesized))
        _ = speech.finish(token: answer.token, outcome: .interrupted, now: 1)
        XCTAssertTrue(value.permits(old, now: 1)); XCTAssertEqual(value.snapshot.goal, goal)
        try value.hold(origin: .trustedInterface, persist: { _ in })
        XCTAssertEqual(value.snapshot.goal?.revision, goal?.revision); XCTAssertEqual(value.itinerary, itinerary)
        XCTAssertEqual(value.snapshot.goal?.status, .paused); XCTAssertFalse(value.permits(old, now: 1))
        XCTAssertThrowsError(try value.next(now: 1)); XCTAssertNil(value.currentPose(now: 1))
        try value.resume(origin: .trustedInterface, persist: { _ in })
        XCTAssertEqual(value.snapshot.goal?.status, .active)
        XCTAssertThrowsError(try value.next(now: 1)); XCTAssertNil(value.currentPose(now: 1))
        try F.observe(&value, F.endpoint(F.a,"s"), time: 2)
        try value.plan(from: F.endpoint(F.a,"s"), now: 2)
        XCTAssertNoThrow(try value.next(now: 2)); XCTAssertFalse(value.permits(old, now: 2))
        try value.setOrdinarySpeechMuted(false, origin: .trustedInterface)
        XCTAssertFalse(value.ordinarySpeechMuted)
    }
    func testPortalCannotBeCompletedWithoutDepartureEvidenceOrAfterRestart() throws {
        var value = try F.prepared(), time = 1.0
        try value.setDestination(F.endpoint(F.c,"p"), origin: .trustedInterface, recordedAt: F.date, persist: { _ in })
        try value.plan(from: F.endpoint(F.a,"s"), now: time)
        time += 0.1; try F.observe(&value, F.endpoint(F.a,"p"), time: time)
        try value.completeLocalLeg(now: time, recordedAt: F.date, persist: { _ in })
        try F.begin(&value, F.endpoint(F.b,"s"), time: 2)
        XCTAssertThrowsError(try value.completePortal(now: 2, recordedAt: F.date, persist: { _ in }))
        XCTAssertEqual(value.snapshot.events.filter { $0.kind == .portalEndpointsAssociated }.count, 0)
    }
    func armedAtFirstPortal() throws -> ConnectedJourneyCoordinator {
        var value = try F.prepared()
        try value.setDestination(F.endpoint(F.c,"p"), origin: .trustedInterface, recordedAt: F.date, persist: { _ in })
        try value.plan(from: F.endpoint(F.a,"s"), now: 1)
        try F.observe(&value, F.endpoint(F.a,"p"), time: 1.1)
        try value.completeLocalLeg(now: 1.1, recordedAt: F.date, persist: { _ in })
        try value.armPortal(now: 1.1, recordedAt: F.date)
        return value
    }
    func testPortalAssociationExpiresEvenWithFreshDestinationEvidence() throws {
        var value = try armedAtFirstPortal()
        try F.begin(&value, F.endpoint(F.b,"s"), time: 121.11)
        XCTAssertThrowsError(try value.completePortal(now: 121.11, recordedAt: F.date, persist: { _ in }))
        XCTAssertTrue(value.snapshot.events.filter { $0.kind == .portalEndpointsAssociated }.isEmpty)
    }
    func testOldPortalDepartureCannotSurviveGoalCatalogOrCameraChange() throws {
        for change in 0..<3 {
            var value = try armedAtFirstPortal()
            if change == 0 {
                try value.setDestination(F.endpoint(F.b,"p"), origin: .trustedInterface, recordedAt: F.date, persist: { _ in })
            } else if change == 1 {
                try value.replaceCatalog(F.catalog())
            } else { value.loseTracking() }
            try F.begin(&value, F.endpoint(F.b,"s"), time: 2)
            XCTAssertThrowsError(try value.completePortal(now: 2, recordedAt: F.date, persist: { _ in }))
            XCTAssertTrue(value.snapshot.events.filter { $0.kind == .portalEndpointsAssociated }.isEmpty)
        }
    }
    func testCurrentCaptureExpiryWithdrawsRouteWithoutNewFrame() throws {
        var value = try F.prepared()
        try value.setDestination(F.endpoint(F.a,"p"), origin: .trustedInterface, recordedAt: F.date, persist: { _ in })
        try value.plan(from: F.endpoint(F.a,"s"), now: 1)
        let ticket = try value.next(now: 1)
        XCTAssertFalse(value.permits(ticket, now: 1.51))
        XCTAssertThrowsError(try value.next(now: 1.51))
    }
}

extension ConnectedJourneyFailureTests {
    func testRejectedCaptureRetiresPortalDepartureWithoutChangingHistoryOrDestination() throws {
        var owner = try F.prepared()
        try owner.setDestination(F.endpoint(F.c,"p"),origin:.trustedInterface,recordedAt:F.date,persist:{_ in})
        try owner.plan(from:F.endpoint(F.a,"s"),now:1)
        try F.observe(&owner,F.endpoint(F.a,"m"),time:1.1); try owner.advanceWaypoint(now:1.1)
        try F.observe(&owner,F.endpoint(F.a,"p"),time:1.2)
        try owner.completeLocalLeg(now:1.2,recordedAt:F.date,persist:{_ in})
        try owner.armPortal(now:1.2,recordedAt:F.date)
        _ = try owner.beginLocalization(in:F.b)
        let saved = try owner.snapshot.encoded(), bad = try F.capture(owner,at:F.endpoint(F.b,"s"),time:1.3)
        let wrong = SpatialFloorSupport(binding:bad.binding,floorID:bad.floorID,sessionID:bad.sessionID,
            captureID:UUID(),height:0,capturedAt:bad.capturedAt)
        XCTAssertThrowsError(try owner.accept(bad,support:wrong,now:1.3))
        XCTAssertNil(owner.currentLeg); XCTAssertTrue(owner.itinerary.isEmpty)
        try F.observe(&owner,F.endpoint(F.b,"s"),time:1.4)
        XCTAssertThrowsError(try owner.completePortal(now:1.4,recordedAt:F.date,persist:{_ in}))
        XCTAssertEqual(try owner.snapshot.encoded(),saved)
        XCTAssertFalse(owner.snapshot.events.contains { $0.kind == .portalEndpointsAssociated })
        try owner.plan(from:F.endpoint(F.b,"s"),now:1.4)
        XCTAssertEqual(try owner.next(now:1.4).route.spatial.binding,F.b)
    }
}
