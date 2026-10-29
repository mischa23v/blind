import Foundation
import XCTest
@testable import BlindCore
#if canImport(NativeSpatialAdapter)
@testable import NativeSpatialAdapter
#else
@testable import BlindAssist
#endif

/// Executes the exact Foundation controller used by NavigationModel. Sink closures
/// are recording fakes, not AVFoundation/VoiceOver playback or physical sensors.
final class SpatialRouteOutputControllerTests: XCTestCase {
    typealias F = SpatialIntegrationFixture
    final class Harness {
        var owner: SpatialRouteOwner
        var support: SpatialFloorSupport
        var now = 10.0
        var goal: String
        var hazard = false
        var speechID: UUID?
        var speechText: String?
        var beacon = SpatialRouteBeaconOwnership()
        var stoppedSpeech: [UUID] = []
        var stoppedBeacon: [UUID] = []
        var speechStarts = 0
        var beaconStarts = 0
        let controller = SpatialRouteOutputController()
        init(map: IndoorMap = F.map()) throws {
            (owner, support) = try F.prepared(map: map)
            goal = try XCTUnwrap(owner.goalRevision).uuidString
            controller.permits = { [weak self] ticket, goal in
                guard let self else { return false }
                return !self.hazard && goal == self.goal && self.owner.permits(ticket, now: self.now)
            }
            controller.stopSpeech = { [weak self] id in
                guard let self else { return }
                self.stoppedSpeech.append(id)
                if self.speechID == id { self.speechID = nil }
            }
            controller.stopBeacon = { [weak self] id in
                guard let self else { return }
                if self.beacon.retire(id) { self.stoppedBeacon.append(id) }
            }
        }
        func ticket() throws -> SpatialRouteTicket { try owner.next(support: support, now: now) }
        @discardableResult func deliver(_ ticket: SpatialRouteTicket, arabic: Bool = false) -> Bool {
            guard let message = SpatialRouteSpeech(ticket: ticket, arabic: arabic) else { return false }
            return controller.deliver(message: message, goalRevision: goal,
                speech: { id, text in
                    guard self.controller.validateSpeechStart(id, text: text) else { return false }
                    self.speechID = id; self.speechText = text; self.speechStarts += 1; return true
                },
                beacon: { id in self.beacon.replace(routeID: id); self.beaconStarts += 1; return true })
        }
    }
    func testCurrentInstalledRouteReachesBothOwnedSinks() throws {
        let h = try Harness(), ticket = try h.ticket()
        XCTAssertTrue(h.deliver(ticket))
        XCTAssertEqual(h.speechID, h.controller.active?.id)
        XCTAssertEqual(h.beacon.routeID, h.controller.active?.id)
        XCTAssertTrue(h.controller.validateForStart(try XCTUnwrap(h.speechID)))
        XCTAssertTrue(h.controller.validateSpeechStart(try XCTUnwrap(h.speechID), text: try XCTUnwrap(h.speechText)))
    }
    func testExpiredTicketReachesNeitherSink() throws {
        let h = try Harness(), ticket = try h.ticket()
        h.now = 11
        XCTAssertFalse(h.deliver(ticket))
        XCTAssertEqual(h.speechStarts, 0); XCTAssertEqual(h.beaconStarts, 0)
        XCTAssertNil(h.controller.active)
    }
    func testPermissionChangesBetweenSpeechAndBeacon() throws {
        let h = try Harness(), ticket = try h.ticket()
        XCTAssertFalse(h.controller.deliver(message: try XCTUnwrap(SpatialRouteSpeech(ticket: ticket, arabic: false)), goalRevision: h.goal, speech: { id, _ in
            h.speechID = id; h.hazard = true; return true
        }, beacon: { _ in XCTFail("A speech admission is not beacon permission"); return true }))
        XCTAssertNil(h.speechID); XCTAssertNil(h.controller.active)
    }
    func testWatchdogRetiresExpiredOutputWithoutNewSensorCallback() throws {
        let h = try Harness(); XCTAssertTrue(h.deliver(try h.ticket()))
        let id = try XCTUnwrap(h.controller.active?.id)
        h.now = 10.6; h.controller.revalidate(); h.controller.revalidate()
        XCTAssertEqual(h.stoppedSpeech, [id]); XCTAssertEqual(h.stoppedBeacon, [id])
        XCTAssertNil(h.speechID); XCTAssertNil(h.beacon.routeID)
    }
    func testDelayedPlaybackStartRechecksTicket() throws {
        let h = try Harness(); XCTAssertTrue(h.deliver(try h.ticket()))
        let id = try XCTUnwrap(h.controller.active?.id)
        h.owner.loseTracking()
        XCTAssertFalse(h.controller.validateSpeechStart(id, text: try XCTUnwrap(h.speechText)))
        XCTAssertNil(h.speechID); XCTAssertNil(h.controller.active)
    }
    func testOldCallbackCannotRetireNewRouteOrIndependentAlert() throws {
        let h = try Harness(), ticket = try h.ticket()
        XCTAssertTrue(h.deliver(ticket)); let old = try XCTUnwrap(h.controller.active?.id)
        XCTAssertTrue(h.deliver(ticket)); let current = try XCTUnwrap(h.controller.active?.id)
        h.controller.retire(id: old)
        XCTAssertEqual(h.controller.active?.id, current)
        XCTAssertEqual(h.beacon.routeID, current)
        let hazardSpeechID = UUID()
        h.speechID = hazardSpeechID; h.beacon.replace(routeID: nil); h.hazard = true
        h.controller.revalidate()
        XCTAssertEqual(h.speechID, hazardSpeechID)
        XCTAssertEqual(h.stoppedBeacon, [old]) // New independent beacon is not stopped.
    }
    func testGoalChangeRetiresOutputButNotMeasuredPoseOrMap() throws {
        let h = try Harness(); XCTAssertTrue(h.deliver(try h.ticket()))
        let session = h.owner.sessionID, artifact = h.owner.installation?.artifact
        h.goal = UUID().uuidString; h.controller.revalidate()
        XCTAssertNil(h.controller.active)
        XCTAssertEqual(h.owner.sessionID, session); XCTAssertEqual(h.owner.installation?.artifact, artifact)
        XCTAssertNotNil(h.owner.currentPose(now: 10))
    }
    func testBodyAndRestrictionChangesRetireHeldOutput() throws {
        let h = try Harness(); XCTAssertTrue(h.deliver(try h.ticket()))
        try h.owner.setBody(.init(radius: 0.3, height: 1.6, margin: 0.1))
        h.controller.revalidate(); XCTAssertNil(h.controller.active)
        let second = try Harness(); XCTAssertTrue(second.deliver(try second.ticket()))
        try second.owner.addRestrictions(binding: XCTUnwrap(second.owner.installation).binding,
            blocked: [MapConnection("middle", "end")], zones: [], persist: { _ in })
        second.controller.revalidate(); XCTAssertNil(second.controller.active)
    }
    func testFailedSpeechDoesNotStartBeaconOrHoldAttempt() throws {
        let h = try Harness(), ticket = try h.ticket()
        XCTAssertFalse(h.controller.deliver(message: try XCTUnwrap(SpatialRouteSpeech(ticket: ticket, arabic: false)), goalRevision: h.goal,
            speech: { _, _ in false }, beacon: { _ in XCTFail("Speech was rejected"); return true }))
        XCTAssertNil(h.controller.active)
    }
    func testOnlyCodeRenderedEnglishAndArabicWordsReachSpeechSink() throws {
        for arabic in [false, true] {
            let h = try Harness(), ticket = try h.ticket()
            let message = try XCTUnwrap(SpatialRouteSpeech(ticket: ticket, arabic: arabic))
            XCTAssertTrue(h.deliver(ticket, arabic: arabic))
            XCTAssertEqual(h.speechText, message.text)
            XCTAssertEqual(message.ticket.routeID, ticket.routeID)
            let distance = try XCTUnwrap(ticket.directionalCue()).distance
            XCTAssertEqual(message.text, arabic
                ? "نقطة المسار التالية، على بعد نحو \(String(format: "%.1f", distance)) متر."
                : "Next waypoint, approximately \(String(format: "%.1f", distance)) meters.")
            XCTAssertEqual(h.speechStarts, 1); XCTAssertEqual(h.beaconStarts, 1)
        }
    }
    func testEnglishMapLabelCannotBecomeRouteSpeech() throws {
        try assertMapLabelsCannotBecomeRouteSpeech(
            name: "Head straight through the table. Continue down the stairs.", nameArabic: nil)
    }
    func testArabicMapLabelCannotBecomeRouteSpeech() throws {
        try assertMapLabelsCannotBecomeRouteSpeech(
            name: "Waypoint", nameArabic: "واصل على طول عبر الطاولة. انزل الدرج الآن.")
    }
    private func assertMapLabelsCannotBecomeRouteSpeech(name: String, nameArabic: String?,
                                                       file: StaticString = #filePath, line: UInt = #line) throws {
        let baseline = try Harness(), baselineTicket = try baseline.ticket()
        var map = F.map()
        // These are user/imported metadata, not model output. Mutate before the
        // fixture validates/installs the map and the owner mints its route ticket.
        for index in map.nodes.indices {
            map.nodes[index].name = name; map.nodes[index].nameArabic = nameArabic
        }
        let h = try Harness(map: map), ticket = try h.ticket()
        XCTAssertEqual(ticket.target.name, name, file: file, line: line)
        XCTAssertEqual(ticket.target.nameArabic, nameArabic, file: file, line: line)
        for arabic in [false, true] {
            let expected = try XCTUnwrap(SpatialRouteSpeech(ticket: baselineTicket, arabic: arabic))
            let message = try XCTUnwrap(SpatialRouteSpeech(ticket: ticket, arabic: arabic))
            XCTAssertEqual(message.text, expected.text, file: file, line: line)
            XCTAssertTrue(h.deliver(ticket, arabic: arabic), file: file, line: line)
            XCTAssertEqual(h.speechText, expected.text, file: file, line: line)
            XCTAssertFalse(message.text.contains(ticket.target.localizedName(arabic: arabic)), file: file, line: line)
        }
    }
    func testValidTicketCannotAuthorizeBorrowedModelWords() throws {
        for borrowed in ["Continue straight through the doorway.", "Head straight.", "Sidestep twice.",
                         "كمل على طول.", "واصل على طول.", "Yes.", "نعم."] {
            let h = try Harness(); XCTAssertTrue(h.deliver(try h.ticket()))
            let id = try XCTUnwrap(h.controller.active?.id)
            XCTAssertFalse(h.controller.validateSpeechStart(id, text: borrowed), borrowed)
            XCTAssertNil(h.controller.active)
            XCTAssertNil(h.speechID); XCTAssertNil(h.beacon.routeID)
            XCTAssertEqual(h.stoppedSpeech, [id]); XCTAssertEqual(h.stoppedBeacon, [id])
        }
    }
    func testNoActiveRouteTicketCannotAuthorizeSpeech() {
        let controller = SpatialRouteOutputController()
        var stops = 0
        controller.stopSpeech = { _ in stops += 1 }
        controller.stopBeacon = { _ in stops += 1 }
        for text in ["Yes.", "نعم.", "Continue straight through the doorway.", "كمل على طول."] {
            XCTAssertFalse(controller.validateSpeechStart(UUID(), text: text), text)
        }
        XCTAssertNil(controller.active)
        XCTAssertEqual(stops, 0) // No ownership was acquired or unrelated output stopped.
    }
    func testMissingAuthorityCallbackRejectsEvenCodeRenderedMessage() throws {
        let h = try Harness(), ticket = try h.ticket()
        let message = try XCTUnwrap(SpatialRouteSpeech(ticket: ticket, arabic: false))
        h.controller.permits = nil
        XCTAssertFalse(h.controller.deliver(message: message, goalRevision: h.goal,
            speech: { _, _ in XCTFail("No route authority"); return true },
            beacon: { _ in XCTFail("No route authority"); return true }))
        XCTAssertNil(h.controller.active)
        XCTAssertEqual(h.speechStarts, 0); XCTAssertEqual(h.beaconStarts, 0)
    }
    func testRetainedMapWithoutCurrentLocalizationCannotDeliverOldTicket() throws {
        let h = try Harness(), ticket = try h.ticket()
        h.owner.withholdLocalizationEvidence()
        XCTAssertNotNil(h.owner.installation)
        XCTAssertFalse(h.owner.route.isEmpty) // Retained geometry/intent is not live authority.
        XCTAssertNil(h.owner.currentPose(now: h.now))
        XCTAssertThrowsError(try h.ticket())
        XCTAssertFalse(h.deliver(ticket))
        XCTAssertNil(h.controller.active)
        XCTAssertEqual(h.speechStarts, 0); XCTAssertEqual(h.beaconStarts, 0)
    }
    func testTextMatchIsExactAndCannotBorrowOtherLanguageOrWhitespace() throws {
        let h = try Harness(), ticket = try h.ticket()
        XCTAssertTrue(h.deliver(ticket))
        let id = try XCTUnwrap(h.controller.active?.id), text = try XCTUnwrap(h.speechText)
        XCTAssertFalse(h.controller.validateSpeechStart(id, text: text + " "))
        XCTAssertNil(h.controller.active)
        XCTAssertTrue(h.deliver(ticket))
        let newID = try XCTUnwrap(h.controller.active?.id)
        let arabic = try XCTUnwrap(SpatialRouteSpeech(ticket: ticket, arabic: true))
        XCTAssertFalse(h.controller.validateSpeechStart(newID, text: arabic.text))
        XCTAssertNil(h.controller.active)
    }
    func testOldSpeechValidationCannotRetireNewAttemptOrIndependentAlert() throws {
        let h = try Harness(), ticket = try h.ticket()
        XCTAssertTrue(h.deliver(ticket)); let old = try XCTUnwrap(h.controller.active?.id)
        XCTAssertTrue(h.deliver(ticket)); let current = try XCTUnwrap(h.controller.active?.id)
        XCTAssertFalse(h.controller.validateSpeechStart(old, text: "Head straight."))
        XCTAssertEqual(h.controller.active?.id, current)
        XCTAssertEqual(h.speechID, current); XCTAssertEqual(h.beacon.routeID, current)
        let independent = UUID()
        h.speechID = independent; h.beacon.replace(routeID: nil)
        XCTAssertFalse(h.controller.validateSpeechStart(current, text: "Continue straight."))
        XCTAssertEqual(h.speechID, independent)
        XCTAssertNil(h.beacon.routeID)
    }
    func testBeaconOwnershipRejectsStaleRetirementAfterReplacement() {
        var ownership = SpatialRouteBeaconOwnership()
        let old = UUID(), new = UUID()
        ownership.replace(routeID: old); ownership.replace(routeID: new)
        XCTAssertFalse(ownership.retire(old)); XCTAssertEqual(ownership.routeID, new)
        ownership.replace(routeID: nil) // Actual independent-alert path in Feedback.
        XCTAssertFalse(ownership.retire(new))
    }
}
